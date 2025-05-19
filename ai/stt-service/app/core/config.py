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
    MAX_AUDIO_BUFFER_MB: int = 30  # 최대 오디오 버퍼 크기(MB)
    
    class Config:
        env_file = ".env"
        env_file_encoding = 'utf-8'
        case_sensitive = True


# 설정 인스턴스 생성
settings = Settings()

# 임시 오디오 디렉토리 생성
os.makedirs(settings.TEMP_AUDIO_DIR, exist_ok=True)