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
                    cpu_threads=settings.CPU_THREADS,
                    num_workers=settings.MAX_WORKERS
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
    
    def _prepare_transcribe_params(self, language: str, scenario: str, return_timestamps: bool) -> Dict[str, Any]:
        """
        시나리오별 Transcribe 매개변수 준비
        
        Args:
            language: 인식할 언어 코드
            scenario: 시나리오 타입 (dating, interview, presentation)
            return_timestamps: 단어별 타임스탬프 반환 여부
            
        Returns:
            설정된 매개변수 딕셔너리
        """
        # 시나리오별 VAD 파라미터 적용
        vad_params = settings.SCENARIO_VAD_PARAMS.get(scenario, settings.TRANSCRIBE_PARAMS["vad_parameters"])
        
        transcribe_params = {
            "language": language,
            "beam_size": 5 if scenario != "interview" else 10,  # 면접은 더 정확하게
            "word_timestamps": return_timestamps,
            "vad_filter": settings.TRANSCRIBE_PARAMS.get("vad_filter", True),
            "task": settings.TRANSCRIBE_PARAMS.get("task", "transcribe"),
            "condition_on_previous_text": settings.TRANSCRIBE_PARAMS.get("condition_on_previous_text", True),
            "vad_parameters": vad_params
        }
        
        logger.debug(f"Transcribe 매개변수 (시나리오: {scenario}): {transcribe_params}")
        return transcribe_params
    
    def _extract_word_timestamps(self, segments_list) -> List[TimestampedWord]:
        """
        단어 타임스탬프 추출
        
        Args:
            segments_list: 세그먼트 목록
            
        Returns:
            타임스탬프가 있는 단어 목록
        """
        if not segments_list:
            return None
            
        logger.info("단어 타임스탬프 처리 시작")
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
        
        logger.info(f"단어 타임스탬프 처리 완료. 총 {len(words_list)}개 단어")
        return words_list
    
    async def process_audio(
        self, 
        audio_file: UploadFile, 
        language: Optional[str] = "ko",
        scenario: str = "presentation",
        return_timestamps: bool = False,
        compute_type: Optional[str] = None
    ) -> STTResponse:
        """
        오디오 파일 처리 및 음성 인식 수행
        
        Args:
            audio_file: 오디오 파일 객체
            language: 인식할 언어 코드 (기본값: ko)
            scenario: 시나리오 타입 (dating, interview, presentation)
            return_timestamps: 단어별 타임스탬프 반환 여부
            compute_type: 연산 타입 (float16, float32 등)
            
        Returns:
            STTResponse: 인식 결과
        """
        start_time = time.time()
        
        # 임시 파일 저장
        temp_file_path = await self._save_temp_file(audio_file)
        
        logger.info(f"임시 파일 저장 완료: {temp_file_path}, 파일명: {audio_file.filename}")
        
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
            
            logger.info(f"오디오 로드 완료. 오디오 길이: {len(audio) / settings.SAMPLE_RATE:.2f}초")
            
            # transcribe 매개변수 준비
            transcribe_params = self._prepare_transcribe_params(language, scenario, return_timestamps)
            
            # 모델 추론
            segments, info = self.model.transcribe(audio, **transcribe_params)
            logger.info(f"모델 추론 완료. 감지된 언어: {info.language}, 확률: {info.language_probability:.2f}")
            
            # 결과 수집
            segments_list = list(segments)  # 제너레이터를 리스트로 변환
            
            # 세그먼트 텍스트 추출
            segment_texts = [segment.text for segment in segments_list]
            full_text = " ".join(segment_texts)
            
            # 단어 정렬 및 타임스탬프 처리
            words_list = None
            if return_timestamps and segments_list:
                words_list = self._extract_word_timestamps(segments_list)
            
            # 오디오 길이 계산
            audio_duration = len(audio) / settings.SAMPLE_RATE
            
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
            
            logger.info(f"STT 응답 생성 완료. 최종 텍스트 길이: {len(full_text)}")
            logger.debug(f"STT 응답 객체: {response.model_dump_json(indent=2)}")
            
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