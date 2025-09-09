#!/bin/sh

# 실패 시 종료
set -e

echo "Kafka 통합 테스트 시작..."

# 환경 변수 설정 - 테스트 환경에서는 kafka:9092를 사용
export KAFKA_BROKER=kafka:9092
export NODE_ENV=test

# Kafka 서비스가 준비될 때까지 대기
echo "Kafka 서비스 준비 확인 중..."
timeout=60
counter=0
until nc -z kafka 9092
do
  sleep 1
  counter=$((counter + 1))
  if [ $counter -eq $timeout ]; then
    echo "Kafka 서비스 연결 실패: 타임아웃"
    exit 1
  fi
  echo "Kafka 서비스 준비 대기 중... ($counter/$timeout)"
done

echo "Kafka 서비스 준비 완료!"

# 테스트 실행
echo "통합 테스트 실행 중..."
npm run test:integration

echo "테스트 완료!" 