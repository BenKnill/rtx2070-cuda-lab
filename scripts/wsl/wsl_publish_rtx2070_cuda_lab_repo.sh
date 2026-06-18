#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/18572/blender-wsl-render"
REPO="$ROOT/rtx2070-cuda-lab"
SOURCE="$ROOT/blender-workbench-artifacts/docs/cuda-demo-gallery"
LOG_DIR="$ROOT/cuda_care_logs"
OWNER="BenKnill"
NAME="rtx2070-cuda-lab"
FULL="$OWNER/$NAME"
HTMLPREVIEW="https://htmlpreview.github.io/?https://github.com/$FULL/blob/main/docs/index.html"
PAGES_URL="https://benknill.github.io/$NAME/"

mkdir -p "$LOG_DIR" "$REPO/docs/media" "$REPO/scripts/windows" "$REPO/scripts/wsl" "$REPO/notes"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/wsl-publish-rtx2070-cuda-lab-$STAMP.txt"
exec > >(tee -a "$LOG") 2>&1

echo "Publish standalone RTX 2070 CUDA lab repo $STAMP"
echo "Repo: $REPO"
echo "GitHub: $FULL"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is not installed in WSL. Run wsl_install_or_probe_gh.sh first."
  exit 1
fi

echo
echo "== gh auth =="
gh auth status

echo
echo "== assemble files =="
cp "$SOURCE/index.html" "$REPO/docs/index.html"
cp "$SOURCE"/media/* "$REPO/docs/media/"
cp "$ROOT/cuda_care_notes.md" "$REPO/notes/cuda_care_notes.md"

cp "$ROOT"/win_build_cuda126_basic_samples.ps1 "$REPO/scripts/windows/" 2>/dev/null || true
cp "$ROOT"/win_build_run_cuda126_fluidsgl.ps1 "$REPO/scripts/windows/" 2>/dev/null || true
cp "$ROOT"/win_capture_fluidsgl_animation_frames.ps1 "$REPO/scripts/windows/" 2>/dev/null || true
cp "$ROOT"/win_capture_oceanfft_animation_frames.ps1 "$REPO/scripts/windows/" 2>/dev/null || true
cp "$ROOT"/win_capture_smokeparticles_animation_frames.ps1 "$REPO/scripts/windows/" 2>/dev/null || true
cp "$ROOT"/win_cuda126_env.ps1 "$REPO/scripts/windows/" 2>/dev/null || true
cp "$ROOT"/win_cuda_care_inventory.ps1 "$REPO/scripts/windows/" 2>/dev/null || true
cp "$ROOT"/win_install_cuda_126_toolkit.ps1 "$REPO/scripts/windows/" 2>/dev/null || true
cp "$ROOT"/win_probe_cuda_downloads.ps1 "$REPO/scripts/windows/" 2>/dev/null || true

cp "$ROOT"/wsl_*cuda*.sh "$REPO/scripts/wsl/" 2>/dev/null || true
cp "$ROOT"/wsl_*fluidsgl*.sh "$REPO/scripts/wsl/" 2>/dev/null || true
cp "$ROOT"/wsl_*oceanfft*.sh "$REPO/scripts/wsl/" 2>/dev/null || true
cp "$ROOT"/wsl_install_or_probe_gh.sh "$REPO/scripts/wsl/" 2>/dev/null || true

perl -0pi -e 's/CUDA Demo Gallery/RTX 2070 CUDA Lab/g; s/Temporary gallery branch for transfer and inspection\. Prefer a Release or permanent Pages gallery if these artifacts should live beyond the current handoff\./Standalone RTX 2070 CUDA sample gallery and care log for render-box experiments\./g' "$REPO/docs/index.html"

cat > "$REPO/README.md" <<EOF_README
Page: [RTX 2070 CUDA Lab gallery]($HTMLPREVIEW)

# RTX 2070 CUDA Lab

Standalone CUDA demo gallery and care notes for the RTX 2070 remote render/offload box.

The practical page lives in \`docs/index.html\`. GitHub's raw-file preview is available immediately through HTMLPreview above. If GitHub Pages is enabled successfully, the cleaner URL should be:

[$PAGES_URL]($PAGES_URL)

## What Is Here

- \`docs/index.html\` - the gallery page.
- \`docs/media/fluidsGL_native_run.gif\` / \`.mp4\` - native Windows CUDA/OpenGL fluidsGL animation.
- \`docs/media/oceanFFT_native_run.gif\` / \`.mp4\` - native Windows CUDA/CUFFT/OpenGL ocean surface animation.
- \`docs/media/cuda_sim_contact.png\` - contact sheet of non-windowed CUDA QA outputs.
- \`notes/cuda_care_notes.md\` - RTX 2070 and CUDA 12.6 setup notes.
- \`scripts/wsl/\` - WSL-first install, probe, conversion, and validation scripts.
- \`scripts/windows/\` - Windows-only native CUDA/OpenGL build/capture scripts for demos that need real Windows graphics interop.

## Box State

- GPU: NVIDIA RTX 2070, compute capability 7.5.
- Windows display driver observed during setup: 566.36, CUDA driver capability 12.7.
- CUDA Toolkit 12.6 installed on Windows and WSL.
- WSL GitHub CLI is the repo/publishing path.

## Policy

Use WSL for repo, GitHub, conversion, probing, and general scripting whenever possible. Use Windows scripts only for native CUDA/OpenGL demos where WSLg cannot provide CUDA/OpenGL interop.
EOF_README

cat > "$REPO/.gitignore" <<'EOF_GITIGNORE'
cuda_care_logs/
cuda_demo_output/
cuda_samples*/
downloads/
*.ppm
*.bin
*.obj
*.exe
*.pdb
*.ilk
EOF_GITIGNORE

