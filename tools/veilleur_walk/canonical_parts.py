"""Proportion correction: source pixels, measured lengths, rigid transforms only.

This is a bounded construction trial. It replaces neither the canonical artwork
nor the rejected previous walk. No part is stretched to fit a generic skeleton.
"""
from pathlib import Path
import math,json,hashlib
import numpy as np
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/source/characters/achilles/veilleur_proportions_v1'
OUT=ROOT/'artifacts/spine_trial/veilleur_proportions_v1'
SRC.mkdir(exist_ok=True);OUT.mkdir(exist_ok=True)
CANON=ROOT/'art/source/characters/achilles/serment_cendre_concept_v1/candidate_c.png'
original=Image.open(CANON).convert('RGBA');raw=np.asarray(original)
S=.32;W=512;OFFSET=np.array([256,442])-np.array([637,1211])*S
def projected(p):return np.array(p)*S+OFFSET
def mask_polygon(points):
    mask=Image.new('L',original.size);ImageDraw.Draw(mask).polygon(points,fill=255)
    return np.asarray(mask)>0

shapes={
 'leg_R':[(516,730),(564,745),(637,752),(622,792),(585,861),(564,937),(550,960),(574,1000),(597,1090),(599,1238),(398,1240),(408,1030),(435,950),(460,877),(490,816),(511,784)],
 'leg_L':[(646,752),(692,743),(740,727),(773,713),(778,806),(760,858),(753,908),(803,930),(855,1010),(873,1112),(850,1134),(641,1132),(629,1000),(650,929),(668,881),(659,846)],
 'arm_R':[(450,397),(492,412),(522,458),(522,514),(493,578),(472,654),(467,688),(499,729),(505,779),(480,804),(460,831),(408,846),(365,799),(368,718),(384,653),(387,573),(416,470)],
 'arm_L':[(761,406),(796,466),(822,542),(859,595),(884,663),(890,725),(874,756),(828,776),(786,736),(776,684),(793,637),(772,608),(748,542),(741,473)]
}
masks={k:mask_polygon(p) for k,p in shapes.items()}
yy,xx=np.indices(raw.shape[:2])
hem=np.interp(xx,[505,516,556,607,644,700,741,773,778],[716,729,743,752,752,743,727,712,714])
lower=((yy>=hem)&(xx>=505)&(xx<=778))|(yy>=850)
split=np.interp(yy,[750,850,1000,1254],[644,633,613,613])
masks['leg_R']=lower&(xx<split)
masks['leg_L']=lower&(xx>=split)
occupied=np.zeros(raw.shape[:2],dtype=bool)
parts={}
for key in ['arm_L','arm_R','leg_L','leg_R']:
    select=masks[key]&~occupied;occupied|=select
    pixels=raw.copy();pixels[~select]=0;parts[key]=Image.fromarray(pixels)
pixels=raw.copy();pixels[occupied]=0;parts['core']=Image.fromarray(pixels)
assembled=Image.new('RGBA',original.size)
for part in parts.values():assembled.alpha_composite(part)
diff=int(np.count_nonzero(np.any(np.asarray(assembled)!=raw,axis=2)))
assert diff==0,diff

# These are annotations on the chosen drawing, not universal human dimensions.
joints={
 'R':{'hip':[580,749],'knee':[546,868],'ankle':[500,992],'shoulder':[465,422]},
 'L':{'hip':[705,752],'knee':[711,844],'ankle':[715,936],'shoulder':[768,432]}}
for side in 'LR':
    leg=np.asarray(parts['leg_'+side]);yy,xx=np.indices(leg.shape[:2])
    knee_y=joints[side]['knee'][1]
    # Keep the entire ivory cuff with its boot, including both raised side rims.
    if side=='R':
        boot_edge=np.interp(xx,[420,443,460,471,486,520,540,553,570,600],[967,961,960,982,996,998,990,975,996,1100])
    else:
        boot_edge=np.interp(xx,[630,655,675,680,703,737,751,769,787,803,873],[925,923,912,935,942,941,918,918,941,993,1010])
    # Partition by local knee and cuff levels; preserve every pixel of the source.
    for name,region in [('thigh',yy<knee_y),('shin',(yy>=knee_y)&(yy<boot_edge)),('boot',yy>=boot_edge)]:
        p=leg.copy();p[~region]=0;parts[name+'_'+side]=Image.fromarray(p)
