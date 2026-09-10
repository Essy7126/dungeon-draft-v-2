"""Dress the validated study with complete rigid armor pieces, retaining its poses."""
import bpy
import bmesh
import sys
import hashlib
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/source/blender/sentinelle_armor_v1'
RIG = bpy.data.objects['Sentinelle_Rig']
SCENE = bpy.context.scene


def action_digest():
    rows = []
    for action in sorted(bpy.data.actions, key=lambda a: a.name):
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        rows.append([action.name, fc.data_path, fc.array_index,
                                     [[list(k.co), list(k.handle_left), list(k.handle_right), k.interpolation] for k in fc.keyframe_points]])
    return hashlib.sha256(json.dumps(rows, sort_keys=True).encode()).hexdigest()


def paint(name, colors, metallic=.12):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*colors[1], 1)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = .76
    noise = nt.nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 4.0
    noise.inputs['Detail'].default_value = 1
    noise.inputs['Roughness'].default_value = .7
    tex = nt.nodes.new('ShaderNodeTexCoord')
    nt.links.new(tex.outputs['Generated'], noise.inputs['Vector'])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.interpolation = 'EASE'
    ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1])
    for i, (position, color) in enumerate(zip((.24, .45, .63, .77), colors)):
        e = ramp.color_ramp.elements[0] if i == 0 else ramp.color_ramp.elements.new(position)
        e.position = position
        e.color = (*color, 1)
    nt.links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], bsdf.inputs['Base Color'])
    return m


def solid(name, color, metal=0):
    return paint(name, [color] * 4, metal)


def attach(ob, bone, material):
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    ARMOR.objects.link(ob)
    if material:
        ob.data.materials.clear()
        ob.data.materials.append(material)
    bpy.context.view_layer.update()
    world = ob.matrix_world.copy()
    ob.parent = RIG
    ob.parent_type = 'BONE'
    ob.parent_bone = bone
    ob.matrix_world = world
    return ob


def line(name, points, radius, material, bone, closed=False):
    data = bpy.data.curves.new(name, 'CURVE')
    data.dimensions = '3D'
    data.bevel_depth = radius
    data.bevel_resolution = 2
    s = data.splines.new('POLY')
    s.points.add(len(points) - 1)
    for p, v in zip(s.points, points):
        p.co = (*v, 1)
    s.use_cyclic_u = closed
    ob = bpy.data.objects.new(name, data)
    ARMOR.objects.link(ob)
    return attach(ob, bone, material)


def ball(name, center, scale, material, bone):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, location=center)
    ob = bpy.context.object
    ob.name = name
    ob.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for p in ob.data.polygons:
        p.use_smooth = True
    return attach(ob, bone, material)


def block(name, center, dimensions, material, bone, bevel=.014):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    ob = bpy.context.object
    ob.name = name
    ob.scale = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = ob.modifiers.new('Forged_edges', 'BEVEL')
    mod.width = bevel
    mod.segments = 2
    ob.modifiers.new('Weighted_normals', 'WEIGHTED_NORMAL')
    return attach(ob, bone, material)


def plate(name, points, material, bone):
    data = bpy.data.meshes.new(name)
    data.from_pydata(points, [], [list(range(len(points)))])
    data.update()
    ob = bpy.data.objects.new(name, data)
    ARMOR.objects.link(ob)
    mod = ob.modifiers.new('Plate_thickness', 'SOLIDIFY')
    mod.thickness = .018
    mod.offset = 0
    return attach(ob, bone, material)


def curved_plate(name, coords, center, radii, offset, material, bone, back=False):
    ob = plate(name, [front(center,radii,x,z,offset,back) for x,z in coords],material,bone)
    # A flat chord would sink into the helmet/chest; subdivide then fit the surface.
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=8,use_grid_fill=True)
    for v in bm.verts:
        v.co = front(center,radii,v.co.x,v.co.z,offset,back)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return ob

def ring(name, center, axis, radius, width, material, bone):
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=8,
                                    major_radius=radius, minor_radius=width, location=center)
    ob = bpy.context.object
    ob.name = name
    ob.rotation_mode = 'QUATERNION'
    ob.rotation_quaternion = Vector(axis).to_track_quat('Z', 'Y')
    for p in ob.data.polygons:
        p.use_smooth = True
    return attach(ob, bone, material)


