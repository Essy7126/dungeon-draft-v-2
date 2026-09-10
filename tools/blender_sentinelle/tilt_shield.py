"""Apply the requested diagonal shield hold to the existing approved thrust study."""
import bpy
import json
import math
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STUDY = ROOT / 'art/source/blender/sentinelle_blocking_v1'
FILE = STUDY / 'sentinelle_blocking_v1.blend'
BACKUP = ROOT / 'artifacts/dev/sentinelle-shield-before-20260910'
PATH = 'pose.bones["CTRL_Hand.L"].rotation_euler'


def curves(action):
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                yield from bag.fcurves


def apply():
    if Path(bpy.data.filepath).resolve() != FILE.resolve():
        raise RuntimeError('Unexpected Blender file; no changes applied.')
    rig = bpy.data.objects['Sentinelle_Rig']
    scene = bpy.context.scene
    actions = [bpy.data.actions[n] for n in ('Estoc_Preview', 'Estoc_Blocking')]
    selected = [[fc for fc in curves(a) if fc.data_path == PATH] for a in actions]
    assert all(sorted(fc.array_index for fc in group) == [0, 1, 2] for group in selected)
    assert all(len(fc.keyframe_points) == 9 for group in selected for fc in group)
    BACKUP.mkdir(parents=True, exist_ok=True)
    if not (BACKUP / FILE.name).exists():
        if bpy.data.is_dirty:
            raise RuntimeError('Save or review unsaved scene changes before backing up.')
        shutil.copy2(FILE, BACKUP / FILE.name)
        shutil.copy2(STUDY / 'review/contact_E.png', BACKUP / 'contact_E.png')
    unaffected = [b.name for b in rig.pose.bones if b.name not in ('CTRL_Hand.L', 'Hand.L')]

    def sample():
        result = []
        for action in actions:
            rig.animation_data.action = action
            if action.slots:
                rig.animation_data.action_slot = action.slots[0]
            for i in range(97):
                frame = 1 + i * .25
                scene.frame_set(int(frame), subframe=frame % 1)
                bpy.context.view_layer.update()
                result.append([v for n in unaffected for row in rig.pose.bones[n].matrix for v in row]
                              + list(rig.pose.bones['Hand.L'].head))
        return result

    before = sample()
    for group in selected:
        for fc in group:
            for key in fc.keyframe_points:
                frame = round(key.co.x)
                key.co.y = math.radians((0, -32, -2 if 6 <= frame <= 20 else -10)[fc.array_index])
            fc.update()
    after = sample()
    delta = max(abs(a - b) for old, new in zip(before, after) for a, b in zip(old, new))
    report = {'revision': 'shield-diagonal-1', 'samples': len(after),
              'hand_control_xyz_degrees_guard': [0, -32, -10],
              'hand_control_xyz_degrees_thrust': [0, -32, -2],
              'max_unaffected_bone_matrix_and_grip_delta': delta,
              'technical_passed': delta < 1e-5, 'artistic_approved': False}
    (STUDY / 'shield_tilt_validation.json').write_text(json.dumps(report, indent=2) + '\n')
    rig.animation_data.action = actions[0]
    if actions[0].slots:
        rig.animation_data.action_slot = actions[0].slots[0]
    scene.frame_set(1)
    scene.camera = bpy.data.objects['Camera_E']
    assert report['technical_passed'], report
    print(json.dumps(report))
    # Inspect the live viewport before explicitly saving and refreshing the review.


if __name__ == '__main__':
    apply()
