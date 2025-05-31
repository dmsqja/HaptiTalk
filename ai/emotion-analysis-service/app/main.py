import time
import os
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import asyncio

from app.api.api import api_router
from app.core.config import settings
from app.core.logging import logger
from app import __version__
from app.services.emotion_service import emotion_processor

# FastAPI 애플리케이션 생성
app = FastAPI(
    title=settings.PROJECT_NAME,
    description="한국어 음성 감정분석 서비스",
    version=__version__,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url=f"{settings.API_V1_STR}/docs",
    redoc_url=f"{settings.API_V1_STR}/redoc",
)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 모든 오리진 허용 (프로덕션에서는 제한 필요)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API 라우터 등록
app.include_router(api_router, prefix=settings.API_V1_STR)

# 미들웨어 - 요청 처리 시간 측정
@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = str(process_time)
    return response

# 애플리케이션 시작 이벤트
@app.on_event("startup")
async def startup_event():
    logger.info(f"감정분석 서비스 시작 - 버전: {__version__}")
    
    # 서버 시작 시 감정분석 모델 미리 로드
    try:
        logger.info("서버 시작 시 감정분석 모델 사전 로딩 중...")
        await emotion_processor.load_model()
        logger.info("감정분석 모델 사전 로딩 완료")
    except Exception as e:
        logger.error(f"감정분석 모델 사전 로딩 실패: {str(e)}", exc_info=True)
        logger.warning("감정분석 모델 로딩 실패했지만 서버는 계속 실행됩니다. 첫 요청 시 다시 로드를 시도합니다.")

# 애플리케이션 종료 이벤트
@app.on_event("shutdown")
async def shutdown_event():
    logger.info("감정분석 서비스 종료")

# 루트 엔드포인트
@app.get("/")
def read_root():
    return {
        "message": "감정분석 서비스에 오신 것을 환영합니다", 
        "version": __version__,
        "model": settings.EMOTION_MODEL
    }


if __name__ == "__main__":
    # 개발 서버 실행
    uvicorn.run("app.main:app", host="0.0.0.0", port=8001, reload=True) 