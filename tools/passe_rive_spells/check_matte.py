from pathlib import Path
import os
ROOT=Path(__file__).resolve().parents[2]
os.environ['U2NET_HOME']=str(ROOT/'artifacts/dev-tools/rembg-models')
os.environ['OMP_NUM_THREADS']='4'
from rembg import remove,new_session
from PIL import Image
import numpy as np
SRC=ROOT/'art/source/characters/achilles/passe_rive_spells_v1'
im=Image.open(SRC/'strike_rgb.png').crop((575,70,1248,570))
s=new_session('birefnet-general-lite',providers=['CPUExecutionProvider'])
rgba=remove(im,session=s,decontaminate=True)
rgba.save(SRC/'rembg_probe.png')
bg=Image.new('RGBA',im.size,'#21372e');bg.alpha_composite(rgba);bg.convert('RGB').save(ROOT/'artifacts/spine_trial/passe_rive_spells_v1/rembg_probe_flat.png')
print('REMOVAL_PROBE_READY')
