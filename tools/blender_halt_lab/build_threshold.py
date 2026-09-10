"""Build the metric pre-run threshold in the guarded private Blender lab."""
import json
import math
from pathlib import Path
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(bpy.data.filepath).resolve().parents[4]
OUT = ROOT / "art/source/halts/underworld_threshold_v1"
OUT.mkdir(parents=True, exist_ok=True)
(OUT / ".gdignore").write_text("", encoding="utf-8")
scene = bpy.context.scene
assert scene.get("halt_lab_id") == "dungeon_draft_halt_scale_lab_v1"
scene.name = "Le Seuil des Ombres — conception métrique"
scene["halt_export_collection"] = "Threshold generated"
scene["halt_export_directory"] = "art/source/halts/underworld_threshold_v1"
scene["halt_required_groups"] = ["statue_left", "statue_right", "statue_rear"]
for sibling in scene.collection.children:
    if sibling.name != "Threshold generated":
        sibling.hide_render = True
        sibling.hide_viewport = True
old = bpy.data.collections.get("Threshold generated")
if old:
    for obj in list(old.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(old)
collection = bpy.data.collections.new("Threshold generated")
scene.collection.children.link(collection)
COLORS = {"stone":(.29,.34,.35,1),"floor":(.32,.38,.39,1),
          "edge":(.43,.47,.44,1),"bronze":(.35,.25,.105,1),
          "dark":(.065,.105,.12,1),"fire":(1,.29,.045,1),"cloth":(.27,.07,.055,1)}


def own(obj,name,mat,group):
    obj.name=name
    for parent in list(obj.users_collection): parent.objects.unlink(obj)
    collection.objects.link(obj)
    obj.color=COLORS[mat]; obj["layer"]=group; obj["threshold_owned"]=True
    return obj


def block(name,loc,dims,mat="stone",group="architecture",bevel=.03):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    obj=own(bpy.context.object,name,mat,group);obj.dimensions=dims
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=obj.modifiers.new("Worn edges","BEVEL");mod.width=bevel;mod.segments=2
    return obj


def cylinder(name,loc,radius,depth,mat="stone",group="architecture",vertices=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
    return own(bpy.context.object,name,mat,group)


def cone(name,loc,r1,r2,depth,mat,group,vertices=20):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r1,radius2=r2,depth=depth,location=loc)
    return own(bpy.context.object,name,mat,group)


def sphere(name,loc,scale,mat,group):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1,location=loc)
    obj=own(bpy.context.object,name,mat,group);obj.scale=scale
    return obj


def limb(name,a,b,radius,group):
    a,b=Vector(a),Vector(b)
    obj=cylinder(name,(a+b)/2,radius,(b-a).length,"edge",group,12)
    obj.rotation_euler=(b-a).to_track_quat("Z","Y").to_euler()
    return obj


block("Suspended terrace 12 x 8 metres",(0,0,-.24),(12,8,.48),"stone","floor")
for i in range(12):
    for j in range(8):
        block(f"Paving {i}-{j}",(i-5.5,j-3.5,-.015),(.97,.97,.05),"floor","floor",.015)
for x in [-5.7,5.7]:
    block("Terrace rim",(x,0,.04),(.32,8,.08),"edge","floor")
for x,y in [(-5.4,-3.5),(5.4,-3.5),(5.4,3.5),(-5.4,3.5)]:
    block("Substructure pier",(x,y,-1.12),(.75,.85,1.9),"stone","substructure")
# Broken parapets frame the paths without making a continuous front wall.
for x,y,dx,dy in [(-5.68,.65,.30,4.8),(5.68,1.45,.30,3.2),(-4.75,-3.68,1.4,.30),(4.7,-3.68,1.6,.30)]:
    block("Low parapet",(x,y,.34),(dx,dy,.68),"stone","parapets")
    block("Parapet cap",(x,y,.70),(dx+.10,dy+.10,.12),"edge","parapets")

