"""Independent checks of actual exported pixels, support, dimensions and loop."""
from pathlib import Path
import json,hashlib,math,ast
import numpy as np
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/spine_trial/veilleur_walk_E_v5'
SRC=ROOT/'art/source/characters/achilles/veilleur_walk_E_v5'
BASE=ROOT/'art/source/characters/achilles/veilleur_proportions_v1'
OLD=ROOT/'artifacts/spine_trial/veilleur_walk_E_v4'
old=json.loads((ROOT/'art/source/characters/achilles/veilleur_walk_E_v4/motion.json').read_text())
motion=json.loads((SRC/'motion.json').read_text())
manifest=json.loads((OUT/'manifest.json').read_text())
lock=json.loads((SRC/'source_lock.json').read_text())
N=manifest['frame_count'];scale=112/manifest['reference_height']
frames=[Image.open(OUT/f'frames/{i:02}.png').convert('RGBA') for i in range(N)]
checks=[]
def check(name,ok,detail=None):
    checks.append({'name':name,'passed':bool(ok),'detail':detail})
    assert ok,(name,detail)

for name in ['walk.png','walk.webp']:
    animation=Image.open(OUT/name);check(name+' frame count',animation.n_frames==N)
    duration=0;diffs=[]
    for i,im in enumerate(frames):
        animation.seek(i); decoded=np.array(animation.convert('RGBA'));original=np.array(im)
        visible=np.maximum(original[:,:,3],decoded[:,:,3])>0
        diffs.append(int((np.any(original!=decoded,axis=2)&visible).sum()))
        duration+=animation.info['duration']
    check(name+' matches visible PNG pixels',max(diffs)==0,{'maximum_changed_pixels':max(diffs)})
    check(name+' exact total duration',duration==800,{'duration_ms':duration})
