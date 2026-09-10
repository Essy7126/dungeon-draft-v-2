"""Read-only skeletal projection for a drawn sprite experiment, not sprite rendering."""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/source/sprite_workshop/sentinelle_guided_v1'
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'.gdignore').write_text('')
scene=bpy.context.scene
rig=bpy.data.objects['Sentinelle_Rig']
camera=bpy.data.objects['Camera_E']
scene.camera=camera
scene.render.resolution_x=800
scene.render.resolution_y=720
scene.render.resolution_percentage=100
rig.animation_data.action=bpy.data.actions['Estoc_Preview']
if rig.animation_data.action.slots:
    rig.animation_data.action_slot=rig.animation_data.action.slots[0]

def project(v):
    p=world_to_camera_view(scene,camera,Vector(v))
    return [round(p.x*800,3),round((1-p.y)*720,3)]

poses=[]
for f,label in [(1,'GARDE'),(6,'CHARGE'),(13,'CONTACT'),(16,'FREINAGE')]:
    scene.frame_set(f)
    bpy.context.view_layer.update()
    bones={b.name:{'head':project(rig.matrix_world@b.head),'tail':project(rig.matrix_world@b.tail)}
           for b in rig.pose.bones if not b.name.startswith(('CTRL_','POLE_'))}
    feet={}
    for side in ('L','R'):
        ob=bpy.data.objects['Boot.'+side]
        corners=[Vector(v) for v in ob.bound_box]
        z=min(v.z for v in corners)
        local=[v for v in corners if abs(v.z-z)<1e-5]
        local.sort(key=lambda v:math.atan2(v.y,v.x))
        world=[ob.matrix_world@v for v in local]
        feet[side]={'sole':[project(v) for v in world],
                    'ground':[project((v.x,v.y,-.015)) for v in world]}
    hand=rig.pose.bones['Hand.R']
    weapon=[project(rig.matrix_world@hand.matrix@Vector((0,t,0))) for t in (-.43,0,.76,1.14)]
    shield=bpy.data.objects['Shield_rim']
    outline=[project(shield.matrix_world@Vector((.56*math.cos(t),0,.68*math.sin(t))))
             for t in [i*math.tau/48 for i in range(49)]]
    ground=[]
    for n in range(-2,5):
        ground.append([project((n*.5,-1,-.015)),project((n*.5,2.5,-.015))])
        ground.append([project((-1,n*.5,-.015)),project((1.5,n*.5,-.015))])
    poses.append({'frame':f,'label':label,'bones':bones,'feet':feet,'weapon':weapon,
                  'shield':outline,'ground':ground,'head':project(bpy.data.objects['Helmet'].matrix_world.translation)})
report={'source_blend':bpy.data.filepath,'direction':'E','camera':'orthographic, elevation 30 degrees',
        'canvas':[800,720],'purpose':'Pose reference only; original painted sprite defines appearance',
        'poses':poses,'limitations':['Existing mannequin proportions are a guide, not a final character design',
            'Sole polygons are bounding boxes; original study retains a small ground clearance']}
(OUT/'pose_guide.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'poses':len(poses),'output':str(OUT/'pose_guide.json')}))
