import asyncio
import json
import time
import uuid
from typing import Dict, List, Any, Optional, Callable, Awaitable
import numpy as np
import whisperx
from fastapi import WebSocket, WebSocketDisconnect
from starlette.websockets import WebSocketState

from app.core.logging import logger
from app.core.config import settings
from app.services.stt_service import stt_processor


class ConnectionManager:
    """
    WebSocket 연결 관리 클래스
    """
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
        
    async def connect(self, websocket: WebSocket) -> str:
        """
        새 WebSocket 연결 수립
        
        Args:
            websocket: WebSocket 인스턴스
            
        Returns:
            생성된 연결 ID
        """
        # 고유 연결 ID 생성
        connection_id = str(uuid.uuid4())
        
        # 연결 수락
        await websocket.accept()
        
        # 활성 연결에 추가
        self.active_connections[connection_id] = websocket
        
        logger.info(f"WebSocket 연결 수립: {connection_id}")
        return connection_id
    
    def disconnect(self, connection_id: str) -> None:
        """
        WebSocket 연결 종료
        
        Args:
            connection_id: 연결 ID
        """
        if connection_id in self.active_connections:
            logger.info(f"WebSocket 연결 종료: {connection_id}")
            del self.active_connections[connection_id]
    
    async def send_text(self, connection_id: str, message: str) -> None:
        """
        텍스트 메시지 전송
        
        Args:
            connection_id: 연결 ID
            message: 전송할 텍스트 메시지
        """
        if connection_id in self.active_connections:
            try:
                websocket = self.active_connections[connection_id]
                if websocket.client_state == WebSocketState.CONNECTED:
                    await websocket.send_text(message)
                else:
                    logger.warning(f"연결이 닫힌 상태입니다: {connection_id}")
                    self.disconnect(connection_id)
            except Exception as e:
                logger.error(f"메시지 전송 실패: {connection_id} - {str(e)}")
                self.disconnect(connection_id)
    
    async def send_json(self, connection_id: str, data: Dict[str, Any]) -> None:
        """
        JSON 메시지 전송
        
        Args:
            connection_id: 연결 ID
            data: 전송할 JSON 데이터
        """
        if connection_id in self.active_connections:
            try:
                await self.send_text(connection_id, json.dumps(data))
            except Exception as e:
                logger.error(f"JSON 메시지 전송 실패: {connection_id} - {str(e)}")
                self.disconnect(connection_id)


