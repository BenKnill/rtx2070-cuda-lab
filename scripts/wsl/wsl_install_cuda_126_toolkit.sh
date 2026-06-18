#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/18572/blender-wsl-render"
LOG_DIR="$ROOT/cuda_care_logs"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/wsl-cuda126-install-$STAMP.txt"
exec > >(tee -a "$LOG") 2>&1

echo "CUDA 12.6 WSL toolkit install $STAMP"
echo "User: $(whoami)"
echo "Kernel: $(uname -a)"

if ! sudo -n true 2>/dev/null; then
  echo "sudo requires a password or is unavailable; cannot continue unattended."
  exit 1
fi

KEYRING="/tmp/cuda-keyring_1.1-1_all.deb"
KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb"

echo
echo "== NVIDIA driver exposed through WSL =="
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi || true
elif [ -x /usr/lib/wsl/lib/nvidia-smi ]; then
  /usr/lib/wsl/lib/nvidia-smi || true
else
  echo "nvidia-smi not found"
fi

echo
echo "== Install CUDA repo keyring =="
if command -v wget >/dev/null 2>&1; then
  wget -O "$KEYRING" "$KEYRING_URL"
else
  curl -L -o "$KEYRING" "$KEYRING_URL"
fi
sudo dpkg -i "$KEYRING"

echo
echo "== apt update =="
sudo apt-get update

echo
echo "== install cuda-toolkit-12-6 =="
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-toolkit-12-6

echo
echo "== verify =="
if [ -x /usr/local/cuda-12.6/bin/nvcc ]; then
  /usr/local/cuda-12.6/bin/nvcc --version
else
  echo "/usr/local/cuda-12.6/bin/nvcc not found"
  exit 1
fi

echo
echo "CUDA symlinks:"
ls -ld /usr/local/cuda* 2>/dev/null || true

echo
echo "Done. Log: $LOG"
