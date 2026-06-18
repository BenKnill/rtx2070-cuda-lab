#!/usr/bin/env bash
set -euo pipefail

OUT=/mnt/c/Users/18572/blender-wsl-render/cuda_demo_output

cp "$OUT/fluidsGL_reference.gif" "$OUT/fluidsGL_reference_inline.gif"

ffmpeg -y \
  -loop 1 \
  -t 5 \
  -i "$OUT/cuda_sim_contact.png" \
  -vf "fps=8,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer" \
  "$OUT/cuda_sim_contact_hold.gif"

ls -lh "$OUT"/*.gif
file "$OUT"/*.gif
