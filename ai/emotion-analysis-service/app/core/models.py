from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from enum import Enum


class EmotionLabel(str, Enum):
    """감정 라벨 열거형"""
    ANGRY = "angry"          # 분노
    CONFUSED = "confused"    # 당황  
    FEARFUL = "fearful"      # 불안
    HAPPY = "happy"          # 기쁨
    NEUTRAL = "neutral"      # 중립
    SAD = "sad"              # 슬픔


class EmotionPrediction(BaseModel):
    """단일 감정 예측 결과"""
    emotion: EmotionLabel = Field(..., description="감정 라벨")
    emotion_kr: str = Field(..., description="한국어 감정 라벨")
    confidence: float = Field(..., ge=0.0, le=1.0, description="신뢰도 (0~1)")
    probability: float = Field(..., ge=0.0, le=1.0, description="확률 (0~1)")


class EmotionAnalysisRequest(BaseModel):
    """감정분석 요청 모델"""
    language: str = Field(default="ko", description="언어 코드")
    scenario: str = Field(default="presentation", description="시나리오 (dating, interview, presentation)")
    apply_scenario_weights: bool = Field(default=True, description="시나리오별 가중치 적용 여부")
    top_k: Optional[int] = Field(default=3, ge=1, le=6, description="상위 K개 감정 반환")
    confidence_threshold: Optional[float] = Field(default=0.5, ge=0.0, le=1.0, description="신뢰도 임계값")


class EmotionAnalysisResponse(BaseModel):
    """감정분석 응답 모델"""
    primary_emotion: EmotionPrediction = Field(..., description="주 감정")
    all_emotions: List[EmotionPrediction] = Field(..., description="모든 감정 예측 결과")
    top_emotions: List[EmotionPrediction] = Field(..., description="상위 K개 감정")
    scenario: str = Field(..., description="사용된 시나리오")
    scenario_applied: bool = Field(..., description="시나리오 가중치 적용 여부")
    audio_duration: Optional[float] = Field(None, description="오디오 길이 (초)")
    processing_time: float = Field(..., description="처리 시간 (초)")
    model_used: str = Field(..., description="사용된 모델명")


class AudioSegmentData(BaseModel):
    """오디오 세그먼트 데이터 (실시간 처리용)"""
    segment_id: int = Field(..., description="세그먼트 ID")
    audio_data: bytes = Field(..., description="오디오 바이너리 데이터")
    sample_rate: int = Field(default=16000, description="샘플링 레이트")
    timestamp: float = Field(..., description="타임스탬프")
    duration: Optional[float] = Field(None, description="세그먼트 길이 (초)")


class RealtimeEmotionResult(BaseModel):
    """실시간 감정분석 결과"""
    segment_id: int = Field(..., description="세그먼트 ID")
    timestamp: float = Field(..., description="타임스탬프")
    emotion_analysis: EmotionAnalysisResponse = Field(..., description="감정분석 결과")
    is_final: bool = Field(default=False, description="최종 결과 여부")


class EmotionWebSocketMessage(BaseModel):
    """WebSocket 메시지 모델"""
    type: str = Field(..., description="메시지 타입 (audio, control, result)")
    data: Dict[str, Any] = Field(..., description="메시지 데이터")
    timestamp: float = Field(..., description="타임스탬프")
    connection_id: Optional[str] = Field(None, description="연결 ID")


class HealthCheckResponse(BaseModel):
    """헬스체크 응답 모델"""
    status: str = Field(..., description="서비스 상태")
    version: str = Field(..., description="서비스 버전")
    model_loaded: bool = Field(..., description="모델 로딩 상태")
    model_name: str = Field(..., description="사용 중인 모델명")
    device: str = Field(..., description="사용 중인 디바이스")
    uptime: float = Field(..., description="서비스 업타임 (초)")


class EmotionStatsResponse(BaseModel):
    """감정분석 통계 응답"""
    total_requests: int = Field(..., description="총 요청 수")
    successful_requests: int = Field(..., description="성공한 요청 수")
    failed_requests: int = Field(..., description="실패한 요청 수")
    average_processing_time: float = Field(..., description="평균 처리 시간 (초)")
    emotion_distribution: Dict[str, int] = Field(..., description="감정별 분포")
    scenario_distribution: Dict[str, int] = Field(..., description="시나리오별 분포") 