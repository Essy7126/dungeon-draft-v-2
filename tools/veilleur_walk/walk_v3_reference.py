"""Retarget observed 2D poses of Nicolas Détrain's public walk to our own art.

Reference frames are study inputs only. Exported character pixels come from the
accepted Veilleur. Manual point estimates, perspective shortening and a small
whole-body registration replace the previous generic foot-driven gait.
"""
from pathlib import Path
import json,math,hashlib,shutil
import numpy as np
from scipy.interpolate import CubicSpline
from scipy.optimize import lsq_linear
from PIL import Image,ImageDraw,ImageFont
import source_rig as rig

ROOT=rig.ROOT;SRC=ROOT/'art/source/characters/achilles/veilleur_walk_E_v3'
OUT=ROOT/'artifacts/spine_trial/veilleur_walk_E_v3';OUT.mkdir(exist_ok=True)
REF=ROOT/'artifacts/dev/veilleur-nicolas-study'
data=json.loads((SRC/'reference_landmarks.json').read_text(encoding='utf-8'))
N=32;DURATION=480;S=rig.S;W=rig.W
# The earlier cuff anchor remains the cloth attachment, but the rotating ankle
# belongs inside the boot. This changes the pivot, not the source silhouette.
ankles={'R':np.array([493.,1092.]),'L':np.array([717.,1030.])}
contacts={'R':np.array([546.,1201.]),'L':np.array([829.,1113.])}
source_lengths={side:np.array([np.linalg.norm(np.array(rig.J[side]['knee'])-rig.J[side]['hip']),np.linalg.norm(ankles[side]-rig.J[side]['knee'])])*S for side in 'LR'}
def boot_projection(side,q):
    axis=np.array(rig.J[side]['ankle'])-ankles[side];axis/=np.linalg.norm(axis)
    return np.eye(2)+(q-1)*np.outer(axis,axis)
def draw_boot(side,anchor,angle,q):
    matrix=S*rig.rotation(angle)@boot_projection(side,q);inverse=np.linalg.inv(matrix)
    translation=np.array(anchor)-matrix@ankles[side]
    return rig.parts['boot_'+side].convert('RGBa').transform((W,W),Image.Transform.AFFINE,tuple(np.column_stack([inverse,-inverse@translation]).ravel()),Image.Resampling.BICUBIC).convert('RGBA')
core_pixels=np.array(rig.parts['core']);core_pixels[761:]=0
clean_core=Image.fromarray(core_pixels)
clean_core.save(SRC/'core_clean.png')
arrays={key:np.array(value,dtype=float) for key,value in data.items() if isinstance(value,list) and len(value)==16}
curves={key:CubicSpline(np.arange(17)/16,np.vstack([value,value[0]]),bc_type='periodic') for key,value in arrays.items()}
reference_max={}
arm_center={};foot_center={}
for side in 'LR':
    reference_max[side]=np.array([np.linalg.norm(arrays['knee_'+side]-arrays['hip_'+side],axis=1).max(),np.linalg.norm(arrays['ankle_'+side]-arrays['knee_'+side],axis=1).max()])
    v=arrays['wrist_'+side]-arrays['shoulder_'+side];arm_center[side]=float(np.median(np.arctan2(v[:,1],v[:,0])))
    support=data['support_frames_'+side];v=arrays['toe_'+side][support]-arrays['ankle_'+side][support]
    foot_center[side]=float(np.median(np.arctan2(v[:,1],v[:,0])))
hip_mean=(arrays['hip_R']+arrays['hip_L'])/2
head_delta=arrays['head']-hip_mean
body_angles=np.arctan2(head_delta[:,0],-head_delta[:,1]);body_center=float(np.mean(body_angles))
body_pivot=np.array([637.,749.]);base_pivot=rig.project(body_pivot)

