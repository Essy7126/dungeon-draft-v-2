"""Read immutable imagegen pixels; emit directional regions, registration and palette."""
from pathlib import Path
import hashlib, importlib.util, json, shutil
import numpy as np
from PIL import Image

GAME = Path(__file__).resolve().parents[3]
ROOT = GAME / 'art/source/passe_rive_s31/kick/sources'
OUT = GAME / 'assets/characters/PasseRive/sprites_s31_kick'
OUT.mkdir(parents=True, exist_ok=True)
spec = importlib.util.spec_from_file_location('palette', GAME / 'tools/class_card_vfx/build_passe_rive_palette.py')
palette = importlib.util.module_from_spec(spec)
spec.loader.exec_module(palette)
native = GAME / 'assets/characters/PasseRive/autosprite_v1'
target = palette.colors(native / 'PasseRive-iso_idle_southeast-v1.png')
geometry = json.loads((native/'manifest.json').read_text())['geometry']
old = json.loads((GAME/'assets/characters/PasseRive/sprites_s24/kick_high.json').read_text())
views = {'SE': dict(old, texture='res://assets/characters/PasseRive/sprites_s24/kick_high.png',
                     sequence=list(range(8)), support=[-18.3333584,17.19648], width_factor=1.0,
                     contact=[429,196])}
# Explicitly authored source cells. S/N cells 2 swap the supporting leg and are excluded.
specs = {
    'E': ('E_W_v03.png',0,4,list(range(8)),[139,237],1.0),
    'W': ('E_W_v03.png',8,4,list(range(8)),[129,237],1.0),
    'NE': ('NE_NW_v01.png',0,4,list(range(8)),[108,211],.92),
    'NW': ('NE_NW_v01.png',8,4,list(range(8)),[149,211],.92),
    'S': ('S_N_v01.png',0,4,[0,1,6,3,4,5,6,7],[158,228],.91),
    'N': ('S_N_v01.png',8,4,[0,1,5,3,4,5,6,7],[104,225],.91),
    'SW': ('SW_v02.png',0,2,list(range(8)),[145,237],.90),
}
# Heel contact locations in the displayed source cell (normalised to cell).
contacts={'E':[.977,.365],'W':[.162,.312],'NE':[.858,.172],
          'NW':[.139,.155],'S':[.448,.347],'N':[.588,.136],'SW':[.236,.405]}
for direction,(file,offset,rows,sequence,sole,width) in specs.items():
    source=ROOT/file
    shutil.copy2(source,OUT/file)
    a=np.asarray(Image.open(source))
    assert a.shape[2]==4 and np.any(a[:,:,3]==0)
    h,w=a.shape[:2]
    frames=[]
    def boundaries(axis,n):
        result=[0]
        size=w if axis==0 else h
        solid=a[:,:,3]>220
        for k in range(1,n):
            m=round(size*k/n)
            gaps=[p for p in range(m-28,m+28) if not (solid[:,p] if axis==0 else solid[p]).any()]
            assert gaps, (file,axis,k,'no empty gutter')
            result.append(round((min(gaps)+max(gaps))/2))
        return result+[size]
    xb,yb=boundaries(0,4),boundaries(1,rows)
    for i in range(8):
        cell=i+offset
        x0,x1=xb[cell%4:cell%4+2]
        y0,y1=yb[cell//4:cell//4+2]
        img=a[y0:y1,x0:x1]
        yy,xx=np.where(img[:,:,3]>220)
        box=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]
        foot=np.ones(len(xx),bool)
        # At the start/end two feet touch the floor; keep the eventual support.
        if i in [0,1,6,7] and direction in ['NE','N']:
            foot=xx<(x1-x0)*(.43 if direction=='NE' else .49)
        elif i in [0,1,6,7] and direction in ['NW','S']:
            foot=xx>(x1-x0)*.51
        low=int(yy[foot].max())+1
        xs=xx[foot & (yy>=low-5)]
        pivot=[float(np.median(xs)),low]
        # Two disconnected boots, measured from their complete bottom components.
        if direction=='NE' and i==7: pivot=[138.0,284]
        if direction=='NW' and i==7: pivot=[222.0,279]
        frames.append(dict(region=[x0,y0,x1-x0,y1-y0],solid_bbox=box,pivot=pivot))
    colors=palette.colors(source)
    geom=geometry['idle_'+direction]
    support=[(sole[j]-geom['anchor'][j])*geom['scale'] for j in range(2)]
    contact=[contacts[direction][j]*frames[4]['region'][j+2] for j in range(2)]
    views[direction]=dict(texture='res://assets/characters/PasseRive/sprites_s31_kick/'+file,
        frames=frames,sequence=sequence,source_height=frames[0]['solid_bbox'][3]-frames[0]['solid_bbox'][1],
        width_factor=width,support=support,contact=contact,
        palette={group:dict(center=center.tolist(),gain=np.clip(target[group]/center,.65,1.5).tolist()) for group,center in colors.items()},
        source_sha256=hashlib.sha256(source.read_bytes()).hexdigest())
