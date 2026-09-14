"""Overlapping joints and two-link limbs using the existing source artwork."""
import math
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import map_coordinates
import source_rig as rig

def section(image,y0,y1):
    p=np.array(image); y=np.arange(image.height)[:,None]
    keep=(y>=y0)&(y<=y1);p[~np.broadcast_to(keep,p.shape[:2])]=0
    return Image.fromarray(p)

def circle(image,point,radius):
    mask=Image.new('L',image.size);x,y=point
    ImageDraw.Draw(mask).ellipse((x-radius,y-radius,x+radius,y+radius),fill=255)
    p=np.array(image);p[:,:,3]=np.minimum(p[:,:,3],np.array(mask))
    return Image.fromarray(p)

def between(image,p0,p1,q0,q1):
    """Constant transverse width, perspective shortening along the segment only."""
    p0,p1,q0,q1=map(lambda x:np.array(x,dtype=float),(p0,p1,q0,q1))
    a=p1-p0;b=q1-q0;u=a/np.linalg.norm(a);v=b/np.linalg.norm(b)
    source_basis=np.column_stack([u,[-u[1],u[0]]])
    dest_basis=np.column_stack([v,[-v[1],v[0]]])
    matrix=dest_basis@np.diag([np.linalg.norm(b)/np.linalg.norm(a),rig.S])@source_basis.T
    inv=np.linalg.inv(matrix);translation=q0-matrix@p0
    return image.convert('RGBa').transform((rig.W,rig.W),Image.Transform.AFFINE,tuple(np.column_stack([inv,-inv@translation]).ravel()),Image.Resampling.BICUBIC).convert('RGBA')

legs={}
for side in 'LR':
    image=Image.open(rig.ROOT/f'art/source/characters/achilles/veilleur_walk_E_v5/leg_{side}_completed.png').convert('RGBA');p=np.array(image)
    p[np.array(rig.parts['boot_'+side])[:,:,3]>0]=0;image=Image.fromarray(p)
    knee=rig.J[side]['knee'];radius=42 if side=='R' else 36
    legs[side]={'image':image,'upper':section(image,0,knee[1]+18),'lower':section(image,knee[1]-18,image.height),
                'cap':circle(image,knee,radius)}

def rigid_leg_trial(side,hip,knee,cuff):
    j=rig.J[side];pieces=legs[side]
    frame=between(pieces['upper'],j['hip'],j['knee'],hip,knee)
    frame.alpha_composite(between(pieces['lower'],j['knee'],j['ankle'],knee,cuff))
    source_axis=np.subtract(j['ankle'],j['hip']);axis=cuff-hip
    angle=math.atan2(axis[1],axis[0])-math.atan2(source_axis[1],source_axis[0])
    frame.alpha_composite(rig.rigid(pieces['cap'],j['knee'],knee,angle))
    return frame

def limb_matrix(p0,p1,q0,q1):
    p0,p1,q0,q1=map(lambda p:np.array(p,dtype=float),(p0,p1,q0,q1))
    u=p1-p0;v=q1-q0;su=np.linalg.norm(u);sv=np.linalg.norm(v);u/=su;v/=sv
    matrix=np.column_stack([v,[-v[1],v[0]]])@np.diag([sv/su,rig.S])@np.column_stack([u,[-u[1],u[0]]]).T
    return matrix,q0-matrix@p0

mesh_sources={}
last_leg_report={}
for side in 'LR':
    im=legs[side]['image'];bbox=im.getchannel('A').getbbox()
    xx,yy=np.meshgrid(np.linspace(bbox[0]-2,bbox[2]+2,12),np.linspace(bbox[1]-2,bbox[3]+2,44))
    points=np.stack([xx,yy],axis=-1)
    pixels=np.array(im).astype(float)/255;pixels[:,:,:3]*=pixels[:,:,3:4]
    mesh_sources[side]=(points,pixels)

