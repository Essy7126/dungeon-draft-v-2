"""Assemble genuine Godot captures, preserving source sprite images."""
from pathlib import Path
import argparse,json,shutil
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('poses',type=Path);p.add_argument('combat',type=Path);a=p.parse_args()
game=Path(__file__).resolve().parents[3]
out=game/'art/source/passe_rive_s31/pull/review';out.mkdir(parents=True,exist_ok=True)
samples=json.loads((a.poses/'samples.json').read_text())
frames=[Image.open(f).convert('RGB') for f in sorted((a.poses/'frames').glob('*.png'))]
assert len(frames)==len(samples)==58
frames[0].save(out/'huit_directions.gif',save_all=True,append_images=frames[1:],duration=[30,30,40]*19+[600],loop=0)
for f,label in [('000','repos'),('017','extension'),('022','traction'),('035','raccord')]:shutil.copy2(a.poses/f'frames/{f}.png',out/f'{label}.png')
report=json.loads((a.combat/'report.json').read_text())
assert report['passed'] and len(report['casts'])==16
assert all(c['copy_consumed'] and c['release']['frame']==6 for c in report['casts'])
combat=json.loads((a.combat/'samples.json').read_text())
film=[Image.open(a.combat/f'frames/{i:04d}.png').convert('RGB').crop((470,200,1040,760)) for i in range(len(combat))]
durations=[]; elapsed=0
for row in combat[1:]:
    end=round((row['time_ms']-combat[0]['time_ms'])/10)*10;durations.append(max(10,end-elapsed));elapsed+=durations[-1]
durations.append(700)
film[0].save(out/'traction_en_combat.gif',save_all=True,append_images=film[1:],duration=durations,loop=0)
provenance=dict(poses=str(a.poses),combat=str(a.combat),casts=16,checks=len(report['checks']),frames=len(samples),
    scope='Eight authored directions;16 genuine g04 casts (base/upgrade). Diagnostic red point in presentation only denotes active hand. Game displacement remains authoritative, including axis selection for diagonals.',
    same_release_ms=400,same_duration_ms=890,mirrors=False)
(out/'provenance.json').write_text(json.dumps(provenance,indent=2),encoding='utf-8')
print(json.dumps(provenance))
