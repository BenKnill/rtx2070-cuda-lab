#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/18572/blender-wsl-render"
FRAME_DIR="$ROOT/cuda_samples_v12_5/Samples/5_Domain_Specific/fluidsGL"
LOG_DIR="$ROOT/cuda_care_logs"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/wsl-probe-fluidsgl-frame-motion-$STAMP.txt"
exec > >(tee -a "$LOG") 2>&1

echo "Probe fluidsGL frame motion $STAMP"
echo "Frame dir: $FRAME_DIR"

python3 - <<'PY'
from pathlib import Path
import hashlib

frame_dir = Path("/mnt/c/Users/18572/blender-wsl-render/cuda_samples_v12_5/Samples/5_Domain_Specific/fluidsGL")
frames = sorted(frame_dir.glob("fluidsGL_frame_*.ppm"))
print(f"frames={len(frames)}")
for p in frames[:8]:
    print(p.name, hashlib.sha256(p.read_bytes()).hexdigest()[:16], p.stat().st_size)

def read_ppm(path):
    data = path.read_bytes()
    parts = data.split(maxsplit=4)
    if parts[0] != b"P6":
        raise ValueError(path)
    width = int(parts[1])
    height = int(parts[2])
    maxv = int(parts[3])
    pixels = parts[4]
    return width, height, maxv, pixels

if len(frames) >= 2:
    prev = None
    for p in frames:
        _, _, _, px = read_ppm(p)
        if prev is not None:
            changed = sum(a != b for a, b in zip(prev, px))
            print(f"diff_vs_prev {p.name}: {changed} bytes")
        prev = px
PY

echo "Done. Log: $LOG"
