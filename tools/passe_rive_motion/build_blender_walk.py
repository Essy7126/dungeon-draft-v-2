"""Build an isolated, editable native-IK motion study at Passe-rive proportions."""
import bpy,sys,json,math,importlib.util
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).parent))
import walk_model as motion
spec=importlib.util.spec_from_file_location('study_helpers',ROOT/'tools/blender_sentinelle/build_blocking.py')
h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
OUT=ROOT/'art/source/blender/passe_rive_walk_v2'
OUT.mkdir(parents=True,exist_ok=True)
FILE=OUT/'passe_rive_walk_v2_refined.blend'
if FILE.exists():raise RuntimeError('Preserve existing authored file; use the saved study for subsequent edits.')
# This script runs only in a new background factory-startup process.
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
char=bpy.data.collections.new('Passe_rive_movement');scene.collection.children.link(char)
stage=bpy.data.collections.new('Ground_reference');scene.collection.children.link(stage)
ink=h.material('Study_dark',(.09,.14,.17));ivory=h.material('Study_mask',(.75,.74,.65))
jade=h.material('Left_leg_jade',(.20,.55,.43));bronze=h.material('Right_leg_bronze',(.55,.34,.16))
floor=h.material('Ground',(.14,.18,.19));grid=h.material('Metric_lines',(.29,.36,.35))
rigdata=bpy.data.armatures.new('Passe_rive_walk');rig=bpy.data.objects.new('PasseRive_Rig',rigdata);char.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);rig.show_in_front=True
bpy.ops.object.mode_set(mode='EDIT')
def bone(name,head,tail,parent=None):
 b=rigdata.edit_bones.new(name);b.head=head;b.tail=tail
 if parent:b.parent=rigdata.edit_bones[parent]
 return b
bone('Root',(0,0,0),(0,0,.2))
bone('Pelvis',(0,0,1.025),(0,0,1.28),'Root')
bone('Chest',(0,0,1.28),(0,0,1.67),'Pelvis')
bone('Head',(0,0,1.67),(0,0,1.98),'Chest')
points={}
def solve(a,b,l1,l2,bend):
 a,b=Vector(a),Vector(b);d=(b-a).length;axis=(b-a).normalized();v=Vector(bend);v=(v-axis*v.dot(axis)).normalized()
 along=(l1*l1-l2*l2+d*d)/(2*d)
 return a+axis*along+v*math.sqrt(max(0,l1*l1-along*along))
for side in 'LR':
 s=1 if side=='R' else -1
 hip=Vector((s*.112,0,1.025));ankle=Vector((s*.112,0,.075));knee=solve(hip,ankle,.50,.49,(0,1,0))
 shoulder=Vector((s*.205,0,1.59));wrist=Vector((s*(.39 if side=='R' else .30),.14,1.32 if side=='R' else 1.20));elbow=solve(shoulder,wrist,.35,.27,(0,-.15,-1))
 points[side]={'hip':hip,'knee':knee,'ankle':ankle,'shoulder':shoulder,'elbow':elbow,'wrist':wrist}
 for name,a,b,parent in [('Thigh',hip,knee,'Pelvis'),('Shin',knee,ankle,'Thigh.'+side),('Foot',ankle,ankle+Vector((0,.18,-.075)),'Shin.'+side),('UpperArm',shoulder,elbow,'Chest'),('Forearm',elbow,wrist,'UpperArm.'+side),('Hand',wrist,wrist+Vector((0,.10,0)),'Forearm.'+side)]:bone(name+'.'+side,a,b,parent)
 bone('CTRL_Foot.'+side,ankle,ankle+Vector((0,.18,-.075)))
 bone('CTRL_Hand.'+side,wrist,wrist+Vector((0,.1,0)))
 bone('POLE_Knee.'+side,knee+Vector((0,.6,0)),knee+Vector((0,.6,.1)))
 bone('POLE_Elbow.'+side,elbow+Vector((0,-.6,-.25)),elbow+Vector((0,-.6,-.15)))
bpy.ops.object.mode_set(mode='OBJECT')
constraints=[]
for p in rig.pose.bones:p.rotation_mode='QUATERNION'
for side in 'LR':
 for lower,end,pole,joint in [('Shin','Foot','Knee','knee'),('Forearm','Hand','Elbow','elbow')]:
  pb=rig.pose.bones[lower+'.'+side];c=pb.constraints.new('IK');c.target=rig;c.subtarget='CTRL_'+end+'.'+side;c.pole_target=rig;c.pole_subtarget='POLE_'+pole+'.'+side;c.chain_count=2;c.use_stretch=False;pb.ik_stretch=0;pb.parent.ik_stretch=0
  constraints.append((c,pb,points[side][joint]));orient=rig.pose.bones[end+'.'+side].constraints.new('COPY_ROTATION');orient.target=rig;orient.subtarget='CTRL_'+end+'.'+side;orient.owner_space=orient.target_space='POSE'
