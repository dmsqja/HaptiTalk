/**
 * 사용자 서비스의 Kafka 관리 모듈
 */
const { createKafkaClient } = require('../../api/shared/kafka-client');
const logger = require('../utils/logger');

// Kafka 클라이언트 생성
const kafkaClient = createKafkaClient({
  clientId: process.env.SERVICE_NAME || 'user-service',
  logger
});

// 구독할 토픽 정의
const TOPICS = {
  USER_ACTIVITY: process.env.KAFKA_TOPIC_USER_ACTIVITY || 'haptitalk-user-activity',
  USER_PREFERENCES: process.env.KAFKA_TOPIC_USER_PREFERENCES || 'haptitalk-user-preferences'
};

/**
 * 사용자 활동 이벤트 발행
 * @param {string} userId 사용자 ID
 * @param {string} action 활동 유형
 * @param {Object} data 추가 데이터
 */
const publishUserActivity = async (userId, action, data = {}) => {
  try {
    await initProducerIfNeeded();
    
    const message = {
      userId,
      action,
      data,
      timestamp: new Date().toISOString()
    };
    
    await kafkaClient.sendMessage(TOPICS.USER_ACTIVITY, message, userId);
    logger.debug(`사용자 활동 이벤트 발행 성공: ${action}`, {
      userId,
      action,
      component: 'kafka'
    });
    
    return true;
  } catch (error) {
    logger.error(`사용자 활동 이벤트 발행 실패: ${action}`, {
      userId,
      action,
      error: error.message,
      stack: error.stack,
      component: 'kafka'
    });
    return false;
  }
};

/**
 * 사용자 설정 변경 이벤트 발행
 * @param {string} userId 사용자 ID
 * @param {Object} preferences 변경된 설정
 */
const publishUserPreferencesUpdated = async (userId, preferences) => {
  try {
    await initProducerIfNeeded();
    
    const message = {
      userId,
      action: 'PREFERENCES_UPDATED',
      data: {
        preferences,
        updatedAt: new Date().toISOString()
      },
      timestamp: new Date().toISOString()
    };
    
    await kafkaClient.sendMessage(TOPICS.USER_PREFERENCES, message, userId);
    logger.debug(`사용자 설정 변경 이벤트 발행 성공`, {
      userId,
      component: 'kafka'
    });
    
    return true;
  } catch (error) {
    logger.error(`사용자 설정 변경 이벤트 발행 실패`, {
      userId,
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
  publishUserActivity,
  publishUserPreferencesUpdated,
  disconnect,
  TOPICS
}; 