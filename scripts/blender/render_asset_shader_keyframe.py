import math
from pathlib import Path
from random import Random

import bpy
from mathutils import Matrix, Vector

ROOT = Path("/mnt/c/Users/18572/blender-wsl-render")
ASSETS = ROOT / "asset_library"
REPO = ROOT / "rtx2070-cuda-lab"

GATEWAY = ASSETS / "source_mirrors/NASA-3D-Resources/3D Models/Gateway/Gateway Core.glb"
CREW_MODULE = ASSETS / "source_mirrors/NASA-3D-Resources/3D Models/ESAS Crew Module/ESAS Crew Module.glb"
EARTH_TEX = ASSETS / "source_mirrors/NASA-3D-Resources/Images and Textures/Earth (B)/Earth (B).tif"
SKYBOX = ASSETS / "skyboxes/eso_milky_way_panorama_large_6000x3000.jpg"

OUT_DIR = ASSETS / "renders"
STILL = OUT_DIR / "gateway_plasma_keyframe.png"
BLEND = OUT_DIR / "gateway_plasma_keyframe.blend"

GALLERY_MEDIA = REPO / "docs/media"
GALLERY_STILL = GALLERY_MEDIA / "gateway_plasma_keyframe.png"


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def configure_gpu(scene):
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 96
    scene.cycles.preview_samples = 16
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 8
    scene.cycles.diffuse_bounces = 3
    scene.cycles.glossy_bounces = 4
    scene.cycles.transparent_max_bounces = 10
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


def set_world_environment(scene):
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    nodes = world.node_tree.nodes
    links = world.node_tree.links
    nodes.clear()

    coord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Rotation"].default_value[2] = math.radians(7)
    tex = nodes.new("ShaderNodeTexEnvironment")
    tex.image = bpy.data.images.load(str(SKYBOX))
    bg = nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = 0.62
    out = nodes.new("ShaderNodeOutputWorld")

    links.new(coord.outputs["Generated"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
    links.new(tex.outputs["Color"], bg.inputs["Color"])
    links.new(bg.outputs["Background"], out.inputs["Surface"])


def make_principled(name, color, roughness=0.5, metallic=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Alpha"].default_value = alpha
    mat.blend_method = "BLEND"
    mat.use_screen_refraction = True
    return mat


def make_image_principled(name, image_path, roughness=0.7):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(image_path))
    bsdf.inputs["Roughness"].default_value = roughness
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def make_emission(name, color, strength=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = color
    emission.inputs["Strength"].default_value = strength
    out = nodes.new("ShaderNodeOutputMaterial")
    mat.node_tree.links.new(emission.outputs["Emission"], out.inputs["Surface"])
    return mat


def make_noisy_plasma(name, color, core_color, strength=8.0, scale=8.0, alpha_cut=0.44):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.blend_method = "BLEND"
    mat.use_screen_refraction = True
    mat.show_transparent_back = True

    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    coord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 13.0
    noise.inputs["Roughness"].default_value = 0.58
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = alpha_cut
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)

    transparent = nodes.new("ShaderNodeBsdfTransparent")
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = color
    emission.inputs["Strength"].default_value = strength
    mix = nodes.new("ShaderNodeMixShader")
    out = nodes.new("ShaderNodeOutputMaterial")

    links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], mix.inputs["Fac"])
    links.new(transparent.outputs["BSDF"], mix.inputs[1])
    links.new(emission.outputs["Emission"], mix.inputs[2])
    links.new(mix.outputs["Shader"], out.inputs["Surface"])

    # A tiny emissive core color node kept for viewport/material swatches.
    mat.diffuse_color = core_color
    return mat


def make_atmosphere_material():
    mat = bpy.data.materials.new("blue rim atmosphere shader")
    mat.use_nodes = True
    mat.blend_method = "BLEND"
    mat.show_transparent_back = False

    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    layer = nodes.new("ShaderNodeLayerWeight")
    layer.inputs["Blend"].default_value = 0.38
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.10
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 0.86
    ramp.color_ramp.elements[1].color = (1, 1, 1, 1)
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (0.16, 0.48, 1.0, 1)
    emission.inputs["Strength"].default_value = 1.25
    mix = nodes.new("ShaderNodeMixShader")
    out = nodes.new("ShaderNodeOutputMaterial")

    links.new(layer.outputs["Fresnel"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], mix.inputs["Fac"])
    links.new(transparent.outputs["BSDF"], mix.inputs[1])
    links.new(emission.outputs["Emission"], mix.inputs[2])
    links.new(mix.outputs["Shader"], out.inputs["Surface"])
    return mat


def import_gltf(filepath):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(filepath))
    return [obj for obj in bpy.context.scene.objects if obj not in before]


