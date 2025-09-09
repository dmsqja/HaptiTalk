/**
 * 하이브리드 메시징 시스템
 * Redis PubSub과 Kafka를 결합하여 메시지 지속성과 낮은 지연 시간 제공
 */

const logger = require('./logger');
const MessageBatcher = require('./message-batcher');
const { createKafkaClient } = require('../../api/shared/kafka-client');

// Kafka 클라이언트 생성
const kafkaClient = createKafkaClient({
  clientId: process.env.SERVICE_NAME || 'realtime-service',
  logger
});

class HybridMessaging {
  constructor(redisClient, io, options = {}) {
    // Redis 관련 설정
    this.redisClient = redisClient;
    this.io = io;
    this.subscriber = redisClient.duplicate();
    this.publisher = redisClient.duplicate();
    this.redisPatterns = new Map(); // Redis 패턴 구독
    this.redisChannels = new Map(); // Redis 채널 구독

    // Kafka 관련 설정
    this.kafkaTopics = new Map(); // Kafka 토픽 구독
    this.kafkaGroupId = options.kafkaGroupId || 'realtime-service';
    
    // 공통 설정
    this.retryAttempts = options.retryAttempts || 3;
    this.retryDelay = options.retryDelay || 1000;
    this.failedMessages = new Map();
    
    // 메시지 배치 처리기
    this.batcher = new MessageBatcher({
      batchSize: options.batchSize || 20,
      flushInterval: options.flushInterval || 50
    });
    
    // 재시도 처리용 타이머
    this.retryInterval = null;
  }

  /**
   * 초기화 및 시작
   */
  async start() {
    try {
      // Redis 연결 확인
      await this.subscriber.ping();
      await this.publisher.ping();
      
      // Kafka 프로듀서 초기화
      await kafkaClient.initProducer();
      
      // 메시지 배치 처리 시작
      this.batcher.start();
      
      // 재시도 처리 타이머 시작
      this.retryInterval = setInterval(() => {
        this.processFailedMessages();
      }, 5000); // 5초마다 실패 메시지 재처리
      
      logger.info('하이브리드 메시징 시스템이 시작되었습니다', { component: 'messaging' });

      // Redis 메시지 처리를 위한 이벤트 리스너 등록
      this.subscriber.on('message', (channel, message) => {
        this.handleRedisMessage(channel, channel, message);
      });

      this.subscriber.on('pmessage', (pattern, channel, message) => {
        this.handleRedisMessage(pattern, channel, message);
      });
      
      return true;
    } catch (error) {
      logger.error('하이브리드 메시징 시스템 시작 오류', {
        error: error.message,
        stack: error.stack,
        component: 'messaging'
      });
      throw error;
    }
  }

  /**
   * Redis 채널 구독
   * @param {string} channel 구독할 채널
   * @param {Function} handler 메시지 처리 핸들러
   */
  subscribeRedis(channel, handler) {
    if (channel.includes('*')) {
      this.redisPatterns.set(channel, handler);
      this.subscriber.psubscribe(channel);
      logger.debug(`Redis 패턴 구독 시작: ${channel}`, { component: 'messaging', type: 'redis' });
    } else {
      this.redisChannels.set(channel, handler);
      this.subscriber.subscribe(channel);
      logger.debug(`Redis 채널 구독 시작: ${channel}`, { component: 'messaging', type: 'redis' });
    }
  }

