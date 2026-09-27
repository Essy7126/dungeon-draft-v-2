"""Lossless atlas packing and pixel/alpha provenance for Blender exports."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[3]
SOURCE=ROOT/'art/source/vfx/approved_spells'
OUTPUT=ROOT/'vfx/class_cards/approved'
RENDERS=ROOT/'artifacts/dev/class_card_vfx/approved/render'
OUTPUT.mkdir(parents=True,exist_ok=True)
manifest=json.loads((SOURCE/'manifest.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
review=Image.new('RGB',(1536,768),'#25333d')
draw=ImageDraw.Draw(review)
poses=[('hook',1),('link',1),('link_edge',1),('arrow',1),('ice',9),('ice',24),('reap',6),('reap',10)]
for name,asset in manifest['assets'].items():
    count,size=asset['frames'],asset['size']
    cols=min(count,6);rows=(count+cols-1)//cols
    atlas=Image.new('RGBA',(cols*size,rows*size))
    frames=[]
    for i in range(count):
        path=RENDERS/name/f'frame_{i+1:04}.png'
        img=Image.open(path).convert('RGBA')
        assert img.size==(size,size)
        bounds=img.getchannel('A').getbbox()
        assert bounds is None or (bounds[0]>0 and bounds[1]>0 and bounds[2]<size and bounds[3]<size),(name,i,bounds)
        box=(i%cols*size,i//cols*size)
        atlas.paste(img,box)
        assert atlas.crop((box[0],box[1],box[0]+size,box[1]+size)).tobytes()==img.tobytes()
        frames.append({'sha256':sha(path),'alpha_bounds':bounds})
    dest=OUTPUT/(name+'.png');atlas.save(dest)
    asset.update({'columns':cols,'rows':rows,'sha256':sha(dest),'rendered_frames':frames})
for index,(name,frame) in enumerate(poses):
    img=Image.open(RENDERS/name/f'frame_{frame:04}.png').convert('RGBA')
    x=index%4*384+(384-img.width)//2;y=index//4*384+32
    review.paste(img,(x,y),img)
    draw.text((index%4*384+16,index//4*384+12),f'{name} / {frame}',fill='white')
review.save(RENDERS.parent/'model_review.png')
manifest['blend_sha256']=sha(SOURCE/'approved_spells.blend')
manifest['script_sha256']=sha(ROOT/'tools/class_card_vfx/approved/build.py')
(OUTPUT/'provenance.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'assets':len(manifest['assets']),'frames':sum(a['frames'] for a in manifest['assets'].values()),'pixel_roundtrip':True}))
