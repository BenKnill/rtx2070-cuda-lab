import math
import os
import shutil
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path("/mnt/c/Users/18572/blender-wsl-render")
REPO = ROOT / "rtx2070-cuda-lab"

SOLAR_FRAMES = ROOT / "blender_bridge_output/starship_star_window_solar_frames"
FRAME_DIR = ROOT / "blender_bridge_output/starship_imagegen_texture_frames"
LOCAL_OUT = ROOT / "blender_bridge_output/starship_imagegen_texture_scene"

HULL_TEXTURE = ROOT / "asset_library/generated/starship_hull_wrap_imagegen.png"
STAR_MASK = ROOT / "asset_library/generated/star_window_mask_deepfield_imagegen.png"

GALLERY_MEDIA = REPO / "docs/media"
GALLERY_ASSETS = REPO / "assets/blender"

FRAME_COUNT = int(os.environ.get("STARSHIP_IMAGEGEN_FRAME_COUNT", "48"))
SAMPLES = int(os.environ.get("STARSHIP_IMAGEGEN_SAMPLES", "36"))
RESOLUTION = (1280, 720)

SHIP_OBJECTS = []


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def configure_gpu(scene):
    scene.render.engine = "CYCLES"
    scene.cycles.samples = SAMPLES
    scene.cycles.preview_samples = 8
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 7
    scene.cycles.diffuse_bounces = 2
    scene.cycles.glossy_bounces = 4
    scene.cycles.transparent_max_bounces = 6
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "OPTIX"
        prefs.get_devices()
        for device in prefs.devices:
            device.use = device.type in {"OPTIX", "CUDA"}
        scene.cycles.device = "GPU"
        print("GPU_DEVICES", " | ".join(f"{d.name}:{d.type}:{d.use}" for d in prefs.devices))
    except Exception as exc:
        print("GPU_DEVICE_WARNING", exc)


def make_principled(name, color, roughness=0.5, metallic=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Alpha"].default_value = alpha
    mat.diffuse_color = color
    if alpha < 1.0:
        mat.blend_method = "BLEND"
        mat.show_transparent_back = False
    return mat


def make_emission(name, color, strength):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = color
    emission.inputs["Strength"].default_value = strength
    out = nodes.new("ShaderNodeOutputMaterial")
    mat.node_tree.links.new(emission.outputs["Emission"], out.inputs["Surface"])
    mat.diffuse_color = color
    return mat


def make_hull_texture_material():
    if not HULL_TEXTURE.exists():
        raise FileNotFoundError(HULL_TEXTURE)

    mat = bpy.data.materials.new("image-generated stainless Starship hull wrap")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.21

    texcoord = nodes.new("ShaderNodeTexCoord")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(HULL_TEXTURE), check_existing=True)
    tex.extension = "REPEAT"
    tex.interpolation = "Smart"
    links.new(texcoord.outputs["UV"], tex.inputs["Vector"])
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def make_solar_mask_material(first_frame):
    if not STAR_MASK.exists():
        raise FileNotFoundError(STAR_MASK)

    mat = bpy.data.materials.new("CUDA solar surface through image-generated star mask")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    texcoord = nodes.new("ShaderNodeTexCoord")
    solar = nodes.new("ShaderNodeTexImage")
    solar.image = bpy.data.images.load(str(first_frame), check_existing=True)
    solar.extension = "EXTEND"
    solar.interpolation = "Smart"

    mask = nodes.new("ShaderNodeTexImage")
    mask.image = bpy.data.images.load(str(STAR_MASK), check_existing=True)
    mask.image.colorspace_settings.name = "Non-Color"
    mask.extension = "EXTEND"
    mask.interpolation = "Closest"

    separate = nodes.new("ShaderNodeSeparateColor")
    threshold = nodes.new("ShaderNodeMath")
    threshold.operation = "GREATER_THAN"
    threshold.inputs[1].default_value = 0.42
    mix = nodes.new("ShaderNodeMixRGB")
    mix.inputs[1].default_value = (0.0, 0.0, 0.0, 1.0)

    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Strength"].default_value = 5.2
    out = nodes.new("ShaderNodeOutputMaterial")

    links.new(texcoord.outputs["UV"], solar.inputs["Vector"])
    links.new(texcoord.outputs["UV"], mask.inputs["Vector"])
    links.new(mask.outputs["Color"], separate.inputs["Color"])
    links.new(separate.outputs["Red"], threshold.inputs[0])
    links.new(threshold.outputs["Value"], mix.inputs["Fac"])
    links.new(solar.outputs["Color"], mix.inputs[2])
    links.new(mix.outputs["Color"], emission.inputs["Color"])
    links.new(emission.outputs["Emission"], out.inputs["Surface"])
    return mat, solar


