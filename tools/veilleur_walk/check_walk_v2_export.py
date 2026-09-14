from pathlib import Path
import json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/spine_trial/veilleur_walk_E_v2'
frames=[Image.open(OUT/f'frames/{i:02}.png').convert('RGBA') for i in range(48)]
animation=Image.open(OUT/'walk.png');assert animation.n_frames==48
duration=0;diffs=[]
for i,frame in enumerate(frames):
    animation.seek(i);duration+=animation.info['duration']
    diffs.append(int(np.any(np.asarray(frame)!=np.asarray(animation.convert('RGBA')),axis=2).sum()))
assert max(diffs)==0 and abs(duration-1100)<.01
atlas=Image.open(OUT/'atlas.png').convert('RGBA');assert atlas.size==(4096,3072)
for i,frame in enumerate(frames):
    tile=atlas.crop(((i%8)*512,(i//8)*512,(i%8+1)*512,(i//8+1)*512))
    assert np.array_equal(np.asarray(frame),np.asarray(tile))
webp=Image.open(OUT/'walk.webp');assert webp.n_frames==48
report={'apng_frame_count':48,'duration_ms':duration,'apng_changed_pixels_by_frame':diffs,'atlas_matches_all_frames':True,'webp_frame_count':webp.n_frames,
    'scope':'Animation and atlas encode the actual 48 PNG frames. Does not establish walk quality.'}
(OUT/'export_report.json').write_text(json.dumps(report,indent=2))
print(json.dumps({'apng_frames':48,'duration_ms':duration,'changed_pixels':max(diffs),'atlas_matches':True}))
