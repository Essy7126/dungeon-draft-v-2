"""Diagnostic construction only: projected contacts, not finished character art."""
from pathlib import Path
import sys,math,json
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/passe_rive_motion'))
import walk_model as gait
gait.STRIDE=1.0
gait.DURATION=1.0
SRC=ROOT/'art/source/characters/achilles/veilleur_walk_E_v1'
OUT=SRC/'guides';OUT.mkdir(exist_ok=True)
S=200;ORIGIN=(192,445);SIZE=(384,512)
def project(p):
    x,y,z=p
    return (ORIGIN[0]+S*(y-x),ORIGIN[1]+S*(.5*(x+y)-z))
def ik(hip,ankle):
    dy,dz=ankle[1]-hip[1],ankle[2]-hip[2]
    length=math.hypot(dy,dz);bend=math.sqrt(max(0,.45**2-length**2/4))
    return [hip[0],(hip[1]+ankle[1])/2-bend*dz/length,(hip[2]+ankle[2])/2+bend*dy/length]
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',15)
all_data=[];sheet=Image.new('RGB',(1536,1536),'#f3f1e8')
for index in range(12):
    t=index/12;a=2*math.pi*t
    frame=Image.new('RGB',SIZE,'#f3f1e8');d=ImageDraw.Draw(frame)
    d.text((12,10),f'{index+1:02}   R=blue / L=orange',fill='#454e50',font=font)
    d.line((24,420,344,420),fill='#d0d0c8',width=1)
    d.line((192,28,192,486),fill='#dedbd0',width=1)
    root=[.025*math.sin(a),0,.865-.020*math.sin(2*a)]
    chest=[root[0]*.45,-.008,root[2]+.38]
    neck=[chest[0],chest[1],chest[2]+.14]
    top=[neck[0],neck[1],neck[2]+.43]
    # Neutral rigid masses are a spatial guide only.
    pelvisL=project([root[0]-.16,0,root[2]]);pelvisR=project([root[0]+.16,0,root[2]])
    chestL=project([chest[0]-.19,0,chest[2]]);chestR=project([chest[0]+.19,0,chest[2]])
    d.polygon([chestL,chestR,pelvisR,pelvisL],fill='#bcc3bc',outline='#6c7772')
    n=project(neck);p=project(top)
    d.rounded_rectangle((p[0]-27,p[1],p[0]+26,n[1]),radius=18,fill='#bcc3bc',outline='#6c7772',width=2)
    data={'id':index,'phase':t,'root':project(root),'feet':{}}
    for side,color in [('L','#ce812d'),('R','#2878be')]:
        sign=1 if side=='R' else -1
        f=gait.foot(t-.5,side)
        f['ankle'][0]=sign*.13;f['heel'][0]=sign*.13;f['toe'][0]=sign*.13
        hip=[root[0]+sign*.13,sign*.018*math.cos(a),root[2]]
        knee=ik(hip,f['ankle'])
        points=[project(p) for p in [hip,knee,f['ankle']]]
        d.line(points,fill=color,width=17)
        for x,y in points:d.ellipse((x-8,y-8,x+8,y+8),fill=color,outline='#3e4545',width=1)
        heel,toe=project(f['heel']),project(f['toe'])
        d.line([heel,toe],fill=color,width=14)
        d.line([heel,toe],fill='#172d39',width=3)
        if f['contact']!='swing':
            c=heel if f['contact']=='heel' else toe if f['contact']=='toe' else ((heel[0]+toe[0])/2,(heel[1]+toe[1])/2)
            d.ellipse((c[0]-6,c[1]-3,c[0]+6,c[1]+3),fill='#152722')
        shoulder=[chest[0]+sign*.19,-sign*.025*math.cos(a),chest[2]]
        ang=-sign*.32*math.cos(a)
        elbow=[shoulder[0]+sign*.04,shoulder[1]+.27*math.sin(ang),shoulder[2]-.27*math.cos(ang)]
        wrist=[elbow[0],elbow[1]+.25*math.sin(ang+.20),elbow[2]-.25*math.cos(ang+.20)]
        d.line([project(p) for p in (shoulder,elbow,wrist)],fill=color,width=13)
        wx,wy=project(wrist);d.ellipse((wx-9,wy-10,wx+9,wy+10),fill=color)
        data['feet'][side]={'heel':heel,'toe':toe,'ankle':project(f['ankle']),'knee':project(knee),'contact':f['contact']}
    frame.save(OUT/f'{index:02}.png');sheet.paste(frame,((index%4)*384,(index//4)*512));all_data.append(data)
sheet.save(SRC/'guide_sheet.png')
(SRC/'guide.json').write_text(json.dumps({'scope':'Reference only, not a measurement of generated art','size':SIZE,'scale':S,'stride':[S,S*.5],'frames':all_data},indent=2))
print('GUIDE_READY')
