"""Authored 2D walk from the actual ORA source, with drawn boot substitutions."""
from pathlib import Path
import sys,math,json,hashlib
import numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/character_concept'))
sys.path.insert(0,str(ROOT/'tools/passe_rive_motion'))
from ora_export import read_layers
import walk_model as gait
gait.STRIDE=.85;gait.DURATION=1.1
gait.TOE=.24
SRC=ROOT/'art/source/characters/achilles/veilleur_walk_E_v1'
OUT=ROOT/'artifacts/spine_trial/veilleur_walk_E_v1'
FRAMES=OUT/'frames';FRAMES.mkdir(exist_ok=True)
layout=json.loads((SRC/'parts_layout.json').read_text())
parts={name:(im,xy) for name,im,xy in read_layers(SRC/'source_parts.ora')[1]}
W=512;PIVOT=(256,432);S=200;N=48

def project(p):
    x,y,z=p;return np.array([PIVOT[0]+S*(y-x),PIVOT[1]+S*(.5*(x+y)-z)])
def local_anchor(name,uv):
    orig=layout[name];im,xy=parts[name]
    return np.array([orig['origin'][0]+uv[0]*orig['size'][0]-xy[0],orig['origin'][1]+uv[1]*orig['size'][1]-xy[1]])
def affine(name,src,dst):
    im,_=parts[name]
    a=np.column_stack([np.array(src),np.ones(3)])
    forward=np.linalg.solve(a,np.array(dst)).T
    matrix=np.vstack([forward,[0,0,1]])
    inverse=np.linalg.inv(matrix)
    # Premultiplied resampling keeps transparent RGB from staining contours.
    return im.convert('RGBa').transform((W,W),Image.Transform.AFFINE,tuple(inverse[:2].ravel()),resample=Image.Resampling.BICUBIC).convert('RGBA')
def segment(name,p0,p1,uv0,uv1,width_factor=1):
    a,b=local_anchor(name,uv0),local_anchor(name,uv1)
    delta=b-a;span=np.linalg.norm(delta);v=np.array(p1)-p0;length=np.linalg.norm(v)
    src=[a,b,a+np.array([-delta[1],delta[0]])/span*40]
    dst=[p0,p1,np.array(p0)+np.array([-v[1],v[0]])/length*40*length/span*width_factor]
    return affine(name,src,dst)
def knee(hip,ankle):
    l1,l2=.315,.315;delta=np.array(ankle)-hip;d=np.linalg.norm(delta)
    if d>l1+l2+1e-5:raise ValueError(f'Overextended leg {d}')
    u=delta/d;along=(l1*l1-l2*l2+d*d)/(2*d)
    bend=math.sqrt(max(0,l1*l1-along*along));perp=np.array([0,-u[2],u[1]]);perp/=np.linalg.norm(perp)
    return np.array(hip)+u*along+perp*bend
def core(name,point,angle):
    im,xy=parts[name];origin=layout[name]['canon_origin'];base=np.array([637,676]);c,s=math.cos(angle),math.sin(angle)
    rotation=np.array([[c,-s],[s,c]])*.32
    src=[np.array([0,0]),np.array([im.width,0]),np.array([0,im.height])]
    # Handle any later ORA recropping using the original atlas coordinates.
    offset=np.array(xy)-layout[name]['origin']+origin
    dst=[np.array(point)+rotation@(p+offset-base) for p in src]
    return affine(name,src,dst)
foot_uv={
 'flat':[(.04,.75),(.85,.97),(.34,.07)],
 'toe':[(.03,.57),(.87,.96),(.58,.12)],
 'swing':[(.04,.50),(.85,.97),(.56,.11)],
 'heel':[(.08,.93),(.94,.72),(.32,.06)]}
