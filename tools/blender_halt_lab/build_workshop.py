"""Deterministic metric pilot, executed ONLY through the guarded lab client."""
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(bpy.data.filepath).resolve().parents[4]
OUT = ROOT / "art/source/halts/bronze_workshop_pilot_v1"
OUT.mkdir(parents=True, exist_ok=True)
(OUT / ".gdignore").write_text("", encoding="utf-8")
scene = bpy.context.scene
assert scene.get("halt_lab_id") == "dungeon_draft_halt_scale_lab_v1"

# Preserve the connection-setup blockout in a hidden collection for reference.
initial = bpy.data.collections.get("Initial connection blockout")
if initial is None:
    initial = bpy.data.collections.new("Initial connection blockout")
    scene.collection.children.link(initial)
    for obj in list(scene.objects):
        for collection in list(obj.users_collection):
            collection.objects.unlink(obj)
        initial.objects.link(obj)
initial.hide_render = True
initial.hide_viewport = True
old = bpy.data.collections.get("Workshop pilot generated")
if old:
    for obj in list(old.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(old)
collection = bpy.data.collections.new("Workshop pilot generated")
scene.collection.children.link(collection)

COLORS = {
    "stone": (0.25, 0.36, 0.40, 1),
    "edge": (0.37, 0.48, 0.48, 1),
    "floor": (0.33, 0.42, 0.44, 1),
    "wood": (0.30, 0.18, 0.095, 1),
    "bronze": (0.44, 0.28, 0.10, 1),
    "iron": (0.12, 0.16, 0.17, 1),
    "fire": (1.0, 0.24, 0.015, 1),
}


def register(obj, name, material, group):
    obj.name = name
    for parent in list(obj.users_collection):
        parent.objects.unlink(obj)
    collection.objects.link(obj)
    obj.color = COLORS[material]
    obj["layer"] = group
    obj["pilot_owned"] = True
    return obj


def block(name, loc, dims, mat="stone", group="architecture", bevel=0.035):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = register(bpy.context.object, name, mat, group)
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Small worn edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    return obj


def cylinder(name, loc, radius, depth, mat, group, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    return register(bpy.context.object, name, mat, group)


block("Foundation 8 x 6 m", (0, 0, -0.13), (8, 6, 0.26), "stone", "floor")
for i in range(8):
    for j in range(6):
        block(f"Floor tile {i}-{j}", (i - 3.5, j - 2.5, -0.015), (0.98, 0.98, 0.05), "floor", "floor", 0.018)

# An actual opening, not a frame painted in front of a solid wall.
block("Rear wall left", (-1.175, 2.90, 1.40), (5.65, 0.28, 2.8))
block("Rear wall right", (3.525, 2.90, 1.40), (0.95, 0.28, 2.8))
block("Door lintel 2.55 m clearance", (2.35, 2.90, 2.70), (1.40, 0.38, 0.30), "edge")
block("Door jamb L", (1.52, 2.83, 1.28), (0.25, 0.45, 2.56), "edge")
block("Door jamb R", (3.18, 2.83, 1.28), (0.25, 0.45, 2.56), "edge")
block("Door threshold", (2.35, 2.90, 0.02), (1.42, 0.75, 0.04), "edge", "floor")
block("Left wall", (-3.93, 1.0, 1.4), (0.24, 3.8, 2.8))
for x in [-3.8, -1.3, 1.30, 3.8]:
    block("Wall buttress", (x, 2.72, 1.40), (0.23, 0.20, 2.8), "edge")
for z in [0.12, 1.35, 2.72]:
    block("Wall band", (-1.20, 2.72, z), (5.5, 0.13, 0.12), "edge")

# Compact brazier / working forge with a hearth at human waist height.
block("Hearth plinth", (-2.90, 1.83, 0.38), (1.20, 1.00, 0.76), "stone", "hearth")
block("Hearth bed", (-2.90, 1.80, 0.78), (1.04, 0.90, 0.12), "iron", "hearth")
block("Hearth rear", (-2.90, 2.20, 1.27), (1.28, 0.20, 1.0), "edge", "hearth")
for x in [-3.48, -2.32]:
    block("Hearth cheek", (x, 1.82, 1.02), (0.18, 0.97, 0.45), "edge", "hearth")
for i in range(7):
    cylinder("Coals", (-3.28+i*.125, 1.74+(i%2)*.14, .91), .13, .14, "fire", "fire", 7)
block("Hood", (-2.90, 2.02, 1.85), (1.42, 0.66, 0.25), "bronze", "hearth")
block("Chimney", (-2.90, 2.18, 2.35), (.66, .43, .8), "stone", "hearth")

block("Workbench top 0.90 m", (-0.85, 1.90, .84), (1.80, .78, .12), "wood", "workbench")
for x in [-1.56, -.14]:
    for y in [1.61, 2.19]:
        block("Workbench leg", (x,y,.39), (.13,.13,.78), "wood", "workbench", .015)
block("Workbench shelf", (-.85, 1.9, .20), (1.60,.64,.09), "wood", "workbench")
block("Hammer handle", (-.85,1.87,.935), (.50,.07,.06), "wood", "workbench", .005)
block("Hammer head", (-1.08,1.87,.98), (.13,.22,.15), "iron", "workbench", .015)

# Open tapered bucket: its BODY is exactly 0.35 m, handle is separate.
bx, by = -1.80, .60
verts=[]
faces=[]
for radius,z in [(.13,0),(.17,.35),(.145,.35),(.105,.04)]:
    verts.extend([(bx+radius*math.cos(i*math.tau/20),by+radius*math.sin(i*math.tau/20),z) for i in range(20)])
for ring in range(3):
    for i in range(20):
        a=ring*20+i; b=ring*20+(i+1)%20
        faces.append((a,b,b+20,a+20))
mesh=bpy.data.meshes.new("Bucket shell geometry")
mesh.from_pydata(verts,[],faces); mesh.update()
obj=bpy.data.objects.new("Bucket body 0.35 m",mesh); collection.objects.link(obj)
register(obj,obj.name,"wood","bucket")
for z,r in [(.06,.139),(.30,.169)]:
    bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=.012,major_segments=20,minor_segments=6,location=(bx,by,z))
    register(bpy.context.object,"Bucket bronze hoop","bronze","bucket")

px,py=1.18,-.66
block("Pillar foot",(px,py,.10),(.82,.82,.20),"edge","pillar")
block("Pillar shaft 2.30 m",(px,py,1.30),(.52,.52,2.20),"stone","pillar")
block("Pillar capital",(px,py,2.48),(.76,.76,.16),"edge","pillar")
block("Pillar bronze band",(px,py,1.97),(.55,.55,.09),"bronze","pillar")

target=Vector((0,.05,1.1))
bpy.ops.object.camera_add(location=target+Vector((7.2,-12,11.0)))
camera=register(bpy.context.object,"Workshop orthographic locked","stone","camera")
camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
camera.data.type="ORTHO"; camera.data.ortho_scale=16.0
scene.camera=camera
scene.unit_settings.system="METRIC"; scene.unit_settings.scale_length=1.0
scene.render.resolution_x=1600; scene.render.resolution_y=900; scene.render.resolution_percentage=100
scene.render.engine="BLENDER_WORKBENCH"
scene.display.shading.color_type="OBJECT"
scene.display.shading.light="STUDIO"
scene.display.shading.show_shadows=True
scene.display.shading.show_cavity=True
scene.display.shading.cavity_type="BOTH"
scene.display.shading.background_type="WORLD"
scene.world.color=(.065,.08,.09)
scene.render.image_settings.file_format="PNG"
scene.view_settings.view_transform="Standard"
bpy.context.view_layer.update()


def project(p):
    q=world_to_camera_view(scene,camera,Vector(p))
    return [round(q.x,6),round(1-q.y,6)]


def rect(x0,y0,x1,y1):
    return [project((x0,y0,0)),project((x1,y0,0)),project((x1,y1,0)),project((x0,y1,0))]


points={
    "spawn":(-2,-1.65,0), "bench_approach":(-.95,.85,0),
    "bucket_approach":(-1.80,-.05,0), "door_approach":(2.35,2.12,0),
    "pillar_behind":(1.18,.23,0), "pillar_front":(1.18,-1.52,0),
    "pillar_left":(.27,-.66,0), "pillar_right":(2.1,-.66,0),
    "fire":(-2.90,1.80,1.00), "bench_focus":(-.85,1.90,.90),
    "door_focus":(2.35,2.9,1.10), "pillar_anchor":(px,py-.41,0),
}
ground=rect(-3.65,-2.7,3.68,2.48)
obstacles={"hearth":rect(-3.60,1.23,-2.20,2.48),"workbench":rect(-1.82,1.43,.12,2.40),"bucket":rect(-2.01,.39,-1.59,.81),"pillar":rect(px-.44,py-.44,px+.44,py+.44)}
groups={}
for obj in collection.objects:
    if obj.type!="MESH": continue
    groups.setdefault(obj["layer"],[]).extend(project(obj.matrix_world@Vector(c)) for c in obj.bound_box)
projection={"camera":{"resolution":[1600,900],"ortho_scale":16.0,"location":list(camera.location),"rotation":list(camera.rotation_euler)},"body_reference_m":1.80,"body_height_ratio":round(project((0,0,0))[1]-project((0,0,1.80))[1],6),"dimensions_m":{"bucket_body":.35,"bench_surface":.90,"door_clearance":2.55,"passage_minimum":1.25},"points":{k:project(v) for k,v in points.items()},"ground_outline":ground,"obstacles":obstacles,"group_projected_bounds":groups,"metric_points":points}
features = {"floor_fl":(-4,-3,.01),"floor_fr":(4,-3,.01),"floor_br":(4,3,.01),"floor_bl":(-4,3,.01),
            "pillar_foot":(1.18,-.66,0),"pillar_head":(1.18,-.66,2.56),
            "bucket_bottom":(-1.8,.6,0),"bucket_top":(-1.8,.6,.35),
            "bench_foot":(-.85,1.9,0),"bench_top":(-.85,1.9,.9),
            "door_foot":(2.35,2.83,0),"door_top":(2.35,2.83,2.55)}
(OUT/"registration_features.json").write_text(json.dumps({k:project(v) for k,v in features.items()},indent=2),encoding="utf-8")
(OUT/"projection.json").write_text(json.dumps(projection,indent=2),encoding="utf-8")
scene.render.filepath=str(OUT/"blockout.png")
bpy.ops.render.render(write_still=True)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=="VIEW_3D":
            area.spaces.active.region_3d.view_perspective="CAMERA"
            area.spaces.active.shading.color_type="OBJECT"
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print(json.dumps({"output":str(OUT),"objects":len(collection.objects),"body_height_ratio":projection["body_height_ratio"]}))
