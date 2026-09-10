"""Check gameplay timing, weapon direction, foot reach and the final floor contact."""
import argparse
import json
import math
import re
import time

import numpy as np
from PIL import Image

from prepare_sentinelle import ROOT, PaintedSkeleton, build_parts, pose_matrices
from sentinelle_kit import DIRECTIONS, DURATIONS, library, pose_for, separate_pauldrons

parser = argparse.ArgumentParser()
parser.add_argument('revision', nargs='?', default='sentinelle_kit_v5')
args = parser.parse_args()
output = ROOT / 'artifacts/spine_trial' / args.revision
report_dir = ROOT / 'artifacts/dev' / f'spine-kit-geometry-{time.time_ns()}'
report_dir.mkdir(parents=True)
checks = []
profile = (ROOT / 'data/visuals/catabase_monsters/sentinelle_airain_sprite_profile.tres').read_text(encoding='utf-8')
for name in ('attack', 'cast'):
    duration = float(re.search(r'&?"' + name + r'": ([\d.]+)', profile)[1])
    checks.append({'check': 'gameplay_duration_' + name, 'passed': duration == DURATIONS[name]})
for direction in DIRECTIONS:
    base = Image.open(ROOT / f'art/source/characters/catabase_monsters/sentinelle_airain/base_frame_{direction}.png').convert('RGBA')
    rig = PaintedSkeleton(base, separate_pauldrons(build_parts('sentinelle_airain', direction, base)), 'sentinelle_airain', direction)
    data = json.loads((output / direction / 'sentinelle.json').read_text(encoding='utf-8'))
    max_error = 0.
    for action, poses in library(rig).items():
        if action == 'death':
            continue
        for _, intent in poses:
            transforms = pose_matrices(rig, intent)
            for side in ('left', 'right'):
                pivot = np.asarray(rig.by_name['foot_' + side]['pivot'])
                actual = (transforms['foot_' + side] @ np.r_[pivot, 1.])[:2]
                target = pivot + np.asarray(intent['ik']['leg_' + side])
                max_error = max(max_error, float(np.linalg.norm(actual - target)))
    checks.append({'direction': direction, 'check': 'foot_targets_all_authored_keys',
                   'max_error_pixels': max_error, 'passed': max_error < .01})
    attack = pose_matrices(rig, pose_for(rig, 'attack', .4))
    part = rig.by_name['hand_right']
    vector = attack['hand_right'][:2, :2] @ (np.asarray(part['weapon_tip']) - np.asarray(part['pivot']))
    desired = np.array([-2 if direction in 'SW' else 2, -1 if direction in 'NW' else 1]) / math.sqrt(5)
    aim_error = math.degrees(math.acos(np.clip(np.dot(vector / np.linalg.norm(vector), desired), -1., 1.)))
    checks.append({'direction': direction, 'check': 'spear_direction_at_release',
                   'angular_error_degrees': aim_error, 'passed': aim_error < .001})
    death = pose_matrices(rig, pose_for(rig, 'death', .8))
    bottom = max(float((points @ death[name].T)[:, 1].max()) for name, points in rig._floor_hulls.items())
    checks.append({'direction': direction, 'check': 'death_floor_contact',
                   'bottom_pixel': bottom, 'passed': abs(bottom - 319) < .001})
    for action, event, at in [('attack', 'attack_release', .4), ('cast', 'cast_release', .44)]:
        keys = data['animations'][action]['events']
        checks.append({'direction': direction, 'check': event, 'passed': keys == [{'time': at, 'name': event}]})
report = {'passed': all(c['passed'] for c in checks), 'revision': args.revision, 'checks': checks,
          'limits': 'Foot constraints measured at authored keys; interpolation between keys and visual quality reviewed in runtimes.'}
(report_dir / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'passed': report['passed'], 'checks': len(checks), 'failed': [c for c in checks if not c['passed']],
                  'max_foot_error': max(c.get('max_error_pixels', 0) for c in checks), 'reports': str(report_dir)}))
raise SystemExit(0 if report['passed'] else 1)
