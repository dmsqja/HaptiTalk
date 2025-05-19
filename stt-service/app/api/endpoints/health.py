from fastapi import APIRouter
import torch
from app.core.models import HealthResponse
from app.core.logging import logger
import platform
import sys
import whisperx

router = APIRouter()


@router.get("/health", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    """
    서비스 상태 확인
    
    Returns:
        서비스 상태 정보
    """
    try:
        # 시스템 정보 확인
        cuda_available = torch.cuda.is_available()
        cuda_info = f"CUDA {torch.version.cuda}" if cuda_available else "사용 불가"
        
        logger.info(f"헬스 체크 요청 - CUDA: {cuda_info}")
        
        # 응답 생성
        return HealthResponse(
            status="healthy",
            version=f"whisperx-{whisperx.__version__}"
        )
    except Exception as e:
        logger.error(f"헬스 체크 중 오류 발생: {str(e)}", exc_info=True)
        return HealthResponse(
            status="unhealthy",
            version="unknown"
        ) 