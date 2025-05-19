from pydantic_settings import BaseSettings
from typing import Optional, Dict, Any, List
import os


class Settings(BaseSettings):
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "STT Service"
    
    # WhisperX 설정
    WHISPER_MODEL: str = "turbo"  # 가벼운 모델로 변경 (tiny, base, small, medium, large, large-v3)
    DEVICE: str = "cuda"  # "cuda" or "cpu"
    COMPUTE_TYPE: str = "float16"  # 정밀도 타입 (float16, float32, int8)
    CPU_THREADS: int = 4  # CPU 스레드 수
    
    # Transcribe 매개변수 설정
    TRANSCRIBE_PARAMS: Dict[str, Any] = {
        "beam_size": 5,
        "word_timestamps": True,
        "vad_filter": True,
        "task": "transcribe",
        "condition_on_previous_text": True,
        # "initial_prompt": "안녕하세요. 이것은 음성 인식 서비스입니다.",  # 초기 프롬프트 문장
        # faster-whisper 라이브러리에서 지원하지 않는 매개변수들 제거
        # "temperature": 0.0,
        # "compression_ratio_threshold": 2.4,
        # "logprob_threshold": -1.0,
        # "no_speech_threshold": 0.6,
        "vad_parameters": {
            "min_silence_duration_ms": 700,
            "min_speech_duration_ms": 250,
            # 지원되지 않는 VAD 옵션 제거
            # "max_speech_duration_s": 30,
            # "max_merge_size": 15,
            # "speech_pad_ms": 30,
            # "padding": 1.0,
            # "prompt_window": 3.0,
            # "onset": 0.5,
            "threshold": 0.7
        }
    }
    
    # 언어별 초기 프롬프트 설정
    LANGUAGE_PROMPTS: Dict[str, str] = {
        "ko": "안녕하세요. 한국어 음성 인식을 시작합니다.",
        "en": "Hello. Starting English speech recognition.",
        "ja": "こんにちは。日本語の音声認識を開始します。",
        "zh": "你好。开始中文语音识别。"
    }
    
    # 환각 필터링 설정
    HALLUCINATION_PATTERNS: List[str] = [
        "감사합니다", "아멘", "다음", "영상", "만나요", "시청", "자막", 
        "by", "한글자막", "자막제공", "시리즈", "아름다운", "공유", "별도",
        "비쥬스", "채널"
    ]
    
    # 임시 파일 저장 경로
    TEMP_AUDIO_DIR: str = "/tmp/stt_audio"
    
    # 다른 서비스 연동을 위한 API 엔드포인트 (향후 사용)
    EMOTION_ANALYSIS_API: Optional[str] = None
    SPEAKER_DIARIZATION_API: Optional[str] = None
    
    # 시스템 리소스 제한
    MAX_WORKERS: int = 2  # 병렬 작업자 수
    MAX_AUDIO_BUFFER_MB: int = 5  # 최대 오디오 버퍼 크기(MB)
    
    class Config:
        case_sensitive = True
        env_file = ".env"


settings = Settings()

# 임시 오디오 디렉토리 생성
os.makedirs(settings.TEMP_AUDIO_DIR, exist_ok=True) 