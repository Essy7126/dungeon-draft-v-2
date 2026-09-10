"""Birefnet matte, preserving ivory clothing. White-key experiment was rejected."""
from pathlib import Path
import os,json
ROOT=Path(__file__).resolve().parents[2]
os.environ['U2NET_HOME']=str(ROOT/'artifacts/dev-tools/rembg-models')
os.environ['OMP_NUM_THREADS']='4'
from rembg import remove,new_session
from PIL import Image
import numpy as np
from scipy import ndimage
SRC=ROOT/'art/source/characters/achilles/passe_rive_spells_v1'
OUT=SRC/'matte_frames';OUT.mkdir(exist_ok=True)
data=json.loads((Path(__file__).parent/'layout.json').read_text(encoding='utf8'))
session=new_session('birefnet-general-lite',providers=['CPUExecutionProvider'])
for a in data['actions']:
    raw=Image.open(SRC/f"{a['id']}_rgb.png").convert('RGB')
    for i,box in enumerate(a['boxes']):
        output=OUT/f"{a['id']}_{i:02}.png"
        if output.exists():
            print(f'Cached {output.name}',flush=True);continue
        image=remove(raw.crop(box),session=session,decontaminate=True)
        px=np.asarray(image).copy()
        labels,count=ndimage.label(px[:,:,3]>32)
        sizes=np.bincount(labels.ravel());sizes[0]=0
        main=labels==int(sizes.argmax())
        support=ndimage.binary_dilation(main,iterations=5)
        px[~support]=0
        px[px[:,:,3]<3]=0
        Image.fromarray(px).save(output)
        print(f'MATTE_READY {output.name}',flush=True)
print('SIX_SHEETS_CUTOUT_READY',flush=True)
