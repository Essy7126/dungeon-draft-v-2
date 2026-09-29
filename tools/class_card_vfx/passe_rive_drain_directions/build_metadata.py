"""Register immutable imagegen sprites against native idles, including active hand sockets."""
from pathlib import Path
from PIL import Image
import numpy as np
import json, shutil, hashlib, importlib.util
from inspect_sources import components
GAME=Path(__file__).resolve().parents[3]
ROOT=GAME/'art/source/passe_rive_s31/drain/sources'
OUT=GAME/'assets/characters/PasseRive/sprites_s31_drain'
OUT.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('palette',GAME/'tools/class_card_vfx/build_passe_rive_palette.py')
palette=importlib.util.module_from_spec(spec);spec.loader.exec_module(palette)
native=GAME/'assets/characters/PasseRive/autosprite_v1'
geom=json.loads((native/'manifest.json').read_text(encoding='utf8'))['geometry']
target=palette.colors(native/'PasseRive-iso_idle_southeast-v1.png')
old=json.loads((GAME/'assets/characters/PasseRive/sprites_s28/drain.json').read_text(encoding='utf8'))
for pose in old['frames']:pose['hand']=pose['hands'][0]
views={'SE':dict(old,texture='res://assets/characters/PasseRive/sprites_s28/drain.png',width_factor=.84,support=[-18.3333584,17.19648])}
# Hand centers were reviewed on full-resolution drawings, not inferred from direction.
hands={'E': [[159, 155], [439, 126], [699, 130], [979, 94], [226, 309], [481, 334], [696, 351], [923, 350], [168, 601], [461, 632], [680, 645], [910, 668]], 'W': [[220, 220], [503, 189], [853, 177], [1156, 131], [115, 483], [461, 480], [842, 500], [1231, 485], [191, 849], [503, 916], [887, 940], [1256, 942]], 'NE': [[233, 167], [594, 167], [981, 142], [1321, 89], [259, 436], [624, 437], [960, 481], [1318, 481], [236, 843], [614, 899], [964, 917], [1320, 917]], 'NW': [[93, 907], [326, 853], [565, 865], [824, 826], [58, 1078], [313, 1078], [590, 1107], [861, 1104], [57, 1374], [328, 1390], [607, 1422], [865, 1424]], 'S': [[207, 177], [428, 152], [699, 154], [936, 125], [218, 375], [455, 376], [671, 393], [886, 384], [167, 652], [455, 681], [691, 707], [921, 707]], 'N': [[104, 944], [333, 887], [566, 906], [800, 897], [80, 1147], [325, 1129], [578, 1137], [819, 1137], [112, 1377], [333, 1392], [581, 1434], [820, 1434]], 'SW': [[253, 219], [592, 176], [844, 199], [1147, 174], [144, 516], [471, 519], [888, 489], [1227, 489], [226, 850], [560, 899], [934, 922], [1266, 940]]}
specs={
'E':('E_W_v01.png',4,0,[139,237],1.0),
'W':('W_v02.png',4,0,[112,239],1.0),
'NE':('NE_v03.png',4,0,[155,232],1.0),
'NW':('NE_NW_v01.png',4,12,[101,232],1.0),
'S':('S_N_v01.png',4,0,[168,230],.91),
'N':('S_N_v01.png',4,12,[109,228],.91),
'SW':('SW_v03.png',4,0,[143,238],.90),
}
cache={}
for direction,(file,cols,offset,sole,width) in specs.items():
    source=ROOT/file
    if file not in cache:
        a=np.array(Image.open(source).convert('RGBA'))
        boxes=sorted(components(a),key=lambda b:b[1])
        assert len(boxes)==(12 if file in ['NE_v03.png','SW_v03.png','W_v02.png'] else 24),(file,len(boxes))
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
    views[direction]=dict(texture='res://assets/characters/PasseRive/sprites_s31_drain/'+file,
        source_height=boxes[offset][3]-boxes[offset][1],width_factor=width,
        sequence=(old['sequence'] if direction == 'E' else [0,1,2,3,4,5,6,7,7,9,10,11] if direction=='NW' else list(range(12))),duration_ms=old['duration_ms'],frames=frames,
        support=[(sole[j]-g['anchor'][j])*g['scale'] for j in range(2)],
        palette={group:dict(center=c.tolist(),gain=np.clip(target[group]/c,.65,1.5).tolist()) for group,c in colors.items()},
        source_sha256=hashlib.sha256(source.read_bytes()).hexdigest())
(OUT/'drain.json').write_text(json.dumps(dict(version='S31-drain-directions-v01',duration_seconds=.94,release_seconds=.33,views=views),indent=2),encoding='utf8')
print(json.dumps({d:dict(height=v['source_height'],support=v['support']) for d,v in views.items()}))
