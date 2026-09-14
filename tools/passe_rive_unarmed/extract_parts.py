"""Extract the generated cutout atlas; software detourage authorized by user."""
from pathlib import Path
import os, sys, json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'art/source/characters/achilles/passe_rive_walk_unarmed_v1'
os.environ['U2NET_HOME'] = str(ROOT / 'artifacts/dev-tools/rembg-models')
os.environ['OMP_NUM_THREADS'] = '4'
direction = sys.argv[1] if len(sys.argv)>1 else 'E'
raw = Image.open(SRC / f'{direction}_parts.png').convert('RGBA')
# Rows follow the actual illustrated atlas, not assumed equal prompt cells.
xs = [0, 315, 637, 948, 1254]
ys = [0, 352, 640, 918, 1254]
if direction != 'E':
    layout = json.loads((SRC / f'{direction}_layout.json').read_text())
    xs, ys = layout['xs'], layout['ys']
xs = [round(x*raw.width/1254) for x in xs]
ys = [round(y*raw.height/1254) for y in ys]
out = SRC / 'parts' / direction
out.mkdir(parents=True, exist_ok=True)
session = None
metadata=[]
for i in range(16):
    path=out/f'{i:02}.png'
    box=[xs[i%4],ys[i//4],xs[i%4+1],ys[i//4+1]]
    if not path.exists():
        from rembg import remove,new_session
        if session is None:session=new_session('birefnet-general-lite',providers=['CPUExecutionProvider'])
        crop=raw.crop(box)
        clean=remove(crop,session=session,decontaminate=True)
        a=np.array(clean)
        # Discard transparent RGB before any resampling; preserve ivory fabric.
        a[a[:,:,3]<6]=0
        clean=Image.fromarray(a)
        bounds=clean.getbbox()
        if bounds is None:raise RuntimeError(f'Empty part {i}')
        clean.crop(bounds).save(path)
        print(f'EXTRACTED {direction}/{i:02}',flush=True)
    im=Image.open(path)
    metadata.append({'id':i,'source_box':box,'size':list(im.size)})
(out/'extraction.json').write_text(json.dumps(metadata,indent=2))
board=Image.new('RGB',(1000,1200),'#364647');d=ImageDraw.Draw(board)
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
for i in range(16):
    im=Image.open(out/f'{i:02}.png').convert('RGBA');im.thumbnail((220,250))
    x=i%4*250+(250-im.width)//2;y=i//4*300+34
    board.paste(im,(x,y),im);d.text((i%4*250+10,i//4*300+5),str(i),font=font,fill='white')
board.save(SRC/f'{direction}_parts_review.jpg',quality=93)
print(json.dumps({'direction':direction,'parts':len(metadata),'atlas':str(SRC/f'{direction}_parts_review.jpg')}))
