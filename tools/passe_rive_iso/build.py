"""Register whole authored poses, pack lossless trimmed atlases, emit Godot resources."""
from pathlib import Path
import json,math,hashlib
import numpy as np
from scipy import ndimage
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/source/characters/achilles/passe_rive_iso_v1'
OLD=ROOT/'art/source/characters/achilles/passe_rive_spells_v1/delivery'
OUT=ROOT/'assets/characters/Achilles/passe_rive_iso_v1'
QA=ROOT/'artifacts/spine_trial/passe_rive_iso_v1'
for p in [OUT,QA,QA/'frames',OUT/'atlases']:p.mkdir(parents=True,exist_ok=True)
W,H=1152,768;PX,PY=576,662;DIRS=['E','S','N','W']
manifest=json.loads((OLD/'manifest.json').read_text(encoding='utf8'))
extraction=json.loads((SRC/'extraction.json').read_text(encoding='utf8'))
annotations=json.loads((SRC/'landmarks.json').read_text(encoding='utf8')) if (SRC/'landmarks.json').exists() else {}
actions=manifest['actions'];images={};transforms={};report=[]

def head_top(im):
 p=np.asarray(im);m=(p[:,:,3]>100)&(p[:,:,:3].max(2)<140)
 broad=m.sum(1)>max(12,im.width*.025)
 hits=np.flatnonzero(ndimage.uniform_filter1d(broad.astype(float),size=19)>.72)
 return int(hits[0]) if len(hits) else im.getbbox()[1]

for a in actions+[{'id':'walk','frames':manifest['walk']}]:
 action=a['id'];count=len(a['frames'])
 images[action+'_E']=[]
 for i,f in enumerate(a['frames']):
  original=Image.open(OLD/f['file']).convert('RGBA');canvas=Image.new('RGBA',(W,H))
  canvas.paste(original,(256 if original.width==768 else 0,0));images[action+'_E'].append(canvas)
 for d in DIRS[1:]:
  clip=action+'_'+d
  if clip not in extraction:continue
  poses=extraction[clip]['poses']
  if len(poses)!=count:raise RuntimeError(f'Wrong count {clip}: {len(poses)} != {count}')
  refindex=0 if action=='guard' else count-1
  ref=images[action+'_E'][refindex]
  target_height=ref.getbbox()[3]-head_top(ref)
  sourceheight=poses[refindex]['anchor'][1]-poses[refindex]['head_y']
  scale=target_height/sourceheight
  if action=='walk':scale=np.median([x.getbbox()[3]-head_top(x) for x in images['walk_E']])/np.median([p['anchor'][1]-p['head_y'] for p in poses])
  images[clip]=[];transforms[clip]=[]
  for i,p in enumerate(poses):
   im=Image.open(ROOT/p['file']).convert('RGBA');anchor=list(p['anchor'])
   if action=='walk':
    arr=np.asarray(im);height=anchor[1]-p['head_y']
    band=arr[int(p['head_y']+height*.4):int(p['head_y']+height*.53)]
    mask=(band[:,:,3]>160)&(band[:,:,:3].max(2)<155)
    xs=np.nonzero(mask)[1]
    if len(xs):anchor[0]=float(np.median(xs))
   lift=0
   if action=='dash' and i==1:lift=32
   sw,sh=round(im.width*scale),round(im.height*scale)
   dst=[round(PX-anchor[0]*scale),round(PY-anchor[1]*scale-lift)]
   canvas=Image.new('RGBA',(W,H));canvas.paste(im.resize((sw,sh),Image.Resampling.LANCZOS),tuple(dst))
   bounds=canvas.getbbox()
   if not bounds or min(bounds[:2])<2 or bounds[2]>W-2 or bounds[3]>H-2:raise RuntimeError(f'Clipped {clip}/{i} {bounds}')
   images[clip].append(canvas);transforms[clip].append({'scale':scale,'offset':dst,'box':p['box'],'anchor':anchor})

