#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-quick}"
RUN_ID="${2:-$(TZ=America/Indianapolis date '+%Y%m%d-%H%M%S')-starship}"

ROOT=/mnt/c/Users/18572/blender-wsl-render
RAW="$ROOT/cuda_demo_output/starship_star_window_solar_ppm"
PNG="$ROOT/blender_bridge_output/starship_star_window_solar_frames"
OUT="$ROOT/render_outbox/$RUN_ID"
FRAMES="$OUT/frames"
SRC_BIN="$ROOT/cuda_demo_output/stellar_surface_kernel"

if [[ "$MODE" == "quick" ]]; then
  FRAME_COUNT=1
  SAMPLES=16
else
  FRAME_COUNT=48
  SAMPLES=36
fi

mkdir -p "$RAW" "$PNG" "$OUT" "$FRAMES"

echo "== render-only outbox job =="
echo "mode=$MODE"
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
if [[ -z "$IMAGEMAGICK" ]]; then
  echo "ImageMagick frontend not found: expected magick or convert" >&2
  exit 1
fi
rm -f "$PNG"/stellar_surface_*.png
for f in "$RAW"/stellar_surface_*.ppm; do
  base=$(basename "$f" .ppm)
  "$IMAGEMAGICK" "$f" "$PNG/$base.png"
done

cp "$PNG/stellar_surface_000.png" "$OUT/stellar_surface_preview.png"
cp "$ROOT/asset_library/generated/star_occluder_optical_alpha.png" "$OUT/mask.png"
cp "$ROOT/asset_library/generated/starship_hull_wrap_v2_imagegen.png" "$OUT/starship_hull_wrap_v2_imagegen.png"
cp "$ROOT/asset_library/generated/starship_aft_engine_sheet_v2_imagegen.png" "$OUT/starship_aft_engine_sheet_v2_imagegen.png"

echo
echo "== render Blender frames only =="
rm -f "$FRAMES"/frame_*.png
STARSHIP_IMAGEGEN_EXPORT_REPO=0 \
STARSHIP_IMAGEGEN_OUT_DIR="$OUT" \
STARSHIP_IMAGEGEN_FRAME_DIR="$FRAMES" \
STARSHIP_IMAGEGEN_FRAME_COUNT="$FRAME_COUNT" \
STARSHIP_IMAGEGEN_SAMPLES="$SAMPLES" \
  /home/bluestar/.local/bin/blender -b --python "$ROOT/render_starship_imagegen_texture_scene.py"

if [[ "$MODE" == "quick" ]]; then
  cp "$OUT/starship_imagegen_texture_preview.png" "$OUT/poster.png"
else
  ffmpeg -y -v error -framerate 12 -i "$FRAMES/frame_%03d.png" \
    -c:v libx264 -pix_fmt yuv420p -crf 18 -preset slow \
    "$OUT/starship_imagegen_texture_scene.mp4"

  ffmpeg -y -v error -i "$OUT/starship_imagegen_texture_scene.mp4" \
    -vf "fps=12,scale=960:-1:flags=lanczos,palettegen=stats_mode=diff" \
    "$OUT/palette.png"
  ffmpeg -y -v error -i "$OUT/starship_imagegen_texture_scene.mp4" -i "$OUT/palette.png" \
    -lavfi "fps=12,scale=960:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3" \
    "$OUT/starship_imagegen_texture_scene.gif"
  cp "$OUT/starship_imagegen_texture_preview.png" "$OUT/poster.png"
fi

cat > "$OUT/manifest.txt" <<EOF
run_id=$RUN_ID
mode=$MODE
created=$(TZ=America/Indianapolis date '+%Y-%m-%d %H:%M:%S %Z')
poster=$OUT/poster.png
mp4=$OUT/starship_imagegen_texture_scene.mp4
gif=$OUT/starship_imagegen_texture_scene.gif
blend=$OUT/starship_imagegen_texture_scene.blend
solar_preview=$OUT/stellar_surface_preview.png
mask=$OUT/mask.png
EOF

echo
echo "== outbox files =="
find "$OUT" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort
echo
echo "RENDER_OUTBOX_OK $OUT"
