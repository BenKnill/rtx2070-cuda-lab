#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/18572/blender-wsl-render"
SAMPLES="$ROOT/cuda_samples_v12_5"
LOG_DIR="$ROOT/cuda_care_logs"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/wsl-cuda126-basic-samples-$STAMP.txt"
exec > >(tee -a "$LOG") 2>&1

export CUDA_HOME=/usr/local/cuda-12.6
export CUDA_PATH=/usr/local/cuda-12.6
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"

echo "CUDA 12.6 WSL basic sample build $STAMP"
echo "Samples: $SAMPLES"
nvcc --version

build_sample() {
  local rel="$1"
  echo
  echo "== Build $rel =="
  make -C "$SAMPLES/$rel" clean || true
  make -C "$SAMPLES/$rel" TARGET_ARCH=x86_64 SMS=75 -j"$(nproc)"
}

build_sample "Samples/1_Utilities/deviceQuery"
build_sample "Samples/1_Utilities/bandwidthTest"

echo
echo "== Run deviceQuery =="
"$SAMPLES/bin/x86_64/linux/release/deviceQuery"

echo
echo "== Run bandwidthTest =="
"$SAMPLES/bin/x86_64/linux/release/bandwidthTest" --mode=quick

echo
echo "Done. Log: $LOG"
