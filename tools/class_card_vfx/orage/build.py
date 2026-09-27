"""Original cel geometry for the approved H / Orage du passage drawing.
Background Blender only: --factory-startup --python build.py -- --render.
"""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT=Path(__file__).resolve().parents[3]
SOURCE=ROOT/'art/source/vfx/orage_passage'
RENDERS=ROOT/'artifacts/dev/class_card_vfx/orage/render'
PALETTE={'night':'132958','blue':'225a94','teal':'168e9b','cyan':'49e6ec',
         'mint':'bcfff0','ivory':'fff6d6','gold':'eab763'}
MATS={}
def rgba(h):
    c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c)+(1,)
for name,h in PALETTE.items():
    m=bpy.data.materials.new('Orage '+name)
    m.diffuse_color=rgba(h);m.use_nodes=True;m.node_tree.nodes.clear()
    emission=m.node_tree.nodes.new('ShaderNodeEmission')
    emission.inputs[0].default_value=rgba(h)
    output=m.node_tree.nodes.new('ShaderNodeOutputMaterial')
    m.node_tree.links.new(emission.outputs[0],output.inputs[0]);MATS[name]=m

def scene(name,frames,scale,target_z=0,front=False):
    s=bpy.data.scenes.new('Orage CEL - '+name);bpy.context.window.scene=s
    s.render.engine=bpy.data.scenes[0].render.engine
    for prop,value in [('file_format','PNG'),('color_mode','RGBA')]:
        assert value in [i.identifier for i in s.render.image_settings.bl_rna.properties[prop].enum_items]
        setattr(s.render.image_settings,prop,value)
    try:s.view_settings.view_transform='Standard'
    except TypeError:pass
    s.render.resolution_x=s.render.resolution_y=384 if name!='bolt' else 512
    s.render.resolution_percentage=100;s.render.film_transparent=True
    s.render.fps=30;s.frame_start=1;s.frame_end=frames
    if 'FIXED' in [i.identifier for i in s.render.bl_rna.properties['threads_mode'].enum_items]:
        s.render.threads_mode='FIXED';s.render.threads=6
    camera=bpy.data.objects.new(name+' camera',bpy.data.cameras.new(name+' camera'))
    s.collection.objects.link(camera)
    assert 'ORTHO' in [i.identifier for i in camera.data.bl_rna.properties['type'].enum_items]
    camera.data.type='ORTHO';camera.data.ortho_scale=scale
    target=Vector((0,0,target_z))
    camera.location=target+Vector((0,-10,0) if front else (4,-10,7))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    s.camera=camera
    return s

def polygon(s,name,points,color,frame=None):
    m=bpy.data.meshes.new(name);m.from_pydata(points,[],[tuple(range(len(points)))]);m.update()
    ob=bpy.data.objects.new(name,m);s.collection.objects.link(ob);m.materials.append(MATS[color])
    if frame is not None:
        for f,hidden in [(1,True),(frame,False),(frame+1,True)]:
            ob.hide_render=hidden;ob.hide_viewport=hidden
            ob.keyframe_insert(data_path='hide_render',frame=f)
            ob.keyframe_insert(data_path='hide_viewport',frame=f)
    return ob

def ribbon(s,name,points,width,color,depth,frame):
    # A single flat-faced zigzag, tapering to a needle at the contact.
    left=[];right=[]
    for i,(x,z) in enumerate(points):
        profile=[.50,.85,1.18,.70,1.0,.55,.38,.015]
        w=width*profile[min(i,len(profile)-1)]
        left.append((x-w/2,depth,z));right.append((x+w/2,depth,z))
    polygon(s,name,left+list(reversed(right)),color,frame)

bolt=scene('bolt',15,4.5,1.72,True)
base=[(-.08,3.7),(-.20,3.05),(.20,2.60),(-.06,1.93),(.29,1.43),(.02,.98),(.13,.55),(0,0)]
for f in range(1,16):
    if f<=8:
        fade=1 if f<=3 else 1-(f-3)/6
        shift=(0,.02,-.025,0,.04,-.02,0,.01)[f-1]
        pts=[(x+shift*math.sin(i*2),z) for i,(x,z) in enumerate(base)]
        for width,color,y in [(.52,'night',.05),(.41,'teal',.01),(.31,'cyan',-.02),(.18,'ivory',-.04)]:
            ribbon(bolt,'Discharge %02d %s'%(f,color),pts,width*fade,color,y,f)
        # Two subordinate side forks only during the peak.
        if f<=4:
            ribbon(bolt,'Upper fork %d'%f,[(.12,2.6),(.43,2.40),(.35,2.02)],.085,'cyan',-.03,f)
            ribbon(bolt,'Lower fork %d'%f,[(-.14,1.9),(-.43,1.70),(-.35,1.40)],.065,'ivory',-.04,f)
    else:
        t=(f-8)/7
        for j in range(5):
            x,z=base[j+1];z+=t*(.12+j*.045);x+=(1 if j%2 else -1)*t*.22
            a=.14*(1-t*.80)
            polygon(bolt,'Residual shard %d %d'%(f,j),[(x-a,.0,z+.26*(1-t*.5)),(x+a*.4,.0,z+.08),(x+a,.0,z-.1),(x-a*.45,.0,z-.03)],'cyan' if j%2 else 'night',f)
            if j%2==0:polygon(bolt,'Ivory shard %d %d'%(f,j),[(x-a*.25,-.01,z+.12),(x+a*.3,-.01,z),(x-a*.2,-.01,z-.03)],'mint',f)

