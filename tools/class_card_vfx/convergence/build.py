"""Convergence J: original faceted cel petals, directional blades and contact.

Render orthographic drawings; Godot projects knot/blades through the actual
grid basis. No baked isometric angle, bloom or full-screen wash.
"""
import bpy
import math
import json
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'art/source/vfx/convergence'
RENDERS = ROOT / 'artifacts/dev/class_card_vfx/convergence/render'
PALETTE = dict(ink='29283f', shadow='403165', violet='7657b5', mid='9867d4',
               lilac='c8a6eb', rim='e1c8ff', ivory='fff0cc', warm='ffcd88')
MATS = {}
for name, value in PALETTE.items():
    rgb = [int(value[i:i+2], 16)/255 for i in (0, 2, 4)]
    rgba = tuple(v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
    material = bpy.data.materials.new('Convergence ' + name)
    material.diffuse_color = rgba
    material.use_nodes = True
    material.node_tree.nodes.clear()
    emission = material.node_tree.nodes.new('ShaderNodeEmission')
    emission.inputs[0].default_value = rgba
    output = material.node_tree.nodes.new('ShaderNodeOutputMaterial')
    material.node_tree.links.new(emission.outputs[0], output.inputs[0])
    MATS[name] = material


def scene(name, frames, scale):
    s = bpy.data.scenes.new('Convergence CEL - ' + name)
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


def petal(s, f, angle, radius, length, width, curl):
    # Asymmetric folded lance with a curved belly; clear dark underside.
    outline = [(0, 0), (.23, -.28), (.53, -.33), (.81, -.20), (1, .04),
               (.79, .29), (.49, .38), (.18, .22)]
    def tr(p):
        u, v = p
        x = radius + u*length
        y = v*width + curl*math.sin(u*math.pi)
        return (x*math.cos(angle)-y*math.sin(angle), x*math.sin(angle)+y*math.cos(angle))
    poly(s, 'folded petal silhouette', [tr(p) for p in outline], 'ink', f, .04)
    ridge = (.48, .07)
    colors = ['shadow', 'violet', 'mid', 'lilac', 'rim', 'violet', 'shadow', 'shadow']
    inset = [(.48+(u-.48)*.94, v*.90) for u, v in outline]
    for j in range(8):
        poly(s, 'solid petal facet', [tr(inset[j]), tr(inset[(j+1)%8]), tr(ridge)], colors[j], f, .02)
    poly(s, 'ivory folded edge', [tr((.06, .01)), tr((.47, .10)), tr((.96, .05)),
                                 tr((.55, .17)), tr((.28, .14))], 'ivory', f, -.015)


knot = scene('knot', 8, 3.8)
for f in range(1, 9):
    t = (f-1)/7
    ease = t*t*(3-2*t)
    radius = .65*(1-ease)+.025
    for j in range(4):
        petal(knot, f, j*math.tau/4+.38*(1-ease), radius,
              1.05-.25*ease, .70-.05*ease, .20*(1-ease))
    d = .09+.045*ease
    poly(knot, 'compressed ivory lozenge', [(0,d),(d,0),(0,-d),(-d,0)], 'ivory', f, -.03)

blade = scene('blade', 12, 3.4)
for f in range(1, 13):
    # Canvas x -1.35..1.35 maps centre-to-adjacent-cell. Avoid area halo.
    t = (f-1)/11
    reach = [ .28, .66, 1, 1, 1, 1, .95, .88, .78, .68, .59, .52 ][f-1]
    retract = max(0, (f-5)/7)
    thick = .40*(1-retract*.92)
    tip = -1.35 + 2.7*reach
    base = -1.35 + retract*1.75
    ridge = base+(tip-base)*.58
    outline = [(base,0),(base+(tip-base)*.32,-thick*.56),(ridge,-thick),
               (tip,0),(ridge,thick*.69),(base+(tip-base)*.20,thick*.40)]
    poly(blade, 'opening lance silhouette', outline, 'ink', f, .04)
    poly(blade, 'violet lance plane', [(base+.025,0),(ridge,-thick*.84),(tip-.025,0),
                                      (ridge,thick*.56)], 'violet', f, .02)
    poly(blade, 'lilac cutting facet', [(base,0),(ridge,-thick*.81),(tip,0),(ridge,-thick*.15)],
         'lilac', f, .01)
    poly(blade, 'ivory edge', [(base,0),(ridge,-thick*.09),(tip,0),(ridge,thick*.035)],
         'ivory', f, -.02)
    if f >= 5:
        for j in range(2):
            x = .52+j*.29+retract*.20
            z = (-1 if j else 1)*(.17+retract*.20)
            w = .075*(1-retract*.75)
            poly(blade, 'separating lilac chip', [(x-w,z),(x+.10,z+w),(x+w,z-.02),(x-.07,z-w)],
                 'rim' if j else 'mid', f, -.01)

contact = scene('contact', 8, 3.6)
for f in range(1, 9):
    t = (f-1)/7
    growth = [ .48, 1, .88, .64, .39, .20, .09, .035 ][f-1]
    for color, size, depth in [('violet', 1.10, .02), ('warm', .94, .0), ('ivory', .78, -.03)]:
        pts = []
        for j in range(16):
            a = j*math.tau/16+.11
            r = ((1.12 if j%4==0 else .82) if j%2==0 else .19)*growth*size
            pts.append((math.cos(a)*r, math.sin(a)*r))
        poly(contact, 'local contact star', pts, color, f, depth)
    for j in range(5):
        a = j*math.tau/5+.22
        r = .38+t*.85
        w = .09*(1-t*.90)
        x, z = math.cos(a)*r, math.sin(a)*r
        poly(contact, 'contact fragments', [(x-w,z),(x,z+w*1.8),(x+w,z),(x,z-w)],
             'lilac' if j%2 else 'ivory', f, -.04)

trail = scene('trail', 6, 3.4)
for f in range(1, 7):
    t = (f-1)/5
    for j in range(3):
        z = (j-1)*.16
        base = -1.38+t*1.7+j*.09
        tip = 1.32-j*.12
        w = (.06 if j!=1 else .09)*(1-t*.75)
        poly(trail, 'one-step pull streak', [(base,z),(tip-.22,z-w),(tip,z),
                                            (tip-.20,z+w)], 'ivory' if j==1 else 'lilac', f, -.01*j)

SCENES = [knot, blade, contact, trail]
SOURCE.mkdir(parents=True, exist_ok=True)
(SOURCE/'.gdignore').touch()
manifest = dict(version=1, blender=bpy.app.version_string, palette_srgb=PALETTE,
                approval='docs/design/vfx_avant_production_lot3_2026-09-27/j_convergence.png',
                source_script='tools/class_card_vfx/convergence/build.py', assets={})
for s in SCENES:
    name = s.name.removeprefix('Convergence CEL - ')
    s.frame_set(1)
    manifest['assets'][name] = dict(size=384, frames=s.frame_end, fps=30,
                                    pivot=[192,192], scene=s.name)
bpy.context.window.scene = knot
knot.frame_set(8)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'convergence.blend'))
(SOURCE/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
if '--render' in sys.argv:
    for s in SCENES:
        bpy.context.window.scene = s
        d = RENDERS/s.name.removeprefix('Convergence CEL - ')
        d.mkdir(parents=True, exist_ok=True)
        s.render.filepath = str(d/'frame_')
        bpy.ops.render.render(animation=True)
print('CONVERGENCE_CEL_BUILD_COMPLETE')
