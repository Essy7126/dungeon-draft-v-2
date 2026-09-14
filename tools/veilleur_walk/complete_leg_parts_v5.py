"""Take only missing trouser areas from ImageGen; retain all existing pixels."""
from pathlib import Path
import json
import numpy as np
from PIL import Image,ImageDraw,ImageFilter
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/source/characters/achilles/veilleur_walk_E_v5'
BASE=ROOT/'art/source/characters/achilles/veilleur_proportions_v1'
generated=Image.open(SRC/'legs_repair_generated.png').convert('RGB').resize((515,565),Image.Resampling.LANCZOS)
canvas=Image.new('RGB',(1254,1254),'white');canvas.paste(generated,(385,680))
rgb=np.array(canvas); cloth=(rgb.max(axis=2)<125)&((rgb.max(axis=2)-rgb.min(axis=2))<45)
# This threshold is specific to the dark trousers. Never apply it to the ivory costume.
matte=Image.fromarray((cloth*255).astype('uint8')).filter(ImageFilter.GaussianBlur(.35))
report={}
for side in 'LR':
    original=np.array(Image.open(BASE/f'leg_{side}.png').convert('RGBA'))
    region=Image.new('L',(1254,1254));d=ImageDraw.Draw(region)
    if side=='R':
        d.rectangle((440,680,646,766),fill=255)
        d.polygon([(475,827),(490,773),(525,761),(530,850),(493,883),(474,872)],fill=255)
    else:d.rectangle((645,680,802,757),fill=255)
    alpha=np.minimum(np.array(matte),np.array(region));alpha[original[:,:,3]>0]=0
    result=original.copy();new=alpha>0;result[new,:3]=rgb[new];result[new,3]=alpha[new]
    assert np.array_equal(result[original[:,:,3]>0],original[original[:,:,3]>0])
    Image.fromarray(result).save(SRC/f'leg_{side}_completed.png')
    report[side]={'added_pixels':int(new.sum()),'changed_existing_pixels':0}
(SRC/'repair_report.json').write_text(json.dumps({'source':'legs_repair_generated.png','method':'Registered by framing; dark-trouser matte; bounded missing areas only; all existing source pixels preserved. Generated boots are unused.','parts':report},indent=2))
print(json.dumps(report))
