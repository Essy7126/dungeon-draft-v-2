"""Editable walk construction: heel contact, flat support, toe-off, swing.

Design reference: Jason Martinsen / Animation Mentor, human walk cycle (2025).
This is an authored blocking study, not motion capture or artistic approval.
"""
import math

DURATION = 1.2
STRIDE = .90
STANCE = .60
HEEL = -.10
TOE = .18
ANKLE_Z = .075


def smooth(t):
    return t*t*(3-2*t)


def rotate_x(v, angle):
    c,s = math.cos(angle),math.sin(angle)
    return [v[0],v[1]*c-v[2]*s,v[1]*s+v[2]*c]


def support(u, x):
    base = .26 - STRIDE*u
    if u < .10:
        pitch = math.radians(12)*(1-smooth(u/.10))
        pivot = HEEL
        contact = 'heel'
    elif u > .44:
        pitch = -math.radians(28)*smooth((u-.44)/(STANCE-.44))
        pivot = TOE
        contact = 'toe'
    else:
        pitch,pivot,contact = 0,0,'flat'
    offset=rotate_x([0,-pivot,ANKLE_Z],pitch)
    ankle=[x,base+pivot+offset[1],offset[2]]
    return ankle,pitch,contact


def foot(t, side):
    u=(t+(.5 if side=='R' else 0))%1
    x=.112 if side=='R' else -.112
    if u <= STANCE:
        ankle,pitch,contact=support(u,x)
    else:
        s=(u-STANCE)/(1-STANCE)
        a,pa,_=support(STANCE,x)
        b,pb,_=support(0,x)
        h00=2*s**3-3*s*s+1;h10=s**3-2*s*s+s
        h01=-2*s**3+3*s*s;h11=s**3-s*s
        dy=-STRIDE*(1-STANCE)
        y=h00*a[1]+h10*dy+h01*b[1]+h11*dy
        z=(1-smooth(s))*a[2]+smooth(s)*b[2]+.12*math.sin(math.pi*s)**1.2
        pitch=(1-smooth(s))*pa+smooth(s)*pb
        ankle=[x,y,z];contact='swing'
    def point(local):
        p=rotate_x(local,pitch)
        return [ankle[i]+p[i] for i in range(3)]
    return {'phase':u,'ankle':ankle,'pitch':pitch,'contact':contact,
            'heel':point([0,HEEL,-ANKLE_Z]),'toe':point([0,TOE,-ANKLE_Z])}


def body(t):
    a=2*math.pi*t
    return {'pelvis':[-.038*math.sin(a),0,1.025-.018*math.sin(2*a)],
            'pelvis_yaw':math.radians(-5)*math.cos(a),
            'chest_yaw':math.radians(4)*math.cos(a),
            'lean':math.radians(-3),
            'spear_swing':.016*math.sin(a-.25)}


def crossing():
    lo,hi=.2,.42
    for _ in range(48):
        t=(lo+hi)/2
        if foot(t,'R')['ankle'][1] < foot(t,'L')['ankle'][1]:lo=t
        else:hi=t
    return (lo+hi)/2


def validate():
    drift=[];floors=[];lengths=[]
    for i in range(1200):
        t=i/1200
        f={s:foot(t,s) for s in 'LR'}
        assert any(v['contact']!='swing' for v in f.values())
        for side,p in f.items():
            floors += [p['heel'][2],p['toe'][2]]
            lengths.append(abs(math.dist(p['heel'],p['toe'])-(TOE-HEEL)))
            n=foot(t+1e-6,side)
            if p['contact']==n['contact']!='swing' and n['phase']>p['phase']:
                key='heel' if p['contact']=='heel' else 'toe'
                v=[(n[key][j]-p[key][j])/1e-6 + (STRIDE if j==1 else 0) for j in range(3)]
                drift.append(math.sqrt(sum(x*x for x in v))/DURATION)
    assert min(floors)>-1e-8
    assert max(drift)<1e-5
    c=crossing()
    assert abs(foot(c,'R')['ankle'][1]-foot(c,'L')['ankle'][1])<1e-8
    assert body(c)['pelvis'][0]<0
    return {'samples':1200,'min_sole_z_m':min(floors),'max_rigid_foot_length_error_m':max(lengths),
            'max_contact_world_speed_m_s':max(drift),'passing_phase':c,'no_flight':True,
            'scope':'Analytical guide only; native Blender constraints and rendered artwork checked separately'}


if __name__=='__main__':
    import json
    print(json.dumps(validate()))
