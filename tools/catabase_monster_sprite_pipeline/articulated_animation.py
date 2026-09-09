"""Local painted skeleton, planted-foot IK and character-specific animation."""
from __future__ import annotations
import math
import numpy as np
from PIL import Image, ImageDraw, ImageChops
from scipy.ndimage import map_coordinates

CANVAS=(512,384)
ANCHOR=np.array([256.,320.])


def matrix(pivot, angle=0., shift=(0.,0.), scale=(1.,1.)):
    angle=math.radians(angle);c,s=math.cos(angle),math.sin(angle)
    m=np.array([[c*scale[0],-s*scale[1],0.],
                [s*scale[0],c*scale[1],0.],[0.,0.,1.]])
    pivot=np.asarray(pivot)
    m[:2,2]=pivot+np.asarray(shift)-m[:2,:2]@pivot
    return m


def angle_of(vector):
    return math.degrees(math.atan2(vector[1],vector[0]))


def shortest(angle):
    return (angle+180.)%360.-180.


def two_joint_ik(hip,knee,foot,target,parent):
    """Solve articulated links in screen space, retaining the authored bend."""
    h=(parent@np.r_[hip,1.])[:2]
    k=(parent@np.r_[knee,1.])[:2]
    f=(parent@np.r_[foot,1.])[:2]
    v1=k-h;v2=f-k
    a=float(np.linalg.norm(v1));b=float(np.linalg.norm(v2))
    delta=np.asarray(target)-h;r=float(np.linalg.norm(delta))
    if min(a,b,r)<.001:return 0.,0.
    r=max(abs(a-b)+.05,min(a+b-.05,r))
    bend=1. if v1[0]*v2[1]-v1[1]*v2[0]>=0 else -1.
    gamma=math.acos(np.clip((a*a+r*r-b*b)/(2*a*r),-1.,1.))
    first=math.atan2(delta[1],delta[0])-bend*gamma
    new_k=h+a*np.array([math.cos(first),math.sin(first)])
    direction=delta/max(float(np.linalg.norm(delta)),.001)
    reachable=h+direction*r
    second=angle_of(reachable-new_k)
    first_delta=shortest(math.degrees(first)-angle_of(v1))
    second_delta=shortest(second-angle_of(v2)-first_delta)
    return first_delta,second_delta


def _split_feet(parts,slug):
    """Give the ankle its own contact angle instead of rotating planted soles."""
    result=[]
    for part in parts:
        part=dict(part)
        part.setdefault('source_image',part['image'])
        part.setdefault('underpaint',Image.new('RGBA',CANVAS))
        if part['name'].startswith('shin') and 'end' in part:
            ex,ey=part['end'];height=8 if slug=='molosse_styx' else 11
            width=22 if slug=='molosse_styx' else 40
            boundary=ey-height
            raw=np.asarray(part['source_image'])
            band=raw[max(0,round(boundary)-2):round(boundary)+3,:,3]
            _,columns=np.where(band>160)
            ankle_x=float(np.median(columns)) if len(columns) else ex
            mask=Image.new('L',CANVAS)
            ImageDraw.Draw(mask).rectangle((ex-width,boundary-3,ex+width,ey+10),fill=255)
            upper_mask=Image.new('L',CANVAS,255)
            ImageDraw.Draw(upper_mask).rectangle((ex-width,boundary+3,ex+width,ey+10),fill=0)
            foot={'name':part['name'].replace('shin','foot',1),
                  'pivot':[ankle_x,boundary],'parent':part['name'],'z':part['z']+.5}
            for field in ('image','source_image','underpaint'):
                foot[field]=part[field].copy()
                foot[field].putalpha(ImageChops.multiply(foot[field].getchannel('A'),mask))
                part[field]=part[field].copy()
                part[field].putalpha(ImageChops.multiply(part[field].getchannel('A'),upper_mask))
            part['end']=[ankle_x,boundary]
            result.append(foot)
        result.append(part)
    return result


