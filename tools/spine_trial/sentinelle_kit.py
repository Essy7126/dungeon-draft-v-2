"""Author the four-direction Sentinelle animation kit using the shared rig.

Run without arguments to create a new numbered revision. Existing work is never
overwritten. All art comes from the four source paintings, without mirroring.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import shutil
import time

import numpy as np
from PIL import Image

from prepare_sentinelle import ROOT, digest, prepare, wrapped

DIRECTIONS = ('E', 'S', 'W', 'N')
DURATIONS = {'idle': 2.4, 'walk': .72, 'attack': .8, 'cast': .88, 'hit': .2, 'death': .8}
EVENTS = {'walk': [(0., 'footstep_left'), (.36, 'footstep_right')],
          'attack': [(.4, 'attack_release')], 'cast': [(.44, 'cast_release')],
          'death': [(.72, 'body_landed')]}



def separate_pauldrons(parts):
    """Keep rigid shoulder plates on the torso while the arm bends beneath.

    The segmentation service already separates source paint from joint
    underpaint. Move the two painted plates to independent bones; retain the
    existing joint underpaint on the articulated upper arms.
    """
    result = []
    for original in parts:
        part = dict(original)
        if part['name'].startswith('upper_arm_'):
            cap = dict(part)
            cap['name'] = part['name'].replace('upper_arm_', 'pauldron_')
            cap['parent'] = 'torso'
            cap['underpaint'] = Image.new('RGBA', part['image'].size)
            cap['image'] = part['source_image'].copy()
            cap.pop('end', None)
            part['source_image'] = Image.new('RGBA', part['image'].size)
            part['image'] = part['underpaint'].copy()
            result.append(cap)
        result.append(part)
    return result

def smooth(t, keys):
    """Interpolate authored phase values; zero velocity at each phase boundary."""
    if t <= keys[0][0]:
        return float(keys[0][1])
    for (a, x), (b, y) in zip(keys, keys[1:]):
        if t <= b + 1e-9:
            f = np.clip((t - a) / (b - a), 0., 1.)
            return float(x + (y - x) * f * f * (3 - 2 * f))
    return float(keys[-1][1])


def pose_for(rig, action, t):
    direction = rig.direction
    sign = -1 if direction in 'SW' else 1
    depth = -1 if direction in 'NW' else 1
    axis = np.array([sign * 2 / math.sqrt(5), depth / math.sqrt(5)])
    angles = {}
    ik = {'leg_left': [0., 0.], 'leg_right': [0., 0.]}
    world = {'foot_left': 0., 'foot_right': 0.}
    p = {'root': {'shift': [0., 0.]}, 'angles': angles, 'ik': ik, 'world_angles': world}
    if action == 'idle':
        breath = math.sin(t / DURATIONS[action] * math.tau)
        p['root']['shift'] = [0., 1.4 * breath]
        angles.update(head=-1.2 * breath * sign, torso=.65 * breath * sign,
                      upper_arm_left=1.3 * breath * sign, arm_left=-.8 * breath * sign,
                      upper_arm_right=-1.2 * breath * sign, arm_right=.7 * breath * sign,
                      cloth=1.8 * breath * sign)
    elif action == 'walk':
        phase = t / DURATIONS[action]
        cycle = math.tau * phase
        p['root']['shift'] = [1.3 * math.sin(cycle) * sign, 3 + 2 * math.cos(2 * cycle)]
        angles.update(torso=2 * math.sin(cycle) * sign, head=-2 * math.sin(cycle) * sign,
                      upper_arm_left=-4 * math.sin(cycle) * sign,
                      arm_left=2 * math.sin(cycle) * sign,
                      upper_arm_right=5 * math.sin(cycle) * sign,
                      arm_right=-3 * math.sin(cycle) * sign,
                      cloth=7 * math.sin(cycle - .4) * sign)
        for side, offset in [('left', 0), ('right', .5)]:
            f = (phase + offset) % 1.
            if f < .5:  # Stance travels backwards at constant speed in place.
                travel, lift = 17 - 68 * f, 0.
            else:  # Swing clears the floor before the next contact.
                u = (f - .5) * 2
                travel = -17 + 34 * (u * u * (3 - 2 * u))
                lift = 14 * math.sin(math.pi * u) ** 2
            ik['leg_' + side] = (axis * travel + [0, -lift]).tolist()
            world['foot_' + side] = -sign * 9 * lift / 14
    elif action == 'attack':
        wind = smooth(t, [(0, 0), (.18, 1), (.4, 0), (.8, 0)])
        thrust = smooth(t, [(0, 0), (.22, 0), (.4, 1), (.46, .94), (.64, .28), (.8, 0)])
        aim = smooth(t, [(0, 0), (.22, 1), (.46, 1), (.66, .5), (.8, 0)])
        p['root']['shift'] = (axis * (13 * thrust - 6 * wind) + [0, 5 * wind + 4 * thrust]).tolist()
        angles.update(torso=sign * (9 * thrust - 5 * wind),
                      head=sign * (-6 * thrust + 3 * wind),
                      upper_arm_left=sign * (-8 * thrust + 3 * wind),
                      arm_left=sign * (7 * thrust + 3 * wind),
                      cloth=sign * (-9 * thrust + 4 * wind))
        # Aim from the moving shoulder, not from the original lowered wrist.
        shoulder = np.asarray(rig.by_name['upper_arm_right']['pivot'])
        elbow = np.asarray(rig.by_name['arm_right']['pivot'])
        wrist = np.asarray(rig.by_name['hand_right']['pivot'])
        reach = np.linalg.norm(elbow - shoulder) + np.linalg.norm(wrist - elbow)
        torso_matrix = rig.matrices(p)['torso']
        shoulder_world = (torso_matrix @ np.r_[shoulder, 1.])[:2]
        aiming_wrist = shoulder_world + axis * reach * (.28 + .66 * thrust) + [0, 22 * (1 - thrust)]
        resting_wrist = (torso_matrix @ np.r_[wrist, 1.])[:2]
        desired_wrist = resting_wrist * (1 - aim) + aiming_wrist * aim
        ik['upper_arm_right'] = (desired_wrist - wrist).tolist()
        hand = rig.by_name['hand_right']
        weapon = np.asarray(hand['weapon_tip']) - np.asarray(hand['pivot'])
        setup = math.degrees(math.atan2(weapon[1], weapon[0]))
        target = math.degrees(math.atan2(axis[1], axis[0]))
        world['hand_right'] = wrapped(target - setup) * aim
    elif action == 'cast':
        charge = smooth(t, [(0, 0), (.27, 1), (.44, .95), (.58, .55), (.88, 0)])
        release = smooth(t, [(0, 0), (.34, 0), (.44, 1), (.61, .25), (.88, 0)])
        p['root']['shift'] = (axis * (-3 * charge + 5 * release) + [0, 5 * charge - 3 * release]).tolist()
        angles.update(torso=-sign * 3 * charge + sign * 4 * release,
                      head=-sign * 4 * charge,
                      upper_arm_left=-sign * (18 * charge + 7 * release),
                      arm_left=sign * (12 * charge - 4 * release),
                      upper_arm_right=-sign * 5 * charge,
                      arm_right=sign * 4 * charge,
                      cloth=sign * (5 * charge - 10 * release))
    elif action == 'hit':
        recoil = smooth(t, [(0, 0), (.045, 1), (.09, .72), (.2, 0)])
        p['root']['shift'] = (-axis * 8 * recoil + [0, 5 * recoil]).tolist()
        angles.update(torso=-sign * 7 * recoil, head=sign * 6 * recoil,
                      upper_arm_left=-sign * 7 * recoil, arm_left=sign * 8 * recoil,
                      upper_arm_right=sign * 6 * recoil, arm_right=-sign * 8 * recoil,
                      cloth=sign * 8 * recoil)
    elif action == 'death':
        recoil = smooth(t, [(0, 0), (.1, 1), (.3, 0), (.8, 0)])
        kneel = smooth(t, [(0, 0), (.12, 0), (.38, 1), (.8, 1)])
        fall = smooth(t, [(0, 0), (.32, 0), (.67, 1), (.72, .98), (.8, 1)])
        p['root']['shift'] = [sign * (-5 * recoil + 8 * kneel + 25 * fall),
                              7 * recoil + 38 * kneel + 58 * fall]
        angles.update(torso=sign * (-8 * recoil + 16 * kneel + 66 * fall),
                      head=sign * (5 * recoil - 10 * kneel + 4 * fall),
                      upper_arm_left=sign * (-8 * kneel - 24 * fall),
                      arm_left=sign * (15 * kneel + 24 * fall),
                      upper_arm_right=sign * (12 * kneel - 30 * fall),
                      arm_right=sign * (-22 * kneel + 38 * fall),
                      cloth=sign * (-12 * kneel - 32 * fall))
        # Once down, both knees fold; the feet follow the fallen pelvis.
        for side, side_sign in [('left', -1), ('right', 1)]:
            ik['leg_' + side] = [sign * (15 + side_sign * 8) * fall, -8 * fall]
            world['foot_' + side] = sign * (22 + 10 * side_sign) * fall
        p['floor_blend'] = smooth(t, [(0, 0), (.32, 0), (.6, 1), (.8, 1)])
        hand = rig.by_name['hand_right']
        weapon = np.asarray(hand['weapon_tip']) - np.asarray(hand['pivot'])
        setup = math.degrees(math.atan2(weapon[1], weapon[0]))
        world['hand_right'] = wrapped((0 if sign > 0 else 180) - setup) * fall
        # Fold the spear arm close to the fallen shoulder instead of propping
        # the entire corpse up on a straight arm.
        current = rig.matrices(p)
        wrist = np.asarray(hand['pivot'])
        shoulder = np.asarray(rig.by_name['upper_arm_right']['pivot'])
        natural_wrist = (current['hand_right'] @ np.r_[wrist, 1.])[:2]
        shoulder_world = (current['torso'] @ np.r_[shoulder, 1.])[:2]
        folded_wrist = shoulder_world + [sign * 25, 12]
        ik['upper_arm_right'] = ((natural_wrist * (1 - fall) + folded_wrist * fall) - wrist).tolist()
    else:
        raise ValueError(action)
    # A planted foot cannot be reached by stretching a rigid two-link leg.
    # Lower the pelvis only as much as needed before solving the leg IK.
    torso_world = rig.matrices(p)['torso']
    drop = 0.
    for side in ('left', 'right'):
        upper = rig.by_name['leg_' + side]
        lower = rig.by_name['shin_' + side]
        hip = np.asarray(upper['pivot'])
        knee = np.asarray(lower['pivot'])
        ankle = np.asarray(lower['end'])
        reach = np.linalg.norm(knee - hip) + np.linalg.norm(ankle - knee) - .2
        hip_world = (torso_world @ np.r_[hip, 1.])[:2]
        dx, dy = ankle + np.asarray(ik['leg_' + side]) - hip_world
        if dy > 0 and abs(dx) < reach:
            drop = max(drop, dy - math.sqrt(reach * reach - dx * dx))
    p['root']['shift'][1] += drop
    return p


def library(rig):
    animations = {}
    for action, duration in DURATIONS.items():
        times = set(np.linspace(0., duration, math.ceil(duration * 30) + 1).tolist())
        times.update(t for t, _ in EVENTS.get(action, []))
        if action == 'attack':
            times.update([.18, .22, .4, .46, .64, .66])
        if action == 'hit':
            times.update([.045, .09])
        animations[action] = [(t, pose_for(rig, action, t)) for t in sorted({round(value, 6) for value in times})]
    return animations


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--revision', help='New directory name; existing outputs are preserved.')
    args = parser.parse_args()
    revision = args.revision or ('sentinelle_kit_' + time.strftime('%Y%m%d_%H%M%S'))
    if not revision.replace('_', '').replace('-', '').isalnum():
        parser.error('Use letters, digits, underscores and hyphens for the revision.')
    output = ROOT / 'artifacts/spine_trial' / revision
    if output.exists():
        raise ValueError(f'Existing work preserved: {output}')
    manifests = []
    for direction in DIRECTIONS:
        manifest = prepare(direction, output, library, separate_pauldrons)
        path = output / direction / 'sentinelle.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        data['events'] = {name: {} for events in EVENTS.values() for _, name in events}
        for action, events in EVENTS.items():
            data['animations'][action]['events'] = [{'time': t, 'name': name} for t, name in events]
        path.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
        manifest.update(animations=DURATIONS, spine_json_sha256=digest(path),
                        recipe_sha256=digest(Path(__file__)))
        (output / direction / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
        manifests.append(manifest)
    manifest = {'character': 'sentinelle_airain', 'revision': revision, 'directions': list(DIRECTIONS),
                'animations': DURATIONS, 'loop': ['idle', 'walk'], 'events': EVENTS,
                'clips': 24, 'status': 'first_complete_kit_for_visual_review',
                'spine_data': '4.2.22', 'editor_roundtrip_verified': False,
                'gameplay_resources_replaced': False, 'sources': manifests}
    (output / 'kit.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    shutil.copyfile(Path(__file__).with_name('kit_review.html'), output / 'review.html')
    print(json.dumps({'passed': True, 'revision': revision, 'clips': 24, 'output': str(output),
                      'review': f'http://127.0.0.1:8734/files/{revision}/review.html'}))


if __name__ == '__main__':
    main()
