/**
 * 피드백 서비스의 Kafka 관리 모듈
 */
const { createKafkaClient } = require('../api/shared/kafka-client');
const logger = require('../utils/logger');

// Kafka 클라이언트 생성
const kafkaClient = createKafkaClient({
  clientId: process.env.SERVICE_NAME || 'feedback-service',
  logger
});

// 구독할 토픽 정의
const TOPICS = {
  FEEDBACK_EVENTS: process.env.KAFKA_TOPIC_FEEDBACK_EVENTS || 'haptitalk-feedback-events',
  SESSION_EVENTS: process.env.KAFKA_TOPIC_SESSION_EVENTS || 'haptitalk-session-events',
  FEEDBACK_ANALYTICS: process.env.KAFKA_TOPIC_FEEDBACK_ANALYTICS || 'haptitalk-feedback-analytics'
};

/**
 * 햅틱 피드백 전송 이벤트 발행
 * @param {Object} feedback 피드백 데이터
 */
const publishFeedbackSent = async (feedback) => {
  try {
    await initProducerIfNeeded();
    
    const message = {
      feedbackId: feedback.id,
      userId: feedback.userId,
      sessionId: feedback.sessionId,
      action: 'SENT',
      timestamp: new Date().toISOString(),
      data: {
        patternId: feedback.patternId,
        intensity: feedback.intensity,
        reason: feedback.reason,
        context: feedback.context
      }
    };
    
    // sessionId를 키로 사용하여 같은 세션의 메시지가 같은 파티션에 전송되도록 함
    await kafkaClient.sendMessage(TOPICS.FEEDBACK_EVENTS, message, feedback.sessionId);
    
    logger.info(`피드백 전송 이벤트 발행 성공: ${feedback.id}`, {
      feedbackId: feedback.id,
      userId: feedback.userId,
      sessionId: feedback.sessionId,
      patternId: feedback.patternId,
      topic: TOPICS.FEEDBACK_EVENTS
    });
    
    return true;
  } catch (error) {
    logger.error(`피드백 전송 이벤트 발행 실패: ${feedback.id}`, {
      error: error.message,
      stack: error.stack,
      component: 'kafka'
    });
    return false;
  }
};

/**
 * 피드백 확인(acknowledge) 이벤트 발행
 * @param {string} feedbackId 피드백 ID
 * @param {Object} data 확인 데이터
 */
const publishFeedbackAcknowledged = async (feedbackId, data) => {
  try {
    await initProducerIfNeeded();
    
    const message = {
      feedbackId,
      userId: data.userId,
      sessionId: data.sessionId,
      action: 'ACKNOWLEDGED',
      timestamp: new Date().toISOString(),
      data: {
        deviceId: data.deviceId,
        acknowledgedAt: data.acknowledgedAt || new Date().toISOString(),
        userResponse: data.userResponse
      }
    };
    
    await kafkaClient.sendMessage(TOPICS.FEEDBACK_EVENTS, message, data.sessionId);
    
    logger.info(`피드백 확인 이벤트 발행 성공: ${feedbackId}`, {
      feedbackId,
      userId: data.userId,
      sessionId: data.sessionId,
      deviceId: data.deviceId,
      topic: TOPICS.FEEDBACK_EVENTS
    });
    
    return true;
  } catch (error) {
    logger.error(`피드백 확인 이벤트 발행 실패: ${feedbackId}`, {
      error: error.message,
      stack: error.stack,
      component: 'kafka'
    });
    return false;
  }
};

/**
 * 피드백 분석 이벤트 발행
 * @param {string} sessionId 세션 ID
 * @param {Object} analysisData 분석 데이터
 */