data=dict(version='S31-kick-directions-v01',duration_ms=old['duration_ms'],release_seconds=.31,
          duration_seconds=.65,views=views)
# The camera-corrected back angles use 8 columns / 2 rows with unequal gutters.
# Identify connected body silhouettes to retain the whole extended heel.
source=ROOT/'NE_NW_v02.png'
shutil.copy2(source,OUT/source.name)
a=np.asarray(Image.open(source).convert('RGBA'))
h,w=a.shape[:2];solid=a[:,:,3]>220;pending=solid.copy();components=[]
for sy,sx in zip(*np.where(pending)):
    if not pending[sy,sx]:continue
    todo=[(int(sy),int(sx))];pending[sy,sx]=False;part=[]
    while todo:
        yy,xx=todo.pop();part.append((yy,xx))
        for dy,dx in [(0,1),(1,0),(0,-1),(-1,0)]:
            ny,nx=yy+dy,xx+dx
            if 0<=ny<h and 0<=nx<w and pending[ny,nx]:pending[ny,nx]=False;todo.append((ny,nx))
    if len(part)>1000:
        yy,xx=np.array(part).T
        components.append([int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)])
assert len(components)==16,components
components=sorted(components,key=lambda b:(int(b[1]>h/2),b[0]))
colors=palette.colors(source)
for direction,offset,sole in [('NE',0,[155,232]),('NW',8,[101,232])]:
    frames=[]
    for i,box in enumerate(components[offset:offset+8]):
        x0,y0,x1,y1=box[0]-3,box[1]-3,box[2]+3,box[3]+3
        cell=a[y0:y1,x0:x1];yy,xx=np.where(cell[:,:,3]>220)
        bottom=yy.max()+1
        frames.append(dict(region=[x0,y0,x1-x0,y1-y0],solid_bbox=[3,3,x1-x0-3,y1-y0-3],
                           pivot=[float(np.median(xx[yy>=bottom-5])),int(bottom)]))
        if i==4:
            edge=(xx>=xx.max()-4) if direction=='NE' else (xx<=xx.min()+4)
            contact=[float(np.median(xx[edge])),float(np.quantile(yy[edge],.9))]
    geom=geometry['idle_'+direction]
    views[direction]=dict(texture='res://assets/characters/PasseRive/sprites_s31_kick/'+source.name,
        frames=frames,sequence=[0,1,2,2,4,5,6,7],source_height=components[offset][3]-components[offset][1],
        width_factor=1.0,support=[(sole[j]-geom['anchor'][j])*geom['scale'] for j in range(2)],contact=contact,
        palette={group:dict(center=center.tolist(),gain=np.clip(target[group]/center,.65,1.5).tolist()) for group,center in colors.items()},
        source_sha256=hashlib.sha256(source.read_bytes()).hexdigest())
(OUT/'kick.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
print(json.dumps({d:{'height':v['source_height'],'support':v['support'],'pivots':[f['pivot'] for f in v['frames']]} for d,v in views.items()}))

