"""Lossless Blender atlas assembly with alpha-margin and pixel checks."""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[3]
SRC=ROOT/'art/source/vfx/contre'
OUT=ROOT/'vfx/class_cards/contre'
RENDER=ROOT/'artifacts/dev/class_card_vfx/contre/render'
OUT.mkdir(parents=True,exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((SRC/'manifest.json').read_text())
review=Image.new('RGB',(1536,768),'#394a5e');draw=ImageDraw.Draw(review)
for index,(name,asset) in enumerate(manifest['assets'].items()):
    size=asset['size'];count=asset['frames'];cols=6;rows=(count+cols-1)//cols
    atlas=Image.new('RGBA',(size*cols,size*rows));frames=[]
    for i in range(count):
        p=RENDER/name/f'frame_{i+1:04}.png';im=Image.open(p).convert('RGBA');b=im.getchannel('A').getbbox()
        assert im.size==(size,size)
        assert b is not None and b[0]>0 and b[1]>0 and b[2]<size and b[3]<size,(name,i,b)
        x,y=i%cols*size,i//cols*size;atlas.paste(im,(x,y))
        assert atlas.crop((x,y,x+size,y+size)).tobytes()==im.tobytes()
        frames.append({'sha256':sha(p),'alpha_bounds':b})
    dest=OUT/(name+'.png');atlas.save(dest)
    asset.update({'columns':cols,'rows':rows,'sha256':sha(dest),'rendered_frames':frames})
    for row,frame in enumerate([min(2,count),min(6,count)]):
        im=Image.open(RENDER/name/f'frame_{frame:04}.png').convert('RGBA');im.thumbnail((360,340))
        review.paste(im,(index*384+(384-im.width)//2,row*384+34),im)
        draw.text((index*384+16,row*384+10),f'{name} / {frame}',fill='white')
manifest['blend_sha256']=sha(SRC/'contre.blend')
manifest['script_sha256']=sha(ROOT/'tools/class_card_vfx/contre/build.py')
(OUT/'provenance.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
review.save(RENDER.parent/'model_review.png')
print(json.dumps({'passed':True,'frames':sum(a['frames'] for a in manifest['assets'].values()),'pixel_roundtrip':True}))


