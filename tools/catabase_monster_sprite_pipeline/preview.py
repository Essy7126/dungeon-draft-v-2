"""Build a local review of the actual exported atlas regions."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FAMILIES = [
    ('sentinelle_airain', "Sentinelle d’airain", '78 PV · 2 PM · Rempart'),
    ('rejeton_braise', 'Rejeton de braise', '42 PV · 3 PM · Feu annoncé'),
    ('molosse_styx', 'Molosse du Styx', '50 PV · 5 PM · Poursuite'),
    ('lamie_lethe', 'Lamie du Léthé', '54 PV · 3 PM · Contrôle'),
]


def main():
    destination = ROOT / 'output/catabase_monsters/review'
    destination.mkdir(parents=True, exist_ok=True)
    font_root = Path('C:/Windows/Fonts')
    title = ImageFont.truetype(str(font_root / 'segoeuib.ttf'), 24)
    subtitle = ImageFont.truetype(str(font_root / 'segoeui.ttf'), 17)
    atlases = [Image.open(ROOT / 'assets/characters/catabase_monsters' / slug / 'atlas_E.png').convert('RGBA') for slug, _, _ in FAMILIES]
    steps = [(0, 700, 'Repos')]
    steps += [(i, 100, 'Marche') for _ in range(2) for i in range(1, 7)]
    steps += [(i, 150, 'Attaque') for i in range(7, 11)]
    steps += [(0, 400, 'Repos')]
    steps += [(i, 190, 'Sort / technique spéciale') for i in range(11, 15)]
    steps += [(15, 240, 'Impact reçu'), (0, 300, 'Repos')]
    steps += [(i, 140 if i < 19 else 1000, 'Mort') for i in range(16, 20)]
    frames = []
    for index, _, action in steps:
        canvas = Image.new('RGB', (1024, 800), '#152126')
        draw = ImageDraw.Draw(canvas)
        for k, (_, name, stats) in enumerate(FAMILIES):
            x, y = (k % 2) * 512, (k // 2) * 400
            draw.rounded_rectangle((x + 8, y + 8, x + 504, y + 392), radius=18, fill='#27363d')
            draw.text((x + 24, y + 21), name, font=title, fill='#ead6ad')
            draw.text((x + 24, y + 54), stats, font=subtitle, fill='#b3c6ca')
            left, top = (index % 4) * 512, (index // 4) * 384
            sprite = atlases[k].crop((left, top, left + 512, top + 384))
            sprite = sprite.resize((450, 338), Image.Resampling.LANCZOS)
            canvas.paste(sprite, (x + 31, y + 60), sprite)
            draw.text((x + 24, y + 362), action, font=subtitle, fill='#e4be73')
        frames.append(canvas)
    frames[0].save(destination / 'monstres_apercu.png')
    frames[0].save(destination / 'monstres_animations.gif', save_all=True, append_images=frames[1:], duration=[duration for _, duration, _ in steps], loop=0, optimize=True)
    print(destination / 'monstres_animations.gif')


if __name__ == '__main__':
    main()
