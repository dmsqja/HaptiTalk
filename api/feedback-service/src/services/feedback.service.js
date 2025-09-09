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

    // 피드백 유형별 설정 및 메시지 (프론트엔드 동기화)
    const feedbackConfig = {
        speaking_pace: {
            patternId: 'D1',
            priority: 'high',
            message: '천천히 말해보세요',
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
            patternId: context.interest_level > 0.7 ? 'C1' : 'C2',
            priority: 'medium',
            message: context.interest_level > 0.7 ? '훌륭한 발표 자신감이에요!' : '더 자신감 있게 발표하세요!',
            visualCue: context.interest_level > 0.7 ? 'interest_high' : 'interest_low',
            trigger: {
                type: 'analysis_result',
                value: context.interest_level > 0.7 ? 'interest_increase' : 'interest_decrease',
                confidence: maxScore
            }
        },
        silence: {
            patternId: 'F1',
            priority: 'high',
            message: '"음", "어" 등을 줄여보세요',
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
        logger.info(`피드백 간격 체크 결과: ${userId}`, { shouldSendFeedback, minInterval: userSettings.minimum_interval_seconds });
        if (!shouldSendFeedback) {
            logger.info(`피드백 생성 스킵 - 최소 간격 미충족: ${userId}`);
            return null;
        }

        // 3. STT 분석 결과 기반 피드백 결정 (8개 MVP 패턴 활용)
        logger.info(`STT 분석 기반 피드백 결정 시작: ${userId}`, { wpm: speechMetrics?.evaluationWpm, scenario });
        const feedbackDecision = decideFeedbackFromSTTAnalysis({
            text,
            speechMetrics,
            emotionAnalysis,
            scenario,
            language,
            userSettings
        });

        logger.info(`피드백 결정 결과: ${userId}`, { decision: feedbackDecision ? feedbackDecision.type : null });
        if (!feedbackDecision) {
            logger.info(`피드백 생성 스킵 - 적절한 피드백 없음: ${userId}`);
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
 * STT 응답에서 confidence 점수 계산 - 리포트 서비스와 동일한 로직
 */
const calculateConfidenceFromSTT = (speechMetrics, text, words) => {
    if (!speechMetrics) {
        return 0.6; // 기본값
    }

    let totalScore = 0;
    let factorCount = 0;

    // 1. 말하기 속도 안정성 (30%) - 한국어 기준 개선
    if (speechMetrics.evaluation_wpm) {
        const wpm = speechMetrics.evaluation_wpm;
        // 한국어 적절한 속도: 100-180 WPM (기존 80-150에서 확장)
        let speedScore = 1.0;
        if (wpm < 100) {
            speedScore = Math.max(0.4, wpm / 100); // 너무 느리면 불안감
        } else if (wpm > 180) {
            speedScore = Math.max(0.3, 1 - (wpm - 180) / 120); // 너무 빠르면 초조함
        }
        totalScore += speedScore * 0.3;
        factorCount += 0.3;
    }

    // 2. 단어 확신도 (25%) - 음성 인식 정확도
    if (words && Array.isArray(words) && words.length > 0) {
        const probabilities = words
            .map(w => w.probability)
            .filter(p => typeof p === 'number' && p >= 0 && p <= 1);

        if (probabilities.length > 0) {
            const avgProbability = probabilities.reduce((sum, p) => sum + p, 0) / probabilities.length;
            totalScore += avgProbability * 0.25;
            factorCount += 0.25;
        }
    }

    // 3. 멈춤 패턴 (20%) - 자연스러운 호흡과 사고
    if (speechMetrics.pause_metrics) {
        const pauseRatio = speechMetrics.pause_metrics.pause_ratio || 0;
        // 적절한 멈춤(0.1-0.25)일 때 높은 점수 (기존보다 범위 확장)
        const pauseScore = pauseRatio >= 0.1 && pauseRatio <= 0.25 ? 1.0 : 
            Math.max(0, 1 - Math.abs(pauseRatio - 0.175) * 4);
        totalScore += pauseScore * 0.2;
        factorCount += 0.2;
    }

    // 4. 음성 패턴 정상성 (15%)
    if (speechMetrics.speech_pattern) {
        const patternScore = speechMetrics.speech_pattern === 'normal' ? 1.0 : 
                           speechMetrics.speech_pattern === 'steady' ? 0.9 : 0.6;
        totalScore += patternScore * 0.15;
        factorCount += 0.15;
    }

    // 5. 발화 연속성 (10%)
    if (speechMetrics.speed_category) {
        const categoryScore = speechMetrics.speed_category === 'normal' ? 1.0 : 
                            speechMetrics.speed_category === 'steady' ? 0.9 : 0.7;
        totalScore += categoryScore * 0.1;
        factorCount += 0.1;
    }

    // 가중평균 계산
    const confidenceScore = factorCount > 0 ? totalScore / factorCount : 0.6;
    return Math.max(0.2, Math.min(1.0, confidenceScore));
};

/**
 * 설득력 계산 - 새로 추가된 타당한 계산법
 */
const calculatePersuasionFromSTT = (speechMetrics, text, words) => {
    if (!speechMetrics || !text) {
        return 0.65; // 기본값
    }

    let totalScore = 0;
    let factorCount = 0;

    // 1. 논리적 구조 키워드 (35%)
    const structureWords = ['첫째', '둘째', '셋째', '마지막으로', '결론적으로', '요약하면', '핵심은', '중요한'];
    const structureCount = structureWords.reduce((count, word) => {
        const regex = new RegExp(word, 'g');
        const matches = text.match(regex);
        return count + (matches ? matches.length : 0);
    }, 0);
    const structureScore = Math.min(1.0, structureCount / 3); // 3개 이상이면 만점
    totalScore += structureScore * 0.35;
    factorCount += 0.35;

    // 2. 설득 키워드 (30%)
    const persuasionWords = ['장점', '이익', '효과', '결과', '성과', '가치', '개선', '해결', '도움'];
    const persuasionCount = persuasionWords.reduce((count, word) => {
        const regex = new RegExp(word, 'g');
        const matches = text.match(regex);
        return count + (matches ? matches.length : 0);
    }, 0);
    const persuasionKeywordScore = Math.min(1.0, persuasionCount / 4); // 4개 이상이면 만점
    totalScore += persuasionKeywordScore * 0.3;
    factorCount += 0.3;

    // 3. 말하기 일관성 (20%) - 설득력은 일관된 전달이 중요
    if (speechMetrics.wpm_cv) {
        const consistencyScore = Math.max(0, 1 - speechMetrics.wpm_cv); // 변동계수가 낮을수록 좋음
        totalScore += consistencyScore * 0.2;
        factorCount += 0.2;
    }

    // 4. 적절한 발화 속도 (15%) - 설득력에는 안정적인 속도가 중요
    if (speechMetrics.evaluation_wpm) {
        const wpm = speechMetrics.evaluation_wpm;
        const speedScore = wpm >= 110 && wpm <= 160 ? 1.0 : // 설득에 적합한 속도
                         wpm >= 90 && wpm <= 180 ? 0.8 : 0.6;
        totalScore += speedScore * 0.15;
        factorCount += 0.15;
    }

    // 가중평균 계산
    const persuasionScore = factorCount > 0 ? totalScore / factorCount : 0.65;
    return Math.max(0.3, Math.min(1.0, persuasionScore));
};

/**
 * 명확성 계산 - 새로 추가된 타당한 계산법
 */
const calculateClarityFromSTT = (speechMetrics, text, words) => {
    if (!speechMetrics || !text) {
        return 0.7; // 기본값
    }

    let totalScore = 0;
    let factorCount = 0;

    // 1. 단어 확신도 (30%) - 명확한 발음일수록 인식률 높음
    if (words && Array.isArray(words) && words.length > 0) {
        const probabilities = words
            .map(w => w.probability)
            .filter(p => typeof p === 'number' && p >= 0 && p <= 1);

        if (probabilities.length > 0) {
            const avgProbability = probabilities.reduce((sum, p) => sum + p, 0) / probabilities.length;
            totalScore += avgProbability * 0.3;
            factorCount += 0.3;
        }
    }

    // 2. 멈춤의 적절성 (25%) - 명확성에는 적절한 휴지가 중요
    if (speechMetrics.pause_metrics) {
        const pauseRatio = speechMetrics.pause_metrics.pause_ratio || 0;
        const avgPauseDuration = speechMetrics.pause_metrics.average_duration || 0;
        
        // 적절한 멈춤 비율 (0.1-0.2)과 적절한 길이 (0.3-1.0초)
        const ratioScore = pauseRatio >= 0.1 && pauseRatio <= 0.2 ? 1.0 : 
                          Math.max(0, 1 - Math.abs(pauseRatio - 0.15) * 5);
        const durationScore = avgPauseDuration >= 0.3 && avgPauseDuration <= 1.0 ? 1.0 :
                             Math.max(0, 1 - Math.abs(avgPauseDuration - 0.65) * 2);
        
        const pauseScore = (ratioScore + durationScore) / 2;
        totalScore += pauseScore * 0.25;
        factorCount += 0.25;
    }

    // 3. 말하기 속도 (20%) - 명확성에는 적당한 속도가 중요
    if (speechMetrics.evaluation_wpm) {
        const wpm = speechMetrics.evaluation_wpm;
        // 명확성에 최적인 속도: 100-150 WPM
        const speedScore = wpm >= 100 && wpm <= 150 ? 1.0 :
                         wpm >= 80 && wpm <= 170 ? 0.8 : 0.6;
        totalScore += speedScore * 0.2;
        factorCount += 0.2;
    }

    // 4. 필러워드 비율 (15%) - 명확성에는 필러워드가 적어야 함
    if (text) {
        const fillerWords = ['음', '어', '아', '그', '뭐', '좀'];
        const textWords = text.split(/\s+/).filter(word => word.length > 0);
        let fillerCount = 0;
        
        fillerWords.forEach(filler => {
            const regex = new RegExp(filler, 'g');
            const matches = text.match(regex);
            if (matches) fillerCount += matches.length;
        });
        
        const fillerRatio = textWords.length > 0 ? fillerCount / textWords.length : 0;
        const fillerScore = Math.max(0, 1 - fillerRatio * 5); // 필러워드가 적을수록 좋음
        totalScore += fillerScore * 0.15;
        factorCount += 0.15;
    }

    // 5. 음성 패턴 (10%)
    if (speechMetrics.speech_pattern) {
        const patternScore = speechMetrics.speech_pattern === 'normal' ? 1.0 : 
                           speechMetrics.speech_pattern === 'steady' ? 0.9 : 0.6;
        totalScore += patternScore * 0.1;
        factorCount += 0.1;
    }

    // 가중평균 계산
    const clarityScore = factorCount > 0 ? totalScore / factorCount : 0.7;
    return Math.max(0.3, Math.min(1.0, clarityScore));
};

/**
 * words 배열의 probability 평균으로 별도 confidence 계산
 */
const calculateConfidenceFromWords = (words) => {
    if (!words || !Array.isArray(words) || words.length === 0) {
        return 0.6; // 기본값
    }

    const probabilities = words
        .map(w => w.probability)
        .filter(p => typeof p === 'number' && p >= 0 && p <= 1);

    if (probabilities.length === 0) {
        return 0.6;
    }

    const averageProbability = probabilities.reduce((sum, p) => sum + p, 0) / probabilities.length;
    return Math.max(0, Math.min(1, averageProbability));
};

/**
 * STT 분석 결과를 기반으로 피드백 결정 (새로운 패턴 시스템)
 */
const decideFeedbackFromSTTAnalysis = ({ text, speechMetrics, emotionAnalysis, scenario, language, userSettings }) => {
    try {
        // 디버깅: 전달받은 데이터 전체 확인
        logger.info('⚡ 함수 호출 매개변수 확인:', {
            hasText: !!text,
            textLength: text?.length,
            hasSpeechMetrics: !!speechMetrics,
            speechMetrics: speechMetrics,
            hasEmotionAnalysis: !!emotionAnalysis,
            scenario,
            language
        });

        // 통합된 3개 지표 계산 (STT 응답 기반)
        const calculatedConfidence = calculateConfidenceFromSTT(speechMetrics, text, speechMetrics?.words);
        const calculatedPersuasion = calculatePersuasionFromSTT(speechMetrics, text, speechMetrics?.words);
        const calculatedClarity = calculateClarityFromSTT(speechMetrics, text, speechMetrics?.words);
        
        // 최종 자신감은 기존 로직 유지 (words confidence 조합)
        const wordsConfidence = calculateConfidenceFromWords(speechMetrics?.words);
        const finalConfidence = (calculatedConfidence * 0.7 + wordsConfidence * 0.3); // 가중평균

        logger.info('피드백 결정 분석 시작 (3개 지표):', {
            wpm: speechMetrics?.evaluation_wpm,
            confidence: Math.round(finalConfidence * 100),
            persuasion: Math.round(calculatedPersuasion * 100),
            clarity: Math.round(calculatedClarity * 100),
            emotion: emotionAnalysis?.primaryEmotion?.emotionKr,
            scenario,
            textLength: text?.length
        });

        // 🚀 D1: 말하기 속도 피드백 (빠른 속도 130 WPM 이상)
        if (speechMetrics?.evaluation_wpm) {
            const wpm = speechMetrics.evaluation_wpm;
            logger.info('말하기 속도 분석:', { wpm, threshold: 130 });

            if (wpm > 130) {
                logger.info('⚡ D1 패턴: 빠른 말하기 속도 피드백 생성', { wpm, threshold: 130 });
                return {
                    type: 'D1_speed_fast',
                    priority: 'high',
                    message: '🐌 천천히 말해보세요',
                    visualCue: {
                        color: '#FF9800',
                        icon: 'speed_down',
                        text: '속도 조절'
                    },
                    trigger: {
                        type: 'speech_analysis',
                        value: 'speaking_pace_too_fast',
                        confidence: Math.min(1.0, (wpm - 130) / 70),
                        data: { wpm, threshold: 130, scenario, pattern: 'D1' }
                    }
                };
            }
        } else {
            logger.warn('⚠️ speechMetrics.evaluation_wpm이 없음:', { speechMetrics });
        }

        // 💼 C1: 높은 확신도 피드백 (0.8 이상) 또는 설득력/명확성 우수
        const hasExcellentPerformance = finalConfidence > 0.8 ||
                                      (scenario === 'presentation' && (calculatedPersuasion > 0.8 || calculatedClarity > 0.8)) ||
                                      (scenario === 'interview' && calculatedClarity > 0.8);
                                      
        if (hasExcellentPerformance) {
            let messages = [];
            let achievement = '';
            
            // 가장 높은 지표를 기준으로 메시지 결정
            if (finalConfidence > 0.8) {
                achievement = 'confidence_excellent';
                messages = scenario === 'interview' 
                    ? ['💼 확신감 있는 답변이에요!', '✨ 자신감이 느껴져요!', '🎯 명확한 답변이네요!']
                    : scenario === 'presentation'
                    ? ['🚀 훌륭한 발표 자신감이에요!', '💪 당당한 발표네요!', '⭐ 확신에 찬 발표예요!']
                    : ['💯 자신감 넘치는 말투예요!', '🌟 확신감이 느껴져요!'];
            } else if (scenario === 'presentation' && calculatedPersuasion > 0.8) {
                achievement = 'persuasion_excellent';
                messages = ['🏆 매우 설득력 있는 발표예요!', '💎 탁월한 논리적 구성이네요!', '🎯 강력한 메시지 전달!'];
            } else if (calculatedClarity > 0.8) {
                achievement = 'clarity_excellent';
                messages = scenario === 'presentation' 
                    ? ['🔍 매우 명확한 발표예요!', '📝 완벽한 구조화!', '💡 이해하기 쉬운 설명!']
                    : ['🔍 매우 명확한 답변이에요!', '📝 잘 정리된 설명!', '💡 이해하기 쉬워요!'];
            }
                
            logger.info('💼 C1 패턴: 우수 성과 피드백 생성', { 
                finalConfidence: Math.round(finalConfidence * 100), 
                persuasion: Math.round(calculatedPersuasion * 100),
                clarity: Math.round(calculatedClarity * 100),
                achievement, 
                scenario 
            });
            
            return {
                type: 'C1_confidence_high',
                priority: 'low',
                message: messages[Math.floor(Math.random() * messages.length)],
                visualCue: {
                    color: '#4CAF50',
                    icon: 'trending_up',
                    text: achievement === 'confidence_excellent' ? '자신감 우수' : 
                          achievement === 'persuasion_excellent' ? '설득력 우수' : '명확성 우수'
                },
                trigger: {
                    type: 'excellence_analysis',
                    value: achievement,
                    confidence: finalConfidence,
                    data: { 
                        confidenceLevel: Math.round(finalConfidence * 100),
                        persuasionLevel: Math.round(calculatedPersuasion * 100),
                        clarityLevel: Math.round(calculatedClarity * 100),
                        primaryStrength: achievement,
                        calculatedFrom: 'stt_comprehensive_metrics',
                        scenario,
                        pattern: 'C1'
                    }
                }
            };
        }

        // 💪 C2: 낮은 확신도 피드백 (0.4 미만) 또는 설득력/명확성 부족
        const needsC2Feedback = finalConfidence < 0.4 || 
                               (scenario === 'presentation' && (calculatedPersuasion < 0.4 || calculatedClarity < 0.4)) ||
                               (scenario === 'interview' && calculatedClarity < 0.4);
                               
        if (needsC2Feedback) {
            let messages = [];
            let reason = '';
            
            // 가장 낮은 지표를 기준으로 메시지 결정
            if (finalConfidence < 0.4) {
                reason = 'confidence_low';
                messages = scenario === 'interview'
                    ? ['💪 더 자신감 있게 답변하세요!', '🔥 당당하게 말해보세요!', '✊ 확신을 가지세요!']
                    : scenario === 'presentation'
                    ? ['💪 더 자신감 있게 발표하세요!', '🎯 당당한 자세로!', '⚡ 확신감을 보여주세요!']
                    : ['💪 더 자신감 있게 말해보세요!', '🌟 당당하게 표현하세요!'];
            } else if (scenario === 'presentation' && calculatedPersuasion < 0.4) {
                reason = 'persuasion_low';
                messages = ['📢 더 설득력 있게 발표하세요!', '🎯 핵심 장점을 강조해보세요!', '💎 가치를 더 어필하세요!'];
            } else if (calculatedClarity < 0.4) {
                reason = 'clarity_low';
                messages = scenario === 'presentation' 
                    ? ['🎤 더 명확하게 발표하세요!', '📝 핵심 포인트를 정리해보세요!', '🔍 구조화해서 말해보세요!']
                    : ['🎤 더 명확하게 답변하세요!', '📝 요점을 정리해서 말해보세요!', '🔍 차근차근 설명해보세요!'];
            }
                
            logger.info('💪 C2 패턴: 자신감/설득력/명확성 개선 피드백 생성', { 
                finalConfidence: Math.round(finalConfidence * 100), 
                persuasion: Math.round(calculatedPersuasion * 100),
                clarity: Math.round(calculatedClarity * 100),
                reason, 
                scenario 
            });
            
            return {
                type: 'C2_confidence_low',
                priority: 'high',
                message: messages[Math.floor(Math.random() * messages.length)],
                visualCue: {
                    color: '#FF9800',
                    icon: 'trending_down',
                    text: reason === 'confidence_low' ? '자신감 필요' : 
                          reason === 'persuasion_low' ? '설득력 개선' : '명확성 개선'
                },
                trigger: {
                    type: 'comprehensive_analysis',
                    value: reason,
                    confidence: finalConfidence,
                    data: { 
                        confidenceLevel: Math.round(finalConfidence * 100),
                        persuasionLevel: Math.round(calculatedPersuasion * 100),
                        clarityLevel: Math.round(calculatedClarity * 100),
                        primaryIssue: reason,
                        calculatedFrom: 'stt_comprehensive_metrics',
                        scenario,
                        pattern: 'C2'
                    }
                }
            };
        }

        // 🎯 F1: 채움어 감지 피드백 (15% 이상)
        if (text) {
            const fillerWords = ['음', '어', '아', '그', '뭐', '좀', '그런', '이제', '근데', '그니까'];
            const textWords = text.split(/\s+/).filter(word => word.length > 0);
            let fillerCount = 0;
            
            fillerWords.forEach(filler => {
                const regex = new RegExp(filler, 'g');
                const matches = text.match(regex);
                if (matches) fillerCount += matches.length;
            });
            
            const wordsCount = textWords.length;
            const fillerRatio = wordsCount > 0 ? fillerCount / wordsCount : 0;

            logger.info('채움어 분석:', { 
                fillerCount, 
                wordsCount, 
                fillerRatio: Math.round(fillerRatio * 100) + '%',
                threshold: '15%'
            });

            // 채움어 비율이 15% 이상인 경우
            if (fillerRatio > 0.15 && fillerCount >= 2) {
                logger.info('🎯 F1 패턴: 채움어 피드백 생성', { 
                    fillerCount, 
                    fillerRatio: Math.round(fillerRatio * 100), 
                    wordsCount 
                });
                return {
                    type: 'F1_filler_words',
                    priority: 'medium',
                    message: '🎯 "음", "어" 줄여보세요',
                    visualCue: {
                        color: '#9C27B0',
                        icon: 'voice_chat',
                        text: '말하기 개선'
                    },
                    trigger: {
                        type: 'filler_analysis',
                        value: 'filler_words_high',
                        confidence: Math.min(1.0, fillerRatio * 2),
                        data: { 
                            fillerCount, 
                            fillerRatio: Math.round(fillerRatio * 100),
                            wordsCount,
                            scenario,
                            pattern: 'F1'
                        }
                    }
                };
            }
        }

        // 어떤 패턴도 해당되지 않는 경우
        logger.info('📊 분석 완료 - 피드백 필요 없음', {
            wpm: speechMetrics?.evaluation_wpm,
            confidence: Math.round((finalConfidence || 0) * 100),
            persuasion: Math.round((calculatedPersuasion || 0) * 100),
            clarity: Math.round((calculatedClarity || 0) * 100),
            scenario,
            reason: 'no_pattern_matched',
            thresholds: {
                speedThreshold: 130,
                confidenceHigh: 80,
                confidenceLow: 40,
                fillerThreshold: 15
            }
        });

        return null; // 피드백 없음
    } catch (error) {
        logger.error('피드백 결정 중 오류 발생:', error);
        return null;
    }
};

/**
 * 피드백 타입과 햅틱 패턴 ID 매핑
 */
const getHapticPatternMapping = () => {
    return {
        // === 새로운 프론트엔드 동기화 패턴 (D1, C1, C2, F1) ===
        'D1_speed_fast': 'D1',            // 속도 조절 패턴 (빠름)
        'C1_confidence_high': 'C1',       // 자신감 상승 패턴
        'C2_confidence_low': 'C2',        // 자신감 하락 패턴
        'F1_filler_words': 'F1',          // 채움어 감지 패턴
        
        // === 직접 패턴 매핑 (하위 호환성) ===
        'D1': 'D1',       // 속도 조절 패턴 (빠름)
        'C1': 'C1',       // 자신감 상승 패턴
        'C2': 'C2',       // 자신감 하락 패턴
        'F1': 'F1',       // 채움어 감지 패턴
        
        // === 기존 패턴 (하위 호환성 유지) ===
        // 말하기 속도 관련
        'speaking_pace': 'D1',            // 통합된 속도 조절 패턴
        'speaking_pace_fast': 'D1',       // 빠른 속도
        'speaking_pace_slow': 'D1',       // 느린 속도
        
        // 감정/반응 관련  
        'emotion_anxiety': 'C2',          // 긴장/불안 → 자신감 하락으로 매핑
        'emotion_lack_enthusiasm': 'C2',  // 무감정/지루함 → 자신감 하락으로 매핑
        'emotion_positive': 'C1',         // 긍정적 감정 → 자신감 상승으로 매핑
        'confidence_up': 'C1',            // 기존 자신감 상승 패턴
        'confidence_down': 'C2',          // 기존 자신감 하락 패턴
        
        // 대화 흐름 관련
        'speech_flow_pauses': 'F1',       // 일시정지 많음 → 채움어로 재분류
        'filler_words': 'F1',             // 기존 채움어 패턴
        'silence_management': 'F3',       // 침묵 관리 패턴 (기존 유지)
        
        // 청자 행동 관련 (기존 패턴 유지)
        'listening_enhancement': 'L1',    // 경청 강화 패턴
        'question_suggestion': 'L3',      // 질문 제안 패턴
        
        // 음량 관련 (기존 패턴 유지)
        'volume_control': 'S2'            // 음량 조절 패턴
    };
};

/**
 * 8개 MVP 패턴 기반 햅틱 데이터 구성
 */
const constructHapticData = (patternId, intensity) => {
    const baseIntensity = Math.max(1, Math.min(10, intensity)); // 1-10 범위로 제한
    
    const patternConfigs = {
        // === 새로운 프론트엔드 동기화 패턴 ===
        'D1': { // 속도 조절 - 3회 강한 진동 (빠름/느림)
            pattern: 'speed_control',
            intensity: baseIntensity,
            duration_ms: 3500, // 3.5초
            vibration_count: 3,
            interval_ms: 800,
            description: '3회 강한 진동 (속도 조절)'
        },
        'C1': { // 자신감 상승 - 상승하는 파동
            pattern: 'confidence_up',
            intensity: baseIntensity,
            duration_ms: 3000, // 3초
            vibration_count: 4,
            interval_ms: 600,
            description: '상승하는 파동 (자신감 증진)'
        },
        'C2': { // 자신감 하락 - 하강하는 파동
            pattern: 'confidence_down',
            intensity: Math.max(1, baseIntensity - 1), // 약간 부드럽게
            duration_ms: 2500, // 2.5초
            vibration_count: 3,
            interval_ms: 700,
            description: '하강하는 파동 (자신감 회복 필요)'
        },
        'F1': { // 채움어 - 2회 짧은 탭
            pattern: 'filler_words',
            intensity: baseIntensity,
            duration_ms: 2000, // 2초
            vibration_count: 2,
            interval_ms: 500,
            description: '2회 짧은 탭 (채움어 줄이기)'
        },
        
        // === 기존 패턴 (하위 호환성 유지) ===
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
        'F2': { // 주제 전환 - 2회 긴 진동
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
        'F3': { // 침묵 관리 - 부드러운 2회 탭
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