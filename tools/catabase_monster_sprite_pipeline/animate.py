"""Author deterministic 2D skeletal poses from Meshy fixed-view paintings.

No remote generation or texture mirroring. A continuous inverse deformation
articulates the painting at explicit joints without cutting its silhouette.
Fixed ground roots and common scaling are established
by prepare_views.py. See rig.json for editable anatomy and pose parameters.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'output/monster-meshy-deps'))
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, map_coordinates
from build import pack_frames, write_sprite_frames

SOURCE = ROOT/'art/source/characters/catabase_monsters'
RIG_PATH = Path(__file__).with_name('rig.json')
CANVAS = (512,384)

def bone(pivot, polygon, parent='torso'):
    return {'pivot':pivot,'polygon':polygon,'parent':parent}

def default_rig(slug, direction):
    """Anatomy coordinates are normalized to the view's opaque bounds."""
    front = direction in ('E','S')
    leftward = direction in ('S','W')
    if slug == 'molosse_styx':
        bones={
            'torso':bone([.5,.48],[], 'root'),
            'head':bone([.72,.35],[[.67,0],[1,0],[1,.64],[.68,.59]]),
            'jaw':bone([.83,.32],[[.77,.31],[1,.3],[1,.48],[.82,.47]],'head'),
            'tail':bone([.18,.36],[[0,.04],[.24,.04],[.26,.57],[0,.7]]),
            'leg_left':bone([.26,.58],[[.06,.48],[.36,.48],[.39,1.01],[.04,1.01]],'root'),
            'shin_left':bone([.20,.8],[[.04,.76],[.34,.76],[.37,1.01],[.02,1.01]],'leg_left'),
            'leg_right':bone([.70,.57],[[.58,.46],[.92,.45],[1,1.01],[.55,1.01]],'root'),
            'shin_right':bone([.77,.82],[[.6,.78],[.98,.74],[1,1.01],[.56,1.01]],'leg_right'),
            'leg_hind_far':bone([.36,.57],[[.31,.57],[.43,.57],[.44,.7],[.49,.82],[.38,.86],[.3,.7]],'root'),
            'leg_fore_far':bone([.77,.52],[[.73,.49],[.82,.51],[.88,.73],[1,.88],[.91,.92],[.8,.76],[.69,.62]],'root'),
        }
    elif slug=='lamie_lethe':
        bones={
            'torso':bone([.51,.54],[], 'root'),
            'head':bone([.5,.2],[[.23,0],[.78,0],[.76,.3],[.28,.3]]),
            'arm_left':bone([.35,.3],[[0,.26],[.37,.22],[.45,.46],[.28,.61],[0,.63]]),
            'arm_right':bone([.67,.31],[[.67,.25],[.9,.05],[1,0],[1,.69],[.75,.77],[.61,.43]]),
            'tail':bone([.5,.6],[[0,.61],[.74,.56],[1,.65],[1,1.01],[0,1.01]],'root'),
        }
    elif slug=='rejeton_braise':
        bones={
            'torso':bone([.48,.61],[], 'root'),
            'head':bone([.54,.27],[[.26,0],[.82,0],[.8,.34],[.34,.34]]),
            'arm_left':bone([.29,.38],[[.20,.28],[.38,.28],[.43,.43],[.63,.44],[.72,.34],[1,.35],[1,.72],[.30,.71],[.20,.58]]),
            'leg_left':bone([.37,.64],[[.15,.61],[.45,.6],[.47,.78],[.29,1.01],[0,1.01],[.03,.86]],'root'),
            'shin_left':bone([.18,.83],[[.03,.78],[.29,.8],[.31,1.01],[0,1.01]],'leg_left'),
            'leg_right':bone([.59,.65],[[.51,.6],[.72,.62],[.82,.85],[1,.89],[1,1.01],[.54,.94],[.49,.8]],'root'),
            'shin_right':bone([.68,.82],[[.54,.8],[.79,.78],[1,.88],[1,1.01],[.57,1.01]],'leg_right'),
        }
        if not front:
            bones['arm_left']=bone([.65,.32],[[.6,.23],[.81,.27],[.84,.36],[1,.33],[1,.59],[.69,.59],[.57,.44]])
    else:
        bones={
            'torso':bone([.52,.63],[], 'root'),
            'head':bone([.51,.19],[[.38,0],[.65,0],[.68,.22],[.36,.22]]),
            'arm_left':bone([.30,.29],[[0,.04],[.27,.09],[.4,.21],[.35,.52],[.29,.75],[0,.74]]),
            'arm_right':bone([.72,.28],[[.67,.17],[1,.14],[1,.79],[.71,.80],[.59,.51]]),
            'leg_left':bone([.38,.63],[[.23,.59],[.47,.61],[.51,.8],[.41,1.01],[.1,1.01],[.12,.86]],'root'),
            'shin_left':bone([.31,.82],[[.15,.79],[.43,.79],[.45,1.01],[.08,1.01]],'leg_left'),
            'leg_right':bone([.65,.66],[[.53,.61],[.76,.64],[.8,.84],[.94,1.01],[.54,1.01]],'root'),
            'shin_right':bone([.69,.84],[[.55,.8],[.82,.79],[.95,1.01],[.56,1.01]],'leg_right'),
        }
    # Geometry can follow the separately drawn opposite view; image pixels are
    # never flipped. Each entry can then be edited independently in rig.json.
    flip_geometry=(direction in ('N','W')) if slug in ('sentinelle_airain','lamie_lethe') else leftward
    if flip_geometry:
        for b in bones.values():
            b['pivot'][0]=1-b['pivot'][0]
            b['polygon']=[[1-x,y] for x,y in b['polygon']]
    return {'slug':slug,'direction':direction,'bones':bones,'blend_pixels':14.0,
            'facing_sign':-1 if leftward else 1, 'back_view':not front,
            'weapon_bone':'arm_left' if slug!='lamie_lethe' else 'arm_right'}

