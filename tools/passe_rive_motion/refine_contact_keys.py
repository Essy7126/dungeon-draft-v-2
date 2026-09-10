"""Add keys at support transitions so interpolation cannot lift a planted foot early."""
import bpy,sys,math
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(Path(__file__).parent));import walk_model as motion
assert Path(bpy.data.filepath).name=='passe_rive_walk_v2_refined.blend'
out=Path(bpy.data.filepath).with_name('passe_rive_walk_v2_contacts.blend')
if out.exists():raise RuntimeError('Contact revision already exists.')
rig=bpy.data.objects['PasseRive_Rig'];scene=bpy.context.scene
for t in [.1,.44,.6,.94]:
 f=1+t*36;scene.frame_set(int(f),subframe=f-int(f))
 for side in 'LR':
  foot=motion.foot(t,side);pb=rig.pose.bones['CTRL_Foot.'+side];base=pb.bone.matrix_local.to_3x3().to_4x4()
  pb.matrix=Matrix.Translation(Vector(foot['ankle']))@Matrix.Rotation(foot['pitch'],4,'X')@base
  pb.keyframe_insert('location',frame=f);pb.keyframe_insert('rotation_quaternion',frame=f)
for layer in rig.animation_data.action.layers:
 for strip in layer.strips:
  for bag in strip.channelbags:
   for fc in bag.fcurves:
    for k in fc.keyframe_points:k.interpolation='LINEAR'
scene.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(out));print('CONTACT_KEYS_READY '+str(out))
