#!/usr/bin/env bash
set -euo pipefail

echo "== WSL =="
uname -a || true
cat /etc/os-release | sed -n '1,8p' || true

echo
echo "== NVIDIA SMI =="
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi || true
elif [ -x /usr/lib/wsl/lib/nvidia-smi ]; then
  /usr/lib/wsl/lib/nvidia-smi || true
else
  echo "nvidia-smi not found"
fi

echo
echo "== CUDA toolkits =="
for nvcc in /usr/local/cuda/bin/nvcc /usr/local/cuda-*/bin/nvcc "$HOME/.local/bin/nvcc"; do
  if [ -x "$nvcc" ]; then
    echo "-- $nvcc"
    "$nvcc" --version || true
  fi
done

echo
echo "== CUDA paths =="
ls -ld /usr/local/cuda* 2>/dev/null || true

echo
echo "== Blender =="
if command -v blender >/dev/null 2>&1; then
  blender --version | sed -n '1,4p' || true
elif [ -x "$HOME/.local/bin/blender" ]; then
  "$HOME/.local/bin/blender" --version | sed -n '1,4p' || true
else
  echo "blender not found"
fi
