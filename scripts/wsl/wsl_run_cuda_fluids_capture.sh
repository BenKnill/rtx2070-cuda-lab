#!/usr/bin/env bash
set -euo pipefail

CUDA_PATH=/usr/local/cuda-11.0
export CUDA_PATH
export PATH="$CUDA_PATH/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_PATH/lib64:${LD_LIBRARY_PATH:-}"

SAMPLE=/mnt/c/Users/18572/blender-wsl-render/cuda_samples_11/5_Simulations/fluidsGL
OUT=/mnt/c/Users/18572/blender-wsl-render/cuda_demo_output
mkdir -p "$OUT"

cd "$SAMPLE"
rm -f fluidsGL.ppm

set +e
./fluidsGL -file=./data/ref_fluidsGL.ppm > "$OUT/fluidsGL_run.log" 2>&1
status=$?
set -e

printf 'fluidsGL exit status: %s\n' "$status"
tail -n 80 "$OUT/fluidsGL_run.log" || true

if [ -f fluidsGL.ppm ]; then
  cp fluidsGL.ppm "$OUT/fluidsGL.ppm"
  convert "$OUT/fluidsGL.ppm" "$OUT/fluidsGL.png"
  file "$OUT/fluidsGL.ppm" "$OUT/fluidsGL.png"
else
  printf '%s\n' "No fluidsGL.ppm was produced."
  exit 1
fi
