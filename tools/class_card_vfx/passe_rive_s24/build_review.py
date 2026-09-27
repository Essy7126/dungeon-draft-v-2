"""Assemble documentary Godot captures, without editing animation source pixels."""
import argparse, json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

p=argparse.ArgumentParser();p.add_argument('capture',type=Path);p.add_argument('out',type=Path);args=p.parse_args()
samples=json.loads((args.capture/'samples.json').read_text())
report=json.loads((args.capture/'report.json').read_text())
assert report['passed'], 'Only publish a passed capture as the current review'
args.out.mkdir(parents=True,exist_ok=True)
crop=(455,325,905,665)
images=[Image.open(args.capture/f'frames/{i:04d}.png').convert('RGB').crop(crop) for i in range(len(samples))]
times=[max(10,min(200,samples[i+1]['time_ms']-s['time_ms'])) if i+1<len(samples) else 600 for i,s in enumerate(samples)]
images[0].save(args.out/'coup_de_talon_B.gif',save_all=True,append_images=images[1:],duration=times,loop=0)
indices=[0]
for frame in [2,4,6]:
    indices.append(next(i for i,s in enumerate(samples) if s['state']['animation']=='PR_KICK_B_S24' and s['state']['frame']==frame))
indices.append(len(images)-1)
board=Image.new('RGB',(450*5,380),'#182626');draw=ImageDraw.Draw(board)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
for n,(idx,title) in enumerate(zip(indices,['Repos natif','Préparation','Contact du talon','Rétraction','Repos natif'])):
    board.paste(images[idx],(n*450,40));draw.text((n*450+16,10),title,font=font,fill='#f1e8d1')
board.save(args.out/'audit_poses.png')
provenance={'capture':str(args.capture),'passed':report['passed'],'checks':len(report['checks']),'frames':len(samples),'contact_frame':indices[2],'source_atlas_sha256':json.loads((Path(__file__).parent/'metadata.json').read_text())['source_sha256']}
(args.out/'capture_provenance.json').write_text(json.dumps(provenance,indent=2),encoding='utf-8')
(args.out/'review.html').write_text('''<!doctype html><meta charset="utf-8"><title>Passe-Rive · Coup de talon B</title>
<style>body{margin:40px;background:#152522;color:#eae1ce;font:17px system-ui}main{max-width:1050px;margin:auto}h1{font-size:28px}img{max-width:100%;border-radius:10px}p{line-height:1.6}.film{width:675px}</style>
<main><h1>Coup de talon · B — Chassé de profil</h1><p>Animatique SE · 8 poses · 650 ms. Capture d’une vraie carte : 1 PA, dégâts au contact et cible repoussée d’une case.</p>
<img class="film" src="coup_de_talon_B.gif" alt="Capture animée dans Godot"><p>À valider : intention, rythme et raccord au repos. Cette animatique précède les intervalles fins et les autres directions.</p>
<img src="audit_poses.png" alt="Comparaison repos, préparation, contact et retour"></main>''',encoding='utf-8')
print(json.dumps(provenance))
