# Emotion Analysis Service

한국어 음성 감정분석을 위한 마이크로서비스입니다. Wav2Vec2-XLSR 모델을 기반으로 한 고성능 감정분석 엔진을 사용하여 실시간 음성 감정분석을 제공하며, **시나리오별 가중치 적용**과 **STT 서비스 연동** 기능을 지원합니다.

## 🎯 주요 기능

- **한국어 음성 감정분석**: Wav2Vec2-XLSR 기반 고정밀 감정 인식
- **7가지 감정 분류**: 화남, 혐오, 두려움, 기쁨, 중립, 슬픔, 놀람
- **시나리오별 최적화**: 소개팅/면접/발표 상황에 맞는 감정분석 가중치
- **실시간 처리**: STT 서비스와 연동하여 실시간 감정분석
- **다중 입력 지원**: 파일 업로드 및 바이너리 데이터 처리
- **GPU 가속**: CUDA 지원으로 고속 처리

## 🛠 기술 스택

### **웹 프레임워크**
- **FastAPI 0.110.0**: 고성능 비동기 웹 프레임워크
- **Uvicorn**: ASGI 서버
- **Pydantic**: 데이터 검증 및 직렬화

### **AI/ML 라이브러리**
- **Transformers 4.51.3**: Hugging Face 모델 라이브러리
- **PyTorch 2.7.0**: 딥러닝 프레임워크 (Jetson 최적화)
- **Librosa 0.10.2**: 오디오 신호 처리
- **NumPy 1.26.4**: 수치 연산

### **오디오 처리**
- **SoundFile**: 오디오 파일 I/O
- **16kHz 샘플링**: 모델 호환성을 위한 표준화

## 📁 프로젝트 구조

```
emotion-analysis-service/
├── app/
│   ├── main.py              # FastAPI 애플리케이션 진입점
│   ├── api/
│   │   ├── api.py           # API 라우터 설정
│   │   └── endpoints/
│   │       ├── emotion.py   # 감정분석 엔드포인트
│   │       └── health.py    # 헬스체크 엔드포인트
│   ├── core/
│   │   ├── config.py        # 설정 관리
│   │   ├── logging.py       # 로깅 설정
│   │   └── models.py        # 데이터 모델
│   └── services/
│       └── emotion_service.py # 감정분석 핵심 로직
├── test/                    # 테스트 파일
├── logs/                    # 로그 파일
├── venv/                    # 가상환경
├── requirements.txt         # 의존성 목록
└── README.md               # 프로젝트 문서
```

## 🚀 설치 및 실행

### 1. 가상환경 설정

```bash
cd emotion-analysis-service
python -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate    # Windows
```

### 2. PyTorch 설치 (Jetson 사용시)

```bash
pip install --no-cache-dir \
  https://pypi.jetson-ai-lab.dev/jp6/cu126/+f/6ef/f643c0a7acda9/torch-2.7.0-cp310-cp310-linux_aarch64.whl \
  https://pypi.jetson-ai-lab.dev/jp6/cu126/+f/c59/026d500c57366/torchaudio-2.7.0-cp310-cp310-linux_aarch64.whl \
  https://pypi.jetson-ai-lab.dev/jp6/cu126/+f/daa/bff3a07259968/torchvision-0.22.0-cp310-cp310-linux_aarch64.whl
```

### 3. 의존성 설치

```bash
pip install -r requirements.txt
```

### 4. 서비스 실행

```bash
# 개발 모드로 실행
uvicorn app.main:app --reload --port 8001

# 또는
python -m app.main
```

## 📚 API 문서

서버 실행 후 다음 URL에서 API 문서를 확인할 수 있습니다:

- **Swagger UI**: http://localhost:8001/api/v1/docs
- **ReDoc**: http://localhost:8001/api/v1/redoc

## 🎯 주요 엔드포인트

### 1. 파일 업로드 감정분석

```bash
curl -X POST "http://localhost:8001/api/v1/emotion/analyze" \
  -H "Content-Type: multipart/form-data" \
  -F "audio_file=@/경로/파일명.wav" \
  -F "scenario=interview" \
  -F "apply_scenario_weights=true"
```

**응답 예시:**
```json
{
  "primary_emotion": {
    "emotion": "happy",
    "emotion_kr": "기쁨",
    "confidence": 0.8234,
    "probability": 0.8234
  },
  "all_emotions": [...],
  "top_emotions": [...],
  "scenario": "interview",
  "scenario_applied": true,
  "audio_duration": 3.5,
  "processing_time": 0.12,
  "model_used": "jungjongho/wav2vec2-xlsr-korean-speech-emotion-recognition2_data_rebalance"
}
```