def make_uv_rect(name, width, height, y, z, material):
    verts = [
        (-width * 0.5, y, z - height * 0.5),
        (width * 0.5, y, z - height * 0.5),
        (width * 0.5, y, z + height * 0.5),
        (-width * 0.5, y, z + height * 0.5),
    ]
    faces = [(0, 1, 2, 3)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="UVMap")
    uvs = [(0, 0), (1, 0), (1, 1), (0, 1)]
    for poly in mesh.polygons:
        for loop_index in poly.loop_indices:
            vi = mesh.loops[loop_index].vertex_index
            uv_layer.data[loop_index].uv = uvs[vi]
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def add_star_mask_background(solar_material):
    make_uv_rect("full black occlusion image mask with CUDA solar apertures", 11.6, 6.52, 2.95, 0.16, solar_material)


def append_ship(obj):
    SHIP_OBJECTS.append(obj)
    return obj


def make_x_tube_mesh(name, x0, x1, r0, r1, material, u0=0.0, u1=1.0, radial=160, x_segments=24, uv_v_offset=0.42):
    verts = []
    for ix in range(x_segments + 1):
        t = ix / x_segments
        x = x0 + (x1 - x0) * t
        radius = r0 + (r1 - r0) * t
        for ir in range(radial + 1):
            angle = math.tau * ir / radial
            verts.append((x, math.cos(angle) * radius, math.sin(angle) * radius + 0.05))

    faces = []
    stride = radial + 1
    for ix in range(x_segments):
        for ir in range(radial):
            a = ix * stride + ir
            faces.append((a, a + stride, a + stride + 1, a + 1))

    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        for loop_index in poly.loop_indices:
            vi = mesh.loops[loop_index].vertex_index
            ix = vi // stride
            ir = vi % stride
            u = u0 + (u1 - u0) * (ix / x_segments)
            v = (ir / radial) + uv_v_offset
            uv_layer.data[loop_index].uv = (u, v)
        poly.use_smooth = True

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return append_ship(obj)


def add_cylinder_x(name, x0, x1, radius, material, vertices=96, location_y=0.0, location_z=0.0):
    length = x1 - x0
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=length,
        location=((x0 + x1) * 0.5, location_y, location_z),
        rotation=(0, math.radians(90), 0),
    )
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.shade_smooth()
    obj.data.materials.append(material)
    return append_ship(obj)


def add_cone_x(name, x0, x1, r0, r1, material, vertices=96, location_y=0.0, location_z=0.0):
    length = x1 - x0
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=r0,
        radius2=r1,
        depth=length,
        location=((x0 + x1) * 0.5, location_y, location_z),
        rotation=(0, math.radians(90), 0),
    )
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.shade_smooth()
    obj.data.materials.append(material)
    return append_ship(obj)


def add_box(name, loc, scale, material, rotation=(0, 0, 0), ship=True):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if ship:
        append_ship(obj)
    return obj