for c,pb,target in constraints:
 best=(1e9,0)
 for degrees in range(-180,180,3):
  c.pole_angle=math.radians(degrees);bpy.context.view_layer.update();e=(pb.head-target).length
  if e<best[0]:best=(e,degrees)
 c.pole_angle=math.radians(best[1])
bpy.context.view_layer.update()
def attach(ob,name):h.bone_parent(ob,rig,name);return ob
attach(h.ellipsoid('Pelvis',(0,0,1.04),(.135,.09,.12),ink,char),'Pelvis')
attach(h.ellipsoid('Waist',(0,0,1.20),(.12,.085,.15),ink,char),'Chest')
attach(h.ellipsoid('Thorax',(0,.008,1.44),(.19,.105,.21),ink,char),'Chest')
attach(h.ellipsoid('Neck',(0,0,1.69),(.047,.045,.07),ink,char),'Head')
attach(h.ellipsoid('Hood',(0,-.007,1.83),(.097,.101,.153),ink,char),'Head')
attach(h.ellipsoid('Mask',(0,.072,1.815),(.064,.040,.105),ivory,char),'Head')
for side in 'LR':
 p=points[side];mat=jade if side=='L' else bronze
 for top,bottom,label,rad,m in [('hip','knee','Thigh',.060,mat),('knee','ankle','Shin',.044,mat),('shoulder','elbow','UpperArm',.049,ink),('elbow','wrist','Forearm',.041,ink)]:attach(h.segment(label+'.'+side,p[top],p[bottom],rad,m,char),label+'.'+side)
 for name,bn,r in [('knee','Shin',.05),('elbow','Forearm',.043),('wrist','Hand',.036)]:attach(h.ellipsoid(name+'.'+side,p[name],(r,r,r),mat if name=='knee' else ink,char),bn+'.'+side)
 # Flat sole footprint: local heel/toe markers match the rigid foot's geometry.
 attach(h.cube('Foot_mesh.'+side,(p['ankle'].x,.04,.042),(.095,.28,.082),mat,char,.022),'Foot.'+side)
 for name,y in [('Heel',motion.HEEL),('Toe',motion.TOE)]:
  marker=bpy.data.objects.new(name+'.'+side,None);char.objects.link(marker);marker.location=(p['ankle'].x,y,0);marker.empty_display_size=.02;h.bone_parent(marker,rig,'Foot.'+side)
 grip=p['wrist']
 if side=='R':
  attach(h.segment('Spear_shaft',grip+Vector((0,0,-1.10)),grip+Vector((0,0,.68)),.011,bronze,char),'Hand.R')
  attach(h.ellipsoid('Spear_blade',grip+Vector((0,0,.77)),(.031,.016,.115),ivory,char),'Hand.R')
 else:
  ob=h.ellipsoid('Shield_rim',grip+Vector((-.035,.06,-.05)),(.19,.045,.295),bronze,char);ob.rotation_euler=(0,math.radians(-22),math.radians(-16));attach(ob,'Hand.L')
  ob=h.ellipsoid('Shield_face',grip+Vector((-.035,.092,-.05)),(.17,.028,.270),ink,char);ob.rotation_euler=(0,math.radians(-22),math.radians(-16));attach(ob,'Hand.L')
rig.animation_data_create();action=bpy.data.actions.new('Walk_E_Editable');rig.animation_data.action=action;action.use_fake_user=True
def control(name,location,rot=None):
 pb=rig.pose.bones[name];base=pb.bone.matrix_local.to_3x3().to_4x4();pb.matrix=Matrix.Translation(Vector(location))@(rot or Matrix.Identity(4))@base
 pb.keyframe_insert('location');pb.keyframe_insert('rotation_quaternion')