# The threshold is architectural: intentionally much larger than a person.
for x in [.75,4.65]:
    block("Gate column plinth",(x,3.35,.17),(.95,1.05,.34),"edge","gate")
    cylinder("Doric column shaft",(x,3.35,2.55),.32,4.40,"edge","gate",24)
    for z in [.43,4.78]: cylinder("Doric column band",(x,3.35,z),.43,.18,"edge","gate")
    block("Doric capital",(x,3.35,4.98),(1.02,1.05,.25),"edge","gate")
block("Gate lintel",(2.7,3.35,5.25),(5.2,1.0,.42),"stone","gate")
block("Bronze lintel inset",(2.7,2.81,5.15),(3.90,.08,.16),"bronze","gate")
block("Door darkness",(2.7,3.72,2.4),(3.25,.15,4.8),"dark","gate",0)
for x in [1.17,4.22]:
    block("Open bronze door leaf",(x,3.54,2.42),(.42,.40,4.78),"bronze","gate")
for i in range(3):
    block("Threshold shallow step",(2.70,2.8+i*.20,.05+i*.05),(3.2,.60,.10),"edge","gate")
for x in [.08,5.25]:
    block("Faded crimson banner",(x,3.20,3.9),(.44,.08,1.50),"cloth","gate",.01)


def statue(name,x,y,body_h,pose):
    base=.60
    block(name+" square pedestal",(x,y,.22),(1.05,1.05,.44),"stone",name)
    block(name+" pedestal crown",(x,y,.52),(1.18,1.18,.16),"edge",name)
    cone(name+" draped robe",(x,y,base+body_h*.36),.43,.25,body_h*.72,"edge",name)
    torso=block(name+" shoulders",(x,y,base+body_h*.70),(.72,.41,body_h*.22),"edge",name,.09)
    sphere(name+" neck",(x,y,base+body_h*.84),(.14,.13,body_h*.065),"edge",name)
    sphere(name+" carved head",(x,y-.025,base+body_h*.92),(.24,.23,body_h*.10),"edge",name)
    # A geometric cloak silhouette is enough to constrain the painted statue.
    for side in [-1,1]:
        a=(x+side*.35,y,base+body_h*.76)
        if pose=="staff" and side==-1:
            b=(x-.64,y-.18,base+body_h*.60)
            c=(x-.67,y-.28,base+body_h*.72)
        else:
            b=(x+side*.32,y-.21,base+body_h*.53)
            c=(x+side*.11,y-.38,base+body_h*.54)
        limb(name+" upper arm",a,b,.14,name);limb(name+" forearm",b,c,.115,name)
        sphere(name+" hand",c,(.12,.11,.13),"edge",name)
    if pose=="staff": cylinder(name+" stone staff",(x-.67,y-.28,base+body_h*.53),.042,body_h*1.04,"bronze",name,10)
    else: block(name+" oath tablet",(x,y-.40,base+body_h*.52),(.43,.12,.43),"stone",name,.03)


statue("statue_left",-3.85,.92,3.05,"staff")
statue("statue_rear",-.85,2.85,2.75,"tablet")
statue("statue_right",3.35,-1.45,2.85,"tablet")
for index,(x,y) in enumerate([(1.15,2.45),(4.8,2.4)]):
    group=f"brazier_{index}"
    block("Human-scale brazier base",(x,y,.37),(.56,.56,.74),"stone",group)
    cylinder("Bronze brazier rim",(x,y,.93),.34,.10,"bronze",group)
    cone("Bronze brazier bowl",(x,y,.82),.17,.32,.22,"bronze",group)
    for i in range(5):
        cone("Flame guide",(x+(i-2)*.075,y+(i%2)*.06,1.15),.09,.005,.38+i*.02,"fire",f"fire_{index}",7)

