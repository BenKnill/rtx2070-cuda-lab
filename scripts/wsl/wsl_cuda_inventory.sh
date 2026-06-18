#!/usr/bin/env bash
set -u

echo "--- nvcc search ---"
find /usr/local -maxdepth 4 -type f -name nvcc -print 2>/dev/null || true

echo "--- cuda sample search ---"
find /usr/local -maxdepth 5 \( -iname '*fluid*' -o -iname '*smoke*' -o -iname '*ocean*' \) -print 2>/dev/null || true

echo "--- cuda bin/include/lib snapshot ---"
for dir in /usr/local/cuda /usr/local/cuda-11.0; do
  echo "## $dir"
  ls "$dir" 2>/dev/null || true
  ls "$dir/bin" 2>/dev/null | sed -n '1,60p' || true
  ls "$dir/samples" 2>/dev/null | sed -n '1,60p' || true
done

echo "--- apt cuda packages already installed ---"
dpkg -l | grep -E 'cuda|nvidia-cuda|freeglut|mesa|cmake' || true
