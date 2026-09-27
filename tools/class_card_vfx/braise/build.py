"""Original cel charcoal, flame shards and steam for Braise tenace / plan E."""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT=Path(__file__).resolve().parents[3]
SOURCE=ROOT/'art/source/vfx/braise'
RENDERS=ROOT/'artifacts/dev/class_card_vfx/braise/render'
PALETTE={'soot':'291f2b','coal':'44303c','facet':'65404b','rust':'9b382a',
 'red':'d84725','orange':'fa852b','gold':'ffc26a','cream':'fff0c7',
 'steam_shadow':'697e94','steam':'a9c3cf','steam_light':'e2ece4'}
MATS={}
def rgba(h):
 v=[int(h[i:i+2],16)/255 for i in (0,2,4)]
 return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in v)+(1,)
for name,h in PALETTE.items():
 m=bpy.data.materials.new('Braise '+name);m.diffuse_color=rgba(h);m.use_nodes=True
 m.node_tree.nodes.clear();e=m.node_tree.nodes.new('ShaderNodeEmission')
 e.inputs[0].default_value=rgba(h);o=m.node_tree.nodes.new('ShaderNodeOutputMaterial')
 m.node_tree.links.new(e.outputs[0],o.inputs[0]);MATS[name]=m

def scene(name,frames,scale=3.7,center=0):
 s=bpy.data.scenes.new('Braise CEL - '+name);bpy.context.window.scene=s
 s.render.engine=bpy.data.scenes[0].render.engine
 s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
 # Read the actual configured transform, which is valid even with dynamic RNA enums.
 s.view_settings.view_transform=bpy.data.scenes[0].view_settings.view_transform
 try:s.view_settings.view_transform='Standard'
 except TypeError:pass
 s.render.resolution_x=s.render.resolution_y=384;s.render.resolution_percentage=100
 s.render.film_transparent=True;s.render.fps=30;s.frame_start=1;s.frame_end=frames
 if 'FIXED' in [i.identifier for i in s.render.bl_rna.properties['threads_mode'].enum_items]:
  s.render.threads_mode='FIXED';s.render.threads=6
 cam=bpy.data.objects.new(name+' camera',bpy.data.cameras.new(name+' camera'));s.collection.objects.link(cam)
 cam.data.type='ORTHO';cam.data.ortho_scale=scale;cam.location=(0,-10,center)
 cam.rotation_euler=(Vector((0,0,center))-cam.location).to_track_quat('-Z','Y').to_euler();s.camera=cam
 return s

def poly(s,name,points,color,f,depth=0):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([(x,depth,z) for x,z in points],[],[tuple(range(len(points)))]);mesh.update()
 ob=bpy.data.objects.new(name,mesh);s.collection.objects.link(ob);mesh.materials.append(MATS[color])
 for frame,hidden in [(1,True),(f,False),(f+1,True)]:
  ob.hide_render=hidden;ob.hide_viewport=hidden
  ob.keyframe_insert(data_path='hide_render',frame=frame);ob.keyframe_insert(data_path='hide_viewport',frame=frame)

ROCK=[(-.55,-.23),(-.64,.14),(-.36,.52),(.13,.62),(.52,.30),(.57,-.12),(.20,-.47),(-.25,-.52)]
def rock(s,f,x=0,z=0,size=1,angle=0,opened=0):
 def tr(p):
  a,b=p;return (x+size*(a*math.cos(angle)-b*math.sin(angle)),z+size*(a*math.sin(angle)+b*math.cos(angle)))
 # Off-centre crest and an irregular rim give a solid, faceted silhouette.
 poly(s,'charcoal silhouette',list(map(tr,ROCK)),'soot',f,.03)
 crest=(-.05,.08)
 for i in range(8):
  a=ROCK[i];b=ROCK[(i+1)%8]
  poly(s,'charcoal facet',list(map(tr,[a,b,crest])),['coal','facet','coal','soot','rust','coal','facet','soot'][i],f,.015)
 cracks=[[(-.44,-.29),(-.12,-.09),(-.19,.09),(.10,.20),(.25,.51)],
         [(-.18,.07),(-.40,.18),(-.49,.32)],[(.04,.17),(.26,.03),(.44,.07)]]
 for path in cracks:
  for thickness,col,depth in [(.075,'red',-.01),(.044+opened*.014,'orange',-.02),(.020+opened*.012,'cream',-.03)]:
   left=[];right=[]
   for k,(a,b) in enumerate(path):
    w=thickness*(.45 if k in [0,len(path)-1] else 1)
    left.append((a-w,b));right.append((a+w,b))
   poly(s,'branching molten seam',list(map(tr,left+right[::-1])),col,f,depth)

coal=scene('coal',8,2.9)
for f in range(1,9):
 a=.12*math.sin(f*.9)
 # Two sharply tapered streaks follow the coal, never a smoky trail.
 for j in range(2):
  z=(j-.5)*.30
  poly(coal,'projectile streak',[(-1.28,z-.12),(-.34,z-.07),(-.33,z+.09),(-.77,z+.035)],'orange' if j else 'gold',f,.06)
 rock(coal,f,.14,0,.78,a,.25)

