"""Check motion from the actual Spine JSON, including between authored keys."""
import argparse
import json
import math
import time
import numpy as np
from PIL import Image
from prepare_sentinelle import ROOT, build_parts, rotate


def value(keys, t, channel, default=0.):
    if not keys or t < keys[0].get('time', 0):
        return default
    for a, b in zip(keys, keys[1:]):
        start, end = a.get('time', 0), b['time']
        if t <= end:
            f = (t-start)/(end-start)
            return a.get(channel, default)*(1-f)+b.get(channel, default)*f
    return keys[-1].get(channel, default)


def worlds(data, action, t):
    result = {}
    for bone in data['bones']:
        tracks = data['animations'][action].get('bones', {}).get(bone['name'], {})
        m = np.eye(3)
        angle = bone.get('rotation', 0)+value(tracks.get('rotate', []), t, 'value')
        m[:2, :2] = rotate(angle)
        m[:2, 0] *= bone.get('scaleX', 1)*value(tracks.get('scale', []), t, 'x', 1.)
        m[:2, 1] *= bone.get('scaleY', 1)*value(tracks.get('scale', []), t, 'y', 1.)
        m[:2, 2] = [bone.get('x', 0)+value(tracks.get('translate', []), t, 'x'),
                     bone.get('y', 0)+value(tracks.get('translate', []), t, 'y')]
        result[bone['name']] = result[bone['parent']]@m if 'parent' in bone else m
    return result


def screen(transform):
    return transform[:2, 2]*[1, -1]+[256, 320]


def alpha(data, action, name, t):
    slot = next(slot for slot in data['slots'] if slot['name'] == name)
    default = int(slot.get('color', 'ffffffff')[-2:], 16)/255
    keys = data['animations'][action].get('slots', {}).get(name, {}).get('rgba', [])
    return value([{'time': k.get('time', 0), 'a': int(k['color'][-2:], 16)/255} for k in keys], t, 'a', default)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('revision', nargs='?', default='sentinelle_kit_v7')
    args = parser.parse_args()
    directory = ROOT/'artifacts/spine_trial'/args.revision
    kit = json.loads((directory/'kit.json').read_text(encoding='utf-8'))
    if kit.get('motion_revision') != 6:
        raise ValueError('These movement criteria apply to revision 6 after user feedback.')
    checks = []
    for direction in kit['directions']:
        data = json.loads((directory/direction/'sentinelle.json').read_text(encoding='utf-8'))
        sign = -1 if direction in 'SW' else 1
        axis = np.array([sign*2, -1 if direction in 'NW' else 1])/math.sqrt(5)
        body = [s['name'] for s in data['slots'] if not s['name'].startswith('vanish_')]
        fx = [s['name'] for s in data['slots'] if s['name'].startswith('vanish_')]
        min_bend, slip = float('inf'), 0.
        duration = kit['animations']['walk']
        speed = kit['locomotion']['cycle_travel_pixels']/duration
        stance = kit['locomotion']['stance_fraction']
        for side, offset in [('left', 0.), ('right', .5)]:
            previous = None
            for t in np.linspace(0, duration, 97):
                matrices = worlds(data, 'walk', t)
                h, k, f = [screen(matrices[n+'_'+side]) for n in ('leg', 'shin', 'foot')]
                a, b = k-h, f-k
                min_bend = min(min_bend, float(sign*(a[0]*b[1]-a[1]*b[0])))
                phase = (t/duration+offset)%1
                if previous:
                    last_t, last_phase, last_f = previous
                    if last_phase <= phase < stance and last_phase < stance:
                        slip = max(slip, float(np.linalg.norm(f-last_f+axis*speed*(t-last_t))))
                previous = (t, phase, f)
        checks.append({'direction': direction, 'check': 'both_knees_forward', 'min_signed_bend': min_bend, 'passed': min_bend > 0})
        checks.append({'direction': direction, 'check': 'support_foot_stationary_in_world', 'max_slip_pixels_per_sample': slip, 'passed': slip < .15})
        source = ROOT/f'art/source/characters/catabase_monsters/sentinelle_airain/base_frame_{direction}.png'
        parts = {p['name']: p for p in build_parts('sentinelle_airain', direction, Image.open(source).convert('RGBA'))}
        vector = np.asarray(parts['hand_right']['weapon_tip'])-parts['hand_right']['pivot']
        # The hand bind axis is +90 degrees in this bridge (a leaf bone).
        local = rotate(-90)@(vector*[1, -1])
        max_angle, tips, roots = 0., [], []
        for t in np.linspace(.28, .4, 13):
            matrices = worlds(data, 'attack', t)
            spear = (matrices['hand_right'][:2, :2]@local)*[1, -1]
            max_angle = max(max_angle, math.degrees(math.acos(float(np.clip(np.dot(spear/np.linalg.norm(spear), axis), -1, 1)))))
            tips.append(screen(matrices['hand_right'])+spear)
            roots.append(screen(matrices['root']))
        travel = np.array(tips)-tips[0]
        axial = travel@axis
        perpendicular = travel@np.array([-axis[1], axis[0]])
        body_drive = float(np.dot(roots[-1]-roots[0], axis))
        checks.append({'direction': direction, 'check': 'spear_aligned_during_drive', 'max_angle_degrees': max_angle, 'passed': max_angle < .05})
        checks.append({'direction': direction, 'check': 'thrust_moves_forward_with_body', 'spear_travel_pixels': float(axial[-1]),
                       'lateral_deviation_pixels': float(np.max(np.abs(perpendicular))), 'body_drive_pixels': body_drive,
                       'passed': axial[-1] > 45 and min(np.diff(axial)) > -.1 and body_drive > 10 and np.max(np.abs(perpendicular)) < 7})
        a, b = worlds(data, 'cast', 0), worlds(data, 'cast', .44)
        shield_motion = float(np.linalg.norm(screen(b['arm_left'])-screen(a['arm_left'])))
        checks.append({'direction': direction, 'check': 'visible_shield_cast', 'elbow_travel_pixels': shield_motion, 'passed': shield_motion > 15})
        no_body = max(alpha(data, 'death', n, .16) for n in body) == 0
        burst_visible = max(alpha(data, 'death', n, .15) for n in fx) > .5
        empty = max(alpha(data, 'death', n, .65) for n in body+fx) == 0
        checks.append({'direction': direction, 'check': 'complete_black_burst_disappearance', 'body_hidden_at_016': no_body,
                       'burst_visible': burst_visible, 'empty_at_065': empty, 'passed': no_body and burst_visible and empty})
    for check in checks:
        check['passed'] = bool(check['passed'])
    report = {'passed': all(c['passed'] for c in checks), 'revision': args.revision, 'checks': checks,
              'scope': 'Motion sampled from actual Spine timelines; artistic quality still requires visual review.'}
    out = ROOT/'artifacts/dev'/f'sentinelle-motion-{time.time_ns()}'
    out.mkdir(parents=True)
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'passed': report['passed'], 'checks': len(checks), 'failed': [c for c in checks if not c['passed']], 'reports': str(out)}))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
