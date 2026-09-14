"""Editable raster cutout walk. Artwork from ImageGen, contact math from our guide.

No Dofus pixels are used. Each part stays identical over the cycle. Projected
heel/toe constraints, joint motion and art attachment data remain editable.
"""
from pathlib import Path
import json, math, sys, shutil, zipfile, io
import numpy as np
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[2]
NATURAL='--natural' in sys.argv
VERSION='passe_rive_walk_unarmed_v2' if NATURAL else 'passe_rive_walk_unarmed_v1'
SRC=ROOT/'art/source/characters/achilles'/VERSION
ART=ROOT/'art/source/characters/achilles/passe_rive_walk_unarmed_v1'
OUT=ROOT/'artifacts/spine_trial'/VERSION
sys.path.insert(0,str(ROOT/'tools/passe_rive_motion'))
import walk_model as contacts

TAU=math.tau
CFG={'duration':0.8,'frames':48,'stride':0.82,'stance':0.60,'scale':260,
     'pivot':[384,662],'canvas':[768,768],'thigh':0.50,'shin':0.48,
     'pelvis_height':0.955,'bob':0.020,'arm_swing':0.23,'foot_lift':0.12}
cfg_path=SRC/'motion.json'
if cfg_path.exists():CFG.update(json.loads(cfg_path.read_text()))
else:cfg_path.write_text(json.dumps(CFG,indent=2))
contacts.STRIDE=CFG['stride'];contacts.DURATION=CFG['duration']
contacts.STANCE=CFG['stance'];contacts.HEEL=-.08;contacts.TOE=.15
contacts.ANKLE_Z=.105
if NATURAL:
    import natural_motion as contacts
    contacts.configure(CFG)

def v(x):return np.array(x,dtype=float)
def project(p,d):
    x,f,z=p;s=CFG['scale'];sx=1 if d in ['E','N'] else -1
    sy=1 if d in ['E','S'] else -1
    # Anatomical right changes screen side between front and back views.
    return v(CFG['pivot'])+s*v([(sx*f-sy*x)*.70710678,(sy*f+sx*x)*.35355339-z*.8660254])

def knee(hip,ankle):
    L1,L2=CFG['thigh'],CFG['shin'];delta=ankle-hip;distance=np.linalg.norm(delta)
    assert distance<L1+L2, f'Unreachable leg: {distance}'
    along=delta/distance;pole=v([0,1,0]);bend=pole-along*np.dot(pole,along)
    bend/=np.linalg.norm(bend);length=(L1*L1-L2*L2+distance*distance)/(2*distance)
    return hip+along*length+bend*math.sqrt(max(0,L1*L1-length*length))

def pose(t,d):
    if NATURAL:return contacts.pose(t,d,knee)
    a=TAU*t;pel=v([.023*math.sin(a),.016,CFG['pelvis_height']-CFG['bob']*math.cos(2*a-.6)])
    joints={};feet={}
    for side,sign in [('R',1),('L',-1)]:
        f=contacts.foot(t,side);ankle=v(f['ankle']);ankle[0]=sign*.100
        f['ankle']=ankle.tolist()
        for key in ['heel','toe']:f[key][0]=ankle[0]
        hip=pel+v([sign*.105,sign*.018*math.cos(a),0])
        k=knee(hip,ankle)
        shoulder=pel+v([sign*.18,.03-sign*.018*math.cos(a),.407])
        swing=sign*math.cos(a-.18)
        elbow=shoulder+v([sign*.025,CFG['arm_swing']*.53*swing,-.274+.012*swing])
        wrist=elbow+v([sign*.004,CFG['arm_swing']*.48*swing+.025,-.222+.022*abs(swing)])
        joints[side]={'hip':hip,'knee':k,'ankle':ankle,'shoulder':shoulder,'elbow':elbow,'wrist':wrist}
        feet[side]=f
    return {'pelvis':pel,'head':pel+v([0,.055,.473]),'joints':joints,'feet':feet}

# Source anchors are normalized in the extracted drawing, not atlas cells.
DEFAULT={
 '4':{'a':[.66,.14],'b':[.25,.94],'width':.122},
 '5':{'a':[.69,.09],'b':[.23,.78],'width':.105},
 '6':{'a':[.35,.13],'b':[.75,.94],'width':.113},
 '7':{'a':[.29,.09],'b':[.69,.78],'width':.100},
 '8':{'a':[.36,.10],'b':[.70,.91],'width':.147},
 '9':{'a':[.48,.09],'b':[.57,.92],'width':.115},
 '12':{'a':[.64,.10],'b':[.30,.91],'width':.140},
 '13':{'a':[.55,.08],'b':[.36,.92],'width':.111},
 '10':{'ankle':[.28,.21],'heel':[.10,.68],'toe':[.91,.92]},
 '11':{'ankle':[.38,.18],'heel':[.17,.61],'toe':[.91,.89]},
 '14':{'ankle':[.27,.22],'heel':[.12,.69],'toe':[.89,.92]},
 'head':{'anchor':[.52,.80],'height':.43},
 'torso':{'anchor':[.49,.92],'width':.410,'height':.472},
 'pelvis':{'anchor':[.50,.17],'width':.383,'height':.281},
 'cape':{'anchor':[.25,.05],'width':.225,'height':.61},
 'sash':{'anchor':[.30,.035],'width':.100,'height':.48}}

