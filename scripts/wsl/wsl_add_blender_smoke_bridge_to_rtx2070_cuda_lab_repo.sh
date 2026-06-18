#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/18572/blender-wsl-render"
REPO="$ROOT/rtx2070-cuda-lab"
LOG_DIR="$ROOT/cuda_care_logs"
BLENDER="$HOME/.local/bin/blender"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/wsl-add-blender-smoke-bridge-to-rtx2070-cuda-lab-$STAMP.txt"
exec > >(tee -a "$LOG") 2>&1

echo "Add Blender smoke bridge to RTX 2070 CUDA lab repo $STAMP"

PREVIEW="$REPO/docs/media/cuda_smoke_blender_bridge_preview.png"
BLEND="$REPO/assets/blender/cuda_smoke_cards_scene.blend"
CARDS_SRC="$ROOT/blender_bridge_output/smoke_cards"
CARDS_DST="$REPO/assets/blender/smoke_cards"

if [ ! -f "$PREVIEW" ]; then
  echo "Missing preview: $PREVIEW"
  exit 1
fi
if [ ! -f "$ROOT/blender_bridge_output/cuda_smoke_cards_scene.blend" ]; then
  echo "Missing local blend output"
  exit 1
fi
if [ ! -x "$BLENDER" ]; then
  echo "Blender not found at $BLENDER"
  exit 1
fi

mkdir -p "$REPO/assets/blender" "$CARDS_DST" "$REPO/scripts/wsl" "$REPO/scripts/blender"
cp "$CARDS_SRC"/smoke_card_*.png "$CARDS_DST/"
cp "$ROOT/create_cuda_smoke_cards_scene.py" "$REPO/scripts/blender/"
cp "$ROOT/pack_cuda_smoke_cards_scene.py" "$REPO/scripts/blender/"
cp "$ROOT/wsl_build_blender_smoke_bridge.sh" "$REPO/scripts/wsl/"
cp "$ROOT/wsl_add_blender_smoke_bridge_to_rtx2070_cuda_lab_repo.sh" "$REPO/scripts/wsl/"

BLENDER_WSL_RENDER_ROOT="$ROOT" "$BLENDER" -b --python "$ROOT/pack_cuda_smoke_cards_scene.py"

python3 - "$REPO" <<'PY'
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])
index = repo / "docs" / "index.html"
readme = repo / "README.md"

html = index.read_text()
if "media/cuda_smoke_blender_bridge_preview.png" not in html:
    block = """        <div class=\"feature\">
          <figure>
            <img src=\"media/cuda_smoke_blender_bridge_preview.png\" alt=\"Blender Cycles scene using CUDA smokeParticles frames as layered smoke cards\">
            <figcaption>
              <strong>Blender smoke-card bridge</strong>
              CUDA smokeParticles frames converted into layered Blender cloud cards, lit and rendered with Cycles.
              <div class=\"downloads\">
                <a class=\"button\" href=\"media/cuda_smoke_blender_bridge_preview.png\">PNG</a>
                <a class=\"button\" href=\"../assets/blender/cuda_smoke_cards_scene.blend\">BLEND</a>
              </div>
            </figcaption>
          </figure>
          <div class=\"notes\">
            <h2>Blender bridge</h2>
            <p>
              This is the first CUDA-to-Blender asset pass: the native CUDA smoke demo becomes reusable image-card atmosphere inside a lit Blender scene.
            </p>
            <p>
              The .blend packs the generated smoke-card textures so it can travel without the local capture folder.
            </p>
          </div>
        </div>

"""
    needle = """        <div class=\"feature\">
          <figure>
            <img src=\"media/fluidsGL_native_run.gif\""""
    html = html.replace(needle, block + needle, 1)
    index.write_text(html)

text = readme.read_text()
if "Blender smoke-card bridge" not in text:
    marker = "## What Is Here\n\n"
    addition = """## Blender Bridge

- `docs/media/cuda_smoke_blender_bridge_preview.png` - Cycles render using CUDA smokeParticles frames as layered cloud cards.
- `assets/blender/cuda_smoke_cards_scene.blend` - packed Blender scene containing the generated smoke-card textures.
- `assets/blender/smoke_cards/` - derived PNG cards from the CUDA smokeParticles frame capture.

"""
    text = text.replace(marker, addition + marker, 1)
    readme.write_text(text)
PY

echo
echo "== asset validation =="
identify -format '%f %w x %h %[colorspace]\n' "$PREVIEW"
ls -lh "$BLEND"
find "$CARDS_DST" -maxdepth 1 -name 'smoke_card_*.png' | wc -l

echo
echo "== git commit/push =="
cd "$REPO"
git status --short
git add README.md docs/index.html docs/media/cuda_smoke_blender_bridge_preview.png assets/blender/cuda_smoke_cards_scene.blend assets/blender/smoke_cards scripts/blender scripts/wsl/wsl_build_blender_smoke_bridge.sh scripts/wsl/wsl_add_blender_smoke_bridge_to_rtx2070_cuda_lab_repo.sh
if git diff --cached --quiet; then
  echo "No changes to commit"
else
  git commit -m "Add Blender smoke-card bridge scene"
  git push origin main
fi

echo
echo "== latest commit =="
git log --oneline --decorate -3

echo
echo "Done. Log: $LOG"
