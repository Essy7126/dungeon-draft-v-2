"""Native Blender geometry animation, baked as separate front/rear PNG sequences.

Run in a NEW background Blender process with --factory-startup --disable-autoexec.
The .blend contains baked geometry and visibility keys; it needs no Python handler.
"""
import bpy
import json
import math
import random
import sys
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RECIPE = json.loads((HERE / "recipe.json").read_text(encoding="utf-8"))
OUT = ROOT / "artifacts/dev/heal_vfx_study/blender_frames"
SOURCE = ROOT / "art/source/vfx/heal_laurel_study_v1"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
random.seed(RECIPE["seed"])

# This process was started with factory-startup. Never attach to the user's editor.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 32
scene.cycles.use_denoising = False
scene.render.resolution_x = RECIPE["frame_size"]
scene.render.resolution_y = RECIPE["frame_size"]
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.color_depth = "8"
scene.render.fps = RECIPE["fps"]
scene.frame_start = 1
scene.frame_end = RECIPE["frames"]
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.world.color = (0, 0, 0)

camera_data = bpy.data.cameras.new("Orthographic_2_to_1")
camera = bpy.data.objects.new("Camera", camera_data)
scene.collection.objects.link(camera)
target = Vector((0, 0, RECIPE["camera_target_z"]))
camera.location = target + Vector((0, -8.660254, 5))
camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
camera_data.type = "ORTHO"
camera_data.ortho_scale = RECIPE["camera_scale"]
scene.camera = camera
collections = {}
for part in ("rear", "front"):
    collection = bpy.data.collections.new(part)
    scene.collection.children.link(collection)
    collections[part] = collection

def linear(v):
    return v / 12.92 if v < 0.04045 else ((v + 0.055) / 1.055) ** 2.4

materials = []
for name, rgb in [("Petrol", "327b72"), ("Jade", "70bda4"),
                  ("Celadon", "b2dcc0"), ("Ivory", "f0e8b9"),
                  ("Bronze", "c6a369"), ("Shadow", "325e57")]:
    color = tuple(linear(int(rgb[i:i+2], 16) / 255) for i in (0, 2, 4))
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1)
    material.use_nodes = True
    material.node_tree.nodes.clear()
    emission = material.node_tree.nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (*color, 1)
    output = material.node_tree.nodes.new("ShaderNodeOutputMaterial")
    material.node_tree.links.new(emission.outputs[0], output.inputs[0])
    materials.append(material)

def smooth(a, b, t):
    u = min(1, max(0, (t - a) / (b - a)))
    return u * u * (3 - 2 * u)

def mesh_buffer():
    return {part: {"v": [], "f": [], "m": []} for part in collections}

def face(buf, points, mat):
    part = "front" if sum(p[1] for p in points) / len(points) < 0 else "rear"
    group = buf[part]
    start = len(group["v"])
    group["v"].extend(points)
    group["f"].append(tuple(range(start, start + len(points))))
    group["m"].append(mat)

def ribbon(buf, points, widths, mat):
    # Width points upwards, giving a tapered band with a consistently readable face.
    for i in range(len(points) - 1):
        a, b = Vector(points[i]), Vector(points[i + 1])
        wa, wb = Vector((0, 0, widths[i])), Vector((0, 0, widths[i + 1]))
        face(buf, [a-wa, b-wb, b+wb, a+wa], mat)

def leaf(buf, center, direction, length, width, mat):
    c = Vector(center)
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, -1, 0.42))).normalized()
    if side.length < 0.1:
        side = Vector((1, 0, 0))
    p0, p1 = c - d * length * 0.5, c + d * length * 0.5
    mid = c + Vector((0, -0.018, 0.012))
    face(buf, [p0, mid-side*width, p1, mid], mat)
    face(buf, [p0, mid, p1, mid+side*width], min(mat+1, 4))

