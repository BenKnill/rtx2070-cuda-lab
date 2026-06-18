#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/18572/blender-wsl-render"
SRC="$ROOT/cuda_samples_v12_5/Samples/5_Domain_Specific/fluidsGL/doc/fluidsGL_lg.gif"
DST_DIR="$ROOT/blender-workbench-artifacts/docs/cuda-demo-gallery/media"
LOG_DIR="$ROOT/cuda_care_logs"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/wsl-fix-fluidsgl-gallery-$STAMP.txt"
exec > >(tee -a "$LOG") 2>&1

echo "Fix fluidsGL gallery reference $STAMP"
echo "Source: $SRC"
echo "Dest: $DST_DIR"

if [ ! -f "$SRC" ]; then
  echo "Missing source GIF: $SRC"
  exit 1
fi

mkdir -p "$DST_DIR"
cp "$SRC" "$DST_DIR/fluidsGL_reference.gif"

if command -v ffmpeg >/dev/null 2>&1; then
  ffmpeg -y -i "$DST_DIR/fluidsGL_reference.gif" \
    -movflags +faststart \
    -pix_fmt yuv420p \
    "$DST_DIR/fluidsGL_reference.mp4"
else
  echo "ffmpeg not found; skipped MP4 regeneration"
fi

echo
echo "== file =="
file "$DST_DIR/fluidsGL_reference.gif" "$DST_DIR/fluidsGL_reference.mp4" || true

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
if command -v ffprobe >/dev/null 2>&1; then
  ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,nb_frames,duration,width,height -of default=noprint_wrappers=1 "$DST_DIR/fluidsGL_reference.mp4"
else
  echo "ffprobe not found"
fi

echo
echo "Done. Log: $LOG"
