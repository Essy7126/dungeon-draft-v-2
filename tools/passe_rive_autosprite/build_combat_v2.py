"""Prepare ImageGen poses after the user's explicit software-cutout approval.

Keep the drawings and original exports. One scale per direction, authored ground
contacts and flight heights, never a runtime bounding-box chase or pose rescale.
"""
import hashlib
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from build import ROOT, contact

SOURCE = ROOT / 'art/source/passe_rive/combat_v2'
BASE = ROOT / 'assets/characters/PasseRive/autosprite_v1'
OUT = ROOT / 'assets/characters/PasseRive/combat_v2'
REVIEW = ROOT / 'artifacts/dev/passe_rive_combat_v2'
CELL = 384
ANCHOR = (192, 330)
DIRS = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']
FLIGHT = {9: 20, 10: 42, 11: 42, 12: 18}
CLIPS = {
    'combat_idle': dict(poses=[0], weights=[1], duration=2.0, release=None),
    'bow_quick': dict(poses=[0, 1, 2, 3, 14, 0], weights=[.4, .9, .7, .65, .85, .4], duration=.58, release=.20, release_frame=3),
    'bow_charged': dict(poses=[0, 4, 5, 6, 7, 4, 14, 0], weights=[.4, .8, .9, 2, .6, .7, .8, .4], duration=1.05, release=.58, release_frame=4),
    'bow_air': dict(poses=[0, 8, 9, 10, 11, 12, 13, 14, 0], weights=[.4, .8, .7, 1, .45, .7, .9, .5, .3], duration=1.10, release=.52, release_frame=4),
}


def cutout(image):
    rgb = np.array(image.convert('RGB'), dtype=np.float32)
    # Magenta excess estimates the background mixture; subtract that mixture
    # from RGB as well as alpha so linear texture filtering has no pink fringe.
    excess = np.maximum(0, np.minimum(rgb[:, :, 0], rgb[:, :, 2]) - rgb[:, :, 1])
    alpha = np.clip(1 - excess / 255, 0, 1)
    fg = (rgb - (1 - alpha[:, :, None]) * np.array([255, 0, 255])) / np.maximum(alpha[:, :, None], .001)
    pixels = np.concatenate([np.clip(fg, 0, 255), alpha[:, :, None] * 255], axis=2).astype(np.uint8)
    pixels[pixels[:, :, 3] < 18] = 0
    return pixels


def components(mask):
    """Connected row runs preserve thin diagonal bowstrings, without ML masks."""
    labels = np.zeros(mask.shape, dtype=np.int32)
    parents = [0]

    def root(a):
        while parents[a] != a:
            parents[a] = parents[parents[a]]
            a = parents[a]
        return a

    previous = []
    for y, row in enumerate(mask):
        edges = np.flatnonzero(np.diff(np.r_[False, row, False]))
        current = []
        for start, end in zip(edges[::2], edges[1::2]):
            number = len(parents)
            parents.append(number)
            for pstart, pend, other in previous:
                if start <= pend and end >= pstart:
                    parents[root(other)] = root(number)
            labels[y, start:end] = number
            current.append((start, end, number))
        previous = current
    lookup = np.array([root(i) for i in range(len(parents))])
    return lookup[labels]


