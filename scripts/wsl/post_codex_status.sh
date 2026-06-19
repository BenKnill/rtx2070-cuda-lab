#!/usr/bin/env bash
set -euo pipefail

REPO=${REPO:-/mnt/c/Users/18572/blender-wsl-render/rtx2070-cuda-lab}
cd "$REPO"

message="${*:-alive}"
stamp="$(TZ=America/Indianapolis date '+%Y-%m-%d %H:%M:%S %Z')"
status="Codex live status: ${stamp} - ${message}"

tmp=$(mktemp)
awk -v status="$status" '
  /id="codex-status"/ {
    print "          <p class=\"codex-status\" id=\"codex-status\">" status "</p>"
    next
  }
  { print }
' docs/index.html > "$tmp"
mv "$tmp" docs/index.html

git add docs/index.html
git commit -m "Update Codex live status"
git push origin main
git log --oneline --decorate -1
