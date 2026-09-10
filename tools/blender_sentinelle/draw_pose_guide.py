"""Plot exported bone coordinates as a technical reference, with no painted armor."""
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/source/sprite_workshop/sentinelle_guided_v1'
data=json.loads((OUT/'pose_guide.json').read_text())
im=Image.new('RGB',(1280,1240),'#f1efe8')
draw=ImageDraw.Draw(im)
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
heading=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',23)
draw.text((25,14),'GUIDE DE POSES / SENTINELLE / VUE E',font=heading,fill='#26343c')
draw.text((25,48),'Appuis et geste uniquement. Le dessin original reste la reference artistique.',font=font,fill='#556167')
for index,pose in enumerate(data['poses']):
    ox=(index%2)*640
    oy=90+(index//2)*570
    def p(v):return (ox+v[0]*.8,oy+v[1]*.72)
    draw.text((ox+22,oy+7),f"{index+1:02d} / {pose['label']} / {(pose['frame']-1)/30:.2f} s",font=heading,fill='#27353a')
    for ends in pose['ground']:
        draw.line([p(v) for v in ends],fill='#dddcd4',width=1)
    for side,foot in pose['feet'].items():
        col='#3484a2' if side=='L' else '#b7763b'
        draw.polygon([p(v) for v in foot['ground']],fill='#e1e4dc',outline='#81928d')
        draw.line([p(v) for v in foot['sole']+[foot['sole'][0]]],fill=col,width=4)
    draw.line([p(v) for v in pose['shield']],fill='#abc8cf',width=4)
    for name,bone in pose['bones'].items():
        if name=='Root':continue
        color='#337f9e' if name.endswith('.L') else '#b57439' if name.endswith('.R') else '#424e57'
        a,b=p(bone['head']),p(bone['tail'])
        draw.line([a,b],fill=color,width=8 if name in ('Pelvis','Thorax') else 5)
        r=5
        draw.ellipse((a[0]-r,a[1]-r,a[0]+r,a[1]+r),fill='#f8f6ef',outline=color,width=2)
    draw.line([p(v) for v in pose['weapon']],fill='#805627',width=5)
    tip=p(pose['weapon'][-1]);draw.ellipse((tip[0]-5,tip[1]-5,tip[0]+5,tip[1]+5),fill='#805627')
    h=p(pose['head']);draw.ellipse((h[0]-25,h[1]-34,h[0]+25,h[1]+34),outline='#424e57',width=3)
    note='Deux pieds au sol' if pose['frame']<13 else 'Pied avant en appui / talon arriere releve'
    draw.text((ox+22,oy+522),note,font=font,fill='#556167')
im.save(OUT/'pose_guide.png')
im.save(OUT/'pose_guide.jpg',quality=91)
print(str(OUT/'pose_guide.png'))
