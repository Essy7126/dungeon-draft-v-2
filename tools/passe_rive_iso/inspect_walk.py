"""Inspection boards only: no modification of artwork or inferred approval."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'artifacts/spine_trial/passe_rive_walk_iso_v1'
SRC = ROOT / 'art/source/characters/achilles/passe_rive_walk_iso_v1'
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 17)
small = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 12)
for direction in 'ESNW':
    if not (OUT / f'{direction}_v1_audit.json').exists():
        continue
    keys = [(f'{direction}_v1', i) for i in range(12)]
    if direction == 'E':
        keys = keys[:6] + [('E_half', i) for i in range(6)]
        if (OUT/'E_inbet_audit.json').exists():
            keys=[('E_keys',0),('E_inbet',0),('E_inbet',1),('E_keys',1),('E_inbet',2),('E_inbet',3),('E_keys',2),('E_inbet',4),('E_inbet',5),('E_keys',3),('E_inbet',6),('E_inbet',7)]
    body = Image.new('RGB', (1536, 1770), '#283b36')
    feet = Image.new('RGB', (1440, 900), '#283b36')
    bd, fd = ImageDraw.Draw(body), ImageDraw.Draw(feet)
    for i, (key, index) in enumerate(keys):
        im = Image.open(OUT/'frames'/f'{key}_{index:02}.png').convert('RGBA')
        bx, by = i%4*384, i//4*590
        crop = im.crop((125, 80, 637, 768)).resize((384,516))
        body.paste(crop, (bx,by+36), crop)
        bd.text((bx+15,by+10), f'{direction} · {i+1:02} / 12', font=font, fill='#fff0cf')
        fx, fy = i%4*360, i//4*300
        crop = im.crop((220,470,580,740))
        feet.paste(crop, (fx,fy+28), crop)
        fd.text((fx+10,fy+4), f'{direction} · {i+1:02}', font=font, fill='#fff0cf')
        for x in range(250,580,50):
            fd.line((fx+x-220,fy+28,fx+x-220,fy+298), fill='#50645c',width=1)
            fd.text((fx+x-220+2,fy+28),str(x),font=small,fill='#bfcdc3')
        for y in range(500,740,50):
            fd.line((fx,fy+28+y-470,fx+359,fy+28+y-470),fill='#50645c',width=1)
            fd.text((fx+2,fy+28+y-470),str(y),font=small,fill='#bfcdc3')
    body.save(OUT/f'{direction}_body_review.jpg',quality=94)
    feet.save(OUT/f'{direction}_feet_measured.jpg',quality=94)
print('INSPECTION_BOARDS_READY')
