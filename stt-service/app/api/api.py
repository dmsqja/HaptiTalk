from fastapi import APIRouter
from app.api.endpoints import stt, health
from app.core.config import settings

# API 라우터 생성
api_router = APIRouter()

# 엔드포인트 라우터 등록
api_router.include_router(stt.router, prefix="/stt", tags=["stt"])
api_router.include_router(health.router, prefix="", tags=["health"]) 