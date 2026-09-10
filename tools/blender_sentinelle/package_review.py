"""Assemble native Blender renders for local visual review."""
from pathlib import Path
import json
import shutil
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'artifacts/dev/sentinelle-blender-review-20260910'
OUT=ROOT/'art/source/blender/sentinelle_blocking_v1/review'
SERVED=ROOT/'artifacts/spine_trial/sentinelle_blender_pilot'
report=json.loads((SRC/'report.json').read_text())
if not report['passed'] or len(report['renders'])!=43:raise RuntimeError('Incomplete render batch')
OUT.mkdir(parents=True,exist_ok=True)
(SERVED/'frames').mkdir(parents=True,exist_ok=True)
for entry in report['renders']:
    with Image.open(entry['path']) as im:
        im.verify()
    shutil.copy2(entry['path'],SERVED/'frames'/Path(entry['path']).name)
frames=[Image.open(SRC/f'E_{f:02d}.png').convert('RGB').resize((600,540),Image.Resampling.LANCZOS) for f in range(1,26)]
durations=[30,30,40]*8+[600]
frames[0].save(OUT/'estoc_E.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
title=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',24)
keys=[1,6,10,13,16,25];labels=['Garde','Charge','Appui','Contact','Freinage','Retour']
sheet=Image.new('RGB',(1500,1020),(18,27,32));draw=ImageDraw.Draw(sheet)
draw.text((20,12),'SENTINELLE / ESTOC / ETUDE BLENDER',font=title,fill=(225,216,198))
for row,d in enumerate('ESWN'):
    for col,(f,label) in enumerate(zip(keys,labels)):
        im=Image.open(SRC/f'{d}_{f:02d}.png').convert('RGB').resize((250,225),Image.Resampling.LANCZOS)
        x=col*250;y=55+row*240
        sheet.paste(im,(x,y));draw.text((x+8,y+202),f'{d} / {label} / {(f-1)/30:.2f}s',font=font,fill=(245,236,219),stroke_width=1,stroke_fill=(20,25,30))
sheet.save(OUT/'poses_four_views.jpg',quality=91)
shutil.copy2(ROOT/'tools/blender_sentinelle/review.html',SERVED/'review.html')
shutil.copy2(SRC/'E_13.png',OUT/'contact_E.png')
(OUT/'review_manifest.json').write_text(json.dumps({'renders':43,'gif_pause_at_end_ms':600,'artistic_approved':False,'url':'http://127.0.0.1:8734/files/sentinelle_blender_pilot/review.html'},indent=2)+'\n')
print(json.dumps({'passed':True,'renders':43,'output':str(OUT),'url':'http://127.0.0.1:8734/files/sentinelle_blender_pilot/review.html'}))
