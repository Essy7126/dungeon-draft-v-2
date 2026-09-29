"""Measure original generated atlases; no source pixel edits or resampling."""
from pathlib import Path
import hashlib, importlib.util, json
import numpy as np
from PIL import Image

GAME = Path(__file__).resolve().parents[3]
OUT = GAME / 'assets/characters/PasseRive/sprites_s30'
spec = importlib.util.spec_from_file_location('palette', GAME / 'tools/class_card_vfx/build_passe_rive_palette.py')
palette = importlib.util.module_from_spec(spec)
spec.loader.exec_module(palette)

def bounds(a):
    ys, xs = np.where(a[:,:,3] > 220)
    return [int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1]

source = OUT / 'renew.png'
im = Image.open(source)
assert im.mode == 'RGBA'
rgba = np.asarray(im)
h,w = rgba.shape[:2]
assert (w,h) == (1448,1086)
hands = [
    [[138,231],[234,182]], [[104,214],[255,181]], [[126,229],[266,202]],
    [[104,173],[294,158]], [[75,150],[311,120]], [[71,94],[294,31]],
    [[74,118],[295,33]], [[72,125],[308,60]], [[65,136],[310,120]],
    [[108,201],[271,184]], [[148,224],[254,182]], [[135,215],[246,182]],
]
frames=[]
for i in range(12):
    x,y=i%4*362,i//4*362
    a=rgba[y:y+362,x:x+362]
    box=bounds(a)
    ys,xs=np.where(a[:,:,3]>220)
    pivot=[float(np.median(xs[ys>=box[3]-6])),box[3]]
    frames.append(dict(region=[x,y,362,362],pivot=pivot,solid_bbox=box,hands=hands[i]))
target=palette.colors(GAME/'assets/characters/PasseRive/autosprite_v1/PasseRive-iso_idle_southeast-v1.png')
colors=palette.colors(source)
data=dict(version='S30-v01',direction='SE',source_height=frames[0]['solid_bbox'][3]-frames[0]['solid_bbox'][1],
          width_factor=.85,frames=frames,
          sequence=list(range(12)),duration_ms=[50,70,90,80,70,90,130,110,110,100,100,120],
          short_sequence=[0,1,2,3,4,8,9,10,11],short_duration_ms=[40,50,70,90,170,100,100,80,120],
          palette={group:dict(center=center.tolist(),gain=np.clip(target[group]/center,.65,1.5).tolist()) for group,center in colors.items()},
          source_sha256=hashlib.sha256(source.read_bytes()).hexdigest())
fx=OUT/'vfx.png'
a=np.asarray(Image.open(fx))
assert a.shape==(887,1774,4)
vframes=[]
for i in range(8):
    x0,x1=round(i%4*1774/4),round((i%4+1)*1774/4)
    # The generated upper row is slightly taller. Measured empty gutter is y=464..521.
    y0,y1=(0,490) if i<4 else (490,887)
    cell=a[y0:y1,x0:x1]
    box=bounds(cell)
    ys,xs=np.where(cell[:,:,3]>220)
    tip=[float(np.median(xs[ys<=box[1]+5])),box[1]]
    base=[float(np.median(xs[ys>=box[3]-6])),box[3]]
    vframes.append(dict(region=[x0,y0,x1-x0,y1-y0],solid_bbox=box,tip=tip,base=base))
data['vfx']=dict(frames=vframes,plume_anchor=[221.75,437],plume_height=380,facet_center=[221.75,180],facet_height=270,
                 source_sha256=hashlib.sha256(fx.read_bytes()).hexdigest())
(OUT/'renew.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
print(json.dumps(dict(source_height=data['source_height'],body_bounds=[f['solid_bbox'] for f in frames],vfx_bounds=[f['solid_bbox'] for f in vframes],
                     durations=[sum(data['duration_ms']),sum(data['short_duration_ms'])],alpha_clear=int((rgba[:,:,3]==0).sum()))))