def transform(pivot, angle=0, translation=(0,0), scale=(1,1)):
    a=math.radians(angle)
    c,s=math.cos(a),math.sin(a)
    m=np.array([[c*scale[0],-s*scale[1],0],[s*scale[0],c*scale[1],0],[0,0,1]],float)
    p=np.array(pivot,float)
    m[:2,2]=p+np.array(translation)-m[:2,:2]@p
    return m

def recipe(slug, index, rig):
    sign=rig['facing_sign']
    angles={}; shifts={}; root={}; extra={}
    def a(name, value): angles[name]=value*sign
    def sh(name,x,y): shifts[name]=[x*sign,y]
    if index==0:return {'angles':angles,'shifts':shifts,'root':root,'extra':extra}
    if 1<=index<=6:
        t=(index-1)/6*2*math.pi
        stride=math.sin(t)
        a('leg_left',9*stride); a('leg_right',-9*stride)
        a('shin_left',-8*max(0,math.sin(t+.65))); a('shin_right',8*max(0,math.sin(t+.65+math.pi)))
        sh('torso',0,-2.6*abs(math.sin(t)))
        a('head',1.8*stride)
        if slug=='molosse_styx':
            a('head',-3*stride);a('tail',7*stride)
            a('leg_hind_far',-9*stride);a('leg_fore_far',9*stride)
            extra['quadruped_phase']=t
        elif slug=='lamie_lethe':
            extra['tail_wave']=[t,5]
            a('torso',2*stride);a('head',-1.5*stride)
        else:
            a('arm_left',-5*stride);a('arm_right',5*stride)
    elif index in range(7,15):
        special=index>=11
        stage=index-(11 if special else 7)
        power=[-.35,.35,1,.12][stage]
        sh('torso',(-4 if special else -2)*-power,-abs(power)*2)
        a('torso',-3*power);a('head',-4*power)
        if slug=='sentinelle_airain':
            target='arm_right' if special else 'arm_left'
            a(target,(8 if special else 10)*power)
            sh(target,(7 if special else 12)*power,-3*power)
            a('leg_left',-4*power);a('shin_right',5*power)
        elif slug=='rejeton_braise':
            a('arm_left',(-12 if special else -6)*power)
            sh('arm_left',(3 if special else 7)*power,(-5 if special else -1)*power)
            a('head',-4*power)
        elif slug=='molosse_styx':
            a('head',-9*power);sh('head',6*power,3*power)
            sh('torso',(10 if special else 3)*power,(-6 if special else 0)*max(power,0))
            a('leg_right',-12*power if special else -5*power)
            a('leg_left',10*power if special else 3*power)
            a('tail',-8*power)
            a('jaw',5*power);sh('jaw',0,1*power)
            extra['jaw']=power*5
        else:
            a('arm_left',-12*power if special else -6*power)
            sh('arm_left',5*power,-4*power)
            a('arm_right',-6*power if special else 3*power)
            sh('arm_right',3*power,-6*power if special else 0)
            extra['tail_wave']=[stage*.55,3*abs(power)]
    elif index==15:
        a('torso',5);a('head',7)
        sh('torso',-4,2)
        a('arm_left',5);a('arm_right',-4)
        a('leg_left',5);a('leg_right',-4)
    else:
        stage=index-16
        fall=[.12,.38,.72,1.0][stage]
        # Multiple joint folds precede the grounded fall; this is not a rigid
        # rotation/fade of the idle image. The runtime may fade the final corpse.
        a('torso',-5*fall);a('head',-4*fall)
        a('arm_left',8*fall);a('arm_right',-6*fall)
        a('leg_left',-9*fall);a('leg_right',8*fall)
        a('shin_left',12*fall);a('shin_right',-11*fall)
        a('leg_hind_far',-9*fall);a('leg_fore_far',10*fall)
        a('tail',8*fall)
        if slug=='lamie_lethe':
            root={'angle':-49*fall*sign,'translation':[52*fall*sign,-24*fall], 'scale':[1,1]}
            sh('torso',5*fall,12*fall)
        elif slug=='molosse_styx':
            root={'angle':78*fall*sign,'translation':[-8*fall*sign,3*fall],'scale':[1,1]}
            sh('torso',0,12*fall);a('head',12*fall)
        else:
            root={'angle':-85*fall*sign,'translation':[78*fall*sign,-38*fall],'scale':[1,1]}
            sh('torso',0,14*fall)
        extra['death_progress']=fall
    return {'angles':angles,'shifts':shifts,'root':root,'extra':extra}

