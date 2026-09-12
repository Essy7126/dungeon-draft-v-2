"""Read-only drawing pieces and continuous trouser renderer shared by pose trials."""
from pathlib import Path
import json,math
import numpy as np
from scipy.ndimage import map_coordinates
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'art/source/characters/achilles/veilleur_proportions_v1'
CFG=json.loads((BASE/'landmarks.json').read_text());J=CFG['joints'];S=CFG['scale'];W=512
PIVOT=np.array([256.,442.]);ORIGIN=np.array([637.,1211.]);OFFSET=PIVOT-ORIGIN*S
parts={name:Image.open(BASE/(name+'.png')).convert('RGBA') for name in ['leg_L','leg_R','boot_L','boot_R','arm_L','arm_R','core']}
def project(p):return np.array(p,dtype=float)*S+OFFSET
def rotation(a):return np.array([[math.cos(a),-math.sin(a)],[math.sin(a),math.cos(a)]])
def rigid(image,anchor,target,angle=0):
    m=S*rotation(angle);inv=np.linalg.inv(m);offset=np.array(target)-m@np.array(anchor)
    coefficients=np.column_stack([inv,-inv@offset]).ravel()
    return image.convert('RGBa').transform((W,W),Image.Transform.AFFINE,tuple(coefficients),Image.Resampling.BICUBIC).convert('RGBA')
def ribbon(joints,scale=1.):
    h,k,a=[np.array(p,dtype=float) for p in joints];u0=k-h;u1=a-k
    l0=np.linalg.norm(u0);l1=np.linalg.norm(u1);n0=u0/l0;n1=u1/l1
    middle=n0+n1;middle/=np.linalg.norm(middle);sections=[]
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
cloth_sources={};source_ribbons={}
for side in 'LR':
    p=np.array(parts['leg_'+side]).astype(float)/255;b=np.array(parts['boot_'+side])[:,:,3]>0;p[b]=0;p[:,:,:3]*=p[:,:,3:4]
    cloth_sources[side]=p;source_ribbons[side]=ribbon([J[side][name] for name in ['hip','knee','ankle']])
def mapped_cloth(side,destination):
    source=source_ribbons[side];sx=np.full((W,W),-1.,dtype=float);sy=sx.copy()
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
            sx[y0:y1,x0:x1][inside]=original[:,:,0][inside];sy[y0:y1,x0:x1][inside]=original[:,:,1][inside]
    sampled=np.stack([map_coordinates(cloth_sources[side][:,:,c],[sy,sx],order=1,mode='constant',cval=0,prefilter=False) for c in range(4)],axis=-1)
    alpha=sampled[:,:,3:4];sampled[:,:,:3]=np.divide(sampled[:,:,:3],alpha,out=np.zeros_like(sampled[:,:,:3]),where=alpha>1e-8)
    return Image.fromarray(np.round(np.clip(sampled,0,1)*255).astype('uint8'))
