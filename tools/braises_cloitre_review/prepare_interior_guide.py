"""Technical interior plan: floor continues beyond the tactical area, no island outline."""
import json
from PIL import Image, ImageDraw
from prepare import ROOM, OUT

geo=json.loads((ROOM/'geometry_manifest.json').read_text(encoding='utf-8-sig'))
ox,oy=geo['grid_origin']; ax,ay=geo['axis_x']; bx,by=geo['axis_y']
def poly(cell):
    x,y=cell
    return [(ox+(x+dx)*ax+(y+dy)*bx,oy+(x+dx)*ay+(y+dy)*by)
            for dx,dy in [(-.5,-.5),(.5,-.5),(.5,.5),(-.5,.5)]]
im=Image.new('RGB',(1920,1200),'#8e998e'); d=ImageDraw.Draw(im)
# These are architectural zones outside the tactical reserve, not gameplay obstacles.
d.polygon([(0,0),(665,0),(650,90),(160,365),(0,400)],fill='#3d4e59')
d.polygon([(1170,0),(1920,0),(1920,350),(1740,340)],fill='#3d4e59')
for cell in geo['floor_cells']:
    d.polygon(poly(cell),fill='#b2c5ac',outline='#708770')
for obstacle in geo['obstacles']:
    for cell in obstacle['cells']: d.polygon(poly(cell),fill='#836877')
for key,color in [('hero_spawns','#447db0'),('enemy_spawns','#bf7156')]:
    for cell in geo[key]: d.polygon(poly(cell),fill=color)
im.save(OUT/'interior-guide-v2.png')
print(OUT/'interior-guide-v2.png')
