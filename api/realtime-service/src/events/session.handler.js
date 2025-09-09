const logger = require('../utils/logger');
const sessionService = require('../services/session.service');
const sessionApiService = require('../services/session-api.service');

// 하이브리드 메시징 시스템 활용하도록 수정
module.exports = (io, socket, redisClient, messagingSystem) => {
    // 세션 입장
    socket.on('join_session', async (data) => {
        try {
            const {sessionId, sessionType, sessionTitle} = data;
            const {user} = socket;

            logger.info(`사용자 ${user.id}가 세션 ${sessionId} 입장 시도`);

            // 1. 먼저 세션 유효성 검증
            let isValid = await sessionService.validateSession(sessionId, user.id, redisClient);

            // 2. 세션이 유효하지 않으면 자동으로 생성 시도
            if (!isValid) {
                logger.info(`세션 ${sessionId}가 존재하지 않음, 자동 생성 시도`);
                
                try {
                    // 먼저 세션이 이미 존재하는지 확인
                    try {
                        const existingSession = await sessionApiService.getSession(sessionId);
                        if (existingSession) {
                            logger.info(`세션 ${sessionId}가 이미 존재함, 재사용`, {
                                userId: user.id,
                                sessionStatus: existingSession.status
                            });
                            isValid = true;
                        }
                    } catch (getError) {
                        // 세션이 없으면 새로 생성
                        logger.debug(`세션 조회 실패, 새 세션 생성 진행: ${getError.message}`);
                        
                        // 세션 타입 매핑 (Flutter에서 온 값을 session-service 형식으로 변환)
                        const sessionTypeMapping = {
                            '발표': 'presentation',
                            '소개팅': 'dating', 
                            '면접': 'interview',
                            '면접(인터뷰)': 'interview',
                            '코칭': 'business',
                            'presentation': 'presentation',
                            'dating': 'dating',
                            'interview': 'interview',
                            'business': 'business'
                        };
                        
                        const mappedType = sessionTypeMapping[sessionType] || 'dating';
                        const title = sessionTitle || `${sessionType || '소개팅'} 세션`;
                        
                        // session-service에 세션 생성 요청
                        const sessionData = await sessionApiService.createSession({
                            id: sessionId, // 기존 sessionId 사용
                            title: title,
                            type: mappedType,
                            user_id: user.id
                        });
                        
                        logger.info(`세션 자동 생성 성공: ${sessionId}`, {
                            userId: user.id,
                            sessionType: mappedType,
                            title: title
                        });
                        
                        // 세션 생성 후 다시 유효성 검증
                        isValid = true;
                    }
                    
                } catch (createError) {
                    logger.warn(`세션 자동 생성 실패: ${createError.message}`, {
                        sessionId,
                        userId: user.id,
                        sessionType,
                        error: createError.message
                    });
                    
                    // 세션 생성 실패 시에도 세션 참여 허용 (폴백)
                    logger.info(`세션 생성 실패하지만 세션 참여 허용 (폴백): ${sessionId}`);
                    isValid = true;
                }
            }

            if (!isValid) {
                socket.emit('error', {
                    type: 'session_error',
                    message: '세션에 접근할 수 없습니다'
                });
                return;
            }

            // 세션 룸에 참여
            socket.join(`session:${sessionId}`);

            // 세션 참여 상태 저장
            await redisClient.sadd(`session:participants:${sessionId}`, user.id);

            // 세션 연결 정보 저장
            await redisClient.hset(`connections:user:${user.id}`, 'sessionId', sessionId);
            await redisClient.hset(`connections:device:${socket.id}`, 'userId', user.id);

            // 세션 상태 조회
            const sessionStatus = await sessionService.getSessionStatus(sessionId, redisClient);

            // 세션 입장 알림
            socket.emit('session_joined', {
                sessionId,
                status: sessionStatus,
                message: '세션에 성공적으로 참여했습니다'
            });

            // 다른 참가자들에게 새 참가자 알림
            socket.to(`session:${sessionId}`).emit('participant_joined', {
                userId: user.id,
                timestamp: new Date().toISOString()
            });

            // Kafka에 세션 이벤트 발행 (지속성 지원)
            try {
                await messagingSystem.publish(
                    process.env.KAFKA_TOPIC_SESSION_EVENTS || 'haptitalk-session-events',
                    {
                        eventType: 'participant_joined',
                        sessionId,
                        userId: user.id,
                        timestamp: new Date().toISOString()
                    },
                    { useKafka: true, key: sessionId }
                );
                logger.debug(`세션 참여 이벤트 Kafka 발행 성공: ${sessionId}`, { 
                    component: 'messaging', 
                    type: 'kafka' 
                });
            } catch (kafkaError) {
                logger.warn(`세션 참여 이벤트 Kafka 발행 실패: ${kafkaError.message}`, {
                    component: 'messaging',
                    type: 'kafka'
                });
                // Kafka 발행 실패 시 Redis로 폴백
                await messagingSystem.publishRedis(`session:events:${sessionId}`, {
                    eventType: 'participant_joined',
                    userId: user.id,
                    timestamp: new Date().toISOString()
                });
            }

            logger.info(`사용자 ${user.id}가 세션 ${sessionId}에 성공적으로 참여함`);
        } catch (error) {
            logger.error(`세션 참여 오류: ${error.message}`);
            socket.emit('error', {
                type: 'session_error',
                message: '세션 참여 중 오류가 발생했습니다'
            });
        }
    });

    // 세션 나가기
    socket.on('leave_session', async (data) => {
        try {
            const {sessionId} = data;
            const {user} = socket;

            // 세션 룸에서 나가기
            socket.leave(`session:${sessionId}`);

            // 세션 참여 상태 제거
            await redisClient.srem(`session:participants:${sessionId}`, user.id);

            // 세션 연결 정보 제거
            await redisClient.hdel(`connections:user:${user.id}`, 'sessionId');

            // 다른 참가자들에게 참가자 퇴장 알림
            socket.to(`session:${sessionId}`).emit('participant_left', {
                userId: user.id,
                timestamp: new Date().toISOString()
            });

            // Kafka에 세션 이벤트 발행 (지속성 지원)
            try {
                await messagingSystem.publish(
                    process.env.KAFKA_TOPIC_SESSION_EVENTS || 'haptitalk-session-events',
                    {
                        eventType: 'participant_left',
                        sessionId,
                        userId: user.id,
                        timestamp: new Date().toISOString()
                    },
                    { useKafka: true, key: sessionId }
                );
                logger.debug(`세션 퇴장 이벤트 Kafka 발행 성공: ${sessionId}`, { 
                    component: 'messaging', 
                    type: 'kafka' 
                });
            } catch (kafkaError) {
                logger.warn(`세션 퇴장 이벤트 Kafka 발행 실패: ${kafkaError.message}`, {
                    component: 'messaging',
                    type: 'kafka'
                });
                // Kafka 발행 실패 시 Redis로 폴백
                await messagingSystem.publishRedis(`session:events:${sessionId}`, {
                    eventType: 'participant_left',
                    userId: user.id,
                    timestamp: new Date().toISOString()
                });
            }

            logger.info(`사용자 ${user.id}가 세션 ${sessionId}에서 나감`);
        } catch (error) {
            logger.error(`세션 나가기 오류: ${error.message}`);
        }
    });

    // 세션 상태 요청
    socket.on('get_session_status', async (data) => {
        try {
            const {sessionId} = data;
            const sessionStatus = await sessionService.getSessionStatus(sessionId, redisClient);

            socket.emit('session_status', sessionStatus);
        } catch (error) {
            logger.error(`세션 상태 조회 오류: ${error.message}`);
            socket.emit('error', {
                type: 'session_error',
                message: '세션 상태 조회 중 오류가 발생했습니다'
            });
        }
    });

    // 세션 이벤트 발행 (분석 결과, 피드백 명령 등)
    socket.on('publish_session_event', async (data) => {
        try {
            const { sessionId, eventType, payload } = data;
            const { user } = socket;

            // 세션 유효성 및 권한 검증
            const isValid = await sessionService.validateSession(sessionId, user.id, redisClient);
            if (!isValid) {
                socket.emit('error', {
                    type: 'session_error',
                    message: '세션 이벤트 발행 권한이 없습니다'
                });
                return;
            }

            // 이벤트 유형에 따라 다른 토픽으로 발행
            let topic;
            let shouldUseKafka = true; // 기본적으로 Kafka 사용

            switch (eventType) {
                case 'analysis_result':
                    topic = process.env.KAFKA_TOPIC_ANALYSIS_RESULTS || 'haptitalk-analysis-results';
                    break;
                case 'feedback_command':
                    // 피드백은 지연 시간이 중요하므로 Redis 우선 사용
                    shouldUseKafka = false;
                    topic = `feedback:channel:${sessionId}`;
                    break;
                case 'session_update':
                    topic = process.env.KAFKA_TOPIC_SESSION_EVENTS || 'haptitalk-session-events';
                    break;
                default:
                    topic = process.env.KAFKA_TOPIC_SESSION_EVENTS || 'haptitalk-session-events';
            }

            // 메시지 구성
            const message = {
                sessionId,
                eventType,
                userId: user.id,
                timestamp: new Date().toISOString(),
                data: payload
            };

            // 발행 방식 결정 (지연 시간이 중요한 피드백은 Redis 사용)
            if (shouldUseKafka) {
                try {
                    await messagingSystem.publish(topic, message, { 
                        useKafka: true, 
                        key: sessionId 
                    });
                    logger.debug(`이벤트 Kafka 발행 성공: ${eventType} - ${sessionId}`, { 
                        component: 'messaging', 
                        type: 'kafka' 
                    });
                } catch (kafkaError) {
                    logger.warn(`이벤트 Kafka 발행 실패: ${kafkaError.message}`, {
                        component: 'messaging',
                        type: 'kafka',
                        eventType
                    });
                    
                    // Kafka 발행 실패 시 Redis로 폴백
                    if (eventType === 'analysis_result') {
                        await messagingSystem.publishRedis(`analysis:events:${sessionId}`, message);
                    } else {
                        await messagingSystem.publishRedis(`session:events:${sessionId}`, message);
                    }
                }
            } else {
                // Redis 직접 사용 (지연 시간이 중요한 피드백)
                await messagingSystem.publishRedis(topic, message);
                logger.debug(`이벤트 Redis 발행 성공: ${eventType} - ${sessionId}`, { 
                    component: 'messaging', 
                    type: 'redis' 
                });
                
                // 중요 피드백은 Kafka에도 백업 (지속성 목적)
                if (eventType === 'feedback_command') {
                    try {
                        await messagingSystem.publish(
                            process.env.KAFKA_TOPIC_FEEDBACK_COMMANDS || 'haptitalk-feedback-commands',
                            message,
                            { useKafka: true, key: sessionId }
                        );
                    } catch (error) {
                        logger.warn(`피드백 명령 Kafka 백업 실패: ${error.message}`, {
                            component: 'messaging',
                            type: 'kafka'
                        });
                    }
                }
            }

            // 발행 성공 응답
            socket.emit('event_published', {
                success: true,
                eventType,
                sessionId,
                timestamp: new Date().toISOString()
            });
        } catch (error) {
            logger.error(`세션 이벤트 발행 오류: ${error.message}`);
            socket.emit('error', {
                type: 'publish_error',
                message: '이벤트 발행 중 오류가 발생했습니다'
            });
        }
    });
};