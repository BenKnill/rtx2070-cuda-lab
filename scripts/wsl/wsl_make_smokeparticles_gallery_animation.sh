#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/18572/blender-wsl-render"
FRAME_DIR="$ROOT/cuda_demo_output/smokeparticles_frames"
DST_DIR="$ROOT/rtx2070-cuda-lab/docs/media"
LOG_DIR="$ROOT/cuda_care_logs"
mkdir -p "$LOG_DIR" "$DST_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/wsl-smokeparticles-gallery-animation-$STAMP.txt"
exec > >(tee -a "$LOG") 2>&1

echo "Build animated smokeParticles gallery assets $STAMP"
echo "Frame dir: $FRAME_DIR"
echo "Dest dir: $DST_DIR"

count="$(find "$FRAME_DIR" -maxdepth 1 -name 'frame_*.ppm' | wc -l)"
if [ "$count" -lt 2 ]; then
  echo "Need at least 2 frames; found $count"
  exit 1
fi
echo "Frames: $count"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ffmpeg -y -framerate 16 -i "$FRAME_DIR/frame_%03d.ppm" \
  -vf "fps=16,scale=640:-1:flags=lanczos,palettegen" \
  "$TMP/palette.png"

ffmpeg -y -framerate 16 -i "$FRAME_DIR/frame_%03d.ppm" -i "$TMP/palette.png" \
  -lavfi "fps=16,scale=640:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=2" \
  "$DST_DIR/smokeParticles_native_run.gif"

ffmpeg -y -framerate 16 -i "$FRAME_DIR/frame_%03d.ppm" \
  -vf "scale=1280:-2:flags=lanczos" \
  -movflags +faststart \
  -pix_fmt yuv420p \
  "$DST_DIR/smokeParticles_native_run.mp4"

echo
echo "== gif frames =="
if command -v magick >/dev/null 2>&1; then
  magick identify -format '%n frames %w x %h\n' "$DST_DIR/smokeParticles_native_run.gif" | head -n 5
elif command -v identify >/dev/null 2>&1; then
  identify -format '%n frames %w x %h\n' "$DST_DIR/smokeParticles_native_run.gif" | head -n 5
else
  echo "ImageMagick identify not found"
fi

echo
echo "== mp4 stream =="
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,nb_frames,duration,width,height -of default=noprint_wrappers=1 "$DST_DIR/smokeParticles_native_run.mp4"

echo
echo "Done. Log: $LOG"