poses=[]
for i in range(N):
    t=i/N;reference={key:curve(t) for key,curve in curves.items()};center=(reference['hip_L']+reference['hip_R'])/2
    head=reference['head']-center
    body_angle=float(np.clip((math.atan2(head[0],-head[1])-body_center)*.6,-.04,.04))
    pose={'phase':t,'body_angle':body_angle,'root_prior':(center-hip_mean.mean(axis=0))*1.25,'legs':{},'arms':{}}
    for side in 'LR':
        h=rig.project(rig.J[side]['hip']);h=base_pivot+rig.rotation(body_angle)@(h-base_pivot)
        v0=reference['knee_'+side]-reference['hip_'+side];v1=reference['ankle_'+side]-reference['knee_'+side]
        lengths=np.array([np.linalg.norm(v0),np.linalg.norm(v1)])
        shortening=np.clip(lengths/reference_max[side],.48,1.)
        target_lengths=source_lengths[side]*shortening
        k=h+v0/lengths[0]*target_lengths[0];a=k+v1/lengths[1]*target_lengths[1]
        fv=reference['toe_'+side]-reference['ankle_'+side]
        angle=float(np.clip(math.atan2(fv[1],fv[0])-foot_center[side],math.radians(-14),math.radians(28)))
        boot_q=max(.65,float(shortening[1]))
        projection=boot_projection(side,boot_q)
        cuff=a+rig.rotation(angle)@projection@((np.array(rig.J[side]['ankle'])-ankles[side])*S)
        sole=a+rig.rotation(angle)@projection@((contacts[side]-ankles[side])*S)
        pose['legs'][side]={'hip':h,'knee':k,'ankle':a,'cuff':cuff,'sole':sole,'boot_angle':angle,'boot_shortening':boot_q,'shortening':shortening}
        av=reference['wrist_'+side]-reference['shoulder_'+side]
        arm_angle=float(np.clip(math.atan2(av[1],av[0])-arm_center[side],-.30,.30))
        pose['arms'][side]=arm_angle
    poses.append(pose)

# Fit a periodic whole-body registration and one isometric travel stride to the
# selected stance intervals. A bounded fit retains the observed body motion.
rows=[];values=[];pairs=[]
def equation(coefficients,value,weight):
    row=np.zeros(2*N+1)
    for key,v in coefficients.items():row[key]=v*weight
    rows.append(row);values.append(value*weight)
