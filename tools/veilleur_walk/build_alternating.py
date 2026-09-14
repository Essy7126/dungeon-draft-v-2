"""Six cutout poses. Exchange leg roles at the hips; no interpolated frames."""
from pathlib import Path
import json
import numpy as np
from scipy import ndimage as ndi
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[2]
OLD=ROOT/'artifacts/spine_trial/veilleur_walk_simple_v1'
OUT=ROOT/'artifacts/spine_trial/veilleur_walk_simple_v2'
DEST=ROOT/'assets/characters/Achilles/veilleur_walk_simple_v2'
for folder in [OUT,DEST]:folder.mkdir(parents=True,exist_ok=True)
(OUT/'.gdignore').touch()
# Near/far leg paths on the three retained original drawings.
PATHS={
 'E':[
  ([[113,160],[107,180],[100,202]],[[134,160],[148,198],[163,226]]),
  ([[115,160],[108,180],[103,205]],[[136,160],[140,197],[143,226]]),
  ([[116,163],[123,187],[116,208]],[[139,163],[137,198],[137,226]])],
 'S':[
  ([[139,162],[147,180],[151,205]],[[118,162],[110,197],[99,226]]),
  ([[139,162],[146,184],[148,205]],[[118,162],[114,199],[108,226]]),
  ([[138,164],[131,190],[139,210]],[[117,164],[119,200],[120,227]])],
 'N':[
  ([[136,170],[120,198],[106,225]],[[115,170],[133,195],[145,206]]),
  ([[136,170],[122,198],[111,224]],[[115,170],[131,195],[139,206]]),
  ([[136,170],[126,199],[117,222]],[[115,170],[132,196],[141,211]])],
 'W':[
  ([[118,170],[137,198],[151,226]],[[139,170],[121,196],[110,207]]),
  ([[118,170],[135,200],[147,225]],[[139,170],[123,196],[115,208]]),
  ([[118,170],[133,200],[141,225]],[[139,170],[125,196],[117,210]])],
}
def distances(points):
    y,x=np.mgrid[:256,:256];q=np.stack([x,y],axis=2);best=np.full((256,256),1e9)
    for a,b in zip(points,points[1:]):
        a=np.array(a);b=np.array(b);v=b-a
        t=np.clip(((q-a)*v).sum(2)/(v*v).sum(),0,1)
        best=np.minimum(best,((q-(a+t[:,:,None]*v))**2).sum(2))
    return best
def exchange(im,d,k):
    rgba=np.array(im);rgb=rgba[:,:,:3];alpha=rgba[:,:,3]>128
    ivory=(rgb[:,:,0]>170)&(rgb[:,:,1]>150)&(rgb[:,:,2]>95)&alpha
    y,x=np.nonzero(ivory[145:174,105:152]);cut=145+int(y.max())+1
    lower=alpha.copy();lower[:cut]=False
    labels,_=ndi.label(lower)
    ids=np.unique(labels[cut:cut+7,105:152]);ids=ids[ids!=0]
    legmask=np.isin(labels,ids)&(labels>0)
    near,far=PATHS[d][k]
    nmask=legmask&(distances(near)<=distances(far));fmask=legmask&~nmask
    upper=rgba.copy();upper[legmask]=0
    out=Image.fromarray(upper,'RGBA')
    shift=np.rint(np.array(near[0])-far[0]).astype(int)
    # Far leg first. Translation changes hip attachment without mirroring the boot.
    for mask,offset in [(nmask,-shift),(fmask,shift)]:
        piece=rgba.copy();piece[~mask]=0
        out.alpha_composite(Image.fromarray(piece,'RGBA'),tuple(map(int,offset)))
    out.alpha_composite(Image.fromarray(upper,'RGBA'))
    diff=np.any(np.array(out)!=rgba,2)
    assert not diff[:cut].any()
    return out,{'cut_y':cut,'hip_offset':shift.tolist(),'leg_pixels':int(legmask.sum()),'changed_pixels':int(diff.sum()),'above_cut_changes':0}
data=json.loads((OLD/'walk_review.json').read_text(encoding='utf8'))
N=6;W=256
data.update(name='Veilleur — alternance en six poses',frame_count=N,duration=.7,rest_frame=2,
    frame_resource='res://assets/characters/Achilles/veilleur_walk_simple_v2/walk_frames.tres',
    method='Six discrete cutout poses; leg roles exchanged at original hips; upper body preserved')
report={'order':['appui A 1','appui A 2','passage','appui B 1','appui B 2','passage'],
        'source_indices':[0,1,6],'views':{},'new_drawings_used':False,'imagegen_attempts_discarded':2}
sheet=Image.new('RGB',(W*N,W*4),(43,57,53));draw=ImageDraw.Draw(sheet)
for r,d in enumerate(data['order']):
    originals=[Image.open(OLD/f'frames/{d}/{i:02d}.png').convert('RGBA') for i in [0,1,6]]
    frames=list(originals);records=[]
    for k,im in enumerate(originals):
        fixed,info=exchange(im,d,k);frames.append(fixed);records.append(info)
    folder=OUT/'frames'/d;folder.mkdir(parents=True,exist_ok=True)
    for i,f in enumerate(frames):
        f.save(folder/f'{i:02d}.png');sheet.paste(f,(i*W,r*W),f)
        draw.text((i*W+7,r*W+7),f'{d} {i+1} / '+report['order'][i],fill='white')
    atlas=Image.new('RGBA',(W*N,W))
    for i,f in enumerate(frames):atlas.alpha_composite(f,(i*W,0))
    for path in [OUT/f'{d}_atlas.png',DEST/f'{d}_atlas.png']:atlas.save(path)
    frames[0].save(OUT/f'{d}_walk.webp',save_all=True,append_images=frames[1:],duration=[117,117,116,117,117,116],lossless=True,loop=0)
    data['views'][d]['frames']=[f'frames/{d}/{i:02d}.png' for i in range(N)]
    report['views'][d]=records
lines=[f'[gd_resource type="SpriteFrames" load_steps={4+4*N+1} format=3]','']
for d in data['order']:lines.append(f'[ext_resource type="Texture2D" path="res://assets/characters/Achilles/veilleur_walk_simple_v2/{d}_atlas.png" id="{d}"]')
for d in data['order']:
    for i in range(N):lines+=['',f'[sub_resource type="AtlasTexture" id="{d}_{i}"]',f'atlas = ExtResource("{d}")',f'region = Rect2({i*W}, 0, {W}, {W})']
lines+=['','[resource]','animations = [']
for ix,d in enumerate(data['order']):
    entries=',\n'.join(f'{{"duration": 1.0, "texture": SubResource("{d}_{i}")}}' for i in range(N))
    lines.append('{"frames": [\n'+entries+'\n], "loop": true, "name": &"walk_'+d+'", "speed": '+str(N/.7)+'}'+(',' if ix<3 else ''))
lines+= [']',''];(DEST/'walk_frames.tres').write_text('\n'.join(lines),encoding='utf8')
for p in [DEST/'manifest.json',OUT/'walk_review.json']:p.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
sheet.save(OUT/'all_poses.jpg',quality=95)
(OUT/'repair_report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(OUT/'all_poses.jpg')
