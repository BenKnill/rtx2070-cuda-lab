#!/usr/bin/env bash
set -euo pipefail

ROOT=/mnt/c/Users/18572/blender-wsl-render
RUN_ID="${1:-$(TZ=America/Indianapolis date '+%Y%m%d-%H%M%S')-chromosphere-lace-mask-preview}"
RAW="$ROOT/cuda_demo_output/chromosphere_lace_ppm"
PNG="$ROOT/blender_bridge_output/chromosphere_lace_frames"
OUT="$ROOT/render_outbox/$RUN_ID"
BIN="$ROOT/cuda_demo_output/chromosphere_lace_kernel"

MASK_BEST="$ROOT/asset_library/generated/star_window_mask_hubble_white_transparent_best_v3.png"
MASK_CANDIDATE="$ROOT/asset_library/generated/star_window_mask_hubble_white_transparent_candidate_v4.png"

mkdir -p "$RAW" "$PNG" "$OUT"

echo "== compile CUDA chromosphere lace shader =="
/usr/local/cuda-12.6/bin/nvcc -O3 -std=c++17 -arch=sm_75 \
  "$ROOT/rtx2070-cuda-lab/src/cuda/cuda_chromosphere_lace_kernel.cu" \
  -o "$BIN"

echo
echo "== generate CUDA shader frames =="
rm -f "$RAW"/chromosphere_lace_*.ppm "$PNG"/chromosphere_lace_*.png
"$BIN" "$RAW" 48 1280 720

IMAGEMAGICK=$(command -v magick || command -v convert || true)
MONTAGE=$(command -v montage || true)
if [[ -z "$IMAGEMAGICK" || -z "$MONTAGE" ]]; then
  echo "ImageMagick convert/montage not found" >&2
  exit 1
fi

echo
echo "== convert frames to PNG =="
for f in "$RAW"/chromosphere_lace_*.ppm; do
  base=$(basename "$f" .ppm)
  "$IMAGEMAGICK" "$f" "$PNG/$base.png"
done

echo
echo "== make masked previews and alpha masks =="
python_script="$OUT/.composite_fix.py"
# Keeping this as a tiny generated script avoids quoting traps with
# Windows-mounted paths.
cat > "$python_script" <<PY
from pathlib import Path
from PIL import Image, ImageDraw
import shutil

root = Path("/mnt/c/Users/18572/blender-wsl-render")
out = Path("$OUT")
png = root / "blender_bridge_output/chromosphere_lace_frames"

masks = [
    ("best_v3", root / "asset_library/generated/star_window_mask_hubble_white_transparent_best_v3.png"),
    ("candidate_v4", root / "asset_library/generated/star_window_mask_hubble_white_transparent_candidate_v4.png"),
]

shader = Image.open(png / "chromosphere_lace_000.png").convert("RGB")
for label, mask_path in masks:
    mask = Image.open(mask_path).convert("L").resize(shader.size, Image.Resampling.LANCZOS)
    hard = mask.point(lambda p: 255 if p > 116 else 0)
    black = Image.new("RGB", shader.size, (0, 0, 0))
    composite = Image.composite(shader, black, hard)
    composite.save(out / f"masked_{label}.png")

    alpha = hard.point(lambda p: 255 - p)
    alpha_img = Image.new("RGBA", shader.size, (0, 0, 0, 255))
    alpha_img.putalpha(alpha)
    alpha_name = f"star_window_mask_hubble_{label}_alpha.png"
    alpha_img.save(root / "asset_library/generated" / alpha_name)
    alpha_img.save(out / alpha_name)
    shutil.copy2(mask_path, out / f"source_mask_{label}.png")

shader.save(out / "chromosphere_lace_raw.png")

panels = []
for title, path in [
    ("raw CUDA chromosphere lace shader", out / "chromosphere_lace_raw.png"),
    ("masked through best_v3", out / "masked_best_v3.png"),
    ("masked through candidate_v4", out / "masked_candidate_v4.png"),
]:
    im = Image.open(path).convert("RGB")
    im.thumbnail((960, 540), Image.Resampling.LANCZOS)
    panel = Image.new("RGB", (1000, 610), (5, 7, 10))
    panel.paste(im, ((1000 - im.width) // 2, 18))
    ImageDraw.Draw(panel).text((24, 570), title, fill=(232, 239, 248))
    panels.append(panel)

poster = Image.new("RGB", (1000, 610 * len(panels)), (5, 7, 10))
for i, panel in enumerate(panels):
    poster.paste(panel, (0, i * 610))
poster.save(out / "poster.png")
PY

python3 "$python_script"

echo
echo "== make motion previews =="
ffmpeg -y -v error -framerate 12 -i "$PNG/chromosphere_lace_%03d.png" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -preset medium \
  "$OUT/chromosphere_lace_raw.mp4"

python3 - <<PY
from pathlib import Path
from PIL import Image

root = Path("/mnt/c/Users/18572/blender-wsl-render")
png = root / "blender_bridge_output/chromosphere_lace_frames"
out = Path("$OUT")
mask = Image.open(root / "asset_library/generated/star_window_mask_hubble_white_transparent_best_v3.png").convert("L")
for frame in range(48):
    shader = Image.open(png / f"chromosphere_lace_{frame:03d}.png").convert("RGB")
    hard = mask.resize(shader.size, Image.Resampling.LANCZOS).point(lambda p: 255 if p > 116 else 0)
    comp = Image.composite(shader, Image.new("RGB", shader.size, (0, 0, 0)), hard)
    comp.save(out / f"masked_frame_{frame:03d}.png")
PY

ffmpeg -y -v error -framerate 12 -i "$OUT/masked_frame_%03d.png" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -preset medium \
  "$OUT/clip.mp4"
ffmpeg -y -v error -i "$OUT/clip.mp4" \
  -vf "fps=12,scale=960:-1:flags=lanczos,palettegen=stats_mode=diff" \
  "$OUT/palette.png"
ffmpeg -y -v error -i "$OUT/clip.mp4" -i "$OUT/palette.png" \
  -lavfi "fps=12,scale=960:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3" \
  "$OUT/clip.gif"

cat > "$OUT/manifest.txt" <<EOF
mode=chromosphere-lace-shader-mask-preview
created=$(TZ=America/Indianapolis date '+%Y-%m-%d %H:%M:%S %Z')
shader_frames=$PNG
raw_shader=$OUT/chromosphere_lace_raw.png
best_mask_alpha=$ROOT/asset_library/generated/star_window_mask_hubble_best_v3_alpha.png
candidate_mask_alpha=$ROOT/asset_library/generated/star_window_mask_hubble_candidate_v4_alpha.png
poster=$OUT/poster.png
clip=$OUT/clip.mp4
EOF

echo
echo "== outbox files =="
find "$OUT" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort
echo
echo "CHROMOSPHERE_LACE_PREVIEW_OK $OUT"
