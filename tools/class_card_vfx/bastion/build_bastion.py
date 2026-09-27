"""Original articulated cel ramparts. Run in Blender; preserve every existing scene."""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'art/source/vfx/bastion_vivant'
RENDERS = ROOT / 'artifacts/dev/class_card_vfx/bastion/render'
SCENE = 'Bastion vivant - CEL'
FRAMES, FPS, SIZE = 48, 30, 384
PALETTE = [('Ink', '172938'), ('Bronze shadow', '723923'), ('Bronze', 'c47a30'),
           ('Gold', 'ecb951'), ('Edge', 'fff0bf'), ('Enamel', '254f60'),
           ('Enamel light', '3c7b85'), ('Seal', '30bdac'), ('Seal light', 'bcf4d8')]
PROFILE = [(-.48,.28),(-.56,1.48),(-.56,1.94),(-.30,1.94),(-.30,1.72),
           (-.12,1.72),(-.12,2.02),(.12,2.02),(.12,1.72),(.30,1.72),
           (.30,1.94),(.56,1.94),(.56,1.48),(.48,.28),(0,0)]


def color(value):
    rgb = [int(value[i:i+2], 16)/255 for i in (0,2,4)]
    return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb)+(1,)


def build():
    if bpy.data.scenes.get(SCENE):
        raise RuntimeError('Dedicated Bastion scene already exists; edit explicitly.')
    original = bpy.context.scene
    scene = bpy.data.scenes.new(SCENE)
    scene.render.engine = original.render.engine
    scene.view_settings.view_transform = original.view_settings.view_transform
    scene.view_settings.look = original.view_settings.look
    scene.view_settings.exposure = original.view_settings.exposure
    bpy.context.window.scene = scene
    mats = []
    for name, hex_value in PALETTE:
        mat = bpy.data.materials.new('Bastion_' + name)
        mat.diffuse_color = color(hex_value)
        mat.use_nodes = True
        mat.node_tree.nodes.clear()
        emit = mat.node_tree.nodes.new('ShaderNodeEmission')
        emit.inputs[0].default_value = color(hex_value)
        out = mat.node_tree.nodes.new('ShaderNodeOutputMaterial')
        mat.node_tree.links.new(emit.outputs[0], out.inputs[0])
        mats.append(mat)

    def mesh(name, points, faces, indices, rig, layer):
        data = bpy.data.meshes.new('Bastion ' + name)
        data.from_pydata(points, [], faces)
        data.update()
        obj = bpy.data.objects.new('Bastion ' + name, data)
        scene.collection.objects.link(obj)
        obj.parent = rig
        obj['render_layer'] = layer
        for mat in mats:
            data.materials.append(mat)
        for face, idx in zip(data.polygons, indices):
            face.material_index = idx
        return obj

    rigs = []
    for index, (x, y, angle, layer) in enumerate([(-1.12,-.13,-24,'front'), (0,1.12,0,'back'), (1.12,-.13,24,'front')]):
        rig = bpy.data.objects.new('Bastion - panel %d' % index, None)
        scene.collection.objects.link(rig)
        rig['render_layer'] = layer
        rigs.append(rig)
        n = len(PROFILE)
        points = [(px, -.16, z) for px,z in PROFILE]+[(px,.16,z) for px,z in PROFILE]
        faces = [tuple(range(n)),tuple(reversed(range(n,2*n)))]
        indices = [0,1]
        for j in range(n):
            faces.append((j,(j+1)%n,(j+1)%n+n,j+n))
            indices.append(3 if j in (2,5,6,9) else 2 if j<7 else 1)
        mesh('castellated shell %d'%index, points, faces, indices, rig, layer)
        for name, shrink, depth, shade in [('bronze rim',.96,-.166,3),('enamel',.80,-.175,5)]:
            mesh('%s %d'%(name,index),[(px*shrink,depth,(z-1.01)*shrink+1.01) for px,z in PROFILE],
                 [tuple(range(n))],[shade],rig,layer)
        # A broad blue facet and ivory top bevel define the volume at gameplay scale.
        mesh('blue facet %d'%index,[(0,-.181,.22),(.37,-.181,.43),(.42,-.181,1.45),(0,-.181,1.58)],
             [(0,1,2,3)],[6],rig,layer)
        mesh('lower metal bevel %d'%index,[(-.43,-.19,.33),(0,-.19,.07),(.43,-.19,.33),(.32,-.19,.43),(0,-.19,.23),(-.32,-.19,.43)],
             [tuple(range(6))],[4],rig,layer)
        crest=[(-.24,1.22),(.24,1.22),(.20,.83),(0,.64),(-.20,.83)]
        for name, shrink, depth, shade in [('crest rim',1,-.195,0),('crest gold',.88,-.201,4),('crest teal',.65,-.207,7)]:
            mesh('%s %d'%(name,index),[(px*shrink,depth,(z-.95)*shrink+.95) for px,z in crest],
                 [tuple(range(5))],[shade],rig,layer)
        mesh('crest shine %d'%index,[(0,-.213,1.12),(.12,-.213,1.12),(.095,-.213,.88),(0,-.213,.79)],
             [(0,1,2,3)],[8],rig,layer)
        for px,z in [(-.39,1.47),(.39,1.47),(-.30,.46),(.30,.46)]:
            points=[(px+math.cos(j*math.tau/6)*.055,-.22,z+math.sin(j*math.tau/6)*.055) for j in range(6)]
            mesh('rivet %d'%index,points,[tuple(range(6))],[4],rig,layer)
        # Left, rear, right lock in sequence, then settle and fold into the active sign.
        delay = [0,2,4][index]
        for frame in range(1, FRAMES+1):
            f = frame-delay
            u = min(1,max(0,(f-1)/8))
            ease = 1-(1-u)**3
            settle = .10*math.sin(max(0,f-9)*math.pi/5)*max(0,1-max(0,f-9)/9) if f>9 else 0
            out = min(1,max(0,(frame-25)/19))
            out = out*out*(3-2*out)
            rig.location = (x*(1.42-.42*ease)*(1-.70*out), y*(1-.7*out), -.72*(1-ease)+settle+out*.55)
            rig.rotation_euler = (math.radians(-24*(1-ease)),0,math.radians(angle*(.65+.35*ease)))
            scale = max(.001,(.58+.42*ease)*(1-out))
            rig.scale = (scale,scale,scale)
            for prop in ['location','rotation_euler','scale']:
                rig.keyframe_insert(data_path=prop,frame=frame)
    camera=bpy.data.objects.new('Bastion - orthographic camera',bpy.data.cameras.new('Bastion camera'))
    scene.collection.objects.link(camera)
    target=Vector((0,0,1.0))
    camera.location=target+Vector((3.8,-10,6))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO'
    camera.data.ortho_scale=6.2
    scene.camera=camera
    scene.render.resolution_x=scene.render.resolution_y=SIZE
    scene.render.resolution_percentage=100
    scene.render.fps=FPS
    scene.render.film_transparent=True
    scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGBA'
    scene.frame_start,scene.frame_end=1,FRAMES
    for f,label in [(1,'GRANT'),(9,'LEFT LOCK'),(11,'REAR LOCK'),(13,'RIGHT LOCK'),(25,'TRANSFER'),(45,'BADGE ONLY')]:
        scene.timeline_markers.new(label,frame=f)
    scene.frame_set(17)
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
    bpy.context.view_layer.update()
    pivot=world_to_camera_view(scene,camera,Vector((0,0,0)))
    SOURCE.mkdir(parents=True,exist_ok=True)
    RENDERS.mkdir(parents=True,exist_ok=True)
    meta={'version':1,'scene':SCENE,'blender_version':bpy.app.version_string,'frames':FRAMES,'fps':FPS,'size':SIZE,
          'pivot_pixels':[round(pivot.x*SIZE,4),round((1-pivot.y)*SIZE,4)],'layers':['back','front'],
          'palette_srgb':dict(PALETTE),'view_transform':scene.view_settings.view_transform,'look':scene.view_settings.look,
          'source_script':'tools/class_card_vfx/bastion/build_bastion.py',
          'intent':'Confirmed protection: three rising interlocking plates, open center, transfer to a compact source-scoped badge.',
          'locks_seconds':[8/30,10/30,12/30], 'gameplay_delay':0}
    (SOURCE/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'bastion_vivant.blend'))
    print(json.dumps(meta))


def render():
    scene=bpy.data.scenes[SCENE]
    bpy.context.window.scene=scene
    for layer in ['back','front']:
        directory=RENDERS/layer
        directory.mkdir(parents=True,exist_ok=True)
        for obj in scene.objects:
            if obj.type=='MESH':
                obj.hide_render=obj.get('render_layer')!=layer
        scene.render.filepath=str(directory/'frame_')
        bpy.ops.render.render(animation=True)
    for obj in scene.objects:
        obj.hide_render=False


if __name__=='__main__':
    import sys
    if '--render' in sys.argv:
        render()
    else:
        build()
