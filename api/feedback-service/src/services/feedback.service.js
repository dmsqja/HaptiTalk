const HapticPattern = require('../models/pattern.model');
const { getUserSettings } = require('./setting.service');
const { saveFeedbackHistory } = require('./mongodb.service');
const { getSessionAnalytics } = require('./mongodb.service');
const Redis = require('ioredis');
const logger = require('../utils/logger');

// Redis 클라이언트 초기화
const redisClient = new Redis({
    host: process.env.REDIS_HOST || 'redis',
    port: process.env.REDIS_PORT || 6379,
    password: process.env.REDIS_PASSWORD
});

/**
 * 실시간 피드백 생성
 */
const generateFeedback = async (params) => {
    const { userId, sessionId, context, deviceId, timestamp } = params;

    try {
        logger.debug(`피드백 생성 요청: 사용자 ${userId}, 세션 ${sessionId}`, {
            context: context?.type || 'unknown',
            deviceId
        });

        // 1. 사용자 피드백 설정 조회
        const userSettings = await getUserSettings(userId);

        // 2. 피드백 생성 전 이전 피드백과의 간격 확인
        const shouldSendFeedback = await checkFeedbackInterval(userId, userSettings.minimum_interval_seconds);
        if (!shouldSendFeedback) {
            logger.debug(`피드백 생성 스킵 - 최소 간격 미충족: ${userId}`);
            return null; // 최소 간격이 지나지 않았으면 피드백 생성하지 않음
        }

        // 3. 세션 분석 데이터 조회 (컨텍스트 개선)
        const sessionAnalytics = await getSessionAnalytics(sessionId);
        const enhancedContext = enhanceContext(context, sessionAnalytics);

        // 4. 피드백 결정 (가장 적절한 햅틱 패턴 선택)
        const feedbackDecision = decideFeedback(enhancedContext, userSettings);
        if (!feedbackDecision) {
            logger.debug(`피드백 생성 스킵 - 적절한 피드백 없음: ${userId}`);
            return null; // 적절한 피드백이 없음
        }

        // 5. 햅틱 패턴 데이터 조회
        const pattern = await HapticPattern.findByPk(feedbackDecision.patternId);
        if (!pattern || !pattern.is_active) {
            logger.warn(`피드백 생성 실패 - 패턴 없음 또는 비활성화: ${feedbackDecision.patternId}`);
            return null; // 패턴이 없거나 비활성화됨
        }

        // 6. 햅틱 데이터 구성
        const hapticData = {
            pattern: pattern.pattern_data,
            intensity: userSettings.haptic_strength,
            duration_ms: pattern.duration_ms
        };

        // 7. 피드백 데이터 구성
        const feedback = {
            id: generateUniqueId(),
            type: feedbackDecision.type,
            pattern_id: pattern.id,
            priority: feedbackDecision.priority,
            haptic_data: hapticData,
            message: feedbackDecision.message,
            visual_cue: feedbackDecision.visualCue
        };

        // 8. 피드백 이력 저장 (비동기)
        const feedbackHistoryData = {
            sessionId,
            userId,
            device_id: deviceId,
            pattern_id: pattern.id,
            feedback_type: feedbackDecision.type,
            intensity: userSettings.haptic_strength,
            trigger: feedbackDecision.trigger,
            delivery: {
                sent: true,
                received: false
            },
            context: enhancedContext,
            timestamp
        };

        saveFeedbackHistory(feedbackHistoryData)
            .then(id => {
                feedback.history_id = id;
                logger.debug(`피드백 이력 저장 성공: ${id}`);
            })
            .catch(err => {
                logger.error('Error saving feedback history:', err);
            });

        // 9. 마지막 피드백 시간 업데이트 (Redis)
        await redisClient.set(`feedback:last:${userId}`, new Date().toISOString());

        logger.info(`피드백 생성 성공: ${feedback.id}`, {
            userId,
            sessionId,
            feedbackType: feedbackDecision.type,
            patternId: pattern.id,
            priority: feedbackDecision.priority,
            intensity: userSettings.haptic_strength
        });

        return feedback;
    } catch (error) {
        logger.error('Error in generateFeedback:', error);
        throw error;
    }
};

/**
 * 피드백 간격 체크
 */