class PaintedSkeleton:
    def __init__(self,base,parts,slug,direction):
        self.base=base.convert('RGBA');self.slug=slug;self.direction=direction
        self.parts=_split_feet(parts,slug)
        self.by_name={p['name']:p for p in self.parts}
        self.yy,self.xx=np.mgrid[0:384,0:512].astype(float)
        self.layers={}
        for part in self.parts:
            for field in ('underpaint','source_image'):
                img=part[field];box=img.getbbox()
                self.layers[(part['name'],field)]=(box,img.crop(box).convert('RGBa')) if box else None

    def matrices(self,pose):
        root=pose.get('root',{})
        result={'root':matrix(ANCHOR,root.get('angle',0),root.get('shift',(0,0)),root.get('scale',(1,1)))}
        angles=dict(pose.get('angles',{}));shifts=pose.get('shifts',{})
        scales=pose.get('scales',{})
        def visit(name):
            if name in result:return result[name]
            part=self.by_name[name]
            result[name]=visit(part['parent'])@matrix(part['pivot'],angles.get(name,0),shifts.get(name,(0,0)),scales.get(name,(1,1)))
            return result[name]
        for upper,target_info in pose.get('ik',{}).items():
            if upper not in self.by_name:continue
            lower=upper.replace('upper_arm','arm') if upper.startswith('upper_arm') else upper.replace('leg','shin',1)
            if lower not in self.by_name or 'end' not in self.by_name[lower]:continue
            first=self.by_name[upper];second=self.by_name[lower]
            parent=visit(first['parent'])
            endpoint=np.array(second['end'])+np.array(target_info)
            angles[upper],angles[lower]=two_joint_ik(first['pivot'],second['pivot'],second['end'],endpoint,parent)
        for name in self.by_name:visit(name)
        for name,desired in pose.get('world_angles',{}).items():
            if name not in self.by_name:continue
            part=self.by_name[name];parent=result[part['parent']]
            parent_angle=angle_of(parent[:2,0])
            result[name]=parent@matrix(part['pivot'],desired-parent_angle,shifts.get(name,(0,0)))
        return result

    def render(self,pose):
        transforms=self.matrices(pose)
        if pose.get('ground_death'):
            support=[]
            for part in self.parts:
                yy,xx=np.where(np.asarray(part['image'])[:,:,3]>32)
                if len(xx):support.append((np.c_[xx,yy,np.ones(len(xx))]@transforms[part['name']].T)[:,:2])
            cloud=np.concatenate(support)
            low=cloud.min(axis=0);high=cloud.max(axis=0)
            if high[0]-low[0]>495 or high[1]-low[1]>310:
                raise ValueError(f'Pose exceeds canvas: {self.slug}/{self.direction}: {high-low}')
            offset=[max(0,8-low[0])-max(0,high[0]-504),319-high[1]]
            correction=np.eye(3);correction[:2,2]=offset
            transforms={name:correction@m for name,m in transforms.items()}
            pose['ground_correction']=list(map(float,offset))
        output=Image.new('RGBA',CANVAS)
        layers=[(part,field) for field in ('underpaint','source_image') for part in sorted(self.parts,key=lambda p:p['z'])]
        for part,field in layers:
            name=part['name']
            cached=self.layers[(name,field)]
            if cached is None:continue
            box,premult=cached
            if name=='tail' and 'tail_wave' in pose:
                phase,amplitude=pose['tail_wave']
                # The coil has its own flexible skin; torso and staff stay rigid.
                raw=np.asarray(part[field].convert('RGBa'))
                wave=amplitude*np.sin(self.yy*.035-phase)*np.clip((self.yy-200)/85,0,1)
                out=np.stack([map_coordinates(raw[:,:,c],[self.yy,self.xx-wave],order=1,mode='constant',cval=0) for c in range(4)],axis=-1).astype('uint8')
                image=Image.fromarray(out,'RGBa').convert('RGBA')
                box=image.getbbox()
                if box is None:continue
                premult=image.crop(box).convert('RGBa')
            x0,y0,x1,y1=box
            corners=np.array([[x0,y0,1],[x1,y0,1],[x0,y1,1],[x1,y1,1]])@transforms[name].T
            if (corners[:,:2].min(axis=0)<2).any() or (corners[:,:2].max(axis=0)>np.array(CANVAS)-2).any():
                yy,xx=np.where(np.asarray(premult)[:,:,3]>32)
                if len(xx):
                    points=np.c_[xx+x0,yy+y0,np.ones(len(xx))]@transforms[name].T
                    if (points[:,:2].min(axis=0)<2).any() or (points[:,:2].max(axis=0)>np.array(CANVAS)-3).any():
                        raise ValueError(f'Clipped articulated part: {self.slug}/{self.direction}/{name}: {pose["action"]}')
            lo=np.maximum([0,0],np.floor(corners[:,:2].min(axis=0)-2)).astype(int)
            hi=np.minimum(CANVAS,np.ceil(corners[:,:2].max(axis=0)+2)).astype(int)
            if np.any(hi<=lo):continue
            inverse=np.linalg.inv(transforms[name])
            inverse[:2,2]+=inverse[:2,:2]@lo-np.array([x0,y0])
            transformed=premult.transform(tuple(hi-lo),Image.Transform.AFFINE,tuple(inverse[:2].ravel()),Image.Resampling.BICUBIC).convert('RGBA')
            output.alpha_composite(transformed,tuple(lo))
        return output


