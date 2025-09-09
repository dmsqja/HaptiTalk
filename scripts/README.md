# HaptiTalk 로컬 개발 환경 관리 스크립트

이 폴더에는 HaptiTalk 플랫폼의 로컬 개발 환경을 관리하는 스크립트들이 있습니다.

## 스크립트 목록

### 로컬 개발 환경

**개발자용 - 코드 변경사항이 실시간 반영됩니다**

```bash
# 로컬 개발 환경 시작
./scripts/start-local-environment.sh

# 로컬 개발 환경 종료
./scripts/stop-local-environment.sh
```

**특징:**
- `docker-compose.yml` 사용 (개발 설정)
- 볼륨 마운트를 통한 코드 실시간 반영
- 디버그 모드 활성화
- 개발에 최적화된 설정

## 사용법

### 1. 로컬 개발 환경 시작하기

```bash
# Docker Desktop이 실행 중인지 확인
docker info

# 로컬 개발 환경 시작
./scripts/start-local-environment.sh
```

### 2. 개발 작업하기

개발 환경이 시작되면 코드 변경사항이 자동으로 컨테이너에 반영됩니다.
- 백엔드: Node.js 서비스들이 nodemon으로 자동 재시작
- 프론트엔드: 모바일 앱은 별도 실행 필요

### 3. 상태 확인

```bash
# 개발 환경 상태 확인
docker-compose ps

# 특정 서비스 로그 확인
docker-compose logs -f [서비스명]

# 모든 서비스 로그 확인
docker-compose logs -f
```

### 4. 개발 환경 종료

```bash
# 개발 환경 종료
./scripts/stop-local-environment.sh
```

## 서비스 포트 정보

| 서비스 | 포트 | 설명 |
|--------|------|------|
| Auth Service | 3000 | 인증 서비스 |
| Realtime Service | 3001 | 실시간 통신 서비스 |
| Session Service | 3002 | 세션 관리 서비스 |
| Feedback Service | 3003 | 피드백 서비스 |
| User Service | 3004 | 사용자 관리 서비스 |
| Report Service | 3005 | 리포트 서비스 |
| Kong API Gateway | 8000 | API 게이트웨이 |
| Kong Admin | 8001 | Kong 관리 인터페이스 |
| Kafka UI | 8080 | Kafka 관리 인터페이스 |

## 🛠️ 개발 팁

### Health Check URL

각 서비스의 상태를 확인할 수 있습니다:

```bash
# 서비스별 헬스체크
curl http://localhost:3000/health  # Auth Service
curl http://localhost:3002/health  # Session Service  
curl http://localhost:3004/health  # User Service
```

### 데이터베이스 접속

```bash
# PostgreSQL 접속
docker-compose exec postgres psql -U haptitalk -d haptitalk

# MongoDB 접속
docker-compose exec mongodb mongosh --username haptitalk --password haptitalk --authenticationDatabase haptitalk

# Redis CLI 접속
docker-compose exec redis redis-cli
```

### 실시간 로그 모니터링

```bash
# 특정 서비스 로그 실시간 확인
docker-compose logs -f auth-service
docker-compose logs -f user-service

# 여러 서비스 로그 동시 확인
docker-compose logs -f auth-service user-service session-service
```

## 주의사항

1. **Docker Desktop 필수**: 스크립트 실행 전에 Docker Desktop이 실행되어 있어야 합니다.

2. **포트 충돌**: 위의 포트들이 이미 사용 중이면 스크립트가 실패할 수 있습니다.

3. **환경 변수**: `.env` 파일이 프로젝트 루트에 있어야 합니다.

4. **권한**: 스크립트에 실행 권한이 있어야 합니다:
   ```bash
   chmod +x scripts/*.sh
   ```

## 문제 해결

### 스크립트가 실행되지 않는 경우

```bash
# 실행 권한 부여
chmod +x scripts/*.sh

# Docker 상태 확인
docker info
```

### 포트 충돌 해결

```bash
# 기존 컨테이너 정리
docker-compose down --remove-orphans

# 시스템 정리
docker system prune -f
```

### 서비스가 시작되지 않는 경우

```bash
# 로그 확인
docker-compose logs [서비스명]

# 컨테이너 상태 확인
docker-compose ps

# 특정 서비스 재시작
docker-compose restart [서비스명]
```

### 데이터베이스 초기화

```bash
# 모든 데이터 삭제하고 재시작
docker-compose down -v
./scripts/start-local-environment.sh
```

---

**개발 팁**: 
- 코드 변경 후 자동 재시작되지 않으면 `docker-compose restart [서비스명]`을 실행하세요.
- 데이터베이스 스키마 변경 시에는 마이그레이션 스크립트를 실행하세요.
- 새로운 의존성 추가 시에는 컨테이너를 재빌드해야 할 수 있습니다. 