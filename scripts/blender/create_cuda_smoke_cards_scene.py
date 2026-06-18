import math
import os
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(os.environ.get("BLENDER_WSL_RENDER_ROOT", "/mnt/c/Users/18572/blender-wsl-render"))
CARD_DIR = ROOT / "blender_bridge_output" / "smoke_cards"
OUT_DIR = ROOT / "blender_bridge_output"
REPO = ROOT / "rtx2070-cuda-lab"
RENDER_PATH = OUT_DIR / "cuda_smoke_blender_bridge_preview.png"
BLEND_PATH = OUT_DIR / "cuda_smoke_cards_scene.blend"
REPO_RENDER_PATH = REPO / "docs" / "media" / "cuda_smoke_blender_bridge_preview.png"
REPO_BLEND_PATH = REPO / "assets" / "blender" / "cuda_smoke_cards_scene.blend"


def ensure_dir(path):
    path.mkdir(parents=True, exist_ok=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def look_at(obj, target, track="-Z", up="Y"):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat(track, up).to_euler()


def make_principled_mat(name, color, roughness=0.75, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    return mat


def make_smoke_card_mat(name, image_path):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.blend_method = "BLEND"
    mat.use_screen_refraction = False
    mat.show_transparent_back = True

    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out = nodes.new("ShaderNodeOutputMaterial")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(image_path))
    tex.extension = "CLIP"

    rgb_to_bw = nodes.new("ShaderNodeRGBToBW")
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.025
    ramp.color_ramp.elements[0].color = (0.0, 0.0, 0.0, 0.0)
    ramp.color_ramp.elements[1].position = 0.18
    ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)

    transparent = nodes.new("ShaderNodeBsdfTransparent")
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    principled.inputs["Roughness"].default_value = 0.92
    principled.inputs["Alpha"].default_value = 0.72

    mix = nodes.new("ShaderNodeMixShader")

    links.new(tex.outputs["Color"], rgb_to_bw.inputs["Color"])
    links.new(rgb_to_bw.outputs["Val"], ramp.inputs["Fac"])
    links.new(tex.outputs["Color"], principled.inputs["Base Color"])
    links.new(ramp.outputs["Alpha"], mix.inputs["Fac"])
    links.new(transparent.outputs["BSDF"], mix.inputs[1])
    links.new(principled.outputs["BSDF"], mix.inputs[2])
    links.new(mix.outputs["Shader"], out.inputs["Surface"])
    return mat


def add_plane(name, loc, scale, mat):
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    if mat:
        obj.data.materials.append(mat)
    return obj


