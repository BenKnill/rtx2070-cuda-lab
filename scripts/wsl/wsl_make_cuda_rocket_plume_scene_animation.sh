#!/usr/bin/env bash
set -euo pipefail

ROOT=/mnt/c/Users/18572/blender-wsl-render
REPO="$ROOT/rtx2070-cuda-lab"
BLENDER=/home/bluestar/.local/bin/blender
BLEND="$ROOT/blender_bridge_output/cuda_rocket_plume_scene.blend"
FRAME_DIR="$ROOT/cuda_demo_output/rocket_plume_cuda_frames"
CLEAN="$ROOT/blender_bridge_output/cuda_rocket_plume_clean_plate.png"
MEDIA="$REPO/docs/media"
LOG_DIR="$ROOT/cuda_care_logs"
STAMP=$(date +%Y%m%d-%H%M%S)
LOG="$LOG_DIR/wsl-make-cuda-rocket-plume-scene-animation-$STAMP.txt"

mkdir -p "$MEDIA" "$LOG_DIR"
exec > >(tee "$LOG") 2>&1

echo "Build full-scene CUDA rocket plume animation $STAMP"
echo "blender: $BLENDER"
echo "blend: $BLEND"

if [ ! -f "$BLEND" ]; then
  echo "Missing blend: $BLEND" >&2
  exit 1
fi
if ! ls "$FRAME_DIR"/plume_frame_000.ppm >/dev/null 2>&1; then
  echo "Missing plume frames in $FRAME_DIR; run wsl_build_cuda_rocket_plume_blender_scene.sh first." >&2
  exit 1
fi

echo
echo "== render clean rocket plate =="
"$BLENDER" -b "$BLEND" --python "$ROOT/render_cuda_rocket_clean_plate.py"

echo
echo "== composite animated plume into scene mp4 =="
ffmpeg -y \
  -loop 1 -framerate 24 -i "$CLEAN" \
  -framerate 24 -i "$FRAME_DIR/plume_frame_%03d.ppm" \
  -filter_complex "[1:v]scale=780:390:flags=lanczos,hflip,colorkey=0x000000:0.055:0.20,format=rgba,colorchannelmixer=aa=0.92[plume];[0:v]scale=1400:800:flags=lanczos,format=rgba[bg];[bg][plume]overlay=x=62:y=224:shortest=1,format=yuv420p" \
  -frames:v 96 -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
  "$MEDIA/cuda_rocket_plume_scene.mp4"

echo
echo "== make page gif preview =="
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ffmpeg -y -i "$MEDIA/cuda_rocket_plume_scene.mp4" \
  -vf "fps=16,scale=900:-1:flags=lanczos,palettegen" \
  "$TMP/palette.png"
ffmpeg -y -i "$MEDIA/cuda_rocket_plume_scene.mp4" -i "$TMP/palette.png" \
  -lavfi "fps=16,scale=900:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=2" \
  "$MEDIA/cuda_rocket_plume_scene.gif"

echo
echo "== validate =="
identify -format '%f %w x %h %[size]\n' "$CLEAN" "$MEDIA/cuda_rocket_plume_scene.gif"
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,duration,nb_frames -of default=nw=1 "$MEDIA/cuda_rocket_plume_scene.mp4"
ls -lh "$MEDIA/cuda_rocket_plume_scene.mp4" "$MEDIA/cuda_rocket_plume_scene.gif"

echo
echo "Done. Log: $LOG"
