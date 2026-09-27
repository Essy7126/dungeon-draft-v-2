"""Original curved cel clasps for approved G / Permutation. Background Blender."""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT/'art/source/vfx/permutation'
RENDERS = ROOT/'artifacts/dev/class_card_vfx/permutation/render'
PALETTE = {'night':'183f45', 'jade':'438d83', 'jade_light':'8de3c2',
           'ivory':'fff0cc', 'cream_shadow':'bfae82', 'bronze':'ac743c',
           'gold':'f3cc80', 'white':'ffffe9'}
MATS = {}
def rgba(h):
    values = [int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in values)+(1,)
for name,h in PALETTE.items():
    m=bpy.data.materials.new('Permutation '+name)
    m.diffuse_color=rgba(h);m.use_nodes=True;m.node_tree.nodes.clear()
    emission=m.node_tree.nodes.new('ShaderNodeEmission');emission.inputs[0].default_value=rgba(h)
    output=m.node_tree.nodes.new('ShaderNodeOutputMaterial')
    m.node_tree.links.new(emission.outputs[0],output.inputs[0]);MATS[name]=m

def scene(name, frames, scale, z, face=False):
    s=bpy.data.scenes.new('Permutation CEL - '+name);bpy.context.window.scene=s
    s.render.engine=bpy.data.scenes[0].render.engine
    for prop,value in [('file_format','PNG'),('color_mode','RGBA')]:
        assert value in [i.identifier for i in s.render.image_settings.bl_rna.properties[prop].enum_items]
        setattr(s.render.image_settings,prop,value)
    s.view_settings.view_transform='Standard'
    s.render.resolution_x=s.render.resolution_y=384;s.render.resolution_percentage=100
    s.render.film_transparent=True;s.render.fps=30;s.frame_start=1;s.frame_end=frames
    if 'FIXED' in [i.identifier for i in s.render.bl_rna.properties['threads_mode'].enum_items]:
        s.render.threads_mode='FIXED';s.render.threads=6
    cam=bpy.data.objects.new(name+' camera',bpy.data.cameras.new(name+' camera'));s.collection.objects.link(cam)
    assert 'ORTHO' in [i.identifier for i in cam.data.bl_rna.properties['type'].enum_items]
    cam.data.type='ORTHO';cam.data.ortho_scale=scale
    target=Vector((0,0,z));cam.location=target+Vector((0,-10,0) if face else (4,-10,7))
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();s.camera=cam
    return s

def polygon(s,name,points,color,f):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(points,[],[tuple(range(len(points)))]);mesh.update()
    ob=bpy.data.objects.new(name,mesh);s.collection.objects.link(ob);mesh.materials.append(MATS[color])
    for frame,hidden in [(1,True),(f,False),(f+1,True)]:
        ob.hide_render=hidden;ob.hide_viewport=hidden
        ob.keyframe_insert(data_path='hide_render',frame=frame)
        ob.keyframe_insert(data_path='hide_viewport',frame=frame)

