FROM node:18-alpine

# 작업 디렉토리 설정
WORKDIR /app

# 의존성 파일 복사
COPY api/realtime-service/package*.json ./

# 의존성 설치
RUN npm install

# 공유 모듈 복사 (auth-service 방식으로 통일)
COPY api/shared /app/api/shared

# 공유 모듈의 의존성 설치
WORKDIR /app/api/shared/kafka-client
RUN npm install
WORKDIR /app

# 앱 소스 복사
COPY api/realtime-service .

# 포트 설정
EXPOSE ${PORT}

# 실행 명령
CMD ["npm", "start"]