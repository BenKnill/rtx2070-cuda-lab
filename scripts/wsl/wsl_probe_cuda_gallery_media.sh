#!/usr/bin/env bash
set -euo pipefail

media="/mnt/c/Users/18572/blender-wsl-render/blender-workbench-artifacts/docs/cuda-demo-gallery/media"

echo "== file =="
file "$media/fluidsGL_reference.gif" "$media/fluidsGL_reference.mp4" || true

echo
echo "== gif frames =="
if command -v magick >/dev/null 2>&1; then
  magick identify -format '%n frames %w x %h\n' "$media/fluidsGL_reference.gif" | head -n 5
elif command -v identify >/dev/null 2>&1; then
  identify -format '%n frames %w x %h\n' "$media/fluidsGL_reference.gif" | head -n 5
else
  echo "ImageMagick identify not found"
fi

echo
echo "== mp4 stream =="
if command -v ffprobe >/dev/null 2>&1; then
  ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,nb_frames,duration,width,height -of default=noprint_wrappers=1 "$media/fluidsGL_reference.mp4"
else
  echo "ffprobe not found"
fi
