import os
import shutil
from pathlib import Path

import bpy


ROOT = Path(os.environ.get("BLENDER_WSL_RENDER_ROOT", "/mnt/c/Users/18572/blender-wsl-render"))
LOCAL_BLEND = ROOT / "blender_bridge_output" / "cuda_smoke_cards_scene.blend"
REPO_BLEND = ROOT / "rtx2070-cuda-lab" / "assets" / "blender" / "cuda_smoke_cards_scene.blend"

if not LOCAL_BLEND.exists():
    raise RuntimeError(f"Missing local blend: {LOCAL_BLEND}")

bpy.ops.wm.open_mainfile(filepath=str(LOCAL_BLEND))
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(LOCAL_BLEND))
REPO_BLEND.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(LOCAL_BLEND, REPO_BLEND)
print(f"Packed and saved: {LOCAL_BLEND}")
print(f"Copied to repo: {REPO_BLEND}")
