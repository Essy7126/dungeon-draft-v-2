"""Sentinelle motion revision: consistent knee bends and a planted thrust.

Screen coordinates are used while authoring; prepare_sentinelle owns the Spine
coordinate conversion. This adapter leaves the shared monster rig unchanged.
"""
import math
import numpy as np
from articulated_animation import PaintedSkeleton, angle_of, shortest

DIRECTIONS = ('E', 'S', 'W', 'N')
DURATIONS = {'idle': 2.4, 'walk': .72, 'attack': .8, 'cast': .88, 'hit': .2, 'death': .8}
EVENTS = {'walk': [(0., 'footstep_left'), (.36, 'footstep_right')],
          'attack': [(.4, 'attack_release')], 'cast': [(.44, 'cast_release')],
          'death': [(.08, 'death_burst'), (.16, 'vanish')]}
STANCE = .6
STEP_SPAN = 24.
CYCLE_TRAVEL = STEP_SPAN / STANCE


def smooth(t, keys):
    for (a, x), (b, y) in zip(keys, keys[1:]):
        if t <= b:
            f = float(np.clip((t-a)/(b-a), 0., 1.))
            return x + (y-x)*f*f*(3-2*f)
    return keys[-1][1]


def axis_for(direction):
    return np.array([-2. if direction in 'SW' else 2., -1. if direction in 'NW' else 1.]) / math.sqrt(5)


def solve_bend(hip, knee, end, target, parent, bend):
    h, k, e = (parent @ np.c_[np.asarray([hip, knee, end]), np.ones(3)].T).T[:, :2]
    first, second = k-h, e-k
    a, b = np.linalg.norm(first), np.linalg.norm(second)
    delta = np.asarray(target)-h
    distance = np.linalg.norm(delta)
    reach = float(np.clip(distance, abs(a-b)+.05, a+b-.05))
    gamma = math.acos(float(np.clip((a*a+reach*reach-b*b)/(2*a*reach), -1, 1)))
    first_angle = math.atan2(delta[1], delta[0])-bend*gamma
    new_knee = h+a*np.array([math.cos(first_angle), math.sin(first_angle)])
    reachable = h+delta/max(distance, .001)*reach
    first_delta = shortest(math.degrees(first_angle)-angle_of(first))
    second_delta = shortest(angle_of(reachable-new_knee)-angle_of(second)-first_delta)
    return first_delta, second_delta


class DirectionalSkeleton(PaintedSkeleton):
    def matrices(self, pose):
        bends = pose.get('bend_directions', {})
        if not bends:
            return super().matrices(pose)
        adapted = dict(pose)
        adapted['angles'] = dict(pose.get('angles', {}))
        adapted['ik'] = {k: v for k, v in pose.get('ik', {}).items() if k not in bends}
        parents = super().matrices(adapted)
        for upper, bend in bends.items():
            if upper not in pose.get('ik', {}):
                continue
            lower = upper.replace('upper_arm', 'arm') if upper.startswith('upper_arm') else upper.replace('leg', 'shin', 1)
            a, b = self.by_name[upper], self.by_name[lower]
            target = np.asarray(b['end'])+pose['ik'][upper]
            first, second = solve_bend(a['pivot'], b['pivot'], b['end'], target, parents[a['parent']], bend)
            adapted['angles'][upper], adapted['angles'][lower] = first, second
        return super().matrices(adapted)


def foot_track(phase):
    phase %= 1.
    if phase < STANCE:
        return STEP_SPAN/2-STEP_SPAN*phase/STANCE, 0.
    u = (phase-STANCE)/(1-STANCE)
    return -STEP_SPAN/2+STEP_SPAN*u*u*(3-2*u), 10*math.sin(math.pi*u)**2