const checkFeedbackInterval = async (userId, minimumIntervalSeconds) => {
    try {
        const lastFeedbackTime = await redisClient.get(`feedback:last:${userId}`);
        if (!lastFeedbackTime) {
            logger.debug(`첫 피드백 생성 허용: ${userId}`);
            return true; // 이전 피드백이 없으면 즉시 전송 가능
        }

        const now = new Date();
        const last = new Date(lastFeedbackTime);
        const diffSeconds = (now - last) / 1000;

        const allowed = diffSeconds >= minimumIntervalSeconds;
        logger.debug(`피드백 간격 체크: ${userId}`, {
            diffSeconds,
            minimumIntervalSeconds,
            allowed
        });

        return allowed;
    } catch (error) {
        logger.error(`Error in checkFeedbackInterval for userId ${userId}:`, error);
        return true; // 오류 발생 시 기본적으로 피드백 허용
    }
};

/**
 * 컨텍스트 개선
 */
const enhanceContext = (context, sessionAnalytics) => {
    const enhancedContext = { ...context };

    if (sessionAnalytics) {
        // 세션 분석 데이터로 컨텍스트 보강
        // 예: 장기적인 트렌드, 이전 감정 상태 등
    }

    return enhancedContext;
};

/**
 * 피드백 결정 알고리즘
 */
const decideFeedback = (context, userSettings) => {
    // 각 피드백 유형에 대한 점수 계산
    const scores = {
        speaking_pace: calculateSpeakingPaceScore(context),
        volume: calculateVolumeScore(context),
        interest_level: calculateInterestScore(context),
        silence: calculateSilenceScore(context)
    };

    // 가장 높은 점수의 피드백 유형 선택
    let maxType = null;
    let maxScore = 0;

    for (const [type, score] of Object.entries(scores)) {
        if (score.score > maxScore) {
            maxScore = score.score;
            maxType = type;
        }
    }

    // 임계값 이상인 경우만 피드백 전송
    if (maxScore < 0.5) {
        return null;
    }

    // 피드백 유형별 설정 및 메시지
    const feedbackConfig = {
        speaking_pace: {
            patternId: 'S1',
            priority: 'high',
            message: '말하기 속도가 빠릅니다. 조금 천천히 말해보세요.',
            visualCue: 'speed_warning',
            trigger: {
                type: 'analysis_result',
                value: 'speaking_pace_too_fast',
                confidence: maxScore
            }
        },
        volume: {
            patternId: 'S2',
            priority: 'medium',
            message: context.current_volume > 70 ? '목소리가 큽니다. 조금 낮추어 보세요.' : '목소리가 작습니다. 조금 크게 말해보세요.',
            visualCue: 'volume_warning',
            trigger: {
                type: 'analysis_result',
                value: context.current_volume > 70 ? 'volume_too_high' : 'volume_too_low',
                confidence: maxScore
            }
        },
        interest_level: {
            patternId: context.interest_level > 0.7 ? 'R1' : 'R2',
            priority: 'medium',
            message: context.interest_level > 0.7 ? '상대방이 관심을 보입니다.' : '상대방의 관심도가 낮아지고 있습니다.',
            visualCue: context.interest_level > 0.7 ? 'interest_high' : 'interest_low',
            trigger: {
                type: 'analysis_result',
                value: context.interest_level > 0.7 ? 'interest_increase' : 'interest_decrease',
                confidence: maxScore
            }
        },
        silence: {
            patternId: 'F2',
            priority: 'high',
            message: '침묵이 길어지고 있습니다. 새로운 주제를 시작해보세요.',
            visualCue: 'silence_warning',
            trigger: {
                type: 'analysis_result',
                value: 'silence_too_long',
                confidence: maxScore
            }
        }
    };

    // 선택된 피드백 유형의 설정 반환
    return maxType ? { type: maxType, ...feedbackConfig[maxType] } : null;
};

/**
 * 말하기 속도 점수 계산
 */
const calculateSpeakingPaceScore = (context) => {
    const { current_speaking_pace } = context;

    // 말하기 속도가 너무 빠르면 높은 점수
    if (current_speaking_pace > 4.0) {
        return {
            score: (current_speaking_pace - 4.0) * 0.5,
            data: { threshold: 4.0, value: current_speaking_pace }
        };
    }

    return { score: 0, data: null };
};

