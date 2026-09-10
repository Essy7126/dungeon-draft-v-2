"""Whole-body thrust poses with native IK and separate blocking/preview actions."""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/source/blender/sentinelle_blocking_v1'


def curves(action):
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                yield from bag.fcurves


def set_control(rig, name, position, rotation=(0,0,0)):
    pb=rig.pose.bones[name]
    rest=pb.bone.matrix_local
    pb.location=rest.to_3x3().inverted()@(Vector(position)-rest.translation)
    pb.rotation_euler=[math.radians(a) for a in rotation]


def author():
    rig=bpy.data.objects['Sentinelle_Rig']
    scene=bpy.context.scene
    if bpy.data.actions.get('Estoc_Blocking'):
        raise RuntimeError('Existing authored actions preserved.')
    rest=json.loads(rig['rest_points'])
    rig.animation_data_create()
    action=bpy.data.actions.new('Estoc_Preview')
    rig.animation_data.action=action
    action.use_fake_user=True
    # Each row describes the entire pose, not independent oscillators.
    # frame, root forward/down, thorax lean/yaw, spear hand, shield hand,
    # front ankle forward/lift, rear heel lift, spear pitch, rear foot pitch.
    poses=[
        (1, 0,0, 0,0, (.65,.40,1.58),(-.68,.48,1.62), .40,0, 0,10,0),
        (6, -.07,-.055, 3,-6, (.67,.18,1.61),(-.76,.42,1.69), .40,0, 0,6,0),
        (8, -.035,-.045, 1,-3, (.66,.25,1.61),(-.78,.42,1.69), .46,.055, 0,4,0),
        (10,.035,-.04, -2,2, (.64,.48,1.61),(-.81,.42,1.68), .54,0, 0,2,0),
        (13,.18,-.045, -6,8, (.63,1.15,1.62),(-.84,.42,1.66), .54,0, .045,0,-8),
        (16,.16,-.05, -5,7, (.63,1.10,1.62),(-.82,.43,1.66), .54,0, .025,0,-4),
        (20,.04,-.035, -1,1, (.64,.55,1.60),(-.75,.45,1.64), .54,0, 0,5,0),
        (22,0,-.02, 0,0, (.65,.43,1.59),(-.71,.47,1.63), .46,.045, 0,8,0),
        (25,0,0, 0,0, (.65,.40,1.58),(-.68,.48,1.62), .40,0, 0,10,0),
    ]
    for row in poses:
        f,forward,down,lean,yaw,hand_r,hand_l,foot_l,lift_l,lift_r,pitch,heel=row
        scene.frame_set(f)
        for pb in rig.pose.bones:
            pb.location=(0,0,0);pb.rotation_euler=(0,0,0);pb.scale=(1,1,1)
        root=rig.pose.bones['Root']
        root.location=root.bone.matrix_local.to_3x3().inverted()@Vector((0,forward,down))
        rig.pose.bones['Pelvis'].rotation_euler=(math.radians(lean*.25),math.radians(yaw*.25),0)
        rig.pose.bones['Thorax'].rotation_euler=(math.radians(lean),math.radians(yaw),0)
        rig.pose.bones['Neck'].rotation_euler=(math.radians(-lean*.5),math.radians(-yaw*.5),0)
        set_control(rig,'CTRL_Hand.R',hand_r,(pitch,0,0))
        set_control(rig,'CTRL_Hand.L',hand_l,(0,-32,-2 if 6<=f<=20 else -10))
        set_control(rig,'CTRL_Foot.L',(-.35,foot_l,.16+lift_l))
        set_control(rig,'CTRL_Foot.R',(.35,-.28,.16+lift_r),(heel,0,0))
        for name in ['Root','Pelvis','Thorax','Neck','CTRL_Hand.R','CTRL_Hand.L','CTRL_Foot.R','CTRL_Foot.L']:
            pb=rig.pose.bones[name]
            pb.keyframe_insert('location',frame=f,group=name)
            pb.keyframe_insert('rotation_euler',frame=f,group=name)
    for fc in curves(action):
        for k in fc.keyframe_points:
            k.interpolation='BEZIER'
            k.handle_left_type=k.handle_right_type='AUTO_CLAMPED'
    blocking=action.copy();blocking.name='Estoc_Blocking';blocking.use_fake_user=True
    for fc in curves(blocking):
        for k in fc.keyframe_points:k.interpolation='CONSTANT'
    markers={1:'01 Garde',6:'02 Charge',10:'03 Appui avant',13:'04 Contact',16:'05 Freinage',25:'06 Retour'}
    for marker in list(scene.timeline_markers):scene.timeline_markers.remove(marker)
    for frame,name in markers.items():scene.timeline_markers.new(name,frame=frame)
    scene.frame_start=1;scene.frame_end=25
    scene.use_preview_range=True;scene.frame_preview_start=1;scene.frame_preview_end=25
    scene.render.fps=30
    bpy.data.objects['Thrust_target'].location.y=2.29
    bpy.data.objects['Target_post'].location.y=2.35
    rig['target_point']=json.dumps([.63,2.29,1.62])
    scene['attack_release_frame']=13
    scene['attack_release_seconds']=.4
    prefs=bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type='OPTIX';prefs.refresh_devices()
    for device in prefs.devices:device.use=device.type=='OPTIX'
    scene.cycles.device='GPU'
    bpy.ops.wm.save_userpref()
    # Measure actual evaluated IK, including interpolated frames. This does not approve the art.
    checks=[]
    for frame in [1+i*.25 for i in range(97)]:
        scene.frame_set(int(frame),subframe=frame%1)
        bpy.context.view_layer.update()
        checks.append({'frame':frame,'errors':{n:(rig.pose.bones[n].head-rig.pose.bones['CTRL_'+n].head).length for n in ['Hand.R','Hand.L','Foot.R','Foot.L']}})
    max_error=max(v for x in checks for v in x['errors'].values())
    scene.frame_set(13)
    hand=rig.pose.bones['Hand.R']
    tip=hand.matrix@Vector((0,1.14,0))
    target=Vector(json.loads(rig['target_point']))
    tip_error=(tip-target).length
    report={'blender':bpy.app.version_string,'file':str(OUT/'sentinelle_blocking_v1.blend'),
            'status':'blocking_for_visual_review','actions':[action.name,blocking.name],
            'main_poses':markers,'duration_seconds':.8,'release_seconds':.4,
            'gpu':'OPTIX','max_native_ik_target_error_m':max_error,
            'spear_tip_contact_error_m':tip_error,'samples':checks,
            'technical_passed':max_error<.005 and tip_error<.005,'artistic_approved':False}
    (OUT/'blocking_validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sentinelle_blocking_v1.blend'))
    print(json.dumps({k:v for k,v in report.items() if k!='samples'}))


if __name__=='__main__':author()
