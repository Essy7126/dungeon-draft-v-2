"""Copy reviewed atlas pixels into an ordinary Godot SpriteFrames resource."""
from pathlib import Path
import json,shutil,hashlib
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/spine_trial/veilleur_walk_iso_v1'
DEST=ROOT/'assets/characters/Achilles/veilleur_walk_iso_v1'
DEST.mkdir(parents=True,exist_ok=True)
data=json.loads((OUT/'walk_review.json').read_text(encoding='utf8'))
lines=['[gd_resource type="SpriteFrames" load_steps=197 format=3]','']
for d in data['order']:
    shutil.copy2(OUT/f'{d}_atlas.png',DEST/f'{d}_atlas.png')
    lines.append(f'[ext_resource type="Texture2D" path="res://assets/characters/Achilles/veilleur_walk_iso_v1/{d}_atlas.png" id="{d}"]')
for d in data['order']:
    for i in range(48):
        lines.extend(['',f'[sub_resource type="AtlasTexture" id="{d}_{i}"]',f'atlas = ExtResource("{d}")',f'region = Rect2({i%8*512}, {i//8*512}, 512, 512)'])
lines+=['','[resource]','animations = [']
for n,d in enumerate(data['order']):
    entries=',\n'.join(f'{{"duration": 1.0, "texture": SubResource("{d}_{i}")}}' for i in range(48))
    lines.append('{"frames": [\n'+entries+f'\n], "loop": true, "name": &"walk_{d}", "speed": 60.0'+'}'+(',' if n<3 else ''))
lines+= [']','']
(DEST/'walk_frames.tres').write_text('\n'.join(lines),encoding='utf8')
data['frame_resource']='res://assets/characters/Achilles/veilleur_walk_iso_v1/walk_frames.tres'
data['atlas_sha256']={d:hashlib.sha256((DEST/f'{d}_atlas.png').read_bytes()).hexdigest() for d in data['order']}
(DEST/'manifest.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
print(DEST/'walk_frames.tres')
