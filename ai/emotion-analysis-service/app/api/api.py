from fastapi import APIRouter

from app.api.endpoints import emotion, health

api_router = APIRouter()

# 감정분석 엔드포인트
api_router.include_router(emotion.router, prefix="/emotion", tags=["emotion"])

# 헬스체크 엔드포인트
api_router.include_router(health.router, prefix="/health", tags=["health"]) 