def normalize_objects(objects, size, location, rotation=(0, 0, 0)):
    meshes = [obj for obj in objects if obj.type == "MESH"]
    if not meshes:
        return
    mins = Vector((1e9, 1e9, 1e9))
    maxs = Vector((-1e9, -1e9, -1e9))
    for obj in meshes:
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            mins.x = min(mins.x, point.x)
            mins.y = min(mins.y, point.y)
            mins.z = min(mins.z, point.z)
            maxs.x = max(maxs.x, point.x)
            maxs.y = max(maxs.y, point.y)
            maxs.z = max(maxs.z, point.z)
    center = (mins + maxs) * 0.5
    extent = max((maxs - mins).x, (maxs - mins).y, (maxs - mins).z)
    scale = size / extent if extent else 1.0
    transform = Matrix.Translation(Vector(location)) @ Matrix.Rotation(rotation[2], 4, "Z") @ Matrix.Rotation(rotation[1], 4, "Y") @ Matrix.Rotation(rotation[0], 4, "X") @ Matrix.Scale(scale, 4) @ Matrix.Translation(-center)
    for obj in objects:
        obj.matrix_world = transform @ obj.matrix_world


def make_curve(name, points, mat, bevel_depth=0.015, resolution=4):
    curve = bpy.data.curves.new(name, type="CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = resolution
    curve.bevel_depth = bevel_depth
    curve.bevel_resolution = 3
    spline = curve.splines.new(type="POLY")
    spline.points.add(len(points) - 1)
    for p, co in zip(spline.points, points):
        p.co = (co[0], co[1], co[2], 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def add_plasma_cone(name, base, direction, length, radius_near, radius_far, mat):
    direction = Vector(direction).normalized()
    base = Vector(base)
    center = base + direction * (length * 0.5)
    bpy.ops.mesh.primitive_cone_add(
        vertices=96,
        radius1=radius_near,
        radius2=radius_far,
        depth=length,
        end_fill_type="NOTHING",
        location=center,
        rotation=direction.to_track_quat("Z", "Y").to_euler(),
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def add_field_sheet(name, center, width, height, rotation, mat, subdivisions=24):
    verts = []
    faces = []
    for y in range(subdivisions + 1):
        ty = y / subdivisions
        for x in range(subdivisions + 1):
            tx = x / subdivisions
            px = (tx - 0.5) * width
            py = (ty - 0.5) * height
            wave = 0.08 * math.sin(tx * math.tau * 3.0 + ty * math.tau * 1.7)
            verts.append((px, py, wave))
    for y in range(subdivisions):
        for x in range(subdivisions):
            i = y * (subdivisions + 1) + x
            faces.append((i, i + 1, i + subdivisions + 2, i + subdivisions + 1))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = center
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    return obj


def material_polish():
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if not bsdf:
            continue
        if "solar" in mat.name.lower() or "array" in mat.name.lower():
            bsdf.inputs["Metallic"].default_value = max(bsdf.inputs["Metallic"].default_value, 0.25)
            bsdf.inputs["Roughness"].default_value = 0.28
        else:
            bsdf.inputs["Roughness"].default_value = min(max(bsdf.inputs["Roughness"].default_value, 0.32), 0.68)


rng = Random(77)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()

scene = bpy.context.scene
configure_gpu(scene)
set_world_environment(scene)

scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene.render.film_transparent = False
scene.view_settings.view_transform = "Filmic"
scene.view_settings.look = "High Contrast"
scene.view_settings.exposure = -0.28
scene.view_settings.gamma = 1.0

gateway = import_gltf(GATEWAY)
normalize_objects(gateway, size=4.2, location=(0.25, 0.0, 0.45), rotation=(math.radians(2), math.radians(-10), math.radians(-28)))

crew = import_gltf(CREW_MODULE)
normalize_objects(crew, size=0.85, location=(-2.75, -1.58, 0.2), rotation=(math.radians(73), math.radians(0), math.radians(58)))

material_polish()

earth_mat = make_image_principled("NASA Earth texture", EARTH_TEX, roughness=0.9)
atmo_mat = make_atmosphere_material()

bpy.ops.mesh.primitive_uv_sphere_add(segments=192, ring_count=96, radius=10.0, location=(1.7, 1.0, -10.5), rotation=(0, 0, math.radians(-18)))
earth = bpy.context.object
earth.name = "downloaded NASA Earth texture limb"
earth.data.materials.append(earth_mat)

bpy.ops.mesh.primitive_uv_sphere_add(segments=192, ring_count=96, radius=10.15, location=earth.location)
atmo = bpy.context.object
atmo.name = "shader atmosphere rim"
atmo.data.materials.append(atmo_mat)

blue_line = make_emission("electric blue field-line shader", (0.22, 0.75, 1.0, 1), 4.6)
violet_line = make_emission("violet ion field-line shader", (0.86, 0.3, 1.0, 1), 3.2)
amber_line = make_emission("amber charged dust shader", (1.0, 0.47, 0.12, 1), 2.8)

plasma_hot = make_noisy_plasma("hot white-orange noisy plume shader", (1.0, 0.54, 0.16, 1), (1.0, 0.46, 0.1, 0.25), 6.5, 15.0, 0.58)
plasma_violet = make_noisy_plasma("violet-blue outer plume shader", (0.45, 0.22, 1.0, 1), (0.45, 0.22, 1.0, 0.14), 2.8, 8.5, 0.5)
plasma_cyan = make_noisy_plasma("cyan field sheet shader", (0.1, 0.85, 1.0, 1), (0.1, 0.85, 1.0, 0.1), 0.85, 4.0, 0.66)

thruster_base = (-3.12, -1.86, 0.16)
trail_dir = (-0.82, -0.48, -0.08)
add_plasma_cone("inner noisy ion plume", thruster_base, trail_dir, 0.95, 0.04, 0.18, plasma_hot)
add_plasma_cone("outer violet exhaust veil", thruster_base, trail_dir, 1.35, 0.1, 0.34, plasma_violet)

add_field_sheet(
    "transparent cyan docking field sheet",
    center=(-0.95, -0.82, 0.22),
    width=4.8,
    height=1.5,
    rotation=(math.radians(73), math.radians(0), math.radians(58)),
    mat=plasma_cyan,
)

for i in range(18):
    t_points = []
    phase = rng.random() * math.tau
    start = Vector((-2.85, -1.62, 0.18))
    end = Vector((0.18 + rng.uniform(-0.24, 0.36), -0.15 + rng.uniform(-0.16, 0.22), 0.42 + rng.uniform(-0.16, 0.24)))
    for k in range(18):
        t = k / 17
        p = start.lerp(end, t)
        wobble = Vector((
            0.0,
            0.1 * math.sin(t * math.tau * 1.6 + phase) * (1 - abs(t - 0.5)),
            0.08 * math.cos(t * math.tau * 1.2 + phase),
        ))
        t_points.append(p + wobble)
    mat = [blue_line, violet_line, amber_line][i % 3]
    make_curve(f"long-exposure docking field line {i:02d}", t_points, mat, bevel_depth=0.003 + 0.004 * rng.random())

dust_mat = make_emission("charged amber dust sparks", (1.0, 0.64, 0.22, 1), 3.5)
for i in range(70):
    t = rng.random()
    pos = Vector(thruster_base).lerp(Vector((-5.2, -3.12, -0.24)), t)
    pos += Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.38, 0.38), rng.uniform(-0.2, 0.2))) * (0.5 + t)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=rng.uniform(0.006, 0.026), location=pos)
    spark = bpy.context.object
    spark.name = f"charged plume dust {i:02d}"
    spark.data.materials.append(dust_mat)

