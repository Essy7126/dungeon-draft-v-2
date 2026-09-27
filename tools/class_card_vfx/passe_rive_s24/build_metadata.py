"""Read-only source measurements. Never rewrite, resize or recolor source pixels."""
from pathlib import Path
import hashlib, importlib.util, json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
GAME = ROOT.parents[2]
spec = importlib.util.spec_from_file_location('palette', ROOT.parent / 'build_passe_rive_palette.py')
palette = importlib.util.module_from_spec(spec)
spec.loader.exec_module(palette)
source = ROOT / 'assets/kick_b.png'
rgba = np.asarray(Image.open(source))
h, w = rgba.shape[:2]
frames = []
for i in range(8):
    x0, x1 = round(i % 4 * w / 4), round((i % 4 + 1) * w / 4)
    y0, y1 = round(i // 4 * h / 2), round((i // 4 + 1) * h / 2)
    ys, xs = np.where(rgba[y0:y1, x0:x1, 3] > 220)
    bottom = int(ys.max())
    sole = [float(np.median(xs[ys > bottom - 5])), bottom + 1]
    frames.append(dict(region=[x0,y0,x1-x0,y1-y0], pivot=sole,
                       solid_bbox=[int(xs.min()),int(ys.min()),int(xs.max()),bottom]))
target = palette.colors(GAME / 'assets/characters/PasseRive/autosprite_v1/PasseRive-iso_idle_southeast-v1.png')
colors = palette.colors(source)
data = dict(source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
            source_height=frames[0]['pivot'][1]-frames[0]['solid_bbox'][1],
            duration_ms=[80,80,100,50,70,80,90,100], contact_frame=4,
            frames=frames, palette={})
for group, center in colors.items():
    data['palette'][group] = dict(center=center.tolist(), gain=np.clip(target[group]/center,.65,1.5).tolist())
(ROOT/'metadata.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
print(json.dumps(dict(frames=len(frames), source_height=data['source_height'], sha256=data['source_sha256'])))
