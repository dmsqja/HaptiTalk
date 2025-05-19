from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, status, BackgroundTasks, WebSocket, Query
from fastapi.responses import StreamingResponse
from typing import Optional

from app.core.models import STTRequest, STTResponse
from app.services.stt_service import stt_processor
from app.services.websocket_service import websocket_manager
from app.core.logging import logger

router = APIRouter()


@router.post("/transcribe", response_model=STTResponse)
async def transcribe_audio(
    audio_file: UploadFile = File(...),
    request: STTRequest = Depends()
) -> STTResponse:
    """
    오디오 파일을 텍스트로 변환
    
    - **audio_file**: 업로드할 오디오 파일 (WAV, MP3, OGG, FLAC)
    - **language**: 인식할 언어 코드 (기본값: ko)
    - **return_timestamps**: 단어별 타임스탬프 반환 여부
    - **compute_type**: 연산 타입 (float16, float32 등)
    
    Returns:
        인식된 텍스트와 메타데이터
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
    
    try:
        # STT 처리
        result = await stt_processor.process_audio(
            audio_file=audio_file,
            language=request.language,
            return_timestamps=request.return_timestamps,
            compute_type=request.compute_type
        )
        return result
    except Exception as e:
        logger.error(f"음성 인식 중 오류 발생: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"음성 인식 중 오류 발생: {str(e)}"
        )


@router.websocket("/stream")
async def websocket_endpoint(
    websocket: WebSocket,
    language: str = Query("ko", description="인식할 언어 코드 (예: ko, en)")
):
    """
    실시간 음성 인식을 위한 WebSocket 엔드포인트
    
    클라이언트는 다음과 같은 메시지를 주고받을 수 있습니다:
    
    1. 텍스트 메시지 (명령어):
       - "start": 인식 시작
       - "stop": 인식 중지
       - "language:CODE": 언어 변경 (예: "language:en")
    
    2. 바이너리 메시지:
       - 오디오 데이터 (16kHz, 16-bit PCM, 모노)
    
    서버 응답:
    - {"type": "connected", "message": "...", "connection_id": "..."}
    - {"type": "status", "message": "..."}
    - {"type": "transcription", "text": "...", "is_final": bool, "segment_id": int}
    - {"type": "error", "message": "..."}
    """
    await websocket_manager.handle_connection(websocket, language) 