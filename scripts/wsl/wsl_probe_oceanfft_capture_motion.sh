#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/18572/blender-wsl-render"
FRAME_DIR="$ROOT/cuda_demo_output/oceanfft_frames"
LOG_DIR="$ROOT/cuda_care_logs"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/wsl-probe-oceanfft-capture-motion-$STAMP.txt"
exec > >(tee -a "$LOG") 2>&1

echo "Probe oceanFFT captured frame motion $STAMP"
echo "Frame dir: $FRAME_DIR"

python3 - <<'PY'
from pathlib import Path
import hashlib

frame_dir = Path("/mnt/c/Users/18572/blender-wsl-render/cuda_demo_output/oceanfft_frames")
frames = sorted(frame_dir.glob("frame_*.ppm"))
print(f"frames={len(frames)}")

def read_ppm(path):
    data = path.read_bytes()
    parts = data.split(maxsplit=4)
    return parts[4]

prev = None
for p in frames[:12]:
    px = read_ppm(p)
    print(p.name, hashlib.sha256(px).hexdigest()[:16], end="")
    if prev is not None:
        changed = sum(a != b for a, b in zip(prev, px))
        print(f" diff_vs_prev={changed}")
    else:
        print()
    prev = px
PY

echo "Done. Log: $LOG"
