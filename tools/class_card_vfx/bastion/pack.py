"""Copy transparent Blender frames unchanged into two layered game atlases."""
import hashlib
import json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
meta=json.loads((ROOT/'art/source/vfx/bastion_vivant/manifest.json').read_text())
out=ROOT/'vfx/class_cards/bastion'
out.mkdir(parents=True,exist_ok=True)
meta['exports']={}
for layer in meta['layers']:
    atlas=Image.new('RGBA',(384*8,384*6))
    frames=[]
    for i in range(48):
        path=ROOT/f'artifacts/dev/class_card_vfx/bastion/render/{layer}/frame_{i+1:04d}.png'
        frame=Image.open(path).convert('RGBA')
        assert frame.size==(384,384)
        bounds=frame.getbbox()
        assert frame.getchannel('A').getextrema()[0]==0
        if bounds:
            assert min(bounds[:2])>0 and max(bounds[2:])<384,(i,bounds)
        atlas.paste(frame,((i%8)*384,(i//8)*384))
        frames.append({'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bounds':bounds})
    atlas.save(out/f'{layer}.png')
    meta['exports'][layer]={'sha256':hashlib.sha256((out/f'{layer}.png').read_bytes()).hexdigest(),'frames':frames}
(out/'provenance.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'layers':2,'frames_per_layer':48,'pixels_preserved':True,'pivot':meta['pivot_pixels']}))
