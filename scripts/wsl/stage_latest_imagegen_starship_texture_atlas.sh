#!/usr/bin/env bash
set -euo pipefail

ROOT=${ROOT:-/mnt/c/Users/18572/blender-wsl-render}
GEN=${GEN:-/mnt/c/Users/18572/.codex/generated_images}
ASSETS="$ROOT/asset_library/generated"
OUTBOX="${1:-$ROOT/render_outbox/$(TZ=America/Indianapolis date '+%Y%m%d-%H%M%S')-starship-texture-atlas}"

mkdir -p "$ASSETS" "$OUTBOX"

OUTBOX_OVERRIDE="$OUTBOX" python3 - <<'PY'
from pathlib import Path
from PIL import Image, ImageDraw
import os
import shutil

root = Path("/mnt/c/Users/18572/blender-wsl-render")
gen = Path("/mnt/c/Users/18572/.codex/generated_images")
assets = root / "asset_library/generated"
outbox = Path(os.environ["OUTBOX_OVERRIDE"])

candidates = sorted(gen.rglob("*.png"), key=lambda p: p.stat().st_mtime, reverse=True)
if not candidates:
    raise SystemExit("no generated PNGs found")

src = candidates[0]
atlas = assets / "starship_texture_atlas_v2_imagegen.png"
hull = assets / "starship_hull_wrap_v2_imagegen.png"
aft = assets / "starship_aft_engine_sheet_v2_imagegen.png"

shutil.copy2(src, atlas)
img = Image.open(atlas).convert("RGB")
w, h = img.size

hull_crop = img.crop((0, 0, w, int(h * 0.64)))
hull_crop.resize((2048, 1024), Image.Resampling.LANCZOS).save(hull)

aft_crop = img.crop((int(w * 0.50), int(h * 0.50), w, h))
aft_crop.resize((1024, 1024), Image.Resampling.LANCZOS).save(aft)

files = [
    ("atlas", atlas),
    ("hull crop", hull),
    ("aft crop", aft),
]

thumbs = []
for label, path in files:
    im = Image.open(path).convert("RGB")
    im.thumbnail((720, 480), Image.Resampling.LANCZOS)
    panel = Image.new("RGB", (760, 540), (7, 9, 13))
    panel.paste(im, ((760 - im.width) // 2, 22))
    ImageDraw.Draw(panel).text((28, 500), label, fill=(230, 238, 248))
    thumbs.append(panel)
    shutil.copy2(path, outbox / path.name)

poster = Image.new("RGB", (760, 540 * len(thumbs)), (7, 9, 13))
for i, panel in enumerate(thumbs):
    poster.paste(panel, (0, i * 540))
poster.save(outbox / "poster.png")

(outbox / "manifest.txt").write_text(
    "mode=starship-texture-atlas\n"
    f"source={src}\n"
    f"poster={outbox / 'poster.png'}\n"
    f"atlas={atlas}\n"
    f"hull={hull}\n"
    f"aft={aft}\n",
    encoding="utf-8",
)

print(f"TEXTURE_OUTBOX_OK {outbox}")
print(f"ATLAS {atlas}")
print(f"HULL {hull}")
print(f"AFT {aft}")
PY
