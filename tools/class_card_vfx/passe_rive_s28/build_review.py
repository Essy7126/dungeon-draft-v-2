"""Assemble captured game frames, preserving their clock; no generated-art edits."""
from pathlib import Path
import argparse, hashlib, json
from PIL import Image, ImageDraw, ImageFont
p=argparse.ArgumentParser()
p.add_argument('capture',type=Path)
p.add_argument('out',type=Path)
a=p.parse_args()
report=json.loads((a.capture/'report.json').read_text(encoding='utf-8'))
samples=json.loads((a.capture/'samples.json').read_text(encoding='utf-8'))
assert report['passed'] and len(report['casts'])==5
assert all(c['release']['animation']=='PR_DRAIN_S28' and c['release']['frame']==5 and c['copy_consumed'] for c in report['casts'])
assert not any(x in (a.capture/'godot.log').read_text(encoding='utf-8') for x in ['SCRIPT ERROR','ERROR:'])
active=[s for s in samples if s['state']['animation']=='PR_DRAIN_S28']
assert len({(s['state']['drawing_scale'],s['state']['drawing_scale_y']) for s in active})==1
assert set(s['state']['frame'] for s in active)==set(range(12))-{9}
assert all(c['siphon_seen']==(c['damage']>0) and c['glint_seen']==(c['healing']>0) and c['same_facts_after_return'] for c in report['casts'])
assert next(c for c in report['casts'] if c['scenario']=='lethal')['damage']==1
a.out.mkdir(parents=True,exist_ok=True)
crop=(535,285,915,635)
images=[Image.open(a.capture/f'frames/{i:04d}.png').convert('RGB').crop(crop) for i in range(len(samples))]
durations=[];elapsed=0
for s in samples[1:]:
    end=round((s['time_ms']-samples[0]['time_ms'])/10)*10
    duration=max(10,end-elapsed);durations.append(duration);elapsed+=duration
durations.append(700)
images[0].save(a.out/'prelevement_en_jeu.gif',save_all=True,append_images=images[1:],duration=durations,loop=0)
names=[('base_t07_before.png','Repos natif'),(5,'Saisie · 330 ms'),(7,'Absorption confirmée'),('base_t07_recovery.png','Retour au repos')]
board=Image.new('RGB',(760,772),'#142021');draw=ImageDraw.Draw(board)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
for i,(filename,title) in enumerate(names):
    if isinstance(filename,str): im=Image.open(a.capture/filename).convert('RGB').crop(crop)
    else:
        index=next(j for j,s in enumerate(samples) if s['state']['animation']=='PR_DRAIN_S28' and s['state']['frame']==filename and (filename!=7 or s['state'].get('healing_glint')))
        im=images[index]
    x,y=i%2*380,i//2*386
    board.paste(im,(x,y+36));draw.text((x+14,y+7),title,font=font,fill='#f0e8d3')
board.save(a.out/'raccord_en_jeu.png')
game=Path(__file__).resolve().parents[3]
sha=hashlib.sha256((game/'assets/characters/PasseRive/sprites_s28/drain.png').read_bytes()).hexdigest()
metadata=json.loads((game/'assets/characters/PasseRive/sprites_s28/drain.json').read_text(encoding='utf-8'))
assert sha==metadata['source_sha256']
provenance=dict(capture=str(a.capture.resolve()),source_sha256=sha,checks=len(report['checks']),casts=report['casts'],frames=len(samples),
                body_duration_ms=940,release_ms=330,width_projection=.84,constant_scale=True,
                gif_timing_error_ms=elapsed-(samples[-1]['time_ms']-samples[0]['time_ms']),
                scope='Actual production battle and public backend. Seeded cards/HP, paused AI, camera 2.4x. Victory deferred only for lethal fixture. SE artwork; other angles keep previous directional cast.')
(a.out/'provenance.json').write_text(json.dumps(provenance,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in provenance.items() if k!='casts'}))