for key,part in parts.items():part.save(SRC/(key+'.png'))
original.save(SRC/'reference.png')

def rigid(image,anchor,target,angle=0):
    c,s=math.cos(angle),math.sin(angle)
    matrix=S*np.array([[c,-s],[s,c]])
    inverse=np.linalg.inv(matrix);translation=np.array(target)-matrix@np.array(anchor)
    coeff=np.column_stack([inverse,-inverse@translation]).ravel()
    return image.convert('RGBa').transform((W,W),Image.Transform.AFFINE,tuple(coeff),Image.Resampling.BICUBIC).convert('RGBA')
def segment(name,source0,source1,target0,target1):
    v=np.array(source1)-source0;w=np.array(target1)-target0
    angle=math.atan2(w[1],w[0])-math.atan2(v[1],v[0])
    error=abs(np.linalg.norm(v)*S-np.linalg.norm(w))
    assert error<1e-6,error
    return rigid(parts[name],source0,target0,angle)
def ik(hip,ankle,l1,l2,reference_sign):
    delta=ankle-hip;length=np.linalg.norm(delta)
    assert abs(l1-l2)<length<l1+l2+1e-6,(length,l1+l2)
    axis=delta/length;along=(l1*l1-l2*l2+length*length)/(2*length)
    height=math.sqrt(max(0,l1*l1-along*along))
    return hip+along*axis+reference_sign*height*np.array([-axis[1],axis[0]])

N=24;A=17.;STANCE=.60;STRIDE=2*A/STANCE;DURATION=1.1
def foot(phase,side):
    u=(phase+(0 if side=='R' else .5))%1
    if u<STANCE:
        along=A-STRIDE*u;lift=0.;angle=0.
    else:
        s=(u-STANCE)/(1-STANCE)
        # Position and horizontal velocity agree at both contact boundaries.
        p0,p1=-A,A;m=-STRIDE*(1-STANCE)
        along=(2*s**3-3*s*s+1)*p0+(s**3-2*s*s+s)*m+(-2*s**3+3*s*s)*p1+(s**3-s*s)*m
        lift=10*math.sin(math.pi*s)**1.2;angle=math.radians(-6)*math.sin(math.pi*s)
    return projected(joints[side]['ankle'])+np.array([along,.5*along-lift]),angle,u

measurements={}
for side,j in joints.items():
    measurements[side]={
      'thigh_source_px':float(np.linalg.norm(np.array(j['knee'])-j['hip'])),
      'shin_source_px':float(np.linalg.norm(np.array(j['ankle'])-j['knee']))}