bpy.ops.object.light_add(type="SUN", location=(-4, -3, 8), rotation=(math.radians(45), math.radians(0), math.radians(-32)))
sun = bpy.context.object
sun.name = "hard orbital sun"
sun.data.energy = 2.3
sun.data.angle = math.radians(1.2)

bpy.ops.object.light_add(type="AREA", location=(-3.4, -2.7, 1.5))
plume_light = bpy.context.object
plume_light.name = "warm plume bounce"
plume_light.data.energy = 520
plume_light.data.size = 2.8
plume_light.data.color = (1.0, 0.58, 0.24)

bpy.ops.object.light_add(type="POINT", location=(1.5, 1.8, 1.2))
rim = bpy.context.object
rim.name = "cool station rim"
rim.data.energy = 155
rim.data.color = (0.42, 0.72, 1.0)

bpy.ops.object.camera_add(location=(5.45, -6.7, 2.55))
camera = bpy.context.object
camera.name = "cinematic orbital keyframe camera"
camera.data.lens = 62
camera.data.dof.use_dof = True
camera.data.dof.focus_distance = 7.3
camera.data.dof.aperture_fstop = 7.5
look_at(camera, (-0.55, -0.55, 0.1))
scene.camera = camera

OUT_DIR.mkdir(parents=True, exist_ok=True)
GALLERY_MEDIA.mkdir(parents=True, exist_ok=True)
scene.render.filepath = str(STILL)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), compress=True)
bpy.ops.render.render(write_still=True)

GALLERY_STILL.write_bytes(STILL.read_bytes())
print("OUTPUT", STILL)
print("BLEND", BLEND)
print("GALLERY_STILL", GALLERY_STILL)
