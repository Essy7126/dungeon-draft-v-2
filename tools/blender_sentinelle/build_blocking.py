"""Build one editable 3D pose study; no final painted assets are generated."""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/source/blender/sentinelle_blocking_v1'
NAME = 'Sentinelle_Blocking'


def material(name, color, metallic=0, roughness=.7):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    return m


def move_to(obj, collection):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


def ellipsoid(name, location, scale, mat, collection, rotation=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, location=location)
    ob = bpy.context.object
    ob.name = name
    ob.scale = scale
    if rotation is not None:
        ob.rotation_mode = 'QUATERNION'
        ob.rotation_quaternion = rotation
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    return move_to(ob, collection)


def segment(name, start, end, radius, mat, collection):
    a, b = Vector(start), Vector(end)
    return ellipsoid(name, (a+b)/2, (radius, radius, (b-a).length*.58), mat,
                     collection, (b-a).to_track_quat('Z', 'Y'))


def cube(name, location, scale, mat, collection, bevel=.06):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    ob = bpy.context.object
    ob.name = name
    ob.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(mat)
    if bevel:
        mod = ob.modifiers.new('Soft_edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        ob.modifiers.new('Weighted_normals', 'WEIGHTED_NORMAL')
    return move_to(ob, collection)


def bone_parent(obj, rig, bone):
    bpy.context.view_layer.update()
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = 'BONE'
    obj.parent_bone = bone
    obj.matrix_world = world
    bpy.context.view_layer.update()


def build():
    if NAME in bpy.data.collections:
        raise RuntimeError('Existing pose study preserved. Edit it instead of rebuilding.')
    scene = bpy.context.scene
    source = bpy.data.collections.get('Source_test2d_preserved') or bpy.data.collections.new('Source_test2d_preserved')
    if source.name not in scene.collection.children: scene.collection.children.link(source)
    for ob in list(scene.objects):
        move_to(ob, source)
    source.hide_render = True
    source.hide_viewport = True
    char = bpy.data.collections.new(NAME)
    stage = bpy.data.collections.new('Review_stage')
    refs = bpy.data.collections.new('Source_references')
    for col in (char, stage, refs):
        scene.collection.children.link(col)

    bronze = material('Study_bronze', (.37, .25, .115), .45)
    ivory = material('Study_ivory', (.69, .64, .49), .15)
    joints = material('Study_joints', (.065, .09, .105), .25)
    teal = material('Study_teal', (.04, .47, .43), .15)
    ground = material('Study_ground', (.075, .094, .108))
    grid = material('Study_grid', (.16, .21, .23))
    gold = material('Target_gold', (.72, .40, .10), .1)

    # Coordinates: Z up, +Y forward, anatomical right +X. The camera defines E/S/W/N.
    points = {
        'hip.R': (.30, -.06, 1.06), 'knee.R': (.35, -.02, .61), 'ankle.R': (.35, -.28, .16),
        'hip.L': (-.30, .06, 1.06), 'knee.L': (-.35, .38, .61), 'ankle.L': (-.35, .40, .16),
        'shoulder.R': (.58, 0, 1.98), 'elbow.R': (.87, -.04, 1.55), 'wrist.R': (.63, .42, 1.57),
        'shoulder.L': (-.58, 0, 1.98), 'elbow.L': (-.84, .03, 1.58), 'wrist.L': (-.68, .48, 1.62),
    }
    arm = bpy.data.armatures.new('Sentinelle_pose_rig')
    rig = bpy.data.objects.new('Sentinelle_Rig', arm)
    char.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    rig.show_in_front = True
    rig.display_type = 'WIRE'
    bpy.ops.object.mode_set(mode='EDIT')

    def bone(name, head, tail, parent=None, deform=True):
        b = arm.edit_bones.new(name)
        b.head, b.tail = head, tail
        if parent:
            b.parent = arm.edit_bones[parent]
        b.use_deform = deform
        return b

    bone('Root', (0,0,0), (0,0,.3), deform=False)
    bone('Pelvis', (0,0,1.06), (0,0,1.35), 'Root')
    bone('Thorax', (0,0,1.35), (0,0,1.99), 'Pelvis')
    bone('Neck', (0,0,1.99), (0,0,2.21), 'Thorax')
    bone('Head', (0,0,2.21), (0,0,2.64), 'Neck')
    for side in ('R', 'L'):
        p = lambda part: Vector(points[part+'.'+side])
        bone('Clavicle.'+side, (0,0,1.95), p('shoulder'), 'Thorax')
        bone('UpperArm.'+side, p('shoulder'), p('elbow'), 'Clavicle.'+side)
        bone('Forearm.'+side, p('elbow'), p('wrist'), 'UpperArm.'+side)
        bone('Hand.'+side, p('wrist'), p('wrist')+Vector((0,.18,0)), 'Forearm.'+side)
        bone('Thigh.'+side, p('hip'), p('knee'), 'Pelvis')
        bone('Shin.'+side, p('knee'), p('ankle'), 'Thigh.'+side)
        bone('Foot.'+side, p('ankle'), p('ankle')+Vector((0,.24,-.065)), 'Shin.'+side)
        bone('CTRL_Hand.'+side, p('wrist'), p('wrist')+Vector((0,.18,0)), deform=False)
        bone('CTRL_Foot.'+side, p('ankle'), p('ankle')+Vector((0,.24,-.065)), deform=False)
        for joint, name in [('elbow','Elbow'), ('knee','Knee')]:
            x = p(joint)
            if joint == 'elbow':
                x += Vector((.65 if side=='R' else -.65, -.25, .03))
            else:
                x += Vector((0, 1, .1))
            bone('POLE_'+name+'.'+side, x, x+Vector((0,0,.12)), deform=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    for pb in rig.pose.bones:
        pb.rotation_mode = 'XYZ'
    control_collection = arm.collections.new('Controls')
    structure_collection = arm.collections.new('Body')
    for b in arm.bones:
        (control_collection if b.name.startswith(('CTRL_', 'POLE_')) or b.name=='Root' else structure_collection).assign(b)
        b.color.palette = 'THEME04' if b.name.startswith('CTRL_') else ('THEME03' if b.name.startswith('POLE_') else 'DEFAULT')

    constraints = []
    for side in ('R', 'L'):
        for lower, ctrl, pole, joint in [('Forearm','Hand','Elbow','elbow'), ('Shin','Foot','Knee','knee')]:
            pb = rig.pose.bones[lower+'.'+side]
            c = pb.constraints.new('IK')
            c.name = 'Plant_'+ctrl+'.'+side
            c.target, c.subtarget = rig, 'CTRL_'+ctrl+'.'+side
            c.pole_target, c.pole_subtarget = rig, 'POLE_'+pole+'.'+side
            c.chain_count = 2
            c.use_stretch = False
            rig.pose.bones[pb.parent.name].ik_stretch = 0
            pb.ik_stretch = 0
            constraints.append((c, pb, Vector(points[joint+'.'+side])))
            orient = rig.pose.bones[ctrl+'.'+side].constraints.new('COPY_ROTATION')
            orient.target, orient.subtarget = rig, 'CTRL_'+ctrl+'.'+side
            orient.owner_space = orient.target_space = 'POSE'
    # Calibrate each native IK pole against the deliberately constructed rest bend.
    for constraint, pb, expected in constraints:
        best = (1e9, 0)
        for degrees in range(-180, 180, 4):
            constraint.pole_angle = math.radians(degrees)
            bpy.context.view_layer.update()
            error = (pb.head-expected).length
            if error < best[0]: best = (error, degrees)
        constraint.pole_angle = math.radians(best[1])
    bpy.context.view_layer.update()

    def part(ob, bone_name):
        bone_parent(ob, rig, bone_name)
        return ob
    part(ellipsoid('Pelvis_plate',(0,0,1.07),(.43,.31,.25),bronze,char),'Pelvis')
    part(ellipsoid('Abdomen',(0,.015,1.39),(.43,.30,.30),ivory,char),'Pelvis')
    part(ellipsoid('Chest_plate',(0,0,1.78),(.61,.35,.40),ivory,char),'Thorax')
    part(ellipsoid('Chest_collar',(0,0,2.02),(.36,.27,.12),bronze,char),'Thorax')
    part(ellipsoid('Neck_joint',(0,0,2.14),(.16,.16,.16),joints,char),'Neck')
    part(ellipsoid('Helmet',(0,0,2.38),(.255,.25,.32),bronze,char),'Head')
    part(cube('Visor',(0,.239,2.39),(.31,.05,.115),joints,char,.018),'Head')
    for x in (-.075,.075):
        part(cube('Eye', (x,.272,2.40),(.044,.015,.031),teal,char,.008),'Head')
    for side in ('R', 'L'):
        p = lambda item: Vector(points[item+'.'+side])
        part(ellipsoid('Shoulder_joint.'+side,p('shoulder'),(.22,.22,.22),joints,char),'Clavicle.'+side)
        part(ellipsoid('Pauldron.'+side,p('shoulder')+Vector((0,0,.07)),(.31,.34,.28),bronze,char),'Clavicle.'+side)
        for top, bottom, label, rad, mat in [('shoulder','elbow','UpperArm',.19,ivory),('elbow','wrist','Forearm',.165,bronze),('hip','knee','Thigh',.23,bronze),('knee','ankle','Shin',.185,ivory)]:
            part(segment(label+'_plate.'+side,p(top),p(bottom),rad,mat,char),label+'.'+side)
        for joint, bone_name, rad in [('elbow','Forearm',.16), ('knee','Shin',.17), ('wrist','Hand',.14)]:
            part(ellipsoid(joint+'.'+side,p(joint),(rad,rad,rad),joints,char),bone_name+'.'+side)
        part(cube('Boot.'+side,p('ankle')+Vector((0,.075,-.06)),(.32,.49,.21),bronze,char,.065),'Foot.'+side)

    wrist = Vector(points['wrist.R'])
    part(segment('Spear_shaft',wrist+Vector((0,-.43,0)),wrist+Vector((0,.89,0)),.035,bronze,char),'Hand.R')
    # A faceted short leaf blade, all of it rigidly attached to the spear hand.
    blade = bpy.data.meshes.new('Spear_blade_mesh')
    verts = [(-.13,.86,0),(0,1.14,0),(.13,.86,0),(0,.76,0),(0,.87,.06),(0,.87,-.06)]
    blade.from_pydata([wrist+Vector(v) for v in verts],[],[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(1,0,5),(2,1,5),(3,2,5),(0,3,5)])
    ob=bpy.data.objects.new('Spear_blade',blade); char.objects.link(ob); ob.data.materials.append(ivory); part(ob,'Hand.R')
    grip=Vector(points['wrist.L'])
    part(ellipsoid('Shield_rim',grip+Vector((-.06,.11,0)),(.56,.11,.68),bronze,char),'Hand.L')
    part(ellipsoid('Shield_face',grip+Vector((-.06,.15,0)),(.50,.09,.61),ivory,char),'Hand.L')
    part(ellipsoid('Shield_boss',grip+Vector((-.06,.225,0)),(.13,.055,.13),bronze,char),'Hand.L')

    # Stage supplies a fixed ground and a real target for the thrust.
    cube('Ground',(0,.6,-.045),(7,7,.06),ground,stage,.02)
    for index in range(-3,5):
        cube('Grid_X',(0,index*.5,-.011),(5,.012,.006),grid,stage,0)
        cube('Grid_Y',(index*.5,.6,-.01),(.012,5,.006),grid,stage,0)
    target=Vector((.63,2.18,1.62))
    bpy.ops.mesh.primitive_torus_add(major_radius=.23,minor_radius=.013,major_segments=40,minor_segments=8,location=target,rotation=(math.pi/2,0,0))
    ob=bpy.context.object;ob.name='Thrust_target';ob.data.materials.append(gold);move_to(ob,stage)
    cube('Target_post',(.63,2.24,.75),(.025,.025,1.5),gold,stage,.005)
    cube('Forward_axis',(0,1.2,.001),(.025,2.3,.008),teal,stage,0)

    # sin(elevation)=0.5 gives the desired 2:1 projected ground axes at 45-degree azimuth.
    cameras={}
    look=Vector((0,.4,1.20)); horizontal=7
    for d,(sx,sy) in {'E':(1,1),'S':(-1,1),'W':(-1,-1),'N':(1,-1)}.items():
        data=bpy.data.cameras.new('Camera_'+d);cam=bpy.data.objects.new('Camera_'+d,data);stage.objects.link(cam)
        offset=Vector((sx*horizontal,sy*horizontal,math.sqrt(2)*horizontal*math.tan(math.radians(30))))
        cam.location=look+offset;cam.rotation_euler=(-offset).to_track_quat('-Z','Y').to_euler()
        data.type='ORTHO';data.ortho_scale=4.25;data.lens=50
        cameras[d]=cam
    scene.camera=cameras['E']
    for name, loc, power, size in [('Key',(3,4,7),850,5),('Fill',(-4,2,4),500,4),('Rim',(0,-4,5),900,3)]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
        ob=bpy.data.objects.new(name,data);stage.objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector((0,0,1.4))-ob.location).to_track_quat('-Z','Y').to_euler()
    scene.world.color=(.16,.16,.16)
    scene.render.engine='CYCLES'
    scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1000;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
    scene.render.fps=30;scene.frame_start=1;scene.frame_end=31
    scene.view_settings.view_transform='AgX'
    scene['study_status']='blocking_for_visual_review_not_approved'
    scene['source_file']='C:/Blender_AI_Test/input/test2d.blend'
    scene['forward_axis']='+Y';scene['camera_elevation_degrees']=30
    rig['rest_points']=json.dumps(points)
    rig['target_point']=json.dumps(list(target))
    # Original concepts remain accessible as image empties, excluded from final renders.
    for index,d in enumerate('ESWN'):
        path=ROOT/f'art/source/characters/catabase_monsters/sentinelle_airain/base_frame_{d}.png'
        ob=bpy.data.objects.new('Reference_'+d,None);refs.objects.link(ob);ob.empty_display_type='IMAGE';ob.data=bpy.data.images.load(str(path),check_existing=True)
        ob.empty_display_size=2.8;ob.location=(-5-index*3,0,1.4);ob.rotation_euler=(math.pi/2,0,0);ob.hide_render=True
    refs.hide_viewport=True
    for ob in bpy.context.selected_objects: ob.select_set(False)
    rig.select_set(True);bpy.context.view_layer.objects.active=rig
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                space=area.spaces.active;space.region_3d.view_perspective='CAMERA';space.overlay.show_overlays=False;space.shading.type='MATERIAL'
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sentinelle_blocking_v1.blend'))
    print(json.dumps({'rig':rig.name,'bones':len(arm.bones),'native_ik':len(constraints),'cameras':list(cameras),'file':bpy.data.filepath}))


if __name__=='__main__':
    build()
