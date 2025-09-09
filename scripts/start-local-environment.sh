#!/bin/bash
set -e

echo "HaptiTalk 로컬 개발 환경 시작 스크립트"
echo "===================================="

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 함수 정의
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

wait_for_service() {
    local service=$1
    local timeout=${2:-60}
    local count=0
    
    log_info "서비스 대기 중: $service (최대 ${timeout}초)"
    
    while [ $count -lt $timeout ]; do
        if docker-compose ps $service | grep -q "healthy\|Up"; then
            log_success "$service 준비 완료"
            return 0
        fi
        sleep 1
        count=$((count + 1))
        if [ $((count % 10)) -eq 0 ]; then
            log_info "$service 대기 중... ($count/${timeout}초)"
        fi
    done
    
    log_error "$service 시작 실패 (시간 초과)"
    return 1
}

# Docker Desktop 실행 확인
log_info "Docker 상태 확인..."
if ! docker info >/dev/null 2>&1; then
    log_error "Docker Desktop이 실행되지 않았습니다. Docker Desktop을 시작해주세요."
    exit 1
fi
log_success "Docker 실행 중"

# 1단계: 기존 환경 정리
log_info "1단계: 기존 환경 정리"
docker-compose down --remove-orphans >/dev/null 2>&1 || true
docker-compose -f docker-compose.prod.yml down --remove-orphans >/dev/null 2>&1 || true
docker network rm haptitalk_network >/dev/null 2>&1 || true
log_success "기존 환경 정리 완료"

# 2단계: 핵심 데이터베이스 서비스
log_info "2단계: 데이터베이스 서비스 시작"
docker-compose up -d postgres mongodb redis
log_info "데이터베이스 준비 대기 중... (30초)"
sleep 30

wait_for_service "postgres" 60
wait_for_service "mongodb" 60  
wait_for_service "redis" 60

# 3단계: 메시징 시스템
log_info "3단계: 메시징 시스템 시작"
docker-compose up -d zookeeper
sleep 10

docker-compose up -d kafka
sleep 15

docker-compose up -d kafka-ui

wait_for_service "kafka" 90

# 4단계: API 게이트웨이
log_info "4단계: API 게이트웨이 시작"
docker-compose up -d kong-init
sleep 10

docker-compose up -d kong static-web

wait_for_service "kong" 60

# 5단계: 애플리케이션 서비스
log_info "5단계: 애플리케이션 서비스 시작"

services=("auth-service" "session-service" "user-service" "feedback-service" "report-service" "realtime-service")

for service in "${services[@]}"; do
    log_info "시작: $service"
    docker-compose up -d $service
    sleep 5
    wait_for_service $service 60
done

# 6단계: 상태 확인
log_info "6단계: 최종 상태 확인"
echo ""
echo "=== 애플리케이션 서비스 상태 ==="
docker-compose ps auth-service session-service user-service feedback-service report-service realtime-service

echo ""
echo "=== Health Check ==="

# Health check 함수
check_health() {
    local port=$1
    local service_name=$2
    
    if curl -s localhost:$port/health >/dev/null 2>&1; then
        log_success "$service_name ($port): 정상"
    else
        log_warning "$service_name ($port): 응답 없음"
    fi
}

check_health 3000 "Auth Service"
check_health 3002 "Session Service" 
check_health 3004 "User Service"

echo ""
log_success "🎉 로컬 개발 환경 시작 완료!"
echo ""
echo "=== 접속 정보 ==="
echo "• Auth Service: http://localhost:3000"
echo "• Realtime Service: http://localhost:3001" 
echo "• Session Service: http://localhost:3002"
echo "• Feedback Service: http://localhost:3003"
echo "• User Service: http://localhost:3004"
echo "• Report Service: http://localhost:3005"
echo "• Kong API Gateway: http://localhost:8000"
echo "• Kong Admin: http://localhost:8001"
echo "• Kafka UI: http://localhost:8080"
echo ""
echo "전체 상태 확인: docker-compose ps"
echo "로그 확인: docker-compose logs -f [서비스명]"
echo "개발 모드로 실행 중 - 코드 변경사항이 실시간 반영됩니다." 