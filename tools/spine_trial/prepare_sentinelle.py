"""Repackage the existing painted rig as Spine 4.2 data for local evaluation.

No source painting or production resource is changed. The shared monster
services own segmentation, joint reconstruction and planted-foot transforms.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/catabase_monster_sprite_pipeline'))
from humanoid_parts import build_parts
from articulated_animation import PaintedSkeleton

OUTPUT = ROOT / 'artifacts/spine_trial/sentinelle'
ANCHOR = np.array([256., 320.])
FLIP = np.diag([1., -1., 1.])


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rotate(degrees):
    a = math.radians(degrees)
    return np.array([[math.cos(a), -math.sin(a)], [math.sin(a), math.cos(a)]])


def wrapped(angle):
    return (angle + 180) % 360 - 180


def r(value):
    return round(float(value), 6)



def pose_matrices(rig, intent):
    transforms = rig.matrices(intent)
    blend = intent.get('floor_blend', 0.)
    if blend:
        if not hasattr(rig, '_floor_hulls'):
            from scipy.spatial import ConvexHull
            rig._floor_hulls = {}
            for part in rig.parts:
                alpha = np.maximum(np.asarray(part['source_image'])[:, :, 3],
                                   np.asarray(part['underpaint'])[:, :, 3])
                yy, xx = np.where(alpha > 40)
                if len(xx) > 3:
                    cloud = np.c_[xx, yy]
                    rig._floor_hulls[part['name']] = np.c_[cloud[ConvexHull(cloud).vertices],
                                                          np.ones(len(ConvexHull(cloud).vertices))]
        bottom = max(float((points @ transforms[name].T)[:, 1].max())
                     for name, points in rig._floor_hulls.items())
        correction = np.eye(3)
        correction[1, 2] = (319. - bottom) * blend
        transforms = {name: correction @ transform for name, transform in transforms.items()}
    return transforms

def encode_animation(rig, ordered, parents, binds, by_bone, poses):
    timelines = {name: {'rotate': [], 'translate': []} for name in ordered}
    max_transform_error = 0.
    previous = {}
    for time, intent in poses:
        matrices = pose_matrices(rig, intent)
        worlds = {}
        for name in ordered:
            # Move the compositor's screen transform to anchor-centred, Y-up space.
            shift = np.eye(3); shift[:2, 2] = ANCHOR
            global_transform = FLIP @ np.linalg.inv(shift) @ matrices[name] @ shift @ FLIP
            worlds[name] = global_transform @ binds[name]
            parent = parents.get(name)
            local = np.linalg.inv(worlds[parent]) @ worlds[name] if parent else worlds[name]
            bone = by_bone[name]
            angle = wrapped(math.degrees(math.atan2(local[1, 0], local[0, 0])) - bone.get('rotation', 0))
            if name in previous:
                angle = previous[name] + wrapped(angle - previous[name])
            previous[name] = angle
            dx, dy = local[:2, 2] - [bone.get('x', 0), bone.get('y', 0)]
            timelines[name]['rotate'].append({'time': time, 'value': r(angle)})
            timelines[name]['translate'].append({'time': time, 'x': r(dx), 'y': r(dy)})
            reconstructed = np.eye(3)
            reconstructed[:2, :2] = rotate(bone.get('rotation', 0) + r(angle))
            reconstructed[:2, 2] = [bone.get('x', 0) + r(dx), bone.get('y', 0) + r(dy)]
            if parent:
                reconstructed = worlds[parent] @ reconstructed
            max_transform_error = max(max_transform_error, float(np.max(np.abs(reconstructed - worlds[name]))))
    if max_transform_error > 0.0001:
        raise ValueError(f'Spine coordinate conversion mismatch: {max_transform_error}')
    return {'bones': timelines}, max_transform_error


def prepare(direction, output_root=None, pose_library=None, part_modifier=None, rig_factory=PaintedSkeleton):
    source = ROOT / f'art/source/characters/catabase_monsters/sentinelle_airain/base_frame_{direction}.png'
    output = (output_root or OUTPUT) / direction
    if (output / 'sentinelle.json').exists():
        raise ValueError(f'Existing Spine work preserved: {output}. Choose a new output directory for another preparation.')
    base = Image.open(source).convert('RGBA')
    source_parts = build_parts('sentinelle_airain', direction, base)
    if part_modifier:
        source_parts = part_modifier(source_parts)
    rig = rig_factory(base, source_parts, 'sentinelle_airain', direction)
    parts = rig.by_name
    pivots = {'root': ANCHOR}
    pivots.update({name: np.array(part['pivot'], dtype=float) for name, part in parts.items()})
    parents = {name: part['parent'] for name, part in parts.items()}
    angles = {'root': 0.}
    for name, part in parts.items():
        target = part.get('end')
        if target is None:
            child = next((p for p in parts.values() if p['parent'] == name), None)
            target = child['pivot'] if child else pivots[name] + [0, -18]
        delta = np.asarray(target) - pivots[name]
        angles[name] = math.degrees(math.atan2(-delta[1], delta[0]))
    ordered = ['root']

    def visit(name):
        if name in ordered:
            return
        visit(parents[name])
        ordered.append(name)

    for name in parts:
        visit(name)
    bones = [{'name': 'root', 'color': '83bdcfff'}]
    binds = {'root': np.eye(3)}
    for name in ordered[1:]:
        parent = parents[name]
        delta = (pivots[name] - pivots[parent]) * [1, -1]
        local = rotate(-angles[parent]) @ delta
        bones.append({'name': name, 'parent': parent, 'x': r(local[0]), 'y': r(local[1]),
                      'rotation': r(wrapped(angles[name] - angles[parent])), 'length': 18, 'color': 'b3cd9aff'})
        bind = np.eye(3)
        bind[:2, :2] = rotate(angles[name])
        bind[:2, 2] = (pivots[name] - ANCHOR) * [1, -1]
        binds[name] = bind
    by_bone = {bone['name']: bone for bone in bones}
    textures = []
    slots = []
    attachments = {}
    for field in ('underpaint', 'source_image'):
        for part in sorted(rig.parts, key=lambda p: p['z']):
            image = part[field]
            box = image.getbbox()
            if not box:
                continue
            name = f"{part['name']}_{field}"
            cropped = image.crop(box)
            textures.append((name, cropped))
            center = np.array([(box[0] + box[2]) / 2, (box[1] + box[3]) / 2])
            offset = rotate(-angles[part['name']]) @ ((center - pivots[part['name']]) * [1, -1])
            slots.append({'name': name, 'bone': part['name'], 'attachment': name})
            attachments[name] = {name: {'x': r(offset[0]), 'y': r(offset[1]),
                                      'rotation': r(-angles[part['name']]),
                                      'width': cropped.width, 'height': cropped.height}}

    # Five gentle whole-body poses exercise the converted hierarchy and IK.
    # This is a rig check, not the rejected estoc or a new approved attack.
    poses = [
        (0., {}),
        (.3, {'root': {'shift': [-4, 2]}, 'angles': {'torso': -3, 'head': 2, 'upper_arm_right': -5, 'arm_right': 3, 'upper_arm_left': 2}}),
        (.6, {'root': {'shift': [5, 1]}, 'angles': {'torso': 4, 'head': -3, 'upper_arm_right': 6, 'arm_right': -4, 'upper_arm_left': -3}}),
        (.9, {'root': {'shift': [2, 1]}, 'angles': {'torso': 1, 'head': -1, 'upper_arm_right': 2, 'upper_arm_left': -1}}),
        (1.2, {}),
    ]
    if pose_library is None:
        for _, intent in poses:
            intent['ik'] = {'leg_left': [0, 0], 'leg_right': [0, 0]}
            intent['world_angles'] = {'foot_left': 0, 'foot_right': 0}
        library = {'controle_articulations': poses}
    else:
        library = pose_library(rig)
    animations = {}
    max_transform_error = 0.
    for name, animation_poses in library.items():
        animations[name], error = encode_animation(rig, ordered, parents, binds, by_bone, animation_poses)
        max_transform_error = max(max_transform_error, error)
    if pose_library is None:
        animations['repos'] = {'bones': {'root': {'translate': [{'time': 0}, {'time': 1.2}]}}}
    data = {'skeleton': {'spine': '4.2.22', 'x': -256, 'y': -64, 'width': 512, 'height': 384,
                         'images': './images/', 'fps': 30},
            'bones': bones, 'slots': slots, 'skins': [{'name': 'default', 'attachments': attachments}],
            'animations': animations}
    images_dir = output / 'images'
    images_dir.mkdir(parents=True)
    width, gutter, x, y, row_height = 2048, 2, 2, 2, 0
    placements = []
    for name, texture in textures:
        if x + texture.width + gutter > width:
            x, y, row_height = gutter, y + row_height + gutter * 2, 0
        placements.append((name, texture, x, y))
        x += texture.width + gutter * 2
        row_height = max(row_height, texture.height)
    atlas = Image.new('RGBA', (width, y + row_height + gutter))
    atlas_lines = ['sentinelle.png', f'size: {atlas.width}, {atlas.height}', 'filter: Linear, Linear', 'pma: false']
    for name, texture, x, y in placements:
        texture.save(images_dir / f'{name}.png')
        atlas.paste(texture, (x, y))
        atlas_lines.extend([name, f'  bounds: {x}, {y}, {texture.width}, {texture.height}'])
    atlas_path = output / 'sentinelle.png'
    atlas.save(atlas_path)
    decoded = Image.open(atlas_path).convert('RGBA')
    for name, texture, x, y in placements:
        if decoded.crop((x, y, x + texture.width, y + texture.height)).tobytes() != texture.tobytes():
            raise ValueError(f'Packed region mismatch: {name}')
    (output / 'sentinelle.atlas').write_text('\n'.join(atlas_lines) + '\n', encoding='utf-8')
    (output / 'sentinelle.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    manifest = {'direction': direction, 'source': source.relative_to(ROOT).as_posix(), 'source_sha256': digest(source),
                'bones': len(bones), 'regions': len(textures), 'atlas_rgba_exact': True,
                'max_transform_error': max_transform_error, 'output': str(output),
                'artistic_status': 'animation_kit_for_review' if pose_library else 'rig_check_only_not_approved_attack', 'editor_roundtrip_verified': False,
                'services': {str(p.relative_to(ROOT)): digest(p) for p in [ROOT / 'tools/catabase_monster_sprite_pipeline/humanoid_parts.py', ROOT / 'tools/catabase_monster_sprite_pipeline/articulated_animation.py', Path(__file__)]}}
    (output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return manifest


if __name__ == '__main__':
    print(json.dumps({'passed': True, 'prepared': [prepare(direction) for direction in ('E', 'N')]}, ensure_ascii=False))
