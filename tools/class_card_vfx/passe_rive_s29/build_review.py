"""Assemble actual Godot captures at their recorded timing; no sprite retouching."""
from pathlib import Path
import argparse, hashlib, json
from PIL import Image, ImageDraw, ImageFont

p=argparse.ArgumentParser()
p.add_argument('capture',type=Path)
p.add_argument('out',type=Path)
a=p.parse_args()
report=json.loads((a.capture/'report.json').read_text(encoding='utf-8'))
samples=json.loads((a.capture/'samples.json').read_text(encoding='utf-8'))
assert report['passed'] and len(report['casts'])==6
assert all(c['arrival_seen'] and c['invisible_release'] and c['no_route_interpolation'] and c['copy_consumed'] for c in report['casts'])
assert not any(x in (a.capture/'console.log').read_text(encoding='utf-8') for x in ['SCRIPT ERROR','ERROR:'])
active=[s for s in samples if s['state']['animation']=='PR_SPECTRAL_S29']
assert active
assert len({(s['state']['drawing_scale'],s['state']['drawing_scale_y']) for s in active})==1
a.out.mkdir(parents=True,exist_ok=True)
crop=(470,240,850,670)
images=[Image.open(a.capture/f'frames/{i:04d}.png').convert('RGB').crop(crop) for i in range(len(samples))]
durations=[]
elapsed=0
for sample in samples[1:]:
    end=round((sample['time_ms']-samples[0]['time_ms'])/10)*10
    duration=max(10,end-elapsed)
    durations.append(duration)
    elapsed+=duration
durations.append(650)
images[0].save(a.out/'passage_spectral_en_jeu.gif',save_all=True,append_images=images[1:],duration=durations,loop=0)
chosen=[]
for title,predicate in [
    ('Repos natif',lambda s: s['state']['animation'].startswith('idle_')),
    ('Pivot',lambda s: s['state']['animation']=='PR_SPECTRAL_S29' and s['state']['frame']==3),
    ('Effacement',lambda s: s['state']['animation']=='PR_SPECTRAL_S29' and s['state']['spectral_alpha']<.01),
    ('Réapparition',lambda s: s['state']['animation']=='PR_SPECTRAL_S29' and s['state']['arrival_confirmed'] and .46<s['state']['action_elapsed']<.60),
]:
    chosen.append((title,next(i for i,s in enumerate(samples) if predicate(s))))
board=Image.new('RGB',(760,936),'#192426')
draw=ImageDraw.Draw(board)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',20)
for index,(title,frame) in enumerate(chosen):
    x,y=index%2*380,index//2*468
    board.paste(images[frame],(x,y+38))
    draw.text((x+15,y+8),title,font=font,fill='#f3ecdb')
board.save(a.out/'raccord_en_jeu.png')
game=Path(__file__).resolve().parents[3]
data=json.loads((game/'assets/characters/PasseRive/sprites_s29/passage.json').read_text(encoding='utf-8'))
assert data['source_sha256']==hashlib.sha256((game/'assets/characters/PasseRive/sprites_s29/passage.png').read_bytes()).hexdigest()
assert data['veil']['source_sha256']==hashlib.sha256((game/'assets/characters/PasseRive/sprites_s29/veil.png').read_bytes()).hexdigest()
provenance=dict(capture=str(a.capture.resolve()),checks=len(report['checks']),casts=report['casts'],frames=len(samples),
    source_sha256=data['source_sha256'],veil_sha256=data['veil']['source_sha256'],duration_ms=860,release_ms=310,
    constant_scale=True,width_factor=.85,gif_timing_error_ms=elapsed-(samples[-1]['time_ms']-samples[0]['time_ms']),
    scope='Six real casts in production Battle; seeded cards, AI paused, camera 2.4x. SE authored body; native correct facings and spectral veil elsewhere. Video records base Bond spectral.')
(a.out/'provenance.json').write_text(json.dumps(provenance,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps({k:v for k,v in provenance.items() if k!='casts'},ensure_ascii=False))
