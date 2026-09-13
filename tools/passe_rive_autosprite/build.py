"""Package original exports unchanged; author atlas, contact and timing metadata."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/characters/PasseRive/autosprite_v1'
DIRS = dict(N='up', NE='northeast', E='right', SE='southeast',
            S='down', SW='southwest', W='left', NW='northwest')
FAMILIES = dict(idle='idle', walk='walk', run='run', bow='attack',
                dash='custom_dash', dodge='custom_dodge', hit='custom_hit_react',
                death='custom_death', jump='jump')
SEQUENCES = dict(idle=list(range(25)), walk=list(range(11)), run=list(range(7)),
                 bow=list(range(25)), dash=list(range(25)), dodge=list(range(25)),
                 hit=list(range(25)), death=list(range(6, 25)), jump=list(range(25)))


def contact(image):
    """Midpoint of visible boot soles, never the weapon or whole-image centroid."""
    alpha = image.getchannel('A')
    box = alpha.point(lambda a: 255 if a > 64 else 0).getbbox()
    floor = box[3]
    # Both soles can differ by 40–55 px vertically in an isometric stance.
    points = set()
    for y in range(floor - 70, floor):
        for x in range(256):
            r, g, b, a = image.getpixel((x, y))
            # Neutral dark boots; reject bronze cuffs, bow and quiver.
            if a > 128 and max(r, g, b) < 85 and b >= r - 8 and b >= g - 8:
                points.add((x, y))
    islands = []
    while points:
        seed = points.pop()
        component, stack = [seed], [seed]
        while stack:
            x, y = stack.pop()
            for q in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                if q in points:
                    points.remove(q)
                    component.append(q)
                    stack.append(q)
        if len(component) > 50:
            bottom = max(y for x, y in component)
            sole = [(x, y) for x, y in component if y >= bottom - 3]
            islands.append((len(component), sum(x for x, y in sole)/len(sole), bottom + 1))
    # The legs/trousers above can be larger than the boot: choose the lowest.
    boots = sorted(islands, key=lambda b: b[2], reverse=True)[:2]
    assert boots
    return [round(sum(b[i] for b in boots)/len(boots), 2) for i in [1, 2]], box


def build(source):
    OUT.mkdir(parents=True, exist_ok=True)
    sheets, resources, atlas, geometry = [], [], {}, {}
    for stem, family in FAMILIES.items():
        for direction, suffix in DIRS.items():
            if stem == 'jump' and direction not in ['W', 'SW']:
                continue
            name = f'PasseRive-iso_{family}_{suffix}-v1.png'
            src, target = source / name, OUT / name
            if src.resolve() != target.resolve():
                shutil.copyfile(src, target)
            image = Image.open(target).convert('RGBA')
            assert image.size == (1280, 1280) and image.getpixel((0, 0))[3] == 0
            key, bounds, frames = f'{stem}_{direction}', [], []
            for i in range(25):
                x, y = i % 5 * 256, i // 5 * 256
                pose = image.crop((x, y, x+256, y+256))
                frames.append(pose)
                bounds.append(pose.getchannel('A').getbbox())
                sub = f'{key}_{i}'
                atlas[stem, direction, i] = sub
                resources.append(f'[sub_resource type="AtlasTexture" id="{sub}"]\natlas = ExtResource("{key}")\nregion = Rect2({x}, {y}, 256, 256)\nfilter_clip = true\n')
            reference = 24 if stem in ['bow', 'dash', 'hit', 'jump'] else 0
            anchor, neutral = contact(frames[reference])
            if stem in ['walk', 'run']:
                # A locomotion contact is not a neutral stance: one foot may be
                # airborne or far behind. Keep the centre of the exported rig,
                # and use the ground envelope of a whole cycle, not that foot.
                anchor = [128.0, float(max(bounds[i][3] for i in SEQUENCES[stem]))]
            # Per-clip fixed geometry retains airborne motion and cloth breathing.
            scale = 1.0 if stem in ['walk', 'run'] else round(214 / (neutral[3] - neutral[1]), 5)
            geometry[key] = dict(anchor=anchor, scale=scale, reference_frame=reference)
            sheets.append(dict(stem=stem, direction=direction, file=name,
                               sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                               frame_bounds=bounds))
    clips = []
    for direction in DIRS:
        for stem, indices in SEQUENCES.items():
            source_stem = 'dodge' if stem == 'jump' and direction not in ['W', 'SW'] else stem
            clips.append((stem, direction, source_stem, indices))
            geometry[f'{stem}_{direction}'] = geometry[f'{source_stem}_{direction}']
        for alias, family in dict(attack='bow', guard='dodge', sweep='jump',
                                  volley='bow', bow_piercing='bow', bow_death='bow').items():
            source_stem = 'dodge' if family == 'jump' and direction not in ['W', 'SW'] else family
            clips.append((alias, direction, source_stem, SEQUENCES[family]))
            geometry[f'{alias}_{direction}'] = geometry[f'{source_stem}_{direction}']
    header = [f'[gd_resource type="SpriteFrames" load_steps={1+len(sheets)+len(resources)} format=3]\n']
    for sheet in sheets:
        header.append(f'[ext_resource type="Texture2D" path="res://assets/characters/PasseRive/autosprite_v1/{sheet["file"]}" id="{sheet["stem"]}_{sheet["direction"]}"]')
    definitions = []
    for stem, direction, family, indices in clips:
        entries = ',\n'.join('{"duration": 1.0, "texture": SubResource("'+atlas[family, direction, i]+'")}' for i in indices)
        loop = 'true' if stem in ['idle', 'walk', 'run'] else 'false'
        fps = 12.5 if stem == 'idle' else 25.0
        definitions.append(f'{{"name": &"{stem}_{direction}", "loop": {loop}, "speed": {fps}, "frames": [\n{entries}\n]}}')
    (OUT/'sprite_frames.tres').write_text('\n'.join(header+['']+resources+['[resource]\nanimations = [\n'+',\n'.join(definitions)+'\n]\n']), encoding='utf-8')
    (OUT/'portrait.tres').write_text('[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="res://assets/characters/PasseRive/autosprite_v1/PasseRive-iso_idle_down-v1.png" id="1"]\n\n[resource]\natlas = ExtResource("1")\nregion = Rect2(64, 8, 136, 146)\nfilter_clip = true\n', encoding='utf-8')
    manifest = dict(sheets=sheets, cell_size=[256,256], sequences=SEQUENCES,
                    geometry=geometry, duplicate='custom_hit_react_down-v1 (1) is byte-identical',
                    jump_fallback='Only W and SW supplied; other directions use their native dodge, without mirroring.',
                    grounding='Fixed midpoint of boot soles per clip; neutral body height normalized; no per-frame bounding-box recentering.')
    (OUT/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(dict(sheets=len(sheets), clips=len(clips), atlas_regions=len(resources))))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=OUT)
    build(parser.parse_args().source)
