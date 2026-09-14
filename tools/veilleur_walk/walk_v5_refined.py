"""Refine V4 with continuous trouser skin, repaired hidden areas and elbows.

Own source art, a sagittal two-link construction projected on the map diagonal,
explicit heel/flat/toe support and periodic body motion. This is an authored
adaptation of the studied gait, not a reconstruction of Nicolas's private rig.
"""
from pathlib import Path
import json, math, hashlib, shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import source_rig as rig
import articulation_v5 as art

ROOT = rig.ROOT
SRC = ROOT / 'art/source/characters/achilles/veilleur_walk_E_v5'
OUT = ROOT / 'artifacts/spine_trial/veilleur_walk_E_v5'
SRC.mkdir(exist_ok=True)
OUT.mkdir(exist_ok=True)
N = 48
DURATION = 800
STANCE = .60
AMPLITUDE = 21.
PROJECTION = .85
STRIDE = 2 * AMPLITUDE / STANCE * PROJECTION
W, S = rig.W, rig.S
ANKLES = {'R': np.array([493., 1092.]), 'L': np.array([717., 1030.])}
HEEL = {'R': np.array([465., 1147.]), 'L': np.array([689., 1058.])}
TOE = {'R': np.array([546., 1201.]), 'L': np.array([829., 1113.])}
BODY_PIVOT = np.array([637., 749.])
BASE_PIVOT = rig.project(BODY_PIVOT)
# A foreshortened far leg in a single drawing is not a second, shorter anatomy.
# Both legs share the near leg's segment ratio. The far projection is 95%.
U = np.linalg.norm(np.array(rig.J['R']['knee']) - rig.J['R']['hip']) * S
V = np.linalg.norm(ANKLES['R'] - rig.J['R']['knee']) * S
HIP = {'R': rig.project(rig.J['R']['hip']),
       'L': rig.project(rig.J['L']['hip']) + np.array([0., -12.])}
DEPTH = {'R': 1., 'L': .95}
clean_core = Image.open(ROOT / 'art/source/characters/achilles/veilleur_walk_E_v3/core_clean.png').convert('RGBA')

def ease(x):
    x = np.clip(x, 0, 1)
    return x*x*x*(10+x*(-15+6*x))

def trajectory(q):
    if q < STANCE:
        f = AMPLITUDE - 2*AMPLITUDE*q/STANCE
        if q < .10:
            angle = math.radians(-7)*(1-ease(q/.10)); contact = 'heel'
        elif q > .44:
            angle = math.radians(12)*ease((q-.44)/(STANCE-.44)); contact = 'toe'
        else:
            angle = 0.; contact = 'flat'
        return f, 0., angle, contact
    s = (q-STANCE)/(1-STANCE)
    slope = -2*AMPLITUDE/STANCE*(1-STANCE)
    f = -AMPLITUDE + slope*s + (2*AMPLITUDE-slope)*ease(s)
    lift_phase=s+.16*math.sin(math.pi*s)
    lift = 8.*math.sin(math.pi*lift_phase)**3
    # Continuous toe-off -> recovery -> heel-first landing.
    angle = math.radians(12*(1-ease(s)) - 7*ease(s) + 5*math.sin(math.pi*s)**3)
    return f, lift, angle, 'swing'

def project_vector(f, down):
    return np.array([PROJECTION*f, .5*PROJECTION*f + down])

def solve_knee(hip, ankle, side):
    dxy = ankle-hip
    target = np.array([dxy[0]/PROJECTION, dxy[1]-.5*dxy[0]])
    length = np.linalg.norm(target)
    u, v = U*DEPTH[side], V*DEPTH[side]
    assert abs(v-u)+.1 < length < u+v-.1, (side, target, length, u+v)
    direction = target/length
    along = (u*u-v*v+length*length)/(2*length)
    height = math.sqrt(max(0, u*u-along*along))
    knee_local = direction*along + np.array([direction[1], -direction[0]])*height
    return hip+project_vector(*knee_local), length

def boot(side, ankle, angle):
    return rig.rigid(rig.parts['boot_'+side], ANKLES[side], ankle, angle)

