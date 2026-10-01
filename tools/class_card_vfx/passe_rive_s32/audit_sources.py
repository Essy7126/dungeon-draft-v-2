from pathlib import Path
import json,hashlib
from PIL import Image
G=Path(__file__).resolve().parents[3]
root=G/'assets/characters/PasseRive/sprites_s32'
meta=json.loads((root/'recenter.json').read_text(encoding='utf8'))
assert set(meta['views'])==set(['N','NE','E','SE','S','SW','W','NW'])
rows=[]
for direction,v in meta['views'].items():
 p=G/v['texture'].removeprefix('res://');source=G/'art/source/passe_rive_s32/sources'/p.name
 assert p.read_bytes()==source.read_bytes()
 assert hashlib.sha256(p.read_bytes()).hexdigest()==v['source_sha256']
 w,h=Image.open(p).size
 assert sum(v['duration_ms'])==800 and sum(v['duration_ms'][:6])==360
 assert v['source_height']>0 and v['width_factor']>0 and len(v['frames'])==12
 for f in v['frames']:
  x,y,rw,rh=f['region'];assert min(x,y)>=0 and x+rw<=w and y+rh<=h
  assert 0<=f['pivot'][0]<rw and 0<f['pivot'][1]<=rh
  assert 0<=f['hand'][0]<rw and 0<=f['hand'][1]<rh
 maximum=max(abs(f['solid_height']/v['source_height']-1) for f in v['frames'])
 assert maximum<.02
 rows.append(dict(direction=direction,texture=p.name,sha256=v['source_sha256'],poses=12,source_height=v['source_height'],maximum_stature_variation=maximum))
report=dict(passed=True,views=rows,frames=96,mirrors=False,pixel_edits=False)
(G/'art/source/passe_rive_s32/source_audit.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(json.dumps(dict(passed=True,views=len(rows),frames=96)))