### 2. 바이너리 데이터 감정분석 (실시간용)

```bash
curl -X POST "http://localhost:8001/api/v1/emotion/analyze_bytes" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @audio_data.wav \
  "?scenario=dating&apply_scenario_weights=true"
```

### 3. 헬스체크

```bash
curl "http://localhost:8001/api/v1/health/"
```

## 🎮 시나리오별 가중치

### 💕 소개팅 (dating)
- **기쁨**: 1.2배 가중치 (긍정적 반응 강조)
- **중립**: 1.1배 가중치 
- **화남/혐오**: 감소 가중치 (부정적 감정 완화)

### 💼 면접 (interview)
- **중립**: 1.3배 가중치 (전문적 태도 강조)
- **기쁨**: 1.1배 가중치
- **화남/혐오**: 큰 감소 가중치

### 📊 발표 (presentation)
- **중립**: 1.2배 가중치 (안정적 발표 강조)
- **기쁨**: 1.1배 가중치
- **감정적 반응**: 적절한 감소 가중치

## 🔗 STT 서비스 연동

### 설정 방법

`app/core/config.py`에서 STT 서비스 URL 설정:
```python
STT_SERVICE_API: str = "http://localhost:8000"
```

### 연동 방식

1. **직접 연동**: STT 서비스에서 HTTP POST로 오디오 데이터 전송
2. **WebSocket 연동**: 실시간 오디오 스트림 처리
3. **배치 처리**: 저장된 오디오 파일 일괄 처리

### 연동 예시

```python
import httpx

# STT 서비스에서 감정분석 서비스 호출
async def analyze_emotion_from_stt(audio_bytes: bytes, scenario: str):
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "http://localhost:8001/api/v1/emotion/analyze_bytes",
            content=audio_bytes,
            params={
                "scenario": scenario,
                "apply_scenario_weights": True
            }
        )
        return response.json()
```

## 📊 지원하는 오디오 형식

- **WAV**: 권장 형식
- **MP3**: 일반적인 압축 형식
- **OGG**: 오픈소스 형식
- **FLAC**: 무손실 압축

## ⚙️ 환경 변수 설정

`.env` 파일 생성:
```bash
# 감정분석 모델 설정
EMOTION_MODEL=jungjongho/wav2vec2-xlsr-korean-speech-emotion-recognition2_data_rebalance
DEVICE=cuda

# 서비스 연동
STT_SERVICE_API=http://localhost:8000

# 오디오 처리 설정
SAMPLE_RATE=16000
MAX_AUDIO_LENGTH=30
AUDIO_NORMALIZE=true
```

## 🐳 Docker 실행 (예정)

```bash
# Docker 이미지 빌드
docker build -t emotion-analysis-service .

# 컨테이너 실행
docker run -p 8001:8001 emotion-analysis-service
```

## 📈 성능 최적화

### GPU 메모리 관리
- 자동 메모리 정리
- 배치 처리 최적화
- 모델 지연 로딩

### 처리 속도
- **평균 처리 시간**: 100-200ms (GPU 기준)
- **동시 요청 처리**: 최대 4개 워커
- **메모리 사용량**: 약 2-3GB (모델 로딩 시)

## 🔧 개발 및 테스트

### 모델 테스트

```python
from app.services.emotion_service import emotion_processor
from app.core.models import EmotionAnalysisRequest

# 테스트 실행
request = EmotionAnalysisRequest(scenario="interview")
result = await emotion_processor.process_audio(audio_file, request)
print(f"주 감정: {result.primary_emotion.emotion_kr}")
```

### 로그 확인

```bash
tail -f logs/emotion_analysis_$(date +%Y%m%d).log
```

## 🤝 연동 가이드

이 서비스는 **HaptiTalk** 프로젝트의 STT 서비스와 완벽하게 연동되어 실시간 음성-감정 분석 파이프라인을 구성합니다.

### 실시간 처리 흐름
1. **STT 서비스**: 음성 → 텍스트 변환
2. **감정분석 서비스**: 동일 오디오 → 감정 분석
3. **통합 결과**: 텍스트 + 감정 정보 제공

이를 통해 사용자의 말하기 내용과 감정 상태를 동시에 분석하여 더 풍부한 피드백을 제공할 수 있습니다. 