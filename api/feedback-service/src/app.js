// OpenTelemetry 트레이싱 초기화 (가장 먼저 로드되어야 함)
require('./utils/tracing');

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const {errorHandler} = require('./middleware/errorHandler.middleware');
const logger = require('./utils/logger');
const metrics = require('./utils/metrics');
const routes = require('./routes');
const appConfig = require('./config/app');
const {connectToMongoDB} = require('./config/mongodb');
const { v4: uuidv4 } = require('uuid');
const { swaggerUi, specs } = require('./utils/swagger');
const Redis = require('ioredis');
const AnalyticsCore = require('../../shared/analytics-core');

// Redis 클라이언트 초기화
const redisClient = new Redis({
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    password: process.env.REDIS_PASSWORD,
    retryDelayOnFailure: 100,
    maxRetriesPerRequest: 3,
});

// Redis 구독자 클라이언트 (별도 연결)
const redisSubscriber = new Redis({
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    password: process.env.REDIS_PASSWORD,
});

// Express 앱 초기화
const app = express();

// 요청 ID 미들웨어 - 각 요청에 고유 ID 부여
app.use((req, res, next) => {
    req.id = req.headers['x-request-id'] || uuidv4();
    res.setHeader('X-Request-ID', req.id);
    next();
});

// 기본 미들웨어 설정
app.use(helmet());
app.use(cors());

// 로깅 미들웨어 추가
app.use(logger.requestMiddleware);

// 메트릭 미들웨어 설정
metrics.setupMetricsMiddleware(app);

// Morgan 설정 변경 - OpenTelemetry와 호환되는 안전한 로깅
app.use(morgan((tokens, req, res) => {
    const logMessage = JSON.stringify({
        method: tokens.method(req, res),
        url: tokens.url(req, res),
        status: tokens.status(req, res),
        contentLength: tokens.res(req, res, 'content-length'),
        responseTime: tokens['response-time'](req, res),
        timestamp: new Date().toISOString(),
        requestId: req.id,
        userAgent: tokens['user-agent'](req, res)
    });
    
    // OpenTelemetry 컨텍스트와 충돌하지 않도록 직접 콘솔 출력
    console.log(logMessage);
    
    return null; // Morgan의 기본 스트림 사용 방지
}));

app.use(express.json());
app.use(express.urlencoded({extended: true}));

// API 라우트 설정
app.use('/api/v1/feedback', routes);

// Swagger UI 설정
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(specs, { explorer: true }));

// 헬스체크 엔드포인트
app.get('/health', (req, res) => {
    res.status(200).json({status: 'OK', service: 'feedback-service'});
});

// 로깅 에러 미들웨어 추가
app.use(logger.errorMiddleware);

// 메트릭 에러 미들웨어 추가
app.use(metrics.errorMetricsMiddleware);

// 에러 핸들링 미들웨어
app.use(errorHandler);

// 실시간 피드백 요청 처리
const handleRealtimeFeedbackRequest = async (channel, message) => {
    try {
        const { sessionId, userId, condition, timestamp } = JSON.parse(message);
        
        logger.debug(`실시간 피드백 요청 수신: ${condition.type} (세션 ${sessionId})`);
        
        // 햅틱 패턴 생성
        const hapticPattern = generateHapticPattern(condition);
        
        // 피드백 응답을 realtime-service로 전송
        const feedbackResponse = {
            sessionId,
            userId,
            type: 'haptic_feedback',
            pattern: hapticPattern,
            message: condition.message,
            priority: condition.priority,
            timestamp: Date.now(),
            originalCondition: condition.type
        };
        
        // Redis를 통해 realtime-service에 피드백 전송
        await redisClient.publish(
            `feedback:channel:${sessionId}`, 
            JSON.stringify(feedbackResponse)
        );
        
        logger.info(`햅틱 피드백 전송 완료: ${condition.type} -> ${sessionId}`, {
            pattern: hapticPattern.type,
            intensity: hapticPattern.intensity
        });
        
    } catch (error) {
        logger.error(`실시간 피드백 처리 오류: ${error.message}`, {
            channel,
            error: error.stack
        });
    }
};

