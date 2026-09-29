"""Register immutable imagegen sprites against native idles, including active hand sockets."""
from pathlib import Path
from PIL import Image
import numpy as np
import json, shutil, hashlib, importlib.util
from inspect_sources import components
GAME=Path(__file__).resolve().parents[3]
ROOT=GAME/'art/source/passe_rive_s31/incantation/sources'
OUT=GAME/'assets/characters/PasseRive/sprites_s31_incantation'
OUT.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('palette',GAME/'tools/class_card_vfx/build_passe_rive_palette.py')
palette=importlib.util.module_from_spec(spec);spec.loader.exec_module(palette)
native=GAME/'assets/characters/PasseRive/autosprite_v1'
geom=json.loads((native/'manifest.json').read_text(encoding='utf8'))['geometry']
target=palette.colors(native/'PasseRive-iso_idle_southeast-v1.png')
old=json.loads((GAME/'assets/characters/PasseRive/sprites_s26/incantation.json').read_text(encoding='utf8'))
for pose in old['frames']:pose['hand']=pose['hands'][1]
old['source_status']=old.pop('status')
views={'SE':dict(old,texture='res://assets/characters/PasseRive/sprites_s26/incantation.png',width_factor=.80,support=[-18.3333584,17.19648])}
# Hand centers were reviewed on full-resolution drawings, not inferred from direction.
hands={
'E':[[181,168],[443,121],[671,92],[901,61],[205,298],[444,303],[731,340],[958,335],[198,645],[406,650],[658,671],[891,671]],
'W':[[143,926],[355,887],[603,858],[850,825],[128,1073],[360,1058],[573,1101],[803,1091],[127,1400],[384,1423],[621,1429],[863,1428]],
'NE':[[215,161],[463,103],[672,83],[898,64],[211,309],[467,307],[728,333],[958,340],[225,632],[460,647],[690,674],[929,674]],
'NW':[[100,916],[340,870],[593,841],[838,825],[98,1074],[348,1085],[560,1098],[798,1101],[106,1399],[352,1411],[594,1426],[836,1427]],
'S':[[193,172],[405,141],[643,114],[884,86],[185,307],[435,308],[683,356],[968,356],[173,665],[427,671],[688,686],[936,686]],
'N':[[193,946],[414,901],[652,890],[896,889],[185,1064],[444,1059],[695,1096],[971,1100],[186,1389],[434,1398],[686,1430],[936,1430]],
'SW':[[155,164],[512,155],[885,124],[1235,87],[156,415],[485,409],[803,481],[1158,476],[134,891],[495,892],[850,891],[1214,891]],
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
    views[direction]=dict(texture='res://assets/characters/PasseRive/sprites_s31_incantation/'+file,
        source_height=boxes[offset][3]-boxes[offset][1],width_factor=width,
        sequence=old['sequence'],duration_ms=old['duration_ms'],frames=frames,
        support=[(sole[j]-g['anchor'][j])*g['scale'] for j in range(2)],
        palette={group:dict(center=c.tolist(),gain=np.clip(target[group]/c,.65,1.5).tolist()) for group,c in colors.items()},
        source_sha256=hashlib.sha256(source.read_bytes()).hexdigest())
(OUT/'incantation.json').write_text(json.dumps(dict(version='S31-incantation-directions-v01',status='integrated-eight-directions',duration_seconds=1.15,release_seconds=.59,views=views),indent=2),encoding='utf8')
print(json.dumps({d:dict(height=v['source_height'],support=v['support']) for d,v in views.items()}))


