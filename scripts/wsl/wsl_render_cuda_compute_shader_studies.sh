#!/usr/bin/env bash
set -euo pipefail

ROOT=/mnt/c/Users/18572/blender-wsl-render
REPO="$ROOT/rtx2070-cuda-lab"
RAW="$ROOT/cuda_demo_output/compute_shader_studies_ppm"
LOCAL="$ROOT/blender_bridge_output/compute_shader_studies"
MEDIA="$REPO/docs/media"
BIN="$ROOT/cuda_demo_output/compute_shader_studies_kernel"

mkdir -p "$RAW" "$LOCAL" "$MEDIA" "$REPO/src/cuda" "$REPO/scripts/wsl"

echo "== compile CUDA compute shader studies =="
/usr/local/cuda-12.6/bin/nvcc -O3 -std=c++17 -arch=sm_75 \
  "$ROOT/cuda_compute_shader_studies_kernel.cu" \
  -o "$BIN"

echo
echo "== generate CUDA study frames =="
rm -f "$RAW"/compute_shader_studies_*.ppm
"$BIN" "$RAW" 72 1280 720

echo
echo "== encode gallery media =="
ffmpeg -y -v error -framerate 12 -i "$RAW/compute_shader_studies_%03d.ppm" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -preset slow \
  "$MEDIA/cuda_compute_shader_studies.mp4"

ffmpeg -y -v error -i "$MEDIA/cuda_compute_shader_studies.mp4" \
  -vf "fps=12,scale=960:-1:flags=lanczos,palettegen=stats_mode=diff" \
  "$LOCAL/cuda_compute_shader_studies_palette.png"
ffmpeg -y -v error -i "$MEDIA/cuda_compute_shader_studies.mp4" -i "$LOCAL/cuda_compute_shader_studies_palette.png" \
  -lavfi "fps=12,scale=960:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3" \
  "$MEDIA/cuda_compute_shader_studies.gif"

IMAGEMAGICK=$(command -v magick || command -v convert || true)
if [[ -z "$IMAGEMAGICK" ]]; then
  echo "ImageMagick frontend not found: expected magick or convert" >&2
  exit 1
fi
"$IMAGEMAGICK" "$RAW/compute_shader_studies_000.ppm" "$MEDIA/cuda_compute_shader_studies_poster.png"

cp "$MEDIA/cuda_compute_shader_studies.mp4" "$LOCAL/cuda_compute_shader_studies.mp4"
cp "$MEDIA/cuda_compute_shader_studies.gif" "$LOCAL/cuda_compute_shader_studies.gif"
cp "$MEDIA/cuda_compute_shader_studies_poster.png" "$LOCAL/cuda_compute_shader_studies_poster.png"
cp "$ROOT/cuda_compute_shader_studies_kernel.cu" "$REPO/src/cuda/cuda_compute_shader_studies_kernel.cu"
cp "$ROOT/wsl_render_cuda_compute_shader_studies.sh" "$REPO/scripts/wsl/wsl_render_cuda_compute_shader_studies.sh"

echo
echo "== outputs =="
identify -format '%f %w x %h %[size]\n' \
  "$MEDIA/cuda_compute_shader_studies_poster.png" \
  "$MEDIA/cuda_compute_shader_studies.gif"
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,nb_frames,duration,avg_frame_rate \
  -of default=noprint_wrappers=1 "$MEDIA/cuda_compute_shader_studies.mp4"

echo
echo "CUDA_COMPUTE_SHADER_STUDIES_OK"
