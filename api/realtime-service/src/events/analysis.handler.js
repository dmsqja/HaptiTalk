const logger = require('../utils/logger');
const AnalyticsCore = require('../../api/shared/analytics-core');

// 이전 지표 저장용 메모리 캐시
const previousMetricsCache = new Map();

module.exports = (io, socket, redisClient, messagingSystem) => {
    // 음성 특성 데이터 수신
    socket.on('speech_features', async (data) => {
        try {
            const {user} = socket;
            const {sessionId, timestamp, features, scenario} = data;

            // 공통 분석 모듈을 사용한 실시간 지표 계산
            const realtimeMetrics = AnalyticsCore.calculateRealtimeMetrics(features, scenario);
            
            // 이전 지표와 비교하여 햅틱 피드백 조건 체크
            const previousMetrics = previousMetricsCache.get(sessionId);
            const hapticConditions = AnalyticsCore.shouldSendHapticFeedback(
                realtimeMetrics, 
                previousMetrics, 
                scenario
            );

            // 현재 지표를 캐시에 저장
            previousMetricsCache.set(sessionId, realtimeMetrics);

            // 실시간 지표를 클라이언트에 전송
            socket.emit('realtime_metrics', {
                sessionId,
                timestamp,
                metrics: realtimeMetrics,
                messageId: data.message_id || `metrics_${Date.now()}`
            });

            // 햅틱 피드백 조건이 충족되면 피드백 서비스에 요청
            if (hapticConditions && hapticConditions.length > 0) {
                for (const condition of hapticConditions) {
                    try {
                        // 하이브리드 메시징을 통해 피드백 요청 전송
                        await messagingSystem.publishRedis(
                            `feedback:request:${sessionId}`,
                            JSON.stringify({
                                sessionId,
                                userId: user.id,
                                condition,
                                timestamp: Date.now()
                            })
                        );

                        logger.debug(`햅틱 피드백 요청 전송: ${condition.type} (${sessionId})`);
                    } catch (feedbackError) {
                        logger.error(`햅틱 피드백 요청 실패: ${feedbackError.message}`);
                    }
                }
            }

            // 분석 요청을 Redis 채널에 발행 (기존 로직 유지)
            const analysisRequest = {
                type: 'speech_features',
                userId: user.id,
                sessionId,
                timestamp,
                features,
                realtimeMetrics, // 계산된 실시간 지표 포함
                messageId: data.message_id || `msg_${Date.now()}`
            };

            // analysis:requests 채널로 분석 요청 발행
            await redisClient.publish(
                'analysis:requests',
                JSON.stringify(analysisRequest)
            );

            logger.debug(`음성 특성 데이터 수신 및 실시간 지표 계산: 세션 ${sessionId}, 사용자 ${user.id}`, {
                metrics: realtimeMetrics,
                hapticTriggered: hapticConditions?.length > 0
            });
        } catch (error) {
            logger.error(`음성 특성 데이터 처리 오류: ${error.message}`, {
                stack: error.stack,
                sessionId: data.sessionId
            });
            socket.emit('error', {
                type: 'analysis_error',
                message: '음성 데이터 처리 중 오류가 발생했습니다',
                originalMessage: data.message_id
            });
        }
    });

    // 텍스트 데이터 수신
    socket.on('text_segment', async (data) => {
        try {
            const {user} = socket;
            const {sessionId, timestamp, speakerId, text, startTime, endTime} = data;

            // 분석 요청을 Redis 채널에 발행
            const analysisRequest = {
                type: 'text_segment',
                userId: user.id,
                sessionId,
                timestamp,
                speakerId,
                text,
                segment: {
                    start: startTime,
                    end: endTime
                },
                messageId: data.message_id || `msg_${Date.now()}`
            };

            // analysis:requests 채널로 분석 요청 발행
            await redisClient.publish(
                'analysis:requests',
                JSON.stringify(analysisRequest)
            );

            logger.debug(`텍스트 데이터 수신: 세션 ${sessionId}, 사용자 ${user.id}`);
        } catch (error) {
            logger.error(`텍스트 데이터 처리 오류: ${error.message}`);
            socket.emit('error', {
                type: 'analysis_error',
                message: '텍스트 데이터 처리 중 오류가 발생했습니다',
                originalMessage: data.message_id
            });
        }
    });

    // 세션 종료 시 캐시 정리
    socket.on('session_end', (data) => {
        try {
            const { sessionId } = data;
            if (sessionId) {
                previousMetricsCache.delete(sessionId);
                logger.debug(`세션 ${sessionId} 지표 캐시 정리 완료`);
            }
        } catch (error) {
            logger.error(`세션 종료 처리 오류: ${error.message}`);
        }
    });

    // 소켓 연결 종료 시 해당 사용자의 모든 세션 캐시 정리
    socket.on('disconnect', () => {
        try {
            // 현재 사용자의 모든 세션 캐시 정리
            for (const [sessionId, metrics] of previousMetricsCache.entries()) {
                // 사용자별 세션 식별 로직이 필요하다면 여기에 추가
                // 현재는 모든 캐시를 유지하고 TTL 기반으로 정리
            }
        } catch (error) {
            logger.error(`연결 종료 시 캐시 정리 오류: ${error.message}`);
        }
    });
};