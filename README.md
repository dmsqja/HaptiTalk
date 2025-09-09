# HaptiTalk
### 실시간 대화 분석 및 햅틱 피드백 커뮤니케이션 코칭 시스템

> 실시간 대화 분석과 햅틱 피드백을 결합한 AI 서비스 기반 커뮤니케이션 코칭 시스템
<img width="171" alt="image" src="https://github.com/user-attachments/assets/cc098176-34d0-4bc3-8f8c-00d0a1bfd8d1" />

[시연 영상](https://www.youtube.com/watch?v=nllbIaujAKU)

---

## 프로젝트 개요

HaptiTalk은 발표, 면접, 소개팅 등 실제 대면 상황에서 **스마트워치를 통한 은밀한 햅틱 피드백**으로 즉각적인 대화 개선을 제공하는 혁신적인 AI 시스템입니다. **HaptiTalk**은 기존 커뮤니케이션 코칭 도구의 한계를 뛰어넘는 실시간 솔루션을 제시합니다.

### 핵심 가치
- **실시간 대화 분석**: WhisperX 기반 고성능 STT 및 AI 감정 인식
- **혁신적 햅틱 피드백**: 상대방 모르게 받는 자연스러운 실시간 코칭
- **세그먼트 기반 분석**: 기존 방식 대비 85% 향상된 말하기 속도 측정 정확도
- **시나리오별 맞춤화**: 발표/면접/소개팅 상황별 특화된 분석 및 피드백

---

## 개발팀

### 프로젝트 구성원
| 역할 | 이름 | 전문 분야 | 연락처 |
|------|------|----------|--------|
| **팀장 & 풀스택** | 최태산 | 백엔드, DevOps, 인프라 | xotks7524@gmail.com |
| **AI/ML** | 정연균 | 음성처리, 감정분석 | jungyk411@sunmoon.ac.kr |
| **프론트엔드** | 이은범 | Flutter, 모바일 개발 | bum17822@naver.com |

### MVP 개발 기간
**2025년 3월 4일 ~ 6월 12일** (총 14주)

---

## 시스템 아키텍처

### 시스템 구조
![아키텍처](https://github.com/user-attachments/assets/1e781e4b-52a8-40af-9b1a-f52b8a0c8c60)
- **마이크로서비스 기반**: 9개의 독립적인 서비스로 구성
- **Docker 컨테이너화**: 확장 가능하고 안정적인 배포 환경
- **Kong API Gateway**: 중앙 집중식 라우팅 및 JWT 인증
- **실시간 처리**: WebSocket 기반 양방향 통신

### AI 처리 파이프라인
![image](https://github.com/user-attachments/assets/1d7e5c7a-9a12-4b06-88d3-0ca0ff23564e)
![image](https://github.com/user-attachments/assets/3bf49042-8658-41fb-b948-31c242a204fa)

- **STT Engine**: WhisperX v3.3.4 기반 실시간 음성 인식
- **Emotion Analysis**: Wav2Vec2-XLSR 모델로 7가지 감정 분류
- **Speaker Diarization**: pyannote.audio 3.1 다중 화자 식별
- **AI Report**: Google Gemini API 기반 맞춤형 분석 보고서

---

## 모바일 애플리케이션

### 주요 화면 구성

#### 메인 화면들
| 로그인 화면 | 메인 화면 | 세션 생성 화면 | 실시간 분석 화면 |
|:---:|:---:|:---:|:---:|
| <img width="250" alt="image" src="https://github.com/user-attachments/assets/1c423ed1-91bc-4e55-8cd2-21514e67be33" /> | <img width="250" alt="image" src="https://github.com/user-attachments/assets/179e2e86-6c3f-4614-a046-5bcb9c405134" /> | <img width="250" alt="image" src="https://github.com/user-attachments/assets/d80b2e10-3fe6-434d-a4a1-646909256d43" /> | <img width="250" alt="image" src="https://github.com/user-attachments/assets/627ce189-3376-4979-b0c5-64c9266213a1" /> |

#### 분석 및 기록 화면들  
| 분석 요약 화면 | 감정/호감도 | 말하기 패턴 | 대화 주제 |
|:---:|:---:|:---:|:---:|
| <img width="250" alt="image" src="https://github.com/user-attachments/assets/35c274c1-a215-4650-8fa6-db57e3a16396" /> | <img width="250" alt="image" src="https://github.com/user-attachments/assets/d8aadb13-f26b-47f5-8422-cf1637f072bf" /> | <img width="250" alt="image" src="https://github.com/user-attachments/assets/6877edc6-ed07-4651-a9bb-3beca68da498" /> | <img width="250" alt="image" src="https://github.com/user-attachments/assets/e29e7296-e407-436a-af38-b1ba9272216b" /> |

#### Apple Watch 연동
| Watch 메인 | 세션 화면 | 햅틱 피드백 | 설정 |
|:---:|:---:|:---:|:---:|
| <img width="250" alt="image" src="https://github.com/user-attachments/assets/a3bb6b90-742f-45d2-a56f-1dad53ed9098" /> | <img width="250" alt="image" src="https://github.com/user-attachments/assets/142af5a2-82b7-4cbc-aa14-50b40774eb06" /> | <img width="250" alt="image" src="https://github.com/user-attachments/assets/aeec22f4-ea41-4763-a3f2-e9d252268b61" /> | <img width="250" alt="image" src="https://github.com/user-attachments/assets/3e612959-fa26-4eb1-995a-f65071d19f7c" /> |

---

## 기술 스택

### Frontend
```
Flutter 3.x          │ 크로스 플랫폼 모바일 앱
├── Provider         │ 상태 관리
├── WebSocket        │ 실시간 통신  
├── Watch Connectivity│ 스마트워치 연동
└── Material Design 3│ 현대적 UI/UX
```

### Backend Services
```
Node.js + Express    │ 마이크로서비스 프레임워크
├── auth-service     │ JWT 기반 인증 및 권한 관리
├── session-service  │ 세션 생명주기 관리
├── feedback-service │ 햅틱 피드백 생성 및 전송
├── user-service     │ 사용자 프로필 및 설정 관리
├── realtime-service │ WebSocket 실시간 통신
├── report-service   │ AI 보고서 생성 및 관리
└── notification-service │ 푸시 알림 및 이벤트 처리
```

### AI Services
```
Python + FastAPI     │ AI 마이크로서비스
├── STT Service      │ WhisperX v3.3.4 음성 인식
├── Emotion Analysis │ Wav2Vec2-XLSR 감정 분석
└── Speaker Diarization │ pyannote.audio 화자 분리
```

### Infrastructure
```
Docker + Compose     │ 컨테이너 오케스트레이션
├── Kong             │ API Gateway 및 인증
├── PostgreSQL       │ 사용자/세션 관계형 데이터
├── MongoDB          │ 비정형 분석 결과 저장
├── Redis            │ 캐싱 및 세션 관리
└── Kafka            │ 비동기 메시징 시스템
```

### Monitoring & DevOps
```
Observability Stack  │ 통합 관찰성 시스템
├── Prometheus       │ 메트릭 수집 및 저장
├── Grafana          │ 통합 관찰성 플랫폼 (메트릭/로그/트레이스)
├── ELK Stack        │ 로그 수집, 처리 및 검색
├── Jaeger           │ 분산 트레이싱 및 성능 분석
└── OpenTelemetry    │ 트레이스 수집 및 전처리
```

---

## 기술적 특징

### 세그먼트 기반 말하기 속도 분석
기존 전체 시간 기반 WPM 계산의 한계를 극복한 혁신적 알고리즘:

```python
# 기존 방식 (부정확)
traditional_wpm = total_words / total_time * 60  # pause 시간 포함

# HaptiTalk 세그먼트 방식 (85% 향상)
segment_wpm = (words_in_segment / segment_duration) * 60
average_wpm = sum(segment_wpms) / len(segments)  # 순수 발화 시간만 계산
```

### 6가지 말하기 패턴 자동 분류
- **staccato**: 끊어 말하기 패턴 감지
- **continuous**: 연속적 발화 패턴
- **very_sparse**: 매우 띄엄띄엄 말하기
- **steady**: 일정한 속도 유지
- **variable**: 속도 변화가 큰 패턴  
- **normal**: 일반적인 대화 패턴

### 시나리오별 특화 분석
| 시나리오 | VAD 임계값 | 침묵 허용 | 감정 가중치 | 분석 초점 |
|---------|-----------|----------|-----------|----------|
| **면접** | 0.7 | 1000ms | 중립(1.3x) | 자신감, 명확성 |
| **소개팅** | 0.6 | 500ms | 기쁨(1.2x) | 호감도, 공감 |
| **발표** | 0.75 | 800ms | 안정감 중심 | 전달력, 설득력 |

---

## 성능 지표

### 핵심 성능
- **STT 정확도**: 95% 이상 (한국어 기준)
- **감정 분석 정확도**: 87% (7가지 감정 분류)
- **평균 처리 지연**: 150ms 이하 (GPU 환경)
- **동시 세션 처리**: 4개 (Jetson Orin Nano 기준)
- **모바일 네트워크 지연**: 200ms 이하
- **배터리 최적화**: 1시간 연속 사용 시 15% 이하 소모

### 하드웨어 최적화
- **NVIDIA Jetson Orin Nano 8GB**: ARM64 아키텍처 네이티브 최적화
- **CUDA 12.6**: GPU 가속 처리로 95% 효율성 달성
- **메모리 사용량**: 전체 시스템 6GB 이하 유지

---
## 모니터링 시스템

### 통합 관찰성 플랫폼 (Grafana)
<img width="1000" alt="image" src="https://github.com/user-attachments/assets/9e8aabcc-ffb8-4aff-89e8-bf1bd8e58e01" />
<img width="1000" alt="image" src="https://github.com/user-attachments/assets/43575777-2d81-49aa-8abb-d5469f1896c5" />

- **기능**: 메트릭, 로그, 트레이스 통합 시각화 및 분석
- **통합 기능**: 트레이스→로그 연결, 메트릭→트레이스 드릴다운
- **모니터링 항목**: API 응답시간, 메모리 사용량, 처리 성공률, 에러율

### 메트릭 수집 (Prometheus)  
<img width="1000" alt="image" src="https://github.com/user-attachments/assets/6adf560a-fbdd-4dd8-a097-c466e202a9a8" />
<img width="1000" alt="image" src="https://github.com/user-attachments/assets/6f23aaa6-9002-443e-946f-0b7ba4d84c44" />

- **기능**: 시계열 메트릭 수집 및 저장
- **수집 대상**: 시스템 리소스, 애플리케이션 성능, 데이터베이스 상태
- **Exporters**: Node, PostgreSQL, Redis, MongoDB, Elasticsearch 메트릭

### 로그 관리 (ELK Stack)
<img width="1000" alt="image" src="https://github.com/user-attachments/assets/8e4a30d6-a596-41f1-927a-c4a733d1fe02" />

- **기능**: 중앙화된 로그 수집, 처리 및 검색
- **구성**: Filebeat → Logstash → Elasticsearch → Kibana
- **활용**: 에러 추적, 사용자 행동 분석, 성능 병목 식별

### 분산 트레이싱 (Jaeger)
<img width="1000" alt="image" src="https://github.com/user-attachments/assets/932db154-b322-4ad7-9e50-237f1df9df9b" />
<img width="1000" alt="image" src="https://github.com/user-attachments/assets/df644c80-ba65-4ac7-a914-743b7f8a9acf" />

- **기능**: 마이크로서비스 간 요청 추적 및 성능 분석
- **수집**: OpenTelemetry Collector를 통한 트레이스 데이터 수집
- **활용**: End-to-end 성능 분석, 병목 지점 탐지, 서비스 의존성 분석

---

## 프로젝트 성과

### 기술적 혁신
- 세계 최초 실시간 대화분석+햅틱피드백 결합 시스템
- 85% 향상된 세그먼트 기반 말하기 속도 측정 정확도
- 95% 달성한 한국어 STT 인식 정확도
- 150ms 이하 실시간 처리 지연시간

### 수상 및 특허
- **선문대학교 SW중심대학 창업 아이디어 경진대회 최우수상** (2025)
- **선문대학교 SW중심대학 기업연계 프로젝트 우수팀 경진대회 대상** (2025)
- **한국디지털콘텐츠학회 하계종합학술대회 대학생 논문경진대회 대상**
- **특허 출원 진행중**

---

## 연락처

### 프로젝트 문의
- **GitHub Issues**: 기술적 문의 및 버그 리포트
- **이메일**: xotks7524@gmail.com (프로젝트 총괄)
- **연구실**: 선문대학교 컴퓨터공학부

### 협업 제안
기업 협력, 연구 참여, 기술 이전 등의 제안은 최태산(xotks7524@gmail.com)에게 직접 연락주시기 바랍니다.

---

<div align="center">

**HaptiTalk** - *Revolutionizing Communication with AI and Haptic Technology*

*Made with ❤️ by Sunmoon University SW Development Team*

</div>
