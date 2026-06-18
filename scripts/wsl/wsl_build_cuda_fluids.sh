#!/usr/bin/env bash
set -euo pipefail

CUDA_PATH=/usr/local/cuda-11.0
export CUDA_PATH
export PATH="$CUDA_PATH/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_PATH/lib64:${LD_LIBRARY_PATH:-}"

WORK=/mnt/c/Users/18572/blender-wsl-render/cuda_samples_11
mkdir -p "$WORK/5_Simulations"

if [ ! -d "$WORK/common" ]; then
  cp -a "$CUDA_PATH/samples/common" "$WORK/common"
fi

for sample in fluidsGL smokeParticles oceanFFT; do
  if [ ! -d "$WORK/5_Simulations/$sample" ]; then
    cp -a "$CUDA_PATH/samples/5_Simulations/$sample" "$WORK/5_Simulations/$sample"
  fi
done

printf '%s\n' "--- nvcc ---"
nvcc --version

for sample in fluidsGL smokeParticles oceanFFT; do
  printf '%s\n' "--- building $sample ---"
  make -C "$WORK/5_Simulations/$sample" clean >/dev/null || true
  make -C "$WORK/5_Simulations/$sample" SMS=75 -j"$(nproc)"
done

printf '%s\n' "--- built binaries ---"
find "$WORK/5_Simulations" -maxdepth 2 -type f -perm -111 -print -exec file {} \;
