"""Export animation previews and a portable kit from the approved-layout PNGs."""
from pathlib import Path
import json,zipfile
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/spine_trial/passe_rive_walk_v3'
DELIVERY=ROOT/'art/source/characters/achilles/passe_rive_walk_v3/delivery'
frames=[Image.open(DELIVERY/'frames'/f'walk_{i:02}.png').convert('RGBA') for i in range(12)]
frames[0].save(DELIVERY/'walk_transparent.png',save_all=True,append_images=frames[1:],duration=100,loop=0,disposal=1,blend=0)
preview=[]
for i,im in enumerate(frames):
    bg=Image.new('RGBA',(320,480),'#253c33')
    d=ImageDraw.Draw(bg)
    d.ellipse((130,417,228,445),fill='#14271f')
    bg.alpha_composite(im)
    preview.append(bg.convert('RGB'))
# One palette for the whole preview prevents per-frame palette flicker.
all_frames=Image.new('RGB',(320*12,480))
for i,im in enumerate(preview):all_frames.paste(im,(i*320,0))
palette=all_frames.quantize(colors=255)
gif=[im.quantize(palette=palette,dither=Image.Dither.FLOYDSTEINBERG) for im in preview]
gif[0].save(OUT/'walk_preview.gif',save_all=True,append_images=gif[1:],duration=100,loop=0,optimize=False,disposal=2)
readme='''Passe-rive — marche E / vue trois-quarts

12 images transparentes de 320 x 480 pixels, 10 images/s, cycle de 1,2 seconde.
Lance à droite anatomique, bouclier à gauche. Ne pas retourner horizontalement.

frames/ : PNG individuels. walk_atlas.png : 4 colonnes x 3 rangées.
walk_transparent.png : PNG animé (APNG), à lire avec un lecteur compatible.
manifest.json : dimensions, pivot et origine des fichiers.
walk_E.tres : ressource SpriteFrames dans le dépôt Catabase, chemin res:// actuel.
godot/ : projet autonome ; ouvrir project.godot puis lancer la scène.

L'animation peinte attend la revue artistique. Le contrôle d'appui du mannequin
Blender ne constitue pas une mesure des pieds de ces dessins.
'''
(DELIVERY/'README.txt').write_text(readme,encoding='utf8')
with zipfile.ZipFile(OUT/'passe_rive_walk_v3.zip','w',zipfile.ZIP_DEFLATED) as z:
    for f in DELIVERY.rglob('*'):
        if f.is_file() and not f.name.endswith('.import'):
            z.write(f,str(f.relative_to(DELIVERY)))
    for f in (OUT/'godot').glob('*'):
        if f.is_file() and not f.name.endswith('.uid'):
            z.write(f,'godot/'+f.name)
with Image.open(OUT/'walk_preview.gif') as gif_check:
    assert gif_check.n_frames==12,gif_check.n_frames
with Image.open(DELIVERY/'walk_transparent.png') as apng:
    assert apng.n_frames==12,apng.n_frames
print(json.dumps({'gif_frames':12,'apng_frames':12,'zip_bytes':(OUT/'passe_rive_walk_v3.zip').stat().st_size}),flush=True)
