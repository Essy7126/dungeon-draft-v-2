"""Three genuinely drawn views, one shared gait, original E V5 kept verbatim.

ImageGen provides stable directional pieces. This file only extracts, binds,
animates and packages those drawings; it never mirrors artwork.
"""
from pathlib import Path
import ast, json, math, shutil, hashlib, sys
import numpy as np
from scipy import ndimage as ndi
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/source/characters/achilles/veilleur_walk_iso_v1'
OUT=ROOT/'artifacts/spine_trial/veilleur_walk_iso_v1'
OUT.mkdir(exist_ok=True)
W=512; N=48; DURATION=800; PIVOT=np.array([256.,442.]); BASE=np.array([256.,294.16])
U=39.6038381978; V=73.6591300607
def vec(p):return np.array(p,dtype=float)
def rot(a):return np.array([[math.cos(a),-math.sin(a)],[math.sin(a),math.cos(a)]])

# Reuse the exact V5 gait functions without executing the old exporter.
tree=ast.parse(Path(__file__).with_name('walk_v5_refined.py').read_text())
env={'np':np,'math':math,'STANCE':.60,'AMPLITUDE':21.}
exec(compile(ast.Module(body=[node for node in tree.body if isinstance(node,ast.FunctionDef) and node.name in ['ease','trajectory']],type_ignores=[]),'<V5 gait>','exec'),env)
ease=env['ease']; trajectory=env['trajectory']

# Landmarks are annotated on the actual generated sheets (1536 x 1024),
# not guessed from their requested layout. Sources are saved with the art.
CONFIG={
 'S':{'near':'L','split':512,'core_anchor':[294,491], 'core_scale':.476,
      'shoulders':{'near':[379,271],'far':[210,251]},
      'near_arm':[[769,87],[775,253],[750,427]], 'far_arm':[[1246,84],[1277,256],[1267,417]],
      'near_leg':[[283,563],[287,661],[322,746],[317,849],[383,900],[207,948]],
      'far_leg':[[752,577],[765,659],[780,750],[786,846],[842,901],[673,939]],
      'boot_cut':[731,736]},
 'N':{'near':'R','split':480,'core_anchor':[260,459], 'core_scale':.505,
      'shoulders':{'near':[342,234],'far':[173,236]},
      'near_arm':[[750,79],[722,228],[760,421]], 'far_arm':[[1223,79],[1266,231],[1310,410]],
      'near_leg':[[280,528],[272,640],[233,782],[236,844],[222,949],[320,865]],
      'far_leg':[[757,532],[754,638],[752,772],[756,835],[737,939],[852,858]],
      'boot_cut':[768,763]},
 'W':{'near':'L','split':512,'core_anchor':[276,462], 'core_scale':.505,
      'shoulders':{'near':[194,259],'far':[360,235]},
      'near_arm':[[750,99],[774,259],[758,431]], 'far_arm':[[1222,95],[1271,242],[1291,390]],
      'near_leg':[[245,561],[275,655],[293,767],[302,795],[334,929],[188,795]],
      'far_leg':[[740,570],[774,661],[790,775],[797,800],[841,926],[704,821]],
      'boot_cut':[746,756]},
}

# Saved attachments and PNG pieces are production inputs, not disposable output.
# --reextract explicitly rebuilds the cutouts from their generated sheets.
for direction in CONFIG:
    binding_path=SRC/f'{direction}_bindings.json'
    if binding_path.exists():
        CONFIG[direction]=json.loads(binding_path.read_text())

def clean_white(image):
    """Connected white-background removal with edge unmatting, ivory preserved."""
    rgb=np.array(image.convert('RGB'),dtype=float)
    labels,count=ndi.label(rgb.min(axis=2)<232)
    sizes=np.bincount(labels.ravel());sizes[0]=0
    mask=labels==int(sizes.argmax());mask=ndi.binary_fill_holes(mask)
    opaque=ndi.binary_erosion(mask,iterations=2)
    band=ndi.binary_dilation(mask,iterations=1)&~opaque
    _,index=ndi.distance_transform_edt(~opaque,return_indices=True)
    solid=rgb[index[0],index[1]]
    a=np.zeros(mask.shape);a[opaque]=1
    alpha=np.max(255-rgb,axis=2)/np.maximum(1,np.max(255-solid,axis=2))
    a[band]=np.clip(alpha[band],0,1)
    a[a<.025]=0
    rgb=np.divide(rgb-255*(1-a[:,:,None]),a[:,:,None],out=np.zeros_like(rgb),where=a[:,:,None]>0)
    return Image.fromarray(np.uint8(np.clip(np.dstack([rgb,a*255]),0,255)))

