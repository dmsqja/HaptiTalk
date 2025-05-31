from pydantic_settings import BaseSettings
from typing import Optional, Dict, Any, List
import os


class Settings(BaseSettings):
    """
    감정분석 서비스 설정 클래스
    
    환경 변수로 오버라이드 가능
    """
    # API 설정
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "감정분석 서비스"
    
    # 감정분석 모델 설정
    EMOTION_MODEL: str = "jungjongho/wav2vec2-xlsr-korean-speech-emotion-recognition2_data_rebalance"
    DEVICE: str = "cuda"  # 사용할 장치 ("cuda" 또는 "cpu")
    
    # 오디오 처리 설정
    SAMPLE_RATE: int = 16000  # 오디오 샘플링 레이트
    MAX_AUDIO_LENGTH: int = 30  # 최대 오디오 길이 (초)
    AUDIO_NORMALIZE: bool = True  # 오디오 정규화 여부
    
    # 감정 카테고리 매핑 (실제 모델 출력에 맞춤)
    EMOTION_LABELS: Dict[str, str] = {
        "angry": "분노",
        "confused": "당황", 
        "fearful": "불안",
        "happy": "기쁨",
        "neutral": "중립",
        "sad": "슬픔"
    }
    
    # 배치 처리 설정
    BATCH_SIZE: int = 1  # 배치 크기
    MAX_WORKERS: int = 2  # 병렬 작업자 수
    
    # 임시 파일 저장 경로
    TEMP_AUDIO_DIR: str = "/tmp/emotion_audio"
    
    # 다른 서비스 연동을 위한 API 엔드포인트
    STT_SERVICE_API: Optional[str] = "http://localhost:8000"
    SPEAKER_DIARIZATION_API: Optional[str] = None
    
    # 감정분석 임계값 설정
    CONFIDENCE_THRESHOLD: float = 0.5  # 신뢰도 임계값
    TOP_K_EMOTIONS: int = 3  # 상위 K개 감정 반환 (최대 6개)
    
    # WebSocket 설정 (실시간 처리용)
    WEBSOCKET_BUFFER_SIZE: int = 1024 * 16  # 16KB 버퍼
    WEBSOCKET_TIMEOUT: int = 60  # 60초 타임아웃
    
    # 시나리오별 감정분석 가중치 (실제 모델 라벨에 맞춤)
    SCENARIO_WEIGHTS: Dict[str, Dict[str, float]] = {
        "dating": {
            "happy": 1.2,      # 기쁨에 가중치
            "neutral": 1.1,    # 중립에 약간 가중치
            "angry": 0.8,      # 분노에 감소 가중치
            "sad": 0.9,        # 슬픔에 감소 가중치
            "fearful": 0.8,    # 불안에 감소 가중치
            "confused": 0.9    # 당황에 감소 가중치
        },
        "interview": {
            "neutral": 1.3,    # 중립에 강한 가중치
            "happy": 1.1,      # 기쁨에 약간 가중치
            "angry": 0.6,      # 분노에 큰 감소 가중치
            "fearful": 0.8,    # 불안에 감소 가중치
            "confused": 0.7,   # 당황에 감소 가중치
            "sad": 0.7         # 슬픔에 감소 가중치
        },
        "presentation": {
            "neutral": 1.2,    # 중립에 가중치
            "happy": 1.1,      # 기쁨에 약간 가중치
            "angry": 0.7,      # 분노에 감소 가중치
            "fearful": 0.8,    # 불안에 감소 가중치
            "confused": 0.8,   # 당황에 감소 가중치
            "sad": 0.8         # 슬픔에 감소 가중치
        }
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