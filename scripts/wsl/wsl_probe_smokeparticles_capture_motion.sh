#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/18572/blender-wsl-render"
FRAME_DIR="$ROOT/cuda_demo_output/smokeparticles_frames"
LOG_DIR="$ROOT/cuda_care_logs"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/wsl-probe-smokeparticles-capture-motion-$STAMP.txt"
exec > >(tee -a "$LOG") 2>&1

echo "Probe smokeParticles captured frame motion $STAMP"
echo "Frame dir: $FRAME_DIR"

count="$(find "$FRAME_DIR" -maxdepth 1 -name 'frame_*.ppm' | wc -l)"
echo "frames=$count"
if [ "$count" -lt 2 ]; then
  echo "Need at least 2 frames to probe motion."
  exit 1
fi

python3 - "$FRAME_DIR" <<'PY'
import hashlib
import pathlib
import sys

frame_dir = pathlib.Path(sys.argv[1])
frames = sorted(frame_dir.glob("frame_*.ppm"))[:16]
prev = None
for frame in frames:
    data = frame.read_bytes()
    digest = hashlib.sha256(data).hexdigest()[:16]
    if prev is None:
        print(f"{frame.name} {digest}")
    else:
        diff = sum(a != b for a, b in zip(prev, data))
        print(f"{frame.name} {digest} diff_vs_prev={diff}")
    prev = data
PY

echo "Done. Log: $LOG"