impact=scene('impact',12,4.0)
for f in range(1,13):
 u=(f-1)/11;grow=min(1,(f+1)/4);retreat=max(0,(f-5)/7)
 # Four unequal flame lobes burst from the seam, then shear upwards.
 for j,(angle,length) in enumerate([(0.42,1.08),(1.90,1.46),(3.15,.93),(4.57,1.19)]):
  angle+=retreat*.17;inner=.09+retreat*.50;outer=length*grow+retreat*.18
  thick=.25*(1-retreat*.83)
  def pt(r,w):return (math.cos(angle)*r-math.sin(angle)*w,math.sin(angle)*r+math.cos(angle)*w+retreat*.25)
  tongue=[pt(inner,0),pt(inner+.22,-thick),pt(outer*.67,-thick*.85),pt(outer,thick*.5),pt(outer*.69,thick*.34),pt(outer*.62,thick*1.7),pt(inner+.12,thick*.4)]
  poly(impact,'rust shell',tongue,'rust',f,.03)
  poly(impact,'vermilion tongue',[(a*.92,b*.92) for a,b in tongue],'red',f,.01)
  core=[pt(inner,.02),pt(outer*.66,-thick*.43),pt(outer*.90,thick*.25),pt(outer*.53,thick*.41)]
  poly(impact,'hot tongue',core,'orange' if f>3 else 'gold',f,-.02)
  if f<=4:rock(impact,f,*pt(outer*.88,0),.27*(1-retreat),angle,.3)
 if f<=5:
  star=[]
  for j in range(16):
   a=j*math.tau/16+.15;r=(.50 if j%2==0 else .18)*grow*(1-max(0,f-2)*.16)
   star.append((math.cos(a)*r,math.sin(a)*r))
  poly(impact,'single impact core',star,'cream',f,-.06)
 for j in range(7):
  a=j*math.tau/7+.3;r=.60+u*.92;w=.065*(1-u*.70)
  x,z=math.cos(a)*r,math.sin(a)*r+u*.22
  poly(impact,'cooling shard',[(x-w,z),(x,z+w*1.7),(x+w,z),(x,z-w*.7)],'gold' if j%3 else 'coal',f,-.03)

ember=scene('ember',7,2.5,.26)
for f in range(1,8):
 pulse=[0,.25,.90,1,.66,.28,.02][f-1]
 rock(ember,f,0,-.02,.63,-.13,pulse)
 for j in range(2):
  x=(-.12 if j==0 else .20);h=(.19+pulse*.60)*(1 if j==0 else .72)
  base=[(x-.11,.28),(x+.06,.38),(x+.13,.44+h),(x-.07,.32+h*.75),(x-.12,.32+h*.40)]
  poly(ember,'breathing tip',base,'orange',f,-.06)
  poly(ember,'tip core',[(x-.04,.30),(x+.04,.39+h*.66),(x-.07,.34+h*.34)],'cream',f,-.07)

steam=scene('steam',12,3.2,1.0)
for f in range(1,13):
 growth=min(1,f/8)
 for j in range(3):
  x=(j-1)*.35;z=.22+j*.37;radius=(.29-j*.025)*growth
  # Open spiral ribbons with negative space; no opaque cloud over the unit.
  center=(x,z+.12*growth)
  outer=[];inner=[]
  for k in range(25):
   a=-1.2+k*math.pi*1.75/24;r=radius*(.48+.52*k/24)
   outer.append((center[0]+math.cos(a)*r,center[1]+math.sin(a)*r))
   inner.append((center[0]+math.cos(a)*(r-.055*growth),center[1]+math.sin(a)*(r-.055*growth)))
  ribbon=outer+inner[::-1]
  poly(steam,'steam curl shadow',[(a+.035,b-.02) for a,b in ribbon],'steam_shadow',f,.02)
  poly(steam,'steam curl',ribbon,'steam_light' if j%2 else 'steam',f,0)
  left=[];right=[]
  for k in range(20):
   t=k/19;cx=x+math.sin(t*math.pi*1.5)*.14*growth;cz=.06+t*(z-.02)
   w=(.035+.065*math.sin(t*math.pi))*growth
   left.append((cx-w,cz));right.append((cx+w,cz))
  poly(steam,'rising curved wisp',left+right[::-1],'steam',f,.03)

SCENES=[coal,impact,ember,steam]
SOURCE.mkdir(parents=True,exist_ok=True)
manifest={'version':1,'blender':bpy.app.version_string,'palette_srgb':PALETTE,
 'approval':'docs/design/vfx_avant_production_lot2_2026-09-27/e_braise_tenace.png',
 'source_script':'tools/class_card_vfx/braise/build.py','assets':{}}
for s in SCENES:
 bpy.context.window.scene=s;s.frame_set(1);bpy.context.view_layer.update()
 p=world_to_camera_view(s,s.camera,Vector((0,0,0)));name=s.name.removeprefix('Braise CEL - ')
 manifest['assets'][name]={'size':384,'frames':s.frame_end,'fps':30,'pivot':[round(p.x*384,4),round((1-p.y)*384,4)],'scene':s.name}
bpy.context.window.scene=impact;impact.frame_set(3)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'braise.blend'))
(SOURCE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
if '--render' in sys.argv:
 for s in SCENES:
  bpy.context.window.scene=s;d=RENDERS/s.name.removeprefix('Braise CEL - ');d.mkdir(parents=True,exist_ok=True)
  s.render.filepath=str(d/'frame_');bpy.ops.render.render(animation=True)
print('BRAISE_CEL_BUILD_COMPLETE')