class Puppet:
    """Continuous articulated painting with a bounded, invertible local field."""
    def __init__(self, image, rig):
        self.image=image.convert('RGBA'); self.rig=rig
        self.rgba=np.asarray(self.image).astype(float)
        self.bbox=self.image.getchannel('A').point(lambda a:255 if a>32 else 0).getbbox()
        x0,y0,x1,y1=self.bbox
        self.origin=np.array([x0,y0]); self.extent=np.array([x1-x0,y1-y0])
        self.yy,self.xx=np.mgrid[0:384,0:512].astype(float)
        self.points=np.stack([self.xx,self.yy,np.ones_like(self.xx)],axis=-1)
        self.bones={}; labels=np.zeros((384,512),np.int16); names=['torso']
        for name,b in rig['bones'].items():
            self.bones[name]={**b,'absolute_pivot':(self.origin+np.array(b['pivot'])*self.extent).tolist()}
            if not b['polygon']: continue
            mask=Image.new('L',CANVAS)
            ImageDraw.Draw(mask).polygon([tuple(self.origin+np.array(point)*self.extent) for point in b['polygon']],fill=255)
            names.append(name); labels[np.array(mask)>0]=len(names)-1
        self.weights={name:gaussian_filter((labels==i).astype(float),rig['blend_pixels'],mode='nearest') for i,name in enumerate(names)}
        self.premult=self.rgba.copy()
        self.premult[:,:,:3]*=self.rgba[:,:,3:4]/255

    def render(self, pose):
        # Build a continuous displacement field from joints. Broad influence
        # transitions keep the painted outline connected instead of revealing
        # holes at cutout boundaries. Equipment shares its hand's influence.
        matrices={'root':np.eye(3)}
        for name,b in self.bones.items():
            local=transform(b['absolute_pivot'],pose['angles'].get(name,0),pose['shifts'].get(name,[0,0]))
            matrices[name]=matrices[b['parent']]@local
        dx=np.zeros((384,512)); dy=np.zeros_like(dx)
        for name,weight in self.weights.items():
            moved=self.points@matrices[name].T
            dx+=weight*(moved[:,:,0]-self.xx)
            dy+=weight*(moved[:,:,1]-self.yy)
        extra=pose['extra']
        if 'tail_wave' in extra:
            phase,amplitude=extra['tail_wave']
            relative=(self.yy-self.origin[1])/self.extent[1]
            dx+=self.weights.get('tail',0)*amplitude*np.sin((relative-.55)*8-phase)
        # Bound the displacement gradient so inversion is a contraction. This
        # prevents spikes/folds while retaining each animation's authored pose.
        dxy,dxx=np.gradient(dx); dyy,dyx=np.gradient(dy)
        norm=np.sqrt(dxx*dxx+dxy*dxy+dyx*dyx+dyy*dyy)
        strength=min(1.0,.55/max(float(norm.max()),1e-9))
        dx*=strength; dy*=strength
        extra['local_motion_strength']=strength
        r=pose['root']
        root=transform([256,320],r.get('angle',0),r.get('translation',[0,0]),r.get('scale',[1,1]))
        if 'death_progress' in extra:
            support=self.rgba[:,:,3]>32
            moved=np.stack([self.xx+dx,self.yy+dy,np.ones_like(dx)],axis=-1)@root.T
            visible=moved[support,:2]
            minimum=visible.min(axis=0); maximum=visible.max(axis=0)
            if maximum[1]-minimum[1]>310 or maximum[0]-minimum[0]>492:
                raise ValueError(f"Death pose exceeds fixed canvas; revise pose, never rescale: {maximum-minimum}")
            offset=[max(0,8-minimum[0])-max(0,maximum[0]-504),320-maximum[1]]
            root[:2,2]+=offset
            extra['grounded_death_offset']=[float(v) for v in offset]
        inverse=np.linalg.inv(root)
        target=self.points@inverse.T
        tx,ty=target[:,:,0],target[:,:,1]
        sx,sy=tx.copy(),ty.copy()
        for _ in range(12):
            sample=[sy,sx]
            sx=tx-map_coordinates(dx,sample,order=1,mode='nearest')
            sy=ty-map_coordinates(dy,sample,order=1,mode='nearest')
        result=np.stack([map_coordinates(self.premult[:,:,ch],[sy,sx],order=1,mode='constant',cval=0) for ch in range(4)],axis=-1)
        alpha=result[:,:,3:4]
        result[:,:,:3]=np.where(alpha>0,result[:,:,:3]*255/np.maximum(alpha,1e-9),0)
        result=np.clip(np.rint(result),0,255).astype(np.uint8)
        result[result[:,:,3]==0,:3]=0
        return Image.fromarray(result)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--slug',default='all')
    parser.add_argument('--direction',default='all')
    args=parser.parse_args()
    slugs=['sentinelle_airain','rejeton_braise','molosse_styx','lamie_lethe'] if args.slug=='all' else [args.slug]
    directions='NESW' if args.direction=='all' else args.direction
    rigs=json.loads(RIG_PATH.read_text(encoding='utf-8')) if RIG_PATH.exists() else {}
    for slug in slugs:
        for direction in directions:
            key=f'{slug}_{direction}'
            if key not in rigs or not rigs[key].get('manual_reviewed',False):
                rigs[key]=default_rig(slug,direction)
    RIG_PATH.write_text(json.dumps(rigs,ensure_ascii=False,indent=2),encoding='utf-8')
    # Hash each independent rig so rendering another family cannot invalidate it.
    for slug in slugs:
        for direction in directions:
            base_path=SOURCE/slug/f'base_frame_{direction}.png'
            base=Image.open(base_path).convert('RGBA')
            rig=rigs[f'{slug}_{direction}']
            rig_hash=hashlib.sha256(json.dumps(rig,sort_keys=True,separators=(',',':')).encode()).hexdigest()
            puppet=Puppet(base,rig)
            poses=[recipe(slug,index,rig) for index in range(20)]
            frames=[base.copy()]+[puppet.render(pose) for pose in poses[1:]]
            review=ROOT/'output/catabase_monsters'/slug
            review.mkdir(parents=True,exist_ok=True)
            debug=Image.new('RGB',(512*4,384*5),'#27363d')
            for i,frame in enumerate(frames):debug.paste(frame,((i%4)*512,(i//4)*384),frame)
            debug.save(review/f'puppet_{direction}_review.jpg',quality=90)
            provenance={'reference_view':str(base_path.relative_to(ROOT)).replace('\\','/'),'reference_sha256':hashlib.sha256(base_path.read_bytes()).hexdigest(),'rig_path':str(RIG_PATH.relative_to(ROOT)).replace('\\','/'),'rig_entry':f'{slug}_{direction}','rig_entry_sha256':rig_hash,'renderer_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'method':'Local continuous 2D skeletal articulation of independently drawn Meshy fixed views; bounded inverse deformation, intact painted silhouette, no texture mirroring or synthesized body parts.','pose_recipes':poses,'source_bbox':puppet.bbox,'render_sampling':'premultiplied RGBA bilinear inverse field; smooth local snake-tail wave; no effects or shadows baked'}
            report=pack_frames(slug,direction,frames,provenance)
            print(json.dumps({'slug':slug,'direction':direction,'frames':len(frames),'raster_error':report['raster_max_error']},ensure_ascii=False),flush=True)
        if args.direction=='all':
            # Reviewed head/upper-neck crops in the fixed E idle canvas.
            # Weapons and broad shoulders must not shrink faces in turn order.
            portrait={
                'sentinelle_airain':[168,32,75,86],
                'rejeton_braise':[207,88,108,106],
                'molosse_styx':[270,151,91,87],
                'lamie_lethe':[249,48,58,80],
            }[slug]
            write_sprite_frames(slug,portrait)
            print('FAMILY_COMPLETE: '+slug,flush=True)

if __name__=='__main__':main()
