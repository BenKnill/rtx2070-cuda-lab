#!/usr/bin/env bash
set -euo pipefail

ROOT=/mnt/c/Users/18572/blender-wsl-render
REPO="$ROOT/rtx2070-cuda-lab"
BLENDER=/home/bluestar/.local/bin/blender
BLEND="$ROOT/blender_bridge_output/cuda_rocket_plume_scene.blend"
SRC_FRAMES="$ROOT/cuda_demo_output/rocket_plume_cuda_frames"
SEQ_DIR="$ROOT/blender_bridge_output/rocket_plume_sequence"
Z_FRAMES="$ROOT/blender_bridge_output/rocket_plume_zaware_frames"
MEDIA="$REPO/docs/media"
LOG_DIR="$ROOT/cuda_care_logs"
STAMP=$(date +%Y%m%d-%H%M%S)
LOG="$LOG_DIR/wsl-render-cuda-rocket-plume-zaware-animation-$STAMP.txt"

mkdir -p "$SEQ_DIR" "$Z_FRAMES" "$MEDIA" "$LOG_DIR"
exec > >(tee "$LOG") 2>&1

echo "Build z-aware CUDA rocket plume animation $STAMP"
echo "blender: $BLENDER"
echo "blend: $BLEND"

if [ ! -f "$BLEND" ]; then
  echo "Missing blend: $BLEND" >&2
  exit 1
fi
if ! ls "$SRC_FRAMES"/plume_frame_000.ppm >/dev/null 2>&1; then
  echo "Missing CUDA plume frames; run wsl_build_cuda_rocket_plume_blender_scene.sh first." >&2
  exit 1
fi

echo
echo "== create flipped PNG image sequence =="
rm -f "$SEQ_DIR"/plume_seq_*.png
ffmpeg -y -framerate 24 -i "$SRC_FRAMES/plume_frame_%03d.ppm" \
  -vf "hflip,scale=1024:512:flags=lanczos" \
  "$SEQ_DIR/plume_seq_%03d.png"

echo
echo "== render z-aware frames in Blender/Cycles =="
ZAWARE_FRAME_COUNT=48 \
ZAWARE_FRAME_STEP=2 \
ZAWARE_CYCLES_SAMPLES=24 \
ZAWARE_RES_X=1120 \
ZAWARE_RES_Y=640 \
"$BLENDER" -b "$BLEND" --python "$ROOT/render_cuda_rocket_plume_zaware_animation.py"

echo
echo "== encode z-aware mp4/gif =="
ffmpeg -y -framerate 12 -i "$Z_FRAMES/frame_%03d.png" \
  -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
  "$MEDIA/cuda_rocket_plume_zaware_scene.mp4"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ffmpeg -y -i "$MEDIA/cuda_rocket_plume_zaware_scene.mp4" \
  -vf "fps=16,scale=900:-1:flags=lanczos,palettegen" \
  "$TMP/palette.png"
ffmpeg -y -i "$MEDIA/cuda_rocket_plume_zaware_scene.mp4" -i "$TMP/palette.png" \
  -lavfi "fps=16,scale=900:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=2" \
  "$MEDIA/cuda_rocket_plume_zaware_scene.gif"

echo
echo "== validate =="
identify -format '%f %w x %h %[size]\n' "$MEDIA/cuda_rocket_plume_zaware_scene.gif" | head -1
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,duration,nb_frames -of default=nw=1 "$MEDIA/cuda_rocket_plume_zaware_scene.mp4"
ls -lh "$MEDIA/cuda_rocket_plume_zaware_scene.mp4" "$MEDIA/cuda_rocket_plume_zaware_scene.gif"

echo
echo "Done. Log: $LOG"