class Renderer:
    def __init__(self,d):
        self.d=d;self.parts=[Image.open(ART/'parts'/d/f'{i:02}.png').convert('RGBA') for i in range(16)]
        # N atlas cell 14 was drawn pointing the wrong way. Reuse the correctly
        # drawn rear sandal for both feet; this is an explicit art substitution.
        if d=='N':self.parts[14]=self.parts[10]
        path=SRC/f'{d}_attachments.json'
        if NATURAL and not path.exists():shutil.copy2(ART/f'{d}_attachments.json',path)
        self.att=json.loads(path.read_text()) if path.exists() else DEFAULT
        if not path.exists():path.write_text(json.dumps(self.att,indent=2))
        self.layers=[]
    def point(self,p):return project(p,self.d)
    def affine(self,index,src,dst,name):
        im=self.parts[index];src=np.array(src)*v(im.size)
        matrix=np.column_stack((src,np.ones(3)));target=np.array(dst)
        # Forward affine source -> destination; Pillow asks for inverse.
        ab=np.linalg.solve(matrix,target).T;A=np.eye(3);A[:2]=ab
        inv=np.linalg.inv(A)[:2].ravel()
        layer=im.transform(tuple(CFG['canvas']),Image.Transform.AFFINE,inv,Image.Resampling.BICUBIC)
        self.canvas.alpha_composite(layer);self.layers.append((name,layer))
    def bone(self,index,A,B):
        conf=self.att[str(index)];a=v(conf['a']);b=v(conf['b']);im=self.parts[index]
        av=a*v(im.size);bv=b*v(im.size);u=bv-av
        normal=v([u[1],-u[0]]);normal/=np.linalg.norm(normal)
        sa=v(A);sb=v(B);normal2=v([(sb-sa)[1],-(sb-sa)[0]]);normal2/=np.linalg.norm(normal2)
        # Map the art's width independently of joint length: no volume breathing.
        third=(av+normal*im.width)/v(im.size)
        self.affine(index,[a,b,third],[sa,sb,sa+normal2*conf['width']*CFG['scale']],f'part_{index}')
    def piece(self,index,pos,name,rotation=0,shear=0):
        conf=self.att[name];im=self.parts[index];anchor=v(conf['anchor']);s=CFG['scale']
        h=conf['height']*s*.8660254;w=conf.get('width',h/s*im.width/im.height)*s
        c,sn=math.cos(rotation),math.sin(rotation);M=np.array([[c,-sn],[sn,c]])@np.array([[w,shear*h],[0,h]])
        dst=[v(pos)+M@(v(p)-anchor) for p in [[0,0],[1,0],[0,1]]]
        self.affine(index,[[0,0],[1,0],[0,1]],dst,name)
    def leg(self,side,p):
        j=p['joints'][side];f=p['feet'][side];indices=(8,9,10) if side=='R' else (12,13,14)
        idx=indices[2];conf=self.att[str(idx)]
        self.affine(idx,[conf['ankle'],conf['heel'],conf['toe']],
                    [self.point(f[k]) for k in ['ankle','heel','toe']],f'{side}_foot')
        self.bone(indices[1],self.point(j['knee']),self.point(j['ankle']))
        self.bone(indices[0],self.point(j['hip']),self.point(j['knee']))
    def arm(self,side,p):
        j=p['joints'][side];indices=(4,5) if side=='R' else (6,7)
        self.bone(indices[1],self.point(j['elbow']),self.point(j['wrist']))
        self.bone(indices[0],self.point(j['shoulder']),self.point(j['elbow']))
    def render(self,t):
        self.canvas=Image.new('RGBA',tuple(CFG['canvas']));self.layers=[]
        p=pose(t,self.d);a=TAU*t;back=self.d in ['N','W'];near='R' if self.d in ['E','N'] else 'L';far='L' if near=='R' else 'R'
        self.arm(far,p)
        # Cape has phase lag; its hinge remains attached to the pelvis.
        cape=self.point(p['pelvis']+v([-.13,-.06,-.035]))
        cloth=CFG.get('cape_swing',.035)
        if not back:self.piece(3,cape,'cape',cloth*math.sin(a-.7),cloth*math.sin(a-.9))
        self.leg(far,p);self.leg(near,p)
        if back:self.piece(3,cape,'cape',cloth*math.sin(a-.7),cloth*math.sin(a-.9))
        self.piece(2,self.point(p['pelvis']),'pelvis',CFG.get('pelvis_roll',.025)*math.sin(a))
        if not back:self.piece(15,self.point(p['pelvis']+v([.11,.10,0])),'sash',-CFG.get('sash_swing',.07)*math.sin(a-.6),cloth*math.sin(a-1))
        self.piece(1,self.point(p['pelvis']+v([0,.025,.055])),'torso',-CFG.get('torso_roll',.024)*math.sin(a),CFG.get('torso_shear',.018)*math.cos(a))
        self.arm(near,p)
        self.piece(0,self.point(p['head']),'head',-CFG.get('head_roll',.009)*math.sin(a-.3))
        return self.canvas,p