def front(center, radii, x, z, offset=.009, back=False):
    dx, dz = x - center[0], z - center[2]
    y = radii[1] * math.sqrt(max(.01, 1 - (dx / radii[0]) ** 2 - (dz / radii[2]) ** 2)) + offset
    return (x, center[1] + (-y if back else y), z)


def build():
    global ARMOR
    assert Path(bpy.data.filepath).resolve() == (OUT / 'source_pose.blend').resolve()
    assert not (OUT / 'sentinelle_armor_v1.blend').exists() or '--replace-generated' in sys.argv, 'Existing dressed study preserved'
    before = action_digest()
    ARMOR = bpy.data.collections.new('Armor_details')
    SCENE.collection.children.link(ARMOR)
    RIG.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    bronze = paint('Armor_weathered_bronze', [(.16,.107,.048),(.225,.16,.076),(.28,.205,.106),(.34,.26,.145)], .28)
    ivory = paint('Armor_old_ivory', [(.45,.40,.28),(.58,.53,.39),(.69,.64,.48),(.74,.69,.53)], .06)
    dark = solid('Armor_dark_recess', (.009,.016,.018), .05)
    patina = paint('Armor_patinated_edges', [(.023,.061,.064),(.049,.12,.12),(.09,.19,.18),(.17,.26,.22)], .22)
    gold = solid('Armor_worn_edges', (.51,.37,.17), .35)
    teal = solid('Armor_turquoise_inlay', (.028,.37,.32), .18)
    leather = paint('Armor_grip_leather', [(.023,.019,.013),(.060,.041,.024),(.11,.074,.037),(.15,.10,.053)])
    old_mapping = {'Study_bronze': bronze, 'Study_ivory': ivory, 'Study_joints': dark, 'Study_teal': teal}
    for ob in bpy.data.collections['Sentinelle_Blocking'].objects:
        if ob.type == 'MESH':
            for slot in ob.material_slots:
                if slot.material and slot.material.name.split('.')[0] in old_mapping:
                    slot.material = old_mapping[slot.material.name.split('.')[0]]
    for name in ('Visor', 'Eye', 'Eye.001', 'Shield_boss'):
        ob = bpy.data.objects.get(name)
        if ob:
            ob.hide_render = True
            ob.hide_set(True)
    bpy.data.objects['Shield_face'].data.materials[0] = bronze
    bpy.data.objects['Shield_rim'].data.materials[0] = patina
    bpy.data.objects['Spear_shaft'].data.materials[0] = leather
    bpy.data.objects['Spear_blade'].data.materials[0] = gold
    # A continuous Corinthian faceplate, with a dark T opening and separate eyes.
    hc, hr = (0,0,2.38), (.255,.25,.32)
    hp = lambda x,z,offset=.01: front(hc,hr,x,z,offset)
    for name, coords in [('Eye_slit',[(-.186,2.46),(.186,2.46),(.165,2.386),(-.165,2.386)]),
                         ('Face_opening',[(-.046,2.435),(.046,2.435),(.061,2.155),(-.061,2.155)])]:
        curved_plate(name, coords, hc, hr, .014, dark, 'Head')
    for sign in (-1,1):
        ball('Inlaid_eye',hp(sign*.096,2.421,.026),(.023,.009,.018),teal,'Head')
        cheek = [(sign*.19,2.40),(sign*.205,2.29),(sign*.15,2.165),(sign*.066,2.145),(sign*.063,2.365)]
        curved_plate('Cheek_guard',cheek,hc,hr,.025,bronze,'Head')
        line('Cheek_edge',[hp(x,z,.033) for x,z in cheek],.009,gold,'Head',True)
    line('Nasal_ridge',[hp(0,2.565,.018),hp(0,2.48,.035),hp(0,2.355,.038)],.020,gold,'Head')
    line('Helmet_crown',[(0,-.245*math.sin(t),2.38+.322*math.cos(t)) for t in [i*math.pi/28 for i in range(25)]],.011,gold,'Head')
    # Breast and back plates: engraved edges follow the existing volume exactly.
    for back in (False,True):
        cp = lambda x,z: front((0,0,1.78),(.61,.35,.40),x,z,.010,back)
        coords = [(-.51,1.9),(-.43,1.72),(-.22,1.61),(0,1.585),(.22,1.61),(.43,1.72),(.51,1.9)]
        line('Chest_plate_recess',[cp(x,z) for x,z in coords],.028,dark,'Thorax')
        line('Chest_plate_lip',[cp(x,z+.02) for x,z in coords],.012,bronze,'Thorax')
        coords = [(-.085,1.90),(0,1.986),(.085,1.90),(.062,1.73),(0,1.67),(-.062,1.73)]
        curved_plate('Central_clasp',coords,(0,0,1.78),(.61,.35,.40),.022,bronze,'Thorax',back)
        line('Clasp_edge',[cp(x,z) for x,z in coords],.008,gold,'Thorax',True)
    for z in (1.26,1.365,1.475):
        radial = math.sqrt(1-((z-1.39)/.30)**2)
        pts = [(.435*radial*math.cos(t),.015+.306*radial*math.sin(t),z) for t in [i*math.tau/64 for i in range(64)]]
        line('Abdominal_overlap',pts,.026,dark,'Pelvis',True)
        line('Abdominal_bronze_lip',[(x,y,z+.018) for x,y,z in pts],.014,bronze,'Pelvis',True)
    ring('Waist_central_buckle',(0,.324,1.095),(0,1,0),.063,.017,gold,'Pelvis')
    rest = json.loads(RIG['rest_points'])
    for side,sign in [('R',1),('L',-1)]:
        p = lambda n: Vector(rest[n+'.'+side])
        shoulder = p('shoulder') + Vector((0,0,.07))
        for back in (False,True):
            pts = [shoulder+Vector((.31*.91*math.cos(t),(-1 if back else 1)*.143,.28*.91*math.sin(t))) for t in [i*math.tau/48 for i in range(48)]]
            line('Pauldron_recess.'+side,pts,.025,dark,'Clavicle.'+side,True)
            line('Pauldron_rim.'+side,[v+Vector((0,-.007 if back else .007,0)) for v in pts],.013,gold,'Clavicle.'+side,True)
            for dx,dz in ((-.18,-.14),(.18,-.14),(0,.23)):
                ball('Pauldron_rivet.'+side,front(shoulder,(.31,.34,.28),shoulder.x+dx,shoulder.z+dz,.016,back),(.028,.018,.028),gold,'Clavicle.'+side)
        for upper,lower,bone,rad in [('elbow','wrist','Forearm',.165),('hip','knee','Thigh',.23),('knee','ankle','Shin',.185)]:
            start,end = p(upper),p(lower)
            for t in (.20,.78):
                center=start.lerp(end,t)
                radius=rad*math.sqrt(1-((t-.5)/.58)**2)
                ring('Guard_seam.'+bone+'.'+side,center,end-start,radius+.004,.018,dark,bone+'.'+side)
                ring('Guard_lip.'+bone+'.'+side,center+(end-start).normalized()*.014,end-start,radius+.009,.008,gold,bone+'.'+side)
        for joint,bone,rad in [('elbow','Forearm',.112),('knee','Shin',.118)]:
            center=p(joint)+Vector((sign*.16,0,0))
            ball('Joint_hinge.'+joint+'.'+side,center,(.032,rad,rad),bronze,bone+'.'+side)
            ring('Hinge_rim.'+joint+'.'+side,center+Vector((sign*.026,0,0)),(1,0,0),rad*.70,.012,gold,bone+'.'+side)
        ball('Kneecap.'+side,p('knee')+Vector((0,.14,.025)),(.135,.068,.145),bronze,'Shin.'+side)
        bpy.data.objects['Boot.'+side].data.materials[0] = dark
        for i in range(4):
            block('Toe_plate.'+side,p('ankle')+Vector(((i-1.5)*.074,.278,-.029)),(.069,.14,.208),bronze,'Foot.'+side)
        block('Instep_plate.'+side,p('ankle')+Vector((0,.028,.06)),(.275,.22,.07),bronze,'Foot.'+side)
        line('Boot_upper_trim.'+side,[p('ankle')+Vector(v) for v in [(-.145,-.10,.04),(-.145,.14,.06),(0,.18,.064),(.145,.14,.06),(.145,-.10,.04)]],.012,gold,'Foot.'+side)
        # Fingers close around the spear/shield grip, following the original hand bone.
        for i in range(3):
            ball('Gauntlet_knuckle.'+side,p('wrist')+Vector((sign*.092,.013+i*.043,.022)),(.044,.032,.065),bronze,'Hand.'+side)
    grip = Vector(rest['wrist.L'])
    center = grip+Vector((-.06,.15,0))
    sp = lambda x,z,offset=.012: Vector(front(center,(.5,.09,.61),center.x+x,center.z+z,offset))
    for rad,mat,width,offset in [(.965,dark,.018,.012),(.940,gold,.009,.02)]:
        line('Shield_inner_rim',[sp(.5*rad*math.cos(t),.61*rad*math.sin(t),offset) for t in [i*math.tau/72 for i in range(72)]],width,mat,'Hand.L',True)
    motif = [(-.32,-.35),(-.20,-.25),(-.135,-.05),(.075,.30),(.24,-.22),(.34,-.36)]
    line('Shield_lambda_channel',[sp(x,z) for x,z in motif],.025,dark,'Hand.L')
    line('Shield_lambda_inlay',[sp(x,z,.024) for x,z in motif],.012,teal,'Hand.L')
    for crack in [[(.075,.30),(.025,.39),(.048,.53)],[(-.20,-.25),(-.27,-.12),(-.39,-.075)],[(.24,-.22),(.26,-.035),(.35,.11),(.31,.34)]]:
        line('Shield_hairline',[sp(x,z,.014) for x,z in crack],.005,dark,'Hand.L')
    for t in (.2,1.2,2.1,3.2,4.3,5.2):
        ball('Shield_rivet',sp(.47*math.cos(t),.565*math.sin(t),.028),(.019,.018,.019),gold,'Hand.L')
    # The rear has a rim and real grip support, rather than an invented flat redraw.
    line('Shield_back_rim',[grip+Vector((-.06+.50*math.cos(t),.04,.60*math.sin(t))) for t in [i*math.tau/60 for i in range(60)]],.018,gold,'Hand.L',True)
    for z in (-.19,.19):
        line('Shield_rear_brace',[grip+Vector((x,.007,z)) for x in (-.35,-.1,.22)],.022,leather,'Hand.L')
    line('Shield_grip_loop',[grip+Vector(v) for v in [(-.1,.015,-.20),(-.1,-.105,-.12),(-.1,-.115,.12),(-.1,.015,.20)]],.024,bronze,'Hand.L')
    wrist = Vector(rest['wrist.R'])
    for distance in (-.18,-.12,-.06,0,.06,.12,.65,.73):
        ring('Spear_binding',wrist+Vector((0,distance,0)),(0,1,0),.036,.006,gold if distance>.6 else bronze,'Hand.R')
    RIG.data.pose_position = 'POSE'
    SCENE.frame_set(1)
    SCENE.camera = bpy.data.objects['Camera_E']
    bpy.context.view_layer.update()
    assert action_digest() == before, 'Animation changed during the dressing pass'
    SCENE['study_status'] = 'armor_v1_for_visual_review'
    SCENE['reference_style'] = 'sentinelle_airain: aged bronze, ivory plates, dark joints, turquoise lambda'
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sentinelle_armor_v1.blend'))
    report = {'technical_passed': True, 'animation_sha256_before': before, 'animation_sha256_after': action_digest(),
              'added_objects': len(ARMOR.objects), 'bones': len(RIG.data.bones), 'artistic_approved': False,
              'source': str(OUT/'source_pose.blend'), 'output': bpy.data.filepath,
              'limits': ['Procedural 3D material study, not final painted 2D pieces', 'Spine rig transfer and combat integration not yet performed']}
    (OUT/'build_report.json').write_text(json.dumps(report,indent=2)+'\n')
    groups = {}
    for ob in list(bpy.data.collections['Sentinelle_Blocking'].objects) + list(ARMOR.objects):
        if ob.parent == RIG and ob.parent_type == 'BONE' and not ob.hide_render:
            groups.setdefault(ob.parent_bone, []).append(ob.name)
    (OUT/'armor_groups.json').write_text(json.dumps({'groups':groups,
        'source':'Native objects attached to bones; not exported Spine layers'},indent=2))
    print(json.dumps(report))


if __name__ == '__main__':
    build()