def crown(front):
    name='crown_front' if front else 'crown_back'
    s=scene(name,18,3.7,.22)
    for f in range(1,19):
        t=(f-1)/30
        buildup=min(1,(f+1)/9)
        dissolve=max(0,(f-10)/8)
        radius=(1.17-.24*buildup)*(1-.30*dissolve)
        height=(.10+.33*buildup)*(1-.9*dissolve)
        for j in range(10):
            angle=j*math.tau/10+.10*buildup
            # Camera faces the (4,-10) quadrant. Split at the true view plane.
            if ((math.cos(angle)*4-math.sin(angle)*10)>0)!=front:continue
            a=angle-.25;b=angle+.25
            r=radius*(1+.03*math.sin(j*2))
            pts=[(r*math.cos(a),r*math.sin(a),.03),
                 (r*math.cos(a+.18),r*math.sin(a+.18),height*.60),
                 (r*math.cos(b-.08),r*math.sin(b-.08),height*.32),
                 (r*math.cos(b),r*math.sin(b),height),
                 ((r-.08)*math.cos(b), (r-.08)*math.sin(b),max(.02,height-.12)),
                 ((r-.08)*math.cos(a+.18),(r-.08)*math.sin(a+.18),max(.02,height*.60-.12)),
                 ((r-.08)*math.cos(a),(r-.08)*math.sin(a),.01)]
            polygon(s,'Crown ribbon %d %d'%(f,j),pts,'night',f)
            polygon(s,'Crown facet %d %d'%(f,j),[pts[1],pts[2],pts[3],pts[4],pts[5]],'cyan' if j%2 else 'teal',f)
            if f>=5:
                p=pts[3];q=pts[2]
                polygon(s,'Crown rim %d %d'%(f,j),[p,q,(q[0]*.98,q[1]*.98,q[2]+.035),(p[0]*.99,p[1]*.99,p[2]+.035)],'ivory',f)
    return s

impact=scene('impact',15,3.8,.22)
for f in range(1,16):
    t=(f-1)/14
    radius=.16+.95*(1-(1-t)**3)
    # Broken planar petals, not a disk. Leave space under the actor.
    for j in range(9):
        a=j*math.tau/9
        length=(.28+.1*(j%3))*(1-t)**.65
        tip=radius+length
        pts=[(radius*math.cos(a-.10),radius*math.sin(a-.10),.025),
             (tip*math.cos(a+.02),tip*math.sin(a+.02),.04+.18*(1-t)),
             ((radius+.08)*math.cos(a+.11),(radius+.08)*math.sin(a+.11),.03)]
        polygon(impact,'Contact shard %d %d'%(f,j),pts,'ivory' if f<4 else ('cyan' if j%2 else 'teal'),f)
        if f<=7:
            tip2=tip+.07
            polygon(impact,'Dark lower edge %d %d'%(f,j),[pts[0],(tip2*math.cos(a),tip2*math.sin(a),.01),pts[1]],'night',f)
    # Three broken shock crescents expand along the ground plane.
    for arc in range(3):
        start=arc*math.tau/3+.18
        thick=.12*(1-t)+.012
        outer=[];inner=[]
        for k in range(9):
            a=start+k/8*1.25
            outer.append(((radius+.12)*math.cos(a),(radius+.12)*math.sin(a),.055))
            inner.append(((radius+.12-thick)*math.cos(a),(radius+.12-thick)*math.sin(a),.055))
        polygon(impact,'Broken shock crescent %d %d'%(f,arc),outer+list(reversed(inner)), 'ivory' if f<4 else 'cyan',f)
    # The tiny warm-white core lives for two exposure frames only.
    if f<=2:
        pts=[]
        for j in range(16):
            r=.42 if j%2==0 else .13
            a=j*math.tau/16
            pts.append((r*math.cos(a),r*math.sin(a),.08))
        polygon(impact,'Two-frame contact core %d'%f,pts,'ivory',f)
    # Six tiny gold sparks are secondary accents, not another damage event.
    for j in range(6):
        a=j*math.tau/6+.3;r=.22+t*.9;z=.20+math.sin(t*math.pi)*(.3+j*.03)
        x,y=r*math.cos(a),r*math.sin(a);size=.045*(1-.75*t)
        polygon(impact,'Gold spark %d %d'%(f,j),[(x-size,y,z),(x,y,z+size*2),(x+size,y,z),(x,y,z-size)],'gold',f)

SCENES=[bolt,crown(False),crown(True),impact]
SOURCE.mkdir(parents=True,exist_ok=True)
manifest={'version':1,'blender':bpy.app.version_string,'palette_srgb':PALETTE,
          'approval':'docs/design/vfx_avant_production_lot2_2026-09-27/h_orage_du_passage.png',
          'source_script':'tools/class_card_vfx/orage/build.py','assets':{}}
for s in SCENES:
    bpy.context.window.scene=s;s.frame_set(1);bpy.context.view_layer.update()
    size=s.render.resolution_x;p=world_to_camera_view(s,s.camera,Vector((0,0,0)))
    name=s.name.removeprefix('Orage CEL - ')
    manifest['assets'][name]={'size':size,'frames':s.frame_end,'fps':30,'pivot':[round(p.x*size,4),round((1-p.y)*size,4)],'scene':s.name}
bpy.context.window.scene=bolt;bolt.frame_set(2)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'orage_passage.blend'))
(SOURCE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
if '--render' in sys.argv:
    for s in SCENES:
        bpy.context.window.scene=s
        d=RENDERS/s.name.removeprefix('Orage CEL - ');d.mkdir(parents=True,exist_ok=True)
        s.render.filepath=str(d/'frame_');bpy.ops.render.render(animation=True)
print('ORAGE_CEL_BUILD_COMPLETE')