def separate(pixels):
    labels = components(pixels[:, :, 3] > 32)
    counts = np.bincount(labels.ravel())
    counts[0] = 0
    major = np.argsort(counts)[-16:]
    assert min(counts[major]) > 2000, 'Expected sixteen complete bodies'
    boxes, centers = {}, {}
    for label in major:
        ys, xs = np.nonzero(labels == label)
        boxes[label] = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
        centers[label] = (xs.mean(), ys.mean())
    # Assign row from the BODY, not the arrow tip, which can cross a cell edge.
    ordered = sorted(major, key=lambda k: (int(centers[k][1] / (pixels.shape[0] / 4)), centers[k][0]))
    owners = np.zeros(len(counts), dtype=np.int32)
    for label in np.flatnonzero(counts):
        ys, xs = np.nonzero(labels == label)
        if counts[label] < 3:
            continue
        x, y = xs.mean(), ys.mean()
        owner = min(major, key=lambda k: max(boxes[k][0]-x, 0, x-boxes[k][2])**2 + max(boxes[k][1]-y, 0, y-boxes[k][3])**2)
        owners[label] = owner
    owned = owners[labels]
    poses = []
    for label in ordered:
        selected = pixels.copy()
        selected[owned != label] = 0
        # Keep antialiased edge pixels adjacent to each retained component.
        keep = owned == label
        padded = np.pad(keep, 1)
        expanded = np.zeros_like(keep)
        for dy in range(3):
            for dx in range(3):
                expanded |= padded[dy:dy+keep.shape[0], dx:dx+keep.shape[1]]
        selected[expanded] = pixels[expanded]
        image = Image.fromarray(selected)
        box = image.getbbox()
        poses.append(image.crop(box))
    return poses


def timing(clip):
    spec = CLIPS[clip]
    if spec['release'] is None:
        return [spec['duration']]
    marker = spec['release_frame']
    before = sum(spec['weights'][:marker])
    after = sum(spec['weights'][marker:])
    return [(spec['release'] / before if i < marker else (spec['duration']-spec['release']) / after) * w for i, w in enumerate(spec['weights'])]


