from pathlib import Path
from PIL import Image
import json,shutil,zipfile
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/source/characters/achilles/passe_rive_spells_v1'
DEL=SRC/'delivery';OUT=ROOT/'artifacts/spine_trial/passe_rive_spells_v1'
LAB=ROOT/'tools/labs/passe_rive_spells_v1';LAB.mkdir(parents=True,exist_ok=True)
data=json.loads((DEL/'manifest.json').read_text(encoding='utf8'))
shutil.copy2(OUT/'map.png',DEL/'map.png')

def resource(prefix):
    ext=[];sub=[];animations=[]
    for a in data['actions']:
        ext.append(f'[ext_resource type="Texture2D" path="{prefix}{a["atlas"]}" id="{a["id"]}"]')
        entries=[]
        for i,f in enumerate(a['frames']):
            key=f'{a["id"]}_{i}'
            sub.append(f'[sub_resource type="AtlasTexture" id="{key}"]\natlas = ExtResource("{a["id"]}")\nregion = Rect2({i%2*768}, {i//2*768}, 768, 768)')
            entries.append(f'{{"duration": {float(f["duration_ms"])}, "texture": SubResource("{key}")}}')
        animations.append('{"name": &"'+a['id']+'", "loop": false, "speed": 1000.0, "frames": ['+', '.join(entries)+']}')
    ext.append(f'[ext_resource type="Texture2D" path="{prefix}frames/idle.png" id="idle"]')
    animations.append('{"name": &"idle", "loop": true, "speed": 1.0, "frames": [{"duration": 1.0, "texture": ExtResource("idle")}]}')
    entries=[]
    for i,f in enumerate(data['walk']):
        ext.append(f'[ext_resource type="Texture2D" path="{prefix}{f["file"]}" id="walk_{i}"]')
        entries.append(f'{{"duration": 1.0, "texture": ExtResource("walk_{i}")}}')
    animations.append('{"name": &"walk", "loop": true, "speed": 10.0, "frames": ['+', '.join(entries)+']}')
    return f'[gd_resource type="SpriteFrames" load_steps={1+len(ext)+len(sub)} format=3]\n\n'+'\n'.join(ext)+'\n\n'+'\n\n'.join(sub)+'\n\n[resource]\nanimations = ['+',\n'.join(animations)+']\n'

(DEL/'sprite_frames.tres').write_text(resource('res://art/source/characters/achilles/passe_rive_spells_v1/delivery/'),encoding='utf8')
scene='[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="SCRIPT" id="1"]\n\n[node name="PasseRiveSpellLab" type="Node2D"]\nscript = ExtResource("1")\nasset_root = "ASSETS"\n'
(LAB/'PasseRiveSpellsLab.tscn').write_text(scene.replace('SCRIPT','res://tools/passe_rive_spells/PasseRiveLab.gd').replace('ASSETS','res://art/source/characters/achilles/passe_rive_spells_v1/delivery/'),encoding='utf8')
native=OUT/'godot';native.mkdir(exist_ok=True)
shutil.copytree(DEL,native/'assets',dirs_exist_ok=True)
(native/'assets/sprite_frames.tres').write_text(resource('res://assets/'),encoding='utf8')
shutil.copy2(ROOT/'tools/passe_rive_spells/PasseRiveLab.gd',native/'PasseRiveLab.gd')
(native/'PasseRiveLab.tscn').write_text(scene.replace('SCRIPT','res://PasseRiveLab.gd').replace('ASSETS','res://assets/'),encoding='utf8')
(native/'project.godot').write_text('config_version=5\n\n[application]\nconfig/name="Passe-rive — six gestes"\nrun/main_scene="res://PasseRiveLab.tscn"\n\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=770\nwindow/stretch/mode="canvas_items"\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',encoding='utf8')
readme='''PASSE-RIVE — SIX GESTES / ESSAI JOUABLE V1

Dans Godot 4.7.1 : importer godot/project.godot puis F6/F5.
Dans le dépôt principal : tools/labs/passe_rive_spells_v1/PasseRiveSpellsLab.tscn, F6.
Toucher 1–6 ou cliquer un bouton ; flèches/ZQSD déplacer, R replacer, V effets, T ralenti, Espace pause.

6 animations de sorts, 4 dessins chacune. PNG RGBA dans frames/, atlas par sort, SpriteFrames Godot et manifest.json contenant durées, pivot et instant de déclenchement. Cellules 768x768 ; pivot (320,662). Les grandes cellules incluent les marges pour la lance, elles ne représentent pas 768 px de hauteur de personnage. Feuilles sources natives 1254x1254, aucun upscale IA.

Les durées SpriteFrames sont exprimées en millisecondes avec speed=1000. Les événements d'impact sont dans le manifeste, pas intégrés au SpriteFrames. Les scripts de laboratoire montrent comment les synchroniser et ne changent aucune règle de campagne.

Quatre familles canoniques : Frappe, Percée, Tir, Garde. Moisson/Heurt sont deux propositions visuelles. Tir teste une projection de lance ; dessin et effets à valider artistiquement. Une seule direction fixe, pas de miroir. L'idle est une pose de récupération ; la marche vient de V3. Graphismes et armes restent à examiner au ralenti.

Génération : outil ImageGen intégré, six appels + correction ciblée de la Garde. Détourage logiciel autorisé. Prompts et coordonnées sources conservés dans le dépôt. Aucune animation 3D ni interpolation artificielle des membres.
'''
(DEL/'README.txt').write_text(readme,encoding='utf8');(OUT/'README.txt').write_text(readme,encoding='utf8')
idle=Image.open(DEL/'frames/idle.png').convert('RGBA')
for a in data['actions']:
    frames=[idle]+[Image.open(DEL/f['file']).convert('RGBA') for f in a['frames']]+[idle]
    timing=[150]+[f['duration_ms'] for f in a['frames']]+[450]
    frames[0].save(DEL/f'{a["id"]}.apng',save_all=True,append_images=frames[1:],duration=timing,loop=0,disposal=1,blend=0)
    flat=[]
    for im in frames:
        im=im.resize((512,512),Image.Resampling.LANCZOS)
        bg=Image.new('RGBA',(512,512),'#21382f');bg.alpha_composite(im);flat.append(bg.convert('RGB'))
    palette=flat[1].quantize(colors=255)
    gif=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in flat]
    gif[0].save(OUT/f'{a["id"]}.gif',save_all=True,append_images=gif[1:],duration=timing,loop=0,disposal=2)
for name in ['review.html','engine.mjs','preview.mjs']:
    shutil.copy2(ROOT/'tools/passe_rive_spells'/name,OUT/name)
with zipfile.ZipFile(OUT/'passe_rive_spells_v1.zip','w',zipfile.ZIP_DEFLATED) as z:
    for file in DEL.rglob('*'):
        if file.is_file() and file.suffix!='.import':z.write(file,'assets/'+file.relative_to(DEL).as_posix())
    for file in native.rglob('*'):
        if file.is_file() and '.godot' not in file.relative_to(native).parts and file.suffix not in ['.import','.uid']:z.write(file,'godot/'+file.relative_to(native).as_posix())
    z.write(OUT/'README.txt','README.txt')
print(json.dumps({'native_project':str(native/'project.godot'),'main_project_scene':str(LAB/'PasseRiveSpellsLab.tscn'),'archive_bytes':(OUT/'passe_rive_spells_v1.zip').stat().st_size}))
