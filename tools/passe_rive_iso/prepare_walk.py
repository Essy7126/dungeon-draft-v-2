"""Cut out one walk direction for inspection, preserving frame geometry before approval."""
from pathlib import Path
import json,os,sys,argparse
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from scipy import ndimage
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/source/characters/achilles/passe_rive_walk_iso_v1'
OUT=ROOT/'artifacts/spine_trial/passe_rive_walk_iso_v1'
args=argparse.ArgumentParser();args.add_argument('direction',choices=['E','S','N','W']);args.add_argument('--version',default='v1');args.add_argument('--cols',default=4,type=int);args.add_argument('--rows',default=3,type=int);args=args.parse_args()
key=args.direction+'_'+args.version;raw=Image.open(SRC/(key+'.png')).convert('RGBA');pixels=np.asarray(raw)
if pixels[:,:,3].min()<128:mask=(pixels[:,:,3]>128)&(pixels[:,:,:3].min(2)<230)
else:mask=pixels[:,:,:3].min(2)<228
count=args.cols*args.rows
labels,_=ndimage.label(mask);sizes=np.bincount(labels.ravel());sizes[0]=0;ids=np.argsort(sizes)[-count:]
boxes=ndimage.find_objects(labels);found=[]
for ident in ids:
 yy,xx=boxes[int(ident)-1];found.append({'id':int(ident),'box':[max(0,xx.start-8),max(0,yy.start-8),min(raw.width,xx.stop+8),min(raw.height,yy.stop+8)],'center':[(xx.start+xx.stop)/2,(yy.start+yy.stop)/2]})
found.sort(key=lambda f:f['center'][1]);ordered=[]
for row in range(args.rows):ordered.extend(sorted(found[row*args.cols:(row+1)*args.cols],key=lambda f:f['center'][0]))
folder=SRC/'cutouts'/key;folder.mkdir(parents=True,exist_ok=True);(OUT/'frames').mkdir(parents=True,exist_ok=True)
restored_folder=SRC/'cutouts'/(key+'_spear_restored');restored_folder.mkdir(parents=True,exist_ok=True)
session=None;metadata=[]
os.environ['U2NET_HOME']=str(ROOT/'artifacts/dev-tools/rembg-models');os.environ['OMP_NUM_THREADS']='4'
for i,f in enumerate(ordered):
 path=folder/f'{i:02}.png';box=f['box']
 if not path.exists():
  crop=raw.crop(box)
  if pixels[:,:,3].min()>=128:
   from rembg import remove,new_session
   if session is None:session=new_session('birefnet-general-lite',providers=['CPUExecutionProvider'])
   selected=labels[box[1]:box[3],box[0]:box[2]]==f['id'];selected=ndimage.binary_dilation(ndimage.binary_fill_holes(selected),iterations=7)
   rgb=np.asarray(crop.convert('RGB')).copy();rgb[~selected]=255
   crop=remove(Image.fromarray(rgb),session=session,decontaminate=True)
  crop.save(path);print(f'CUTOUT {key} {i}',flush=True)
 im=Image.open(path).convert('RGBA')
 # A segmentation model can erase a thin lance. Restore only the narrow weapon
 # strip from the same original pixels, leaving the opaque ivory costume intact.
 q=np.asarray(raw.crop(box).convert('RGB')).astype(float)
 darkness=(q.min(2)<215);counts=darkness.sum(0)
 side=range(0,max(1,int(im.width*.32))) if args.direction in ['E','S'] else range(int(im.width*.68),im.width)
 spear_x=max(side,key=lambda x:counts[x]);weapon_width=max(10,round(im.height*.028))
 strip=np.zeros(q.shape[:2],bool);strip[:,max(0,spear_x-weapon_width):min(im.width,spear_x+weapon_width+1)]=True
 foreground=(q.min(2)<230)&strip
 core=ndimage.binary_erosion(foreground,iterations=1)
 if not core.any():core=(q.min(2)<100)&strip
 nearest=ndimage.distance_transform_edt(~core,return_distances=False,return_indices=True)
 nearest_color=q[nearest[0],nearest[1]]
 vector=255-nearest_color
 restored_alpha=np.clip(((255-q)*vector).sum(2)/np.maximum(1,(vector*vector).sum(2)),0,1)
 restored_alpha[core]=1
 restored_alpha[(q.min(2)>245)|(~strip)|(restored_alpha<.08)]=0
 current=np.asarray(im).copy();replace=strip
 color=np.where(core[:,:,None],q,nearest_color)
 current[:,:,:3][replace]=color[replace].astype('uint8');current[:,:,3][replace]=(restored_alpha[replace]*255).astype('uint8')
 im=Image.fromarray(current);path=restored_folder/f'{i:02}.png';im.save(path)
 p=np.asarray(im);bbox=im.getbbox()
 dark=(p[:,:,3]>120)&(p[:,:,:3].max(2)<140);broad=dark.sum(1)>max(10,im.width*.04)
 hits=np.flatnonzero(ndimage.uniform_filter1d(broad.astype(float),size=13)>.72);head=int(hits[0]) if len(hits) else bbox[1]
 band=p[int(head+(bbox[3]-head)*.35):int(head+(bbox[3]-head)*.51)]
 torso=(band[:,:,3]>160)&(band[:,:,:3].max(2)<170);xs=np.nonzero(torso)[1]
 centre=float(np.median(xs)) if len(xs) else (bbox[0]+bbox[2])/2
 metadata.append({'source_box':box,'bounds':list(bbox),'head':head,'torso_x':centre,'file':str(path.relative_to(ROOT)).replace('\\','/')})