  /**
   * Kafka 토픽 구독
   * @param {string} topic 구독할 토픽
   * @param {Function} handler 메시지 처리 핸들러
   * @param {Object} options 추가 설정
   */
  async subscribeKafka(topic, handler, options = {}) {
    // 이미 등록된 토픽인 경우 핸들러만 업데이트
    if (this.kafkaTopics.has(topic)) {
      this.kafkaTopics.set(topic, handler);
      logger.debug(`기존 Kafka 토픽 핸들러 업데이트: ${topic}`, { component: 'messaging', type: 'kafka' });
      return;
    }

    this.kafkaTopics.set(topic, handler);
    
    // 컨슈머 그룹 ID 생성
    const groupId = options.groupId || `${this.kafkaGroupId}-${topic}`;
    
    try {
      // Kafka 컨슈머 초기화 및 메시지 처리 함수 등록
      await kafkaClient.initConsumer(
        {
          groupId,
          topics: [topic]
        },
        (message) => this.handleKafkaMessage(topic, message)
      );
      
      logger.info(`Kafka 토픽 구독 시작: ${topic}`, { 
        component: 'messaging', 
        type: 'kafka',
        groupId
      });
    } catch (error) {
      this.kafkaTopics.delete(topic);
      logger.error(`Kafka 토픽 구독 오류: ${topic}`, {
        error: error.message,
        stack: error.stack,
        component: 'messaging',
        type: 'kafka'
      });
      throw error;
    }
  }

  /**
   * Redis 채널 구독 해제
   * @param {string} channel 구독 해제할 채널
   */
  unsubscribeRedis(channel) {
    if (channel.includes('*')) {
      this.subscriber.punsubscribe(channel);
      this.redisPatterns.delete(channel);
      logger.debug(`Redis 패턴 구독 해제: ${channel}`, { component: 'messaging', type: 'redis' });
    } else {
      this.subscriber.unsubscribe(channel);
      this.redisChannels.delete(channel);
      logger.debug(`Redis 채널 구독 해제: ${channel}`, { component: 'messaging', type: 'redis' });
    }
  }

  /**
   * Kafka 토픽 구독 해제
   * @param {string} topic 구독 해제할 토픽
   * @param {string} groupId 컨슈머 그룹 ID (선택사항)
   */
  async unsubscribeKafka(topic, groupId = null) {
    this.kafkaTopics.delete(topic);
    
    // 공통 Kafka 클라이언트는 stopConsumer 대신 disconnect() 메서드를 사용합니다.
    // 현재 컨슈머 중지는 disconnect()를 통해 한번에 처리됩니다.
    logger.debug(`Kafka 토픽 구독 해제: ${topic}`, { 
      component: 'messaging', 
      type: 'kafka',
      groupId: groupId || `${this.kafkaGroupId}-${topic}`
    });
  }

  /**
   * Redis를 통한 메시지 발행
   * @param {string} channel 발행할 채널
   * @param {any} message 발행할 메시지
   * @returns {Promise<number>} 메시지를 받은 구독자 수
   */
  async publishRedis(channel, message) {
    try {
      const payload = typeof message === 'string' ? message : JSON.stringify(message);
      const subscribers = await this.publisher.publish(channel, payload);
      
      logger.debug(`Redis 메시지 발행: ${channel}`, { 
        component: 'messaging', 
        type: 'redis',
        subscribers 
      });
      return subscribers;
    } catch (error) {
      logger.error(`Redis 메시지 발행 오류: ${channel}`, {
        error: error.message,
        stack: error.stack,
        component: 'messaging',
        type: 'redis'
      });
      throw error;
    }
  }

  /**
   * Kafka를 통한 메시지 발행
   * @param {string} topic 발행할 토픽
   * @param {any} message 발행할 메시지
   * @param {string} key 메시지 키 (선택사항)
   * @param {Object} headers 메시지 헤더 (선택사항)
   * @returns {Promise<boolean>} 발행 성공 여부
   */
  async publishKafka(topic, message, key = null, headers = {}) {
    try {
      await kafkaClient.sendMessage(topic, message, key, headers);
      
      logger.debug(`Kafka 메시지 발행: ${topic}`, { 
        component: 'messaging', 
        type: 'kafka',
        key: key || 'none'
      });
      return true;
    } catch (error) {
      logger.error(`Kafka 메시지 발행 오류: ${topic}`, {
        error: error.message,
        stack: error.stack,
        component: 'messaging',
        type: 'kafka'
      });
      throw error;
    }
  }

