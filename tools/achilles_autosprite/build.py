"""Package supplied PNGs byte-for-byte and author Godot atlas metadata."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/characters/Achilles/autosprite_v1'
DIRECTIONS = dict(N='up', NE='northeast', E='right', SE='southeast',
                  S='down', SW='southwest', W='left', NW='northwest')
FAMILIES = dict(idle='idle', walk='walk', run='run', attack='attack',
                sweep='custom_balayage', bow='custom_tirappuie', hook='custom_crochet_rappel')


def build(source):
    OUT.mkdir(parents=True, exist_ok=True)
    sheets = []
    atlas = {}
    resources = []
    for stem, family in FAMILIES.items():
        for direction, suffix in DIRECTIONS.items():
            version = '-v2' if stem == 'attack' else '-v1'
            if stem == 'idle' and direction == 'N':
                version = ''
            name = f'Achille-iso_{family}_{suffix}{version}.png'
            original = source / name
            image = Image.open(original).convert('RGBA')
            assert image.size == (1280, 1280), name
            assert image.getpixel((0, 0))[3] == 0, name
            target = OUT / name
            if original.resolve() != target.resolve():
                shutil.copyfile(original, target)
            sha = hashlib.sha256(target.read_bytes()).hexdigest()
            key = f'{stem}_{direction}'
            bounds = []
            for frame in range(25):
                x, y = frame % 5 * 256, frame // 5 * 256
                alpha = image.getchannel('A').crop((x, y, x + 256, y + 256))
                bbox = alpha.point(lambda a: 255 if a > 32 else 0).getbbox()
                assert bbox, (name, frame)
                bounds.append(bbox)
                sub = f'{key}_{frame}'
                atlas[stem, direction, frame] = sub
                resources.append(f'[sub_resource type="AtlasTexture" id="{sub}"]\natlas = ExtResource("{key}")\nregion = Rect2({x}, {y}, 256, 256)\nfilter_clip = true\n')
            sheets.append(dict(stem=stem, direction=direction, file=name, sha256=sha,
                               size=[1280, 1280], frame_bounds=bounds))
    # One complete locomotion cycle, removing the duplicated lead-in and extra cycles.
    sequences = dict(idle=list(range(25)), walk=list(range(1, 13)),
                     run=list(range(1, 8)), attack=list(range(25)),
                     sweep=list(range(25)), bow=list(range(25)), hook=list(range(25)))
    clips = []
    for direction in DIRECTIONS:
        for stem, indices in sequences.items():
            clips.append((stem, direction, [(stem, i) for i in indices]))
        for stem in ['bow_piercing', 'bow_death', 'volley']:
            clips.append((stem, direction, [('bow', i) for i in range(25)]))
        clips.append(('dash', direction, [('run', 2), ('run', 3), ('run', 4), ('idle', 0)]))
        for stem, count in [('guard', 4), ('hit', 3), ('death', 4)]:
            clips.append((stem, direction, [('idle', 0)] * count))
    header = [f'[gd_resource type="SpriteFrames" load_steps={1 + len(sheets) + len(resources)} format=3]\n']
    for sheet in sheets:
        header.append(f'[ext_resource type="Texture2D" path="res://assets/characters/Achilles/autosprite_v1/{sheet["file"]}" id="{sheet["stem"]}_{sheet["direction"]}"]')
    definitions = []
    for stem, direction, entries in clips:
        frames = ',\n'.join('{"duration": 1.0, "texture": SubResource("' + atlas[family, direction, i] + '")}' for family, i in entries)
        loop = 'true' if stem in ['idle', 'walk', 'run'] else 'false'
        fps = 12.5 if stem == 'idle' else 25.0
        definitions.append(f'{{"name": &"{stem}_{direction}", "loop": {loop}, "speed": {fps}, "frames": [\n{frames}\n]}}')
    (OUT / 'sprite_frames.tres').write_text('\n'.join(header + [''] + resources + ['[resource]\nanimations = [\n' + ',\n'.join(definitions) + '\n]\n']), encoding='utf-8')
    manifest = dict(source='User supplied AutoSprite export, 2026-09-13',
                    sheets=sheets, cell_size=[256, 256], sequences=sequences,
                    fallbacks=dict(guard='idle + existing guard VFX', hit='idle + existing damage flash',
                                   death='idle + runtime fade', dash='run + idle landing',
                                   bow_piercing='bow', bow_death='bow', volley='bow'))
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(dict(sheets=len(sheets), clips=len(clips), atlas_regions=len(resources), output=str(OUT))))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=OUT)
    build(parser.parse_args().source)
