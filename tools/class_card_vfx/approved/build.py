"""Original cel meshes from the four explicitly approved perspective drawings.

Run in background Blender with --factory-startup --python this_file -- --render.
Each scene is independent; no existing scene or accepted source is removed.
"""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'art/source/vfx/approved_spells'
RENDERS = ROOT / 'artifacts/dev/class_card_vfx/approved/render'
PALETTE = {'ink':'302932', 'bronze_dark':'563d2a', 'bronze':'a56d32',
           'gold':'e5ae59', 'ivory':'fff1cf', 'plum':'664761', 'obsidian':'342b41',
           'violet':'8d6a8b', 'ice_dark':'344969', 'ice':'58bce7',
           'ice_light':'a3eaff', 'porcelain':'eefbff', 'jade':'379a81', 'shaft':'203e38'}


def rgba(hex_value):
    values = [int(hex_value[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in values)+(1,)


def smooth(a,b,t):
    u = max(0,min(1,(t-a)/(b-a)))
    return u*u*(3-2*u)


def create_scene(name, size, scale, target_z, frames):
    scene = bpy.data.scenes.new('Approved CEL - '+name)
    bpy.context.window.scene = scene
    scene.render.engine = bpy.data.scenes[0].render.engine
    # These identifiers are checked against this Blender build before assignment.
    for prop, value in [('file_format','PNG'),('color_mode','RGBA')]:
        settings = scene.render.image_settings
        assert value in [i.identifier for i in settings.bl_rna.properties[prop].enum_items]
        setattr(settings,prop,value)
    try:
        scene.view_settings.view_transform = 'Standard'
    except TypeError:
        pass
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.fps = 30
    scene.render.threads_mode = 'FIXED' if 'FIXED' in [i.identifier for i in scene.render.bl_rna.properties['threads_mode'].enum_items] else scene.render.threads_mode
    scene.render.threads = 6
    scene.frame_start, scene.frame_end = 1, frames
    camera = bpy.data.objects.new(name+' camera',bpy.data.cameras.new(name+' camera'))
    scene.collection.objects.link(camera)
    assert 'ORTHO' in [i.identifier for i in camera.data.bl_rna.properties['type'].enum_items]
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = scale
    aim = Vector((0,0,target_z))
    camera.location = aim+Vector((3.8,-10,6))
    camera.rotation_euler = (aim-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.camera = camera
    return scene


def mesh(scene,name,points,faces,shades,parent=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(points,[],faces)
    data.update()
    obj = bpy.data.objects.new(name,data)
    scene.collection.objects.link(obj)
    obj.parent = parent
    for mat in MATS.values():
        data.materials.append(mat)
    names = list(MATS)
    for face, shade in zip(data.polygons,shades):
        face.material_index = names.index(shade)
    return obj


def slab(scene,name,profile,depth,front='bronze',side='bronze_dark',parent=None):
    n=len(profile)
    points=[(x,-depth/2,z) for x,z in profile]+[(x,depth/2,z) for x,z in profile]
    faces=[tuple(range(n)),tuple(reversed(range(n,2*n)))]
    shades=[front,side]
    for j in range(n):
        faces.append((j,(j+1)%n,(j+1)%n+n,j+n))
        shades.append('gold' if front=='bronze' and j%3==0 else side)
    return mesh(scene,name,points,faces,shades,parent)


def ring(scene,name,outer,inner,depth,parent=None):
    n=len(outer)
    pts=[(x,y,z) for y in [-depth/2,depth/2] for contour in [outer,inner] for x,z in contour]
    faces=[]; shades=[]
    for j in range(n):
        k=(j+1)%n
        faces.extend([(j,k,n+k,n+j),(j,2*n+j,2*n+k,k),(n+j,n+k,3*n+k,3*n+j),
                      (2*n+j,3*n+j,3*n+k,2*n+k)])
        shades.extend(['gold' if j<3 else 'bronze','bronze_dark','ink','bronze'])
    return mesh(scene,name,pts,faces,shades,parent)


def rig(scene,name):
    obj=bpy.data.objects.new(name,None)
    scene.collection.objects.link(obj)
    return obj


def key(obj,frame):
    for prop in ['location','rotation_euler','scale']:
        obj.keyframe_insert(data_path=prop,frame=frame)


def build_hook():
    scene=create_scene('hook',256,2.7,0,1)
    outer=[(-.35,-.65),(-.68,-.35),(-.72,.30),(-.40,.64),(.34,.64),(.63,.36)]
    inner=[(.31,.24),(.12,.34),(-.20,.34),(-.38,.12),(-.37,-.19),(-.20,-.34),(.28,-.34),(.37,-.62)]
    slab(scene,'Tartare open U shackle',outer+inner,.29)
    slab(scene,'Shackle socket',[(-.84,-.16),(-.48,-.16),(-.48,.17),(-.84,.17)],.43)
    mesh(scene,'Shackle bright bevel',[(x,-.151,z) for x,z in [(-.67,.31),(-.39,.60),(.32,.60),(.46,.45),(-.30,.46),(-.53,.22)]],
         [tuple(range(6))],['ivory'])
    return scene


def build_link(edge=False):
    scene=create_scene('link_edge' if edge else 'link',192,2.3,0,1)
    outline=[(-.67,-.19),(-.43,-.34),(.46,-.34),(.68,-.15),(.68,.17),(.44,.34),(-.44,.34),(-.67,.15)]
    inset=[(x*.70,z*.47) for x,z in outline]
    obj=ring(scene,'Rectangular bronze link',outline,inset,.20)
    if edge:
        obj.rotation_euler.x=math.radians(64)
    return scene


def build_arrow():
    scene=create_scene('arrow',256,2.8,1.0,1)
    slab(scene,'Dark jade shaft',[(-.045,.32),(.045,.32),(.045,2.08),(-.045,2.08)],.10,'shaft','ink')
    pts=[(0,0,0),(-.29,-.02,.63),(-.07,-.12,.52),(.29,-.02,.63),(.07,.12,.52),(0,-.16,.32),(0,.14,.32)]
    mesh(scene,'Bronze broadhead',pts,[(0,1,5),(1,2,5),(0,5,3),(3,5,2),(0,3,6),(0,6,1)],
         ['gold','bronze','ivory','bronze_dark','bronze','bronze_dark'])
    for sign in [-1,1]:
        slab(scene,'Jade fletching',[(sign*.03,1.36),(sign*.28,1.57),(sign*.31,2.04),(sign*.04,1.80)],.05,'jade','shaft')
    return scene


def build_ice():
    scene=create_scene('ice',256,3.0,.35,24)
    petals=[]
    for i,angle in enumerate([25,119,210,300]):
        root=rig(scene,'Ice petal %d'%i)
        root.rotation_euler.z=math.radians(angle)
        pts=[(0,0,0),(-.26,.35,.20),(0,.55,.50),(.26,.35,.20),(0,.94,1.17),(0,.48,.10)]
        mesh(scene,'Folded ice petal %d'%i,pts,[(0,1,2),(0,2,3),(1,4,2),(2,4,3),(1,5,4),(3,4,5),(0,5,1),(0,3,5)],
             ['ice_dark','ice','ice_light','porcelain','ice','ice_dark','ice_dark','ice_dark'],root)
        petals.append(root)
    # Thin frost veins remain strictly inside one cell's footprint.
    for i in range(8):
        a=i*math.tau/8
        along=Vector((math.cos(a),math.sin(a),0))
        across=Vector((-math.sin(a),math.cos(a),0))
        pts=[along*.16+Vector((0,0,.012)),along*1.04+Vector((0,0,.012)),along*.55+across*.025+Vector((0,0,.012))]
        mesh(scene,'Frost vein %d'%i,pts,[(0,1,2)],['ice_light'])
    for f in range(1,25):
        t=(f-1)/30
        growth=smooth(0,.27,t)
        settle=smooth(.35,.70,t)
        for i,obj in enumerate(petals):
            size=.03+.97*growth
            obj.scale=(size*(1-.18*settle),size*(1-.18*settle),size*(1-.78*settle))
            key(obj,f)
    return scene


def build_reap():
    scene=create_scene('reap',384,6.2,1.15,30)
    root=rig(scene,'Harpe sweep')
    outer=[(0,0),(.68,.22),(.93,.93),(.77,1.64),(.22,2.23),(-.55,2.60)]
    inner=[(-.13,.13),(.02,.50),(.20,1.00),(.16,1.59),(-.10,2.13),(-.55,2.60)]
    parts=[]
    for j in range(5):
        part=rig(scene,'Blade wedge %d'%j);part.parent=root
        a,b=Vector(outer[j]),Vector(outer[j+1]);c,d=Vector(inner[j]),Vector(inner[j+1])
        mid_a=a.lerp(c,.68);mid_b=b.lerp(d,.68)
        slab(scene,'Obsidian blade section %d'%j,[a,b,mid_b,mid_a],.16,'obsidian','ink',part)
        mesh(scene,'Violet blade facet %d'%j,[(a.x,-.085,a.y),(b.x,-.085,b.y),(mid_a.x,-.11,mid_a.y)],[(0,1,2)],['plum' if j%2 else 'violet'],part)
        slab(scene,'Ivory cutting edge %d'%j,[mid_a,mid_b,d,c],.12,'ivory','plum',part)
        parts.append(part)
    slab(scene,'Bronze tang',[(-.19,-.06),(.12,-.06),(.10,-.29),(-.15,-.29)],.25,parent=root)
    slab(scene,'Wrapped short handle',[(-.11,-.27),(.05,-.27),(.03,-.71),(-.09,-.71)],.12,'obsidian','ink',root)
    for f in range(1,31):
        t=(f-1)/30
        grow=smooth(0,.10,t)
        cut=smooth(.16,.30,t)
        follow=smooth(.34,.53,t)
        root.location=(.53-.60*cut+.1*follow,-.32,1.18-.48*cut)
        root.rotation_euler.y=math.radians(-30+136*cut+28*follow)
        root.scale=(grow,)*3
        key(root,f)
        for i,part in enumerate(parts):
            out=smooth(.48,.85,t)
            part.location=(out*(.25+.09*i),0,out*(.3+.1*i))
            part.rotation_euler.y=out*(i-2)*.22
            part.scale=(max(.001,1-out),)*3
            key(part,f)
    scene.timeline_markers.new('CONTACT - confirmed cast only',frame=10)
    return scene


SOURCE.mkdir(parents=True,exist_ok=True)
MATS={}
for name,hex_value in PALETTE.items():
    mat=bpy.data.materials.new('Approved CEL '+name)
    mat.diffuse_color=rgba(hex_value)
    mat.use_nodes=True
    mat.node_tree.nodes.clear()
    node=mat.node_tree.nodes.new('ShaderNodeEmission');node.inputs[0].default_value=rgba(hex_value)
    output=mat.node_tree.nodes.new('ShaderNodeOutputMaterial')
    mat.node_tree.links.new(node.outputs[0],output.inputs[0])
    MATS[name]=mat
SCENES=[build_hook(),build_link(),build_link(True),build_arrow(),build_ice(),build_reap()]
manifest={'version':1,'blender':bpy.app.version_string,'palette_srgb':PALETTE,'assets':{},
          'approval':'docs/design/vfx_avant_production_2026-09-27/README.md',
          'source_script':'tools/class_card_vfx/approved/build.py'}
for scene in SCENES:
    bpy.context.window.scene=scene
    scene.frame_set(1)
    bpy.context.view_layer.update()
    pivot=world_to_camera_view(scene,scene.camera,Vector((0,0,0)))
    size=scene.render.resolution_x
    name=scene.name.removeprefix('Approved CEL - ')
    manifest['assets'][name]={'size':size,'frames':scene.frame_end,'fps':30,
        'pivot':[round(pivot.x*size,4),round((1-pivot.y)*size,4)],'scene':scene.name}
bpy.context.window.scene=SCENES[-1]
SCENES[-1].frame_set(6)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'approved_spells.blend'))
(SOURCE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
if '--render' in sys.argv:
    for scene in SCENES:
        bpy.context.window.scene=scene
        folder=RENDERS/scene.name.removeprefix('Approved CEL - ')
        folder.mkdir(parents=True,exist_ok=True)
        scene.render.filepath=str(folder/'frame_')
        bpy.ops.render.render(animation=True)
print('APPROVED_CEL_BUILD_COMPLETE')