  /**
   * Redis 메시지 처리
   * @param {string} pattern 구독한 패턴
   * @param {string} channel 실제 채널
   * @param {string} message 메시지 내용
   */
  handleRedisMessage(pattern, channel, message) {
    try {
      // 배치 처리를 위해 메시지 추가
      this.batcher.add(
        `redis:${channel}`,
        { type: 'redis', pattern, channel, message },
        (messages) => this.processBatch(messages)
      );
    } catch (error) {
      logger.error(`Redis 메시지 처리 오류: ${channel}`, {
        error: error.message,
        stack: error.stack,
        component: 'messaging',
        type: 'redis'
      });
      this.addFailedMessage('redis', pattern, channel, message);
    }
  }

  /**
   * Kafka 메시지 처리
   * @param {string} topic 토픽
   * @param {Object} kafkaMessage Kafka 메시지 객체
   */
  handleKafkaMessage(topic, kafkaMessage) {
    try {
      const { key, value, headers } = kafkaMessage;
      
      // 배치 처리를 위해 메시지 추가
      this.batcher.add(
        `kafka:${topic}`,
        { type: 'kafka', topic, key, value, headers },
        (messages) => this.processBatch(messages)
      );
    } catch (error) {
      logger.error(`Kafka 메시지 처리 오류: ${topic}`, {
        error: error.message,
        stack: error.stack,
        component: 'messaging',
        type: 'kafka'
      });
      this.addFailedMessage('kafka', null, topic, JSON.stringify(kafkaMessage.value));
    }
  }

  /**
   * 메시지 배치 처리
   * @param {Array} messages 처리할 메시지 배열
   */
  processBatch(messages) {
    if (!messages || messages.length === 0) return;
    
    // 채널/토픽별로 메시지 그룹화
    const redisMessages = new Map();
    const kafkaMessages = new Map();
    
    for (const msg of messages) {
      if (msg.type === 'redis') {
        if (!redisMessages.has(msg.channel)) {
          redisMessages.set(msg.channel, []);
        }
        
        let payload;
        try {
          payload = JSON.parse(msg.message);
        } catch {
          payload = msg.message; // JSON이 아닌 경우 그대로 사용
        }
        
        redisMessages.get(msg.channel).push(payload);
      } 
      else if (msg.type === 'kafka') {
        if (!kafkaMessages.has(msg.topic)) {
          kafkaMessages.set(msg.topic, []);
        }
        
        kafkaMessages.get(msg.topic).push(msg.value);
      }
    }
    
    // Redis 메시지 처리
    for (const [channel, payloads] of redisMessages.entries()) {
      // 일반 채널 처리
      if (this.redisChannels.has(channel)) {
        try {
          const handler = this.redisChannels.get(channel);
          handler(channel, payloads.length === 1 ? payloads[0] : payloads);
        } catch (error) {
          logger.error(`Redis 채널 메시지 처리 오류: ${channel}`, {
            error: error.message,
            stack: error.stack,
            component: 'messaging',
            type: 'redis'
          });
          
          // 실패 처리 (재시도 위해)
          for (const msg of messages.filter(m => m.type === 'redis' && m.channel === channel)) {
            this.addFailedMessage('redis', msg.pattern, msg.channel, msg.message);
          }
        }
      }
      
      // 패턴 매칭 처리
      for (const [pattern, handler] of this.redisPatterns.entries()) {
        if (this.matchPattern(pattern, channel)) {
          try {
            handler(channel, payloads.length === 1 ? payloads[0] : payloads);
          } catch (error) {
            logger.error(`Redis 패턴 메시지 처리 오류: 채널=${channel}, 패턴=${pattern}`, {
              error: error.message,
              stack: error.stack,
              component: 'messaging',
              type: 'redis'
            });
            
            // 실패 처리 (재시도 위해)
            for (const msg of messages.filter(m => m.type === 'redis' && m.channel === channel)) {
              this.addFailedMessage('redis', msg.pattern, msg.channel, msg.message);
            }
          }
        }
      }
    }
    
    // Kafka 메시지 처리
    for (const [topic, payloads] of kafkaMessages.entries()) {
      if (this.kafkaTopics.has(topic)) {
        try {
          const handler = this.kafkaTopics.get(topic);
          handler(topic, payloads.length === 1 ? payloads[0] : payloads);
        } catch (error) {
          logger.error(`Kafka 토픽 메시지 처리 오류: ${topic}`, {
            error: error.message,
            stack: error.stack,
            component: 'messaging',
            type: 'kafka'
          });
          
          // 실패 처리 (재시도 위해)
          for (const msg of messages.filter(m => m.type === 'kafka' && m.topic === topic)) {
            this.addFailedMessage('kafka', null, msg.topic, JSON.stringify(msg.value));
          }
        }
      }
    }
  }

