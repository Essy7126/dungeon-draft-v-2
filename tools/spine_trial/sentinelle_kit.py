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

from sentinelle_motion import DIRECTIONS, DURATIONS, EVENTS, CYCLE_TRAVEL, STANCE, DirectionalSkeleton, pose_for, library
from spine_burst import add_black_burst


def separate_pauldrons(parts):
    """Keep rigid shoulder plates on the torso while the arm bends beneath.

    The segmentation service already separates source paint from joint
    underpaint. Move the two painted plates to independent bones; retain the
    existing joint underpaint on the articulated upper arms.
    """
    from humanoid_parts import _bone_underpaint, _palette
    source = Image.new('RGBA', parts[0]['image'].size)
    for item in parts:
        source.alpha_composite(item['source_image'])
    lookup = {item['name']: item for item in parts}
    torso_pivot = lookup['torso']['pivot']
    plate = _palette(source, [torso_pivot[0], torso_pivot[1]-55], 7)
    sleeve = tuple(max(60, int(channel*.68)) for channel in plate[:3])+(255,)
    result = []
    for original in parts:
        part = dict(original)
        # The original underpaint was clipped to the standing silhouette.
        # Restore the complete hidden limb when a new bend exposes it.
        child_name = part['name'].replace('upper_arm_', 'arm_').replace('leg_', 'shin_')
        endpoint = lookup[child_name]['pivot'] if child_name != part['name'] and child_name in lookup else part.get('end')
        if endpoint is not None and part['name'].startswith(('upper_arm_', 'arm_', 'leg_', 'shin_')):
            part['underpaint'] = part['underpaint'].copy()
            _bone_underpaint(part['underpaint'], source, part['pivot'], endpoint,
                             12 if 'arm_' in part['name'] else 11, sleeve if 'arm_' in part['name'] else None)
        if part['name'].startswith('upper_arm_'):
            cap = dict(part)
            cap['name'] = part['name'].replace('upper_arm_', 'pauldron_')
            cap['parent'] = 'torso'
            cap['underpaint'] = Image.new('RGBA', part['image'].size)
            # Only the shoulder plate stays on the torso. The painted biceps
            # below it must follow the articulated upper arm.
            cap_pixels = np.asarray(part['source_image']).copy()
            arm_pixels = cap_pixels.copy()
            cut = int(part['pivot'][1]+24)
            cap_pixels[cut:, :, 3] = 0
            arm_pixels[:cut, :, 3] = 0
            cap['source_image'] = Image.fromarray(cap_pixels)
            cap['image'] = cap['source_image'].copy()
            cap.pop('end', None)
            part['source_image'] = Image.fromarray(arm_pixels)
            part['image'] = part['underpaint'].copy()
            part['image'].alpha_composite(part['source_image'])
            result.append(cap)
        result.append(part)
    return result

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
        rig_info = {}
        def author(rig):
            rig_info['torso_pivot'] = rig.by_name['torso']['pivot']
            return library(rig)
        manifest = prepare(direction, output, author, separate_pauldrons, DirectionalSkeleton)
        path = output / direction / 'sentinelle.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        # A crossing upper arm must be drawn in front of the torso paint.
        arm_support = [slot for slot in data['slots'] if slot['name'] in
                       ('upper_arm_right_underpaint', 'arm_right_underpaint')]
        data['slots'] = [slot for slot in data['slots'] if slot not in arm_support]
        torso_index = next(i for i, slot in enumerate(data['slots']) if slot['name'] == 'torso_source_image')
        data['slots'][torso_index+1:torso_index+1] = arm_support
        data['events'] = {name: {} for events in EVENTS.values() for _, name in events}
        for action, events in EVENTS.items():
            data['animations'][action]['events'] = [{'time': t, 'name': name} for t, name in events]
        effect = add_black_burst(data, output / direction, rig_info['torso_pivot'])
        data['skeleton']['fps'] = 60
        path.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
        manifest.update(animations=DURATIONS, bones=len(data['bones']), regions=manifest['regions']+1, effect=effect,
                        motion_sha256=digest(Path(__file__).with_name('sentinelle_motion.py')),
                        burst_sha256=digest(Path(__file__).with_name('spine_burst.py')), spine_json_sha256=digest(path),
                        recipe_sha256=digest(Path(__file__)))
        (output / direction / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
        manifests.append(manifest)
    manifest = {'character': 'sentinelle_airain', 'revision': revision, 'directions': list(DIRECTIONS),
                'animations': DURATIONS, 'loop': ['idle', 'walk'], 'events': EVENTS,
                'clips': 24, 'status': 'motion_revision_after_user_feedback',
                'death': 'black_burst_disappearance', 'motion_revision': 6,
                'locomotion': {'cycle_travel_pixels': CYCLE_TRAVEL, 'stance_fraction': STANCE},
                'spine_data': '4.2.22', 'editor_roundtrip_verified': False,
                'gameplay_resources_replaced': False, 'sources': manifests}
    (output / 'kit.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    shutil.copyfile(Path(__file__).with_name('kit_review.html'), output / 'review.html')
    print(json.dumps({'passed': True, 'revision': revision, 'clips': 24, 'output': str(output),
                      'review': f'http://127.0.0.1:8734/files/{revision}/review.html'}))


if __name__ == '__main__':
    main()
