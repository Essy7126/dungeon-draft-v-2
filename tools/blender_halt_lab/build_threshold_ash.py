"""Build the metric pre-run threshold in the guarded private Blender lab."""
import json
import math
from pathlib import Path
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(bpy.data.filepath).resolve().parents[4]
OUT = ROOT / "art/source/halts/underworld_threshold_v1/ash"
OUT.mkdir(parents=True, exist_ok=True)
(OUT / ".gdignore").write_text("", encoding="utf-8")
scene = bpy.context.scene
assert scene.get("halt_lab_id") == "dungeon_draft_halt_scale_lab_v1"
scene.name = "Le Seuil des Ombres — clairière des trois dieux"
scene["halt_export_collection"] = "Threshold ash generated"
scene["halt_export_directory"] = "art/source/halts/underworld_threshold_v1/ash"
scene["halt_required_groups"] = ["statue_left", "statue_right", "statue_rear"]
for sibling in scene.collection.children:
    if sibling.name != "Threshold ash generated":
        sibling.hide_render = True
        sibling.hide_viewport = True
old = bpy.data.collections.get("Threshold ash generated")
if old:
    for obj in list(old.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(old)
collection = bpy.data.collections.new("Threshold ash generated")
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


COLORS["soil"]=(.095,.105,.105,1)
block("Continuous scorched earth",(0,0,-.18),(36,32,.25),"soil","floor",0)
# Broad walkable clearing; irregular buried stones never define a raised edge.
for i in range(-9,10):
    for j in range(-9,7):
        x,y=i*.82,j*.82
        centre=((x+.2)/7.3)**2+((y+1.4)/7.8)**2
        road=abs(x-(.62*y+1.3)) < 1.8
        if centre<1 and (road or (i*7+j*3)%5==0):
            o=block(f"Buried stone {i}-{j}",(x,y,-.02),(.74,.77,.07),"floor","floor",.045)
            o.rotation_euler.z=.14*math.sin(i*2+j*5)
# Ruined rocky margin, mostly low at sides to preserve open circulation.
for index,(x,y,z,sx,sy,sz) in enumerate([
    (-8.2,3.5,.8,1.3,1.7,1.1),(-7.8,-2.6,.5,1.4,1.6,.7),
    (-6.2,-7.8,.35,1.1,1.0,.6),(7.8,-5.8,.5,1.3,1.3,.8),
    (8.8,.0,.7,1.6,1.8,1.0),(-3.6,7,.9,1.5,1.6,1.3),
    (.5,8.2,1.5,1.8,1.5,2.0),(3.4,8.8,2.5,1.6,1.6,3),
    (6.8,8.2,2.5,1.4,1.5,3),(9.4,6,2,1.7,1.7,2.5)]):
    o=sphere("Burned rock "+str(index),(x,y,z),(sx,sy,sz),"stone","rock")
    o.rotation_euler=(.11*index,.13*index,.37*index)
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


for o in collection.objects:
    if o.get("layer")=="gate":
        o.location.x+=1.3
        o.location.y+=1.65
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


# Equilateral triangle: all pedestal centres lie on the same ground plane.
TRIANGLE={"hades":(-4.0,1.5,0.0),"zeus":(4.0,1.5,0.0),"hera":(0.0,1.5-4*math.sqrt(3),0.0)}
statue("statue_left",*TRIANGLE["hades"][:2],3.05,"staff")
statue("statue_rear",*TRIANGLE["zeus"][:2],3.05,"tablet")
statue("statue_right",*TRIANGLE["hera"][:2],3.05,"tablet")
# Identity cues in the scale model; final sculptural style comes from Emerald.
for dx in [-.09,.09]:
    cylinder("Hades bident prong",(-4.67+dx,1.22,3.66),.025,.35,"bronze","statue_left",8)
for a,b in [((4.45,1.22,2.9),(4.62,1.22,2.62)),((4.62,1.22,2.62),(4.44,1.22,2.53)),((4.44,1.22,2.53),(4.61,1.22,2.18))]:
    limb("Zeus lightning",a,b,.06,"statue_rear")
cone("Hera crown",(0,TRIANGLE["hera"][1],3.68),.28,.20,.24,"bronze","statue_right",12)
for index,(x,y) in enumerate([(1.30,4.10),(6.10,4.05)]):
    group=f"brazier_{index}"
    block("Human-scale brazier base",(x,y,.37),(.56,.56,.74),"stone",group)
    cylinder("Bronze brazier rim",(x,y,.93),.34,.10,"bronze",group)
    cone("Bronze brazier bowl",(x,y,.82),.17,.32,.22,"bronze",group)
    for i in range(5):
        cone("Flame guide",(x+(i-2)*.075,y+(i%2)*.06,1.15),.09,.005,.38+i*.02,"fire",f"fire_{index}",7)

target=Vector((0,-.5,1.1))
bpy.ops.object.camera_add(location=target+Vector((8,-14,13)))
camera=own(bpy.context.object,"Threshold orthographic locked","stone","camera")
camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
camera.data.type="ORTHO";camera.data.ortho_scale=24.0
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


points={"spawn":(-5.1,-5.5,0),"statue_memory":(-2.3,.7,0),"fallen_oath":(-1.7,-4.8,0),
        "threshold_gate":(4,3.2,0),"central":(0,-.5,0),
        "statue_right_behind":(0,-3.9,0),"statue_right_front":(0,-6.8,0),
        "statue_left_behind":(-4,2.85,0),"right_side":(5.5,-1.7,0),
        "fire_0":(1.30,4.10,1.22),"fire_1":(6.10,4.05,1.22)}
obstacles={name:rect(x-.7,y-.7,x+.7,y+.7) for name,(x,y,z) in TRIANGLE.items()}
pairs=[(a,b,(Vector(TRIANGLE[a])-Vector(TRIANGLE[b])).length) for a,b in [("hades","zeus"),("zeus","hera"),("hera","hades")]]
assert all(abs(distance-8)<1e-6 for a,b,distance in pairs)
data={"id":"underworld_threshold_v1","layout":"grounded_ash_equilateral",
      "camera":{"resolution":[1600,900],"ortho_scale":24.0,"location":list(camera.location),"rotation":list(camera.rotation_euler)},
      "body_reference_m":1.8,"body_height_ratio":round(project((0,0,0))[1]-project((0,0,1.8))[1],7),
      "body_reference_pixels":202,"full_silhouette_pixels":257,
      "triangle":{"centres_metres":TRIANGLE,"pairwise_distances_metres":pairs,"side_metres":8.0,"equilateral_verified":True},
      "points":{k:project(v) for k,v in points.items()},"metric_points":points,
      "statue_ground_anchors":{k:project(v) for k,v in TRIANGLE.items()},
      "ground_outline":rect(-7.1,-7.6,7.5,4.2),"obstacles":obstacles}
(OUT/"projection.json").write_text(json.dumps(data,indent=2),encoding="utf-8")
scene.render.filepath=str(OUT/"blockout.png")
bpy.ops.render.render(write_still=True)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=="VIEW_3D":area.spaces.active.region_3d.view_perspective="CAMERA"
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print(json.dumps({"objects":len(collection.objects),"body_height_ratio":data["body_height_ratio"],"triangle":data["triangle"],"output":str(OUT)}))