  /**
   * Redis 패턴 일치 여부 확인
   * @param {string} pattern 패턴
   * @param {string} channel 채널
   * @returns {boolean} 일치 여부
   */
  matchPattern(pattern, channel) {
    const regexPattern = pattern
      .replace(/\*/g, '.*')
      .replace(/\?/g, '.')
      .replace(/\[/g, '[')
      .replace(/\]/g, ']');
    
    const regex = new RegExp(`^${regexPattern}$`);
    return regex.test(channel);
  }

  /**
   * 실패한 메시지 추가
   * @param {string} type 메시지 유형 ('redis' 또는 'kafka')
   * @param {string} pattern Redis 패턴 (Redis인 경우만)
   * @param {string} channelOrTopic 채널 또는 토픽
   * @param {string} message 메시지 내용
   */
  addFailedMessage(type, pattern, channelOrTopic, message) {
    const id = `${type}:${channelOrTopic}:${Date.now()}:${Math.random().toString(36).substring(2, 15)}`;
    
    this.failedMessages.set(id, {
      type,
      pattern,
      channelOrTopic,
      message,
      attempts: 0,
      lastAttempt: Date.now(),
      nextAttempt: Date.now() + this.retryDelay
    });
  }

  /**
   * 실패한 메시지 재처리
   */
  processFailedMessages() {
    const now = Date.now();
    const toDelete = [];
    
    for (const [id, msg] of this.failedMessages.entries()) {
      if (now >= msg.nextAttempt) {
        if (msg.attempts < this.retryAttempts) {
          try {
            let payload = msg.message;
            try {
              payload = JSON.parse(msg.message);
            } catch {
              // 이미 문자열인 경우 그대로 사용
            }
            
            if (msg.type === 'redis') {
              // Redis 메시지 재처리
              const channel = msg.channelOrTopic;
              
              // 일반 채널 처리
              if (this.redisChannels.has(channel)) {
                const handler = this.redisChannels.get(channel);
                handler(channel, payload);
                toDelete.push(id);
              }
              // 패턴 매칭 처리
              else {
                let processed = false;
                for (const [pattern, handler] of this.redisPatterns.entries()) {
                  if (this.matchPattern(pattern, channel)) {
                    handler(channel, payload);
                    processed = true;
                    toDelete.push(id);
                    break;
                  }
                }
                
                // 매치되는 패턴이 없는 경우
                if (!processed) {
                  logger.warn(`재처리할 Redis 채널 또는 패턴을 찾을 수 없음: ${channel}`, {
                    component: 'messaging',
                    type: 'redis'
                  });
                  toDelete.push(id); // 더 이상 처리 불가
                }
              }
            }
            else if (msg.type === 'kafka') {
              // Kafka 메시지 재처리
              const topic = msg.channelOrTopic;
              
              if (this.kafkaTopics.has(topic)) {
                const handler = this.kafkaTopics.get(topic);
                handler(topic, payload);
                toDelete.push(id);
              } else {
                logger.warn(`재처리할 Kafka 토픽 핸들러를 찾을 수 없음: ${topic}`, {
                  component: 'messaging',
                  type: 'kafka'
                });
                toDelete.push(id); // 더 이상 처리 불가
              }
            }
            
            logger.debug(`실패 메시지 재처리 성공: ${id}`, {
              component: 'messaging',
              type: msg.type
            });
          } catch (error) {
            logger.error(`실패 메시지 재처리 오류: ${id}`, {
              error: error.message,
              stack: error.stack,
              component: 'messaging',
              type: msg.type
            });
            
            // 재시도 정보 업데이트
            msg.attempts++;
            msg.lastAttempt = now;
            msg.nextAttempt = now + (this.retryDelay * Math.pow(2, msg.attempts)); // 지수 백오프
          }
        } else {
          logger.warn(`최대 재시도 횟수 초과로 메시지 폐기: ${id}`, {
            component: 'messaging',
            type: msg.type,
            channelOrTopic: msg.channelOrTopic
          });
          toDelete.push(id);
        }
      }
    }
    
    // 처리 완료된 메시지 제거
    for (const id of toDelete) {
      this.failedMessages.delete(id);
    }
    
    if (this.failedMessages.size > 0) {
      logger.debug(`실패 메시지 재처리 완료: 남은 메시지=${this.failedMessages.size}`, {
        component: 'messaging'
      });
    }
  }

