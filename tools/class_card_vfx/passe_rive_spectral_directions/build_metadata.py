from pathlib import Path
import json,copy
GAME=Path(__file__).resolve().parents[3]
out=GAME/'assets/characters/PasseRive/sprites_s31_spectral';out.mkdir(parents=True,exist_ok=True)
old=json.loads((GAME/'assets/characters/PasseRive/sprites_s29/passage.json').read_text(encoding='utf8'))
drain=json.loads((GAME/'assets/characters/PasseRive/sprites_s31_drain/drain.json').read_text(encoding='utf8'))
mapping=[0,1,7,8,8,8,7,2,1,10,11,11]
views={'SE':dict(old,texture='res://assets/characters/PasseRive/sprites_s29/passage.png',support=[-18.3333584,17.19648])}
for direction in ['E','W','NE','NW','S','N','SW']:
    base=drain['views'][direction]
    indices=[base['sequence'][i] for i in mapping]
    views[direction]={k:copy.deepcopy(base[k]) for k in ['texture','source_height','width_factor','support','palette','source_sha256']}
    views[direction].update(duration_ms=old['duration_ms'],frames=[copy.deepcopy(base['frames'][i]) for i in indices],veil=old['veil'],source_pose_indices=indices)
assert all(sum(v['duration_ms'])==860 and len(v['frames'])==12 for v in views.values())
(out/'passage.json').write_text(json.dumps(dict(version='S31-spectral-registered-shared-poses',views=views),indent=2),encoding='utf8')
print('Eight spectral views registered; shared pixels unchanged.')