/**
 * 음량 점수 계산
 */
const calculateVolumeScore = (context) => {
    const { current_volume } = context;

    // 음량이 너무 크거나 작으면 높은 점수
    if (current_volume > 80) {
        return {
            score: (current_volume - 80) * 0.05,
            data: { threshold: 80, value: current_volume, type: 'high' }
        };
    } else if (current_volume < 40) {
        return {
            score: (40 - current_volume) * 0.05,
            data: { threshold: 40, value: current_volume, type: 'low' }
        };
    }

    return { score: 0, data: null };
};

/**
 * 관심도 점수 계산
 */
const calculateInterestScore = (context) => {
    const { interest_level, previous_interest_level } = context;

    // 관심도가 크게 변했을 때 높은 점수
    if (previous_interest_level && Math.abs(interest_level - previous_interest_level) > 0.2) {
        return {
            score: Math.abs(interest_level - previous_interest_level),
            data: { current: interest_level, previous: previous_interest_level }
        };
    }

    return { score: 0, data: null };
};

/**
 * 침묵 점수 계산
 */
const calculateSilenceScore = (context) => {
    const { silence_duration } = context;

    // 침묵이 길수록 높은 점수
    if (silence_duration > 5) {
        return {
            score: (silence_duration - 5) * 0.1,
            data: { threshold: 5, value: silence_duration }
        };
    }

    return { score: 0, data: null };
};

/**
 * 유니크 ID 생성
 */
const generateUniqueId = () => {
    return 'f' + Math.random().toString(36).substr(2, 9);
};

/**
 * 피드백 수신 확인
 */
const acknowledgeFeedback = async (feedbackId, data) => {
    try {
        // MongoDB에서 피드백 이력 업데이트
        const collection = getCollection('hapticFeedbacks');
        await collection.updateOne(
            { _id: feedbackId },
            {
                $set: {
                    'delivery.received': true,
                    'delivery.receivedAt': data.receivedAt
                }
            }
        );

        return true;
    } catch (error) {
        logger.error(`Error in acknowledgeFeedback for id ${feedbackId}:`, error);
        throw error;
    }
};

/**
 * STT 분석 결과를 처리하여 햅틱 피드백을 생성하고 실시간 서비스로 전송
 */
const processSTTAnalysisAndGenerateFeedback = async (params) => {
    const { userId, sessionId, text, speechMetrics, emotionAnalysis, scenario, language, timestamp } = params;

    try {
        logger.debug(`STT 분석 결과 처리 시작: 사용자 ${userId}, 세션 ${sessionId}`, {
            textLength: text?.length,
            scenario,
            language,
            wpm: speechMetrics?.evaluationWpm,
            emotion: emotionAnalysis?.primaryEmotion?.emotionKr
        });

        // 1. 사용자 피드백 설정 조회
        const userSettings = await getUserSettings(userId);

        // 2. 피드백 생성 전 이전 피드백과의 간격 확인
        const shouldSendFeedback = await checkFeedbackInterval(userId, userSettings.minimum_interval_seconds);
        if (!shouldSendFeedback) {
            logger.debug(`피드백 생성 스킵 - 최소 간격 미충족: ${userId}`);
            return null;
        }

        // 3. STT 분석 결과 기반 피드백 결정 (8개 MVP 패턴 활용)
        const feedbackDecision = decideFeedbackFromSTTAnalysis({
            text,
            speechMetrics,
            emotionAnalysis,
            scenario,
            language,
            userSettings
        });

        if (!feedbackDecision) {
            logger.debug(`피드백 생성 스킵 - 적절한 피드백 없음: ${userId}`);
            return null;
        }

        // 4. 햅틱 패턴 데이터 조회 (8개 MVP 패턴 중 매칭)
        const patternMapping = getHapticPatternMapping();
        const patternId = patternMapping[feedbackDecision.type];
        
        if (!patternId) {
            logger.warn(`피드백 생성 실패 - 매핑된 패턴 없음: ${feedbackDecision.type}`);
            return null;
        }

        // 5. 햅틱 데이터 구성 (8개 MVP 패턴 기반)
        const hapticData = constructHapticData(patternId, userSettings.haptic_strength);

        // 6. 피드백 데이터 구성
        const feedback = {
            id: generateUniqueId(),
            type: feedbackDecision.type,
            pattern_id: patternId,
            priority: feedbackDecision.priority,
            haptic_data: hapticData,
            message: feedbackDecision.message,
            visual_cue: feedbackDecision.visualCue
        };

        // 7. 피드백 이력 저장 (비동기)
        const feedbackHistoryData = {
            sessionId,
            userId,
            pattern_id: patternId,
            feedback_type: feedbackDecision.type,
            intensity: userSettings.haptic_strength,
            trigger: feedbackDecision.trigger,
            delivery: {
                sent: true,
                received: false
            },
            context: {
                text: text?.substring(0, 100), // 처음 100자만 저장
                speechMetrics,
                emotionAnalysis,
                scenario,
                language
            },
            timestamp
        };

        saveFeedbackHistory(feedbackHistoryData)
            .then(id => {
                feedback.history_id = id;
                logger.debug(`피드백 이력 저장 성공: ${id}`);
            })
            .catch(err => {
                logger.error('Error saving feedback history:', err);
            });

        // 8. 마지막 피드백 시간 업데이트 (Redis)
        await redisClient.set(`feedback:last:${userId}`, new Date().toISOString());

        // 9. 실시간 서비스로 햅틱 피드백 전송 (Redis Pub/Sub)
        await sendHapticFeedbackToRealtimeService(sessionId, feedback);

        logger.info(`STT 분석 기반 피드백 생성 성공: ${feedback.id}`, {
            userId,
            sessionId,
            feedbackType: feedbackDecision.type,
            patternId,
            priority: feedbackDecision.priority,
            intensity: userSettings.haptic_strength
        });

        return feedback;
    } catch (error) {
        logger.error('Error in processSTTAnalysisAndGenerateFeedback:', error);
        throw error;
    }
};

