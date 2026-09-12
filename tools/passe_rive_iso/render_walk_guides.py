"""One motion, four cameras. Render the evaluated saved contact rig, never the open scene."""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/passe_rive_motion'))
import walk_model as motion
OUT=ROOT/'art/source/characters/achilles/passe_rive_walk_iso_v1'
OUT.mkdir(parents=True,exist_ok=True)
scene=bpy.context.scene;rig=bpy.data.objects['PasseRive_Rig']
scene.render.resolution_x=640;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.render.film_transparent=True;bpy.data.collections['Ground_reference'].hide_render=True
report={}
for direction,(x,y) in {'E':(6,6),'S':(-6,6),'N':(6,-6),'W':(-6,-6)}.items():
 camera=bpy.data.objects['Camera_E'].copy();camera.data=camera.data.copy();scene.collection.objects.link(camera)
 camera.name='Guide_'+direction;offset=Vector((x,y,math.sqrt(72)*math.tan(math.radians(30))))
 camera.location=Vector((0,0,1.04))+offset;camera.rotation_euler=(-offset).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=2.52;scene.camera=camera
 def project(p):
  q=world_to_camera_view(scene,camera,Vector(p));return [q.x*640,(1-q.y)*960]
 origin=project((0,0,0));forward=project((0,.9,0));rows=[]
 folder=OUT/'guides'/direction;folder.mkdir(parents=True,exist_ok=True)
 for i in range(12):
  frame=1+i*3;scene.frame_set(frame);bpy.context.view_layer.update();row={'frame':i,'phase':i/12,'feet':{},'joints':{}}
  for side in 'LR':
   f=motion.foot(i/12,side);row['feet'][side]={'contact':f['contact']}
   for name in ['Heel','Toe']:row['feet'][side][name.lower()]=project(bpy.data.objects[name+'.'+side].matrix_world.translation)
   row['joints'][side]={name:project(rig.matrix_world@rig.pose.bones[bone+'.'+side].head) for name,bone in [('hip','Thigh'),('knee','Shin'),('ankle','Foot'),('shoulder','UpperArm'),('elbow','Forearm'),('hand','Hand')]}
  path=folder/f'{i:02}.png'
  scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
  rows.append(row)
 report[direction]={'origin':origin,'stride_vector':[forward[k]-origin[k] for k in range(2)],'rows':rows}
(OUT/'guide_measurements.json').write_text(json.dumps(report,indent=2))
print('FOUR_CAMERA_GUIDES_COMPLETE')