class STTWebSocketManager:
    """
    STT 웹소켓 관리 클래스
    """
    def __init__(self):
        self.connection_manager = ConnectionManager()
        self.sessions: Dict[str, Dict[str, Any]] = {}
        
    async def handle_connection(self, websocket: WebSocket, language: str = "ko") -> None:
        """
        WebSocket 연결 처리
        
        Args:
            websocket: WebSocket 연결
            language: 인식 언어
        """
        connection_id = await self.connection_manager.connect(websocket)
        
        # 세션 초기화
        self.sessions[connection_id] = {
            "buffer": bytearray(),
            "last_chunk_time": time.time(),
            "is_processing": False,
            "language": language,
            "segment_count": 0,
            "last_transcription": "",  # 이전 인식 결과 저장
            "is_first_segment": True   # 첫 번째 세그먼트 여부
        }
        
        try:
            # STT 모델이 로드되지 않았다면 로드
            if stt_processor.model is None:
                logger.info("WhisperX 모델 로딩 시작...")
                try:
                    await stt_processor.load_model()
                    logger.info("WhisperX 모델 로딩 완료")
                except Exception as e:
                    # 모델 로딩 실패 시 클라이언트에게 오류 메시지 전송
                    await self.connection_manager.send_json(connection_id, {
                        "type": "error",
                        "message": f"모델 로딩 실패: {str(e)}"
                    })
                    # 클라이언트 연결 종료
                    raise
            else:
                logger.info("WhisperX 모델이 이미 로드되어 있습니다.")
                
            # 환영 메시지 전송
            await self.connection_manager.send_json(connection_id, {
                "type": "connected",
                "message": "STT 서비스에 연결되었습니다. 오디오 데이터를 전송해주세요.",
                "connection_id": connection_id
            })
            
            # 메시지 수신 대기
            while True:
                try:
                    # 메시지 수신
                    message = await websocket.receive()
                    
                    # 텍스트 메시지인 경우 (명령)
                    if "text" in message:
                        text_data = message["text"]
                        try:
                            data = json.loads(text_data)
                            if "command" in data:
                                command = data["command"]
                                
                                # 최종 처리 명령인 경우
                                if command == "process_final":
                                    logger.info(f"최종 처리 요청 수신: {connection_id}")
                                    
                                    # 버퍼에 있는 데이터 최종 처리
                                    await self._process_audio_buffer(connection_id, is_final=True)
                                    
                                    # 결과 전송 완료 메시지
                                    await self.connection_manager.send_json(connection_id, {
                                        "type": "processing_complete",
                                        "message": "오디오 처리가 완료되었습니다."
                                    })
                                
                                # 언어 설정 명령인 경우
                                elif command == "set_language" and "language" in data:
                                    new_language = data["language"]
                                    
                                    # 세션 언어 업데이트
                                    if connection_id in self.sessions:
                                        old_language = self.sessions[connection_id]["language"]
                                        self.sessions[connection_id]["language"] = new_language
                                        # 새 언어로 전환할 때 첫 번째 세그먼트 플래그 설정
                                        self.sessions[connection_id]["is_first_segment"] = True
                                        
                                        logger.info(f"언어 변경: {connection_id} - {old_language} -> {new_language}")
                                        
                                        # 클라이언트에게 언어 변경 확인 메시지 전송
                                        await self.connection_manager.send_json(connection_id, {
                                            "type": "language_changed",
                                            "language": new_language,
                                            "message": f"인식 언어가 변경되었습니다: {new_language}"
                                        })
                                
                                # 버퍼 초기화 명령인 경우
                                elif command == "reset":
                                    if connection_id in self.sessions:
                                        # 버퍼 비우기
                                        session = self.sessions[connection_id]
                                        session["buffer"] = bytearray()
                                        session["segment_count"] = 0
                                        session["last_transcription"] = ""
                                        session["is_first_segment"] = True
                                        
                                        logger.info(f"버퍼 초기화: {connection_id}")
                                        
                                        # 클라이언트에게 초기화 확인 메시지 전송
                                        await self.connection_manager.send_json(connection_id, {
                                            "type": "reset_complete",
                                            "message": "버퍼가 초기화되었습니다."
                                        })
                                
                        except json.JSONDecodeError:
                            # 유효하지 않은 JSON 형식
                            logger.warning(f"잘못된 JSON 형식: {connection_id} - {text_data}")
                    
                    # 바이너리 메시지인 경우 (오디오 데이터)
                    elif "bytes" in message:
                        binary_data = message["bytes"]
                        
                        # 오디오 데이터 처리
                        if connection_id in self.sessions:
                            session = self.sessions[connection_id]
                            
                            # 데이터 버퍼에 추가
                            session["buffer"].extend(binary_data)
                            session["last_chunk_time"] = time.time()
                            
                            # 버퍼 크기 확인 및 처리
                            # 5초 분량의 오디오 데이터 (16kHz, 16-bit, mono = 2바이트 * 16000 * 5 = 160000바이트)
                            buffer_threshold = min(160000, settings.MAX_AUDIO_BUFFER_MB * 1024 * 1024)
                            
                            if len(session["buffer"]) >= buffer_threshold and not session["is_processing"]:
                                # 병렬로 처리
                                asyncio.create_task(self._process_audio_buffer(connection_id))
                
                except WebSocketDisconnect:
                    # 연결이 종료된 경우
                    break
                except Exception as e:
                    # 기타 예외 처리
                    logger.error(f"메시지 수신 중 오류 발생: {connection_id} - {str(e)}", exc_info=True)
                    # 오류 메시지 전송
                    await self.connection_manager.send_json(connection_id, {
                        "type": "error",
                        "message": f"오류가 발생했습니다: {str(e)}"
                    })
                    break
        
        finally:
            # 세션 정리
            if connection_id in self.sessions:
                del self.sessions[connection_id]
            
            # 연결 종료
            self.connection_manager.disconnect(connection_id)
    
    async def _process_audio_buffer(self, connection_id: str, is_final: bool = False) -> None:
        """
        오디오 버퍼 처리
        
        Args:
            connection_id: 연결 ID
            is_final: 최종 처리 여부
        """
        if connection_id not in self.sessions:
            return
        
        session = self.sessions[connection_id]
        
        # 이미 처리 중인 경우 반환
        if session["is_processing"]:
            return
        
        # 처리 중 플래그 설정
        session["is_processing"] = True
        
        try:
            # 버퍼에 데이터가 있는지 확인
            if len(session["buffer"]) == 0:
                session["is_processing"] = False
                return
            
            # 버퍼에서 데이터 가져오기
            if is_final:
                # 최종 처리인 경우 모든 데이터 사용
                audio_data = bytes(session["buffer"])
                session["buffer"] = bytearray()
            else:
                # 일부 처리인 경우 버퍼 앞부분 사용
                buffer_size = len(session["buffer"])
                use_size = min(buffer_size, settings.MAX_AUDIO_BUFFER_MB * 1024 * 1024)
                
                audio_data = bytes(session["buffer"][:use_size])
                session["buffer"] = session["buffer"][use_size:]
                
            try:
                # 바이너리 데이터를 numpy 배열로 변환
                # 16-bit PCM, 단일 채널 오디오 가정
                audio_np = np.frombuffer(audio_data, dtype=np.int16).astype(np.float32) / 32768.0
                
                # 오디오 데이터가 충분한지 확인
                if len(audio_np) < 512:  # 너무 짧은 오디오는 처리하지 않음
                    session["is_processing"] = False
                    return
                    
                # WhisperX 처리
                segment_id = session["segment_count"]
                session["segment_count"] += 1
                
                # 실제 STT 처리
                if stt_processor.model is not None:
                    try:
                        # 실시간 처리를 위한 transcribe 매개변수 준비
                        transcribe_params = {
                            "language": session["language"],
                            "beam_size": settings.TRANSCRIBE_PARAMS.get("beam_size", 5),
                            "word_timestamps": True,  # 실시간 처리에서는, 단어 타임스탬프가 필요
                            "vad_filter": settings.TRANSCRIBE_PARAMS.get("vad_filter", True),
                            "task": settings.TRANSCRIBE_PARAMS.get("task", "transcribe"),
                            "condition_on_previous_text": settings.TRANSCRIBE_PARAMS.get("condition_on_previous_text", True),
                        }
                        
                        # 언어별 초기 프롬프트 적용 (첫 번째 세그먼트인 경우에만)
                        if session["is_first_segment"]:
                            language = session["language"]
                            if language in settings.LANGUAGE_PROMPTS:
                                transcribe_params["initial_prompt"] = settings.LANGUAGE_PROMPTS[language]
                            else:
                                transcribe_params["initial_prompt"] = settings.TRANSCRIBE_PARAMS.get("initial_prompt", "")
                            
                            # 첫 번째 세그먼트 플래그 해제
                            session["is_first_segment"] = False
                        elif session["last_transcription"]:
                            # 이전 인식 결과를 초기 프롬프트로 사용하여 연속성 보장
                            transcribe_params["initial_prompt"] = session["last_transcription"]
                        
                        # VAD 파라미터 추가
                        if "vad_parameters" in settings.TRANSCRIBE_PARAMS:
                            transcribe_params["vad_parameters"] = settings.TRANSCRIBE_PARAMS["vad_parameters"]
                        
                        logger.debug(f"WebSocket Transcribe 매개변수: {transcribe_params}")
                        
                        # 타임아웃 설정 - 10초 이상 걸리면 취소
                        segments, info = await asyncio.wait_for(
                            asyncio.get_event_loop().run_in_executor(None, lambda: stt_processor.model.transcribe(
                                audio_np, **transcribe_params
                            )),
                            timeout=10
                        )
                        
                        # 결과 수집 및 후처리
                        segments_list = list(segments)
                        
                        # 결과 텍스트 추출
                        text = ""
                        for segment in segments_list:
                            if hasattr(segment, 'text'):
                                text += segment.text + " "
                        
                        text = text.strip()
                        
                        # 환각 필터링
                        if settings.HALLUCINATION_PATTERNS and text:
                            original_text = text
                            for pattern in settings.HALLUCINATION_PATTERNS:
                                if pattern.lower() in text.lower():
                                    logger.warning(f"환각 감지 및 제거: '{pattern}' in '{text}'")
                                    text = text.lower().replace(pattern.lower(), "").strip()
                            
                            if original_text != text:
                                logger.info(f"환각 패턴 필터링 적용: '{original_text}' -> '{text}'")
                        
                        if not text:
                            session["is_processing"] = False
                            return
                        
                        # 현재 인식 결과 저장 (다음 세그먼트의 프롬프트로 사용)
                        session["last_transcription"] = text
                        
                        # 말하기 속도 계산
                        speaking_rate = 0
                        word_count = 0
                        duration = 0
                        
                        if segments_list:
                            # 전체 단어 수 계산
                            for segment in segments_list:
                                if hasattr(segment, 'words') and segment.words:
                                    word_count += len(segment.words)
                            
                            # 오디오 길이 계산 (초 단위)
                            duration = len(audio_np) / whisperx.audio.SAMPLE_RATE
                            
                            # 분당 단어 수 계산 (WPM)
                            if duration > 0:
                                speaking_rate = word_count / duration * 60
                            
                            # 말하기 속도 평가
                            speed_assessment = "보통"
                            if speaking_rate > 0:
                                if speaking_rate < 130:
                                    speed_assessment = "느림"
                                elif speaking_rate > 160:
                                    speed_assessment = "빠름"
                            
                            # 결과 전송
                            try:
                                result_data = {
                                    "type": "transcription",
                                    "text": text,
                                    "is_final": is_final,
                                    "segment_id": segment_id,
                                    "speaking_rate": speaking_rate,
                                    "speed_assessment": speed_assessment,
                                    "segments": [{"text": s.text, "start": s.start, "end": s.end} for s in segments_list],
                                    "language": info.language,  # 감지된 언어 정보 추가
                                    "language_probability": info.language_probability,  # 언어 감지 확률 추가
                                }
                                
                                # 단어 수준 타임스탬프 정보 추가
                                words_with_timestamps = []
                                for segment in segments_list:
                                    if hasattr(segment, 'words') and segment.words:
                                        for word in segment.words:
                                            words_with_timestamps.append({
                                                "word": word.word,
                                                "start": word.start,
                                                "end": word.end,
                                                "probability": word.probability
                                            })
                                
                                if words_with_timestamps:
                                    result_data["words"] = words_with_timestamps
                                
                                await self.connection_manager.send_json(connection_id, result_data)
                                
                                logger.debug(f"문장 인식 결과: {connection_id} -> {text} (말하기 속도: {speaking_rate} WPM, 평가: {speed_assessment})")
                            except (RuntimeError, WebSocketDisconnect) as e:
                                logger.info(f"결과 전송 중 연결 종료: {connection_id} - {str(e)}")
                                return
                                
                    except asyncio.TimeoutError:
                        # 처리 시간 초과
                        logger.warning(f"오디오 처리 시간 초과: {connection_id}")
                        try:
                            await self.connection_manager.send_json(connection_id, {
                                "type": "error",
                                "message": "오디오 처리 시간이 초과되었습니다."
                            })
                        except:
                            pass
                    except Exception as e:
                        # 기타 오류
                        logger.error(f"오디오 처리 중 오류 발생: {connection_id} - {str(e)}", exc_info=True)
                        try:
                            await self.connection_manager.send_json(connection_id, {
                                "type": "error",
                                "message": f"오디오 처리 중 오류 발생: {str(e)}"
                            })
                        except:
                            pass
                else:
                    logger.error(f"STT 모델이 초기화되지 않았습니다: {connection_id}")
                    try:
                        await self.connection_manager.send_json(connection_id, {
                            "type": "error",
                            "message": "STT 모델이 초기화되지 않았습니다."
                        })
                    except:
                        pass
            except Exception as e:
                logger.error(f"오디오 데이터 변환 중 오류 발생: {connection_id} - {str(e)}", exc_info=True)
                try:
                    await self.connection_manager.send_json(connection_id, {
                        "type": "error",
                        "message": f"오디오 데이터 변환 중 오류 발생: {str(e)}"
                    })
                except:
                    pass
        finally:
            # 처리 완료 플래그 설정
            session["is_processing"] = False


# 싱글톤 인스턴스 생성
websocket_manager = STTWebSocketManager() 