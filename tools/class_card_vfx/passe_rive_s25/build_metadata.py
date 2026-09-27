"""Measure the generated atlas and register it without changing source pixels."""
from pathlib import Path
import hashlib, importlib.util, json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
GAME = ROOT.parents[2]
source = GAME / 'assets/characters/PasseRive/sprites_s25/pull.png'
spec = importlib.util.spec_from_file_location('palette', ROOT.parent / 'build_passe_rive_palette.py')
palette = importlib.util.module_from_spec(spec)
spec.loader.exec_module(palette)
rgba = np.asarray(Image.open(source))
h, w = rgba.shape[:2]
# Hand landmarks inspected on the unchanged 362px square source cells.
hands = [[232,198],[263,181],[232,142],[318,108],[321,90],[322,97],
         [224,156],[198,148],[264,143],[266,184],[249,189],[261,194]]
frames = []
for i in range(12):
    x0,x1=round(i%4*w/4),round((i%4+1)*w/4)
    y0,y1=round(i//4*h/3),round((i//4+1)*h/3)
    ys,xs=np.where(rgba[y0:y1,x0:x1,3]>220)
    bottom=int(ys.max())
    frames.append(dict(region=[x0,y0,x1-x0,y1-y0],
                       pivot=[float(np.median(xs[ys>bottom-5])),bottom+1],
                       hand=[hands[i][0]*(x1-x0)/362,hands[i][1]*(y1-y0)/362],
                       solid_bbox=[int(xs.min()),int(ys.min()),int(xs.max()),bottom]))
data = dict(source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
            source_height=frames[0]['pivot'][1]-frames[0]['solid_bbox'][1],
            sequence=[0,1,3,4,5,6,7,8,9,10,11],
            duration_ms=[60,100,60,80,100,70,100,80,80,80,80],
            release_ms=400,release_frame=6,frames=frames,palette={})
target=palette.colors(GAME / 'assets/characters/PasseRive/autosprite_v1/PasseRive-iso_idle_southeast-v1.png')
for group,center in palette.colors(source).items():
    data['palette'][group]=dict(center=center.tolist(),gain=np.clip(target[group]/center,.65,1.5).tolist())
(source.with_suffix('.json')).write_text(json.dumps(data,indent=2),encoding='utf-8')
print(json.dumps(dict(sha256=data['source_sha256'],source_height=data['source_height'],duration=sum(data['duration_ms']))))
