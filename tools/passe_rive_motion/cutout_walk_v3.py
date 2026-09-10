"""Extract the generated sheet and apply the already-authorized software cutout."""
import os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
os.environ['U2NET_HOME']=str(ROOT/'artifacts/dev-tools/rembg-models')
os.environ['OMP_NUM_THREADS']='4'
import json,hashlib
import numpy as np
from PIL import Image
from rembg import new_session,remove

SOURCE=ROOT/'art/source/characters/achilles/passe_rive_walk_v3'
sheet=Image.open(SOURCE/'candidate_b_rgb.png').convert('RGB')
native=SOURCE/'rgb_frames';native.mkdir(exist_ok=True)
out=SOURCE/'rgba_frames';out.mkdir(exist_ok=True)
session=new_session('birefnet-general-lite',providers=['CPUExecutionProvider'])
reports=[]
for i in range(12):
    x,y=i%4,i//4
    box=(round(x*sheet.width/4),round(y*sheet.height/3),round((x+1)*sheet.width/4),round((y+1)*sheet.height/3))
    crop=sheet.crop(box)
    frame=Image.new('RGB',(320,480),'white')
    # Fixed grid origin and scale; never normalize by each pose's bounding box.
    frame.paste(crop,(12,18))
    rgb_path=native/f'walk_{i:02}.png';frame.save(rgb_path)
    dst=out/f'walk_{i:02}.png'
    if dst.exists():raise RuntimeError(f'Preserve existing output: {dst}')
    result=remove(frame,session=session,alpha_matting=False,decontaminate=True)
    px=np.array(result);original=np.asarray(frame)
    near_white=(original.min(axis=2)>=248)&(np.ptp(original,axis=2)<=8)
    px[near_white,3]=0
    px[px[:,:,3]<4]=0
    result=Image.fromarray(px);result.save(dst)
    alpha=px[:,:,3]
    report={'frame':i,'crop':box,'cell_size':[320,480],'bbox':result.getchannel('A').getbbox(),
            'opaque_pixels':int((alpha>=240).sum()),'transparent_fraction':float((alpha==0).mean()),
            'sha256':hashlib.sha256(dst.read_bytes()).hexdigest()}
    if report['opaque_pixels']<6000:raise RuntimeError(f'Insufficient foreground in frame {i}')
    reports.append(report);print(json.dumps(report),flush=True)
(SOURCE/'cutout_report.json').write_text(json.dumps({'sheet_size':sheet.size,'frames':reports,'method':'rembg / birefnet-general-lite CPU, white backdrop cleanup','per_frame_rescaling':False},indent=2),encoding='utf8')
print('WALK_V3_CUTOUT_READY',flush=True)
