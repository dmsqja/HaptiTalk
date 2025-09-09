#!/bin/bash

echo "🛑 HaptiTalk 로컬 개발 환경 종료 스크립트"
echo "======================================="

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 모든 서비스 종료
log_info "모든 컨테이너 종료 중..."
docker-compose down --remove-orphans

# 네트워크 정리
log_info "네트워크 정리 중..."
docker network rm haptitalk_network 2>/dev/null || true

# 선택적 정리 옵션
read -p "Docker 시스템 정리를 수행하시겠습니까? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Docker 시스템 정리 중..."
    docker system prune -f
    log_success "시스템 정리 완료"
fi

log_success "🎉 로컬 개발 환경 종료 완료!"
echo "다시 시작하려면: ./scripts/start-local-environment.sh" 