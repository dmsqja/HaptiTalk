FROM node:18-alpine

WORKDIR /app

# 의존성 파일 복사
COPY api/feedback-service/package*.json ./

# 의존성 설치
RUN npm install

# 공유 모듈 복사 (auth-service 방식으로 통일)
COPY api/shared /app/api/shared

# 공유 모듈의 의존성 설치
WORKDIR /app/api/shared/kafka-client
RUN npm install
WORKDIR /app

# 앱 소스 복사
COPY api/feedback-service .

EXPOSE ${PORT}

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:${PORT:-3003}/health || exit 1

CMD ["npm", "start"]