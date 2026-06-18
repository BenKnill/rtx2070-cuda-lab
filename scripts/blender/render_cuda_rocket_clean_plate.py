from pathlib import Path

import bpy


ROOT = Path("/mnt/c/Users/18572/blender-wsl-render")
OUT = ROOT / "blender_bridge_output" / "cuda_rocket_plume_clean_plate.png"


def configure_cycles():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 128
    scene.cycles.preview_samples = 32
    scene.cycles.use_denoising = True
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "OPTIX"
        for device in prefs.devices:
            device.use = device.type in {"OPTIX", "CUDA"}
        scene.cycles.device = "GPU"
    except Exception as exc:
        print(f"GPU setup skipped: {exc}")


def hide_plume_helpers():
    hide_tokens = (
        "cuda rocket plume card",
        "low density exhaust haze volume",
        "nozzle throat light",
        "plume warm fill",
    )
    for obj in bpy.context.scene.objects:
        if any(token in obj.name.lower() for token in hide_tokens):
            obj.hide_render = True
            obj.hide_viewport = True


configure_cycles()
hide_plume_helpers()
OUT.parent.mkdir(parents=True, exist_ok=True)
bpy.context.scene.render.filepath = str(OUT)
bpy.ops.render.render(write_still=True)
print(f"Clean plate: {OUT}")