effects={}
for a in actions:
 id=a['id'];e={}
 if 'vfx' in a:
  e={'palms':[[[p[0]+256,p[1]] for p in pair] for pair in a['vfx']['palms']], 'chest':[[p[0]+256,p[1]] for p in a['vfx']['chest']]}
 if 'tremor' in a:e={'tremor':dict(a['tremor'],center=[a['tremor']['center'][0]+256,a['tremor']['center'][1]])}
 if 'sweep_trail' in a:e={'tips':a['sweep_trail']['tips'],'front_segments':[False,False,False,True,True]}
 if e:effects[id+'_E']=e
 for d in DIRS[1:]:
  key=id+'_'+d
  if key not in transforms:continue
  def point(i,p):
   t=transforms[key][i];return [round(t['offset'][k]+(p[k]-t['box'][k])*t['scale'],2) for k in range(2)]
  if key in annotations:
   raw=annotations[key];e={}
   if 'tips' in raw:e={'tips':[point(i,p) for i,p in enumerate(raw['tips'])], 'front_segments':raw.get('front_segments',[False,False,False,True,True])}
   if 'palms' in raw:e={'palms':[[point(i,p) for p in pair] for i,pair in enumerate(raw['palms'])], 'chest':[point(i,p) for i,p in enumerate(raw['chest'])]}
   if 'tremor' in raw:
    t=raw['tremor'];e={'tremor':{'center':point(3,t['center']),'radius':[v*transforms[key][3]['scale'] for v in t['radius']]}}
   effects[key]=e

texture_defs=[];external=[];animations=[];atlas_id=0
def add_animation(name,indices,durations,loop=False):
 frames=', '.join('{"duration": '+str(float(ms)/100.0)+', "texture": SubResource("'+tex+'")}' for tex,ms in zip(indices,durations))
 animations.append('{"frames": ['+frames+'], "loop": '+str(loop).lower()+', "name": &"'+name+'", "speed": 10.0}')
texture_ids={}
for clip,frames in images.items():
 atlas_id+=1;ext='atlas_'+str(atlas_id);packed=[];x=y=rowh=0
 for i,im in enumerate(frames):
  box=im.getbbox();crop=im.crop(box);cw,ch=crop.size
  if x+cw+8>2048:x=0;y+=rowh;rowh=0
  packed.append((x+4,y+4,box,crop));x+=cw+8;rowh=max(rowh,ch+8)
 ah=y+rowh;atlas=Image.new('RGBA',(2048,ah));ids=[]
 for i,(x,y,box,crop) in enumerate(packed):
  atlas.paste(crop,(x,y));tex=f'{clip}_{i:02}';ids.append(tex)
  texture_defs.append(f'[sub_resource type="AtlasTexture" id="{tex}"]\natlas = ExtResource("{ext}")\nregion = Rect2({x}, {y}, {crop.width}, {crop.height})\nmargin = Rect2({box[0]}, {box[1]}, {W-crop.width}, {H-crop.height})\nfilter_clip = true\n')
  restored=Image.new('RGBA',(W,H));restored.paste(atlas.crop((x,y,x+crop.width,y+crop.height)),box[:2])
  if restored.tobytes()!=frames[i].tobytes():raise RuntimeError('Atlas pixel roundtrip mismatch')
  filename=f'{clip}_{i:02}.png';frames[i].save(QA/'frames'/filename)
  report.append({'clip':clip,'frame':i,'bounds':box,'sha256':hashlib.sha256(frames[i].tobytes()).hexdigest()})
 atlas.save(OUT/'atlases'/f'{clip}.png')
 external.append(f'[ext_resource type="Texture2D" path="res://assets/characters/Achilles/passe_rive_iso_v1/atlases/{clip}.png" id="{ext}"]')
 texture_ids[clip]=ids
 action=clip.rsplit('_',1)[0];definition=next((a for a in actions if a['id']==action),None)
 durations=[f['duration_ms'] for f in definition['frames']] if definition else [100]*len(ids)
 add_animation(clip,ids,durations,action=='walk')
for d in DIRS:
 if 'strike_'+d not in texture_ids:continue
 ids=texture_ids['strike_'+d]
 add_animation('attack_'+d,ids,[100,80,90,130])
 add_animation('idle_'+d,[ids[3]],[1000],True)
 for a in ['sky_bow','ivory_bow','vital_harvest','fauche']:
  if a+'_'+d in texture_ids:add_animation(a+'_rest_'+d,[texture_ids[a+'_'+d][-1]],[1000],False)