for frame in range(1,38):
 scene.frame_set(frame);t=(frame-1)/36;b=motion.body(t)
 # Pelvis and chest remain editable bones; targets are independent siblings.
 control('Pelvis',b['pelvis'],Matrix.Rotation(b['pelvis_yaw'],4,'Z'))
 chest=rig.pose.bones['Chest'];chest.rotation_quaternion=(Matrix.Rotation(b['lean'],4,'X')@Matrix.Rotation(b['chest_yaw']-b['pelvis_yaw'],4,'Y')).to_quaternion();chest.keyframe_insert('rotation_quaternion')
 head=rig.pose.bones['Head'];head.rotation_quaternion=Matrix.Rotation(-b['lean']*.7,4,'X').to_quaternion();head.keyframe_insert('rotation_quaternion')
 for side in 'LR':
  f=motion.foot(t,side);control('CTRL_Foot.'+side,f['ankle'],Matrix.Rotation(f['pitch'],4,'X'))
  rest=points[side]['wrist'];a=2*math.pi*t;dy=b['spear_swing']*(1 if side=='R' else -.6)
  control('CTRL_Hand.'+side,(rest.x+b['pelvis'][0]*.4,rest.y+dy,rest.z+(b['pelvis'][2]-1.025)*.6))
for layer in action.layers:
 for strip in layer.strips:
  for bag in strip.channelbags:
   for fc in bag.fcurves:
    for k in fc.keyframe_points:k.interpolation='LINEAR'
    fc.modifiers.new('CYCLES')
scene.frame_start=1;scene.frame_end=36;scene.render.fps=30
passes=motion.crossing();events=[(0,'Contact gauche'),(.10,'Absorption gauche'),(passes,'Passage droit'),(.40,'Remontee'),(.5,'Contact droit'),(.60,'Absorption droite'),(passes+.5,'Passage gauche'),(.90,'Remontee')]
for t,name in events:scene.timeline_markers.new(name,frame=round(t*36)+1)
for ix in range(-10,11):
 h.cube('Ground_line_X',(0,ix*.25,-.01),(6,.007,.006),grid,stage,0)
 h.cube('Ground_line_Y',(ix*.25,0,-.01),(.007,6,.006),grid,stage,0)
h.cube('Ground',(0,0,-.035),(6,6,.04),floor,stage,0)
look=Vector((0,0,1.04))
for name,offset in [('E',Vector((6,6,math.sqrt(72)*math.tan(math.radians(30))))),('Side',Vector((8,0,0)))]:
 cd=bpy.data.cameras.new('Camera_'+name);cam=bpy.data.objects.new('Camera_'+name,cd);scene.collection.objects.link(cam);cam.location=look+offset;cam.rotation_euler=(-offset).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO';cd.ortho_scale=2.52
scene.camera=bpy.data.objects['Camera_E'];scene.render.engine='BLENDER_WORKBENCH';scene.render.resolution_x=768;scene.render.resolution_y=1024;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.film_transparent=True
scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=True;scene.display.shading.show_cavity=True;scene.display.shading.cavity_type='BOTH';scene.display.shading.background_type='WORLD';scene.world.color=(.13,.15,.16)
scene.view_settings.view_transform='Standard'
rig['cycle_seconds']=motion.DURATION;rig['stride_m']=motion.STRIDE;rig['source_reference']='Animation Mentor / Jason Martinsen walk-cycle course; authored blocking, not mocap';rig['artwork_status']='Technical mannequin only'
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
scene.frame_set(1);bpy.context.view_layer.update()
measurements=[];native_errors=[];floor_z=[]
for frame in range(1,38):
 scene.frame_set(frame);bpy.context.view_layer.update();t=(frame-1)/36
 row={'frame':frame,'phase':t,'root_translation':[0,motion.STRIDE*t,0],'feet':{}}
 for side in 'LR':
  pb=rig.pose.bones['Shin.'+side];native_errors.append((pb.tail-rig.pose.bones['CTRL_Foot.'+side].head).length)
  f=motion.foot(t,side);observed={n:list(bpy.data.objects[n+'.'+side].matrix_world.translation) for n in ['Heel','Toe']};row['feet'][side]={'contact':f['contact'],**observed};floor_z.extend([observed[n][2] for n in observed])
 measurements.append(row)
assert max(native_errors)<.002, max(native_errors)
assert min(floor_z)>-.003,min(floor_z)
report={'blend_file':str(FILE.relative_to(ROOT)),'analytical':motion.validate(),'native_ik_max_target_error_m':max(native_errors),'native_sole_min_z_m':min(floor_z),'frames':measurements,'events':[{'phase':t,'name':n} for t,n in events],'artistic_approval':False}
(OUT/'walk_validation.json').write_text(json.dumps(report,indent=2))
scene.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(FILE))
print('PASSE_RIVE_WALK_BUILT '+json.dumps({'file':str(FILE),'native_ik_error_m':max(native_errors),'passing_phase':passes}))
