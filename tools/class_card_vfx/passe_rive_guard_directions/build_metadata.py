"""Register immutable imagegen sprites against native idles, including active hand sockets."""
from pathlib import Path
from PIL import Image
import numpy as np
import json, shutil, hashlib, importlib.util
from inspect_sources import components
GAME=Path(__file__).resolve().parents[3]
ROOT=GAME/'art/source/passe_rive_s31/guard/sources'
OUT=GAME/'assets/characters/PasseRive/sprites_s31_guard'
OUT.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('palette',GAME/'tools/class_card_vfx/build_passe_rive_palette.py')
palette=importlib.util.module_from_spec(spec);spec.loader.exec_module(palette)
native=GAME/'assets/characters/PasseRive/autosprite_v1'
geom=json.loads((native/'manifest.json').read_text(encoding='utf8'))['geometry']
target=palette.colors(native/'PasseRive-iso_idle_southeast-v1.png')
old=json.loads((GAME/'assets/characters/PasseRive/sprites_s27/guard.json').read_text(encoding='utf8'))
for pose in old['frames']:pose['hand']=pose['hands'][0]
views={'SE':dict(old,texture='res://assets/characters/PasseRive/sprites_s27/guard.png',width_factor=.93,support=[-18.3333584,17.19648])}
# Hand centers were reviewed on full-resolution drawings, not inferred from direction.
hands={
'E':[[158,170],[427,138],[669,135],[907,96],[197,324],[451,313],[691,311],[932,320],[184,657],[425,669],[660,677],[904,677]],
'W':[[114,929],[348,899],[598,904],[849,863],[86,1087],[328,1080],[572,1079],[821,1087],[111,1430],[361,1430],[607,1432],[849,1433]],
'NE':[[164,177],[432,141],[676,109],[933,101],[175,345],[443,314],[700,330],[965,348],[181,664],[427,692],[686,694],[948,696]],
'NW':[[84,949],[330,909],[602,881],[860,867],[81,1110],[330,1081],[583,1097],[842,1117],[76,1426],[345,1442],[602,1443],[857,1444]],
'S':[[182,156],[414,133],[645,141],[899,90],[176,317],[424,306],[686,305],[944,317],[161,645],[437,666],[694,667],[946,669]],
'N':[[75,919],[337,889],[602,873],[855,871],[76,1079],[336,1066],[593,1065],[844,1081],[73,1432],[330,1434],[586,1433],[842,1433]],
'SW':[[171,157],[519,140],[870,150],[1207,105],[168,453],[487,427],[813,437],[1141,449],[172,892],[507,891],[836,887],[1166,887]],
}
specs={
'E':('E_W_v01.png',4,0,[139,237],1.0),
'W':('E_W_v01.png',4,12,[112,239],1.0),
'NE':('NE_NW_v01.png',4,0,[155,232],1.0),
'NW':('NE_NW_v01.png',4,12,[101,232],1.0),
'S':('S_N_v01.png',4,0,[168,230],.91),
'N':('S_N_v01.png',4,12,[109,228],.91),
'SW':('SW_v01.png',4,0,[143,238],.90),
}
cache={}
for direction,(file,cols,offset,sole,width) in specs.items():
    source=ROOT/file
    if file not in cache:
        a=np.array(Image.open(source).convert('RGBA'))
        boxes=sorted(components(a),key=lambda b:b[1])
        assert len(boxes)==(12 if direction=='SW' else 24),(file,len(boxes))
        boxes=[p for i in range(0,len(boxes),cols) for p in sorted(boxes[i:i+cols],key=lambda b:b[0])]
        cache[file]=(a,boxes,palette.colors(source))
        shutil.copy2(source,OUT/file)
    a,boxes,colors=cache[file]
    frames=[]
    for i,b in enumerate(boxes[offset:offset+12]):
        x0,y0,x1,y1=b[0]-3,b[1]-3,b[2]+3,b[3]+3
        yy,xx=np.where(a[y0:y1,x0:x1,3]>220)
        foot=np.ones(len(xx),bool)
        if direction=='S':foot=xx>(x1-x0)*.53
        if direction=='N':foot=xx<(x1-x0)*.48
        bottom=int(yy[foot].max())+1
        pivot=[float(np.median(xx[foot & (yy>=bottom-5)])),bottom]
        hand=[hands[direction][i][0]-x0,hands[direction][i][1]-y0]
        assert 0<=hand[0]<x1-x0 and 0<=hand[1]<y1-y0,(direction,i,hand)
        frames.append(dict(region=[x0,y0,x1-x0,y1-y0],pivot=pivot,hand=hand,solid_bbox=[3,3,x1-x0-3,y1-y0-3]))
    g=geom['idle_'+direction]
    views[direction]=dict(texture='res://assets/characters/PasseRive/sprites_s31_guard/'+file,
        source_height=boxes[offset][3]-boxes[offset][1],width_factor=width,
        sequence=old['sequence'],duration_ms=old['duration_ms'],frames=frames,
        support=[(sole[j]-g['anchor'][j])*g['scale'] for j in range(2)],
        palette={group:dict(center=c.tolist(),gain=np.clip(target[group]/c,.65,1.5).tolist()) for group,c in colors.items()},
        source_sha256=hashlib.sha256(source.read_bytes()).hexdigest())
import math
vectors={'E':(1,0),'SE':(1,.5),'S':(0,1),'SW':(-1,.5),'W':(-1,0),'NW':(-1,-.5),'N':(0,-1),'NE':(1,-.5)}
for direction,view in views.items():
    view['ward_angle']=math.atan2(vectors[direction][1],vectors[direction][0])-math.atan2(.5,1)
(OUT/'guard.json').write_text(json.dumps(dict(version='S31-guard-directions-v01',duration_seconds=.72,release_seconds=.24,views=views),indent=2),encoding='utf8')
print(json.dumps({d:dict(height=v['source_height'],support=v['support']) for d,v in views.items()}))


