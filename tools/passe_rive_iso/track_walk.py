"""Measure a visible stance interval on PAINTED frames; never modify artwork.

Lucas-Kanade with forward/backward rejection. Scope is one visible shoe patch,
not automatic anatomical recognition or proof of every foot contact.
"""
from pathlib import Path
import sys,json
import numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'artifacts/dev-tools/walk-tracking'))
import cv2
OUT=ROOT/'artifacts/spine_trial/passe_rive_walk_iso_v1'
data=json.loads((OUT/'walk_review.json').read_text(encoding='utf8'))
frames=[np.asarray(Image.open(OUT/f).convert('RGBA')) for f in data['views']['E']['frames'][:6]]
gray=[cv2.cvtColor(f[:,:,:3],cv2.COLOR_RGB2GRAY) for f in frames]
mask=np.zeros(gray[0].shape,np.uint8)
mask[618:640,397:442]=255
mask[frames[0][:,:,3]<180]=0
points=cv2.goodFeaturesToTrack(gray[0],maxCorners=30,qualityLevel=.04,minDistance=3,mask=mask,blockSize=3)
if points is None or len(points)<4: raise RuntimeError('Insufficient shoe features')
initial=points[:,0].copy();active=points.copy();tracks=[initial.tolist()];records=[]
alive=np.arange(len(points));positions=np.full((6,len(points),2),np.nan);positions[0]=initial
lost_at=None
for i in range(1,6):
    nxt,status,error=cv2.calcOpticalFlowPyrLK(gray[i-1],gray[i],active,None,winSize=(25,25),maxLevel=3,criteria=(cv2.TERM_CRITERIA_EPS|cv2.TERM_CRITERIA_COUNT,40,.01))
    back,backstatus,_=cv2.calcOpticalFlowPyrLK(gray[i],gray[i-1],nxt,None,winSize=(25,25),maxLevel=3,criteria=(cv2.TERM_CRITERIA_EPS|cv2.TERM_CRITERIA_COUNT,40,.01))
    fb=np.linalg.norm(back[:,0]-active[:,0],axis=1)
    valid=(status[:,0]==1)&(backstatus[:,0]==1)&(fb<1.5)&(error[:,0]<20)
    alive=alive[valid];active=nxt[valid]
    if len(alive)<3:
        lost_at=i
        positions=positions[:i]
        break
    positions[i,alive]=active[:,0]
    records.append({'frame':i,'surviving_features':len(alive),'max_forward_backward_error':float(fb[valid].max())})
complete=np.isfinite(positions).all(axis=(0,2))
if complete.sum()<3:raise RuntimeError('Too few full tracks')
movement=np.median(positions[:,complete]-positions[0,complete],axis=1)
times=np.arange(len(positions))/12
stride=np.asarray(data['views']['E']['stride'])
world=movement+times[:,None]*stride
# The source camera expects a 2:1 floor direction; fit only that distance.
axis=np.array([1,.5]);design=np.outer(times,axis)
best_stride=float(-(movement*design).sum()/(design*design).sum())
best_world=movement+best_stride*design
result={'method':'OpenCV pyramidal Lucas-Kanade + forward/backward check','opencv':cv2.__version__,'scope':'E initial visible left shoe patch, manually selected; not all feet or anatomical approval','requested_frames':6,'frames':len(positions),'tracking_lost_at_frame_1based':None if lost_at is None else lost_at+1,'complete_features':int(complete.sum()),'tracking':records,'painted_shoe_displacement_px':movement.tolist(),'provisional_cycle_stride_px':stride.tolist(),'world_patch_displacement_px':world.tolist(),'world_endpoint_drift_at_game_scale_px':float(np.linalg.norm(world[-1])*.35),'best_fit_cycle_stride_px':[best_stride,best_stride*.5],'best_fit_world_endpoint_drift_at_game_scale_px':float(np.linalg.norm(best_world[-1])*.35),'artist_approval':False,'interpretation':'A shoe feature is not itself the changing heel/toe ground contact. Review overlays and rolling phase before concluding. Fitting speed alone cannot fix a trajectory with the wrong direction. A truncated track is explicitly incomplete.'}
(OUT/'foot_tracking_report.json').write_text(json.dumps(result,indent=2),encoding='utf8')
sheet=Image.new('RGB',(1440,580),'#203b31');draw=ImageDraw.Draw(sheet);font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
for i,frame in enumerate(frames[:len(positions)]):
    im=Image.fromarray(frame)
    x=i%3*480;y=i//3*290
    # 1.5x view fits one tile without covering another.
    crop=im.crop((270,520,510,700)).resize((360,270));sheet.paste(crop,(x+60,y+15),crop)
    for point in positions[i,complete]:
        px=x+60+(point[0]-270)*1.5;py=y+15+(point[1]-520)*1.5
        draw.ellipse((px-2,py-2,px+2,py+2),fill='#fff566')
    draw.text((x+8,y+8),f'E {i+1}',font=font,fill='white')
sheet.save(OUT/'tracked_shoe_review.jpg',quality=94)
print(json.dumps({k:result[k] for k in ['frames','complete_features','world_endpoint_drift_at_game_scale_px','best_fit_world_endpoint_drift_at_game_scale_px','artist_approval']}))
