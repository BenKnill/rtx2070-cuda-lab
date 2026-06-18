#!/usr/bin/env bash
set -euo pipefail

CUDA_PATH=/usr/local/cuda-11.0
export CUDA_PATH
export PATH="$CUDA_PATH/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_PATH/lib64:${LD_LIBRARY_PATH:-}"

ROOT=/mnt/c/Users/18572/blender-wsl-render
OUT="$ROOT/cuda_demo_output"
mkdir -p "$OUT"

printf '%s\n' "--- smokeParticles CUDA QA ---"
cd "$ROOT/cuda_samples_11/5_Simulations/smokeParticles"
rm -f smokeParticles_pos.bin smokeParticles_vel.bin
set +e
./smokeParticles -qatest -n=65536 > "$OUT/smokeParticles_qatest.log" 2>&1
smoke_status=$?
set -e
printf 'smokeParticles exit status: %s\n' "$smoke_status"
tail -n 80 "$OUT/smokeParticles_qatest.log" || true
cp smokeParticles_pos.bin "$OUT/smokeParticles_pos.bin"
cp smokeParticles_vel.bin "$OUT/smokeParticles_vel.bin"

printf '%s\n' "--- oceanFFT CUDA QA ---"
cd "$ROOT/cuda_samples_11/5_Simulations/oceanFFT"
rm -f spatialDomain.bin slopeShading.bin
set +e
./oceanFFT -qatest > "$OUT/oceanFFT_qatest.log" 2>&1
ocean_status=$?
set -e
printf 'oceanFFT exit status: %s\n' "$ocean_status"
tail -n 80 "$OUT/oceanFFT_qatest.log" || true
cp spatialDomain.bin "$OUT/spatialDomain.bin"
cp slopeShading.bin "$OUT/slopeShading.bin"

printf '%s\n' "--- visualizing binary outputs ---"
python3 "$ROOT/visualize_cuda_sim_bins.py" \
  --ocean-spatial "$OUT/spatialDomain.bin" \
  --ocean-slope "$OUT/slopeShading.bin" \
  --ocean-out "$OUT/oceanFFT.ppm" \
  --smoke-pos "$OUT/smokeParticles_pos.bin" \
  --smoke-vel "$OUT/smokeParticles_vel.bin" \
  --smoke-out "$OUT/smokeParticles.ppm"

convert "$OUT/oceanFFT.ppm" "$OUT/oceanFFT.png"
convert "$OUT/smokeParticles.ppm" "$OUT/smokeParticles.png"

montage "$OUT/oceanFFT.png" "$OUT/smokeParticles.png" \
  -tile 2x1 \
  -geometry 640x400+24+34 \
  -background '#0b0d12' \
  -bordercolor '#202838' \
  -border 2 \
  "$OUT/cuda_sim_contact.png"

file "$OUT/oceanFFT.png" "$OUT/smokeParticles.png" "$OUT/cuda_sim_contact.png"