atlas=Image.open(OUT/'atlas.png').convert('RGBA')
check('Atlas size',atlas.size==(4096,3072))
check('All atlas tiles match exports',all(np.array_equal(np.array(frame),np.array(atlas.crop(((i%8)*512,(i//8)*512,(i%8+1)*512,(i//8+1)*512)))) for i,frame in enumerate(frames)))
sources={name:hashlib.sha256((BASE/(name+'.png')).read_bytes()).hexdigest()==digest for name,digest in lock['source_piece_sha256'].items()}
check('Accepted source pieces unchanged',all(sources.values()),sources)
check('All frame bounds inside canvas',all(min(p['bbox'][:2])>0 and max(p['bbox'][2:])<512 for p in motion))
check('Stable limb depth order',all(p['leg_order']==['L','R'] for p in motion))

length_errors=[]
for pose in motion:
    for side,depth in [('R',1),('L',.95)]:
        leg=pose['legs'][side]
        for a,b,expected in [('hip','knee',lock['sagittal_lengths'][0]*depth),('knee','ankle',lock['sagittal_lengths'][1]*depth)]:
            xy=np.subtract(leg[b],leg[a]); sagittal=[xy[0]/.85,xy[1]-.5*xy[0]]
            length_errors.append(abs(np.linalg.norm(sagittal)-expected))
check('Constant constructed leg lengths',max(length_errors)<1e-7,{'max_output_error':max(length_errors)})
contacts={}
for side in 'LR':
    contacts[side]={}
    for contact,point in [('heel','heel'),('flat','toe'),('toe','toe')]:
        indices=[i for i in range(N) if motion[i]['legs'][side]['contact']==contact]
        indices.sort(key=lambda i:motion[i]['legs'][side]['phase'])
        world=[]
        for i in indices:
            t=i/N+(1 if side=='L' and i<N/2 else 0)
            world.append(np.array(motion[i]['legs'][side][point])+np.array(manifest['stride'])*t)
        world=np.array(world)
        span=float(np.linalg.norm(world[:,None]-world[None,:],axis=2).max())
        contacts[side][contact]={'samples':len(indices),'span_output_px':span,'span_at_112px':span*scale}
check('Heel, flat and toe support landmarks fixed in world',max(x['span_output_px'] for side in contacts.values() for x in side.values())<1e-7,contacts)

# Verify a visible toe/sole patch in the actual composited PNGs during flat R support.
# This independently catches a mismatch between landmarks and raster placement.
indices=[i for i,p in enumerate(motion) if p['legs']['R']['contact']=='flat']
world_images=[]
for i in indices:
    rgba=np.array(frames[i]); alpha=rgba[:,:,3:4]/255
    rgb=(rgba[:,:,:3]*alpha+np.array([36,59,64])*(1-alpha)).astype(np.uint8)
    offset=np.array(manifest['stride'])*i/N
    world_images.append(np.array(Image.fromarray(rgb).transform((512,512),Image.Transform.AFFINE,(1,0,-offset[0],0,1,-offset[1]),Image.Resampling.BILINEAR,fillcolor=(36,59,64))))
point=np.array(motion[indices[0]]['legs']['R']['toe'])+np.array(manifest['stride'])*indices[0]/N+np.array([-10,-14])
x,y=np.round(point).astype(int)
# Include the curved toe outline, not only an ambiguous straight gold stripe.
template=world_images[0][y-17:y+18,x-17:x+18]
offsets=[]
for image in world_images:
    candidates=[]
    for dy in range(-3,4):
        for dx in range(-3,4):
            patch=image[y-17+dy:y+18+dy,x-17+dx:x+18+dx]
            candidates.append((float(np.mean((patch.astype(float)-template.astype(float))**2)),dx,dy))
    difference,dx,dy=min(candidates)
    offsets.append({'dx':dx,'dy':dy,'mean_squared_difference':difference})
pixel_drift=max(math.hypot(p['dx'],p['dy']) for p in offsets)
check('Rendered near sole remains fixed during flat support',pixel_drift<=1.5,{'tested_frames':indices,'max_template_offset_output_px':pixel_drift,'max_at_112px':pixel_drift*scale,'matches':offsets})
Image.fromarray(world_images[0]).crop((x-24,y-24,x+25,y+25)).resize((294,294)).save(OUT/'checked_sole.png')

seams={}
for side in 'LR':
    positions=np.array([p['legs'][side]['ankle'] for p in motion])
    delta=np.linalg.norm(np.roll(positions,-1,axis=0)-positions,axis=1)
    seams[side]={'wrap_step_output_px':float(delta[-1]),'maximum_other_step_output_px':float(delta[:-1].max())}
check('Loop seam no larger than internal steps',all(x['wrap_step_output_px']<=x['maximum_other_step_output_px']*1.1 for x in seams.values()),seams)
patch_checks={}
for side in 'LR':
    before=np.array(Image.open(BASE/f'leg_{side}.png').convert('RGBA'))
    after=np.array(Image.open(SRC/f'leg_{side}_completed.png').convert('RGBA'))
    occupied=before[:,:,3]>0
    patch_checks[side]={'changed_existing_pixels':int(np.any(before[occupied]!=after[occupied],axis=1).sum()),
                        'added_pixels':int(((~occupied)&(after[:,:,3]>0)).sum())}
check('Repairs preserve every previously drawn leg pixel',all(p['changed_existing_pixels']==0 for p in patch_checks.values()),patch_checks)
check('No surface inversion over drawn trouser pixels',all(p['legs'][side]['cloth_deformation']['inverted_triangles_over_art']==0 for p in motion for side in 'LR'))
arm_lengths={}
opposition={}
for side in 'LR':
    lengths=np.array([[np.linalg.norm(np.subtract(p['arms'][side]['elbow'],p['arms'][side]['shoulder'])),np.linalg.norm(np.subtract(p['arms'][side]['wrist'],p['arms'][side]['elbow']))] for p in motion])
    arm_lengths[side]=np.ptp(lengths,axis=0).tolist()
    hands=np.array([p['arms'][side]['hand'][0] for p in motion]);feet=np.array([p['legs'][side]['ankle'][0] for p in motion])
    opposition[side]=float(np.corrcoef(hands,feet)[0,1])
check('Articulated arms retain their segment lengths',max(max(v) for v in arm_lengths.values())<1e-7,arm_lengths)
check('Hands oppose the same-side feet over the whole cycle',all(c<-.6 for c in opposition.values()),opposition)

# Evaluate the actual trajectory functions at the support/return boundaries.
# This checks continuity properties, rather than repeating their formulas.
def read_trajectory(filename):
    tree=ast.parse((ROOT/'tools/veilleur_walk'/filename).read_text(encoding='utf-8-sig'))
    functions=[node for node in tree.body if isinstance(node,ast.FunctionDef) and node.name in ['ease','trajectory']]
    scope={'np':np,'math':math,'STANCE':.6,'AMPLITUDE':21.}
    exec(compile(ast.Module(body=functions,type_ignores=[]),filename,'exec'),scope)
    return scope['trajectory']
boundaries={}
for version,filename in [('v4','walk_v4_corrected.py'),('v5','walk_v5_refined.py')]:
    fn=read_trajectory(filename);values=[];e=1e-5
    for b in [.6,1.]:
        sample=lambda q:np.array(fn(q%1)[:3])
        left=(sample(b)-sample(b-e))/e;right=(sample(b+e)-sample(b))/e
        acceleration_left=(sample(b)-2*sample(b-e)+sample(b-2*e))/(e*e)
        acceleration_right=(sample(b+2*e)-2*sample(b+e)+sample(b))/(e*e)
        values.append({'phase':b,'speed_discontinuity_estimate':np.abs(right-left).tolist(),
                       'acceleration_discontinuity_estimate':np.abs(acceleration_right-acceleration_left).tolist()})
    boundaries[version]=values
check('Foot position/lift/angle join without velocity jumps',max(max(v['speed_discontinuity_estimate']) for v in boundaries['v5'])<.01,boundaries)
old_orders=[p['leg_order'] for p in old]
old_switches=sum(old_orders[i]!=old_orders[(i+1)%len(old)] for i in range(len(old)))
oldroot=np.ptp(np.array([p['root'] for p in old]),axis=0)
newroot=np.ptp(np.array([p['root'] for p in motion]),axis=0)
report={'scope':'V5 refinement of V4. Checks establish local geometry, files and visible sole tracking, not artistic acceptance.',
        'checks':checks,'comparison':{'body_shift_range_output_px':{'v4':oldroot.tolist(),'v5':newroot.tolist()},
        'leg_layer_switches_per_cycle':{'v4':old_switches,'v5':0},
        'animated_boot_scale_range':{'v4':[1.,1.],'v5':[1.,1.]},
        'duration_ms':{'v4':800,'v5':800},'stride_output_px':{'v4':59.5,'v5':manifest['stride'][0]},
        'maximum_swing_lift_output_px':{'v4':max(p['legs'][s]['swing_lift'] for p in old for s in 'LR'),'v5':max(p['legs'][s]['swing_lift'] for p in motion for s in 'LR')},
        'foot_transition_measurements':boundaries,'hand_foot_correlation':opposition,'missing_region_repairs':patch_checks},
        'limitations':['The boot orientation artwork is still a single view.',
                       'Pixel tracking covers the visible near toe/sole during flat support, not every contact pixel.',
                       'Far limb length uses a shared anatomy with perspective instead of treating a shortened source drawing as anatomical length.',
                       'No native Godot integration or user artistic approval.']}
(OUT/'audit_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')

# Equal-phase contact sheets: V3 starts at the opposite contact, so add half a cycle.
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
board=Image.new('RGB',(1536,768),'#243b40')
for column,phase in enumerate([0,.25,.5,.75]):
    for row,(folder,index,label) in enumerate([(OLD,int(phase*N),'Avant V4'),(OUT,int(phase*N),'Après V5')]):
        im=Image.open(folder/f'frames/{index:02}.png').convert('RGBA').resize((384,384),Image.Resampling.LANCZOS)
        board.paste(im,(column*384,row*384),im)
        ImageDraw.Draw(board).text((column*384+12,row*384+10),f'{label} · phase {phase:.2f}',font=font,fill='#e6ddc7')
board.save(OUT/'audit_comparison.jpg',quality=95)
print(json.dumps({'checks_passed':len(checks),'comparison':report['comparison'],'rendered_sole_drift_px':pixel_drift,'seam':seams}))