cat > "$REPO/docs/README.md" <<EOF_DOCS
Page: [RTX 2070 CUDA Lab gallery]($HTMLPREVIEW)

This directory is the static gallery payload. GitHub Pages can serve it from \`/docs\` on \`main\`.
EOF_DOCS

echo "Assembled $(find "$REPO" -type f | wc -l) files"

echo
echo "== git init/commit =="
cd "$REPO"
if [ ! -d .git ]; then
  git init
fi
git checkout -B main
git config user.name "Codex"
git config user.email "codex@openai.com"
git add .
if git diff --cached --quiet; then
  echo "No local changes to commit"
else
  git commit -m "Initial RTX 2070 CUDA lab gallery"
fi

echo
echo "== create or verify GitHub repo =="
if gh repo view "$FULL" >/dev/null 2>&1; then
  echo "Repo already exists: $FULL"
else
  gh repo create "$FULL" --public --description "RTX 2070 CUDA demo gallery and care notes" --homepage "$PAGES_URL"
fi

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "https://github.com/$FULL.git"
else
  git remote add origin "https://github.com/$FULL.git"
fi

echo
echo "== push =="
git push -u origin main

echo
echo "== enable GitHub Pages from docs =="
PAGES_PAYLOAD="$(mktemp)"
cat > "$PAGES_PAYLOAD" <<EOF_JSON
{"source":{"branch":"main","path":"/docs"}}
EOF_JSON

set +e
gh api "repos/$FULL/pages" >/dev/null 2>&1
PAGES_EXISTS=$?
set -e

if [ "$PAGES_EXISTS" -eq 0 ]; then
  gh api --method PUT "repos/$FULL/pages" --input "$PAGES_PAYLOAD" >/dev/null || echo "Pages update failed; leaving HTMLPreview as canonical link for now."
else
  gh api --method POST "repos/$FULL/pages" --input "$PAGES_PAYLOAD" >/dev/null || echo "Pages create failed; leaving HTMLPreview as canonical link for now."
fi

echo
echo "== links =="
echo "Repo: https://github.com/$FULL"
echo "Page: $HTMLPREVIEW"
echo "Pages: $PAGES_URL"
echo
echo "Done. Log: $LOG"
