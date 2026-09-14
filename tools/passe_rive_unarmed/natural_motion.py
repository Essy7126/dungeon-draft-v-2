"""V2 ordinary walk: support-side weight, fixed arm lengths, smooth foot recovery.

All values are authored, not mocap. Ground contacts and inter-segment lengths
are constraints; visual approval remains separate from those measurements.
"""
import math
import numpy as np

CFG={}
HEEL=-.08
TOE=.15
ANKLE_Z=.105
TAU=math.tau

def configure(config):
    CFG.clear();CFG.update(config)

def smooth(t):
    t=max(0.,min(1.,t))
    return t*t*t*(10+t*(-15+6*t))

def rotate(v,angle):
    c,s=math.cos(angle),math.sin(angle)
    return [v[0],v[1]*c-v[2]*s,v[1]*s+v[2]*c]

def support(u,x):
    base=CFG['stride']*(CFG['stance']*.5-u)
    if u<CFG['heel_end']:
        pitch=math.radians(CFG['heel_angle'])*(1-smooth(u/CFG['heel_end']))
        pivot=HEEL;contact='heel'
    elif u>CFG['toe_start']:
        pitch=-math.radians(CFG['toe_angle'])*smooth((u-CFG['toe_start'])/(CFG['stance']-CFG['toe_start']))
        pivot=TOE;contact='toe'
    else:
        pitch=0.;pivot=0.;contact='flat'
    offset=rotate([0,-pivot,ANKLE_Z],pitch)
    return [x,base+pivot+offset[1],offset[2]],pitch,contact

def foot(t,side):
    u=(t+(.5 if side=='R' else 0))%1
    x=.100 if side=='R' else -.100
    if u<=CFG['stance']:
        ankle,pitch,contact=support(u,x)
    else:
        s=(u-CFG['stance'])/(1-CFG['stance']);q=smooth(s)
        a,pa,_=support(CFG['stance'],x);b,pb,_=support(0,x)
        speed=-CFG['stride']*(1-CFG['stance'])
        # Equal first derivatives and zero second derivatives at both boundaries.
        y=a[1]+speed*s+(b[1]-a[1]-speed)*q
        lift=CFG['foot_lift']*64*s**3*(1-s)**3
        z=a[2]+(b[2]-a[2])*q+lift
        pitch=pa+(pb-pa)*q
        ankle=[x,y,z];contact='swing'
    def point(local):
        r=rotate(local,pitch)
        return [ankle[i]+r[i] for i in range(3)]
    return {'phase':u,'ankle':ankle,'pitch':pitch,'contact':contact,
            'heel':point([0,HEEL,-ANKLE_Z]),'toe':point([0,TOE,-ANKLE_Z])}

def pose(t,d,knee):
    a=TAU*t;s,c=math.sin(a),math.cos(a)
    bob=-CFG['bob']*math.cos(2*a-.6)
    # At phase .25 the LEFT leg bears weight, so the pelvis moves LEFT (negative x).
    pel=np.array([-CFG['sway']*s,.016,CFG['pelvis_height']+bob])
    joints={};feet={}
    for side,sign in [('R',1),('L',-1)]:
        f=foot(t,side);ankle=np.array(f['ankle'])
        hip=pel+np.array([sign*.105,-sign*CFG['hip_yaw_travel']*c,-sign*CFG['hip_drop']*s])
        k=knee(hip,ankle)
        shoulder=pel+np.array([sign*.18,.03+sign*CFG['shoulder_yaw_travel']*c,.407])
        # Pendular upper arm, with a relaxed elbow. Both segment lengths stay fixed.
        swing=sign*math.cos(a-.10)
        angle=CFG['arm_angle']*swing-.025
        elbow_angle=angle+CFG['elbow_flex']+.035*(1+swing)*.5
        upper=.275;lower=.225;lateral=sign*.012
        planar=math.sqrt(upper*upper-lateral*lateral)
        elbow=shoulder+np.array([lateral,planar*math.sin(angle),-planar*math.cos(angle)])
        wrist=elbow+np.array([0,lower*math.sin(elbow_angle),-lower*math.cos(elbow_angle)])
        joints[side]={'hip':hip,'knee':k,'ankle':ankle,'shoulder':shoulder,'elbow':elbow,'wrist':wrist}
        feet[side]=f
    head=pel+np.array([0,.055,.473])
    head[0]*=CFG['head_sway_follow']
    head[2]-=(1-CFG['head_bob_follow'])*bob
    return {'pelvis':pel,'head':head,'joints':joints,'feet':feet}

def validate():
    drift=[];floor=[];rigid=[]
    for i in range(2400):
        t=i/2400
        f={side:foot(t,side) for side in ['L','R']}
        assert any(p['contact']!='swing' for p in f.values())
        for side,p in f.items():
            floor.extend([p['heel'][2],p['toe'][2]])
            rigid.append(abs(math.dist(p['heel'],p['toe'])-(TOE-HEEL)))
            n=foot(t+1e-6,side)
            if n['contact']==p['contact']!='swing' and n['phase']>p['phase']:
                key='heel' if p['contact']=='heel' else 'toe'
                vel=[(n[key][j]-p[key][j])/1e-6+(CFG['stride'] if j==1 else 0) for j in range(3)]
                drift.append(math.sqrt(sum(v*v for v in vel))/CFG['duration'])
    assert min(floor)>-1e-8
    assert max(drift)<1e-5
    return {'samples':2400,'min_sole_z_m':min(floor),'max_rigid_foot_length_error_m':max(rigid),
            'max_contact_world_speed_m_s':max(drift),'no_flight':True,
            'scope':'Authored projected heel/toe contact anchors; painted sole requires visual review.'}