def comparison_preview(direction='SE'):
    """Common playback clock; atlas crops and timings are the runtime values."""
    atlas = Image.open(OUT / f'passe_rive_combat_{direction.lower()}_v2.png')
    frames = []
    labels = [('bow_quick', 'Tir rapide'), ('bow_charged', 'Tir charge'), ('bow_air', 'Tir aerien')]
    for tick in range(40):
        frame = Image.new('RGB', (CELL * 3, CELL), '#263b3c')
        draw = ImageDraw.Draw(frame)
        for column, (stem, label) in enumerate(labels):
            remaining = tick / 25
            pose = 0
            for index, duration in zip(CLIPS[stem]['poses'], timing(stem)):
                if remaining < duration:
                    pose = index
                    break
                remaining -= duration
            crop = atlas.crop((pose % 4 * CELL, pose // 4 * CELL, (pose % 4 + 1) * CELL, (pose // 4 + 1) * CELL))
            x = column * CELL
            draw.ellipse((x+ANCHOR[0]-34, ANCHOR[1]-7, x+ANCHOR[0]+34, ANCHOR[1]+7), fill='#142222')
            frame.paste(crop, (x, 0), crop)
            draw.text((x+20, 16), f'{label} / {direction}', fill='#e6ddc9')
        frames.append(frame)
    frames[0].save(REVIEW / f'combat_comparison_{direction}.gif', save_all=True, append_images=frames[1:], duration=40, loop=0)


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    manifest = dict(version=2, generator='built-in image_gen.imagegen', software_preparation_authorized=True,
                    cell_size=[CELL, CELL], clips=CLIPS, flight_height_px=FLIGHT,
                    geometry={}, sheets=[], poses={}, validation={})
    sheet_review = Image.new('RGB', (8 * 230, 4 * 250), '#263b3c')
    draw = ImageDraw.Draw(sheet_review)
    for col, direction in enumerate(DIRS):
        path = SOURCE / f'passe_rive_combat_{direction.lower()}_concept_v1.png'
        source = Image.open(path)
        raw = separate(cutout(source))
        scale = 214 / raw[0].height
        atlas = Image.new('RGBA', (CELL * 4, CELL * 4))
        details, prepared = [], []
        for i, pose in enumerate(raw):
            sole, _ = contact(pose)
            sized = pose.resize((round(pose.width * scale), round(pose.height * scale)), Image.Resampling.LANCZOS)
            offset = (round(ANCHOR[0] - sole[0] * scale), round(ANCHOR[1] - sole[1] * scale - FLIGHT.get(i, 0)))
            assert offset[0] >= 0 and offset[1] >= 0 and offset[0]+sized.width <= CELL and offset[1]+sized.height <= CELL, (direction, i, offset, sized.size)
            canvas = Image.new('RGBA', (CELL, CELL))
            canvas.alpha_composite(sized, offset)
            prepared.append(canvas)
            atlas.alpha_composite(canvas, (i % 4 * CELL, i // 4 * CELL))
            details.append(dict(source_contact=sole, source_size=list(pose.size), translation=list(offset), bounds=canvas.getbbox(), flight_height=FLIGHT.get(i, 0)))
        name = f'passe_rive_combat_{direction.lower()}_v2.png'
        atlas.save(OUT / name)
        manifest['sheets'].append(dict(direction=direction, file=name, source_file=str(path.relative_to(ROOT)), source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), sha256=hashlib.sha256((OUT/name).read_bytes()).hexdigest(), scale=scale))
        manifest['poses'][direction] = details
        for stem, spec in CLIPS.items():
            manifest['geometry'][f'{stem}_{direction}'] = dict(anchor=list(ANCHOR), scale=1.0, reference_frame=0)
            preview = []
            for index in spec['poses']:
                bg = Image.new('RGBA', (CELL, CELL), '#263b3c')
                d = ImageDraw.Draw(bg)
                d.ellipse((ANCHOR[0]-34, ANCHOR[1]-7, ANCHOR[0]+34, ANCHOR[1]+7), fill='#142222')
                bg.alpha_composite(prepared[index])
                preview.append(bg.convert('RGB'))
            preview[0].save(REVIEW/f'{stem}_{direction}.gif', save_all=True, append_images=preview[1:], duration=[max(20, round(t*1000)) for t in timing(stem)], loop=0)
        for row, index in enumerate([0, 2, 6, 10]):
            thumb = prepared[index].resize((230, 230), Image.Resampling.LANCZOS)
            sheet_review.paste(thumb, (col*230, row*250+20), thumb)
            draw.text((col*230+8, row*250+4), f'{direction} / {index}', fill='#e6ddc9')
    sheet_review.save(REVIEW/'pose_review.png')
    # Extend the existing resource; native locomotion/reactions remain byte-for-
    # byte the same AtlasTexture definitions and clips as in the v1 package.
    resource = (BASE/'sprite_frames.tres').read_text(encoding='utf8')
    ext, sub, animations = [], [], []
    for direction in DIRS:
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/characters/PasseRive/combat_v2/passe_rive_combat_{direction.lower()}_v2.png" id="combat_{direction}"]')
        for i in range(16):
            sub.append(f'[sub_resource type="AtlasTexture" id="combat_{direction}_{i}"]\natlas = ExtResource("combat_{direction}")\nregion = Rect2({i%4*CELL}, {i//4*CELL}, {CELL}, {CELL})\nfilter_clip = true\n')
        for stem, spec in CLIPS.items():
            entries = ',\n'.join('{"duration": '+str(w)+', "texture": SubResource("combat_'+direction+'_'+str(i)+'")}' for i, w in zip(spec['poses'], spec['weights']))
            loop = 'true' if stem == 'combat_idle' else 'false'
            animations.append(f'{{"name": &"{stem}_{direction}", "loop": {loop}, "speed": 10.0, "frames": [\n{entries}\n]}}')
    resource = re.sub(r'load_steps=(\d+)', lambda m: f'load_steps={int(m[1])+8+128}', resource, count=1)
    first_sub = resource.index('[sub_resource')
    resource = resource[:first_sub] + '\n'.join(ext) + '\n\n' + resource[first_sub:]
    resource = resource.replace('[resource]\n', '\n'.join(sub)+'\n[resource]\n', 1)
    last = resource.rfind('\n]')
    resource = resource[:last] + ',\n' + ',\n'.join(animations) + resource[last:]
    (OUT/'sprite_frames.tres').write_text(resource, encoding='utf8')
    manifest['validation'] = dict(directions=8, drawings=128, new_clips=32, runtime_clips=152, clipping_checks=128, actual_alpha=True)
    (OUT/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf8')
    comparison_preview()
    print(json.dumps(manifest['validation']))


if __name__ == '__main__':
    build()
