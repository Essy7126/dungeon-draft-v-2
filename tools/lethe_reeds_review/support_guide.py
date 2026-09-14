"""Technical guide only: reserve the complete tactical floor under opaque coral."""
from PIL import Image, ImageDraw, ImageFilter
from prepare import ROOT, ROOM, OUT
import json

art = Image.open(OUT/'land.png').convert('RGB')
w,h = art.size
geo = json.loads((ROOM/'geometry_manifest.json').read_text(encoding='utf-8-sig'))
mask = Image.new('L', art.size)
draw = ImageDraw.Draw(mask)
ox,oy=geo['grid_origin']; ax,ay=geo['axis_x']; bx,by=geo['axis_y']
for x,y in geo['floor_cells']:
    cx,cy=ox+x*ax+y*bx,oy+x*ay+y*by
    draw.polygon([((cx+dx*ax+dy*bx)*w/1920,(cy+dx*ay+dy*by)*h/1200)
                  for dx,dy in [(-.5,-.5),(.5,-.5),(.5,.5),(-.5,.5)]],fill=255)
mask = mask.filter(ImageFilter.MaxFilter(85))  # about 50 native pixels outward
path=ROOT/'artifacts/dev/lethe-reeds/floor-support-opaque-guide.png'
Image.composite(Image.new('RGB',art.size,'#ef977f'),art,mask).save(path)
print(path)