def build_frame(t):
    buf = mesh_buffer()
    base = smooth(0.0, 0.12, t) * (1 - smooth(0.60, 0.96, t))
    radius = RECIPE["radius"] * (0.7 + 0.3*smooth(0, 0.22, t))
    # An open laurel wreath at the feet, leaving breathing room around the actor.
    for k in range(18):
        theta = 2*math.pi*k/18 + 0.1
        leaf(buf, (radius*math.cos(theta), radius*math.sin(theta), 0.055),
             (-math.sin(theta), math.cos(theta), 0.35),
             0.19*base, 0.045*base, 1 if k % 3 else 4)
    # Two staggered upward strokes. Their tails narrow, then erode into leaves.
    for strand in range(2):
        u = (t - strand*0.08) / 0.88
        if not 0 < u < 1:
            continue
        envelope = smooth(0, 0.13, u)*(1-smooth(0.58, 1, u))
        height = 0.10 + RECIPE["rise"] * (1-(1-u)**1.45)
        angle = strand*math.pi + u*math.pi*2.0
        points, widths = [], []
        for j in range(49):
            q = j/48
            theta = angle - (1-q)*2.65
            r = radius * (1 - 0.24*u) + 0.035*math.sin(q*math.pi*3)
            z = height - (1-q)*0.54
            points.append((r*math.cos(theta), r*math.sin(theta), max(0.08,z)))
            widths.append(RECIPE["ribbon_width"] * math.sin(math.pi*q)**0.85 * envelope)
        ribbon(buf, points, widths, 1 if strand == 0 else 0)
        edge = [Vector(p)+Vector((0,0,w*0.57)) for p,w in zip(points,widths)]
        ribbon(buf, edge, [w*0.13 for w in widths], 2)
        p = points[-3]
        leaf(buf, p, (-math.sin(angle),math.cos(angle),1.2),
             0.28*envelope, 0.065*envelope, 2)
    # Deterministic rising seed/leaves, with staggered starts and asymmetric paths.
    for i in range(13):
        start = 0.045 + i*0.028
        u = (t-start)/(0.57 + (i%3)*0.06)
        if not 0 < u < 1:
            continue
        amp = smooth(0,0.18,u)*(1-smooth(0.58,1,u))
        angle = i*2.39996 + u*0.65
        r = 0.48 + (i%4)*0.10
        pos = (r*math.cos(angle),r*math.sin(angle),0.18+u*(1.65+(i%3)*0.17))
        leaf(buf,pos,(0.3*math.sin(angle),0.12,1),
             (0.095+(i%3)*0.028)*amp,0.021*amp,3 if i%4 == 0 else 1)
    return buf

for frame in range(1, scene.frame_end+1):
    t = (frame-1)/RECIPE["fps"]
    buffers = build_frame(t)
    for part, data in buffers.items():
        mesh = bpy.data.meshes.new(f"{part}_{frame:03d}")
        mesh.from_pydata(data["v"], [], data["f"])
        mesh.update()
        obj = bpy.data.objects.new(mesh.name, mesh)
        collections[part].objects.link(obj)
        for mat in materials:
            mesh.materials.append(mat)
        for polygon, index in zip(mesh.polygons, data["m"]):
            polygon.material_index = index
        for f, hidden in [(0, True), (frame, False), (frame+1, True)]:
            obj.hide_render = hidden
            obj.hide_viewport = hidden
            obj.keyframe_insert(data_path="hide_render", frame=f)
            obj.keyframe_insert(data_path="hide_viewport", frame=f)

scene.frame_set(12)
scene["recipe"] = json.dumps(RECIPE)
scene["description"] = "Heal VFX study. Baked mesh poses; no script required for playback."
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "heal_laurel.blend"))
projected = world_to_camera_view(scene, camera, Vector((0,0,0)))
meta = {"blender": bpy.app.version_string, "recipe": RECIPE,
        "pivot_normalized": [projected.x, 1-projected.y],
        "source": str(SOURCE / "heal_laurel.blend"),
        "parts": ["rear", "front"], "render_engine": scene.render.engine}
(OUT.parent / "blender_manifest.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
preview_only = "--preview" in sys.argv
for part in ("rear", "front"):
    collections["front"].hide_render = part != "front"
    collections["rear"].hide_render = part != "rear"
    (OUT/part).mkdir(exist_ok=True)
    frames = [12] if preview_only else range(1,scene.frame_end+1)
    for frame in frames:
        scene.frame_set(frame)
        scene.render.filepath = str(OUT/part/f"{frame-1:03d}.png")
        bpy.ops.render.render(write_still=True)
print("HEAL_RENDER_COMPLETE " + json.dumps({"frames_per_part": 1 if preview_only else scene.frame_end}))
