"""Original mesh VFX. Run Blender --background --factory-startup --disable-autoexec.
Each saved blend is editable, with baked visibility keys and no Python handlers.
"""
import bpy
import math
import json
import sys
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/dev/class_card_vfx/render"
SOURCE = ROOT / "art/source/vfx/class_cards"
FAMILIES = ["slash", "pierce", "cleave", "fire", "ice", "lightning", "shadow",
            "guard", "mark", "bleed", "weaken", "root", "disrupt", "stasis",
            "move", "push", "pull"]
FRAMES, SIZE, FPS = 24, 256, 30
PALETTES = {
 "fire": ["813e38", "e78148", "f3c876"], "ice": ["377b87", "86d4d5", "e1eee1"],
 "lightning": ["697795", "b7cbef", "fff0be"], "shadow": ["564c72", "ab87b2", "e5c4d6"],
 "guard": ["78633f", "c5a269", "eee0ad"], "mark": ["926953", "e5b079", "ffdfb1"],
 "bleed": ["682e45", "bf5869", "edb29b"], "weaken": ["5a536d", "998eae", "d7c2d4"],
 "root": ["4b7461", "8eb48a", "d8d7a2"], "disrupt": ["536b86", "9caec6", "e7dabb"],
 "stasis": ["66648c", "aaa3ce", "eae3e6"], "move": ["416b68", "81af9f", "d0d8b3"],
 "pull": ["595b76", "9da1bd", "dfdac1"], "push": ["88694f", "c3a376", "ede0b9"],
}

def smooth(a, b, t):
    u = min(1, max(0, (t-a)/(b-a)))
    return u*u*(3-2*u)