def add_fin(name, x, y_sign, z, material, aft=True):
    length = 0.72 if aft else 0.48
    height = 0.84 if aft else 0.52
    verts = [
        (-length * 0.52, 0, -height * 0.24),
        (length * 0.52, 0, -height * 0.16),
        (length * 0.14, 0, height * 0.52),
        (-length * 0.44, 0, height * 0.2),
    ]
    faces = [(0, 1, 2, 3)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = (x, y_sign * 0.49, z)
    obj.rotation_euler = (math.radians(83), 0, y_sign * math.radians(8 if aft else -13))
    obj.data.materials.append(material)
    solid = obj.modifiers.new("thin flap thickness", "SOLIDIFY")
    solid.thickness = 0.04
    bevel = obj.modifiers.new("soft flap edges", "BEVEL")
    bevel.width = 0.018
    bevel.segments = 2
    return append_ship(obj)


def add_engine_bell(name, x, y, z, material):
    obj = add_cone_x(name, x - 0.17, x + 0.23, 0.125, 0.048, material, vertices=64, location_y=y, location_z=z)
    obj.rotation_euler[0] += math.radians(180)
    return obj


def add_starship():
    hull = make_hull_texture_material()
    steel_dark = make_principled("darkened stainless fin alloy", (0.55, 0.52, 0.47, 1), roughness=0.3, metallic=1.0)
    black_tile = make_principled("matte black ceramic details", (0.012, 0.012, 0.014, 1), roughness=0.78, metallic=0.04)
    glass = make_principled("smoked cockpit glass", (0.004, 0.009, 0.012, 1), roughness=0.07, metallic=0.0)
    engine = make_principled("dark raptor bell alloy", (0.075, 0.07, 0.065, 1), roughness=0.36, metallic=0.86)
    warm_glow = make_emission("low amber engine idle glow", (1.0, 0.34, 0.12, 1), 1.4)

    make_x_tube_mesh("Starship imagegen-wrapped cylindrical body", -2.95, 1.45, 0.5, 0.5, hull, u0=0.0, u1=0.79)
    make_x_tube_mesh("Starship imagegen-wrapped cone nose", 1.45, 2.62, 0.5, 0.045, hull, u0=0.79, u1=1.0, x_segments=18)

    add_cylinder_x("aft black skirt ring", -3.12, -2.92, 0.515, black_tile, vertices=160, location_z=0.05)
    add_cylinder_x("forward dark tile accent", 1.32, 1.48, 0.506, black_tile, vertices=160, location_z=0.05)

    add_box("left cockpit glaze", (2.0, -0.42, 0.29), (0.24, 0.016, 0.074), glass, rotation=(0, 0, math.radians(-12)))
    add_box("right cockpit glaze", (2.22, -0.41, 0.18), (0.18, 0.016, 0.064), glass, rotation=(0, 0, math.radians(-18)))

    add_fin("aft port stainless flap", -2.36, -1, -0.02, steel_dark, aft=True)
    add_fin("aft starboard stainless flap", -2.36, 1, -0.02, steel_dark, aft=True)
    add_fin("forward port stainless flap", 1.25, -1, 0.17, steel_dark, aft=False)
    add_fin("forward starboard stainless flap", 1.25, 1, 0.17, steel_dark, aft=False)

    for iy in (-0.23, 0.0, 0.23):
        add_engine_bell(f"raptor bell {iy:+.2f}", -3.33, iy, 0.05, engine)
    add_cone_x("soft idle engine glow", -3.5, -3.36, 0.18, 0.055, warm_glow, vertices=64, location_z=0.05)

    root = bpy.data.objects.new("static Starship imagegen texture rig", None)
    bpy.context.collection.objects.link(root)
    root.rotation_euler = (math.radians(1.5), 0.0, math.radians(-5.2))
    root.location = (-0.12, -0.06, 0.02)
    for obj in SHIP_OBJECTS:
        obj.parent = root
    return root


def add_lighting():
    bpy.ops.object.light_add(type="AREA", location=(-3.8, -4.1, 3.2), rotation=(math.radians(62), 0, math.radians(-18)))
    key = bpy.context.object
    key.name = "long soft reflection key"
    key.data.energy = 420
    key.data.size = 5.0

    bpy.ops.object.light_add(type="AREA", location=(1.5, -3.2, 1.25), rotation=(math.radians(70), 0, math.radians(15)))
    strip = bpy.context.object
    strip.name = "thin white hull reflection strip"
    strip.data.energy = 170
    strip.data.size = 1.35

    bpy.ops.object.light_add(type="POINT", location=(3.7, 1.6, 1.7))
    warm = bpy.context.object
    warm.name = "warm solar aperture bounce"
    warm.data.energy = 110
    warm.data.color = (1.0, 0.42, 0.16)

    bpy.ops.object.light_add(type="AREA", location=(-1.6, -3.6, -1.25))
    cool = bpy.context.object
    cool.name = "cool black-side fill"
    cool.data.energy = 62
    cool.data.size = 3.0
    cool.data.color = (0.45, 0.58, 1.0)


def cleanup_for_packing(keep_solar):
    keep_path = str(keep_solar)
    for image in list(bpy.data.images):
        if image.filepath and "stellar_surface_" in image.filepath and image.filepath != keep_path:
            bpy.data.images.remove(image)


def main():
    first = SOLAR_FRAMES / "stellar_surface_000.png"
    if not first.exists():
        raise FileNotFoundError(first)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    SHIP_OBJECTS.clear()

    scene = bpy.context.scene
    configure_gpu(scene)
    scene.render.resolution_x, scene.render.resolution_y = RESOLUTION
    scene.render.fps = 12
    scene.frame_start = 1
    scene.frame_end = FRAME_COUNT
    scene.view_settings.view_transform = "Filmic"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = -0.08
    scene.view_settings.gamma = 1.0
    scene.world = scene.world or bpy.data.worlds.new("World")
    scene.world.color = (0, 0, 0)

    solar_mat, solar_node = make_solar_mask_material(first)
    add_star_mask_background(solar_mat)
    add_starship()
    add_lighting()

    bpy.ops.object.camera_add(location=(0.18, -9.75, 1.2))
    camera = bpy.context.object
    camera.name = "locked imagegen Starship camera"
    camera.data.lens = 46
    camera.data.dof.use_dof = True
    camera.data.dof.focus_distance = 9.6
    camera.data.dof.aperture_fstop = 9.5
    look_at(camera, (-0.18, 0.05, 0.16))
    scene.camera = camera

    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    LOCAL_OUT.mkdir(parents=True, exist_ok=True)
    GALLERY_MEDIA.mkdir(parents=True, exist_ok=True)
    GALLERY_ASSETS.mkdir(parents=True, exist_ok=True)

    loaded = {}
    for frame in range(FRAME_COUNT):
        scene.frame_set(frame + 1)
        image_path = SOLAR_FRAMES / f"stellar_surface_{frame % 48:03d}.png"
        loaded[frame] = bpy.data.images.load(str(image_path), check_existing=True)
        solar_node.image = loaded[frame]
        scene.render.filepath = str(FRAME_DIR / f"frame_{frame:03d}.png")
        bpy.ops.render.render(write_still=True)

    preview = FRAME_DIR / "frame_000.png"
    local_preview = LOCAL_OUT / "starship_imagegen_texture_preview.png"
    shutil.copy2(preview, local_preview)
    shutil.copy2(preview, GALLERY_MEDIA / "starship_imagegen_texture_preview.png")

    solar_node.image = bpy.data.images.load(str(first), check_existing=True)
    cleanup_for_packing(first)
    bpy.ops.file.pack_all()
    blend = LOCAL_OUT / "starship_imagegen_texture_scene.blend"
    gallery_blend = GALLERY_ASSETS / "starship_imagegen_texture_scene.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend), compress=True)
    shutil.copy2(blend, gallery_blend)

    print("PREVIEW", local_preview)
    print("BLEND", blend)
    print("GALLERY_PREVIEW", GALLERY_MEDIA / "starship_imagegen_texture_preview.png")
    print("GALLERY_BLEND", gallery_blend)


if __name__ == "__main__":
    main()
