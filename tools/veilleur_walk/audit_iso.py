"""Validate delivered pixels, source preservation, support and runtime atlases."""
from pathlib import Path
import json,hashlib,math
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'artifacts/spine_trial/veilleur_walk_iso_v1'
ASSETS=ROOT/'assets/characters/Achilles/veilleur_walk_iso_v1';data=json.loads((OUT/'walk_review.json').read_text(encoding='utf8'))
checks=[];details={}
def check(name,value,detail=None):
    checks.append({'name':name,'passed':bool(value),'detail':detail})
    if not value:print('FAIL',name,detail,flush=True)
for d in data['order']:
    frames=[np.array(Image.open(OUT/f).convert('RGBA')) for f in data['views'][d]['frames']]
    motion=json.loads((OUT/f'{d}_motion.json').read_text());stride=np.array(data['views'][d]['stride'])
    check(d+' 48 distinct RGBA frames',len(frames)==48 and len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames})==48)
    check(d+' canvas and unclipped alpha',all(f.shape==(512,512,4) and not np.any(f[0,:,3]) and not np.any(f[-1,:,3]) and not np.any(f[:,0,3]) and not np.any(f[:,-1,3]) for f in frames))
    if d=='E':check('Original E V5 pixel identity',all(np.array_equal(f,np.array(Image.open(ROOT/f'artifacts/spine_trial/veilleur_walk_E_v5/frames/{i:02}.png'))) for i,f in enumerate(frames)))
    atlas=Image.open(ASSETS/f'{d}_atlas.png').convert('RGBA')
    check(d+' imported atlas matches all 48 frames',all(np.array_equal(f,np.array(atlas.crop((i%8*512,i//8*512,(i%8+1)*512,(i//8+1)*512)))) for i,f in enumerate(frames)))
    for suffix in ['png','webp']:
        clip=Image.open(OUT/f'{d}_walk.{suffix}');ms=0;match=True
        check(d+' '+suffix+' 48 frames',clip.n_frames==48)
        for i in range(clip.n_frames):
            clip.seek(i);px=np.array(clip.convert('RGBA'));visible=np.maximum(px[:,:,3],frames[i][:,:,3])>0
            match=match and np.array_equal(px[visible],frames[i][visible]);ms+=clip.info['duration']
        check(d+' '+suffix+' exact 800 ms and visible pixels',ms==800 and match,{'duration_ms':ms})
    contact_reports={};coverage=0;missing=[]
    for side in 'LR':
        for contact,point in [('heel','heel'),('flat','toe'),('toe','toe')]:
            indices=[i for i,p in enumerate(motion) if p['legs'][side]['contact']==contact]
            world=np.array([np.array(motion[i]['legs'][side][point])+stride*(i/48+(1 if side=='L' and i<24 else 0)) for i in indices])
            span=float(np.linalg.norm(world[:,None]-world[None,:],axis=2).max())
            contact_reports[side+'_'+contact]=span
        for i,f in enumerate(frames):
            for joint in ['knee','cuff','ankle']:
                x,y=np.round(motion[i]['legs'][side][joint]).astype(int)
                coverage+=1
                if f[max(0,y-3):y+4,max(0,x-3):x+4,3].max()<64:missing.append([i,side,joint])
    check(d+' fixed support landmarks in world',max(contact_reports.values())<1e-6,contact_reports)
    check(d+' visible knee/cuff/ankle coverage',not missing,{'sampled':coverage,'missing':missing})
    # Independently track a patch in the actual composited near boot pixels.
    near='R' if d in ['E','N'] else 'L';point='toe' if d in ['E','S'] else 'heel'
    indices=[i for i,p in enumerate(motion) if p['legs'][near]['contact']=='flat']
    world_images=[]
    for i in indices:
        rgba=frames[i];a=rgba[:,:,3:4]/255;rgb=rgba[:,:,:3]*a+np.array([36,59,64])*(1-a)
        translation=stride*(i/48+(1 if near=='L' and i<24 else 0))
        world_images.append(np.array(Image.fromarray(np.uint8(rgb)).transform((512,512),Image.Transform.AFFINE,(1,0,-translation[0],0,1,-translation[1]),Image.Resampling.BILINEAR,fillcolor=(36,59,64))))
    i=indices[0];translation=stride*(i/48+(1 if near=='L' and i<24 else 0))
    # A 21 px patch inside a plain gold band produced ambiguous matches even
    # on the unchanged E reference. Include its curved toe outline (35 px),
    # exactly as the independent E V5 audit does.
    center=np.array(motion[i]['legs'][near][point])+translation+np.array([(-10 if d=='E' else 10 if d=='S' else 0),-14 if d in ['E','S'] else -11])
    x,y=np.round(center).astype(int);radius=17 if d in ['E','S'] else 10;template=world_images[0][y-radius:y+radius+1,x-radius:x+radius+1].astype(float)
    offsets=[]
    for im in world_images:
        candidates=[]
        for dy in range(-3,4):
            for dx in range(-3,4):
                patch=im[y-radius+dy:y+radius+dy+1,x-radius+dx:x+radius+dx+1].astype(float)
                candidates.append((float(np.mean((patch-template)**2)),dx,dy))
        score,dx,dy=min(candidates);offsets.append([dx,dy,score])
    drift=max(math.hypot(dx,dy) for dx,dy,_ in offsets)
    check(d+' rendered near sole during flat support',drift<=1.5,{'tested_frames':indices,'max_offset_output_px':drift,'max_at_game_scale':drift*.3,'patch_offsets':offsets})
    Image.fromarray(world_images[0]).crop((x-20,y-20,x+21,y+21)).resize((246,246)).save(OUT/f'{d}_tracked_sole.png')
    prem=[np.concatenate([f[:,:,:3]/255*(f[:,:,3:4]/255),f[:,:,3:4]/255],axis=2) for f in frames]
    diffs=[float(np.mean(np.abs(prem[(i+1)%48]-prem[i]))) for i in range(48)]
    check(d+' loop seam within internal frame changes',diffs[-1]<=max(diffs[:-1])*1.35,{'wrap':diffs[-1],'max_internal':max(diffs[:-1])})
    components=[]
    for f in frames:
        labels,n=ndi.label(f[:,:,3]>128);areas=np.bincount(labels.ravel())[1:];components.append(int(areas.sum()-areas.max()))
    details[d]={'max_pixels_outside_largest_component':max(components),'alpha_height_range':[min(Image.fromarray(f).getbbox()[3]-Image.fromarray(f).getbbox()[1] for f in frames),max(Image.fromarray(f).getbbox()[3]-Image.fromarray(f).getbbox()[1] for f in frames)]}
lock=json.loads((ROOT/'art/source/characters/achilles/veilleur_walk_E_v5/source_lock.json').read_text())
check('Accepted canonical pieces unchanged',all(hashlib.sha256((ROOT/'art/source/characters/achilles/veilleur_proportions_v1'/f'{name}.png').read_bytes()).hexdigest()==digest for name,digest in lock['source_piece_sha256'].items()))
result={'passed':all(x['passed'] for x in checks),'checks':checks,'observations':details,'artistic_approval':False,'limits':['Sole tracking tests the visible near boot during flat support only.','Coverage does not prove anatomical or artistic quality.','All views are drawn; no mirrored directions.']}
(OUT/'audit_report.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'passed':result['passed'],'checks':len(checks),'failed':[x['name'] for x in checks if not x['passed']],'details':details}))
raise SystemExit(0 if result['passed'] else 1)
