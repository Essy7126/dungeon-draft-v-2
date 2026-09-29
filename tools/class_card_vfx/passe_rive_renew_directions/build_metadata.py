"""Register immutable imagegen sprites against native idles, including active hand sockets."""
from pathlib import Path
from PIL import Image
import numpy as np
import json, shutil, hashlib, importlib.util
from inspect_sources import components
GAME=Path(__file__).resolve().parents[3]
ROOT=GAME/'art/source/passe_rive_s31/renew/sources'
OUT=GAME/'assets/characters/PasseRive/sprites_s31_renew'
OUT.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('palette',GAME/'tools/class_card_vfx/build_passe_rive_palette.py')
palette=importlib.util.module_from_spec(spec);spec.loader.exec_module(palette)
native=GAME/'assets/characters/PasseRive/autosprite_v1'
geom=json.loads((native/'manifest.json').read_text(encoding='utf8'))['geometry']
target=palette.colors(native/'PasseRive-iso_idle_southeast-v1.png')
old=json.loads((GAME/'assets/characters/PasseRive/sprites_s30/renew.json').read_text(encoding='utf8'))
views={'SE':dict(old,texture='res://assets/characters/PasseRive/sprites_s30/renew.png',width_factor=.85,support=[-18.3333584,17.19648])}
# Hand centers were reviewed on full-resolution drawings, not inferred from direction.
hands={'E': [[[147, 164], [157, 147]], [[421, 159], [437, 134]], [[658, 164], [676, 136]], [[894, 143], [934, 104]], [[95, 404], [194, 361]], [[340, 392], [456, 285]], [[578, 382], [692, 278]], [[828, 385], [942, 278]], [[180, 640], [182, 620]], [[430, 651], [432, 633]], [[659, 674], [676, 653]], [[902, 682], [915, 670]]], 'W': [[[115, 933], [107, 908]], [[360, 930], [343, 905]], [[610, 930], [594, 905]], [[884, 917], [849, 866]], [[84, 1138], [79, 1120]], [[442, 1158], [328, 1047]], [[694, 1148], [579, 1045]], [[952, 1151], [826, 1048]], [[95, 1402], [93, 1384]], [[354, 1402], [350, 1384]], [[602, 1422], [603, 1410]], [[877, 1441], [865, 1423]]], 'NE': [[[115, 124], [186, 162]], [[356, 132], [453, 158]], [[612, 132], [703, 158]], [[851, 117], [978, 118]], [[85, 377], [228, 385]], [[363, 284], [489, 367]], [[619, 283], [745, 368]], [[875, 283], [998, 368]], [[86, 637], [225, 654]], [[353, 651], [457, 669]], [[613, 653], [703, 682]], [[877, 653], [952, 683]]], 'NW': [[[89, 934], [166, 891]], [[325, 916], [431, 895]], [[578, 916], [688, 895]], [[822, 889], [973, 874]], [[55, 1139], [209, 1121]], [[318, 1038], [483, 1128]], [[576, 1038], [738, 1137]], [[834, 1038], [989, 1137]], [[67, 1410], [207, 1377]], [[328, 1413], [446, 1383]], [[601, 1424], [685, 1406]], [[858, 1424], [936, 1406]]], 'S': [[[78, 152], [177, 153]], [[326, 144], [446, 143]], [[582, 137], [687, 143]], [[829, 112], [963, 112]], [[47, 357], [211, 357]], [[306, 371], [445, 291]], [[561, 386], [679, 274]], [[814, 366], [949, 281]], [[58, 628], [198, 628]], [[327, 652], [443, 652]], [[589, 666], [693, 665]], [[847, 666], [948, 666]]], 'N': [[[77, 925], [182, 925]], [[323, 911], [448, 911]], [[579, 907], [696, 907]], [[825, 873], [967, 873]], [[38, 1118], [217, 1118]], [[324, 1046], [473, 1138]], [[586, 1039], [726, 1147]], [[835, 1045], [983, 1137]], [[57, 1393], [200, 1393]], [[320, 1410], [451, 1410]], [[591, 1422], [695, 1422]], [[847, 1422], [948, 1422]]], 'SW': [[[135, 172], [216, 229]], [[490, 180], [614, 229]], [[855, 183], [966, 222]], [[1193, 148], [1340, 187]], [[104, 502], [277, 533]], [[445, 478], [597, 391]], [[802, 525], [956, 392]], [[1166, 515], [1318, 395]], [[107, 868], [260, 895]], [[480, 888], [604, 919]], [[856, 899], [946, 946]], [[1219, 909], [1313, 974]]]}
specs={'E': ('E_W_v02.png', 4, 0, [139, 237], 1.0), 'W': ('E_W_v02.png', 4, 12, [112, 239], 1.0), 'NE': ('NE_NW_v02.png', 4, 0, [155, 232], 1.0), 'NW': ('NE_NW_v02.png', 4, 12, [101, 232], 1.0), 'S': ('S_N_v01.png', 4, 0, [168, 230], 0.91), 'N': ('S_N_v01.png', 4, 12, [109, 228], 0.91), 'SW': ('SW_v01.png', 4, 0, [143, 238], 0.9)}
cache={}
for direction,(file,cols,offset,sole,width) in specs.items():
    source=ROOT/file
    if file not in cache:
        a=np.array(Image.open(source).convert('RGBA'))
        boxes=sorted(components(a),key=lambda b:b[1])
        assert len(boxes)==(12 if file == 'SW_v01.png' else 24),(file,len(boxes))
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
        sockets=[[point[0]-x0,point[1]-y0] for point in hands[direction][i]]
        for hand in sockets:
            assert 0<=hand[0]<x1-x0 and 0<=hand[1]<y1-y0,(direction,i,hand,[x0,y0,x1,y1])
        frames.append(dict(region=[x0,y0,x1-x0,y1-y0],pivot=pivot,hands=sockets,solid_bbox=[3,3,x1-x0-3,y1-y0-3]))
    g=geom['idle_'+direction]
    views[direction]=dict(texture='res://assets/characters/PasseRive/sprites_s31_renew/'+file,
        source_height=boxes[offset][3]-boxes[offset][1],width_factor=width,
        sequence=old['sequence'],duration_ms=old['duration_ms'],short_sequence=old['short_sequence'],short_duration_ms=old['short_duration_ms'],vfx=old['vfx'],frames=frames,
        support=[(sole[j]-g['anchor'][j])*g['scale'] for j in range(2)],
        palette={group:dict(center=c.tolist(),gain=np.clip(target[group]/c,.65,1.5).tolist()) for group,c in colors.items()},
        source_sha256=hashlib.sha256(source.read_bytes()).hexdigest())
(OUT/'renew.json').write_text(json.dumps(dict(version='S31-renew-directions-v01',duration_seconds=1.12,release_seconds=.45,views=views),indent=2),encoding='utf8')
print(json.dumps({d:dict(height=v['source_height'],support=v['support']) for d,v in views.items()}))
