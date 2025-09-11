from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from enum import Enum


class AudioFormat(str, Enum):
    WAV = "wav"
    MP3 = "mp3"
    OGG = "ogg"
    FLAC = "flac"


class STTRequest(BaseModel):
    """음성 인식 요청 모델"""
    language: Optional[str] = Field("ko", description="인식할 언어 코드 (예: ko, en)")
    return_timestamps: bool = Field(False, description="단어별 타임스탬프 반환 여부")
    compute_type: Optional[str] = Field(None, description="연산 타입 (float16, float32 등)")


class TimestampedWord(BaseModel):
    """타임스탬프가 있는 단어 모델"""
    word: str = Field(..., description="단어")
    start: float = Field(..., description="시작 시간 (초)")
    end: float = Field(..., description="종료 시간 (초)")
    probability: float = Field(..., description="신뢰도")


class STTResponse(BaseModel):
    """음성 인식 응답 모델"""
    text: str = Field(..., description="인식된 텍스트")
    language: str = Field(..., description="인식된 언어")
    words: Optional[List[TimestampedWord]] = Field(None, description="단어별 타임스탬프 (요청시)")
    duration: float = Field(..., description="오디오 길이 (초)")
    processing_time: float = Field(..., description="처리 시간 (초)")


class STTStreamingResponse(BaseModel):
    """실시간 음성 인식 응답 모델"""
    partial_text: str = Field(..., description="현재까지 인식된 텍스트")
    is_final: bool = Field(False, description="최종 인식 결과 여부")
    segment_id: int = Field(..., description="세그먼트 ID")


class HealthResponse(BaseModel):
    """서비스 상태 확인 응답 모델"""
    status: str = Field(..., description="서비스 상태")
    version: str = Field(..., description="서비스 버전") 