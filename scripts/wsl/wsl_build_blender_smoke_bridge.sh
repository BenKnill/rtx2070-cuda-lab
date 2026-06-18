#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/18572/blender-wsl-render"
FRAME_DIR="$ROOT/cuda_demo_output/smokeparticles_frames"
CARD_DIR="$ROOT/blender_bridge_output/smoke_cards"
LOG_DIR="$ROOT/cuda_care_logs"
BLENDER="$HOME/.local/bin/blender"
mkdir -p "$CARD_DIR" "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/wsl-build-blender-smoke-bridge-$STAMP.txt"
exec > >(tee -a "$LOG") 2>&1

echo "Build Blender smoke bridge $STAMP"
echo "Frame dir: $FRAME_DIR"
echo "Card dir: $CARD_DIR"

if [ ! -x "$BLENDER" ]; then
  echo "Blender not found at $BLENDER"
  exit 1
fi

rm -f "$CARD_DIR"/smoke_card_*.png
for idx in 006 010 014 018 022 026 030 034 038 042; do
  src="$FRAME_DIR/frame_$idx.ppm"
  dst="$CARD_DIR/smoke_card_$idx.png"
  if [ ! -f "$src" ]; then
    echo "Missing smoke frame: $src"
    exit 1
  fi
  ffmpeg -y -i "$src" -vf "scale=960:-1:flags=lanczos" "$dst"
done

echo
echo "== card stats =="
if command -v identify >/dev/null 2>&1; then
  identify -format '%f %w x %h mean=%[mean]\n' "$CARD_DIR"/smoke_card_*.png
fi

echo
echo "== blender render =="
BLENDER_WSL_RENDER_ROOT="$ROOT" "$BLENDER" -b --python "$ROOT/create_cuda_smoke_cards_scene.py"

echo
echo "== outputs =="
ls -lh "$ROOT/blender_bridge_output/cuda_smoke_blender_bridge_preview.png"
ls -lh "$ROOT/blender_bridge_output/cuda_smoke_cards_scene.blend"
ls -lh "$ROOT/rtx2070-cuda-lab/docs/media/cuda_smoke_blender_bridge_preview.png"
ls -lh "$ROOT/rtx2070-cuda-lab/assets/blender/cuda_smoke_cards_scene.blend"

echo
echo "Done. Log: $LOG"
