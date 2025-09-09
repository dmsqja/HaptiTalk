#!/bin/bash

# 모든 서비스의 logger.js 파일 수정
services=("user-service" "feedback-service" "realtime-service" "session-service" "report-service")

for service in "${services[@]}"; do
    logger_file="/Users/tae4an/haptitalk/api/$service/src/utils/logger.js"
    
    if [ -f "$logger_file" ]; then
        echo "Updating logger.js for $service..."
        
        # 백업 생성
        cp "$logger_file" "$logger_file.bak"
        
        # logger.js 파일 수정
        cat > "$logger_file" << 'EOF'
const winston = require('winston');
const { format } = winston;

// 서비스 이름 설정
const SERVICE_NAME = process.env.SERVICE_NAME || 'REPLACE_SERVICE_NAME';

// Define log format with standardized structure
const logFormat = format.combine(
    format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss.SSS' }),
    format.errors({ stack: true }),
    format.metadata({ fillExcept: ['message', 'level', 'timestamp', 'service'] }),
    format.json()
);

// Create logger instance
const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: logFormat,
    defaultMeta: { 
        service: SERVICE_NAME,
        // host 정보 추가
        host: process.env.HOSTNAME || 'localhost',
        environment: process.env.NODE_ENV || 'development'
    },
    transports: [
        // 콘솔 출력 (도커 로그용)
        new winston.transports.Console({
            format: process.env.NODE_ENV === 'production' 
                ? format.json() // 프로덕션에서는 JSON 형식
                : format.combine( // 개발 환경에서는 읽기 쉬운 형식
                    format.colorize(),
                    format.printf(info => {
                        const { timestamp, level, message, metadata } = info;
                        const metaStr = Object.keys(metadata).length ? 
                            ` ${JSON.stringify(metadata)}` : '';
                        return `${timestamp} ${level}: [${SERVICE_NAME}] ${message}${metaStr}`;
                    })
                )
        }),
        // 파일 로깅 설정 (옵션)
        ...(process.env.LOG_TO_FILE === 'true' ? [
            new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
            new winston.transports.File({ filename: 'logs/combined.log' })
        ] : [])
    ],
    // 종료 시 로깅 처리
    exitOnError: false
});

// HTTP 요청 로깅 미들웨어
logger.requestMiddleware = (req, res, next) => {
    const start = Date.now();
    const requestId = req.headers['x-request-id'] || req.id;
    
    // 요청 정보 로깅
    logger.info(`Request received: ${req.method} ${req.originalUrl}`, {
        requestId,
        method: req.method,
        url: req.originalUrl,
        ip: req.ip,
        headers: req.headers,
        userId: req.user?.id
    });

    // 응답이 끝나면 결과 로깅
    res.on('finish', () => {
        const duration = Date.now() - start;
        const message = `Request completed: ${req.method} ${req.originalUrl} ${res.statusCode} ${duration}ms`;
        
        const logObject = {
            requestId,
            method: req.method,
            url: req.originalUrl,
            statusCode: res.statusCode,
            duration,
            ip: req.ip,
            userId: req.user?.id
        };

        if (res.statusCode >= 400) {
            logger.warn(message, logObject);
        } else {
            logger.info(message, logObject);
        }
    });

    next();
};

// 에러 핸들링 미들웨어
logger.errorMiddleware = (err, req, res, next) => {
    const requestId = req.headers['x-request-id'] || req.id;

    logger.error(`Error processing request: ${err.message}`, {
        requestId,
        method: req.method,
        url: req.originalUrl,
        statusCode: err.status || 500,
        error: err.message,
        stack: err.stack,
        userId: req.user?.id
    });

    next(err);
};

module.exports = logger;
EOF

        # 서비스 이름 교체
        sed -i '' "s/REPLACE_SERVICE_NAME/$service/g" "$logger_file"
        
        echo "Updated $service logger.js"
    fi
done

echo "All logger.js files have been updated!"
