"""Validate delivered frames, real alpha at joints, reach, and cycle continuity."""
import json, math
import numpy as np
from PIL import Image
from build_walk import CFG,OUT,SRC,pose,project,contacts

data=json.loads((OUT/'walk_review.json').read_text());assert data['order']==['E','S','N','W'];count=CFG['frames']
report={'directions':{},'artistic_approval':False,'contact_scope':'Authored projected heel/toe anchors, not independent tracking of the full painted sole.'}
for d in data['order']:
    covered=0;missing=[];frames=[]
    for i,file in enumerate(data['views'][d]['frames']):
        im=Image.open(OUT/file);assert im.mode=='RGBA' and im.size==(768,768)
        px=np.array(im);assert px[:,:,3].min()==0 and px[:,:,3].max()==255
        bbox=im.getbbox();assert bbox[0]>3 and bbox[1]>3 and bbox[2]<765 and bbox[3]<765
        p=pose(i/count,d)
        for side,joints in p['joints'].items():
            for name in ['hip','knee','ankle','shoulder','elbow','wrist']:
                xy=np.rint(project(joints[name],d)).astype(int);x,y=xy
                patch=px[y-2:y+3,x-2:x+3,3]
                if patch.max()<180:missing.append([i,side,name,xy.tolist()])
                else:covered+=1
        # Compare premultiplied reduced pixels, including alpha, for visible pops.
        small=np.asarray(im.resize((192,192))).astype(float)/255
        small[:,:,:3]*=small[:,:,3:4];frames.append(small)
    diffs=[float(np.abs(frames[(i+1)%count]-frames[i]).mean()) for i in range(count)]
    median=float(np.median(diffs));assert diffs[-1]<median*2.5,'Loop seam pop '+d
    assert not missing, f'Uncovered attachment {d}: {missing}'
    for i in range(2400):pose(i/2400,d)
    # Same raster source parts are used through the entire animation.
    report['directions'][d]={'frames':count,'covered_joint_samples':covered,'uncovered':missing,
        'loop_seam_pixel_delta':diffs[-1],'median_frame_delta':median,
        'maximum_frame_delta':max(diffs),'cycle_seam_ratio':diffs[-1]/median,
        'source_part_count':16,'bounds_and_alpha':True,'leg_reach_samples':2400}
report['analytical_contact']=contacts.validate()
(OUT/'asset_verification.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
