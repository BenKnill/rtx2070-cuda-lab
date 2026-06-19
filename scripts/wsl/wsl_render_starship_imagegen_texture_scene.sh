#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-full}"
ROOT=/mnt/c/Users/18572/blender-wsl-render
REPO="$ROOT/rtx2070-cuda-lab"
RAW="$ROOT/cuda_demo_output/starship_star_window_solar_ppm"
PNG="$ROOT/blender_bridge_output/starship_star_window_solar_frames"
FRAMES="$ROOT/blender_bridge_output/starship_imagegen_texture_frames"
LOCAL="$ROOT/blender_bridge_output/starship_imagegen_texture_scene"
MEDIA="$REPO/docs/media"
SRC_BIN="$ROOT/cuda_demo_output/stellar_surface_kernel"

if [[ "$MODE" == "quick" ]]; then
  FRAME_COUNT=1
  SAMPLES=20
else
  FRAME_COUNT=48
  SAMPLES=36
fi

mkdir -p "$RAW" "$PNG" "$FRAMES" "$LOCAL" "$MEDIA" "$REPO/assets/blender" "$REPO/assets/textures"

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

cp "$ROOT/asset_library/generated/starship_hull_wrap_imagegen.png" "$REPO/assets/textures/starship_hull_wrap_imagegen.png"
cp "$ROOT/asset_library/generated/star_window_mask_imagegen.png" "$REPO/assets/textures/star_window_mask_imagegen.png"
cp "$ROOT/asset_library/generated/star_window_mask_deepfield_imagegen.png" "$REPO/assets/textures/star_window_mask_deepfield_imagegen.png"

echo
echo "== render Blender imagegen-textured Starship scene ($MODE) =="
rm -f "$FRAMES"/frame_*.png
STARSHIP_IMAGEGEN_FRAME_COUNT="$FRAME_COUNT" STARSHIP_IMAGEGEN_SAMPLES="$SAMPLES" \
  /home/bluestar/.local/bin/blender -b --python "$ROOT/render_starship_imagegen_texture_scene.py"

if [[ "$MODE" == "quick" ]]; then
  echo
  echo "== quick output =="
  identify -format '%f %w x %h %[size]\n' "$MEDIA/starship_imagegen_texture_preview.png"
  echo "STARSHIP_IMAGEGEN_QUICK_OK"
  exit 0
fi

echo
echo "== encode animation =="
ffmpeg -y -v error -framerate 12 -i "$FRAMES/frame_%03d.png" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -preset slow \
  "$MEDIA/starship_imagegen_texture_scene.mp4"

ffmpeg -y -v error -i "$MEDIA/starship_imagegen_texture_scene.mp4" \
  -vf "fps=12,scale=960:-1:flags=lanczos,palettegen=stats_mode=diff" \
  "$LOCAL/starship_imagegen_texture_palette.png"
ffmpeg -y -v error -i "$MEDIA/starship_imagegen_texture_scene.mp4" -i "$LOCAL/starship_imagegen_texture_palette.png" \
  -lavfi "fps=12,scale=960:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3" \
  "$MEDIA/starship_imagegen_texture_scene.gif"

cp "$MEDIA/starship_imagegen_texture_preview.png" "$LOCAL/starship_imagegen_texture_preview.png"
cp "$MEDIA/starship_imagegen_texture_scene.mp4" "$LOCAL/starship_imagegen_texture_scene.mp4"
cp "$MEDIA/starship_imagegen_texture_scene.gif" "$LOCAL/starship_imagegen_texture_scene.gif"

echo
echo "== outputs =="
identify -format '%f %w x %h %[size]\n' "$MEDIA/starship_imagegen_texture_preview.png" "$MEDIA/starship_imagegen_texture_scene.gif"
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,nb_frames,duration,avg_frame_rate \
  -of default=noprint_wrappers=1 "$MEDIA/starship_imagegen_texture_scene.mp4"
stat -c 'starship_imagegen_texture_scene.blend %s bytes' "$REPO/assets/blender/starship_imagegen_texture_scene.blend"

echo
echo "STARSHIP_IMAGEGEN_FULL_OK"