/**
 * STT 분석 결과 기반 피드백 결정 (8개 MVP 패턴)
 */
const decideFeedbackFromSTTAnalysis = ({ text, speechMetrics, emotionAnalysis, scenario, language, userSettings }) => {
    try {
        // 🎯 S1: 말하기 속도 기반 피드백 (가장 우선순위 높음)
        if (speechMetrics?.evaluationWpm) {
            const wpm = speechMetrics.evaluationWpm;
            
            if (wpm > 150) {
                return {
                    type: 'speaking_pace_fast',
                    priority: 'high',
                    message: '말하는 속도가 너무 빠릅니다. 조금 천천히 말해보세요.',
                    visualCue: {
                        color: '#FF6B6B',
                        icon: 'speed_down',
                        text: '천천히'
                    },
                    trigger: {
                        type: 'speech_analysis',
                        value: 'wpm_too_fast',
                        confidence: Math.min((wpm - 150) / 50, 1.0),
                        data: { currentWpm: wpm, threshold: 150 }
                    }
                };
            } else if (wpm < 80) {
                return {
                    type: 'speaking_pace_slow',
                    priority: 'medium',
                    message: '말하는 속도가 느립니다. 조금 더 활발하게 말해보세요.',
                    visualCue: {
                        color: '#FFD93D',
                        icon: 'speed_up',
                        text: '조금 더 빠르게'
                    },
                    trigger: {
                        type: 'speech_analysis',
                        value: 'wpm_too_slow',
                        confidence: Math.min((80 - wpm) / 30, 1.0),
                        data: { currentWpm: wpm, threshold: 80 }
                    }
                };
            }
        }

        // 🎯 R1 & R2: 감정 분석 기반 피드백 (시나리오별)
        if (emotionAnalysis?.primaryEmotion) {
            const emotion = emotionAnalysis.primaryEmotion.emotionKr;
            const probability = emotionAnalysis.primaryEmotion.probability;

            // 면접 시나리오에서 긴장/불안 → L1 (경청 강화) 패턴
            if (scenario === 'interview' && (emotion === '불안' || emotion === '긴장') && probability > 0.7) {
                return {
                    type: 'emotion_anxiety',
                    priority: 'medium',
                    message: '긴장을 풀고 자신감 있게 말해보세요.',
                    visualCue: {
                        color: '#4ECDC4',
                        icon: 'relax',
                        text: '진정하기'
                    },
                    trigger: {
                        type: 'emotion_analysis',
                        value: 'anxiety_high',
                        confidence: probability,
                        data: { emotion, probability: Math.round(probability * 100), scenario }
                    }
                };
            }

            // 소개팅/일반 대화에서 무감정/지루함 → R2 (관심도 하락) 패턴
            if ((scenario === 'dating' || scenario === 'general') && 
                (emotion === '무감정' || emotion === '지루함') && probability > 0.6) {
                return {
                    type: 'emotion_lack_enthusiasm',
                    priority: 'high',
                    message: '좀 더 생기있게 대화해보세요.',
                    visualCue: {
                        color: '#FF6B9D',
                        icon: 'smile',
                        text: '활기차게'
                    },
                    trigger: {
                        type: 'emotion_analysis',
                        value: 'enthusiasm_low',
                        confidence: probability,
                        data: { emotion, probability: Math.round(probability * 100), scenario }
                    }
                };
            }

            // 긍정적 감정 → R1 (호감도 상승) 패턴
            if ((emotion === '기쁨' || emotion === '행복' || emotion === '만족') && probability > 0.7) {
                return {
                    type: 'emotion_positive',
                    priority: 'low',
                    message: '좋습니다! 긍정적인 분위기를 유지하세요.',
                    visualCue: {
                        color: '#4CAF50',
                        icon: 'favorite',
                        text: '좋아요!'
                    },
                    trigger: {
                        type: 'emotion_analysis',
                        value: 'positive_emotion',
                        confidence: probability,
                        data: { emotion, probability: Math.round(probability * 100) }
                    }
                };
            }
        }

        // 🎯 F1: 일시정지가 너무 많은 경우 → 주제 전환 제안
        if (speechMetrics?.pauseMetrics?.count > 5 && speechMetrics?.pauseMetrics?.averageDuration > 1.5) {
            return {
                type: 'speech_flow_pauses',
                priority: 'medium',
                message: '말하기가 끊어지고 있어요. 새로운 주제로 자연스럽게 넘어가보세요.',
                visualCue: {
                    color: '#45B7D1',
                    icon: 'change_circle',
                    text: '주제 전환'
                },
                trigger: {
                    type: 'speech_analysis',
                    value: 'too_many_pauses',
                    confidence: Math.min(speechMetrics.pauseMetrics.count / 10, 1.0),
                    data: { 
                        pauseCount: speechMetrics.pauseMetrics.count,
                        avgPauseDuration: speechMetrics.pauseMetrics.averageDuration.toFixed(1)
                    }
                }
            };
        }

        // 🎯 S2: 음량 문제 (추후 음량 데이터가 추가되면 구현 예정)
        // 🎯 F2: 침묵 관리 (추후 침묵 지속시간 데이터가 추가되면 구현 예정)
        // 🎯 L3: 질문 제안 (대화 맥락 분석을 통해 추후 구현 예정)

        // 특별한 피드백이 필요하지 않은 경우
        return null;

    } catch (error) {
        logger.error(`STT 분석 기반 피드백 결정 오류: ${error.message}`);
        return null;
    }
};

