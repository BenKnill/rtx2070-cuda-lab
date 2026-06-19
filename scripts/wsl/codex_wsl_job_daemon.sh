#!/usr/bin/env bash
set -euo pipefail

ROOT=${ROOT:-/mnt/c/Users/18572/blender-wsl-render}
BUS="$ROOT/.codex_page_bus"
JOB="$BUS/job.sh"
RUNNING="$BUS/running.sh"
STATE="$BUS/last.sha256"
LOG="$BUS/daemon.log"

mkdir -p "$BUS"
touch "$LOG"

echo "codex_wsl_job_daemon started at $(date -Is)" >> "$LOG"

while true; do
  if [[ -f "$JOB" ]]; then
    sha="$(sha256sum "$JOB" | awk '{print $1}')"
    last=""
    [[ -f "$STATE" ]] && last="$(cat "$STATE")"
    if [[ -s "$JOB" && "$sha" != "$last" ]]; then
      cp "$JOB" "$RUNNING"
      chmod +x "$RUNNING"
      {
        echo
        echo "=== job $sha started $(date -Is) ==="
        bash "$RUNNING"
        rc=$?
        echo "=== job $sha exited $rc $(date -Is) ==="
        exit "$rc"
      } >> "$LOG" 2>&1 || true
      echo "$sha" > "$STATE"
    fi
  fi
  sleep 1
done
