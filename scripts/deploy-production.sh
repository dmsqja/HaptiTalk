#!/bin/bash

# HaptiTalk 프로덕션 배포 스크립트
set -e

echo "===== HaptiTalk 프로덕션 배포 시작 ====="

# 스크립트 디렉토리로 이동
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# 환경변수 설정
export NODE_ENV=production
export COMPOSE_PROJECT_NAME=haptitalk

# GitHub Container Registry 설정
GITHUB_REPOSITORY_OWNER=${GITHUB_REPOSITORY_OWNER:-"tae4an"}
IMAGE_TAG=${IMAGE_TAG:-"latest"}

echo "Repository Owner: $GITHUB_REPOSITORY_OWNER"
echo "Image Tag: $IMAGE_TAG"

# Docker Desktop 실행 상태 확인
echo "Docker 상태 확인 중..."
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker가 실행되지 않았습니다."
    echo "Docker Desktop을 시작하는 중..."
    
    # macOS에서 Docker Desktop 시작
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open -a Docker
        echo "Docker Desktop이 시작되고 있습니다. 30초 대기 중..."
        sleep 30
        
        # Docker가 준비될 때까지 대기
        for i in {1..30}; do
            if docker info > /dev/null 2>&1; then
                echo "✅ Docker가 준비되었습니다."
                break
            fi
            echo "Docker 시작 대기 중... ($i/30)"
            sleep 2
        done
        
        if ! docker info > /dev/null 2>&1; then
            echo "❌ Docker 시작에 실패했습니다. 수동으로 Docker Desktop을 시작하고 다시 시도하세요."
            exit 1
        fi
    else
        echo "❌ Docker를 수동으로 시작하고 다시 시도하세요."
        exit 1
    fi
else
    echo "✅ Docker가 실행 중입니다."
fi

# 네트워크 생성
echo "Docker 네트워크 생성 중..."
docker network create haptitalk_network 2>/dev/null || echo "네트워크가 이미 존재합니다."

# GitHub Container Registry 인증 (PAT 토큰 필요)
if [ -n "$GHCR_PAT" ]; then
    echo "GitHub Container Registry 인증 중..."
    echo "$GHCR_PAT" | docker login ghcr.io -u "$GITHUB_REPOSITORY_OWNER" --password-stdin
else
    echo "⚠️  GHCR_PAT 환경변수가 설정되지 않았습니다. 공개 이미지만 사용할 수 있습니다."
fi

# 기존 컨테이너 정리 (선택적)
read -p "기존 컨테이너를 정리하시겠습니까? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "기존 컨테이너 정리 중..."
    docker-compose -f docker-compose.prod.yml down --volumes --remove-orphans || true
    docker system prune -f || true
fi

# 최신 이미지 다운로드
echo "최신 이미지 다운로드 중..."
export GITHUB_REPOSITORY_OWNER
export IMAGE_TAG
docker-compose -f docker-compose.prod.yml pull || echo "일부 이미지를 가져오지 못했습니다."

# 인프라 서비스 먼저 시작
echo "===== 인프라 서비스 시작 ====="
docker-compose -f docker-compose.prod.yml up -d postgres mongodb redis zookeeper kafka kafka-ui kafka-init kong static-web

echo "인프라 서비스 준비 대기 중... (60초)"
sleep 60

# 인프라 서비스 상태 확인
echo "===== 인프라 서비스 상태 확인 ====="
docker-compose -f docker-compose.prod.yml ps postgres mongodb redis kafka kong

# 애플리케이션 서비스 시작
echo "===== 애플리케이션 서비스 시작 ====="
docker-compose -f docker-compose.prod.yml up -d auth-service session-service user-service feedback-service report-service realtime-service

echo "애플리케이션 서비스 준비 대기 중... (30초)"
sleep 30

# 최종 상태 확인
echo "===== 최종 배포 상태 ====="
docker-compose -f docker-compose.prod.yml ps

# 헬스 체크
echo "===== 헬스 체크 ====="
SERVICES=("postgres" "redis" "kafka" "kong")
for service in "${SERVICES[@]}"; do
    if docker-compose -f docker-compose.prod.yml ps "$service" | grep -q "Up"; then
        echo "✅ $service: 정상"
    else
        echo "❌ $service: 오류"
    fi
done

# 접속 정보 출력
echo ""
echo "===== 접속 정보 ====="
echo "🌐 Kong API Gateway: http://localhost:8000"
echo "📊 Kafka UI: http://localhost:8080"
echo "🔧 Kong Admin: http://localhost:8001"
echo "🗄️  PostgreSQL: localhost:5432"
echo "📝 Redis: localhost:6379"
echo "📨 Kafka: localhost:9092"

echo ""
echo "===== 프로덕션 배포 완료 ====="
echo "로그 확인: docker-compose -f docker-compose.prod.yml logs -f [service_name]"
echo "서비스 중지: docker-compose -f docker-compose.prod.yml down" 