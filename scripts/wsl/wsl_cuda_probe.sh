#!/usr/bin/env bash
set -u

source /mnt/c/Users/18572/blender-wsl-render/wsl_worker_env.sh 2>/dev/null || true

echo "--- user/kernel ---"
whoami
uname -a

echo "--- nvidia-smi ---"
nvidia-smi || true

echo "--- cuda compiler ---"
command -v nvcc || true
nvcc --version || true

echo "--- cuda paths ---"
ls -ld /usr/local/cuda* 2>/dev/null || true

echo "--- compilers/build tools ---"
for tool in git cmake make g++ gcc pkg-config python3 ffmpeg montage magick; do
  printf '%-12s' "$tool:"
  command -v "$tool" || true
done

echo "--- display/opengl clues ---"
printf 'DISPLAY=%s\n' "${DISPLAY:-}"
printf 'WAYLAND_DISPLAY=%s\n' "${WAYLAND_DISPLAY:-}"
ls -ld /mnt/wslg 2>/dev/null || true
command -v glxinfo || true
glxinfo -B 2>/dev/null || true

echo "--- gl dev libs ---"
pkg-config --modversion gl glu glut freeglut 2>/dev/null || true