frames, motion = [], []
for i in range(N):
    t=i/N
    bob=-1.6*math.cos(4*math.pi*t)
    sway=.8*math.sin(2*math.pi*t)
    shift=np.array([sway,-bob])
    body_angle=math.radians(.8)*math.sin(2*math.pi*t)
    joints, layers = {}, {}
    for side in 'LR':
        q=(t+(.5 if side=='L' else 0))%1
        forward,lift,angle,contact=trajectory(q)
        # Gait distance is identical for both feet, regardless of their drawn size.
        hip=HIP[side]+shift
        depth=DEPTH[side]
        flat_ankle=HIP[side]+project_vector(forward, 109.*depth-lift)
        rotation=rig.rotation(angle)
        heel=(HEEL[side]-ANKLES[side])*S
        toe=(TOE[side]-ANKLES[side])*S
        if contact=='heel': roll=(np.eye(2)-rotation)@heel
        elif contact=='toe': roll=(np.eye(2)-rotation)@toe
        elif contact=='swing':
            s=(q-STANCE)/(1-STANCE)
            roll=(1-ease(s/.3))*((np.eye(2)-rotation)@toe)+ease((s-.7)/.3)*((np.eye(2)-rotation)@heel)
        else: roll=np.zeros(2)
        ankle=flat_ankle+roll
        knee,reach=solve_knee(hip,ankle,side)
        cuff=ankle+rotation@((np.array(rig.J[side]['ankle'])-ANKLES[side])*S)
        layer=art.leg(side,hip,knee,cuff)
        layer.alpha_composite(boot(side,ankle,angle))
        layers[side]=layer
        joints[side]={'phase':q,'hip':hip.tolist(),'knee':knee.tolist(),'ankle':ankle.tolist(),
                      'cuff':cuff.tolist(),'heel':(ankle+rotation@heel).tolist(),
                      'toe':(ankle+rotation@toe).tolist(),'boot_angle':angle,'contact':contact,
                      'reach':reach,'swing_lift':lift,'cloth_deformation':dict(art.last_leg_report[side])}
    frame=Image.new('RGBA',(W,W))
    # Far/near limb order follows the torso depth, not changing sole height.
    for side in 'LR': frame.alpha_composite(layers[side])
    arms={}; arm_layers={}
    for side in 'LR':
        q=(t+(.5 if side=='L' else 0))%1
        arm_angle=math.radians(10)*math.cos(2*math.pi*(q-.025))
        bend=-math.radians(2+6*(1-math.cos(2*math.pi*q))*.5)
        shoulder=rig.project(rig.J[side]['shoulder'])
        shoulder=BASE_PIVOT+rig.rotation(body_angle)@(shoulder-BASE_PIVOT)+shift
        upper,lower,arm_data=art.arm(side,shoulder,arm_angle,bend)
        frame.alpha_composite(upper)
        if side=='L':frame.alpha_composite(lower)
        arm_layers[side]=lower;arms[side]=arm_data
    frame.alpha_composite(rig.rigid(clean_core,BODY_PIVOT,BASE_PIVOT+shift,body_angle))
    frame.alpha_composite(arm_layers['R'])
    bbox=frame.getchannel('A').getbbox()
    assert bbox and min(bbox[:2])>0 and max(bbox[2:])<W,bbox
    frames.append(frame)
    motion.append({'index':i,'phase':t,'root':shift.tolist(),'body_angle':body_angle,
                   'arms':arms,'legs':joints,'bbox':bbox,'leg_order':['L','R']})
    if (i+1)%12==0: print('CORRECTED_WALK',i+1,'/',N,flush=True)

directory=OUT/'frames';directory.mkdir(exist_ok=True)
for i,frame in enumerate(frames): frame.save(directory/f'{i:02}.png')
# Integer milliseconds preserve the 800 ms duration with 17/16 ms holds.
durations=[round((i+1)*DURATION/N)-round(i*DURATION/N) for i in range(N)]
frames[0].save(OUT/'walk.png',save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=0,blend=0)
frames[0].save(OUT/'walk.webp',save_all=True,append_images=frames[1:],duration=durations,loop=0,lossless=True)
atlas=Image.new('RGBA',(W*8,W*6))
for i,frame in enumerate(frames): atlas.alpha_composite(frame,((i%8)*W,(i//8)*W))
atlas.save(OUT/'atlas.png')
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
board=Image.new('RGB',(1536,768),'#243b40')
for j,i in enumerate(range(0,N,6)):
    im=frames[i].resize((384,384),Image.Resampling.LANCZOS); x=j%4*384; y=j//4*384
    board.paste(im,(x,y),im);ImageDraw.Draw(board).text((x+12,y+10),f'Pose {i:02}',font=font,fill='#e6ddc7')
board.save(OUT/'poses.jpg',quality=95)
shutil.copyfile(ROOT/'artifacts/spine_trial/veilleur_proportions_v1/reference.png',OUT/'reference.png')
(SRC/'motion.json').write_text(json.dumps(motion,indent=2))
hashes={name:hashlib.sha256((rig.BASE/(name+'.png')).read_bytes()).hexdigest() for name in rig.parts}
(SRC/'source_lock.json').write_text(json.dumps({'source_piece_sha256':hashes,'boots':'Original rigid PNG, rotation and translation only. No animated scaling.',
    'anatomy_note':'Shared near-leg sagittal lengths with 0.95 far depth projection; source far-pose length was not an anatomical limit.',
    'sagittal_lengths':[float(U),float(V)],'far_projection':DEPTH['L'],
    'completed_leg_sha256':{side:hashlib.sha256((SRC/f'leg_{side}_completed.png').read_bytes()).hexdigest() for side in 'LR'},
    'imagegen_calls':1,'imagegen_usage':'Missing trouser regions only. Generated boots not used. See repair_report.json and legs_repair_prompt.txt.'},indent=2))
(OUT/'manifest.json').write_text(json.dumps({'name':'Veilleur — marche avec articulations affinées','frame_count':N,'duration_ms':DURATION,
    'frame_size':[W,W],'pivot':rig.PIVOT.tolist(),'stride':[STRIDE,STRIDE*.5],
    'reference_height':1168*S,'frames':[f'frames/{i:02}.png' for i in range(N)],'status':'articulated_walk_art_review'},ensure_ascii=False,indent=2),encoding='utf-8')
print('READY',json.dumps({'duration_ms':DURATION,'stride':STRIDE,'max_art_inversions':max(p['legs'][s]['cloth_deformation']['inverted_triangles_over_art'] for p in motion for s in 'LR')}))