def add_cube(name, loc, scale, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    if mat:
        obj.data.materials.append(mat)
    return obj


def configure_cycles():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 160
    scene.cycles.preview_samples = 32
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Filmic"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0

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


def build_scene():
    ensure_dir(OUT_DIR)
    ensure_dir(REPO_RENDER_PATH.parent)
    ensure_dir(REPO_BLEND_PATH.parent)
    clear_scene()
    configure_cycles()

    floor_mat = make_principled_mat("charcoal concrete", (0.025, 0.029, 0.032, 1.0), 0.86)
    wall_mat = make_principled_mat("matte graphite walls", (0.055, 0.062, 0.07, 1.0), 0.9)
    glass_mat = make_principled_mat("dim cyan glass", (0.08, 0.25, 0.32, 1.0), 0.18, 0.0)
    glass_bsdf = glass_mat.node_tree.nodes.get("Principled BSDF")
    if glass_bsdf:
        glass_bsdf.inputs["Alpha"].default_value = 0.32
        glass_bsdf.inputs["Transmission Weight"].default_value = 0.18
    glass_mat.blend_method = "BLEND"

    add_plane("floor", (0.0, 0.0, 0.0), (8.0, 7.0, 1.0), floor_mat)
    back = add_plane("back wall", (0.0, 3.2, 2.2), (8.0, 4.4, 1.0), wall_mat)
    back.rotation_euler[0] = math.radians(90)
    left = add_plane("left wall", (-4.0, 0.0, 2.2), (7.0, 4.4, 1.0), wall_mat)
    left.rotation_euler[1] = math.radians(90)

    add_cube("low glass plinth", (0.0, 0.55, 0.35), (2.8, 1.3, 0.08), glass_mat)
    add_cube("dark equipment block", (-2.8, 1.3, 0.8), (0.45, 0.4, 0.8), wall_mat)
    add_cube("dark equipment block right", (2.65, 1.1, 0.65), (0.38, 0.5, 0.65), wall_mat)

    card_images = sorted(CARD_DIR.glob("smoke_card_*.png"))
    if not card_images:
        raise RuntimeError(f"No smoke cards found in {CARD_DIR}")

    camera_loc = Vector((4.7, -5.8, 3.1))
    target = Vector((0.0, 0.85, 1.6))

    offsets = [
        (-0.95, 0.00, 1.42, 3.4, 2.72, -9.0),
        (-0.38, 0.18, 1.56, 3.9, 3.12, 5.0),
        (0.35, 0.33, 1.48, 3.6, 2.88, -3.5),
        (0.82, 0.52, 1.68, 3.1, 2.48, 8.0),
        (-0.12, 0.72, 1.86, 2.8, 2.24, -12.0),
    ]

    for idx, data in enumerate(offsets):
        img = card_images[min(idx * 2, len(card_images) - 1)]
        x, y, z, sx, sy, roll = data
        mat = make_smoke_card_mat(f"cuda smoke card {idx:02d}", img)
        card = add_plane(f"cuda smoke card {idx:02d}", (x, y, z), (sx, sy, 1.0), mat)
        direction = camera_loc - card.location
        card.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
        card.rotation_euler.rotate_axis("Z", math.radians(roll))

    volume_mat = bpy.data.materials.new("thin stage haze")
    volume_mat.use_nodes = True
    nodes = volume_mat.node_tree.nodes
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    vol = nodes.new("ShaderNodeVolumeScatter")
    vol.inputs["Color"].default_value = (0.30, 0.46, 0.62, 1.0)
    vol.inputs["Density"].default_value = 0.018
    volume_mat.node_tree.links.new(vol.outputs["Volume"], out.inputs["Volume"])
    haze = add_cube("thin stage haze volume", (0.0, 0.75, 1.55), (3.8, 2.5, 1.7), volume_mat)
    haze.display_type = "WIRE"

    bpy.ops.object.light_add(type="AREA", location=(-2.8, -2.4, 4.8))
    key = bpy.context.object
    key.name = "large soft key"
    key.data.energy = 540
    key.data.size = 4.0
    look_at(key, (0.0, 0.7, 1.4))

    bpy.ops.object.light_add(type="AREA", location=(3.8, 2.4, 2.7))
    rim = bpy.context.object
    rim.name = "cyan rim through smoke"
    rim.data.energy = 900
    rim.data.size = 1.8
    rim.data.color = (0.36, 0.68, 1.0)
    look_at(rim, (0.0, 0.55, 1.6))

    bpy.ops.object.light_add(type="POINT", location=(-1.6, 0.1, 1.1))
    ember = bpy.context.object
    ember.name = "warm low practical"
    ember.data.energy = 95
    ember.data.color = (1.0, 0.50, 0.26)

    bpy.ops.object.camera_add(location=camera_loc)
    cam = bpy.context.object
    cam.name = "bridge preview camera"
    look_at(cam, target)
    cam.data.lens = 38
    cam.data.dof.use_dof = True
    cam.data.dof.focus_distance = (camera_loc - target).length
    cam.data.dof.aperture_fstop = 5.6
    bpy.context.scene.camera = cam

    scene = bpy.context.scene
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("deep blue world")
    scene.world.color = (0.005, 0.007, 0.011)

    scene.render.filepath = str(RENDER_PATH)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.render.render(write_still=True)

    import shutil

    shutil.copyfile(RENDER_PATH, REPO_RENDER_PATH)
    shutil.copyfile(BLEND_PATH, REPO_BLEND_PATH)
    print(f"Render: {RENDER_PATH}")
    print(f"Repo render: {REPO_RENDER_PATH}")
    print(f"Blend: {BLEND_PATH}")
    print(f"Repo blend: {REPO_BLEND_PATH}")


if __name__ == "__main__":
    build_scene()
