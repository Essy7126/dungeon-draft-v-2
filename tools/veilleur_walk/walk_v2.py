"""Walk refinement on the proportion base accepted on 2026-09-12.

Read the frozen source pieces. Bone lengths and boot scale stay constant; only
the cloth around the knee is continuously mapped instead of split into blocks.
Contact checks measure annotated drawing points, not artistic walk quality.
"""
from pathlib import Path
import math,json,hashlib,shutil
import numpy as np
from scipy.ndimage import map_coordinates,gaussian_filter1d
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'art/source/characters/achilles/veilleur_proportions_v1'
SRC=ROOT/'art/source/characters/achilles/veilleur_walk_E_v2'
OUT=ROOT/'artifacts/spine_trial/veilleur_walk_E_v2'
SRC.mkdir(exist_ok=True);OUT.mkdir(exist_ok=True)
cfg=json.loads((BASE/'landmarks.json').read_text());J=cfg['joints']
S=cfg['scale'];W=512;N=48;DURATION=1.1
PIVOT=np.array([256.,442.]);ORIGIN=np.array([637.,1211.])
OFFSET=PIVOT-ORIGIN*S
PI=math.pi
parts={name:Image.open(BASE/(name+'.png')).convert('RGBA') for name in ['leg_L','leg_R','boot_L','boot_R','arm_L','arm_R','core']}
input_hashes={name:hashlib.sha256((BASE/(name+'.png')).read_bytes()).hexdigest() for name in parts}
boot_contacts={'R':{'heel':[438,1157],'toe':[546,1201]},'L':{'heel':[663,1075],'toe':[829,1113]}}
def project(p):return np.array(p,dtype=float)*S+OFFSET
def rotation(a):return np.array([[math.cos(a),-math.sin(a)],[math.sin(a),math.cos(a)]])
def rigid(image,anchor,target,angle=0):
    m=S*rotation(angle);inv=np.linalg.inv(m);offset=np.array(target)-m@np.array(anchor)
    coefficients=np.column_stack([inv,-inv@offset]).ravel()
    return image.convert('RGBa').transform((W,W),Image.Transform.AFFINE,tuple(coefficients),Image.Resampling.BICUBIC).convert('RGBA')
def smooth(t):return t*t*(3-2*t)

A=17.;STANCE=.60;STRIDE=2*A/STANCE;V=np.array([1.,.5])
HEEL_ANGLE=math.radians(-4);TOE_ANGLE=math.radians(5)
def pivot_offset(side,key,angle):
    vector=(np.array(J[side]['ankle'])-boot_contacts[side][key])*S
    return rotation(angle)@vector-vector
def foot(t,side):
    u=(t+(0 if side=='R' else .5))%1
    if u<STANCE:
        along=A-STRIDE*u;lift=0.
        if u<.10:
            contact='heel';angle=HEEL_ANGLE*(1-smooth(u/.10))
        elif u>.46:
            contact='toe';angle=TOE_ANGLE*smooth((u-.46)/(.60-.46))
        else:contact='flat';angle=0.
        offset=pivot_offset(side,'heel' if contact=='heel' else 'toe',angle)
    else:
        s=(u-STANCE)/(1-STANCE);b=smooth(s)
        m=-STRIDE*(1-STANCE)
        along=(2*s**3-3*s*s+1)*(-A)+(s**3-2*s*s+s)*m+(-2*s**3+3*s*s)*A+(s**3-s*s)*m
        lift=8*math.sin(PI*s)**2
        angle=TOE_ANGLE*(1-b)+HEEL_ANGLE*b
        offset=pivot_offset(side,'toe',TOE_ANGLE)*(1-b)+pivot_offset(side,'heel',HEEL_ANGLE)*b
        contact='swing'
    ankle=project(J[side]['ankle'])+along*V+offset-[0,lift]
    points={key:(ankle+rotation(angle)@((np.array(p)-J[side]['ankle'])*S)).tolist() for key,p in boot_contacts[side].items()}
    return {'ankle':ankle,'angle':angle,'u':u,'contact':contact,'points':points}

lengths={side:[np.linalg.norm(np.array(J[side]['knee'])-J[side]['hip'])*S,np.linalg.norm(np.array(J[side]['ankle'])-J[side]['knee'])*S] for side in 'LR'}
def required_drop(t):
    drop=0.
    for side in 'LR':
        h=project(J[side]['hip']);a=foot(t,side)['ankle'];d=a-h
        maximum=sum(lengths[side])-.8
        assert abs(d[0])<maximum
        drop=max(drop,d[1]-math.sqrt(maximum*maximum-d[0]*d[0]))
    return drop
samples=768
required=np.array([required_drop(i/samples) for i in range(samples)])
smoothed=gaussian_filter1d(required,sigma=samples*.022,mode='wrap')
smoothed+=max(0,float(np.max(required-smoothed)))+.12
def hip_drop(t):
    index=(t%1)*samples;i=int(index);b=index-i
    return smoothed[i]*(1-b)+smoothed[(i+1)%samples]*b