  /**
   * 리소스 정리
   */
  async stop() {
    try {
      // 배치 처리 중지
      this.batcher.stop();
      
      // 재시도 타이머 중지
      if (this.retryInterval) {
        clearInterval(this.retryInterval);
      }
      
      // 남은 실패 메시지 강제 처리
      this.processFailedMessages();
      
      // Redis 구독 해제
      // 패턴 구독 해제
      for (const pattern of this.redisPatterns.keys()) {
        await this.subscriber.punsubscribe(pattern);
      }
      // 일반 채널 구독 해제
      for (const channel of this.redisChannels.keys()) {
        await this.subscriber.unsubscribe(channel);
      }
      
      // Kafka 연결 종료
      await kafkaClient.disconnect();
      
      logger.info('하이브리드 메시징 시스템이 중지되었습니다', { component: 'messaging' });
    } catch (error) {
      logger.error('하이브리드 메시징 시스템 중지 오류', {
        error: error.message,
        stack: error.stack,
        component: 'messaging'
      });
    }
  }

  /**
   * 통합 구독 메소드 - Redis 또는 Kafka를 자동 선택
   * @param {string} channelOrTopic 채널 또는 토픽
   * @param {Function} handler 메시지 처리 핸들러
   * @param {Object} options 추가 설정
   * @param {boolean} options.useKafka Kafka 사용 여부 (기본: false)
   */
  async subscribe(channelOrTopic, handler, options = {}) {
    if (options.useKafka) {
      return this.subscribeKafka(channelOrTopic, handler, options);
    } else {
      return this.subscribeRedis(channelOrTopic, handler);
    }
  }

  /**
   * 통합 발행 메소드 - Redis 또는 Kafka를 자동 선택
   * @param {string} channelOrTopic 채널 또는 토픽
   * @param {any} message 발행할 메시지
   * @param {Object} options 추가 설정
   * @param {boolean} options.useKafka Kafka 사용 여부 (기본: false)
   * @param {string} options.key Kafka 메시지 키 (Kafka 사용 시)
   * @param {Object} options.headers Kafka 메시지 헤더 (Kafka 사용 시)
   */
  async publish(channelOrTopic, message, options = {}) {
    if (options.useKafka) {
      return this.publishKafka(channelOrTopic, message, options.key, options.headers);
    } else {
      return this.publishRedis(channelOrTopic, message);
    }
  }
}

module.exports = HybridMessaging;