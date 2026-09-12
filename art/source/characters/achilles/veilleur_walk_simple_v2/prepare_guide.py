from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np
root=Path(__file__).resolve().parents[5]
dst=Path(__file__).parent
old=root/'artifacts/spine_trial/veilleur_walk_simple_v1'
Image.open(old/'frames/E/00.png').crop((53,15,201,159)).save(dst/'upper_reference.png')
Image.open(old/'frames/E/00.png').crop((134,195,188,242)).save(dst/'boot_reference.png')
canvas=Image.new('RGB',(6*256,4*256),'white');p=ImageDraw.Draw(canvas)
near_q=[18,5,-8,-18,-10,0];far_q=[-18,-10,0,18,5,-8]
near_l=[0,0,0,0,7,12];far_l=[0,7,12,0,0,0]
for r,d in enumerate(['E','S','N','W']):
    u=np.array([1 if d in ['E','N'] else -1,.5 if d in ['E','S'] else -.5])
    hips={'E':[[114,158],[137,158]],'S':[[139,158],[116,158]],'N':[[139,166],[116,166]],'W':[[116,166],[139,166]]}[d]
    bases={'E':[[109,227],[142,214]],'S':[[144,227],[111,214]],'N':[[141,227],[108,214]],'W':[[111,227],[144,214]]}[d]
    for i in range(6):
        o=np.array([i*256,r*256]);b=[0,2,-1,0,2,-1][i]
        p.text(tuple(o+[8,5]),f'{d} {i+1}',fill='#222222')
        p.ellipse(tuple(o+[109,30])+tuple(o+[146,70]),outline='#777777',width=3)
        p.polygon([tuple(o+x) for x in [[105,80],[149,80],[143,153+b],[112,153+b]]],outline='#777777',width=3)
        for k,color in [(1,'#2875d9'),(0,'#da4a3e')]:
            q=(near_q if k==0 else far_q)[i];lift=(near_l if k==0 else far_l)[i]
            hip=np.array(hips[k])+[0,b]
            ankle=np.array(bases[k])+u*q-[0,lift]
            knee=(hip+ankle)*.5+u*(7 if lift else 4)-[0,3 if lift else 0]
            p.line([tuple(o+z) for z in [hip,knee,ankle]],fill=color,width=9)
            p.line([tuple(o+ankle-u*5),tuple(o+ankle+u*13)],fill=color,width=10)
            for z in [hip,knee,ankle]:
                z=o+z;p.ellipse((z[0]-5,z[1]-5,z[0]+5,z[1]+5),fill=color)
canvas.save(dst/'pose_guide.png')
