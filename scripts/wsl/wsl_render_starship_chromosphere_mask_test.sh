#!/usr/bin/env bash
set -euo pipefail

ROOT=/mnt/c/Users/18572/blender-wsl-render
RUN_ID="${1:-$(TZ=America/Indianapolis date '+%Y%m%d-%H%M%S')-starship-chromosphere-mask-test}"
OUT="$ROOT/render_outbox/$RUN_ID"
FRAMES="$OUT/frames"

mkdir -p "$OUT" "$FRAMES"

STARSHIP_IMAGEGEN_EXPORT_REPO=0 \
STARSHIP_IMAGEGEN_VIEW="${STARSHIP_IMAGEGEN_VIEW:-side}" \
STARSHIP_IMAGEGEN_OUT_DIR="$OUT" \
STARSHIP_IMAGEGEN_FRAME_DIR="$FRAMES" \
STARSHIP_IMAGEGEN_FRAME_COUNT=1 \
STARSHIP_IMAGEGEN_SAMPLES=24 \
STARSHIP_SOLAR_FRAMES="$ROOT/blender_bridge_output/chromosphere_lace_frames" \
STARSHIP_SOLAR_FRAME_PREFIX=chromosphere_lace \
STARSHIP_MASK="$ROOT/asset_library/generated/star_window_mask_hubble_best_v3_alpha.png" \
  /home/bluestar/.local/bin/blender -b --python "$ROOT/render_starship_imagegen_texture_scene.py"

cp "$OUT/starship_imagegen_texture_preview.png" "$OUT/poster.png"
cp "$ROOT/render_outbox/20260619-155950-chromosphere-lace-mask-preview/chromosphere_lace_raw.png" "$OUT/chromosphere_lace_raw.png" || true
cp "$ROOT/render_outbox/20260619-155950-chromosphere-lace-mask-preview/masked_best_v3.png" "$OUT/masked_best_v3.png" || true
cp "$ROOT/asset_library/generated/star_window_mask_hubble_best_v3_alpha.png" "$OUT/mask.png"

cat > "$OUT/manifest.txt" <<EOF
mode=starship-chromosphere-mask-test
created=$(TZ=America/Indianapolis date '+%Y-%m-%d %H:%M:%S %Z')
view=${STARSHIP_IMAGEGEN_VIEW:-side}
shader_frames=$ROOT/blender_bridge_output/chromosphere_lace_frames
mask=$ROOT/asset_library/generated/star_window_mask_hubble_best_v3_alpha.png
poster=$OUT/poster.png
EOF

echo "STARSHIP_CHROMOSPHERE_MASK_TEST_OK $OUT"
