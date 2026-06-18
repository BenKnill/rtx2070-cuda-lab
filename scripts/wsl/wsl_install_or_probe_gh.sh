#!/usr/bin/env bash
set -euo pipefail

ROOT="/mnt/c/Users/18572/blender-wsl-render"
LOG_DIR="$ROOT/cuda_care_logs"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/wsl-gh-install-probe-$STAMP.txt"
exec > >(tee -a "$LOG") 2>&1

echo "WSL GitHub CLI install/probe $STAMP"
echo "User: $(whoami)"
echo "Distro: $(lsb_release -ds 2>/dev/null || cat /etc/os-release)"

if ! command -v gh >/dev/null 2>&1; then
  echo
  echo "== Install gh =="
  sudo apt-get update
  sudo apt-get install -y curl ca-certificates gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
    sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
    sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y gh
else
  echo
  echo "== gh already installed =="
fi

echo
echo "== gh path =="
command -v gh

echo
echo "== gh version =="
gh --version

echo
echo "== gh auth status =="
set +e
gh auth status
AUTH_EXIT=$?
set -e
echo "gh auth status exit code: $AUTH_EXIT"

echo
echo "Done. Log: $LOG"