def geometry(family, t):
    buffers = {p: {"v": [], "f": [], "m": []} for p in ["rear", "front"]}
    envelope = smooth(0, .16, t)*(1-smooth(.48, 1, t))
    if envelope < .001:
        return buffers
    def face(points, material=1):
        part = "front" if sum(p[1] for p in points)/len(points) < 0 else "rear"
        b = buffers[part]
        start = len(b["v"])
        b["v"].extend(points)
        b["f"].append(tuple(range(start, start+len(points))))
        b["m"].append(material)
    def band(points, width=.045, material=1):
        for i in range(len(points)-1):
            a, b = Vector(points[i]), Vector(points[i+1])
            wa = Vector((0, 0, width*envelope*math.sin(math.pi*(i+.5)/len(points))))
            face([a-wa, b-wa, b+wa, a+wa], material)
    def shard(c, direction, length, width, material=1):
        c, d = Vector(c), Vector(direction).normalized()
        side = Vector((d.z, 0, -d.x)).normalized()*width*envelope
        face([c-d*length*.5*envelope, c+side, c+d*length*.5*envelope, c-side], material)
    def ring(radius, z, count=60, phase=0, extent=math.tau, width=.04, material=1):
        band([(radius*math.cos(phase+extent*i/count), radius*math.sin(phase+extent*i/count), z)
              for i in range(count+1)], width, material)
    if family in ["slash", "cleave", "pierce"]:
        sweeps = 3 if family == "cleave" else 1
        for j in range(sweeps):
            if family == "pierce":
                shard((0, -.13, 1), (1, 0, .4), 2.8, .12, 2)
                band([(-1.2, .1, .65), (0, .1, 1), (1.3, .1, 1.4)], .09)
            else:
                points = [(1.05*math.cos(-2+t*2+i*.036+j*2), .52*math.sin(-2+t*2+i*.036+j*2),
                           .85+.5*math.sin(i*.032+j)) for i in range(65)]
                band(points, .12 if family == "slash" else .07, 2)
                band([(x,y,z-.09) for x,y,z in points], .05, 0)
    elif family == "fire":
        ring(.35+t*.65, .06, width=.07)
        for i in range(9):
            a=i*2.39996
            r=.25+(i%3)*.2
            h=.55+(.35 if i%2 else .65)*envelope
            x,y=r*math.cos(a),r*math.sin(a)
            w=.12*envelope
            drift=.15*math.sin(a+t*9)
            # Grounded curved tongues, with no geometry extending below the tile.
            face([(x-w,y,.06),(x-w*1.35,y,.23),(x-w*.8,y,h*.55),
                  (x+drift-w*.3,y,h*.83),(x+drift,y,h+.22),
                  (x+w*.65,y,h*.6),(x+w*1.2,y,.25),(x+w,y,.06)],i%3)
            shard((r*math.cos(a+t),r*math.sin(a+t),.45+t*1.45),(.3,0,1),.2,.05,2)
    elif family == "ice":
        ring(.75*envelope,.07,6,width=.055)
        for i in range(7):
            a=i*math.tau/7
            r=.6
            shard((r*math.cos(a),r*math.sin(a),.54),(.35*math.cos(a),0,1),1.05,.13,i%3)
    elif family == "lightning":
        for j in range(3):
            a=j*math.tau/3+t*.6
            band([(.5*math.cos(a)+(.2 if i%2 else -.18),.45*math.sin(a),2-i*.27)
                  for i in range(8)],.05,2 if j==0 else 1)
        ring(.3+t*.7,.06,width=.045)
    elif family in ["shadow", "move", "pull"]:
        for j in range(3):
            radius=(1-t)*.9+.12 if family=="pull" else .35+t*.65
            points=[]
            for i in range(70):
                a=i*.045+j*math.tau/3+t*3
                points.append((radius*math.cos(a),radius*math.sin(a),.15+i*.015))
            band(points,.075, j%3)
    elif family == "guard":
        ring(.83,.08,width=.055,material=2)
        for i in range(7):
            a=i*math.tau/7
            x,y=.78*math.cos(a),.78*math.sin(a)
            shard((x,y,.65),(0,0,1),1.3,.18,1)
            shard((x,y-.015,.72),(0,0,1),.75,.055,2)
        ring(.8,1.12,phase=t*.6,extent=5.8,width=.035)
    elif family == "mark":
        ring(.66,1.6,4,phase=math.pi/4,width=.07,material=2)
        for i in range(4):
            a=i*math.pi/2
            shard((.6*math.cos(a),.6*math.sin(a),1.6),(0,0,1),.35,.05,1)
    elif family == "bleed":
        band([(-.65,.12,.55),(0,.12,.95),(.68,.12,1.35)],.06,2)
        for i in range(8):
            a=i*2.39996
            r=.35+t*.45
            shard((r*math.cos(a),r*math.sin(a),1.3-t*(.5+i*.05)),(.2,0,1),.32,.065,1 if i%3 else 2)
        ring(.5,.05,extent=4.8,width=.055,material=0)
    elif family == "weaken":
        for j in range(3):
            ring(.5+j*.15,1.5-j*.3-t*.4,phase=j*1.5,extent=4.5,width=.06,material=j)
    elif family == "root":
        for j in range(6):
            a=j*math.tau/6
            band([( (.82-i*.013)*math.cos(a+i*.02), (.82-i*.013)*math.sin(a+i*.02), i*.026)
                  for i in range(32)],.05, j%3)
        ring(.78,.05,8,width=.06)
    elif family == "disrupt":
        for j in range(6):
            a=j*math.tau/6
            r=.35+t*.5
            shard((r*math.cos(a),r*math.sin(a),1.55), (math.cos(a),0,math.sin(a)),.48,.07,j%3)
        band([(-.55,0,1.9),(0,0,1.2),(.5,0,1.8)],.045,2)
    elif family == "stasis":
        for j in range(2):
            z=.25+j*1.4
            ring(.7,z,8,phase=t*.5,width=.045,material=2)
        for j in range(5):
            a=j*math.tau/5
            band([(.7*math.cos(a),.7*math.sin(a),.25),(0,0,.95),(.7*math.cos(a+.8),.7*math.sin(a+.8),1.65)],.045)
    elif family == "push":
        for j in range(3):
            ring(.2+t*.85+j*.16,.12+j*.1,phase=-.1,extent=5.8,width=.07,material=j)
    # Small chips finish the decay and keep the burst legible at gameplay scale.
    if family in ["slash", "pierce", "cleave", "push", "ice", "guard"]:
        for i in range(9):
            a=i*2.39996
            r=.45+t*.75
            shard((r*math.cos(a),r*math.sin(a),.35+t*.3),(math.cos(a),0,1),.17,.035,i%3)
    return buffers