for i in range(N):
    j=(i+1)%N
    for side in 'LR':
        support=set(data['support_frames_'+side])
        if (i//2) not in support or (j//2) not in support:continue
        delta=poses[j]['legs'][side]['sole']-poses[i]['legs'][side]['sole']
        equation({j:1,i:-1,2*N:1/N},-delta[0],8.)
        equation({N+j:1,N+i:-1,2*N:.5/N},-delta[1],8.)
        pairs.append((i,j,side))
    for axis in range(2):
        equation({axis*N+i:1},float(poses[i]['root_prior'][axis]),.8)
        equation({axis*N+(i-1)%N:1,axis*N+i:-2,axis*N+(i+1)%N:1},0.,2.)
fit=lsq_linear(np.array(rows),np.array(values),bounds=(np.r_[np.full(2*N,-16.),10.],np.r_[np.full(2*N,16.),240.]),tol=1e-10)
assert fit.success
roots=np.stack([fit.x[:N],fit.x[N:2*N]],axis=1);stride=float(fit.x[-1])
residuals=[]
for i,j,side in pairs:
    residual=poses[j]['legs'][side]['sole']+roots[j]-poses[i]['legs'][side]['sole']-roots[i]+np.array([stride,stride*.5])/N
    residuals.append(float(np.linalg.norm(residual)))

frames=[];motion=[]
for i,pose in enumerate(poses):
    shift=roots[i];layers={};joint_report={}
    for side in 'LR':
        leg=pose['legs'][side]
        image=rig.mapped_cloth(side,rig.ribbon([leg['hip']+shift,leg['knee']+shift,leg['cuff']+shift],S))
        image.alpha_composite(draw_boot(side,leg['ankle']+shift,leg['boot_angle'],leg['boot_shortening']))
        layers[side]=image
        joint_report[side]={key:value.tolist() if isinstance(value,np.ndarray) else value for key,value in leg.items()}
    frame=Image.new('RGBA',(W,W))
    for side in sorted('LR',key=lambda s:pose['legs'][s]['sole'][1]):frame.alpha_composite(layers[side])
    for side in 'LR':
        shoulder=rig.project(rig.J[side]['shoulder']);shoulder=base_pivot+rig.rotation(pose['body_angle'])@(shoulder-base_pivot)
        frame.alpha_composite(rig.rigid(rig.parts['arm_'+side],rig.J[side]['shoulder'],shoulder+shift,pose['arms'][side]))
    frame.alpha_composite(rig.rigid(clean_core,body_pivot,base_pivot+shift,pose['body_angle']))
    box=frame.getchannel('A').getbbox();assert box and box[0]>0 and box[1]>0 and box[2]<W and box[3]<W,box
    frames.append(frame);motion.append({'index':i,'reference_phase':i/2,'root':shift.tolist(),'body_angle':pose['body_angle'],'arms':pose['arms'],'legs':joint_report,'bbox':box})
    if (i+1)%8==0:print('REFERENCE_POSES',i+1,'/',N,flush=True)

directory=OUT/'frames';directory.mkdir(exist_ok=True)
for i,im in enumerate(frames):im.save(directory/f'{i:02}.png')
frames[0].save(OUT/'walk.png',save_all=True,append_images=frames[1:],duration=15,loop=0,disposal=0,blend=0)
frames[0].save(OUT/'walk.webp',save_all=True,append_images=frames[1:],duration=15,loop=0,lossless=True)
atlas=Image.new('RGBA',(W*8,W*4))
for i,im in enumerate(frames):atlas.alpha_composite(im,((i%8)*W,(i//8)*W))
atlas.save(OUT/'atlas.png')
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
board=Image.new('RGB',(1536,768),'#243b40')
for index,i in enumerate(range(0,32,4)):
    im=frames[i].resize((384,384),Image.Resampling.LANCZOS);x=index%4*384;y=index//4*384
    board.paste(im,(x,y),im);ImageDraw.Draw(board).text((x+12,y+10),f'Veilleur {i:02} / référence {i//2:02}',font=font,fill='#e6ddc7')
board.save(OUT/'poses.jpg',quality=95)
overlay=Image.new('RGB',(324*4,347*4),'#a59882')
for i in range(16):
    im=Image.open(REF/f'frame_{i:02}.png').convert('RGB');d=ImageDraw.Draw(im)
    for side,color in [('R','#b24f42'),('L','#386b91')]:
        points=[tuple(arrays[key+'_'+side][i]) for key in ['hip','knee','ankle','toe']]
        d.line(points,fill=color,width=2)
        for x,y in points:d.ellipse((x-2,y-2,x+2,y+2),fill=color)
    d.text((12,12),str(i),font=font,fill='#16312d');overlay.paste(im,((i%4)*324,(i//4)*347))
overlay.save(REF/'annotated_cycle.png')
shutil.copyfile(ROOT/'artifacts/spine_trial/veilleur_proportions_v1/reference.png',OUT/'reference.png')
source_hashes={name:hashlib.sha256((rig.BASE/(name+'.png')).read_bytes()).hexdigest() for name in rig.parts}
(SRC/'motion.json').write_text(json.dumps(motion,indent=2))
(SRC/'source_lock.json').write_text(json.dumps({'source_art':'veilleur_proportions_v1','source_piece_sha256':source_hashes,'internal_ankles':{s:p.tolist() for s,p in ankles.items()},'cloth_attachment':{s:rig.J[s]['ankle'] for s in 'LR'},'maximum_projected_lengths':{s:x.tolist() for s,x in source_lengths.items()},'note':'Pivot correction inside existing boots; no reference character pixels used in Veilleur frames.'},indent=2))
(OUT/'manifest.json').write_text(json.dumps({'name':'Veilleur — marche depuis référence Nicolas Détrain','frame_count':N,'duration_ms':DURATION,'frame_size':[W,W],'pivot':rig.PIVOT.tolist(),'stride':[stride,stride*.5],'reference_height':1168*S,'frames':[f'frames/{i:02}.png' for i in range(N)],'status':'reference_retarget_art_review','reference_original_cycle_ms':480,'reference_frame_count':16},indent=2))
(OUT/'report.json').write_text(json.dumps({'scope':'Observed-pose retarget, bounded perspective shortening, estimated contact registration. Not an exact copy of the unavailable studio rig.',
    'reference_points':'Manually estimated, not automatically tracked or supplied by the animator.',
    'reference_cycle_ms':480,'rendered_frames':N,'stride_output_px':stride,'root_shift_range':np.ptp(roots,axis=0).tolist(),
    'max_contact_residual_output_px_per_sample':max(residuals),'mean_contact_residual_output_px_per_sample':float(np.mean(residuals)),
    'max_contact_residual_at_112px':max(residuals)*112/(1168*S),'contact_pairs':len(pairs),'perspective_shortening_bounds':[.48,1.],
    'limitations':['La perspective peut raccourcir une jambe ; aucune longueur maximale ne dépasse le dessin source.', 'Les contacts sont des repères estimés, pas un suivi exhaustif des pieds.', 'Le rig de Nicolas n’est pas disponible : les poses ont été relevées visuellement.']},ensure_ascii=False,indent=2),encoding='utf-8')
print('REFERENCE_WALK_READY',json.dumps({'stride':stride,'max_contact_residual':max(residuals),'root_range':np.ptp(roots,axis=0).tolist()}),flush=True)