def clasp(front):
    s=scene('clasp_front' if front else 'clasp_back',20,3.25,.20)
    for f in range(1,21):
        # Broad seated crescents approach, pinch, reopen, then break into chips.
        sx=[1.10,1.04,.99,.96,.95,.92,.70,.32,.08,.30,.69,.95,1.05,1.10,1.12,1.15,1.17,1.19,1.21,1.23][f-1]
        radius=.92
        dissolve=max(0,(f-13)/7)
        for j in range(32):
            a=j*math.tau/32;b=(j+1)*math.tau/32
            middle=(a+b)*.5
            if ((math.cos(middle)*4-math.sin(middle)*10)>0)!=front:continue
            # Open ends of the two C-shaped pieces; no complete magic circle.
            if j in [7,8,23,24]:continue
            if f>13 and j%3!=0:continue
            angular_gap=0 if f<=13 else .04+dissolve*.025
            a+=angular_gap;b-=angular_gap
            inner=radius-(.23 if f<=13 else .16*(1-dissolve*.7))
            outer=radius+dissolve*.2
            z=.11+.08*math.sin(middle)**2+dissolve*.1
            low=.018+dissolve*.07
            def p(r,ang,h):return (r*math.cos(ang)*sx,r*math.sin(ang)*sx,h)
            top=[p(outer,a,z),p(outer,b,z),p(inner,b,z),p(inner,a,z)]
            jade=math.cos(middle)<0
            polygon(s,'Arc top %d %d'%(f,j),top,'jade' if jade else 'ivory',f)
            polygon(s,'Arc outer %d %d'%(f,j),[top[0],p(outer,a,low),p(outer,b,low),top[1]],'night' if jade else 'cream_shadow',f)
            polygon(s,'Arc inner %d %d'%(f,j),[top[2],p(inner,b,low),p(inner,a,low),top[3]],'night',f)
            rim=[p(outer-.026,a,z+.004),p(outer-.026,b,z+.004),p(outer-.050,b,z+.004),p(outer-.050,a,z+.004)]
            polygon(s,'Arc polished edge %d %d'%(f,j),rim,'jade_light' if jade else 'white',f)
        if front and f<=13:
            # Front-facing bronze keystone, split into two facets.
            x=.0;y=-.94*sx;z=.12
            w=.13*max(.5,sx)
            polygon(s,'Bronze lock %d'%f,[(-w,y-.025,z+.14),(w,y-.025,z+.14),(w*.74,y-.03,z-.12),(0,y-.04,z-.21),(-w*.74,y-.03,z-.12)],'bronze',f)
            polygon(s,'Gold bevel %d'%f,[(-w,y-.041,z+.14),(0,y-.05,z-.015),(0,y-.05,z-.20),(-w*.74,y-.04,z-.12)],'gold',f)
        if f>=10:
            # Four quiet slivers continue the opening gesture, without a hit burst.
            for j in range(4):
                a=j*math.tau/4+.2
                if ((math.cos(a)*4-math.sin(a)*10)>0)!=front:continue
                t=(f-10)/10;r=.85+t*.55;h=.12+.32*math.sin(t*math.pi)
                x,y=r*math.cos(a),r*math.sin(a);w=.06*(1-t*.7)
                polygon(s,'Release chip %d %d'%(f,j),[(x-w,y,h),(x,y,h+.12*(1-t*.7)),(x+w,y,h+.01),(x,y,h-.025)],'jade_light' if j%2 else 'ivory',f)
    return s

slit=scene('slit',8,2.7,.58,True)
for f in range(1,9):
    widths=[.10,.14,.20,.23,.17,.10,.06,.025]
    heights=[.42,.63,.84,.78,.57,.36,.20,.09]
    w=widths[f-1];h=heights[f-1]
    for mult,color,depth in [(1.35,'night',.02),(1.0,'jade_light',0),(.46,'white',-.025)]:
        polygon(slit,'Pinch aperture %d %s'%(f,color),[(0,depth,.04),(w*mult,depth,h*.45),(.015,depth,h),(-w*mult,depth,h*.45)],color,f)
    if f<=5:
        for side in [-1,1]:
            polygon(slit,'Pinch glint %d %d'%(f,side),[(side*.14,-.035,.19),(side*(.34+f*.03),-.035,.28),(side*.19,-.035,.24)],'ivory',f)

SCENES=[clasp(False),clasp(True),slit]
SOURCE.mkdir(parents=True,exist_ok=True)
manifest={'version':1,'blender':bpy.app.version_string,'palette_srgb':PALETTE,
 'approval':'docs/design/vfx_avant_production_lot2_2026-09-27/g_permutation.png',
 'source_script':'tools/class_card_vfx/permutation/build.py','assets':{}}
for s in SCENES:
    bpy.context.window.scene=s;s.frame_set(1);bpy.context.view_layer.update()
    size=s.render.resolution_x;p=world_to_camera_view(s,s.camera,Vector((0,0,0)))
    name=s.name.removeprefix('Permutation CEL - ')
    manifest['assets'][name]={'size':size,'frames':s.frame_end,'fps':30,'pivot':[round(p.x*size,4),round((1-p.y)*size,4)],'scene':s.name}
bpy.context.window.scene=SCENES[1];SCENES[1].frame_set(4)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'permutation.blend'))
(SOURCE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
if '--render' in sys.argv:
    for s in SCENES:
        bpy.context.window.scene=s;d=RENDERS/s.name.removeprefix('Permutation CEL - ');d.mkdir(parents=True,exist_ok=True)
        s.render.filepath=str(d/'frame_');bpy.ops.render.render(animation=True)
print('PERMUTATION_CEL_BUILD_COMPLETE')
