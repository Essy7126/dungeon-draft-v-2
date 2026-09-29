"""Approved F: two bronze crescent pieces, a quiet readiness token and a cel backhand."""
import bpy
import math
import json
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'art/source/vfx/contre'
RENDERS = ROOT / 'artifacts/dev/class_card_vfx/contre/render'
PALETTE = dict(ink='3a2528', shadow='674139', bronze='a36237', copper='ca8542',
               honey='efa84f', light='ffd891', ivory='fff4d1', ochre='df9135')
MATS = {}
for name, value in PALETTE.items():
    rgb = [int(value[i:i+2], 16)/255 for i in (0, 2, 4)]
    rgba = tuple(v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
    material = bpy.data.materials.new('Contre ' + name)
    material.diffuse_color = rgba
    material.use_nodes = True
    material.node_tree.nodes.clear()
    emission = material.node_tree.nodes.new('ShaderNodeEmission')
    emission.inputs[0].default_value = rgba
    output = material.node_tree.nodes.new('ShaderNodeOutputMaterial')
    material.node_tree.links.new(emission.outputs[0], output.inputs[0])
    MATS[name] = material


def scene(name, frames, scale):
    s = bpy.data.scenes.new('Contre CEL - ' + name)
    bpy.context.window.scene = s
    engines = [e.identifier for e in s.render.bl_rna.properties['engine'].enum_items]
    s.render.engine = next(e for e in engines if e.startswith('BLENDER_EEVEE'))
    s.view_settings.view_transform = 'Standard'
    s.render.image_settings.file_format = 'PNG'
    s.render.image_settings.color_mode = 'RGBA'
    s.render.resolution_x = s.render.resolution_y = 384
    s.render.resolution_percentage = 100
    s.render.film_transparent = True
    s.render.fps = 30
    s.render.threads_mode = 'FIXED'
    s.render.threads = 6
    s.frame_start, s.frame_end = 1, frames
    camera = bpy.data.objects.new(name+' camera', bpy.data.cameras.new(name+' camera'))
    s.collection.objects.link(camera)
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = scale
    camera.location = (0, -10, 0)
    camera.rotation_euler = Vector((0, 10, 0)).to_track_quat('-Z', 'Y').to_euler()
    s.camera = camera
    return s


def poly(s, name, points, color, frame, depth=0):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([(x, depth, z) for x, z in points], [], [tuple(range(len(points)))])
    mesh.update()
    ob = bpy.data.objects.new(name, mesh)
    s.collection.objects.link(ob)
    mesh.materials.append(MATS[color])
    for f, hidden in [(1, True), (frame, False), (frame+1, True)]:
        ob.hide_render = hidden
        ob.hide_viewport = hidden
        ob.keyframe_insert(data_path='hide_render', frame=f)
        ob.keyframe_insert(data_path='hide_viewport', frame=f)


def crescent(s, f, start, end, offset=(0, 0), scale=1, turn=0):
    def tr(a, radius):
        a += turn
        return (offset[0]+math.cos(a)*radius*scale, offset[1]+math.sin(a)*radius*scale)
    angles = [math.radians(start+(end-start)*j/15) for j in range(16)]
    outer, inner, ridge = [], [], []
    for a in angles:
        weight = max(.06, math.sin((a-math.radians(54))/math.radians(252)*math.pi))
        outer.append(tr(a, .92))
        inner.append(tr(a, .92-.39*weight))
        ridge.append(tr(a, .92-.11*weight))
    poly(s, 'ink cut crescent', outer+inner[::-1], 'ink', f, .04)
    for j in range(15):
        poly(s, 'bronze solid facet', [outer[j],outer[j+1],ridge[j+1],ridge[j]],
             'honey' if j%5==0 else 'copper', f, .02)
        poly(s, 'bronze inward bevel', [ridge[j],ridge[j+1],inner[j+1],inner[j]],
             'bronze' if j%4 else 'shadow', f, .01)
    # Sparse ivory edge, never a bloom halo.
    for j in range(2, 8):
        a, b = angles[j], angles[j+1]
        poly(s, 'ivory sharp rim', [tr(a,.916),tr(b,.916),tr(b,.889),tr(a,.889)],
             'ivory', f, -.01)


arm = scene('arm', 14, 3.4)
for f in range(1, 15):
    settle = min(1, (f-1)/5)
    travel = (1-settle)**2
    shrink = 1 if f <= 8 else max(.10, 1-(f-8)/6*.90)
    crescent(arm, f, 54, 179, (.05*travel,.50*travel), shrink, -.24*travel)
    crescent(arm, f, 181, 306, (-.08*travel,-.5*travel), shrink, .24*travel)
    if 5 <= f <= 9:
        k = [ .10,.20,.12,.055,.025 ][f-5]
        x = -.70*shrink
        poly(arm, 'join ivory snap', [(x-k*1.4,0),(x-k*.17,k*.2),(x,k),(x+k*.16,k*.15),
             (x+k,0),(x+k*.15,-k*.17),(x,-k),(x-k*.14,-k*.2)], 'ivory', f, -.06)

token = scene('token', 1, 2.6)
poly(token,'cut bronze readiness token',[(-.68,.64),(.66,.03),(-.40,-.69),(-.29,-.05)],'ink',1,.04)
poly(token,'gold folded tip',[(-.58,.54),(.54,.025),(-.25,-.02)],'honey',1,.02)
poly(token,'bronze folded base',[(-.25,-.02),(.54,.025),(-.38,-.57)],'bronze',1,.01)
poly(token,'ivory token lip',[(-.56,.53),(.54,.025),(.27,.17)],'ivory',1,-.02)

slash = scene('slash', 9, 3.4)
for f in range(1,10):
    t=(f-1)/8
    reach=[.20,.58,1,1,1,1,1,1,1][f-1]
    tail=max(0,(f-3)/6)
    def ribbon(top,bottom,color,depth):
        a=[];b=[]
        for j in range(19):
            u=tail*.88+(reach-tail*.88)*j/18
            x=-1.35+2.7*u
            z=.52*math.sin(u*math.pi)-.15
            w=math.sin(j/18*math.pi)**.8*(1-tail*.82)
            a.append((x,z+top*w));b.append((x,z+bottom*w))
        poly(slash,'backhand '+color,a+b[::-1],color,f,depth)
    ribbon(.18,-.24,'shadow',.04)
    ribbon(.17,-.18,'honey',.02)
    ribbon(.16,-.065,'ivory',-.02)
    ribbon(-.10,-.20,'copper',-.03)
    if f <= 5:
        crescent(slash,f,74,286,(-1.05,-.07),.34*(1-.10*f),-.60+t)
    for j in range(2):
        x=.4+t*.76-j*.3;z=-.27-j*.16;w=.12*(1-t*.85)
        poly(slash,'short bronze fragment',[(x-w,z),(x+.16,z+w*.4),(x+w,z-.06),(x-w*.7,z-.04)],
             'ivory' if j==0 else 'honey',f,-.05)

contact=scene('contact',8,3.4)
for f in range(1,9):
    t=(f-1)/7
    growth=[.43,1,.86,.59,.34,.16,.07,.02][f-1]
    for color,size,depth in [('shadow',1.09,.03),('ochre',1,.01),('ivory',.79,-.02)]:
        pts=[]
        for j in range(14):
            a=j*math.tau/14+.13
            radius=(1 if j%2==0 else .20)*growth*size
            pts.append((math.cos(a)*radius,math.sin(a)*radius*(.8 if j%3 else 1.15)))
        poly(contact,'local ivory contact',pts,color,f,depth)
    for j in range(4):
        a=.3+j*math.tau/4;r=.35+t*.82;w=.10*(1-t*.86)
        x,z=math.cos(a)*r,math.sin(a)*r
        poly(contact,'fading honey splinter',[(x-w,z),(x,z+w*1.8),(x+w,z),(x,z-w)],
             'ivory' if j%2 else 'honey',f,-.04)

SCENES=[arm,token,slash,contact]
SOURCE.mkdir(parents=True,exist_ok=True)
(SOURCE/'.gdignore').touch()
manifest=dict(version=1,blender=bpy.app.version_string,palette_srgb=PALETTE,
 approval='docs/design/vfx_avant_production_lot2_2026-09-27/f_contre_prepare.png',
 source_script='tools/class_card_vfx/contre/build.py',assets={})
for s in SCENES:
    name=s.name.removeprefix('Contre CEL - ');s.frame_set(1)
    manifest['assets'][name]=dict(size=384,frames=s.frame_end,fps=30,pivot=[192,192],scene=s.name)
bpy.context.window.scene=arm;arm.frame_set(6)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'contre.blend'))
(SOURCE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
if '--render' in sys.argv:
    for s in SCENES:
        bpy.context.window.scene=s;d=RENDERS/s.name.removeprefix('Contre CEL - ')
        d.mkdir(parents=True,exist_ok=True);s.render.filepath=str(d/'frame_')
        bpy.ops.render.render(animation=True)
print('CONTRE_CEL_BUILD_COMPLETE')

