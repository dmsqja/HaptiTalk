import os
import time
import tempfile
from typing import Optional, Dict, Any, List, BinaryIO
import torch
import librosa
import numpy as np
from transformers import AutoProcessor, AutoModelForAudioClassification
from fastapi import UploadFile
import random

from app.core.config import settings
from app.core.logging import logger
from app.core.models import (
    EmotionAnalysisResponse, 
    EmotionPrediction, 
    EmotionLabel,
    EmotionAnalysisRequest
)


class EmotionProcessor:
    """Wav2Vec2 모델을 사용한 감정분석 처리 클래스"""
    
    def __init__(self) -> None:
        """감정분석 프로세서 초기화"""
        self.model = None
        self.processor = None
        self.device = settings.DEVICE if torch.cuda.is_available() else "cpu"
        self.model_name = settings.EMOTION_MODEL
        
        # 재현성을 위한 seed 설정
        self._set_seeds()
        
        logger.info(f"감정분석 프로세서 초기화 - 장치: {self.device}, 모델: {self.model_name}")
        
    def _set_seeds(self, seed: int = 42) -> None:
        """재현성을 위한 시드 설정"""
        torch.manual_seed(seed)
        torch.cuda.manual_seed_all(seed)
        np.random.seed(seed)
        random.seed(seed)
        
        if torch.cuda.is_available():
            torch.backends.cudnn.deterministic = True
            torch.backends.cudnn.benchmark = False
    
    async def load_model(self) -> None:
        """감정분석 모델 로드"""
        if self.model is not None:
            logger.info("모델이 이미 로드되어 있습니다")
            return
        
        try:
            logger.info(f"감정분석 모델 로딩 시작: {self.model_name}")
            logger.info(f"디바이스: {self.device}")
            
            # Processor 로드
            self.processor = AutoProcessor.from_pretrained(
                self.model_name,
                cache_dir=".cache/transformers"
            )
            
            # Model 로드
            self.model = AutoModelForAudioClassification.from_pretrained(
                self.model_name,
                cache_dir=".cache/transformers"
            )
            
            # GPU로 이동
            self.model.to(self.device)
            self.model.eval()
            
            # 모델 라벨 매핑 디버그 출력
            logger.info(f"모델 라벨 매핑: {self.model.config.id2label}")
            
            # 한국어-영어 라벨 매핑 생성 (실제 모델 출력에 맞춤)
            self.label_mapping = {
                "기쁨": "happy",
                "당황": "confused",
                "분노": "angry", 
                "불안": "fearful",
                "슬픔": "sad",
                "중립": "neutral"
            }
            
            logger.info(f"한국어-영어 라벨 매핑: {self.label_mapping}")
            logger.info("감정분석 모델 로딩 완료")
            
        except Exception as e:
            logger.error(f"모델 로딩 중 오류 발생: {str(e)}", exc_info=True)
            raise RuntimeError(f"모델 로딩 실패: {str(e)}")
    
    def _preprocess_audio(self, audio_file_path: str) -> np.ndarray:
        """
        오디오 파일 전처리
        
        Args:
            audio_file_path: 오디오 파일 경로
            
        Returns:
            전처리된 오디오 배열
        """
        # 오디오 로드 (16kHz로 리샘플링, 모노)
        speech, sampling_rate = librosa.load(
            audio_file_path, 
            sr=settings.SAMPLE_RATE, 
            mono=True
        )
        
        # 오디오 길이 제한
        max_samples = settings.MAX_AUDIO_LENGTH * settings.SAMPLE_RATE
        if len(speech) > max_samples:
            speech = speech[:max_samples]
            logger.warning(f"오디오가 {settings.MAX_AUDIO_LENGTH}초로 잘렸습니다.")
        
        # 오디오 정규화
        if settings.AUDIO_NORMALIZE and np.max(np.abs(speech)) > 0:
            speech = speech / np.max(np.abs(speech))
        
        logger.debug(f"오디오 전처리 완료 - 길이: {len(speech)/settings.SAMPLE_RATE:.2f}초, 샘플링 레이트: {sampling_rate}")
        
        return speech
    
    def _apply_scenario_weights(
        self, 
        probabilities: torch.Tensor, 
        scenario: str
    ) -> torch.Tensor:
        """
        시나리오별 가중치 적용
        
        Args:
            probabilities: 원본 확률 텐서
            scenario: 시나리오명
            
        Returns:
            가중치가 적용된 확률 텐서
        """
        if scenario not in settings.SCENARIO_WEIGHTS:
            logger.warning(f"알 수 없는 시나리오: {scenario}. 가중치를 적용하지 않습니다.")
            return probabilities
        
        weights = settings.SCENARIO_WEIGHTS[scenario]
        weighted_probs = probabilities.clone()
        
        # 각 감정에 가중치 적용
        for i, emotion_id in enumerate(self.model.config.id2label.keys()):
            emotion_label_kr = self.model.config.id2label[emotion_id]  # 한국어 라벨
            emotion_label_en = self.label_mapping.get(emotion_label_kr, emotion_label_kr)  # 영어 라벨로 변환
            
            if emotion_label_en in weights:
                weighted_probs[0][i] *= weights[emotion_label_en]
                logger.debug(f"가중치 적용: {emotion_label_kr} -> {emotion_label_en} (x{weights[emotion_label_en]})")
        
        # 재정규화
        weighted_probs = torch.nn.functional.softmax(weighted_probs, dim=-1)
        
        logger.debug(f"시나리오별 가중치 적용 완료 - 시나리오: {scenario}")
        
        return weighted_probs
    
    def _create_emotion_predictions(
        self, 
        probabilities: torch.Tensor,
        apply_scenario_weights: bool = True,
        scenario: str = "presentation",
        top_k: int = 3
    ) -> tuple[List[EmotionPrediction], List[EmotionPrediction], EmotionPrediction]:
        """
        감정 예측 결과 생성
        
        Args:
            probabilities: 모델 출력 확률
            apply_scenario_weights: 시나리오 가중치 적용 여부
            scenario: 시나리오명
            top_k: 상위 K개 감정
            
        Returns:
            (전체 감정 리스트, 상위 K개 감정 리스트, 주 감정)
        """
        # 시나리오 가중치 적용
        if apply_scenario_weights:
            probabilities = self._apply_scenario_weights(probabilities, scenario)
        
        # 모든 감정 예측 결과 생성
        all_emotions = []
        for i, (emotion_id, emotion_label) in enumerate(self.model.config.id2label.items()):
            probability = probabilities[0][i].item()
            
            # 한국어 라벨을 영어 라벨로 변환
            english_label = self.label_mapping.get(emotion_label, emotion_label)
            emotion_kr = settings.EMOTION_LABELS.get(english_label, emotion_label)
            
            # 영어 라벨이 EmotionLabel enum에 있는지 확인
            try:
                emotion_enum = EmotionLabel(english_label)
            except ValueError:
                logger.warning(f"알 수 없는 감정 라벨: {emotion_label} -> {english_label}")
                continue
            
            emotion_pred = EmotionPrediction(
                emotion=emotion_enum,
                emotion_kr=emotion_kr,
                confidence=probability,
                probability=probability
            )
            all_emotions.append(emotion_pred)
        
        # 확률 기준으로 정렬
        all_emotions.sort(key=lambda x: x.probability, reverse=True)
        
        # 상위 K개 감정
        top_emotions = all_emotions[:top_k]
        
        # 주 감정 (가장 높은 확률)
        primary_emotion = all_emotions[0]
        
        return all_emotions, top_emotions, primary_emotion
    
    async def process_audio(
        self, 
        audio_file: UploadFile,
        request: EmotionAnalysisRequest
    ) -> EmotionAnalysisResponse:
        """
        오디오 파일 감정분석 수행
        
        Args:
            audio_file: 오디오 파일 객체
            request: 감정분석 요청 매개변수
            
        Returns:
            EmotionAnalysisResponse: 감정분석 결과
        """
        start_time = time.time()
        
        # 모델 로드 확인
        if self.model is None or self.processor is None:
            await self.load_model()
        
        # 임시 파일 저장
        temp_file_path = await self._save_temp_file(audio_file)
        
        try:
            logger.info(f"감정분석 시작 - 파일: {audio_file.filename}, 시나리오: {request.scenario}")
            
            # 오디오 전처리
            speech = self._preprocess_audio(temp_file_path)
            audio_duration = len(speech) / settings.SAMPLE_RATE
            
            # 모델 입력 준비
            inputs = self.processor(
                speech,
                sampling_rate=settings.SAMPLE_RATE,
                return_tensors="pt",
                padding=True
            )
            
            # GPU로 입력 데이터 이동
            inputs = {key: value.to(self.device) for key, value in inputs.items()}
            
            # 예측 수행
            with torch.no_grad():
                outputs = self.model(**inputs)
                logits = outputs.logits
            
            # 확률 계산
            probabilities = torch.nn.functional.softmax(logits, dim=-1)
            
            # 감정 예측 결과 생성
            all_emotions, top_emotions, primary_emotion = self._create_emotion_predictions(
                probabilities,
                apply_scenario_weights=request.apply_scenario_weights,
                scenario=request.scenario,
                top_k=request.top_k or settings.TOP_K_EMOTIONS
            )
            
            processing_time = time.time() - start_time
            
            logger.info(f"감정분석 완료 - 주 감정: {primary_emotion.emotion_kr} ({primary_emotion.probability:.3f}), 처리시간: {processing_time:.2f}초")
            
            return EmotionAnalysisResponse(
                primary_emotion=primary_emotion,
                all_emotions=all_emotions,
                top_emotions=top_emotions,
                scenario=request.scenario,
                scenario_applied=request.apply_scenario_weights,
                audio_duration=audio_duration,
                processing_time=processing_time,
                model_used=self.model_name
            )
            
        except Exception as e:
            logger.error(f"감정분석 중 오류 발생: {str(e)}", exc_info=True)
            raise
        finally:
            # 임시 파일 정리
            if os.path.exists(temp_file_path):
                os.unlink(temp_file_path)
    
    async def process_audio_bytes(
        self,
        audio_bytes: bytes,
        request: EmotionAnalysisRequest
    ) -> EmotionAnalysisResponse:
        """
        오디오 바이트 데이터 감정분석 수행 (실시간 처리용)
        
        Args:
            audio_bytes: 오디오 바이너리 데이터 (16-bit PCM 형식)
            request: 감정분석 요청 매개변수
            
        Returns:
            EmotionAnalysisResponse: 감정분석 결과
        """
        start_time = time.time()
        
        # 모델 로드 확인
        if self.model is None or self.processor is None:
            await self.load_model()
        
        try:
            # raw PCM 바이트 데이터를 numpy array로 변환
            # STT 서비스에서 16-bit PCM으로 변환해서 보냄
            audio_np = np.frombuffer(audio_bytes, dtype=np.int16)
            
            # int16 -> float32로 정규화 (-1.0 ~ 1.0)
            speech = audio_np.astype(np.float32) / 32768.0
            
            # 오디오 길이 계산
            audio_duration = len(speech) / settings.SAMPLE_RATE
            
            logger.debug(f"PCM 데이터 변환 완료 - 길이: {audio_duration:.2f}초, 샘플 수: {len(speech)}")
            
            # 오디오 길이 제한
            max_samples = settings.MAX_AUDIO_LENGTH * settings.SAMPLE_RATE
            if len(speech) > max_samples:
                speech = speech[:max_samples]
                audio_duration = len(speech) / settings.SAMPLE_RATE
                logger.warning(f"오디오가 {settings.MAX_AUDIO_LENGTH}초로 잘렸습니다.")
            
            # 오디오 정규화 (추가)
            if settings.AUDIO_NORMALIZE and np.max(np.abs(speech)) > 0:
                speech = speech / np.max(np.abs(speech))
            
            # 오디오 데이터 검증
            if len(speech) == 0:
                raise ValueError("오디오 데이터가 비어있습니다")
            
            # 모델 입력 준비
            inputs = self.processor(
                speech,
                sampling_rate=settings.SAMPLE_RATE,
                return_tensors="pt",
                padding=True
            )
            
            # GPU로 입력 데이터 이동
            inputs = {key: value.to(self.device) for key, value in inputs.items()}
            
            # 예측 수행
            with torch.no_grad():
                outputs = self.model(**inputs)
                logits = outputs.logits
            
            # 확률 계산
            probabilities = torch.nn.functional.softmax(logits, dim=-1)
            
            # 감정 예측 결과 생성
            all_emotions, top_emotions, primary_emotion = self._create_emotion_predictions(
                probabilities,
                apply_scenario_weights=request.apply_scenario_weights,
                scenario=request.scenario,
                top_k=request.top_k or settings.TOP_K_EMOTIONS
            )
            
            processing_time = time.time() - start_time
            
            logger.debug(f"실시간 감정분석 완료 - 주 감정: {primary_emotion.emotion_kr} ({primary_emotion.probability:.3f})")
            
            return EmotionAnalysisResponse(
                primary_emotion=primary_emotion,
                all_emotions=all_emotions,
                top_emotions=top_emotions,
                scenario=request.scenario,
                scenario_applied=request.apply_scenario_weights,
                audio_duration=audio_duration,
                processing_time=processing_time,
                model_used=self.model_name
            )
            
        except Exception as e:
            logger.error(f"실시간 감정분석 중 오류 발생: {str(e)}", exc_info=True)
            raise
    
    async def _save_temp_file(self, file: UploadFile) -> str:
        """
        업로드된 파일을 임시 디렉토리에 저장
        
        Args:
            file: 업로드된 파일 객체
            
        Returns:
            저장된 파일의 경로
        """
        # 임시 파일 경로 생성
        file_extension = os.path.splitext(file.filename or "audio.wav")[1]
        temp_file_path = os.path.join(
            settings.TEMP_AUDIO_DIR,
            f"emotion_audio_{int(time.time() * 1000)}{file_extension}"
        )
        
        # 파일 저장
        with open(temp_file_path, "wb") as temp_file:
            content = await file.read()
            temp_file.write(content)
        
        return temp_file_path


# 전역 감정분석 프로세서 인스턴스
emotion_processor = EmotionProcessor()