const publishFeedbackAnalytics = async (sessionId, analysisData) => {
  try {
    await initProducerIfNeeded();
    
    const message = {
      sessionId,
      userId: analysisData.userId,
      action: 'ANALYTICS',
      timestamp: new Date().toISOString(),
      data: {
        feedbackCount: analysisData.feedbackCount,
        acknowledgementRate: analysisData.acknowledgementRate,
        averageResponseTime: analysisData.averageResponseTime,
        patterns: analysisData.patterns,
        effectiveness: analysisData.effectiveness
      }
    };
    
    await kafkaClient.sendMessage(TOPICS.FEEDBACK_ANALYTICS, message, sessionId);
    
    logger.info(`피드백 분석 이벤트 발행 성공: ${sessionId}`, {
      sessionId,
      userId: analysisData.userId,
      feedbackCount: analysisData.feedbackCount,
      acknowledgementRate: analysisData.acknowledgementRate,
      topic: TOPICS.FEEDBACK_ANALYTICS
    });
    
    return true;
  } catch (error) {
    logger.error(`피드백 분석 이벤트 발행 실패: ${sessionId}`, {
      error: error.message,
      stack: error.stack,
      component: 'kafka'
    });
    return false;
  }
};

/**
 * 세션 이벤트 구독 및 처리
 * @param {Function} handleSessionStart 세션 시작 처리 함수
 * @param {Function} handleSessionEnd 세션 종료 처리 함수
 */
const subscribeToSessionEvents = async (handleSessionStart, handleSessionEnd) => {
  try {
    await kafkaClient.initConsumer({
      groupId: 'feedback-service-session-events',
      topics: [TOPICS.SESSION_EVENTS]
    }, async (message) => {
      try {
        const { value } = message;
        
        if (!value || !value.action || !value.sessionId) {
          logger.warn('유효하지 않은 세션 이벤트 메시지', { component: 'kafka' });
          return;
        }
        
        logger.debug(`세션 이벤트 수신: ${value.action} - ${value.sessionId}`, { component: 'kafka' });
        
        switch (value.action) {
          case 'CREATED':
          case 'UPDATED':
            if (value.data && value.data.status === 'ACTIVE' && handleSessionStart) {
              await handleSessionStart(value.sessionId, value.userId, value);
              logger.info(`세션 시작 이벤트 처리 성공: ${value.sessionId}`, {
                sessionId: value.sessionId,
                userId: value.userId,
                action: value.action
              });
            }
            break;
            
          case 'ENDED':
            if (handleSessionEnd) {
              await handleSessionEnd(value.sessionId, value.userId, value);
              logger.info(`세션 종료 이벤트 처리 성공: ${value.sessionId}`, {
                sessionId: value.sessionId,
                userId: value.userId,
                action: value.action
              });
            }
            break;
            
          default:
            logger.debug(`처리되지 않은 세션 이벤트 액션: ${value.action}`, { component: 'kafka' });
        }
      } catch (error) {
        logger.error('세션 이벤트 처리 오류', {
          error: error.message,
          stack: error.stack,
          component: 'kafka'
        });
      }
    });
    
    logger.info('세션 이벤트 구독 시작됨', { 
      component: 'kafka',
      topic: TOPICS.SESSION_EVENTS,
      groupId: 'feedback-service-session-events'
    });
    return true;
  } catch (error) {
    logger.error('세션 이벤트 구독 실패', {
      error: error.message,
      stack: error.stack,
      component: 'kafka'
    });
    return false;
  }
};

/**
 * 프로듀서 초기화 (필요한 경우에만)
 */
const initProducerIfNeeded = async () => {
  try {
    await kafkaClient.initProducer();
    return true;
  } catch (error) {
    logger.error('Kafka 프로듀서 초기화 실패', {
      error: error.message,
      stack: error.stack,
      component: 'kafka'
    });
    throw error;
  }
};

/**
 * Kafka 연결 종료
 */
const disconnect = async () => {
  try {
    await kafkaClient.disconnect();
    logger.info('Kafka 연결 종료 완료', { component: 'kafka' });
    return true;
  } catch (error) {
    logger.error('Kafka 연결 종료 실패', {
      error: error.message,
      stack: error.stack,
      component: 'kafka'
    });
    return false;
  }
};

module.exports = {
  publishFeedbackSent,
  publishFeedbackAcknowledged,
  publishFeedbackAnalytics,
  subscribeToSessionEvents,
  disconnect,
  TOPICS
}; 