"""Measure original generated PNGs without changing their pixels."""
from pathlib import Path
import hashlib, importlib.util, json
import numpy as np
from PIL import Image

GAME = Path(__file__).resolve().parents[3]
OUT = GAME / 'assets/characters/PasseRive/sprites_s29'
spec = importlib.util.spec_from_file_location('palette', GAME / 'tools/class_card_vfx/build_passe_rive_palette.py')
palette = importlib.util.module_from_spec(spec)
spec.loader.exec_module(palette)

def measure(path, columns, rows):
    rgba = np.asarray(Image.open(path).convert('RGBA'))
    h, w = rgba.shape[:2]
    frames = []
    for i in range(columns * rows):
        x0, x1 = round(i % columns * w / columns), round((i % columns + 1) * w / columns)
        y0, y1 = round(i // columns * h / rows), round((i // columns + 1) * h / rows)
        ys, xs = np.where(rgba[y0:y1, x0:x1, 3] > 220)
        bottom = int(ys.max())
        frames.append(dict(region=[x0,y0,x1-x0,y1-y0], pivot=[float(np.median(xs[ys>bottom-5])),bottom+1],
                           solid_bbox=[int(xs.min()),int(ys.min()),int(xs.max())+1,bottom+1]))
    return frames

source = OUT / 'passage.png'
frames = measure(source,4,3)
target = palette.colors(GAME / 'assets/characters/PasseRive/autosprite_v1/PasseRive-iso_idle_southeast-v1.png')
colors = palette.colors(source)
data = dict(version='S29-v01',direction='SE',source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
            source_height=frames[0]['pivot'][1]-frames[0]['solid_bbox'][1],width_factor=.85,
            duration_ms=[40,55,65,65,55,90,65,75,85,85,90,90],release_ms=310,release_frame=5,
            frames=frames,palette={})
for group,center in colors.items():
    data['palette'][group]=dict(center=center.tolist(),gain=np.clip(target[group]/center,.65,1.5).tolist())
fx = OUT / 'veil.png'
vframes = measure(fx,4,2)
# Preserve the authored changing extent: a small wisp must not be upscaled to body height.
# The base anchor stays at the common bottom; center in the two full-height departure cells.
fx_width = Image.open(fx).width / 4
for frame in vframes:
    frame['pivot'] = [fx_width * .5, frame['pivot'][1]]
data['veil'] = dict(frames=vframes, source_height=vframes[2]['pivot'][1]-vframes[2]['solid_bbox'][1],
                    source_sha256=hashlib.sha256(fx.read_bytes()).hexdigest())
(OUT/'passage.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
print(json.dumps(dict(source_height=data['source_height'], heights=[f['solid_bbox'][3]-f['solid_bbox'][1] for f in frames], pivots=[f['pivot'] for f in frames],fx_height=data['veil']['source_height'])))