def leg(side,hip,knee,cuff):
    """One continuous UV surface; smooth two-bone weights around the knee."""
    source,pixels=mesh_sources[side];j=dict(rig.J[side])
    # Skin binding uses the centre of the trouser cross-section, not the offset
    # painted kneecap highlight. The motion skeleton itself stays unchanged.
    j['knee']=[525.,869.] if side=='R' else [716.,846.]
    upper,tu=limb_matrix(j['hip'],j['knee'],hip,knee)
    lower,tl=limb_matrix(j['knee'],j['ankle'],knee,cuff)
    bind_axis=np.subtract(j['ankle'],j['hip']).astype(float);bind_axis/=np.linalg.norm(bind_axis)
    longitudinal=(source-np.array(j['knee']))@bind_axis
    weight=np.clip((longitudinal+76)/152,0,1)
    weight=weight*weight*(3-2*weight)
    def polar(matrix):
        u,values,vt=np.linalg.svd(matrix);r=u@vt
        return math.atan2(r[1,0],r[0,0]),vt.T@np.diag(values)@vt
    angle0,stretch0=polar(upper);angle1,stretch1=polar(lower)
    delta_angle=math.atan2(math.sin(angle1-angle0),math.cos(angle1-angle0))
    angles=angle0+weight*delta_angle
    relative=source-np.array(j['knee'])
    stretched=(relative@stretch0.T)*(1-weight[:,:,None])+(relative@stretch1.T)*weight[:,:,None]
    c=np.cos(angles);s=np.sin(angles)
    destination=np.stack([c*stretched[:,:,0]-s*stretched[:,:,1],s*stretched[:,:,0]+c*stretched[:,:,1]],axis=-1)+knee
    sx=np.full((rig.W,rig.W),-1.);sy=sx.copy();inverted=[];empty_inversions=0
    for row in range(source.shape[0]-1):
      for col in range(source.shape[1]-1):
       for corners in [(0,1,2),(1,3,2)]:
        sv=np.array([source[row,col],source[row,col+1],source[row+1,col],source[row+1,col+1]])[list(corners)]
        dv=np.array([destination[row,col],destination[row,col+1],destination[row+1,col],destination[row+1,col+1]])[list(corners)]
        mat=np.column_stack([dv[1]-dv[0],dv[2]-dv[0]])
        det=np.linalg.det(mat)
        if det<=0:
            bx0,by0=np.maximum(0,np.floor(sv.min(axis=0)).astype(int));bx1,by1=np.minimum([pixels.shape[1],pixels.shape[0]],np.ceil(sv.max(axis=0)).astype(int)+1)
            yy,xx=np.mgrid[by0:by1,bx0:bx1]
            sw=np.stack([xx+.5-sv[0,0],yy+.5-sv[0,1]],axis=-1)@np.linalg.inv(np.column_stack([sv[1]-sv[0],sv[2]-sv[0]])).T
            visible=(sw[:,:,0]>=0)&(sw[:,:,1]>=0)&(sw.sum(axis=-1)<=1)&(pixels[by0:by1,bx0:bx1,3]>0)
            if visible.any():inverted.append({'source_center':sv.mean(axis=0).tolist(),'visible_pixels':int(visible.sum())})
            else:empty_inversions+=1
            continue
        x0,y0=np.maximum(0,np.floor(dv.min(axis=0)).astype(int));x1,y1=np.minimum(rig.W,np.ceil(dv.max(axis=0)).astype(int)+1)
        if x1<=x0 or y1<=y0:continue
        yy,xx=np.mgrid[y0:y1,x0:x1]
        w=np.stack([xx+.5-dv[0,0],yy+.5-dv[0,1]],axis=-1)@np.linalg.inv(mat).T
        inside=(w[:,:,0]>=-1e-6)&(w[:,:,1]>=-1e-6)&(w.sum(axis=-1)<=1+1e-6)
        mapped=sv[0]+w[:,:,0:1]*(sv[1]-sv[0])+w[:,:,1:2]*(sv[2]-sv[0])
        sx[y0:y1,x0:x1][inside]=mapped[:,:,0][inside];sy[y0:y1,x0:x1][inside]=mapped[:,:,1][inside]
    assert not inverted,(side,inverted)
    last_leg_report[side]={'inverted_triangles_over_art':len(inverted),'inverted_triangles_over_transparent_space':empty_inversions}
    result=np.stack([map_coordinates(pixels[:,:,c],[sy,sx],order=1,mode='constant',cval=0,prefilter=False) for c in range(4)],axis=-1)
    a=result[:,:,3:4];result[:,:,:3]=np.divide(result[:,:,:3],a,out=np.zeros_like(result[:,:,:3]),where=a>1e-8)
    return Image.fromarray(np.round(np.clip(result,0,1)*255).astype('uint8'))

ELBOW={'R':np.array([427.,590.]),'L':np.array([798.,555.])}
WRIST={'R':np.array([435.,717.]),'L':np.array([832.,681.])}
HAND={'R':np.array([438.,775.]),'L':np.array([841.,728.])}
arms={}
for side in 'LR':
    im=rig.parts['arm_'+side]; elbow=ELBOW[side]
    arms[side]={'upper':section(im,0,elbow[1]+24),'lower':section(im,elbow[1]-20,im.height),
                'cap':circle(im,elbow,39 if side=='R' else 30)}

def arm(side,shoulder,upper_angle,bend):
    pieces=arms[side]; source_shoulder=rig.J[side]['shoulder']; elbow=ELBOW[side]
    target_elbow=shoulder+rig.rotation(upper_angle)@((elbow-source_shoulder)*rig.S)
    lower_angle=upper_angle+bend
    upper=rig.rigid(pieces['upper'],source_shoulder,shoulder,upper_angle)
    lower=rig.rigid(pieces['lower'],elbow,target_elbow,lower_angle)
    lower.alpha_composite(rig.rigid(pieces['cap'],elbow,target_elbow,upper_angle+bend*.5))
    wrist=target_elbow+rig.rotation(lower_angle)@((WRIST[side]-elbow)*rig.S)
    hand=target_elbow+rig.rotation(lower_angle)@((HAND[side]-elbow)*rig.S)
    return upper,lower,{'shoulder':shoulder.tolist(),'elbow':target_elbow.tolist(),'wrist':wrist.tolist(),'hand':hand.tolist(),
                       'upper_angle':upper_angle,'elbow_bend':bend}