frames=[];reports=[];font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
for i in range(N):
    t=i/N;feet={side:foot(t,side) for side in 'LR'}
    # Minimal common vertical accommodation; no bone can grow to reach a pose.
    drop=0.
    for side in 'LR':
        hip=projected(joints[side]['hip']);ankle=feet[side][0]
        total=S*sum(measurements[side].values())-.15
        dx=ankle[0]-hip[0]
        allowed=math.sqrt(max(0,total*total-dx*dx))
        drop=max(drop,ankle[1]-hip[1]-allowed)
    shift=np.array([0,drop]);layers={};knees={};errs=[]
    for side in 'LR':
        j=joints[side];hip=projected(j['hip'])+shift;ankle,angle,u=feet[side]
        l1=measurements[side]['thigh_source_px']*S;l2=measurements[side]['shin_source_px']*S
        knee=ik(hip,ankle,l1,l2,-1)
        knees[side]=(hip,knee,ankle)
        layers['thigh_'+side]=segment('thigh_'+side,j['hip'],j['knee'],hip,knee)
        layers['shin_'+side]=segment('shin_'+side,j['knee'],j['ankle'],knee,ankle)
        layers['boot_'+side]=rigid(parts['boot_'+side],j['ankle'],ankle,angle)
        arm_angle=math.radians(5)*(1 if side=='L' else -1)*math.cos(math.tau*t)
        layers['arm_'+side]=rigid(parts['arm_'+side],j['shoulder'],projected(j['shoulder'])+shift,arm_angle)
        errs.extend([abs(np.linalg.norm(knee-hip)-l1),abs(np.linalg.norm(ankle-knee)-l2)])
    frame=Image.new('RGBA',(W,W))
    for side in 'LR':
        # Tiny concealed fabric caps cover cut edges; no boot shape is synthesized.
        cap=Image.new('RGBA',(W,W));d=ImageDraw.Draw(cap)
        hip,knee,ankle=knees[side]
        for p,r in [(hip,15),(knee,9)]:d.ellipse((p[0]-r,p[1]-r,p[0]+r,p[1]+r),fill='#32312d')
        frame.alpha_composite(cap)
        for key in ['thigh_'+side,'shin_'+side,'boot_'+side]:frame.alpha_composite(layers[key])
    frame.alpha_composite(layers['arm_L']);frame.alpha_composite(layers['arm_R'])
    frame.alpha_composite(rigid(parts['core'],[637,1211],np.array([256,442])+shift))
    assert frame.getchannel('A').getbbox()
    frames.append(frame)
    reports.append({'i':i,'hip_drop_output_px':drop,'max_length_error':max(errs),
                    'feet':{side:{'ankle':feet[side][0].tolist(),'phase':feet[side][2],'angle':feet[side][1]} for side in 'LR'}})

reference=rigid(original,[637,1211],[256,442])
reference.save(OUT/'reference.png')
board=Image.new('RGB',(512*3,570),'#243b40');d=ImageDraw.Draw(board)
for column,(label,im) in enumerate([('Modèle retenu · pixels sources',reference),('Pose A · longueurs conservées',frames[0]),('Pose B · longueurs conservées',frames[12])]):
    board.paste(im,(column*512,45),im);d.text((column*512+18,15),label,font=font,fill='#e0d9c8')
board.save(OUT/'proportions.jpg',quality=95)
directory=OUT/'frames';directory.mkdir(exist_ok=True)
for i,im in enumerate(frames):im.save(directory/f'{i:02}.png')
frames[0].save(OUT/'construction.webp',save_all=True,append_images=frames[1:],duration=[46,46,45]*8,loop=0,lossless=True)
atlas=Image.new('RGBA',(512*6,512*4))
for i,im in enumerate(frames):atlas.alpha_composite(im,((i%6)*512,(i//6)*512))
atlas.save(OUT/'construction_atlas.png')
(SRC/'landmarks.json').write_text(json.dumps({'source_sha256':hashlib.sha256(CANON.read_bytes()).hexdigest(),'joints':joints,'measurements':measurements,'scale':S},indent=2))
(OUT/'report.json').write_text(json.dumps({'scope':'Neutral source reconstruction and rigid-part lengths only. Joint drawing and gait are provisional.',
    'neutral_reconstruction_changed_pixels':diff,'measurements':measurements,'frames':reports},indent=2))
(OUT/'manifest.json').write_text(json.dumps({'name':'Veilleur — correction des proportions','frame_count':N,'duration_ms':1100,'frame_size':[512,512],
    'pivot':[256,442],'stride':[STRIDE,STRIDE*.5],'reference_height':1168*S,'frames':[f'frames/{i:02}.png' for i in range(N)],
    'status':'proportion_construction_review','limits':['Raccords des articulations provisoires.','La marche précédente a été rejetée par l’utilisateur.','Pas une marche finalisée.']},indent=2))
print(json.dumps({'neutral_changed_pixels':diff,'measurements':measurements,'max_hip_drop':max(x['hip_drop_output_px'] for x in reports)}))
