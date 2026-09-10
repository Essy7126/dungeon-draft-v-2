"""Check evaluated Blender foot markers and export camera coordinates for review."""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(Path(__file__).parent));import walk_model as motion
OUT=ROOT/'artifacts/spine_trial/passe_rive_walk_v2'
scene=bpy.context.scene;camera=bpy.data.objects['Camera_E'];camera.data.ortho_scale=2.20
scene.render.resolution_x=640;scene.render.resolution_y=960
def project(p):
 q=world_to_camera_view(scene,camera,Vector(p));return [q.x*640,(1-q.y)*960]
rows=[];drift=[];floor=[];previous={}
for tick in range(145):
 time=tick/120;phase=time/motion.DURATION
 frame=1+phase*36;scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
 row={'time':time,'phase':phase,'feet':{}}
 for side in 'LR':
  f=motion.foot(phase,side);points={n:Vector(bpy.data.objects[n+'.'+side].matrix_world.translation) for n in ['Heel','Toe']};floor.extend(p.z for p in points.values())
  key='Heel' if f['contact']=='heel' else 'Toe';world=points[key]+Vector((0,motion.STRIDE*phase,0))
  prev=previous.get(side)
  if prev and prev['contact']==f['contact']!='swing' and f['phase']>prev['phase']:drift.append((world-prev['point']).length)
  previous[side]={'contact':f['contact'],'phase':f['phase'],'point':world}
  row['feet'][side]={'contact':f['contact'],'heel':project(points['Heel']),'toe':project(points['Toe'])}
 rows.append(row)
origin=project((0,0,0));forward=project((0,1,0));vector=[forward[i]-origin[i] for i in range(2)]
report={'cycle_seconds':1.2,'stride_m':.9,'speed_m_s':.75,'fps':30,'frame_count':36,'native_size':[640,960],
 'root_pixel':origin,'forward_pixels_per_meter':vector,'native_checks':{'samples':145,'max_contact_step_drift_m':max(drift),'sample_interval_seconds':1/120,'min_sole_height_m':min(floor)},
 'rows':rows,'scope':'Evaluated Blender markers; does not validate a subsequently generated painted character'}
(OUT/'native_review.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='rows'}))
assert min(floor)>-.001, min(floor)
assert max(drift)<.001, max(drift)
