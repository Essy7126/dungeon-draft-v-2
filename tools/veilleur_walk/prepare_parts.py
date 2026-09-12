from pathlib import Path
import os,json,io,zipfile,sys,xml.etree.ElementTree as ET
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from scipy import ndimage
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/source/characters/achilles/veilleur_walk_E_v1'
PARTS=SRC/'parts';PARTS.mkdir(exist_ok=True)
os.environ['U2NET_HOME']=str(ROOT/'artifacts/dev-tools/rembg-models')
os.environ['OMP_NUM_THREADS']='4'
from rembg import remove,new_session
session=new_session('birefnet-general-lite',providers=['CPUExecutionProvider'])
raw=Image.open(SRC/'parts_raw.png').convert('RGB')
names=['arm_R','arm_L','hand_R','hand_L','thigh_R','thigh_L','shin_R','shin_L','flat_R','flat_L','toe_R','toe_L','swing_R','swing_L','heel_R','heel_L']
report=[]
for index,name in enumerate(names):
    path=PARTS/f'{name}.png'
    if not path.exists() or '--refresh' in sys.argv:
        x,y=index%4,index//4
        box=(round(x*raw.width/4)+4,round(y*raw.height/4)+4,round((x+1)*raw.width/4)-4,round((y+1)*raw.height/4)-4)
        original=raw.crop(box)
        clean=remove(original,session=session,decontaminate=True)
        px=np.asarray(clean).copy();labels,count=ndimage.label(px[:,:,3]>40)
        counts=np.bincount(labels.ravel());counts[0]=0
        keep=ndimage.binary_dilation(labels==int(counts.argmax()),iterations=3)
        px[~keep]=0;px[px[:,:,3]<5]=0
        filled=ndimage.binary_fill_holes(px[:,:,3]>32)
        holes=(filled&(px[:,:,3]<16))|(ndimage.binary_erosion(filled,iterations=3)&(px[:,:,3]<240))
        px[holes,:3]=np.asarray(original)[holes];px[holes,3]=255
        clean=Image.fromarray(px);clean=clean.crop(clean.getchannel('A').getbbox())
        # Trim the drawn hollow caps where adjacent segments overlap.
        if name.startswith('arm_'):
            px=np.asarray(clean).copy();px[int(clean.height*.90):]=0;clean=Image.fromarray(px)
        if name.startswith('thigh_'):
            px=np.asarray(clean).copy();px[int(clean.height*.90):]=0;clean=Image.fromarray(px)
        clean.save(path)
        print(name,clean.size,flush=True)
    report.append({'name':name,'size':Image.open(path).size})

# Preserve the selected model's head, tunic and scarf pixels.
canon=Image.open(ROOT/'art/source/characters/achilles/serment_cendre_concept_v1/candidate_c.png').convert('RGBA')
shapes={
 'head':[(478,10),(789,10),(789,302),(742,359),(670,375),(553,350),(482,315)],
 'body':[(477,324),(550,305),(684,305),(750,338),(778,381),(756,470),(742,558),(746,603),(776,716),(709,742),(642,750),(578,736),(510,714),(536,635),(540,603),(506,614),(488,592),(510,480),(473,437),(458,395),(451,354)]}
boxes={}
for name,points in shapes.items():
    mask=Image.new('L',canon.size);ImageDraw.Draw(mask).polygon(points,fill=255)
    p=np.asarray(canon).copy();p[:,:,3]=np.minimum(p[:,:,3],np.asarray(mask));p[p[:,:,3]==0]=0
    cut=Image.fromarray(p);box=cut.getchannel('A').getbbox();boxes[name]=box;cut.crop(box).save(PARTS/f'{name}.png');names.append(name)

W,H=1536,2560
root=ET.Element('image',{'version':'0.0.3','w':str(W),'h':str(H),'name':'Veilleur — pieces de marche E'})
stack=ET.SubElement(root,'stack');atlas=Image.new('RGBA',(W,H));parts={}
def png(im):
    b=io.BytesIO();im.save(b,format='PNG');return b.getvalue()
with zipfile.ZipFile(SRC/'source_parts.ora','w') as z:
    z.writestr('mimetype','image/openraster',compress_type=zipfile.ZIP_STORED)
    for index,name in enumerate(names):
        im=Image.open(PARTS/f'{name}.png').convert('RGBA');x=index%4*384+(384-im.width)//2;y=index//4*512+40
        parts[name]={'origin':[x,y],'size':list(im.size)}
        if name in boxes:parts[name]['canon_origin']=list(boxes[name][:2])
        member=f'data/{name}.png';ET.SubElement(stack,'layer',{'name':name,'src':member,'x':str(x),'y':str(y),'opacity':'1.0','visibility':'visible','composite-op':'svg:src-over'})
        z.writestr(member,png(im));atlas.alpha_composite(im,(x,y))
    z.writestr('stack.xml',ET.tostring(root,encoding='UTF-8',xml_declaration=True));z.writestr('mergedimage.png',png(atlas))
    thumb=atlas.copy();thumb.thumbnail((256,256));z.writestr('Thumbnails/thumbnail.png',png(thumb))
(SRC/'parts_layout.json').write_text(json.dumps(parts,indent=2))
(SRC/'extraction.json').write_text(json.dumps(report,indent=2))
bg=Image.new('RGBA',atlas.size,'#253b40');bg.alpha_composite(atlas);d=ImageDraw.Draw(bg);font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',22)
for i,name in enumerate(names):d.text((i%4*384+20,i//4*512+5),name,font=font,fill='white')
bg.convert('RGB').save(SRC/'parts_review.jpg',quality=94)
print('PARTS_READY',flush=True)
