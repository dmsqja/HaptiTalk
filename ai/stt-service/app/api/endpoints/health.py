from fastapi import APIRouter
import torch
from app.core.models import HealthResponse
from app.core.logging import logger
import platform
import sys
import whisperx

router = APIRouter()


def get_whisperx_version() -> str:
    """
    WhisperX 버전을 안전하게 가져오기
    
    Returns:
        WhisperX 버전 문자열
    """
    # 방법 1: __version__ 속성 확인
    try:
        if hasattr(whisperx, '__version__'):
            return whisperx.__version__
    except:
        pass
    
    # 방법 2: importlib.metadata 사용 (Python 3.8+)
    try:
        from importlib.metadata import version as get_version
        return get_version('whisperx')
    except Exception:
        pass
        
    # 방법 3: pkg_resources 사용 (레거시)
    try:
        import pkg_resources
        return pkg_resources.get_distribution('whisperx').version
    except Exception:
        pass
    
    # 방법 4: 모듈 경로 기반 추정
    try:
        module_path = whisperx.__file__
        if 'site-packages' in module_path:
            return "installed"
        else:
            return "dev"
    except Exception:
        pass
    
    return "unknown"


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
        
        # WhisperX 버전 확인
        whisperx_version = get_whisperx_version()
        
        logger.info(f"헬스 체크 요청 - CUDA: {cuda_info}, WhisperX: {whisperx_version}")
        
        # 응답 생성
        return HealthResponse(
            status="healthy",
            version=f"whisperx-{whisperx_version}"
        )
    except Exception as e:
        logger.error(f"헬스 체크 중 오류 발생: {str(e)}", exc_info=True)
        return HealthResponse(
            status="unhealthy",
            version="unknown"
        ) 