"""Assemble actual Godot captures at recorded timing; no sprite retouching."""
from pathlib import Path
import argparse, hashlib, json
from PIL import Image, ImageDraw, ImageFont

p=argparse.ArgumentParser()
p.add_argument('capture',type=Path)
p.add_argument('out',type=Path)
a=p.parse_args()
report=json.loads((a.capture/'report.json').read_text(encoding='utf-8'))
samples=json.loads((a.capture/'samples.json').read_text(encoding='utf-8'))
assert report['passed'] and len(report['casts'])==8
assert all(c['copy_consumed'] and c['heal_seen']==(c['healing']>0) and c['guard_seen']==(c['guard']>0) for c in report['casts'])
assert all(c['end_turn']==1 and c['end_saw_idle'] for c in report['casts'] if c['id']=='i01')
assert not any(x in (a.capture/'console.log').read_text(encoding='utf-8') for x in ['SCRIPT ERROR','ERROR:'])
active=[s for s in samples if s['state']['animation']=='PR_RENEW_S30']
assert active
assert len({(s['state']['drawing_scale'],s['state']['drawing_scale_y']) for s in active})==1
a.out.mkdir(parents=True,exist_ok=True)
crop=(515,260,875,625)
images=[Image.open(a.capture/f'frames/{i:04d}.png').convert('RGB').crop(crop) for i in range(len(samples))]
durations=[]
elapsed=0
for sample in samples[1:]:
    end=round((sample['time_ms']-samples[0]['time_ms'])/10)*10
    duration=max(10,end-elapsed)
    durations.append(duration)
    elapsed+=duration
durations.append(650)
images[0].save(a.out/'seconde_aurore_en_jeu.gif',save_all=True,append_images=images[1:],duration=durations,loop=0)
chosen=[]
for title,predicate in [
    ('Repos natif',lambda s:s['state']['animation'].startswith('idle_')),
    ('Préparation',lambda s:s['state']['animation']=='PR_RENEW_S30' and s['state']['frame']==2),
    ('Soin confirmé',lambda s:s['state']['animation']=='PR_RENEW_S30' and s['state']['frame']==6 and s['state']['renew_heal_visible']),
    ('Protection',lambda s:s['state']['animation']=='PR_RENEW_S30' and s['state']['frame']>=9 and s['state']['renew_guard_visible']),
]:
    chosen.append((title,next(i for i,s in enumerate(samples) if predicate(s))))
board=Image.new('RGB',(720,802),'#192426')
draw=ImageDraw.Draw(board)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',20)
for index,(title,frame) in enumerate(chosen):
    x,y=index%2*360,index//2*401
    board.paste(images[frame],(x,y+36))
    draw.text((x+12,y+6),title,font=font,fill='#f3ecdb')
board.save(a.out/'raccord_en_jeu.png')
game=Path(__file__).resolve().parents[3]
data=json.loads((game/'assets/characters/PasseRive/sprites_s30/renew.json').read_text(encoding='utf-8'))
for file,key in [('renew.png','source_sha256'),('vfx.png','vfx')]:
    expected=data[key] if key!='vfx' else data[key]['source_sha256']
    assert expected==hashlib.sha256((game/'assets/characters/PasseRive/sprites_s30'/file).read_bytes()).hexdigest()
provenance=dict(capture=str(a.capture.resolve()),checks=len(report['checks']),casts=report['casts'],frames=len(samples),
    source_sha256=data['source_sha256'],vfx_sha256=data['vfx']['source_sha256'],duration_ms=[1120,820],release_ms=[450,250],
    constant_scale=True,width_factor=data['width_factor'],gif_timing_error_ms=elapsed-(samples[-1]['time_ms']-samples[0]['time_ms']),
    scope='Eight real casts in production Battle and end-turn flow; seeded cards, AI paused, checkpoint writes disabled, camera 2.4x. SE authored body; existing directional incantation and new VFX elsewhere. GIF records base Seconde aurore.')
(a.out/'provenance.json').write_text(json.dumps(provenance,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps({k:v for k,v in provenance.items() if k!='casts'},ensure_ascii=False))
