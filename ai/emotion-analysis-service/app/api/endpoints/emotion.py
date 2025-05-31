from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status, Query, Request
from typing import Optional

from app.core.models import (
    EmotionAnalysisRequest, 
    EmotionAnalysisResponse
)
from app.services.emotion_service import emotion_processor
from app.core.logging import logger

router = APIRouter()


@router.post("/analyze", response_model=EmotionAnalysisResponse)
async def analyze_emotion(
    audio_file: UploadFile = File(...),
    language: str = Query(default="ko", description="언어 코드"),
    scenario: str = Query(default="presentation", description="시나리오 (dating, interview, presentation)"),
    apply_scenario_weights: bool = Query(default=True, description="시나리오별 가중치 적용 여부"),
    top_k: Optional[int] = Query(default=3, ge=1, le=6, description="상위 K개 감정 반환"),
    confidence_threshold: Optional[float] = Query(default=0.5, ge=0.0, le=1.0, description="신뢰도 임계값")
) -> EmotionAnalysisResponse:
    """
    오디오 파일 감정분석
    
    - **audio_file**: 업로드할 오디오 파일 (WAV, MP3, OGG, FLAC)
    - **language**: 언어 코드 (기본값: ko)
    - **scenario**: 시나리오 타입 (dating, interview, presentation)
    - **apply_scenario_weights**: 시나리오별 가중치 적용 여부
    - **top_k**: 상위 K개 감정 반환
    - **confidence_threshold**: 신뢰도 임계값
    
    Returns:
        감정분석 결과와 메타데이터
    """
    # 파일 확장자 검사
    if not audio_file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="파일 이름이 없습니다"
        )
    
    file_ext = audio_file.filename.split('.')[-1].lower()
    if file_ext not in ["wav", "mp3", "ogg", "flac"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"지원하지 않는 파일 형식입니다: {file_ext}. 지원되는 형식: wav, mp3, ogg, flac"
        )
    
    logger.info(f"감정분석 요청 수신 - 파일: {audio_file.filename}, 크기: {audio_file.size} bytes")
    logger.info(f"요청 파라미터 - 언어: {language}, 시나리오: {scenario}, 가중치 적용: {apply_scenario_weights}")
    
    try:
        # 요청 객체 생성
        request = EmotionAnalysisRequest(
            language=language,
            scenario=scenario,
            apply_scenario_weights=apply_scenario_weights,
            top_k=top_k,
            confidence_threshold=confidence_threshold
        )
        
        # 감정분석 처리
        result = await emotion_processor.process_audio(audio_file, request)
        return result
        
    except Exception as e:
        logger.error(f"감정분석 중 오류 발생: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"감정분석 중 오류 발생: {str(e)}"
        )


@router.post("/analyze_bytes", response_model=EmotionAnalysisResponse)
async def analyze_emotion_bytes(
    request: Request,
    language: str = Query(default="ko", description="언어 코드"),
    scenario: str = Query(default="presentation", description="시나리오 (dating, interview, presentation)"),
    apply_scenario_weights: bool = Query(default=True, description="시나리오별 가중치 적용 여부"),
    top_k: Optional[int] = Query(default=3, ge=1, le=6, description="상위 K개 감정 반환"),
    confidence_threshold: Optional[float] = Query(default=0.5, ge=0.0, le=1.0, description="신뢰도 임계값")
) -> EmotionAnalysisResponse:
    """
    오디오 바이트 데이터 감정분석 (실시간 처리용)
    
    Request body에 오디오 바이너리 데이터를 포함해야 합니다.
    Content-Type: application/octet-stream
    
    - **language**: 언어 코드 (기본값: ko)
    - **scenario**: 시나리오 타입 (dating, interview, presentation)
    - **apply_scenario_weights**: 시나리오별 가중치 적용 여부
    - **top_k**: 상위 K개 감정 반환
    - **confidence_threshold**: 신뢰도 임계값
    
    Returns:
        감정분석 결과와 메타데이터
    """
    try:
        # Request body에서 바이너리 데이터 읽기
        audio_bytes = await request.body()
        
        if not audio_bytes:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="오디오 데이터가 없습니다"
            )
        
        logger.info(f"바이트 데이터 감정분석 요청 수신 - 크기: {len(audio_bytes)} bytes")
        logger.info(f"요청 파라미터 - 언어: {language}, 시나리오: {scenario}, 가중치 적용: {apply_scenario_weights}")
        
        # 요청 객체 생성
        emotion_request = EmotionAnalysisRequest(
            language=language,
            scenario=scenario,
            apply_scenario_weights=apply_scenario_weights,
            top_k=top_k,
            confidence_threshold=confidence_threshold
        )
        
        # 감정분석 처리
        result = await emotion_processor.process_audio_bytes(audio_bytes, emotion_request)
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"바이트 데이터 감정분석 중 오류 발생: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"감정분석 중 오류 발생: {str(e)}"
        ) 