(OUT/'sprite_frames.tres').write_text(f'[gd_resource type="SpriteFrames" load_steps={1+len(external)+len(texture_defs)} format=3]\n\n'+'\n'.join(external)+'\n\n'+'\n'.join(texture_defs)+'\n[resource]\nanimations = [\n'+',\n'.join(animations)+'\n]\n',encoding='utf8')

settings={}
for a in actions:
 if a['id']=='dash':continue
 t=0;release=0
 for i,f in enumerate(a['frames']):
  if t>=a['event_ms']:release=i;break
  t+=f['duration_ms']
 settings[a['id']]={'frame_count':len(a['frames']),'duration_seconds':a['total_ms']/1000,'release_seconds':a['event_ms']/1000,'release_frame':release}
settings['attack']=dict(settings['strike'])
profile='''[gd_resource type="Resource" script_class="AchillesSpriteVisualProfile" load_steps=2 format=3]
[ext_resource type="Script" path="res://data/visuals/achilles/achilles_sprite_visual_profile.gd" id="1"]
[resource]
script = ExtResource("1")
profile_id = &"passe_rive_iso_v1"
sprite_frames_path = "res://assets/characters/Achilles/passe_rive_iso_v1/sprite_frames.tres"
expanded_kit_enabled = false
frame_canvas_size = Vector2i(1152, 768)
foot_anchor = Vector2(576, 662)
display_scale = 0.22
attack_release_frame = 1
walk_segment_duration_seconds = 0.6
run_segment_duration_seconds = 0.4
attack_duration_seconds = 0.4
attack_release_seconds = 0.1
advance_duration_seconds = 1.2
advance_release_seconds = 0.1
'''
profile+='action_clip_settings = '+json.dumps(settings)+'\n'
(OUT/'profile.tres').write_text(profile,encoding='utf8')
# Portrait is a lossless crop of the authored E recovery pose.
portrait=images['strike_E'][3].crop((440,190,680,490));portrait.save(OUT/'portrait.png')
(OUT/'portrait.tres').write_text('[gd_resource type="AtlasTexture" load_steps=2 format=3]\n[ext_resource type="Texture2D" path="res://assets/characters/Achilles/passe_rive_iso_v1/portrait.png" id="1"]\n[resource]\natlas = ExtResource("1")\nregion = Rect2(0, 0, 240, 300)\n',encoding='utf8')
result={'schema':2,'name':'Passe-rive — quatre vues isométriques','directions':DIRS,'frame_size':[W,H],'pivot':[PX,PY],'display_scale':.22,'actions':actions,'effects':effects,'walk_frames':12,'status':'in_game_art_trial','missing_clips':[a['id']+'_'+d for a in actions+[{'id':'walk'}] for d in DIRS if a['id']+'_'+d not in images],'generation':'Built-in ImageGen, whole-pose registration and authorized RemBG cutout; no software mirroring.'}
for folder in [OUT,QA]:(folder/'manifest.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
(SRC/'registration.json').write_text(json.dumps(transforms,indent=2),encoding='utf8')
(QA/'build_report.json').write_text(json.dumps({'clips':len(images),'painted_frames':len(report),'atlas_roundtrip_exact':True,'effects':list(effects),'missing':result['missing_clips'],'frames':report},indent=2),encoding='utf8')
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
for a in actions+[{'id':'walk','name':'Marche'}]:
 action=a['id'];count=len(images[action+'_E']);cw,ch=230,195
 contact=Image.new('RGB',(cw*count,ch*4),'#223330');draw=ImageDraw.Draw(contact)
 for row,d in enumerate(DIRS):
  for i,im in enumerate(images.get(action+'_'+d,[])):
   thumb=im.resize((230,154),Image.Resampling.LANCZOS);contact.paste(thumb,(i*cw,row*ch+24),thumb)
   draw.text((i*cw+8,row*ch+4),f'{d} / {i+1}',font=font,fill='#e5d6b2')
 contact.save(QA/f'{action}_contact.jpg',quality=90)
print(json.dumps({'clips':len(images),'frames':len(report),'missing':result['missing_clips'],'effects':list(effects)}))
