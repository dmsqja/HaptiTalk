import logging
import colorlog
import os
from datetime import datetime


def setup_logger(name: str = "emotion_analysis_service", level: int = logging.INFO) -> logging.Logger:
    """
    컬러 로깅을 지원하는 로거 설정
    
    Args:
        name: 로거 이름
        level: 로깅 레벨
        
    Returns:
        설정된 로거 인스턴스
    """
    # 로거 생성
    logger = logging.getLogger(name)
    logger.setLevel(level)
    
    # 이미 핸들러가 있으면 제거 (중복 방지)
    if logger.handlers:
        logger.handlers.clear()
    
    # 컬러 포맷터 설정
    color_formatter = colorlog.ColoredFormatter(
        "%(log_color)s%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt='%Y-%m-%d %H:%M:%S',
        log_colors={
            'DEBUG': 'cyan',
            'INFO': 'green',
            'WARNING': 'yellow',
            'ERROR': 'red',
            'CRITICAL': 'red,bg_white',
        }
    )
    
    # 콘솔 핸들러 설정
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(color_formatter)
    logger.addHandler(console_handler)
    
    # 파일 핸들러 설정 (logs 디렉토리)
    logs_dir = "logs"
    os.makedirs(logs_dir, exist_ok=True)
    
    file_formatter = logging.Formatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # 일반 로그 파일
    file_handler = logging.FileHandler(
        os.path.join(logs_dir, f"emotion_analysis_{datetime.now().strftime('%Y%m%d')}.log"),
        encoding='utf-8'
    )
    file_handler.setFormatter(file_formatter)
    logger.addHandler(file_handler)
    
    # 에러 로그 파일 (ERROR 이상만)
    error_handler = logging.FileHandler(
        os.path.join(logs_dir, f"emotion_analysis_error_{datetime.now().strftime('%Y%m%d')}.log"),
        encoding='utf-8'
    )
    error_handler.setLevel(logging.ERROR)
    error_handler.setFormatter(file_formatter)
    logger.addHandler(error_handler)
    
    return logger


# 기본 로거 인스턴스 생성
logger = setup_logger() 