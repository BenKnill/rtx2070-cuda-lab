#!/usr/bin/env bash
set -euo pipefail

OUT=/mnt/c/Users/18572/blender-wsl-render/cuda_demo_output

ffmpeg -y \
  -i "$OUT/fluidsGL_reference.gif" \
  -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p" \
  -movflags +faststart \
  "$OUT/fluidsGL_reference.mp4"

ffmpeg -y \
  -loop 1 \
  -t 6 \
  -i "$OUT/cuda_sim_contact.png" \
  -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p" \
  -r 30 \
  -movflags +faststart \
  "$OUT/cuda_sim_contact_hold.mp4"

ls -lh "$OUT"/*.mp4
file "$OUT"/*.mp4