def pose_for(rig, action, t):
    sign = -1 if rig.direction in 'SW' else 1
    axis = axis_for(rig.direction)
    angles = {}
    ik = {'leg_left': [0., 0.], 'leg_right': [0., 0.]}
    world = {'foot_left': 0., 'foot_right': 0., 'hand_right': 0.}
    p = {'root': {'shift': [0., 0.]}, 'angles': angles, 'ik': ik, 'world_angles': world,
         'bend_directions': {'leg_left': sign, 'leg_right': sign, 'upper_arm_right': -sign}}
    shoulder = np.asarray(rig.by_name['upper_arm_right']['pivot'])
    elbow = np.asarray(rig.by_name['arm_right']['pivot'])
    wrist = np.asarray(rig.by_name['hand_right']['pivot'])
    arm_reach = np.linalg.norm(elbow-shoulder)+np.linalg.norm(wrist-elbow)
    if action == 'idle':
        breath = math.sin(t/DURATIONS[action]*math.tau)
        p['root']['shift'] = [0., 1.2*breath]
        angles.update(head=-.7*breath*sign, torso=.45*breath*sign,
                      upper_arm_left=.8*breath*sign, arm_left=-.5*breath*sign, cloth=1.2*breath*sign)
    elif action == 'walk':
        phase = t/DURATIONS[action]
        # Stable pelvis height: do not let individual IK reach limits drive a
        # different vertical bounce for each leg. Both feet share the same lane.
        p['root']['shift'] = [0., 10+1.2*math.cos(phase*math.tau*2)]
        angles.update(torso=.6*sign*math.sin(phase*math.tau), head=-.6*sign*math.sin(phase*math.tau),
                      upper_arm_left=-2*sign*math.sin(phase*math.tau),
                      arm_left=1.5*sign*math.sin(phase*math.tau), cloth=3*sign*math.sin(phase*math.tau-.3))
        for side, offset in [('left', 0.), ('right', .5)]:
            travel, lift = foot_track(phase+offset)
            ik['leg_'+side] = (axis*travel+[0., -lift]).tolist()
        # The arm absorbs the body's gait instead of swinging the heavy spear.
        ik['upper_arm_right'] = [0., 6.]
    elif action == 'attack':
        guard = smooth(t, [(0, 0), (.20, 1), (.52, 1), (.8, 0)])
        coil = smooth(t, [(0, 0), (.20, 1), (.28, 1), (.4, 0), (.8, 0)])
        drive = smooth(t, [(0, 0), (.28, 0), (.4, 1), (.46, 1), (.66, .2), (.8, 0)])
        step = smooth(t, [(0, 0), (.16, 0), (.34, 1), (.50, 1), (.8, 0)])
        p['root']['shift'] = (axis*(14*drive-4*coil)+[0, 3*coil+3*drive]).tolist()
        angles.update(torso=sign*(4*drive-2*coil), head=sign*(-2.5*drive+1.3*coil),
                      upper_arm_left=sign*(12*drive+5*coil), arm_left=sign*(-10*drive+2*coil),
                      cloth=sign*(-6*drive+3*coil))
        front = max(('left', 'right'), key=lambda side: float(np.dot(rig.by_name['foot_'+side]['pivot'], axis)))
        rear = 'right' if front == 'left' else 'left'
        lift = 5*math.sin(math.pi*np.clip((t-.16)/.18, 0, 1))**2 if t < .34 else 0.
        ik['leg_'+front] = (axis*10*step+[0, -lift]).tolist()
        ik['leg_'+rear] = [0., -1.5*drive]
        torso = rig.matrices(p)['torso']
        shoulder_world = (torso@np.r_[shoulder, 1])[:2]
        resting_wrist = (torso@np.r_[wrist, 1])[:2]
        coil_pose = {'root': {'shift': (-axis*4+[0, 3]).tolist()}, 'angles': {'torso': -2*sign}}
        reference = (rig.matrices(coil_pose)['torso']@np.r_[shoulder, 1])[:2]
        target = reference+[axis[0]*12, min(42, arm_reach*.4)]+axis*(18+arm_reach*.60)*drive
        desired = resting_wrist*(1-guard)+target*guard
        ik['upper_arm_right'] = (desired-wrist).tolist()
        weapon = np.asarray(rig.by_name['hand_right']['weapon_tip'])-wrist
        world['hand_right'] = shortest(angle_of(axis)-angle_of(weapon))*guard
    elif action == 'cast':
        charge = smooth(t, [(0, 0), (.25, 1), (.34, 1), (.44, .55), (.62, .2), (.88, 0)])
        release = smooth(t, [(0, 0), (.32, 0), (.44, 1), (.51, .92), (.70, .2), (.88, 0)])
        p['root']['shift'] = (axis*(-7*charge+10*release)+[0, 9*charge-2*release]).tolist()
        angles.update(torso=sign*(-5*charge+6*release), head=sign*(-6*charge-2*release),
                      upper_arm_left=sign*(-31*charge-12*release), arm_left=sign*(20*charge-16*release),
                      cloth=sign*(7*charge-12*release))
        # The spear remains in guard while the shield makes a clear forward beat.
        ik['upper_arm_right'] = (-axis*4*charge+[0, -8*charge]).tolist()
        world['hand_right'] = sign*(-9*charge+4*release)
    elif action == 'hit':
        recoil = smooth(t, [(0, 0), (.045, 1), (.09, .72), (.2, 0)])
        p['root']['shift'] = (-axis*8*recoil+[0, 5*recoil]).tolist()
        angles.update(torso=-sign*7*recoil, head=sign*6*recoil,
                      upper_arm_left=-sign*7*recoil, arm_left=sign*8*recoil, cloth=sign*8*recoil)
    elif action == 'death':
        # The disappearance is authored in slot alpha and burst timelines.
        pulse = smooth(t, [(0, 0), (.05, 1), (.16, 0), (.8, 0)])
        p['root']['shift'] = [0., 2*pulse]
        angles['head'] = -sign*pulse
    else:
        raise ValueError(action)
    # Keep the chosen knee bend reachable, with only a small correction outside
    # walking. The gait is designed to fit at a stable pelvis height.
    torso = rig.matrices(p)['torso']
    drop = 0.
    for side in ('left', 'right'):
        upper, lower = rig.by_name['leg_'+side], rig.by_name['shin_'+side]
        hip, knee, ankle = map(np.asarray, (upper['pivot'], lower['pivot'], lower['end']))
        reach = np.linalg.norm(knee-hip)+np.linalg.norm(ankle-knee)-.2
        dx, dy = ankle+ik['leg_'+side]-(torso@np.r_[hip, 1])[:2]
        if dy > 0 and abs(dx) < reach:
            drop = max(drop, dy-math.sqrt(reach*reach-dx*dx))
    p['root']['shift'][1] += drop
    if 'upper_arm_right' not in ik:
        natural = rig.matrices(p)['hand_right']
        ik['upper_arm_right'] = ((natural@np.r_[wrist, 1])[:2]-wrist).tolist()
    return p


def library(rig):
    result = {}
    for action, duration in DURATIONS.items():
        times = set(np.linspace(0., duration, math.ceil(duration*60)+1))
        times.update(t for t, _ in EVENTS.get(action, []))
        if action == 'attack':
            times.update([.16, .20, .28, .34, .4, .46, .50, .52, .66])
        if action == 'hit':
            times.update([.045, .09])
        result[action] = [(t, pose_for(rig, action, t)) for t in sorted({round(float(v), 6) for v in times})]
    return result