frames=[];motion=[]
for index in range(N):
    t=index/N;a=math.tau*t
    root=np.array([.04*math.sin(a),0,.805-.012*math.sin(2*a)])
    rp=project(root);angle=math.radians(1.4)*math.cos(a)
    layers={};foot_data={};ik_error=[]
    for side,sign in [('L',-1),('R',1)]:
        f=gait.foot(t-.5,side)
        for key in ('ankle','heel','toe'):f[key][0]=sign*.112
        cuff=np.array(f['ankle'])+gait.rotate_x([0,0,.18],f['pitch'])
        hip=root+np.array([sign*.12,sign*.014*math.cos(a),0])
        k=knee(hip,cuff)
        ik_error.extend([abs(np.linalg.norm(k-hip)-.315),abs(np.linalg.norm(k-cuff)-.315)])
        hp,kp,ap=map(project,(hip,k,cuff))
        uv0=(.63,.16) if side=='R' else (.38,.16)
        uv1=(.33,.82) if side=='R' else (.68,.82)
        layers['thigh_'+side]=segment('thigh_'+side,hp,kp,uv0,uv1,.72)
        shin0=(.60,.20) if side=='R' else (.40,.20)
        shin1=(.26,.87) if side=='R' else (.73,.87)
        layers['shin_'+side]=segment('shin_'+side,kp,ap,shin0,shin1,1.03)
        state=f['contact'] if f['contact'] in ['heel','toe','swing'] else 'flat'
        # Flat boot through most of swing avoids an unnecessary long held toe tuck.
        name=state+'_'+side
        src=[local_anchor(name,p) for p in foot_uv[state]]
        dest=[project(f['heel']),project(f['toe']),ap]
        layers['boot_'+side]=affine(name,src,dest)
        foot_data[side]={'state':state,'heel':dest[0].tolist(),'toe':dest[1].tolist(),'cuff':ap.tolist(),
                         'source_piece':name,'source_contact_annotations':foot_uv[state]}
        shoulder_source=np.array([475,414]) if side=='R' else np.array([752,414])
        c,s=math.cos(angle),math.sin(angle);rot=np.array([[c,-s],[s,c]])*.32
        shoulder=rp+rot@(shoulder_source-np.array([637,676]))
        swing=-sign*.34*math.cos(a)
        elbow=shoulder+np.array([math.sin(swing)*53,math.cos(swing)*53+math.sin(swing)*26.5])
        hand=elbow+np.array([math.sin(swing+.14)*50,math.cos(swing+.14)*50+math.sin(swing+.14)*25])
        arm0=(.73,.08) if side=='R' else (.24,.08);arm1=(.24,.84) if side=='R' else (.72,.84)
        layers['arm_'+side]=segment('arm_'+side,shoulder,elbow,arm0,arm1,1.25)
        layers['hand_'+side]=segment('hand_'+side,elbow,hand,(.50,.10),(.52,.84),1.3)
    image=Image.new('RGBA',(W,W))
    for name in ['hand_L','arm_L','shin_L','thigh_L','boot_L','shin_R','thigh_R','boot_R','arm_R']:
        image.alpha_composite(layers[name])
    image.alpha_composite(core('head',rp,angle))
    image.alpha_composite(core('body',rp,angle))
    image.alpha_composite(layers['hand_R'])
    # Shoulder and neck seams hide beneath original mantle, while hand stays in front.
    # Near arm remains below the mantle's top; local seam checked in the contact sheet.
    box=image.getchannel('A').getbbox()
    assert box and min(box)>0 and box[2]<W and box[3]<W
    image.save(FRAMES/f'{index:02}.png');frames.append(image)
    motion.append({'index':index,'phase':t,'feet':foot_data,'bbox':box,'max_ik_length_error':max(ik_error)})

# Check annotated points in exported transforms, within unchanged contact states.
drifts=[]
for i in range(N):
    j=(i+1)%N
    for side in 'LR':
        prev,nxt=motion[i]['feet'][side],motion[j]['feet'][side]
        if prev['state']!=nxt['state'] or prev['state']=='swing':continue
        # Exclude the transition between separate stance phases across contact reset.
        ph0=gait.foot(i/N-.5,side)['phase'];ph1=gait.foot((i+1)/N-.5,side)['phase']
        if ph1<ph0:continue
        key='heel' if prev['state']=='heel' else 'toe'
        delta=np.array(nxt[key])-prev[key]+np.array([S*gait.STRIDE,S*gait.STRIDE*.5])/N
        drifts.append(float(np.linalg.norm(delta)))
assert max(drifts)<1e-6
atlas=Image.new('RGBA',(W*8,W*6))
for i,im in enumerate(frames):atlas.alpha_composite(im,((i%8)*W,(i//8)*W))
atlas.save(OUT/'walk_E_atlas.png')
board=Image.new('RGB',(1536,1536),'#243b40');d=ImageDraw.Draw(board);font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',22)
for i in range(12):
    im=frames[i*4];im=im.resize((384,384),Image.Resampling.LANCZOS)
    x=i%4*384;y=i//4*512
    board.paste(im,(x,y+45),im);d.text((x+14,y+10),f'{i*4:02}',font=font,fill='white')
board.save(OUT/'poses.jpg',quality=95)
frames[0].save(OUT/'walk_E.png',save_all=True,append_images=frames[1:],duration=1100/N,loop=0,disposal=1,blend=0)
preview=[]
for im in frames:
    bg=Image.new('RGBA',(W,W),'#243b40');bg.alpha_composite(im);preview.append(bg)
preview[0].save(OUT/'walk_E.webp',save_all=True,append_images=preview[1:],duration=round(1100/N),loop=0,lossless=True)
manifest={'name':'Veilleur d’airain — marche E','status':'single_direction_art_review', 'frame_size':[W,W],'pivot':PIVOT,'frame_count':N,'duration_ms':1100,
 'stride':[S*gait.STRIDE,S*gait.STRIDE*.5],'frames':[f'frames/{i:02}.png' for i in range(N)],
 'source':'source_parts.ora','source_sha256':hashlib.sha256((SRC/'source_parts.ora').read_bytes()).hexdigest(),
 'method':'2D cutout with authored IK and four drawn boot states per side; no mirrored character',
 'body_scale':.32,'comparison_heights':[112,280],
 'limits':['Une direction seulement.','Les 48 images échantillonnent un montage 2D, pas 48 nouveaux dessins.',
 'La mesure suit les points de semelle annotés sur les pièces, pas un suivi indépendant exhaustif de chaque pixel du pied.',
 'Les transitions entre les dessins de bottes et les raccords des articulations restent à examiner artistiquement.',
 'Laboratoire de marche, pas intégration à la campagne.']}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding='utf8')
(SRC/'motion.json').write_text(json.dumps(motion,indent=2))
(OUT/'geometry_report.json').write_text(json.dumps({'frames':N,'max_contact_annotation_drift_source_pixels':max(drifts),'sample_pairs':len(drifts),'max_leg_length_error':max(m['max_ik_length_error'] for m in motion),'scope':manifest['limits'][2]},indent=2))
print(json.dumps({'frames':N,'max_contact_annotation_drift':max(drifts)}))
