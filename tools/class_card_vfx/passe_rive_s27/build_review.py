"""Assemble actual battle screenshots, preserving the captured playback clock."""
from pathlib import Path
import argparse, hashlib, json
from PIL import Image, ImageDraw, ImageFont

p = argparse.ArgumentParser()
p.add_argument('capture', type=Path)
p.add_argument('out', type=Path)
a = p.parse_args()
report = json.loads((a.capture/'report.json').read_text(encoding='utf-8'))
samples = json.loads((a.capture/'samples.json').read_text(encoding='utf-8'))
assert report['passed'] and len(report['casts']) == 5
assert all(c['release']['animation']=='PR_GUARD_S27' and c['release']['frame']==5 and (c['copy_consumed'] or c['fallback']) for c in report['casts'])
assert not any(x in (a.capture/'godot.log').read_text(encoding='utf-8') for x in ['SCRIPT ERROR','ERROR:'])
active=[s for s in samples if s['state']['animation']=='PR_GUARD_S27']
assert len({(s['state']['drawing_scale'],s['state']['drawing_scale_y']) for s in active})==1
assert set(s['state']['frame'] for s in active)==set(range(12))
a.out.mkdir(parents=True,exist_ok=True)
crop=(535,285,915,635)
images=[Image.open(a.capture/f'frames/{i:04d}.png').convert('RGB').crop(crop) for i in range(len(samples))]
durations=[]
elapsed=0
for s in samples[1:]:
    end=round((s['time_ms']-samples[0]['time_ms'])/10)*10
    duration=max(10,end-elapsed)
    durations.append(duration)
    elapsed+=duration
durations.append(700)
images[0].save(a.out/'garde_en_jeu.gif',save_all=True,append_images=images[1:],duration=durations,loop=0)
names=[('base_n02_before.png','Repos natif'),(None,'Garde croisée'),('base_n02_release.png','Libération · 240 ms'),('base_n02_recovery.png','Retour au repos')]
board=Image.new('RGB',(760,772),'#142021')
draw=ImageDraw.Draw(board)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
for i,(filename,title) in enumerate(names):
    if filename:
        im=Image.open(a.capture/filename).convert('RGB').crop(crop)
    else:
        index=next(i for i,s in enumerate(samples) if s['state']['animation']=='PR_GUARD_S27' and s['state']['frame']==3)
        im=images[index]
    x,y=(i%2)*380,(i//2)*386
    board.paste(im,(x,y+36))
    draw.text((x+14,y+7),title,font=font,fill='#f0e8d3')
board.save(a.out/'raccord_en_jeu.png')
sha=hashlib.sha256((Path(__file__).resolve().parents[3]/'assets/characters/PasseRive/sprites_s27/guard.png').read_bytes()).hexdigest()
metadata=json.loads((Path(__file__).resolve().parents[3]/'assets/characters/PasseRive/sprites_s27/guard.json').read_text(encoding='utf-8'))
assert sha == metadata['source_sha256']
assert all(c['ward_seen'] and c['shield_granted'] > 0 for c in report['casts'])
assert all(c['counter_damage'] > 0 for c in report['casts'] if c['id']=='cc2_g05')
assert all(not c['copy_consumed'] for c in report['casts'] if c['fallback'])
provenance=dict(capture=str(a.capture.resolve()),source_sha256=sha,checks=len(report['checks']),casts=report['casts'],
                frames=len(samples),body_duration_ms=720,release_ms=240,width_projection=.93,
                constant_scale=True,gif_timing_error_ms=elapsed-(samples[-1]['time_ms']-samples[0]['time_ms']),
                scope='real production battle and public backend; seeded hand, actors positioned, camera magnified 2.4x; SE artwork with native neutral guard in other directions')
(a.out/'provenance.json').write_text(json.dumps(provenance,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in provenance.items() if k!='casts'}))

