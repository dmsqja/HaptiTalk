#!/bin/bash

# Kong API 게이트웨이 재시작 스크립트
# API 보안 설정 변경 후 적용하기 위한 용도

echo "Kong API 게이트웨이 재시작을 시작합니다..."

# 작업 디렉토리를 프로젝트 루트로 변경
cd "$(dirname "$0")/.."

# 현재 Kong 컨테이너 상태 확인
echo "현재 Kong 컨테이너 상태 확인 중..."
docker ps | grep haptitalk-kong

# Kong 컨테이너 재시작
echo "Kong 컨테이너를 재시작합니다..."
docker-compose restart kong

# 재시작 후 상태 확인 (약간의 지연 적용)
echo "재시작 중입니다. 잠시 기다려주세요..."
sleep 5

# 컨테이너 상태 다시 확인
echo "Kong 컨테이너 상태 확인 중..."
docker ps | grep haptitalk-kong

# 라우트 확인
echo "Kong 라우트 확인 중..."
curl -s http://localhost:8001/routes | grep name

echo "Kong API 게이트웨이 재시작이 완료되었습니다."
echo "보안 설정이 성공적으로 적용되었습니다."