def ik(h,a,l1,l2):
    d=a-h;length=np.linalg.norm(d);assert length<=l1+l2+1e-6
    axis=d/length;along=(l1*l1-l2*l2+length*length)/(2*length)
    bend=math.sqrt(max(0,l1*l1-along*along))
    return h+axis*along-bend*np.array([-axis[1],axis[0]])

# Continuous cloth strip. The centerline crosses the same hip/knee/ankle points;
# the width at every corresponding section is constant at the shared scale.
def ribbon(joints,scale=1.):
    h,k,a=[np.array(p,dtype=float) for p in joints]
    u0=k-h;u1=a-k;l0=np.linalg.norm(u0);l1=np.linalg.norm(u1)
    n0=u0/l0;n1=u1/l1;middle=(n0+n1);middle/=np.linalg.norm(middle)
    sections=[]
    for f in np.linspace(-.08,2.06,30):
        if f<0:c=h+u0*f;tangent=n0
        elif f>2:c=a+u1*(f-2);tangent=n1
        else:
            if f<=1:p0,p1,m0,m1,t=h,k,u0,middle*l0,f
            else:p0,p1,m0,m1,t=k,a,middle*l1,u1,f-1
            c=(2*t**3-3*t*t+1)*p0+(t**3-2*t*t+t)*m0+(-2*t**3+3*t*t)*p1+(t**3-t*t)*m1
            tangent=(6*t*t-6*t)*p0+(3*t*t-4*t+1)*m0+(-6*t*t+6*t)*p1+(3*t*t-2*t)*m1
            tangent/=np.linalg.norm(tangent)
        normal=np.array([-tangent[1],tangent[0]])
        width=np.interp(f,[0,.7,1,1.5,2],[88,58,52,57,58])*scale
        sections.append([c-normal*width,c+normal*width])
    return np.array(sections)

cloth_sources={}
source_ribbons={}
for side in 'LR':
    p=np.array(parts['leg_'+side]).astype(float)/255
    b=np.array(parts['boot_'+side])[:,:,3]>0
    p[b]=0
    p[:,:,:3]*=p[:,:,3:4]
    cloth_sources[side]=p
    source_ribbons[side]=ribbon([J[side][name] for name in ['hip','knee','ankle']])

def mapped_cloth(side,destination):
    source=source_ribbons[side]
    sx=np.full((W,W),-1.,dtype=float);sy=sx.copy()
    for row in range(len(source)-1):
        for corners in [(0,1,2),(1,3,2)]:
            sv=np.array([source[row,0],source[row,1],source[row+1,0],source[row+1,1]])[list(corners)]
            dv=np.array([destination[row,0],destination[row,1],destination[row+1,0],destination[row+1,1]])[list(corners)]
            x0,y0=np.maximum(0,np.floor(dv.min(axis=0)).astype(int));x1,y1=np.minimum(W,np.ceil(dv.max(axis=0)).astype(int)+1)
            if x1<=x0 or y1<=y0:continue
            matrix=np.column_stack([dv[1]-dv[0],dv[2]-dv[0]])
            if abs(np.linalg.det(matrix))<1e-8:continue
            yy,xx=np.mgrid[y0:y1,x0:x1];points=np.stack([xx+.5-dv[0,0],yy+.5-dv[0,1]],axis=-1)
            weights=points@np.linalg.inv(matrix).T
            inside=(weights[:,:,0]>=-1e-6)&(weights[:,:,1]>=-1e-6)&(weights.sum(axis=-1)<=1+1e-6)
            original=sv[0]+weights[:,:,0:1]*(sv[1]-sv[0])+weights[:,:,1:2]*(sv[2]-sv[0])
            sx[y0:y1,x0:x1][inside]=original[:,:,0][inside]
            sy[y0:y1,x0:x1][inside]=original[:,:,1][inside]
    sampled=np.stack([map_coordinates(cloth_sources[side][:,:,c],[sy,sx],order=1,mode='constant',cval=0,prefilter=False) for c in range(4)],axis=-1)
    alpha=sampled[:,:,3:4]
    sampled[:,:,:3]=np.divide(sampled[:,:,:3],alpha,out=np.zeros_like(sampled[:,:,:3]),where=alpha>1e-8)
    return Image.fromarray(np.round(np.clip(sampled,0,1)*255).astype('uint8'))

