#!/usr/bin/env bash
set -euo pipefail

ROOT=/mnt/c/Users/18572/blender-wsl-render
OUT="$ROOT/asset_library/renders/gateway_plasma_keyframe.png"

/home/bluestar/.local/bin/blender -b --python "$ROOT/render_asset_shader_keyframe.py"
identify -format '%f %w x %h %[size]\n' "$OUT"
