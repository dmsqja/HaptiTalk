#!/bin/bash
# CTranslate2를 CUDA 지원으로 소스에서 빌드하는 스크립트
# Jetson Orin Nano 8GB 디바이스용

set -e

# 현재 경로 기억
CURRENT_DIR=$(pwd)

# 필요한 도구 설치
# echo "필요한 도구 설치 중..."
# sudo apt-get update
# sudo apt-get install -y cmake build-essential git python3-dev

# venv 활성화
source venv/bin/activate

# 필요한 Python 패키지 설치
pip install pybind11 setuptools wheel

# 소스 코드 다운로드
echo "CTranslate2 소스 코드 다운로드 중..."
git clone --recursive https://github.com/OpenNMT/CTranslate2.git
cd CTranslate2

# C++ 라이브러리 빌드
echo "C++ 라이브러리 빌드 중..."
mkdir -p build && cd build
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DWITH_CUDA=ON \
  -DCUDA_ARCH_LIST="8.7" \
  -DWITH_CUDNN=ON \
  -DWITH_MKL=OFF \
  -DWITH_DNNL=OFF \
  -DWITH_OPENBLAS=ON \
  -DOPENMP_RUNTIME=COMP

make -j$(nproc)
sudo make install
sudo ldconfig

# Python 래퍼 빌드
echo "Python 래퍼 빌드 중..."
cd ../python
pip install -r install_requirements.txt
CTRANSLATE2_ROOT=/usr/local python setup.py bdist_wheel
pip install dist/*.whl

# 원래 디렉토리로 돌아가기
cd $CURRENT_DIR

echo "CTranslate2가 CUDA 지원으로 성공적으로 빌드되었습니다."