"""Measure and register immutable generated drawings; never resample source pixels."""
from pathlib import Path
from PIL import Image
import numpy as np
import json,shutil,hashlib,importlib.util
from inspect_sources import components
GAME=Path(__file__).resolve().parents[3]
ROOT=GAME/'art/source/passe_rive_s32/sources'
OUT=GAME/'assets/characters/PasseRive/sprites_s32'
OUT.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('palette',GAME/'tools/class_card_vfx/build_passe_rive_palette.py')
palette=importlib.util.module_from_spec(spec);spec.loader.exec_module(palette)
native=GAME/'assets/characters/PasseRive/autosprite_v1'
geom=json.loads((native/'manifest.json').read_text(encoding='utf8'))['geometry']
target=palette.colors(native/'PasseRive-iso_idle_southeast-v1.png')
specs={'SE':('SE_v01.png',0,None,.90),'E':('E_W_v01.png',0,[139,237],1.0),'W':('W_v02.png',0,[112,239],1.0),'NE':('NE_v03.png',0,[155,232],1.0),'NW':('NW_v03.png',0,[101,232],.95),'S':('S_N_v01.png',0,[168,230],.91),'N':('N_v02.png',0,[109,228],.91),'SW':('SW_v01.png',0,[143,238],.90)}
# Receiving LEFT palm, inspected in full atlas coordinates. Rear-view sockets may
# be occluded by the torso; their glyph layer is correspondingly behind the body.
hands={
'SE':[[263,185],[610,190],[952,188],[1336,166],[300,510],[640,510],[941,529],[1290,522],[277,887],[611,901],[958,906],[1311,906]],
'E':[[227,131],[509,130],[794,127],[1095,116],[261,323],[543,323],[802,334],[1084,334],[249,560],[528,570],[785,584],[1071,584]],
'W':[[204,211],[564,211],[921,211],[1233,164],[158,531],[517,531],[888,528],[1244,531],[177,925],[563,929],[921,928],[1277,931]],
'NE':[[251,240],[550,237],[844,236],[1140,233],[286,592],[581,592],[852,604],[1143,605],[259,1020],[563,1040],[850,1038],[1151,1037]],
'NW':[[199,193],[496,193],[805,193],[1110,178],[156,515],[499,508],[812,503],[1124,510],[188,892],[499,892],[809,892],[1150,892]],
'S':[[230,116],[617,116],[1002,116],[1383,106],[237,290],[624,290],[990,293],[1375,294],[227,501],[619,505],[1007,504],[1386,505]],
'N':[[116,233],[418,229],[711,227],[1008,608-412],[91,609],[396,609],[711,604],[1022,604],[112,1050],[403,1043],[710,1052],[1021,1052]],
'SW':[[233,198],[583,198],[922,198],[1260,163],[233,518],[581,518],[910,521],[1252,520],[229,908],[568,904],[916,918],[1265,919]]}
views={};cache={}
for direction,(file,offset,sole,width) in specs.items():
 source=ROOT/file
 if file not in cache:
  a=np.array(Image.open(source).convert('RGBA'))
  boxes=sorted(components(a),key=lambda b:b[1]);boxes=[p for i in range(0,len(boxes),4) for p in sorted(boxes[i:i+4],key=lambda b:b[0])]
  assert len(boxes)==(24 if file in ['E_W_v01.png','NE_NW_v02.png','S_N_v01.png'] else 12),(file,len(boxes))
  cache[file]=(a,boxes,palette.colors(source));shutil.copy2(source,OUT/file)
 a,boxes,colors=cache[file];frames=[]
 for i,b in enumerate(boxes[offset:offset+12]):
  # Tight rows in S share one transparent scanline; don't sample adjacent sprites.
  mx,my=3,(0 if file=='S_N_v01.png' else 2)
  x0,y0,x1,y1=b[0]-mx,b[1]-my,b[2]+mx,b[3]+my
  yy,xx=np.where(a[y0:y1,x0:x1,3]>220);foot=np.ones(len(xx),bool)
  if direction=='S':foot=xx>(x1-x0)*.53
  if direction=='N':foot=xx<(x1-x0)*.48
  bottom=int(yy[foot].max())+1;pivot=[float(np.median(xx[foot & (yy>=bottom-5)])),bottom]
  hand=[hands[direction][i][0]-x0,hands[direction][i][1]-y0]
  assert 0<=hand[0]<x1-x0 and 0<=hand[1]<y1-y0,(direction,i,hand,b)
  frames.append(dict(region=[x0,y0,x1-x0,y1-y0],pivot=pivot,hand=hand,solid_height=b[3]-b[1]))
 # Preserve the inward gathered palm for the hold; source7 reopens it early.
 if direction=='NW':frames[7]=dict(frames[6])
 # The head may nod in recovery, but must rise again before the native-idle blend.
 if direction=='S':
  frames[10]=dict(frames[0]);frames[11]=dict(frames[0])
 g=geom['idle_'+direction]
 views[direction]=dict(texture='res://assets/characters/PasseRive/sprites_s32/'+file,source_height=boxes[offset][3]-boxes[offset][1],width_factor=width,sequence=list(range(12)),duration_ms=[40,50,60,70,70,70,100,70,70,70,60,70],frames=frames,support=[-18.3333584,17.19648] if sole is None else [(sole[j]-g['anchor'][j])*g['scale'] for j in range(2)],palette={group:dict(center=c.tolist(),gain=np.clip(target[group]/c,.65,1.5).tolist()) for group,c in colors.items()},source_sha256=hashlib.sha256(source.read_bytes()).hexdigest())
shutil.copy2(ROOT/'glyph_v01.png',OUT/'glyph.png')
glyph=np.array(Image.open(ROOT/'glyph_v01.png').convert('RGBA'));yy,xx=np.where(glyph[:,:,3]>220)
(OUT/'recenter.json').write_text(json.dumps(dict(version='S32-recenter-v01',duration_seconds=.8,release_seconds=.36,glyph_height=int(yy.max()-yy.min()+1),views=views),indent=2),encoding='utf8')
print(json.dumps({d:dict(height=v['source_height'],variation=round(max(abs(f['solid_height']/v['source_height']-1) for f in v['frames']),4)) for d,v in views.items()}))
