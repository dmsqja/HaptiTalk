from pydantic_settings import BaseSettings
from typing import Optional, Dict, Any, List
import os


class Settings(BaseSettings):
    """
    STT 서비스 설정 클래스
    
    환경 변수로 오버라이드 가능
    """
    # API 설정
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "STT Service"
    
    # 오디오 관련 상수
    SAMPLE_RATE: int = 16000  # 오디오 샘플링 레이트 (Hz)
    DEFAULT_BUFFER_SIZE: int = 960000  # 기본 오디오 버퍼 크기 (bytes)
    
    # WhisperX 모델 설정
    WHISPER_MODEL: str = "turbo"  # 사용할 모델 (tiny, base, small, medium, large, large-v3)
    DEVICE: str = "cuda"  # 사용할 장치 ("cuda" 또는 "cpu")
    COMPUTE_TYPE: str = "float16"  # 연산 정밀도 (float16, float32, int8)
    CPU_THREADS: int = 4  # CPU 스레드 수
    
    # Transcribe 매개변수 설정
    TRANSCRIBE_PARAMS: Dict[str, Any] = {
        "beam_size": 5,
        "word_timestamps": True,
        "vad_filter": True,
        "task": "transcribe",
        "condition_on_previous_text": True,
        "vad_parameters": {
            "min_silence_duration_ms": 700,
            "min_speech_duration_ms": 250,
            "threshold": 0.7
        }
    }
    
    # 임시 파일 저장 경로
    TEMP_AUDIO_DIR: str = "/tmp/stt_audio"
    
    # 다른 서비스 연동을 위한 API 엔드포인트
    EMOTION_ANALYSIS_API: Optional[str] = None
    SPEAKER_DIARIZATION_API: Optional[str] = None
    
    # 시스템 리소스 제한
    MAX_WORKERS: int = 4  # 병렬 작업자 수
    MAX_AUDIO_BUFFER_MB: int = 15  # 최대 오디오 버퍼 크기(MB) - 30초 분량
    
    # 시나리오별 VAD 파라미터 (음성 감지 민감도)
    SCENARIO_VAD_PARAMS: Dict[str, Dict[str, Any]] = {
        "dating": {
            "min_silence_duration_ms": 500,    # 짧은 침묵도 구분
            "min_speech_duration_ms": 200,     # 짧은 반응도 포착
            "threshold": 0.6                   # 더 민감하게
        },
        "interview": {
            "min_silence_duration_ms": 1000,   # 긴 침묵 허용
            "min_speech_duration_ms": 300,     # 명확한 발화만
            "threshold": 0.7                   # 표준
        },
        "presentation": {
            "min_silence_duration_ms": 800,    # 적당한 pause
            "min_speech_duration_ms": 250,     # 표준
            "threshold": 0.75                  # 약간 높게
        }
    }
    
    # 시나리오별 말하기 속도 임계값 (WPM)
    SCENARIO_SPEED_THRESHOLDS: Dict[str, Dict[str, Dict[str, float]]] = {
        "dating": {
            "ko": {"very_slow": 60, "slow": 70, "normal": 100, "fast": 120, "very_fast": 120},
            "en": {"very_slow": 80, "slow": 100, "normal": 130, "fast": 150, "very_fast": 150}
        },
        "interview": {
            "ko": {"very_slow": 50, "slow": 65, "normal": 95, "fast": 110, "very_fast": 110},
            "en": {"very_slow": 70, "slow": 90, "normal": 120, "fast": 140, "very_fast": 140}
        },
        "presentation": {
            "ko": {"very_slow": 65, "slow": 75, "normal": 105, "fast": 120, "very_fast": 120},
            "en": {"very_slow": 90, "slow": 110, "normal": 140, "fast": 160, "very_fast": 160}
        }
    }
    
    # 발화 밀도 계산을 위한 설정
    SPEECH_DENSITY_THRESHOLDS: Dict[str, float] = {
        "very_sparse": 0.2,   # 20% 미만 발화
        "sparse": 0.4,        # 20-40% 발화
        "normal": 0.6,        # 40-60% 발화
        "dense": 0.8,         # 60-80% 발화
        "very_dense": 1.0     # 80% 이상 발화
    }
    
    class Config:
        env_file = ".env"
        env_file_encoding = 'utf-8'
        case_sensitive = True
        extra = "ignore"  # 알 수 없는 환경 변수 무시


# 설정 인스턴스 생성
settings = Settings()

# 임시 오디오 디렉토리 생성
os.makedirs(settings.TEMP_AUDIO_DIR, exist_ok=True)