def build(family):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=16
    scene.cycles.use_denoising=False
    scene.render.resolution_x=SIZE
    scene.render.resolution_y=SIZE
    scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.fps=FPS
    scene.frame_start=1
    scene.frame_end=FRAMES
    scene.view_settings.view_transform="Standard"
    scene.view_settings.look="None"
    camera=bpy.data.objects.new("Camera",bpy.data.cameras.new("Isometric_30_degrees"))
    scene.collection.objects.link(camera)
    target=Vector((0,0,1))
    camera.location=target+Vector((0,-8.660254,5))
    camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.type="ORTHO"
    camera.data.ortho_scale=3.6
    scene.camera=camera
    materials=[]
    for rgb in PALETTES.get(family,["76604c","c8b497","f1e8c8"]):
        values=[int(rgb[i:i+2],16)/255 for i in (0,2,4)]
        linear=[v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in values]
        mat=bpy.data.materials.new(rgb)
        mat.use_nodes=True
        mat.node_tree.nodes.clear()
        emit=mat.node_tree.nodes.new("ShaderNodeEmission")
        emit.inputs["Color"].default_value=(*linear,1)
        output=mat.node_tree.nodes.new("ShaderNodeOutputMaterial")
        mat.node_tree.links.new(emit.outputs[0],output.inputs[0])
        materials.append(mat)
    collections={}
    for part in ["rear","front"]:
        col=bpy.data.collections.new(part)
        scene.collection.children.link(col)
        collections[part]=col
    for frame in range(FRAMES):
        for part, data in geometry(family,frame/(FRAMES-1)).items():
            mesh=bpy.data.meshes.new(f"{part}_{frame:02d}")
            mesh.from_pydata(data["v"],[],data["f"])
            mesh.update()
            obj=bpy.data.objects.new(mesh.name,mesh)
            collections[part].objects.link(obj)
            for mat in materials: mesh.materials.append(mat)
            for p,index in zip(mesh.polygons,data["m"]): p.material_index=index
            for f,hidden in [(0,True),(frame+1,False),(frame+2,True)]:
                obj.hide_render=hidden
                obj.hide_viewport=hidden
                obj.keyframe_insert(data_path="hide_render",frame=f)
                obj.keyframe_insert(data_path="hide_viewport",frame=f)
    scene.frame_set(8)
    scene["family"]=family
    scene["provenance"]="Original procedural mesh geometry; no external art."
    SOURCE.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(family+".blend")))
    pivot=world_to_camera_view(scene,camera,Vector((0,0,0)))
    for part in ["rear","front"]:
        for name,col in collections.items(): col.hide_render=name!=part
        output=OUT/family/part
        output.mkdir(parents=True,exist_ok=True)
        for frame in range(FRAMES):
            scene.frame_set(frame+1)
            scene.render.filepath=str(output/f"{frame:02d}.png")
            bpy.ops.render.render(write_still=True)
    return {"family":family,"pivot":[pivot.x,1-pivot.y],"frames":FRAMES,"fps":FPS,"size":SIZE}

selected=FAMILIES
if "--family" in sys.argv: selected=[sys.argv[sys.argv.index("--family")+1]]
metadata=[build(f) for f in selected]
OUT.mkdir(parents=True,exist_ok=True)
(OUT/"manifest.json").write_text(json.dumps(metadata,indent=2),encoding="utf-8")
print("CLASS_VFX_RENDER_COMPLETE",len(metadata))
