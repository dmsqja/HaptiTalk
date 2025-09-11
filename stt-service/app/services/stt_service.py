import os
import time
import tempfile
from typing import Optional, Dict, Any, List, Tuple, BinaryIO
import torch
import whisperx
import numpy as np
from fastapi import UploadFile
import faster_whisper

from app.core.config import settings
from app.core.logging import logger
from app.core.models import STTResponse, TimestampedWord


class STTProcessor:
    """WhisperX 모델을 사용한 STT 처리 클래스"""
    
    def __init__(self) -> None:
        """STT 프로세서 초기화"""
        self.model = None
        self.device = settings.DEVICE if torch.cuda.is_available() else "cpu"
        self.compute_type = settings.COMPUTE_TYPE
        self.model_name = settings.WHISPER_MODEL
        
        logger.info(f"STT Processor 초기화 - 장치: {self.device}, 연산 타입: {self.compute_type}, 모델: {self.model_name}")
        
    async def load_model(self) -> None:
        """WhisperX 모델 로드 (지연 로딩)"""
        if self.model is None:
            logger.info("WhisperX 모델 로딩 시작...")
            start_time = time.time()
            
            try:
                # 메모리 정리 시도
                if torch.cuda.is_available():
                    torch.cuda.empty_cache()
                
                import gc
                gc.collect()
                
                # 버전 호환성 문제를 해결하기 위해 직접 WhisperModel 생성
                self.model = faster_whisper.WhisperModel(
                    model_size_or_path=self.model_name, 
                    device=self.device,
                    compute_type=self.compute_type,
                    download_root=None,
                    local_files_only=False,
                    cpu_threads=settings.CPU_THREADS,  # 설정에서 가져온 CPU 스레드 수
                    num_workers=settings.MAX_WORKERS  # 설정에서 가져온 작업자 수
                )
                
                load_time = time.time() - start_time
                logger.info(f"WhisperX 모델 로딩 완료 (소요 시간: {load_time:.2f}초)")
            except Exception as e:
                logger.error(f"WhisperX 모델 로딩 실패: {str(e)}", exc_info=True)
                # 실패한 경우 모델 변수 초기화
                self.model = None
                # 메모리 정리 다시 시도
                if torch.cuda.is_available():
                    torch.cuda.empty_cache()
                
                import gc
                gc.collect()
                
                raise RuntimeError(f"모델 로딩 실패: {str(e)}")
    
    async def process_audio(
        self, 
        audio_file: UploadFile, 
        language: Optional[str] = "ko",
        return_timestamps: bool = False,
        compute_type: Optional[str] = None
    ) -> STTResponse:
        """
        오디오 파일 처리 및 음성 인식 수행
        
        Args:
            audio_file: 오디오 파일 객체
            language: 인식할 언어 코드 (기본값: ko)
            return_timestamps: 단어별 타임스탬프 반환 여부
            compute_type: 연산 타입 (float16, float32 등)
            
        Returns:
            STTResponse: 인식 결과
        """
        start_time = time.time()
        
        # 임시 파일 저장
        temp_file_path = await self._save_temp_file(audio_file)
        
        # 임시로 연산 타입 변경이 필요한 경우
        current_compute_type = self.compute_type
        if compute_type and compute_type != self.compute_type:
            self.compute_type = compute_type
            logger.info(f"연산 타입 임시 변경: {current_compute_type} -> {compute_type}")
        
        try:
            # 오디오 처리
            logger.info(f"오디오 파일 처리 시작: {audio_file.filename}")
            
            # 오디오 로드
            audio = whisperx.load_audio(temp_file_path)
            
            # transcribe 매개변수 준비
            transcribe_params = {
                "language": language,
                "beam_size": settings.TRANSCRIBE_PARAMS.get("beam_size", 5),
                "word_timestamps": return_timestamps,
                "vad_filter": settings.TRANSCRIBE_PARAMS.get("vad_filter", True),
                "task": settings.TRANSCRIBE_PARAMS.get("task", "transcribe"),
                "condition_on_previous_text": settings.TRANSCRIBE_PARAMS.get("condition_on_previous_text", True),
            }
            
            # 언어별 초기 프롬프트 적용
            if language in settings.LANGUAGE_PROMPTS:
                transcribe_params["initial_prompt"] = settings.LANGUAGE_PROMPTS[language]
            else:
                transcribe_params["initial_prompt"] = settings.TRANSCRIBE_PARAMS.get("initial_prompt", "")
                
            # VAD 파라미터가 설정되어 있으면 추가
            if "vad_parameters" in settings.TRANSCRIBE_PARAMS:
                transcribe_params["vad_parameters"] = settings.TRANSCRIBE_PARAMS["vad_parameters"]
            
            # 로그 추가
            logger.debug(f"Transcribe 매개변수: {transcribe_params}")
            
            # faster-whisper 모델 사용 방식으로 변경
            segments, info = self.model.transcribe(audio, **transcribe_params)
            
            # 결과 수집
            segments_list = list(segments)  # 제너레이터를 리스트로 변환
            
            # 세그먼트 텍스트 추출
            segment_texts = [segment.text for segment in segments_list]
            full_text = " ".join(segment_texts)
            
            # 환각 필터링
            if settings.HALLUCINATION_PATTERNS and full_text:
                original_text = full_text
                for pattern in settings.HALLUCINATION_PATTERNS:
                    if pattern.lower() in full_text.lower():
                        full_text = full_text.lower().replace(pattern.lower(), "").strip()
                
                if original_text != full_text:
                    logger.info(f"환각 패턴 필터링 적용: '{original_text}' -> '{full_text}'")
            
            # 단어 정렬 및 타임스탬프 처리
            words_list = None
            if return_timestamps and segments_list:
                words_data = []
                for segment in segments_list:
                    if hasattr(segment, 'words') and segment.words:
                        for word in segment.words:
                            words_data.append({
                                "word": word.word,
                                "start": word.start,
                                "end": word.end,
                                "probability": word.probability
                            })
                
                # TimestampedWord 형식으로 변환
                words_list = [
                    TimestampedWord(
                        word=word["word"],
                        start=word["start"],
                        end=word["end"],
                        probability=word.get("probability", 1.0)
                    )
                    for word in words_data
                ]
            
            # 오디오 길이 계산
            audio_duration = len(audio) / whisperx.audio.SAMPLE_RATE
            
            processing_time = time.time() - start_time
            logger.info(f"오디오 처리 완료 (소요 시간: {processing_time:.2f}초, 오디오 길이: {audio_duration:.2f}초)")
            
            # 응답 생성
            response = STTResponse(
                text=full_text,
                language=info.language,
                words=words_list,
                duration=audio_duration,
                processing_time=processing_time
            )
            
            return response
            
        finally:
            # 임시 파일 삭제
            if os.path.exists(temp_file_path):
                os.remove(temp_file_path)
            
            # 원래 계산 타입으로 복원
            if compute_type:
                self.compute_type = current_compute_type
    
    async def _save_temp_file(self, file: UploadFile) -> str:
        """
        업로드된 파일을 임시 파일로 저장
        
        Args:
            file: 업로드된 파일
            
        Returns:
            임시 파일 경로
        """
        # 임시 파일 생성
        temp_file = tempfile.NamedTemporaryFile(delete=False, dir=settings.TEMP_AUDIO_DIR, suffix=f".{file.filename.split('.')[-1]}")
        
        # 파일 내용 쓰기
        content = await file.read()
        temp_file.write(content)
        temp_file.close()
        
        return temp_file.name


# 싱글톤 인스턴스 생성
stt_processor = STTProcessor() 