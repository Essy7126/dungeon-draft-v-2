"""Register immutable imagegen sprites against native idles, including active hand sockets."""
from pathlib import Path
from PIL import Image
import numpy as np
import json, shutil, hashlib, importlib.util
from inspect_sources import components
GAME=Path(__file__).resolve().parents[3]
ROOT=GAME/'art/source/passe_rive_s31/pull/sources'
OUT=GAME/'assets/characters/PasseRive/sprites_s31_pull'
OUT.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('palette',GAME/'tools/class_card_vfx/build_passe_rive_palette.py')
palette=importlib.util.module_from_spec(spec);spec.loader.exec_module(palette)
native=GAME/'assets/characters/PasseRive/autosprite_v1'
geom=json.loads((native/'manifest.json').read_text(encoding='utf8'))['geometry']
target=palette.colors(native/'PasseRive-iso_idle_southeast-v1.png')
old=json.loads((GAME/'assets/characters/PasseRive/sprites_s25/pull.json').read_text(encoding='utf8'))
views={'SE':dict(old,texture='res://assets/characters/PasseRive/sprites_s25/pull.png',width_factor=1.0,support=[-18.3333584,17.19648])}
# Hand centers were reviewed on full-resolution drawings, not inferred from direction.
hands={
'E':[[184,165],[414,125],[641,96],[926,84],[265,322],[491,327],[651,360],[879,356],[207,620],[430,656],[645,677],[884,677]],
'W':[[139,920],[362,906],[593,856],[790,848],[74,1086],[308,1094],[585,1114],[837,1119],[125,1387],[361,1420],[601,1422],[837,1422]],
'NE':[[132,213],[296,174],[454,136],[668,124],[838,114],[995,126],[127,465],[295,447],[475,472],[650,501],[817,501],[984,500]],
'NW':[[52,854],[222,828],[401,788],[539,783],[701,765],[883,774],[68,1137],[220,1118],[400,1147],[560,1175],[733,1174],[897,1174]],
'S':[[108,162],[360,133],[600,110],[810,114],[112,341],[364,360],[607,371],[849,372],[120,641],[352,662],[573,671],[815,671]],
'N':[[215,922],[453,859],[669,834],[925,818],[205,1063],[451,1064],[678,1091],[930,1116],[208,1349],[455,1404],[685,1423],[925,1424]],
'SW':[[170,169],[517,151],[889,120],[1140,144],[101,460],[452,460],[890,485],[1227,478],[202,846],[511,901],[858,901],[1196,901]],
}
specs={
'E':('E_W_v02.png',4,0,[139,237],1.0),
'W':('E_W_v02.png',4,12,[112,239],1.0),
'NE':('NE_NW_v01.png',6,0,[155,232],1.0),
'NW':('NE_NW_v01.png',6,12,[101,232],1.0),
'S':('S_N_v01.png',4,0,[168,230],.91),
'N':('S_N_v01.png',4,12,[109,228],.91),
'SW':('SW_v02.png',4,0,[143,238],.90),
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
    views[direction]=dict(texture='res://assets/characters/PasseRive/sprites_s31_pull/'+file,
        source_height=boxes[offset][3]-boxes[offset][1],width_factor=width,
        sequence=old['sequence'],duration_ms=old['duration_ms'],frames=frames,
        support=[(sole[j]-g['anchor'][j])*g['scale'] for j in range(2)],
        palette={group:dict(center=c.tolist(),gain=np.clip(target[group]/c,.65,1.5).tolist()) for group,c in colors.items()},
        source_sha256=hashlib.sha256(source.read_bytes()).hexdigest())
(OUT/'pull.json').write_text(json.dumps(dict(version='S31-pull-directions-v01',duration_seconds=.89,release_seconds=.4,views=views),indent=2),encoding='utf8')
print(json.dumps({d:dict(height=v['source_height'],support=v['support']) for d,v in views.items()}))