// 햅틱 패턴 생성 함수
const generateHapticPattern = (condition) => {
    const patternMap = {
        // 자신감 관련
        'confidence_up': {
            type: 'success_burst',
            intensity: 0.8,
            duration: 300,
            pattern: [100, 50, 100, 50, 150]
        },
        'confidence_down': {
            type: 'attention_pulse',
            intensity: 0.6,
            duration: 500,
            pattern: [200, 100, 200, 100, 200]
        },
        
        // 설득력 관련
        'persuasion_low': {
            type: 'gentle_nudge',
            intensity: 0.5,
            duration: 250,
            pattern: [150, 75, 150]
        },
        
        // 안정감 관련
        'stability_low': {
            type: 'calming_rhythm',
            intensity: 0.4,
            duration: 400,
            pattern: [120, 60, 120, 60, 120]
        },
        
        // 호감도 관련
        'likeability_up': {
            type: 'positive_wave',
            intensity: 0.7,
            duration: 350,
            pattern: [80, 40, 120, 60, 160]
        },
        
        // 관심도 관련
        'interest_down': {
            type: 'warning_tap',
            intensity: 0.6,
            duration: 200,
            pattern: [100, 50, 100]
        },
        
        // 말하기 속도 관련
        'speed_fast': {
            type: 'slow_down',
            intensity: 0.5,
            duration: 600,
            pattern: [300, 150, 300]
        }
    };
    
    return patternMap[condition.type] || {
        type: 'default',
        intensity: 0.5,
        duration: 200,
        pattern: [100, 50, 100]
    };
};

// Redis 구독 설정
const setupRedisSubscription = async () => {
    try {
        // 패턴 기반 구독: feedback:request:* 채널들 구독
        await redisSubscriber.psubscribe('feedback:request:*');
        
        redisSubscriber.on('pmessage', (pattern, channel, message) => {
            handleRealtimeFeedbackRequest(channel, message);
        });
        
        logger.info('Redis 피드백 요청 구독 시작: feedback:request:*', {
            component: 'redis-subscriber',
            pattern: 'feedback:request:*'
        });
        
    } catch (error) {
        logger.error('Redis 구독 설정 실패:', {
            error: error.message,
            stack: error.stack
        });
    }
};

// 서버 시작
const PORT = appConfig.port || 3003;
app.listen(PORT, async () => {
    logger.info(`Feedback service is running on port ${PORT}`, { 
        port: PORT, 
        environment: process.env.NODE_ENV,
        node_version: process.version
    });
    
    // MongoDB 연결 초기화
    try {
        await connectToMongoDB();
        logger.info('MongoDB connection initialized successfully', {
            component: 'database',
            type: 'mongodb',
            status: 'connected'
        });
    } catch (err) {
        logger.error('Failed to initialize MongoDB connection:', { 
            error: err.message, 
            stack: err.stack,
            component: 'database',
            type: 'mongodb'
        });
    }
    
    // Redis 연결 확인 및 구독 설정
    try {
        await redisClient.ping();
        await redisSubscriber.ping();
        logger.info('Redis 연결 성공', {
            component: 'redis',
            status: 'connected'
        });
        
        // 실시간 피드백 구독 시작
        await setupRedisSubscription();
        
    } catch (err) {
        logger.error('Redis 연결 실패:', {
            error: err.message,
            stack: err.stack,
            component: 'redis'
        });
    }
});

// 종료 시 정리
process.on('SIGTERM', async () => {
    logger.info('SIGTERM 수신, 서버 종료 중...');
    await redisClient.quit();
    await redisSubscriber.quit();
    process.exit(0);
});

process.on('SIGINT', async () => {
    logger.info('SIGINT 수신, 서버 종료 중...');
    await redisClient.quit();
    await redisSubscriber.quit();
    process.exit(0);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled Rejection', { 
        reason: reason instanceof Error ? reason.message : reason,
        stack: reason instanceof Error ? reason.stack : undefined,
        promise
    });
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
    logger.error('Uncaught Exception', { 
        error: error.message, 
        stack: error.stack
    });
    process.exit(1);
});

module.exports = app;