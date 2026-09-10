"""Make labelled review sheets from official-runtime screenshots."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

parser = argparse.ArgumentParser()
parser.add_argument('report_directory', type=Path)
args = parser.parse_args()
font = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 18)
small = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 13)
for action in ('idle', 'walk', 'attack', 'cast', 'hit', 'death'):
    frames = {}
    bounds = []
    for d in ('E', 'S', 'W', 'N'):
        for i in range(5):
            im = Image.open(args.report_directory / f'{action}_{d}_{i}.png').convert('RGB')
            frames[d, i] = im
            raw = np.asarray(im).astype(int)
            # The official player has a flat background; retain all visible art.
            colors, counts = np.unique(raw.reshape(-1, 3), axis=0, return_counts=True)
            background = colors[counts.argmax()]
            mask = np.max(np.abs(raw - background), axis=2) > 30
            mask[:45] = False
            yy, xx = np.where(mask)
            bounds.append([xx.min(), yy.min(), xx.max()+1, yy.max()+1])
    boxes = np.asarray(bounds)
    box = (max(0, boxes[:, 0].min()-12), max(0, boxes[:, 1].min()-12),
           min(im.width, boxes[:, 2].max()+12), min(im.height, boxes[:, 3].max()+12))
    sheet = Image.new('RGB', (1420, 1120), '#12191c')
    draw = ImageDraw.Draw(sheet)
    draw.text((20, 14), f'SENTINELLE / {action.upper()} / Spine 4.2', font=font, fill='#dbc292')
    for row, d in enumerate(('E', 'S', 'W', 'N')):
        for i in range(5):
            tile = frames[d, i].crop(box)
            scale = min(274 / tile.width, 236 / tile.height)
            tile = tile.resize((round(tile.width * scale), round(tile.height * scale)), Image.Resampling.LANCZOS)
            x, y = 18 + i*281, 60 + row*262
            sheet.paste(tile, (x+(274-tile.width)//2, y))
            draw.text((x+8, y+238), f'{d}  ·  {i*25} %', font=small, fill='#c2cbc8')
    sheet.save(args.report_directory / f'sheet_{action}.jpg', quality=93)
print(args.report_directory)
