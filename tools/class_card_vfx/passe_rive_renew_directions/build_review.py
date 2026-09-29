"""Assemble real Godot captures without modifying any source sprite."""
from pathlib import Path
import argparse,json,shutil
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('poses',type=Path);p.add_argument('combat',type=Path);a=p.parse_args()
game=Path(__file__).resolve().parents[3]
out=game/'art/source/passe_rive_s31/renew/review';out.mkdir(parents=True,exist_ok=True)
samples=json.loads((a.poses/'samples.json').read_text(encoding='utf8'))
frames=[Image.open(f).convert('RGB') for f in sorted((a.poses/'frames').glob('*.png'))]
assert len(frames)==len(samples)==132
frames[0].save(out/'huit_directions.gif',save_all=True,append_images=frames[1:],duration=[30,30,40]*43+[30,30,600],loop=0)
for f,label in [('000','repos'),('024','ouverture_longue'),('030','soin_et_garde'),('083','ouverture_courte'),('099','raccord')]:shutil.copy2(a.poses/f'frames/{f}.png',out/f'{label}.png')
report=json.loads((a.combat/'report.json').read_text(encoding='utf8'))
assert report['passed'] and len(report['casts'])==64
assert all(c['copy_consumed'] and c['release']['frame']==(6 if c['id']=='i01' else 4) for c in report['casts'])
combat=json.loads((a.combat/'samples.json').read_text(encoding='utf8'))
film=[Image.open(a.combat/f'frames/{i:04d}.png').convert('RGB').crop((470,200,1040,760)) for i in range(len(combat))]
durations=[]; elapsed=0
for row in combat[1:]:
    end=round((row['time_ms']-combat[0]['time_ms'])/10)*10;durations.append(max(10,end-elapsed));elapsed+=durations[-1]
durations.append(700)
film[0].save(out/'restauration_en_combat.gif',save_all=True,append_images=film[1:],duration=durations,loop=0)
provenance=dict(poses=str(a.poses),combat=str(a.combat),casts=64,checks=len(report['checks']),frames=len(samples),
    scope='Eight authored directions, long and compact variants. Pose grid confirms synthetic 20 HP / 10 guard; combat proves actual base, upgraded, full HP and guard cap results for both cards, plus rejection without AP. Automatic end turn only after native recovery.',
    releases_ms=[450,250],duration_ms=[1120,820],mirrors=False)
(out/'provenance.json').write_text(json.dumps(provenance,indent=2),encoding='utf8')
print(json.dumps(provenance))
