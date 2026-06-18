import os
from pathlib import Path

import bpy


ROOT = Path(os.environ.get("BLENDER_WSL_RENDER_ROOT", "/mnt/c/Users/18572/blender-wsl-render"))
SEQ_DIR = ROOT / "blender_bridge_output" / "rocket_plume_sequence"
FRAME_DIR = ROOT / "blender_bridge_output" / "rocket_plume_zaware_frames"


def configure_zaware_cycles_render():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = int(os.environ.get("ZAWARE_CYCLES_SAMPLES", "24"))
    scene.cycles.preview_samples = 8
    scene.cycles.use_denoising = True

    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for device_type in ("OPTIX", "CUDA"):
            try:
                prefs.compute_device_type = device_type
                prefs.get_devices()
                enabled = False
                for device in prefs.devices:
                    if device.type != "CPU":
                        device.use = True
                        enabled = True
                if enabled:
                    scene.cycles.device = "GPU"
                    print(f"Cycles GPU enabled through {device_type}")
                    break
            except Exception as exc:
                print(f"Cycles {device_type} setup skipped: {exc}")
    except Exception as exc:
        print(f"Cycles GPU preference setup skipped: {exc}")

    scene.frame_start = 1
    scene.frame_end = int(os.environ.get("ZAWARE_FRAME_COUNT", "48"))
    scene.frame_set(1)
    scene.render.fps = 24
    scene.render.resolution_x = int(os.environ.get("ZAWARE_RES_X", "1120"))
    scene.render.resolution_y = int(os.environ.get("ZAWARE_RES_Y", "640"))
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Filmic"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = -0.15


def find_plume_materials():
    mats = []
    for mat in bpy.data.materials:
        if mat.name.lower().startswith("cuda plume card"):
            mats.append(mat)
    if not mats:
        raise RuntimeError("No cuda plume card materials found")
    return sorted(mats, key=lambda mat: mat.name)


def set_card_image(mat, image):
    if not mat.use_nodes:
        return
    for node in mat.node_tree.nodes:
        if node.bl_idname == "ShaderNodeTexImage":
            node.image = image
            node.extension = "CLIP"


def soften_scene_for_realtime():
    for obj in bpy.context.scene.objects:
        if obj.name.lower().startswith("cuda rocket plume card"):
            obj.visible_shadow = False
        if obj.name.lower() == "low density exhaust haze volume":
            obj.hide_render = True
            obj.hide_viewport = True

    for mat in bpy.data.materials:
        if mat.name.lower().startswith("cuda plume card"):
            mat.blend_method = "BLEND"
            mat.show_transparent_back = True
            if hasattr(mat, "use_screen_refraction"):
                mat.use_screen_refraction = False


def render_frames():
    mats = find_plume_materials()
    frame_paths = sorted(SEQ_DIR.glob("plume_seq_*.png"))
    if len(frame_paths) < 96:
        raise RuntimeError(f"Expected at least 96 sequence frames in {SEQ_DIR}, found {len(frame_paths)}")

    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    for old in FRAME_DIR.glob("frame_*.png"):
        old.unlink()

    scene = bpy.context.scene
    frame_count = int(os.environ.get("ZAWARE_FRAME_COUNT", "48"))
    frame_step = int(os.environ.get("ZAWARE_FRAME_STEP", "2"))
    for frame_number in range(1, frame_count + 1):
        base_idx = frame_number - 1
        seq_base = (base_idx * frame_step) % len(frame_paths)
        for mat_idx, mat in enumerate(mats):
            image_path = frame_paths[(seq_base + mat_idx * 5) % len(frame_paths)]
            image = bpy.data.images.load(str(image_path), check_existing=True)
            set_card_image(mat, image)

        scene.frame_set(frame_number)
        scene.render.filepath = str(FRAME_DIR / f"frame_{base_idx:03d}.png")
        bpy.ops.render.render(write_still=True)
        print(f"Rendered z-aware frame {base_idx:03d}")


configure_zaware_cycles_render()
soften_scene_for_realtime()
render_frames()
