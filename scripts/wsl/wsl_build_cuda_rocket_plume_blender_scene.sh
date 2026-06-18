#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/18572/blender-wsl-render"
BUILD_DIR="$ROOT/build_cuda"
FRAME_DIR="$ROOT/cuda_demo_output/rocket_plume_cuda_frames"
CARD_DIR="$ROOT/blender_bridge_output/rocket_plume_cards"
REPO="$ROOT/rtx2070-cuda-lab"
MEDIA="$REPO/docs/media"
LOG_DIR="$ROOT/cuda_care_logs"
BLENDER="$HOME/.local/bin/blender"
NVCC="/usr/local/cuda-12.6/bin/nvcc"
mkdir -p "$BUILD_DIR" "$FRAME_DIR" "$CARD_DIR" "$MEDIA" "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/wsl-build-cuda-rocket-plume-blender-scene-$STAMP.txt"
exec > >(tee -a "$LOG") 2>&1

echo "Build CUDA rocket plume Blender scene $STAMP"

if [ ! -x "$NVCC" ]; then
  NVCC="$(command -v nvcc || true)"
fi
if [ -z "$NVCC" ] || [ ! -x "$NVCC" ]; then
  echo "nvcc not found"
  exit 1
fi
if [ ! -x "$BLENDER" ]; then
  echo "Blender not found at $BLENDER"
  exit 1
fi

echo "nvcc: $NVCC"
echo "blender: $BLENDER"

rm -f "$FRAME_DIR"/plume_frame_*.ppm "$CARD_DIR"/plume_card_*.png

echo
echo "== compile CUDA plume generator =="
"$NVCC" -O3 -std=c++17 -arch=sm_75 "$ROOT/cuda_rocket_plume_kernel.cu" -o "$BUILD_DIR/cuda_rocket_plume"

echo
echo "== generate CUDA plume frames =="
"$BUILD_DIR/cuda_rocket_plume" "$FRAME_DIR" 96 1024 512

echo
echo "== derive plume cards =="
for idx in 006 014 022 030 038 046 054 062 070 078; do
  ffmpeg -y -i "$FRAME_DIR/plume_frame_$idx.ppm" -vf "scale=1024:-1:flags=lanczos" "$CARD_DIR/plume_card_$idx.png"
done

echo
echo "== encode plume preview animation =="
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ffmpeg -y -framerate 24 -i "$FRAME_DIR/plume_frame_%03d.ppm" \
  -vf "fps=24,scale=640:-1:flags=lanczos,palettegen" \
  "$TMP/palette.png"
ffmpeg -y -framerate 24 -i "$FRAME_DIR/plume_frame_%03d.ppm" -i "$TMP/palette.png" \
  -lavfi "fps=24,scale=640:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=2" \
  "$MEDIA/cuda_rocket_plume.gif"
ffmpeg -y -framerate 24 -i "$FRAME_DIR/plume_frame_%03d.ppm" \
  -movflags +faststart \
  -pix_fmt yuv420p \
  "$MEDIA/cuda_rocket_plume.mp4"

echo
echo "== card stats =="
identify -format '%f %w x %h mean=%[mean]\n' "$CARD_DIR"/plume_card_*.png

echo
echo "== animation stats =="
identify -format '%n frames %w x %h\n' "$MEDIA/cuda_rocket_plume.gif" | head -n 5
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,nb_frames,duration,width,height -of default=noprint_wrappers=1 "$MEDIA/cuda_rocket_plume.mp4"

echo
echo "== blender render =="
BLENDER_WSL_RENDER_ROOT="$ROOT" "$BLENDER" -b --python "$ROOT/create_cuda_rocket_plume_scene.py"

echo
echo "== outputs =="
ls -lh "$ROOT/blender_bridge_output/cuda_rocket_plume_blender_preview.png"
ls -lh "$ROOT/blender_bridge_output/cuda_rocket_plume_scene.blend"
ls -lh "$MEDIA/cuda_rocket_plume.gif"
ls -lh "$MEDIA/cuda_rocket_plume.mp4"
ls -lh "$MEDIA/cuda_rocket_plume_blender_preview.png"
ls -lh "$REPO/assets/blender/cuda_rocket_plume_scene.blend"

echo
echo "Done. Log: $LOG"
