"""Cut out one generated sheet and pack its drawn poses; no rig or interpolation."""
from pathlib import Path
import json, hashlib
import numpy as np
from scipy import ndimage as ndi
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/source/characters/achilles/veilleur_walk_simple_v1'
OUT=ROOT/'artifacts/spine_trial/veilleur_walk_simple_v1'
DEST=ROOT/'assets/characters/Achilles/veilleur_walk_simple_v1'
for folder in [OUT,DEST]: folder.mkdir(parents=True,exist_ok=True)
(OUT/'.gdignore').touch()
rgb=np.array(Image.open(SRC/'sheet.png').convert('RGB'))
v=rgb.astype(np.int16)
# Painted checkerboard is neutral light grey; preserve coloured ivory and dark outlines.
mask=((v.max(2)-v.min(2)>12)|(v.max(2)<130))
labels,count=ndi.label(mask)
objects=ndi.find_objects(labels)
components=[]
for i,box in enumerate(objects,1):
    if box is None: continue
    area=int((labels[box]==i).sum())
    if area>2000:
        y,x=box
        components.append({'id':i,'box':[x.start,y.start,x.stop,y.stop],'area':area})
rows=[[] for _ in range(4)]
for c in components:
    x0,y0,x1,y1=c['box']; row=min(3,int(((y0+y1)/2)/rgb.shape[0]*4))
    rows[row].append(c)
for row in rows: row.sort(key=lambda c:c['box'][0])
assert [len(r) for r in rows]==[7]*4, [(c['box'],c['area']) for c in components]
N=7; W=256; DURATION=.7; SCALE=.52
names=['E','S','N','W']; labels_fr=['Bas droite','Bas gauche','Haut droite','Haut gauche']
data={'name':'Veilleur — marche simple dessinée','order':names,'canvas':[W,W],
      'frame_count':N,'duration':DURATION,'display_scale':SCALE,'views':{},'rest_frame':1,
      'frame_resource':'res://assets/characters/Achilles/veilleur_walk_simple_v1/walk_frames.tres',
      'artistic_approval':False,'generation_calls':1,'method':'Whole drawn poses; cutout and translation only'}
report={'source_sha256':hashlib.sha256((SRC/'sheet.png').read_bytes()).hexdigest(),
        'requested_poses_per_view':8,'actual_poses_per_view':7,'views':{},'interpolation':False}
contact=Image.new('RGB',(W*N,W*4),(43,57,53));draw=ImageDraw.Draw(contact)
for row,d in zip(rows,names):
    folder=OUT/'frames'/d;folder.mkdir(parents=True,exist_ok=True)
    frames=[];records=[]
    for i,c in enumerate(row):
        x0,y0,x1,y1=c['box']; submask=labels[y0:y1,x0:x1]==c['id']
        # Fill tiny antialias gaps only. Keep real negative spaces between arms/legs.
        holes,hc=ndi.label(~submask); sizes=np.bincount(holes.ravel())
        submask|=(sizes[holes]<10)
        rgba=np.dstack([rgb[y0:y1,x0:x1],submask.astype(np.uint8)*255])
        piece=Image.fromarray(rgba,'RGBA')
        h,w=submask.shape
        # Align the waist, rather than the changing outer extent of hands/feet.
        yy,xx=np.nonzero(submask[int(h*.50):int(h*.62)])
        center=int(round(float(np.median(xx))))
        offset=(128-center,239-h)
        frame=Image.new('RGBA',(W,W));frame.alpha_composite(piece,offset)
        assert frame.getbbox()[0]>0 and frame.getbbox()[2]<W and frame.getbbox()[1]>0
        frame.save(folder/f'{i:02d}.png');frames.append(frame)
        contact.paste(frame,(i*W,names.index(d)*W),frame)
        draw.text((i*W+8,names.index(d)*W+8),f'{d} / {i+1}',fill='white')
        records.append({'source_bbox':c['box'],'waist_center':center,'offset':offset,'opaque_pixels':int(submask.sum())})
    atlas=Image.new('RGBA',(W*N,W))
    for i,frame in enumerate(frames):atlas.alpha_composite(frame,(i*W,0))
    for folder_out in [OUT,DEST]:atlas.save(folder_out/f'{d}_atlas.png')
    frames[0].save(OUT/f'{d}_walk.webp',save_all=True,append_images=frames[1:],duration=100,loop=0,lossless=True)
    data['views'][d]={'label':labels_fr[names.index(d)],'atlas':f'{d}_atlas.png',
        'pivot':[128,239],'stride':[90*(1 if d in ['E','N'] else -1),45*(1 if d in ['E','S'] else -1)],
        'frames':[f'frames/{d}/{i:02d}.png' for i in range(N)]}
    report['views'][d]=records
lines=[f'[gd_resource type="SpriteFrames" load_steps={4+4*N+1} format=3]','']
for d in names:lines.append(f'[ext_resource type="Texture2D" path="res://assets/characters/Achilles/veilleur_walk_simple_v1/{d}_atlas.png" id="{d}"]')
for d in names:
    for i in range(N):lines+=['',f'[sub_resource type="AtlasTexture" id="{d}_{i}"]',f'atlas = ExtResource("{d}")',f'region = Rect2({i*W}, 0, {W}, {W})']
lines+=['','[resource]','animations = [']
for idx,d in enumerate(names):
    entries=',\n'.join(f'{{"duration": 1.0, "texture": SubResource("{d}_{i}")}}' for i in range(N))
    lines.append('{"frames": [\n'+entries+f'\n], "loop": true, "name": &"walk_{d}", "speed": 10.0'+'}'+(',' if idx<3 else ''))
lines+= [']',''];(DEST/'walk_frames.tres').write_text('\n'.join(lines),encoding='utf8')
for p in [DEST/'manifest.json',OUT/'walk_review.json']:
    p.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
(OUT/'cutout_report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
contact.save(OUT/'all_poses.jpg',quality=93)
print(json.dumps({'directions':4,'frames':N*4,'fps':10,'duration':DURATION,'contact_sheet':str(OUT/'all_poses.jpg')}))
