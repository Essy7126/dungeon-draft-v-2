"""Arrange accepted pieces as an ImageGen layout reference, without redrawing."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/source/characters/achilles/veilleur_walk_iso_v1'
SRC.mkdir(exist_ok=True)
BASE=ROOT/'art/source/characters/achilles/veilleur_proportions_v1'
sheet=Image.new('RGB',(1536,1024),'white')
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
items=[('core','Core: helmet to hem'),('arm_R','Near arm'),('arm_L','Far arm'),('leg_R','Near leg + boot'),('leg_L','Far leg + boot'),('reference','Complete design reference')]
for i,(name,label) in enumerate(items):
    image=Image.open(BASE/(name+'.png')).convert('RGBA')
    image=image.crop(image.getbbox())
    image.thumbnail((400,445),Image.Resampling.LANCZOS)
    x=i%3*512+(512-image.width)//2;y=i//3*512+52
    sheet.paste(image,(x,y),image)
    ImageDraw.Draw(sheet).text((i%3*512+22,i//3*512+14),label,fill='#333333',font=font)
sheet.save(SRC/'layout_reference_E.png')
(SRC/'work.md').write_text('''# Veilleur — quatre vues de marche, essai en jeu

12 septembre 2026. Demande : décliner la marche E V5 sous E/S/N/W puis essai Godot.
E V5 reste conservée. Trois dessins directionnels propres à créer et contrôler.
Une seule animation : marche ; pas de validation artistique finale implicite.
Mêmes 48 phases / 800 ms, pied d’appui piloté par la distance réelle.
Vues E/S/N/W = bas droite / bas gauche / haut droite / haut gauche. Aucun miroir.
Réutiliser GridData / Pathfinder et la vraie carte forêt pour le laboratoire.
État initial : génération des vues manquantes ; intégration et vérifications à faire.
''',encoding='utf8')
print(SRC/'layout_reference_E.png')
