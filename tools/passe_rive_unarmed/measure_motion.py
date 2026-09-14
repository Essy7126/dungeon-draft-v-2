"""Measure coordination and discontinuities independently from rendered FPS."""
import json,math
import numpy as np
from build_walk import CFG,OUT,pose,contacts,NATURAL

samples=2400
poses=[pose(i/samples,'E') for i in range(samples)]
arms=[];legs=[];foot_heights=[];head=[];hip_agreement=[]
for p in poses:
    head.append(p['head'])
    for side,j in p['joints'].items():
        arms.append([np.linalg.norm(j['elbow']-j['shoulder']),np.linalg.norm(j['wrist']-j['elbow'])])
        legs.append([np.linalg.norm(j['knee']-j['hip']),np.linalg.norm(j['ankle']-j['knee'])])
        f=p['feet'][side]
        if f['contact']=='swing':foot_heights.append(min(f['heel'][2],f['toe'][2]))
    support=[s for s in ['L','R'] if p['feet'][s]['contact']!='swing']
    if len(support)==1:
        sign=-1 if support[0]=='L' else 1
        hip_agreement.append(p['pelvis'][0]*sign>0)
arms=np.array(arms);legs=np.array(legs);head=np.array(head)
xyz=np.array([p['feet']['R']['ankle'] for p in poses])
dt=CFG['duration']/samples
velocity=(np.roll(xyz,-1,axis=0)-np.roll(xyz,1,axis=0))/(2*dt)
acceleration=(np.roll(xyz,-1,axis=0)-2*xyz+np.roll(xyz,1,axis=0))/(dt*dt)
report={'duration_s':CFG['duration'],'frames':CFG['frames'],'steps_per_minute':120/CFG['duration'],
 'stride_m':CFG['stride'],'max_swing_sole_clearance_m':max(foot_heights),
 'weight_shift_toward_support_fraction':sum(hip_agreement)/len(hip_agreement),
 'upper_arm_length_range_m':[float(arms[:,0].min()),float(arms[:,0].max())],
 'forearm_length_range_m':[float(arms[:,1].min()),float(arms[:,1].max())],
 'leg_length_variation_m':np.ptp(legs,axis=0).tolist(),
 'head_vertical_range_m':float(np.ptp(head[:,2])),
 'max_ankle_speed_m_s':float(np.linalg.norm(velocity,axis=1).max()),
 'max_sampled_ankle_acceleration_m_s2':float(np.linalg.norm(acceleration,axis=1).max()),
 'sample_count':samples,'artistic_approval':False}
if NATURAL:
    assert report['weight_shift_toward_support_fraction']==1.0
    assert np.ptp(arms,axis=0).max()<1e-10
    assert max(report['leg_length_variation_m'])<1e-10
    assert max(foot_heights)<.095
    # Periodic position AND velocity at toe-off and cycle boundary.
    eps=1e-6
    for boundary in [0,CFG['heel_end'],CFG['toe_start'],CFG['stance']]:
        a=np.array(contacts.foot(boundary-eps,'L')['ankle'])
        b=np.array(contacts.foot(boundary,'L')['ankle'])
        c=np.array(contacts.foot(boundary+eps,'L')['ankle'])
        assert np.linalg.norm((c-b)/eps-(b-a)/eps)<.002
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'motion_measurements.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
