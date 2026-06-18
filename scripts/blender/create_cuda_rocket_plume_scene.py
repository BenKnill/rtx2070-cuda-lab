import math
import os
import shutil
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(os.environ.get("BLENDER_WSL_RENDER_ROOT", "/mnt/c/Users/18572/blender-wsl-render"))
CARD_DIR = ROOT / "blender_bridge_output" / "rocket_plume_cards"
OUT_DIR = ROOT / "blender_bridge_output"
REPO = ROOT / "rtx2070-cuda-lab"
RENDER_PATH = OUT_DIR / "cuda_rocket_plume_blender_preview.png"
BLEND_PATH = OUT_DIR / "cuda_rocket_plume_scene.blend"
REPO_RENDER_PATH = REPO / "docs" / "media" / "cuda_rocket_plume_blender_preview.png"
REPO_BLEND_PATH = REPO / "assets" / "blender" / "cuda_rocket_plume_scene.blend"


def ensure_dir(path):
    path.mkdir(parents=True, exist_ok=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def look_at(obj, target, track="-Z", up="Y"):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat(track, up).to_euler()


def make_mat(name, color, roughness=0.55, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    return mat


def make_plume_mat(name, image_path, strength=3.0):
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
    ramp.color_ramp.elements[0].position = 0.08
    ramp.color_ramp.elements[0].color = (0.0, 0.0, 0.0, 0.0)
    ramp.color_ramp.elements[1].position = 0.28
    ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)

    transparent = nodes.new("ShaderNodeBsdfTransparent")
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Strength"].default_value = strength
    mix = nodes.new("ShaderNodeMixShader")

    links.new(tex.outputs["Color"], rgb_to_bw.inputs["Color"])
    links.new(rgb_to_bw.outputs["Val"], ramp.inputs["Fac"])
    links.new(tex.outputs["Color"], emission.inputs["Color"])
    links.new(ramp.outputs["Color"], mix.inputs["Fac"])
    links.new(transparent.outputs["BSDF"], mix.inputs[1])
    links.new(emission.outputs["Emission"], mix.inputs[2])
    links.new(mix.outputs["Shader"], out.inputs["Surface"])
    return mat


def configure_cycles():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 192
    scene.cycles.preview_samples = 32
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Filmic"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = -0.15

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


def add_body_part(kind, name, location, rotation, **kwargs):
    if kind == "cylinder":
        bpy.ops.mesh.primitive_cylinder_add(location=location, rotation=rotation, **kwargs)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(location=location, rotation=rotation, **kwargs)
    obj = bpy.context.object
    obj.name = name
    return obj


def add_fin(name, angle, mat):
    radius = 0.34
    x0 = -1.55
    x1 = -1.05
    out = 0.72
    thick = 0.035
    ca = math.cos(angle)
    sa = math.sin(angle)

    def p(x, r, offset=0.0):
        return (x, ca * (r + offset), 1.25 + sa * (r + offset))

    side = Vector((0.0, -sa, ca)) * thick
    verts = [
        Vector(p(x0, radius)) - side,
        Vector(p(x0, out)) - side,
        Vector(p(x1, radius)) - side,
        Vector(p(x0, radius)) + side,
        Vector(p(x0, out)) + side,
        Vector(p(x1, radius)) + side,
    ]
    faces = [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def build_scene():
    ensure_dir(OUT_DIR)
    ensure_dir(REPO_RENDER_PATH.parent)
    ensure_dir(REPO_BLEND_PATH.parent)
    clear_scene()
    configure_cycles()

    white = make_mat("warm ceramic white", (0.86, 0.83, 0.76, 1.0), 0.48)
    graphite = make_mat("ablative graphite nozzle", (0.035, 0.032, 0.03, 1.0), 0.82)
    black = make_mat("matte black trim", (0.015, 0.016, 0.018, 1.0), 0.7)
    copper = make_mat("dark copper fins", (0.55, 0.18, 0.07, 1.0), 0.45, 0.2)
    floor_mat = make_mat("scored launch concrete", (0.045, 0.047, 0.05, 1.0), 0.9)

    body = add_body_part(
        "cylinder",
        "procedural rocket body",
        (0.0, 0.0, 1.25),
        (0.0, math.radians(90), 0.0),
        vertices=96,
        radius=0.34,
        depth=3.7,
    )
    body.data.materials.append(white)

    nose = add_body_part(
        "cone",
        "procedural nose cone",
        (2.30, 0.0, 1.25),
        (0.0, math.radians(90), 0.0),
        vertices=96,
        radius1=0.34,
        radius2=0.0,
        depth=0.9,
    )
    nose.data.materials.append(white)

    stripe = add_body_part(
        "cylinder",
        "black aft band",
        (-1.38, 0.0, 1.25),
        (0.0, math.radians(90), 0.0),
        vertices=96,
        radius=0.345,
        depth=0.18,
    )
    stripe.data.materials.append(black)

    nozzle = add_body_part(
        "cone",
        "bell nozzle",
        (-2.04, 0.0, 1.25),
        (0.0, math.radians(90), 0.0),
        vertices=96,
        radius1=0.13,
        radius2=0.29,
        depth=0.44,
    )
    nozzle.data.materials.append(graphite)

    for idx, angle in enumerate((math.radians(90), math.radians(210), math.radians(330))):
        add_fin(f"stabilizer fin {idx}", angle, copper)

    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(-1.65, 0.0, 0.0))
    floor = bpy.context.object
    floor.name = "launch pad floor"
    floor.scale = (8.0, 5.5, 1.0)
    floor.data.materials.append(floor_mat)

    card_images = sorted(CARD_DIR.glob("plume_card_*.png"))
    if not card_images:
        raise RuntimeError(f"No plume cards found in {CARD_DIR}")

    length = 4.85
    height = 2.15
    center_x = -4.62
    center_z = 1.25
    rotations = [0, 28, -28, 58, -58, 90]
    for idx, rot in enumerate(rotations):
        img = card_images[min(idx * 2, len(card_images) - 1)]
        mat = make_plume_mat(f"cuda plume card {idx:02d}", img, 3.1 - idx * 0.18)
        bpy.ops.mesh.primitive_plane_add(
            size=1.0,
            location=(center_x, 0.0, center_z),
            rotation=(math.radians(90 + rot), 0.0, 0.0),
        )
        card = bpy.context.object
        card.name = f"cuda rocket plume card {idx:02d}"
        card.scale = (length, height, 1.0)
        card.visible_shadow = False
        card.data.materials.append(mat)

    glow_mat = bpy.data.materials.new("blue orange plume haze")
    glow_mat.use_nodes = True
    nodes = glow_mat.node_tree.nodes
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    vol = nodes.new("ShaderNodeVolumeScatter")
    vol.inputs["Color"].default_value = (0.85, 0.45, 0.22, 1.0)
    vol.inputs["Density"].default_value = 0.006
    glow_mat.node_tree.links.new(vol.outputs["Volume"], out.inputs["Volume"])
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=1.0, location=(-4.35, 0.0, 1.25))
    haze = bpy.context.object
    haze.name = "low density exhaust haze volume"
    haze.scale = (2.85, 0.82, 0.58)
    haze.visible_shadow = False
    haze.data.materials.append(glow_mat)
    haze.display_type = "WIRE"

    bpy.ops.object.light_add(type="POINT", location=(-2.38, 0.0, 1.25))
    throat = bpy.context.object
    throat.name = "nozzle throat light"
    throat.data.energy = 420
    throat.data.color = (0.55, 0.72, 1.0)

    bpy.ops.object.light_add(type="AREA", location=(-4.3, -1.4, 1.45))
    plume_fill = bpy.context.object
    plume_fill.name = "plume warm fill"
    plume_fill.data.energy = 520
    plume_fill.data.size = 2.6
    plume_fill.data.color = (1.0, 0.48, 0.20)

    bpy.ops.object.light_add(type="AREA", location=(1.4, -4.8, 4.2))
    key = bpy.context.object
    key.name = "large rocket key"
    key.data.energy = 420
    key.data.size = 5.0
    look_at(key, (-1.1, 0.0, 1.2))

    camera_loc = Vector((3.4, -6.1, 2.65))
    target = Vector((-1.85, 0.0, 1.18))
    bpy.ops.object.camera_add(location=camera_loc)
    cam = bpy.context.object
    cam.name = "rocket plume camera"
    look_at(cam, target)
    cam.data.lens = 42
    cam.data.dof.use_dof = True
    cam.data.dof.focus_distance = (camera_loc - target).length
    cam.data.dof.aperture_fstop = 6.3
    bpy.context.scene.camera = cam

    scene = bpy.context.scene
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 800
    scene.world = bpy.data.worlds.new("black launch world")
    scene.world.color = (0.001, 0.0015, 0.0025)
    scene.render.filepath = str(RENDER_PATH)

    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.render.render(write_still=True)

    shutil.copyfile(RENDER_PATH, REPO_RENDER_PATH)
    shutil.copyfile(BLEND_PATH, REPO_BLEND_PATH)
    print(f"Render: {RENDER_PATH}")
    print(f"Blend: {BLEND_PATH}")
    print(f"Repo render: {REPO_RENDER_PATH}")
    print(f"Repo blend: {REPO_BLEND_PATH}")


if __name__ == "__main__":
    build_scene()
