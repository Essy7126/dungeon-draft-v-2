"""Birefnet matte, preserving ivory clothing. White-key experiment was rejected."""
from pathlib import Path
import os,json
ROOT=Path(__file__).resolve().parents[2]
os.environ['U2NET_HOME']=str(ROOT/'artifacts/dev-tools/rembg-models')
os.environ['OMP_NUM_THREADS']='4'
from rembg import remove,new_session
from PIL import Image,ImageDraw
import numpy as np
from scipy import ndimage
SRC=ROOT/'art/source/characters/achilles/passe_rive_spells_v1'
OUT=SRC/'matte_frames';OUT.mkdir(exist_ok=True)
data=json.loads((Path(__file__).parent/'layout.json').read_text(encoding='utf8'))
session=new_session('birefnet-general-lite',providers=['CPUExecutionProvider'])
for a in data['actions']:
    source_dir=ROOT/a['source_dir'] if 'source_dir' in a else SRC
    raw=Image.open(source_dir/a.get('source_file',f"{a['id']}_rgb.png")).convert('RGB')
    for i,box in enumerate(a['boxes']):
        output=OUT/f"{a['id']}_{i:02}.png"
        if output.exists():
            print(f'Cached {output.name}',flush=True);continue
        isolated=raw.copy()
        for excluded in a.get('exclude_rects',[[]]*len(a['boxes']))[i]:
            ImageDraw.Draw(isolated).rectangle(excluded,fill='white')
        image=remove(isolated.crop(box),session=session,decontaminate=True)
        if a['id'] in ['sky_bow','ivory_bow']:
            # Fine bow strings may form separate alpha components. Keep the complete matte.
            image.save(output)
            print(f'MATTE_READY {output.name}',flush=True)
            continue
        px=np.asarray(image).copy()
        labels,count=ndimage.label(px[:,:,3]>32)
        sizes=np.bincount(labels.ravel());sizes[0]=0
        main=labels==int(sizes.argmax())
        support=ndimage.binary_dilation(main,iterations=5)
        px[~support]=0
        px[px[:,:,3]<3]=0
        Image.fromarray(px).save(output)
        print(f'MATTE_READY {output.name}',flush=True)
print('PALETTE_CUTOUT_READY',flush=True)