def save_ora(renderer,d):
    renderer.render(.125);from xml.etree.ElementTree import Element,SubElement,tostring
    root=Element('image',{'w':'768','h':'768','name':f'Passe-rive {d} — pièces éditables'})
    stack=SubElement(root,'stack')
    with zipfile.ZipFile(SRC/f'{d}_editable.ora','w') as z:
        z.writestr('mimetype','image/openraster')
        for i,(name,layer) in reversed(list(enumerate(renderer.layers))):
            f=f'data/layer{i}.png';buf=io.BytesIO();layer.save(buf,format='PNG');z.writestr(f,buf.getvalue())
            SubElement(stack,'layer',{'name':name,'src':f,'opacity':'1.0','visibility':'visible','composite-op':'svg:src-over','x':'0','y':'0'})
        z.writestr('stack.xml',tostring(root));buf=io.BytesIO();renderer.canvas.save(buf,format='PNG');z.writestr('mergedimage.png',buf.getvalue())

def build(d,only_preview=False):
    r=Renderer(d);folder=OUT/'frames'/d;folder.mkdir(parents=True,exist_ok=True)
    frames=[];audit=[];count=CFG['frames']
    sample=[round(i*count/8) for i in range(8)]
    for i in (sample if only_preview else range(count)):
        im,p=r.render(i/count);bbox=im.getbbox()
        assert bbox and min(bbox[:2])>3 and max(bbox[2:])<765, f'Clip {d}/{i}: {bbox}'
        im.save(folder/f'{i:02}.png');frames.append(im)
        audit.append({'frame':i,'bounds':bbox,'feet':{s:{'phase':f['phase'],'contact':f['contact'],
                    'heel':project(f['heel'],d).tolist(),'toe':project(f['toe'],d).tolist()} for s,f in p['feet'].items()}})
    board=Image.new('RGB',(1536,1024),'#344444');draw=ImageDraw.Draw(board)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
    for j,i in enumerate(sample):
        im=Image.open(folder/f'{i:02}.png').resize((461,461))
        # Constant framing, no per-frame recentering.
        x=j%4*384-38;y=j//4*512+38;board.paste(im,(x,y),im)
        draw.text((j%4*384+14,j//4*512+15),f'{d}  {i:02}/{count}',fill='#f0ebcf',font=font)
    board.save(OUT/f'{d}_poses.jpg',quality=94)
    (OUT/f'{d}_audit_preview.json' if only_preview else OUT/f'{d}_audit.json').write_text(json.dumps(audit,indent=2))
    if not only_preview:
        atlas=Image.new('RGBA',(768*8,768*math.ceil(count/8)))
        for i,im in enumerate(frames):atlas.paste(im,(i%8*768,i//8*768))
        atlas.save(OUT/f'{d}_walk.png')
        save_ora(r,d)
        gif=[im.resize((384,384)) for im in frames]
        durations=[round((i+1)*CFG['duration']*1000/count)-round(i*CFG['duration']*1000/count) for i in range(count)]
        gif[0].save(OUT/f'{d}_walk.webp',save_all=True,append_images=gif[1:],duration=durations,loop=0,lossless=True)
    print(json.dumps({'direction':d,'frames':len(frames),'contact_guide':contacts.validate(),'status':'visual_review_required'}),flush=True)

def package():
    dirs=[d for d in ['E','S','N','W'] if (OUT/f'{d}_walk.png').exists()]
    labels={'E':'Bas droite','S':'Bas gauche','N':'Haut droite','W':'Haut gauche'}
    views={d:{'label':labels[d],'atlas':f'{d}_walk.png','frames':[f'frames/{d}/{i:02}.png' for i in range(CFG['frames'])],
             'stride':(project([0,CFG['stride'],0],d)-project([0,0,0],d)).tolist()} for d in dirs}
    data={'order':dirs,'duration':CFG['duration'],'frame_count':CFG['frames'],'pivot':CFG['pivot'],'canvas':CFG['canvas'],
          'views':views,'artistic_approval':False,'method':'stable raster cutout, projected heel/toe contacts, editable joint and secondary curves'}
    (OUT/'walk_review.json').write_text(json.dumps(data,indent=2))
    shutil.copy2(ROOT/'asset/map/painted/room_01_forest/forest_background_v2.webp',OUT/'map.webp')
    html=Path(__file__).with_name('review.html')
    if html.exists():shutil.copy2(html,OUT/'review.html')

if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    directions=[arg for arg in sys.argv[1:] if arg in ['E','S','N','W']]
    build(directions[0] if directions else 'E','--preview' in sys.argv)
    if '--preview' not in sys.argv:package()