def pose_for(slug,direction,index,parts):
    """Eight idle, twelve locomotion, two eight-frame actions, hit and death."""
    sign=-1 if direction in 'SW' else 1
    depth=-1 if direction in 'NW' else 1
    p={'angles':{},'shifts':{},'scales':{},'ik':{},'world_angles':{}}
    names={part['name'] for part in parts}
    def a(name,value):p['angles'][name]=value*sign
    def sh(name,x,y):p['shifts'][name]=[x*sign,y]
    def plant():
        for name in names:
            if name.startswith('leg'):p['ik'][name]=[0,0]
        for name in names:
            if name.startswith('shin'):p['world_angles'][name.replace('shin','foot',1)]=0
    if index<8:
        t=index/8*math.tau;breathe=math.sin(t)
        # A different body rhythm gives each creature a recognizable presence.
        if slug=='sentinelle_airain':
            sh('torso',0,2.2*breathe);a('head',-2*breathe)
            a('upper_arm_left',1.6*breathe);a('arm_left',-1.2*breathe)
            a('upper_arm_right',-1.8*breathe);a('arm_right',1.8*breathe)
            p['scales']['torso']=[1+.012*breathe,1+.008*breathe];plant()
        elif slug=='rejeton_braise':
            sh('torso',1.7*math.sin(t),-3.5*breathe)
            a('head',4*math.sin(t-.35));a('upper_arm_right',-5*breathe)
            a('arm_right',7*breathe);a('upper_arm_left',4*math.sin(t+.6))
            a('arm_left',-8*math.sin(t+.6));a('cloth',5*math.sin(t-.7))
            p['scales']['torso']=[1+.018*breathe,1+.016*breathe];plant()
        elif slug=='molosse_styx':
            sh('torso',0,2.5*breathe);a('head',-3*math.sin(t-.3))
            a('jaw',9*max(0,breathe));a('tail',14*math.sin(t-.6));plant()
        else:
            sh('torso',2*math.sin(t),-3*breathe)
            a('torso',2.4*math.sin(t));a('head',-4*math.sin(t-.3))
            a('upper_arm_right',4*math.sin(t+.4));a('arm_right',-5*math.sin(t+.6))
            a('upper_arm_left',-2*math.sin(t));a('arm_left',2*math.sin(t))
            p['tail_wave']=[t,3.5]
    elif index<20:
        t=(index-8)/12*math.tau
        if slug=='lamie_lethe':
            sh('torso',7*math.sin(t),-4*math.sin(2*t))
            a('torso',5*math.sin(t));a('head',-6*math.sin(t-.35))
            a('upper_arm_right',9*math.sin(t+.7));a('arm_right',-12*math.sin(t+.4))
            a('upper_arm_left',-4*math.sin(t+.2));a('arm_left',5*math.sin(t+.5))
            p['tail_wave']=[t,12]
        else:
            quadruped=slug=='molosse_styx'
            sh('torso',0,(7 if quadruped else 7)+3*math.cos(2*t))
            a('torso',(2 if quadruped else 3)*math.sin(t))
            a('head',(-4 if quadruped else -3)*math.sin(t+.25))
            a('tail',17*math.sin(t-.55));a('cloth',-9*math.sin(t-.3))
            amplitude=18 if quadruped else (15 if slug=='sentinelle_airain' else 22)
            lift=15 if quadruped else (13 if slug=='sentinelle_airain' else 20)
            phases={'leg_left':0.,'leg_right':.5,'leg_hind_far':.5,'leg_fore_far':0.}
            for name,phase in phases.items():
                if name not in names:continue
                u=((index-8)/12+phase)%1
                if u<.5:travel=amplitude*(1-4*u);rise=0.
                else:
                    f=(u-.5)*2;travel=-amplitude*math.cos(math.pi*f);rise=-lift*math.sin(math.pi*f)
                p['ik'][name]=[sign*travel,rise+depth*travel*.17]
                foot=name.replace('leg','foot',1)
                p['world_angles'][foot]=0 if u<.5 else sign*(-15*math.sin(math.pi*(u-.5)*2))
            for side,phase in [('left',0),('right',math.pi)]:
                a('upper_arm_'+side,10*math.sin(t+phase));a('arm_'+side,-10*math.sin(t+phase-.25))
    elif index<36:
        special=index>=28;step=index-(28 if special else 20)
        power=[0,-.30,-.72,-.30,1.,.74,.25,0][step]
        plant()
        sh('torso',(10 if special else 7)*power,5*abs(power))
        a('torso',5*power);a('head',-7*power)
        if slug=='sentinelle_airain':
            side='left' if special else 'right'
            reach=45 if direction=='S' and not special else sign*(32 if special else 47)
            p['ik']['upper_arm_'+side]=[reach*power,8*power]
            other='right' if special else 'left'
            a('upper_arm_'+other,-8*power);a('arm_'+other,12*power)
            if not special and 'hand_right' in names:
                weapon=next(part for part in parts if part['name']=='hand_right')
                desired={'E':25.,'S':155.,'N':-25.,'W':-155.}[direction]
                aim=shortest(desired-angle_of(weapon['weapon_axis']))
                p['world_angles']['hand_right']=aim*max(0,power)-20*sign*min(0,power)
            elif not special:
                a('arm_right',55*power)
            sh('torso',16*power,5*abs(power))
        elif slug=='rejeton_braise':
            a('upper_arm_right',(-40 if special else -18)*power)
            a('arm_right',(-35 if special else -28)*power)
            a('upper_arm_left',(28 if special else -8)*power)
            a('arm_left',(-65 if special else -38)*power)
            a('head',(-13 if special else -8)*power)
            sh('torso',8*power,-7*max(0,power)+6*max(0,-power));a('cloth',-13*power)
        elif slug=='molosse_styx':
            a('head',-13*power);a('jaw',24*max(0,power))
            a('tail',-22*power)
            sh('torso',(25 if special else 14)*power,-13*max(0,power)+8*max(0,-power))
            if special:
                p['ik']={};p['world_angles']={}
                a('leg_right',-38*power);a('shin_right',45*power)
                a('leg_fore_far',-32*power);a('shin_fore_far',30*power)
                a('leg_left',25*power);a('shin_left',-35*power)
                a('leg_hind_far',18*power);a('shin_hind_far',-27*power)
        else:
            a('upper_arm_right',(42 if special else 23)*power)
            a('arm_right',(48 if special else 33)*power)
            a('upper_arm_left',-14*power);a('arm_left',(-20 if special else 9)*power)
            a('head',-10*power);a('torso',-8*power)
            sh('torso',6*power,-8*max(0,power))
            p['tail_wave']=[step*.8,5+6*abs(power)]
    elif index<40:
        power=[.35,1.,.50,0][index-36];plant()
        sh('torso',-13*power,5*power);a('torso',-10*power)
        a('head',13*power);a('upper_arm_left',16*power);a('upper_arm_right',-18*power)
        a('arm_left',12*power);a('arm_right',-15*power);a('tail',9*power)
    else:
        fall=[0,.12,.30,.50,.72,.90,1.,1.][index-40]
        p['ground_death']=True
        a('head',18*fall);a('upper_arm_right',-32*fall);a('arm_right',44*fall)
        a('upper_arm_left',25*fall);a('arm_left',-40*fall)
        if slug=='molosse_styx':
            sh('torso',-6*fall,45*fall);a('torso',5*fall);a('head',25*fall)
            a('leg_left',-75*fall);a('shin_left',-10*fall)
            a('leg_hind_far',-65*fall);a('shin_hind_far',-15*fall)
            a('leg_right',65*fall);a('shin_right',35*fall)
            a('leg_fore_far',55*fall);a('shin_fore_far',45*fall)
            a('tail',-20*fall);a('jaw',6*fall)
        elif slug=='lamie_lethe':
            a('torso',-68*fall)
            a('head',28*fall);a('arm_left',30*fall);a('upper_arm_left',15*fall)
            a('upper_arm_right',25*fall);a('arm_right',50*fall)
            p['tail_wave']=[fall*2,4*(1-fall)]
        else:
            p['root']={'angle':-74*fall*sign,'shift':[70*fall*sign,-25*fall]}
            sh('torso',0,19*fall);a('torso',-8*fall)
            a('leg_left',-25*fall);a('shin_left',55*fall)
            a('leg_right',26*fall);a('shin_right',-42*fall)
            a('cloth',25*fall)
            if 'hand_right' in names:
                weapon=next(part for part in parts if part['name']=='hand_right')
                desired=170. if direction in 'EN' else 10.
                p['world_angles']['hand_right']=shortest(desired-angle_of(weapon['weapon_axis']))*fall
    p['action']='idle' if index<8 else 'walk' if index<20 else 'attack' if index<28 else 'cast' if index<36 else 'hit' if index<40 else 'death'
    return p