frames=[];motion=[]
for i in range(N):
    t=i/N;drop=hip_drop(t);shift=np.array([0.,drop]);legs={};hands={};record={'index':i,'phase':t,'hip_drop':drop,'feet':{},'bone_errors':[]}
    for side in 'LR':
        j=J[side];f=foot(t,side);h=project(j['hip'])+shift;a=f['ankle'];k=ik(h,a,*lengths[side])
        legs[side]=mapped_cloth(side,ribbon([h,k,a],S))
        legs[side].alpha_composite(rigid(parts['boot_'+side],j['ankle'],a,f['angle']))
        # Continuous but restrained arm swing, opposite the corresponding leg.
        arm_angle=math.radians(6)*(1 if side=='R' else -1)*math.cos(2*PI*t-.2)
        hands[side]=rigid(parts['arm_'+side],j['shoulder'],project(j['shoulder'])+shift,arm_angle)
        record['feet'][side]={'u':f['u'],'contact':f['contact'],'angle':f['angle'],'ankle':a.tolist(),**f['points']}
        record.setdefault('arm_angles',{})[side]=arm_angle
        record['bone_errors']+=list(np.abs([np.linalg.norm(k-h)-lengths[side][0],np.linalg.norm(a-k)-lengths[side][1]]))
    image=Image.new('RGBA',(W,W))
    for side in 'LR':image.alpha_composite(legs[side])
    image.alpha_composite(hands['L']);image.alpha_composite(hands['R'])
    image.alpha_composite(rigid(parts['core'],ORIGIN,PIVOT+shift))
    box=image.getchannel('A').getbbox();assert box and box[0]>0 and box[1]>0 and box[2]<W and box[3]<W
    frames.append(image);record['bbox']=box;motion.append(record)
    if (i+1)%12==0:print('POSES',i+1,'/',N,flush=True)

directory=OUT/'frames';directory.mkdir(exist_ok=True)
for i,im in enumerate(frames):im.save(directory/f'{i:02}.png')
durations=[23]*44+[22]*4
frames[0].save(OUT/'walk.webp',save_all=True,append_images=frames[1:],duration=durations,loop=0,lossless=True)
frames[0].save(OUT/'walk.png',save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=0,blend=0)
atlas=Image.new('RGBA',(512*8,512*6))
for i,im in enumerate(frames):atlas.alpha_composite(im,((i%8)*512,(i//8)*512))
atlas.save(OUT/'atlas.png')
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
board=Image.new('RGB',(1536,1152),'#243b40')
for i in range(12):
    im=frames[i*4].resize((384,384),Image.Resampling.LANCZOS)
    board.paste(im,((i%4)*384,(i//4)*384),im)
    ImageDraw.Draw(board).text(((i%4)*384+12,(i//4)*384+10),f'{i*4:02}',font=font,fill='#e5ddc5')
board.save(OUT/'poses.jpg',quality=95)
shutil.copyfile(ROOT/'artifacts/spine_trial/veilleur_proportions_v1/reference.png',OUT/'reference.png')
drifts=[]
for i in range(N):
    j=(i+1)%N
    for side in 'LR':
        a,b=motion[i]['feet'][side],motion[j]['feet'][side]
        if a['contact']!=b['contact'] or a['contact']=='swing' or b['u']<a['u']:continue
        key='heel' if a['contact']=='heel' else 'toe'
        drifts.append(float(np.linalg.norm(np.array(b[key])-a[key]+STRIDE*V/N)))
assert max(drifts)<1e-6
assert max(e for item in motion for e in item['bone_errors'])<1e-6
counter_swing=[]
for i in [0,N//2]:
    for side in 'LR':
        palm=np.array([437,757] if side=='R' else [837,696])
        delta=(rotation(motion[i]['arm_angles'][side])-np.eye(2))@((palm-J[side]['shoulder'])*S)
        forward_delta=float((delta[0]+2*delta[1])/2)
        leg_sign=1 if ((side=='R')==(i==0)) else -1
        assert forward_delta*leg_sign<0
        counter_swing.append({'frame':i,'side':side,'arm_forward_displacement':forward_delta,'opposite_to_leg':True})
for name,digest in input_hashes.items():assert hashlib.sha256((BASE/(name+'.png')).read_bytes()).hexdigest()==digest
(SRC/'source_lock.json').write_text(json.dumps({'basis':'User accepted the proportions, not the walk. 2026-09-12.','piece_sha256':input_hashes,'landmarks':cfg,'contacts':boot_contacts},indent=2))
(SRC/'motion.json').write_text(json.dumps(motion,indent=2))
(OUT/'manifest.json').write_text(json.dumps({'name':'Veilleur — marche E V2','frame_count':N,'duration_ms':1100,'frame_size':[W,W],
    'pivot':PIVOT.tolist(),'stride':[STRIDE,STRIDE*.5],'reference_height':1168*S,'frames':[f'frames/{i:02}.png' for i in range(N)],
    'status':'walk_refinement_not_artistically_approved'},indent=2))
(OUT/'report.json').write_text(json.dumps({'scope':'Fixed bone lengths, unchanged input pieces, annotated sole-point contacts and output framing. Not artistic approval or exhaustive pixel-foot tracking.',
    'max_bone_length_error':max(e for item in motion for e in item['bone_errors']),
    'max_annotated_contact_drift_output_px':max(drifts),'contact_pairs':len(drifts),
    'source_files_unchanged':True,'duration_ms':sum(durations),'frames':N,'counter_swing':counter_swing,
    'hip_drop_range':[float(min(smoothed)),float(max(smoothed))]},indent=2))
print('WALK_READY',json.dumps({'frames':N,'hip_drop_range':[float(min(smoothed)),float(max(smoothed))],'contact_drift':max(drifts)}),flush=True)
