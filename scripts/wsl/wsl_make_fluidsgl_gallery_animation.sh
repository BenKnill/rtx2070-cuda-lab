#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/18572/blender-wsl-render"
FRAME_DIR="$ROOT/cuda_samples_v12_5/Samples/5_Domain_Specific/fluidsGL"
DST_DIR="$ROOT/blender-workbench-artifacts/docs/cuda-demo-gallery/media"
LOG_DIR="$ROOT/cuda_care_logs"
mkdir -p "$LOG_DIR" "$DST_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/wsl-fluidsgl-gallery-animation-$STAMP.txt"
exec > >(tee -a "$LOG") 2>&1

echo "Build fluidsGL gallery animation $STAMP"
echo "Frame dir: $FRAME_DIR"
echo "Dest dir: $DST_DIR"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

i=0
while IFS= read -r frame; do
  printf -v name "frame_%03d.ppm" "$i"
  cp "$frame" "$TMP/$name"
  i=$((i + 1))
done < <(find "$FRAME_DIR" -maxdepth 1 -name 'fluidsGL_frame_*.ppm' | sort)

if [ "$i" -lt 2 ]; then
  echo "Need at least 2 frames; found $i"
  exit 1
fi

echo "Frames: $i"

ffmpeg -y -framerate 12 -i "$TMP/frame_%03d.ppm" \
  -vf "fps=12,scale=512:-1:flags=lanczos,palettegen" \
  "$TMP/palette.png"

ffmpeg -y -framerate 12 -i "$TMP/frame_%03d.ppm" -i "$TMP/palette.png" \
  -lavfi "fps=12,scale=512:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3" \
  "$DST_DIR/fluidsGL_reference.gif"

ffmpeg -y -framerate 12 -i "$TMP/frame_%03d.ppm" \
  -movflags +faststart \
  -pix_fmt yuv420p \
  "$DST_DIR/fluidsGL_reference.mp4"

echo
echo "== gif frames =="
if command -v magick >/dev/null 2>&1; then
  magick identify -format '%n frames %w x %h\n' "$DST_DIR/fluidsGL_reference.gif" | head -n 5
elif command -v identify >/dev/null 2>&1; then
  identify -format '%n frames %w x %h\n' "$DST_DIR/fluidsGL_reference.gif" | head -n 5
else
  echo "ImageMagick identify not found"
fi

echo
echo "== mp4 stream =="
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,nb_frames,duration,width,height -of default=noprint_wrappers=1 "$DST_DIR/fluidsGL_reference.mp4"

echo
echo "Done. Log: $LOG"
