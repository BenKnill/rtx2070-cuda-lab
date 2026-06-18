#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/18572/blender-wsl-render"
FRAME_DIR="$ROOT/cuda_demo_output/oceanfft_frames"
OUT_DIR="$ROOT/cuda_demo_output/oceanfft_preview"
mkdir -p "$OUT_DIR"

python3 - <<'PY'
from pathlib import Path
from statistics import mean

frame_dir = Path("/mnt/c/Users/18572/blender-wsl-render/cuda_demo_output/oceanfft_frames")
for p in sorted(frame_dir.glob("frame_*.ppm"))[:8]:
    data = p.read_bytes()
    px = data.split(maxsplit=4)[4]
    vals = list(px)
    print(p.name, "min", min(vals), "max", max(vals), "mean", round(mean(vals), 2), "nonzero", sum(v != 0 for v in vals))
PY

if command -v magick >/dev/null 2>&1; then
  magick "$FRAME_DIR/frame_000.ppm" "$OUT_DIR/frame_000.png"
  magick "$FRAME_DIR/frame_016.ppm" "$OUT_DIR/frame_016.png"
elif command -v convert >/dev/null 2>&1; then
  convert "$FRAME_DIR/frame_000.ppm" "$OUT_DIR/frame_000.png"
  convert "$FRAME_DIR/frame_016.ppm" "$OUT_DIR/frame_016.png"
else
  ffmpeg -y -i "$FRAME_DIR/frame_000.ppm" "$OUT_DIR/frame_000.png"
  ffmpeg -y -i "$FRAME_DIR/frame_016.ppm" "$OUT_DIR/frame_016.png"
fi

echo "Previews: $OUT_DIR"