# A shallow medallion marks the landing without obstructing navigation.
cylinder("Landing medallion",(-1.1,-1.15,.025),.70,.018,"bronze","floor",48)
cylinder("Medallion inset",(-1.1,-1.15,.038),.64,.014,"floor","floor",48)
target=Vector((0,.3,1.1))
bpy.ops.object.camera_add(location=target+Vector((8,-14,13)))
camera=own(bpy.context.object,"Threshold orthographic locked","stone","camera")
camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
camera.data.type="ORTHO";camera.data.ortho_scale=19.8
scene.camera=camera
scene.unit_settings.system="METRIC";scene.unit_settings.scale_length=1.0
scene.render.resolution_x=1600;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.engine="BLENDER_WORKBENCH"
scene.display.shading.color_type="OBJECT";scene.display.shading.light="STUDIO"
scene.display.shading.show_shadows=True;scene.display.shading.show_cavity=True
scene.display.shading.cavity_type="BOTH";scene.display.shading.background_type="WORLD"
scene.world.color=(.05,.08,.09);scene.view_settings.view_transform="Standard"
scene.render.image_settings.file_format="PNG"
bpy.context.view_layer.update()


def project(p):
    q=world_to_camera_view(scene,camera,Vector(p))
    return [round(q.x,7),round(1-q.y,7)]


def rect(x0,y0,x1,y1):
    return [project((x0,y0,0)),project((x1,y0,0)),project((x1,y1,0)),project((x0,y1,0))]


points={"spawn":(-3.2,-2.3,0),"statue_memory":(-2.5,.10,0),"fallen_oath":(2.0,-2.0,0),
        "threshold_gate":(2.7,1.5,0),"left_focus":(-3.85,.92,2.1),"right_focus":(3.35,-1.45,2.0),
        "gate_focus":(2.7,3.35,2.1),"fire_0":(1.15,2.45,1.22),"fire_1":(4.8,2.4,1.22),
        "statue_right_behind":(3.25,-.35,0),"statue_right_front":(3.25,-2.55,0),
        "statue_left_behind":(-3.85,2.05,0),"central":(-.8,-.6,0),"right_side":(4.7,-1.3,0)}
obstacles={"statue_left":rect(-4.50,.27,-3.20,1.57),"statue_rear":rect(-1.48,2.22,-.22,3.48),
           "statue_right":rect(2.70,-2.10,4.0,-.8),"brazier_0":rect(.83,2.13,1.47,2.77),
           "brazier_1":rect(4.48,2.08,5.12,2.72),"gate":rect(.20,2.92,5.2,3.72)}
data={"id":"underworld_threshold_v1","camera":{"resolution":[1600,900],"ortho_scale":19.8,
      "location":list(camera.location),"rotation":list(camera.rotation_euler)},
      "body_reference_m":1.80,"body_height_ratio":round(project((0,0,0))[1]-project((0,0,1.8))[1],7),
      "body_reference_pixels":202,"full_silhouette_pixels":257,
      "points":{k:project(v) for k,v in points.items()},"metric_points":points,
      "ground_outline":rect(-5.40,-3.40,5.35,2.93),"obstacles":obstacles,
      "features":{k:project(v) for k,v in {"floor_fl":(-6,-4,0),"floor_fr":(6,-4,0),"floor_br":(6,4,0),
                  "floor_bl":(-6,4,0),"left_statue_ground":(-3.85,.92,0),"left_statue_head":(-3.85,.92,3.65),
                  "right_statue_ground":(3.35,-1.45,0),"right_statue_head":(3.35,-1.45,3.45)}.items()}}
(OUT/"projection.json").write_text(json.dumps(data,indent=2),encoding="utf-8")
scene.render.filepath=str(OUT/"blockout.png")
bpy.ops.render.render(write_still=True)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=="VIEW_3D":
            area.spaces.active.region_3d.view_perspective="CAMERA"
            area.spaces.active.shading.color_type="OBJECT"
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print(json.dumps({"objects":len(collection.objects),"body_height_ratio":data["body_height_ratio"],"output":str(OUT)}))