# Keep the authored positions within each sheet cell. A single origin and scale
# avoid pinning each lowest foot independently, which destroys isometric travel.
heights=[m['bounds'][3]-m['head'] for m in metadata];scale=440/float(np.median(heights));frames=[]
cellw,cellh=raw.width/args.cols,raw.height/args.rows
rootx=float(np.median([m['source_box'][0]+m['torso_x']-(i%args.cols)*cellw for i,m in enumerate(metadata)]))
rooty=float(np.median([m['source_box'][1]+m['bounds'][3]-(i//args.cols)*cellh for i,m in enumerate(metadata)]))
for i,m in enumerate(metadata):
 im=Image.open(ROOT/m['file']).convert('RGBA')
 offset=[round(384+(m['source_box'][0]-(i%args.cols)*cellw-rootx)*scale),round(662+(m['source_box'][1]-(i//args.cols)*cellh-rooty)*scale)]
 dst=Image.new('RGBA',(768,768));dst.paste(im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS),tuple(offset))
 bounds=dst.getbbox()
 if min(bounds[:2])<2 or bounds[2]>766 or bounds[3]>766:raise RuntimeError(f'Clipped frame {key}/{i}: {bounds}')
 dst.save(OUT/'frames'/f'{key}_{i:02}.png');frames.append(dst);m.update(scale=scale,offset=offset,registered_bounds=list(bounds))
 # Diagnostic ankle-cuff candidates, not claimed as proven foot contacts.
 arr=np.asarray(dst).astype(int);region=np.zeros((768,768),bool);region[500:700]=True
 bronze=(arr[:,:,3]>160)&(arr[:,:,0]>arr[:,:,1]+8)&(arr[:,:,1]>arr[:,:,2]+8)&(arr[:,:,1]>45)&region
 lab,n=ndimage.label(bronze);parts=[]
 for ident,sl in enumerate(ndimage.find_objects(lab),1):
  if sl is None:continue
  yy,xx=sl;area=int((lab[yy,xx]==ident).sum())
  if area>=12 and xx.stop-xx.start>=4:parts.append({'center':[(xx.start+xx.stop)/2,(yy.start+yy.stop)/2],'area':area})
 m['ankle_candidates']=parts
(SRC/(key+'_registration.json')).write_text(json.dumps(metadata,indent=2))
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
sheet=Image.new('RGB',(1536,1536),'#263835');draw=ImageDraw.Draw(sheet)
for i,im in enumerate(frames):
 thumb=im.resize((384,384));sheet.paste(thumb,(i%4*384,i//4*512),thumb)
 feet=im.crop((220,490,550,700)).resize((330,210));sheet.paste(feet,(i%4*384+20,i//4*512+300),feet)
 draw.text((i%4*384+12,i//4*512+10),str(i+1),font=font,fill='white')
sheet.save(OUT/(key+'_contact.jpg'),quality=92)
audit={ 'direction':args.direction,'version':args.version,'frames':count,'canvas':[768,768],'pivot':[384,662],'scale':scale,'status':'UNREVIEWED','checks':{'alpha':True,'not_clipped':True,'fixed_clip_scale':True},'poses':metadata}
(OUT/(key+'_audit.json')).write_text(json.dumps(audit,indent=2))
print(json.dumps({'key':key,'frames':count,'scale':scale,'ready_for_visual_review':True}))
