#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: publish_outbox_post.sh /mnt/c/.../render_outbox/<run_id> [title] [description]" >&2
  exit 2
fi

RUN_DIR="$1"
TITLE="${2:-Outbox render}"
DESCRIPTION="${3:-Render output published from the Windows-visible outbox.}"

REPO=/mnt/c/Users/18572/blender-wsl-render/rtx2070-cuda-lab
MEDIA="$REPO/docs/media"

if [[ ! -d "$RUN_DIR" ]]; then
  echo "outbox directory not found: $RUN_DIR" >&2
  exit 1
fi

slug="$(basename "$RUN_DIR" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')"
stamp="$(TZ=America/Indianapolis date '+%Y-%m-%d %H:%M:%S %Z')"

mkdir -p "$MEDIA"
cd "$REPO"

poster_src="$RUN_DIR/poster.png"
[[ -f "$poster_src" ]] || poster_src="$RUN_DIR/starship_imagegen_texture_preview.png"
if [[ ! -f "$poster_src" ]]; then
  echo "no poster image found in $RUN_DIR" >&2
  exit 1
fi

poster="media/${slug}_poster.png"
cp "$poster_src" "docs/$poster"

mp4=""
gif=""
sun=""
mask=""

if [[ -f "$RUN_DIR/starship_imagegen_texture_scene.mp4" ]]; then
  mp4="media/${slug}.mp4"
  cp "$RUN_DIR/starship_imagegen_texture_scene.mp4" "docs/$mp4"
fi
if [[ -f "$RUN_DIR/starship_imagegen_texture_scene.gif" ]]; then
  gif="media/${slug}.gif"
  cp "$RUN_DIR/starship_imagegen_texture_scene.gif" "docs/$gif"
fi
if [[ -f "$RUN_DIR/stellar_surface_preview.png" ]]; then
  sun="media/${slug}_sun.png"
  cp "$RUN_DIR/stellar_surface_preview.png" "docs/$sun"
fi
for candidate in mask.png star_occluder_optical_alpha.png star_window_mask_deepfield_imagegen.png; do
  if [[ -f "$RUN_DIR/$candidate" ]]; then
    mask="media/${slug}_mask.png"
    cp "$RUN_DIR/$candidate" "docs/$mask"
    break
  fi
done

python3 - "$slug" "$stamp" "$TITLE" "$DESCRIPTION" "$poster" "$mp4" "$gif" "$sun" "$mask" <<'PY'
from html import escape
from pathlib import Path
import sys

slug, stamp, title, description, poster, mp4, gif, sun, mask = sys.argv[1:10]
path = Path("docs/index.html")
text = path.read_text(encoding="utf-8")

downloads = [f'<a class="button" href="{escape(poster)}">PNG</a>']
if gif:
    downloads.append(f'<a class="button" href="{escape(gif)}">GIF</a>')
if mp4:
    downloads.append(f'<a class="button" href="{escape(mp4)}">MP4</a>')
if sun:
    downloads.append(f'<a class="button" href="{escape(sun)}">SUN</a>')
if mask:
    downloads.append(f'<a class="button" href="{escape(mask)}">MASK</a>')

if mp4:
    media_html = (
        f'<video autoplay loop muted playsinline poster="{escape(poster)}" '
        f'aria-label="{escape(title)}">'
        f'\n              <source src="{escape(mp4)}" type="video/mp4">\n            </video>'
    )
else:
    media_html = f'<img src="{escape(poster)}" alt="{escape(title)}">'

post = f'''        <div class="feature" id="post-{escape(slug)}">
          <figure>
            {media_html}
            <figcaption>
              <strong>{escape(title)}</strong>
              {escape(description)}
              <div class="downloads">
                {' '.join(downloads)}
              </div>
            </figcaption>
          </figure>
          <div class="notes">
            <h2>{escape(stamp)}</h2>
            <p>
              Published from render outbox <code>{escape(slug)}</code>. New posts are inserted at the top of this gallery.
            </p>
          </div>
        </div>

'''

needle = '      <section class="gallery" aria-label="CUDA sample outputs">\n'
if needle not in text:
    raise SystemExit("gallery insertion point not found")
text = text.replace(needle, needle + post, 1)
path.write_text(text, encoding="utf-8")
PY

git add docs/index.html "docs/$poster"
[[ -n "$mp4" ]] && git add "docs/$mp4"
[[ -n "$gif" ]] && git add "docs/$gif"
[[ -n "$sun" ]] && git add "docs/$sun"
[[ -n "$mask" ]] && git add "docs/$mask"

git commit -m "Publish outbox post $slug"
git push origin main
git log --oneline --decorate -1
