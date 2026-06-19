#!/usr/bin/env bash
set -euo pipefail

RUN_ID="${1:-$(TZ=America/Indianapolis date '+%Y%m%d-%H%M%S')-starship-v1-stills}"

ROOT=/mnt/c/Users/18572/blender-wsl-render
RAW="$ROOT/cuda_demo_output/starship_star_window_solar_ppm"
PNG="$ROOT/blender_bridge_output/starship_star_window_solar_frames"
OUT="$ROOT/render_outbox/$RUN_ID"
SRC_BIN="$ROOT/cuda_demo_output/stellar_surface_kernel"

mkdir -p "$RAW" "$PNG" "$OUT"

echo "== render-only Starship v1 still set =="
echo "out=$OUT"

echo
echo "== compile CUDA stellar surface kernel =="
/usr/local/cuda-12.6/bin/nvcc -O3 -std=c++17 -arch=sm_75 \
  "$ROOT/cuda_stellar_surface_kernel.cu" \
  -o "$SRC_BIN"

echo
echo "== generate CUDA solar frames =="
rm -f "$RAW"/stellar_surface_*.ppm
"$SRC_BIN" "$RAW" 48 1280 720

echo
echo "== convert solar frames to PNG =="
IMAGEMAGICK=$(command -v magick || command -v convert || true)
MONTAGE=$(command -v montage || true)
if [[ -z "$IMAGEMAGICK" || -z "$MONTAGE" ]]; then
  echo "ImageMagick convert/montage not found" >&2
  exit 1
fi
rm -f "$PNG"/stellar_surface_*.png
for f in "$RAW"/stellar_surface_*.ppm; do
  base=$(basename "$f" .ppm)
  "$IMAGEMAGICK" "$f" "$PNG/$base.png"
done

for view in hero aft side; do
  view_out="$OUT/$view"
  frames="$view_out/frames"
  mkdir -p "$frames"
  rm -f "$frames"/frame_*.png
  echo
  echo "== render $view still =="
  STARSHIP_IMAGEGEN_EXPORT_REPO=0 \
  STARSHIP_IMAGEGEN_VIEW="$view" \
  STARSHIP_IMAGEGEN_OUT_DIR="$view_out" \
  STARSHIP_IMAGEGEN_FRAME_DIR="$frames" \
  STARSHIP_IMAGEGEN_FRAME_COUNT=1 \
  STARSHIP_IMAGEGEN_SAMPLES=24 \
    /home/bluestar/.local/bin/blender -b --python "$ROOT/render_starship_imagegen_texture_scene.py"
  cp "$view_out/starship_imagegen_texture_preview.png" "$OUT/${view}.png"
done

"$MONTAGE" "$OUT/hero.png" "$OUT/aft.png" "$OUT/side.png" \
  -tile 1x3 -geometry +0+14 -background '#07090d' "$OUT/poster.png"

cp "$PNG/stellar_surface_000.png" "$OUT/stellar_surface_preview.png"
cp "$ROOT/asset_library/generated/star_occluder_optical_alpha.png" "$OUT/mask.png"
cp "$ROOT/asset_library/generated/starship_hull_wrap_v2_imagegen.png" "$OUT/starship_hull_wrap_v2_imagegen.png"
cp "$ROOT/asset_library/generated/starship_aft_engine_sheet_v2_imagegen.png" "$OUT/starship_aft_engine_sheet_v2_imagegen.png"

cat > "$OUT/manifest.txt" <<EOF
run_id=$RUN_ID
mode=starship-v1-still-set
created=$(TZ=America/Indianapolis date '+%Y-%m-%d %H:%M:%S %Z')
poster=$OUT/poster.png
hero=$OUT/hero.png
aft=$OUT/aft.png
side=$OUT/side.png
solar_preview=$OUT/stellar_surface_preview.png
mask=$OUT/mask.png
EOF

echo
echo "== outbox files =="
find "$OUT" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort
echo
echo "RENDER_OUTBOX_OK $OUT"
