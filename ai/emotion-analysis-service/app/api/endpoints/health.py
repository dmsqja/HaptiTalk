from fastapi import APIRouter, HTTPException, status
import time
import torch

from app.core.models import HealthCheckResponse
from app.services.emotion_service import emotion_processor
from app.core.config import settings
from app.core.logging import logger
from app import __version__

router = APIRouter()

# 서비스 시작 시간
_service_start_time = time.time()


@router.get("/", response_model=HealthCheckResponse)
async def health_check() -> HealthCheckResponse:
    """
    서비스 헬스체크
    
    Returns:
        서비스 상태 정보
    """
    try:
        # 모델 로딩 상태 확인
        model_loaded = (
            emotion_processor.model is not None and 
            emotion_processor.processor is not None
        )
        
        # 업타임 계산
        uptime = time.time() - _service_start_time
        
        # 디바이스 정보
        device = "cuda" if torch.cuda.is_available() else "cpu"
        if torch.cuda.is_available():
            device_info = f"cuda ({torch.cuda.get_device_name()})"
        else:
            device_info = "cpu"
        
        return HealthCheckResponse(
            status="healthy",
            version=__version__,
            model_loaded=model_loaded,
            model_name=settings.EMOTION_MODEL,
            device=device_info,
            uptime=uptime
        )
        
    except Exception as e:
        logger.error(f"헬스체크 중 오류 발생: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"헬스체크 실패: {str(e)}"
        )


@router.get("/ready")
async def readiness_check():
    """
    서비스 준비 상태 확인 (모델 로딩 완료 여부)
    
    Returns:
        준비 상태 정보
    """
    try:
        # 모델이 로딩되어 있지 않으면 로딩 시도
        if emotion_processor.model is None or emotion_processor.processor is None:
            logger.info("헬스체크에서 모델 로딩 시작...")
            await emotion_processor.load_model()
        
        return {
            "status": "ready",
            "message": "서비스가 준비되었습니다",
            "model_loaded": True
        }
        
    except Exception as e:
        logger.error(f"준비 상태 확인 중 오류 발생: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"서비스가 준비되지 않았습니다: {str(e)}"
        )


@router.get("/live")
async def liveness_check():
    """
    서비스 생존 상태 확인
    
    Returns:
        생존 상태 정보
    """
    return {
        "status": "alive",
        "message": "서비스가 실행 중입니다",
        "timestamp": time.time()
    } 