def extract(d):
    cfg=CONFIG[d];sheet=Image.open(SRC/f'{d}_sheet.png');assert sheet.size==(1536,1024),sheet.size
    folder=SRC/'parts'/d;folder.mkdir(parents=True,exist_ok=True)
    parts={};meta={}
    for i,name in enumerate(['core','near_arm','far_arm','near_leg','far_leg','reference']):
        row=i//3;col=i%3
        box=[col*512,0 if row==0 else cfg['split'],(col+1)*512,cfg['split'] if row==0 else 1024]
        path=folder/(name+'.png')
        if path.exists() and '--reextract' not in sys.argv:
            im=Image.open(path).convert('RGBA')
            assert im.size==(box[2]-box[0],box[3]-box[1]),('Keep the part canvas unchanged',path)
        else:
            im=clean_white(sheet.crop(box));im.save(path)
        parts[name]=im
        meta[name]={'box':box,'alpha_bbox':im.getbbox(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    (folder/'extraction.json').write_text(json.dumps(meta,indent=2))
    cfg['boxes']={name:val['box'] for name,val in meta.items()}
    return parts

def affine(im,m,source_anchor,target_anchor):
    translation=vec(target_anchor)-m@vec(source_anchor);inv=np.linalg.inv(m)
    return im.convert('RGBa').transform((W,W),Image.Transform.AFFINE,tuple(np.column_stack([inv,-inv@translation]).ravel()),Image.Resampling.BICUBIC).convert('RGBA')

def bone_matrix(p0,p1,q0,q1,width_scale):
    u=vec(p1)-p0;v=vec(q1)-q0;su=np.linalg.norm(u);sv=np.linalg.norm(v);u/=su;v/=sv
    return np.column_stack([v,[-v[1],v[0]]])@np.diag([sv/su,width_scale])@np.column_stack([u,[-u[1],u[0]]]).T

class Skin:
    """Continuous two-link UV surface; rotational blend avoids knee pinching."""
    def __init__(self,image,p0,p1,p2,width,blend):
        self.image=image;self.bind=[vec(p) for p in [p0,p1,p2]];self.width=width;self.blend=blend
        bbox=image.getbbox();xx,yy=np.meshgrid(np.linspace(bbox[0]-1,bbox[2]+1,13),np.linspace(bbox[1]-1,bbox[3]+1,40))
        self.source=np.stack([xx,yy],axis=-1)
        self.pixels=np.array(image,dtype=float)/255;self.pixels[:,:,:3]*=self.pixels[:,:,3:4]
    def draw(self,q0,q1,q2):
        p0,p1,p2=self.bind;source=self.source
        a=bone_matrix(p0,p1,q0,q1,self.width);b=bone_matrix(p1,p2,q1,q2,self.width)
        axis=p2-p0;axis/=np.linalg.norm(axis)
        weight=np.clip(((source-p1)@axis+self.blend)/(2*self.blend),0,1);weight=weight*weight*(3-2*weight)
        def polar(m):
            u,s,vt=np.linalg.svd(m);r=u@vt
            return math.atan2(r[1,0],r[0,0]),vt.T@np.diag(s)@vt
        angle0,stretch0=polar(a);angle1,stretch1=polar(b)
        delta=math.atan2(math.sin(angle1-angle0),math.cos(angle1-angle0));angles=angle0+delta*weight
        relative=source-p1;stretched=(relative@stretch0.T)*(1-weight[:,:,None])+(relative@stretch1.T)*weight[:,:,None]
        c=np.cos(angles);s=np.sin(angles)
        dest=np.stack([c*stretched[:,:,0]-s*stretched[:,:,1],s*stretched[:,:,0]+c*stretched[:,:,1]],axis=-1)+q1
        sx=np.full((W,W),-1.);sy=sx.copy();bad=0
        for row in range(source.shape[0]-1):
          for col in range(source.shape[1]-1):
           for ids in [(0,1,2),(1,3,2)]:
            sv=np.array([source[row,col],source[row,col+1],source[row+1,col],source[row+1,col+1]])[list(ids)]
            dv=np.array([dest[row,col],dest[row,col+1],dest[row+1,col],dest[row+1,col+1]])[list(ids)]
            mat=np.column_stack([dv[1]-dv[0],dv[2]-dv[0]])
            if np.linalg.det(mat)<=0:
                # Transparent margins may fold. Painted samples must not.
                center=sv.mean(axis=0);x,y=np.round(center).astype(int)
                if 0<=y<self.image.height and 0<=x<self.image.width and self.pixels[y,x,3]>.1:bad+=1
                continue
            x0,y0=np.maximum(0,np.floor(dv.min(axis=0)).astype(int));x1,y1=np.minimum(W,np.ceil(dv.max(axis=0)).astype(int)+1)
            if x1<=x0 or y1<=y0:continue
            yy,xx=np.mgrid[y0:y1,x0:x1]
            w=np.stack([xx+.5-dv[0,0],yy+.5-dv[0,1]],axis=-1)@np.linalg.inv(mat).T
            inside=(w[:,:,0]>=-1e-6)&(w[:,:,1]>=-1e-6)&(w.sum(axis=-1)<=1+1e-6)
            uv=sv[0]+w[:,:,0:1]*(sv[1]-sv[0])+w[:,:,1:2]*(sv[2]-sv[0])
            sx[y0:y1,x0:x1][inside]=uv[:,:,0][inside];sy[y0:y1,x0:x1][inside]=uv[:,:,1][inside]
        assert bad==0,('Painted skin fold',bad)
        sampled=np.stack([ndi.map_coordinates(self.pixels[:,:,c],[sy,sx],order=1,mode='constant',cval=0,prefilter=False) for c in range(4)],axis=-1)
        a=sampled[:,:,3:4];sampled[:,:,:3]=np.divide(sampled[:,:,:3],a,out=np.zeros_like(sampled[:,:,:3]),where=a>1e-8)
        return Image.fromarray(np.uint8(np.clip(sampled*255,0,255)))

class Renderer:
    def __init__(self,d):
        self.d=d;self.cfg=CONFIG[d];self.parts=extract(d)
        self.sx=1 if d in ['E','N'] else -1;self.sy=1 if d in ['E','S'] else -1
        self.near=self.cfg['near'];self.far='L' if self.near=='R' else 'R';self.skins={};self.boots={};self.bind={}
        self.hips={self.near:vec([274.24 if d in ['S','N'] else 237.76,294.16]),self.far:vec([234.24 if d in ['S','N'] else 277.76,283.12])}
        for rank,side in [('near',self.near),('far',self.far)]:
            name=rank+'_leg';box=self.cfg['boxes'][name]
            p=[vec(p)-box[:2] for p in self.cfg[name]];self.bind[side]=p
            im=self.parts[name];cut=self.cfg['boot_cut'][0 if rank=='near' else 1]-box[1]
            pixels=np.array(im);yy,xx=np.indices(pixels.shape[:2]);boot_mask=yy>=cut
            if d=='W':
                # The receding toe is above the cuff: a horizontal split would
                # accidentally leave a second toe attached to the trouser.
                edge=np.interp(xx+box[0],[0,235,247,300,512] if rank=='near' else [512,734,749,800,1024],
                               [700,700,748,746,746] if rank=='near' else [715,715,761,756,756])-box[1]
                boot_mask=yy>=edge
            # Retain an overlapping tongue of the existing dark trouser inside
            # the cuff. The two pieces rotate differently at the ankle.
            trouser_overlap=(np.abs(xx-p[2][0])<40)&(yy<p[2][1]+8)&(yy>p[1][1])&(pixels[:,:,:3].max(axis=2)<125)
            cloth=pixels.copy();cloth[boot_mask&~trouser_overlap]=0
            boot=pixels.copy();boot[~boot_mask]=0;self.boots[side]=Image.fromarray(boot)
            self.skins[side]=Skin(Image.fromarray(cloth),*p[:3],.285 if rank=='near' else .273,53)
            name=rank+'_arm';box=self.cfg['boxes'][name];points=[vec(p)-box[:2] for p in self.cfg[name]]
            self.skins[side+'_arm']=Skin(self.parts[name],*points,.265 if rank=='near' else .25,44)
        self.boot_maps={}
        for side in [self.near,self.far]:
            depth=1. if side==self.near else .95;p=self.bind[side]
            sole=p[5]-p[4];target=vec([self.sx,self.sy*.5])
            angle=math.atan2(target[1],target[0])-math.atan2(sole[1],sole[0])
            # Only a constant uniform scale and rotation bind the boot drawing.
            # Its shape is preserved; animated deformation is never applied.
            self.boot_maps[side]=(.30 if d=='W' else .32)*depth*rot(angle)
        # A directional ground pivot is measured once from the flat soles.
        centers=[]
        for side in [self.near,self.far]:
            depth=1. if side==self.near else .95;p=self.bind[side]
            centers.append(self.hips[side]+[0,109*depth]+self.boot_maps[side]@((p[4]+p[5])*.5-p[3]))
        self.ground_pivot=np.mean(centers,axis=0)
    def project(self,f,down):return vec([self.sx*.85*f,self.sy*.425*f+down])
    def knee(self,h,a,depth):
        delta=a-h;target=vec([delta[0]/(.85*self.sx),delta[1]-self.sy*.5*delta[0]/self.sx]);length=np.linalg.norm(target)
        u,v=U*depth,V*depth;assert abs(v-u)<length<u+v,(self.d,length,u+v)
        axis=target/length;along=(u*u-v*v+length*length)/(2*length);height=math.sqrt(max(0,u*u-along*along))
        local=axis*along+vec([axis[1],-axis[0]])*height
        return h+self.project(*local),length
    def render(self,t):
        shift=vec([.8*math.sin(math.tau*t),1.6*math.cos(2*math.tau*t)])
        body_angle=math.radians(.8)*math.sin(math.tau*t);legs={};motion={};arms={}
        for side in [self.far,self.near]:
            depth=1 if side==self.near else .95;q=(t+(.5 if side=='L' else 0))%1
            forward,lift,angle,contact=trajectory(q);angle*=self.sx;r=rot(angle);boot_map=self.boot_maps[side];p=self.bind[side]
            heel=boot_map@(p[4]-p[3]);toe=boot_map@(p[5]-p[3])
            if contact=='heel':roll=(np.eye(2)-r)@heel
            elif contact=='toe':roll=(np.eye(2)-r)@toe
            elif contact=='swing':
                s=(q-.60)/.4;roll=(1-ease(s/.3))*((np.eye(2)-r)@toe)+ease((s-.7)/.3)*((np.eye(2)-r)@heel)
            else:roll=vec([0,0])
            hip=self.hips[side]+shift;ankle=self.hips[side]+self.project(forward,109*depth-lift)+roll
            knee,reach=self.knee(hip,ankle,depth);cuff=ankle+r@boot_map@(p[2]-p[3])
            layer=self.skins[side].draw(hip,knee,cuff)
            layer.alpha_composite(affine(self.boots[side],r@boot_map,p[3],ankle));legs[side]=layer
            rank='near' if side==self.near else 'far'
            shoulder=BASE+rot(body_angle)@((vec(self.cfg['shoulders'][rank])-self.cfg['core_anchor'])*self.cfg['core_scale'])+shift
            swing=.18*math.cos(math.tau*(q-.025));bend=.035+.105*(1-math.cos(math.tau*q))*.5
            elbow=shoulder+self.project(-55*math.sin(swing),55*math.cos(swing))
            wrist=elbow+self.project(-47*math.sin(swing-bend),47*math.cos(swing-bend))
            arms[side]=self.skins[side+'_arm'].draw(shoulder,elbow,wrist)
            motion[side]={'phase':q,'contact':contact,'hip':hip.tolist(),'knee':knee.tolist(),'ankle':ankle.tolist(),'cuff':cuff.tolist(),'heel':(ankle+r@heel).tolist(),'toe':(ankle+r@toe).tolist(),'reach':reach,'swing_lift':lift,'boot_angle':angle,'shoulder':shoulder.tolist(),'elbow':elbow.tolist(),'wrist':wrist.tolist()}
        frame=Image.new('RGBA',(W,W))
        frame.alpha_composite(arms[self.far])
        for side in [self.far,self.near]:frame.alpha_composite(legs[side])
        frame.alpha_composite(affine(self.parts['core'],self.cfg['core_scale']*rot(body_angle),self.cfg['core_anchor'],BASE+shift))
        frame.alpha_composite(arms[self.near])
        return frame,{'index':round(t*N)%N,'phase':t,'legs':motion,'bbox':frame.getbbox(),'ground_pivot':self.ground_pivot.tolist()}

def package_direction(d,frames,motion,pivot):
    folder=OUT/'frames'/d;folder.mkdir(parents=True,exist_ok=True)
    for i,frame in enumerate(frames):frame.save(folder/f'{i:02}.png')
    atlas=Image.new('RGBA',(W*8,W*6))
    for i,frame in enumerate(frames):atlas.paste(frame,(i%8*W,i//8*W))
    atlas.save(OUT/f'{d}_atlas.png')
    holds=[round((i+1)*DURATION/N)-round(i*DURATION/N) for i in range(N)]
    frames[0].save(OUT/f'{d}_walk.webp',save_all=True,append_images=frames[1:],duration=holds,loop=0,lossless=True)
    frames[0].save(OUT/f'{d}_walk.png',save_all=True,append_images=frames[1:],duration=holds,loop=0,disposal=0,blend=0)
    (OUT/f'{d}_motion.json').write_text(json.dumps(motion,indent=2))
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18);board=Image.new('RGB',(1536,768),'#243b40')
    for n,i in enumerate(range(0,N,6)):
        im=frames[i].resize((384,384));x=n%4*384;y=n//4*384;board.paste(im,(x,y),im)
        ImageDraw.Draw(board).text((x+15,y+12),f'{d} / {i:02}',fill='#eadfbd',font=font)
    board.save(OUT/f'{d}_poses.jpg',quality=94)
    return {'label':{'E':'Bas droite','S':'Bas gauche','N':'Haut droite','W':'Haut gauche'}[d],
            'frames':[f'frames/{d}/{i:02}.png' for i in range(N)],'atlas':f'{d}_atlas.png',
            'pivot':list(pivot),'stride':[59.5*(1 if d in ['E','N'] else -1),29.75*(1 if d in ['E','S'] else -1)]}

def main():
    selected=[d for d in sys.argv[1:] if d in ['E','S','N','W']] or ['E','S','N','W']
    preview='--preview' in sys.argv;views={}
    for d in selected:
        if d=='E':
            old=ROOT/'artifacts/spine_trial/veilleur_walk_E_v5'
            frames=[Image.open(old/'frames'/f'{i:02}.png').convert('RGBA') for i in range(N)]
            motion=json.loads((ROOT/'art/source/characters/achilles/veilleur_walk_E_v5/motion.json').read_text())
            pivot=[266.48,416.915]
        else:
            renderer=Renderer(d);frames=[];motion=[];pivot=renderer.ground_pivot.tolist()
            for i in (range(0,N,6) if preview else range(N)):
                im,m=renderer.render(i/N);assert im.getbbox() and min(im.getbbox()[:2])>2 and max(im.getbbox()[2:])<510,(d,i,im.getbbox())
                frames.append(im);motion.append(m)
                if i%12==0:print('RENDER',d,i,flush=True)
            (SRC/f'{d}_bindings.json').write_text(json.dumps(CONFIG[d],indent=2))
        if preview and d!='E':
            board=Image.new('RGB',(W*4,W*2),'#243b40');draw=ImageDraw.Draw(board)
            for j,im in enumerate(frames):board.paste(im,(j%4*W,j//4*W),im);draw.text((j%4*W+15,j//4*W+15),f'{d} phase {j*6}',fill='white')
            board.save(OUT/f'{d}_preview.jpg',quality=94)
        else:views[d]=package_direction(d,frames,motion,pivot)
        print('READY',d,'pivot',pivot,flush=True)
    if not preview:
        path=OUT/'walk_review.json'
        previous=json.loads(path.read_text()) if path.exists() else {'views':{}}
        previous['views'].update(views)
        data={'name':'Veilleur — marche quatre vues','order':['E','S','N','W'],'canvas':[W,W],'pivot':PIVOT.tolist(),'frame_count':N,'duration':.8,'display_scale':.30,'views':previous['views'],'artistic_approval':False,'notes':['E: original V5 pixels, corrected runtime ground anchor.','S/N/W: new directional drawings; shared V5 contacts, new skin bindings.','No mirrors. Walk only; turns are instant and rest holds the last pose.']}
        path.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
        shutil.copyfile(ROOT/'asset/map/painted/room_01_forest/forest_background_v2.webp',OUT/'map.webp')
if __name__=='__main__':main()
