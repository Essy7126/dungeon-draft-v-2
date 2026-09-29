from pathlib import Path
from PIL import Image
import numpy as np
import json

def components(a):
    pending=a[:,:,3]>220
    h,w=pending.shape
    parts=[]
    for sy,sx in zip(*np.where(pending)):
        if not pending[sy,sx]: continue
        todo=[(int(sy),int(sx))];pending[sy,sx]=False;points=[]
        while todo:
            y,x=todo.pop();points.append((y,x))
            for dy,dx in [(0,1),(1,0),(0,-1),(-1,0)]:
                ny,nx=y+dy,x+dx
                if 0<=ny<h and 0<=nx<w and pending[ny,nx]:
                    pending[ny,nx]=False;todo.append((ny,nx))
        if len(points)>1200:
            yy,xx=np.array(points).T
            parts.append([int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)])
    return parts

if __name__=='__main__':
    root=Path(__file__).resolve().parent
    for name,cols in [('E_W_v02.png',4),('NE_NW_v01.png',6),('S_N_v01.png',4),('SW_v02.png',4)]:
        a=np.array(Image.open(root/name).convert('RGBA'))
        parts=components(a)
        parts=sorted(parts,key=lambda b:b[1])
        parts=[p for i in range(0,len(parts),cols) for p in sorted(parts[i:i+cols],key=lambda b:b[0])]
        print(name,a.shape,'transparent',round(float((a[:,:,3]==0).mean()),3),'opaque',round(float((a[:,:,3]>240).mean()),3))
        print(json.dumps(parts))