/**
 * 8개 MVP 햅틱 패턴 매핑 테이블
 */
const getHapticPatternMapping = () => {
    return {
        // 말하기 속도 관련
        'speaking_pace_fast': 'S1',       // 속도 조절 패턴
        'speaking_pace_slow': 'S1',       // 속도 조절 패턴 (같은 패턴, 메시지만 다름)
        
        // 감정/반응 관련
        'emotion_anxiety': 'L1',          // 경청 강화 패턴 (긴장 완화 효과)
        'emotion_lack_enthusiasm': 'R2',  // 관심도 하락 패턴 (경고)
        'emotion_positive': 'R1',         // 호감도 상승 패턴 (긍정 강화)
        
        // 대화 흐름 관련
        'speech_flow_pauses': 'F1',       // 주제 전환 패턴
        'silence_management': 'F2',       // 침묵 관리 패턴
        
        // 청자 행동 관련
        'listening_enhancement': 'L1',    // 경청 강화 패턴
        'question_suggestion': 'L3',      // 질문 제안 패턴
        
        // 음량 관련
        'volume_control': 'S2'            // 음량 조절 패턴
    };
};

/**
 * 8개 MVP 패턴 기반 햅틱 데이터 구성
 */
const constructHapticData = (patternId, intensity) => {
    const baseIntensity = Math.max(1, Math.min(10, intensity)); // 1-10 범위로 제한
    
    const patternConfigs = {
        'S1': { // 속도 조절 - 3회 강한 진동
            pattern: 'speed_control',
            intensity: baseIntensity,
            duration_ms: 3500, // 3.5초 (실제 Apple Watch 패턴 지속시간)
            vibration_count: 3,
            interval_ms: 800,
            description: '3회 강한 진동 (더블탭 패턴)'
        },
        'L1': { // 경청 강화 - 점진적 강도 증가
            pattern: 'listening_enhancement',
            intensity: baseIntensity,
            duration_ms: 4500, // 4.5초
            vibration_count: 4,
            interval_ms: 1000,
            description: '약함→중간→강함 (트리플탭 추가)'
        },
        'F1': { // 주제 전환 - 2회 긴 진동
            pattern: 'topic_change',
            intensity: baseIntensity,
            duration_ms: 3000, // 3초
            vibration_count: 2,
            interval_ms: 1500,
            description: '2회 긴 진동 (페이지 넘기기)'
        },
        'R1': { // 호감도 상승 - 4단계 행복감 폭발
            pattern: 'likability_up',
            intensity: baseIntensity,
            duration_ms: 3500, // 3.5초
            vibration_count: 4,
            interval_ms: 700,
            description: '4회 상승 파동 (행복감 폭발)'
        },
        'F2': { // 침묵 관리 - 부드러운 2회 탭
            pattern: 'silence_management',
            intensity: Math.max(1, baseIntensity - 2), // 더 부드럽게
            duration_ms: 2500, // 2.5초
            vibration_count: 2,
            interval_ms: 1200,
            description: '2회 부드러운 탭 (긴 간격)'
        },
        'S2': { // 음량 조절 - 극명한 강도 대비
            pattern: 'volume_control',
            intensity: baseIntensity,
            duration_ms: 4000, // 4초
            vibration_count: 4,
            interval_ms: 800,
            description: '극명한 강도 변화 (약함↔강함)'
        },
        'R2': { // 관심도 하락 - 7회 강한 경고
            pattern: 'interest_down',
            intensity: Math.min(10, baseIntensity + 2), // 더 강하게
            duration_ms: 3500, // 3.5초
            vibration_count: 7,
            interval_ms: 500,
            description: '7회 강한 경고 진동'
        },
        'L3': { // 질문 제안 - 물음표 패턴
            pattern: 'question_suggestion',
            intensity: baseIntensity,
            duration_ms: 4500, // 4.5초
            vibration_count: 4,
            interval_ms: [200, 200, 1500, 1000], // 가변 간격
            description: '짧음-짧음-긴휴지-긴진동-여운'
        }
    };

    const config = patternConfigs[patternId];
    if (!config) {
        // 기본 패턴
        return {
            pattern: 'default',
            intensity: baseIntensity,
            duration_ms: 1000,
            vibration_count: 1,
            description: '기본 진동'
        };
    }

    return config;
};

/**
 * 실시간 서비스로 햅틱 피드백 전송 (Redis Pub/Sub)
 */
const sendHapticFeedbackToRealtimeService = async (sessionId, feedback) => {
    try {
        const hapticCommand = {
            type: 'haptic_feedback',
            sessionId,
            feedback,
            timestamp: new Date().toISOString()
        };

        // Redis 채널로 실시간 서비스에 햅틱 명령 전송
        await redisClient.publish(
            `feedback:channel:${sessionId}`,
            JSON.stringify(hapticCommand)
        );

        logger.debug(`햅틱 피드백 실시간 서비스 전송 성공: ${sessionId}`, {
            feedbackId: feedback.id,
            patternId: feedback.pattern_id,
            type: feedback.type
        });

        return true;
    } catch (error) {
        logger.error(`햅틱 피드백 실시간 서비스 전송 실패: ${sessionId}`, {
            error: error.message,
            feedbackId: feedback.id
        });
        return false;
    }
};

module.exports = {
    generateFeedback,
    acknowledgeFeedback,
    processSTTAnalysisAndGenerateFeedback
};