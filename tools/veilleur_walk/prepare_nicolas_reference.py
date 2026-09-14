"""Inspect the already cached public walk clip; no Dofus pixels enter game art."""
from pathlib import Path
import hashlib,json
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
CACHE=ROOT/'artifacts/dev/dofus-research/puppet_8.gif'
OUT=ROOT/'artifacts/dev/veilleur-nicolas-study';OUT.mkdir(exist_ok=True)
gif=Image.open(CACHE);frames=[];durations=[]
for i in range(32):
    gif.seek(i);frames.append(gif.convert('RGBA'));durations.append(gif.info['duration'])
assert all(frames[i].tobytes()==frames[i+16].tobytes() for i in range(16))
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',15)
for bank in range(2):
    board=Image.new('RGB',(1296,760),'#a59882');draw=ImageDraw.Draw(board)
    for cell in range(8):
        i=bank*8+cell;x=cell%4*324;y=cell//4*380
        board.paste(frames[i].convert('RGB'),(x,y+30))
        draw.text((x+12,y+7),f'Image {i:02} · {i*30} ms',font=font,fill='#10262a')
        for gx in range(60,281,20):
            draw.line((x+gx,y+30,x+gx,y+377),fill='#8d8979',width=1)
            draw.text((x+gx,y+32),str(gx),font=font,fill='#314342')
        for gy in range(100,321,20):
            draw.line((x+30,y+30+gy,x+304,y+30+gy),fill='#8d8979',width=1)
            draw.text((x+2,y+23+gy),str(gy),font=font,fill='#314342')
    board.save(OUT/f'grid_{bank}.png')
for i in range(16):frames[i].save(OUT/f'frame_{i:02}.png')
(OUT/'source.json').write_text(json.dumps({'author':'Nicolas Détrain','project':'Dofus Unity — Universal Puppet/Rig — Animation',
    'page':'https://www.behance.net/gallery/251129565/Dofus-Unity-Universal-PuppetRig-Animation',
    'source_url':'https://mir-s3-cdn-cf.behance.net/project_modules/disp/a7e1e3251129565.6a2fd897ac7b0.gif',
    'cache':str(CACHE.relative_to(ROOT)),'sha256':hashlib.sha256(CACHE.read_bytes()).hexdigest(),
    'size':list(gif.size),'cycle_count':16,'durations_ms':durations[:16],'cycle_verified_by_exact_repeat':True,
    'scope':'First orientation only. Encoded GIF timing is not an assertion about game FPS.'},ensure_ascii=False,indent=2),encoding='utf-8')
print('REFERENCE_READY',sum(durations[:16]))
