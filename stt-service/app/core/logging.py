import logging
import sys
from typing import Optional
import os

# 로그 포맷 설정
FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

# 로그 레벨 설정
LOG_LEVEL = logging.INFO

# 로그 디렉토리 설정
LOG_DIR = "logs"
os.makedirs(LOG_DIR, exist_ok=True)


def setup_logger(name: str, log_file: Optional[str] = None, level: int = LOG_LEVEL) -> logging.Logger:
    """
    로거 설정 함수
    
    Args:
        name: 로거 이름
        log_file: 로그 파일 경로 (None이면 파일 출력 안함)
        level: 로깅 레벨
        
    Returns:
        설정된 로거 객체
    """
    logger = logging.getLogger(name)
    logger.setLevel(level)
    
    # 콘솔 핸들러 설정
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(logging.Formatter(FORMAT))
    logger.addHandler(console_handler)
    
    # 파일 핸들러 설정 (옵션)
    if log_file:
        file_handler = logging.FileHandler(os.path.join(LOG_DIR, log_file))
        file_handler.setFormatter(logging.Formatter(FORMAT))
        logger.addHandler(file_handler)
    
    return logger


# 기본 로거 설정
logger = setup_logger("stt_service", "stt_service.log") 