"""Isolate authored poses and register whole drawings; never warp limbs or mirror art."""
from pathlib import Path
import json,os,sys
import numpy as np
from PIL import Image,ImageDraw
from scipy import ndimage
ROOT=Path(__file__).resolve().parents[2];SRC=ROOT/'art/source/characters/achilles/passe_rive_iso_v1'
os.environ['U2NET_HOME']=str(ROOT/'artifacts/dev-tools/rembg-models');os.environ['OMP_NUM_THREADS']='4'
from rembg import remove,new_session
session=None

def components(raw,count):
    px=np.asarray(raw.convert('RGB'));mask=px.min(2)<228
    labels,_=ndimage.label(mask)
    sizes=np.bincount(labels.ravel());sizes[0]=0
    ids=np.argsort(sizes)[-count:]
    if min(sizes[ids])<1000:raise RuntimeError('Not enough distinct painted figures')
    boxes=ndimage.find_objects(labels)
    found=[]
    for ident in ids:
        yy,xx=boxes[int(ident)-1]
        found.append({'box':[max(0,xx.start-9),max(0,yy.start-9),min(raw.width,xx.stop+9),min(raw.height,yy.stop+9)],'id':int(ident),'center':[(xx.start+xx.stop)/2,(yy.start+yy.stop)/2]})
    return labels,found

def head_top(im):
    p=np.asarray(im.convert('RGBA'));dark=(p[:,:,3]>100)&(p[:,:,:3].max(2)<140)
    broad=dark.sum(1)>max(12,im.width*.043)
    smooth=ndimage.uniform_filter1d(broad.astype(float),size=19)
    hits=np.flatnonzero(smooth>.72)
    return int(hits[0]) if len(hits) else im.getbbox()[1]

all_reports={}
for sheet in json.loads((SRC/'sheets.json').read_text(encoding='utf8')):
    path=SRC/sheet['file']
    if not path.exists():continue
    raw=Image.open(path);count=sheet['cols']*sheet['rows']
    labels,found=components(raw,count)
    # Rows follow the drawing's centre, independently of projecting weapon tips.
    found.sort(key=lambda f:f['center'][1]);ordered=[]
    for row in range(sheet['rows']):ordered.extend(sorted(found[row*sheet['cols']:(row+1)*sheet['cols']],key=lambda f:f['center'][0]))
    preview=raw.convert('RGB');draw=ImageDraw.Draw(preview)
    clips={}
    for index,f in enumerate(ordered):
        box=f['box'];draw.rectangle(box,outline='red',width=2);draw.text((box[0]+3,box[1]+3),str(index),fill='red')
    preview.thumbnail((1000,1500));preview.save(SRC/(path.stem+'_boxes.jpg'))
    for direction,indices in sheet['clips'].items():
        action=sheet['action'];clip=[]
        folder=SRC/'matte'/f'{action}_{direction}';folder.mkdir(parents=True,exist_ok=True)
        for i,index in enumerate(indices):
            f=ordered[index];box=f['box'];dest=folder/f'{i:02}.png'
            if not dest.exists():
                region=labels[box[1]:box[3],box[0]:box[2]]==f['id']
                region=ndimage.binary_fill_holes(region)
                region=ndimage.binary_dilation(region,iterations=7)
                crop=np.asarray(raw.convert('RGB').crop(box)).copy();crop[~region]=255
                if session is None:session=new_session('birefnet-general-lite',providers=['CPUExecutionProvider'])
                matte=remove(Image.fromarray(crop),session=session,decontaminate=True)
                matte.save(dest)
                print(f'MATTE {action}_{direction}_{i}',flush=True)
            im=Image.open(dest).convert('RGBA');bounds=im.getchannel('A').getbbox()
            if bounds is None:raise RuntimeError(f'Empty {dest}')
            p=np.asarray(im);head=head_top(im)
            band=p[max(head,int(bounds[3]-(bounds[3]-head)*.2)):bounds[3],:,3]>160
            xs=np.nonzero(band)[1]
            anchor_x=float((xs.min()+xs.max())*.5) if len(xs) else (bounds[0]+bounds[2])*.5
            clip.append({'file':dest.relative_to(ROOT).as_posix(),'box':box,'bounds':list(bounds),'head_y':head,'anchor':[anchor_x,bounds[3]-1]})
        all_reports[f'{action}_{direction}']={'sheet':sheet['file'],'poses':clip}
(SRC/'extraction.json').write_text(json.dumps(all_reports,indent=2),encoding='utf8')
print(json.dumps({'extracted_clips':len(all_reports),'poses':sum(len(c['poses']) for c in all_reports.values())}))
