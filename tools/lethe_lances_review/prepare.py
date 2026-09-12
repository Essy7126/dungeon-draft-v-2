"""Calibrate art against the existing Lethe III geometry, never infer gameplay from pixels."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ROOM = ROOT / 'data/rooms/catabase_routes/route_10ce1ff88330'
OUT = ROOT / 'assets/catabase/combat/lethe_lances_v1'
BASE = ROOT / 'artifacts/dev/lethe-lances/before'

def hull(points):
    points = sorted(set(points))
    def cross(o, a, b):
        return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
    lower, upper = [], []
    for sequence, chain in [(points, lower), (points[::-1], upper)]:
        for p in sequence:
            while len(chain) >= 2 and cross(chain[-2], chain[-1], p) <= 0:
                chain.pop()
            chain.append(p)
    return lower[:-1]+upper[:-1]

def expand(points, radius):
    # Square Minkowski envelope: every full tile has >= radius clearance.
    return hull([(x+dx,y+dy) for x,y in points for dx,dy in
                 [(-radius,-radius),(-radius,radius),(radius,-radius),(radius,radius)]])

def main():
    BASE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    for name in ['room.tres','geometry_manifest.json','terrain_plan.json']:
        dest=BASE/name
        if not dest.exists():
            dest.write_bytes((ROOM/name).read_bytes())
    geo=json.loads((ROOM/'geometry_manifest.json').read_text(encoding='utf-8-sig'))
    ox,oy=geo['grid_origin']; ax,ay=geo['axis_x']; bx,by=geo['axis_y']
    def center(cell):
        x,y=cell
        return ox+x*ax+y*bx,oy+x*ay+y*by
    def polygon(cell):
        x,y=center(cell)
        return [(x+dx*ax+dy*bx,y+dx*ay+dy*by) for dx,dy in
                [(-.5,-.5),(.5,-.5),(.5,.5),(-.5,.5)]]
    floor=[polygon(c) for c in geo['floor_cells']]
    footprint=hull([p for poly in floor for p in poly])
    reserve=expand(footprint,60)
    shore=expand(footprint,100)
    image=Image.new('RGB',(1920,1200),'#123f42'); draw=ImageDraw.Draw(image)
    draw.polygon(shore, fill='#626b62')
    draw.line(shore+[shore[0]],fill='#b5c9a6',width=4)
    draw.polygon(reserve,fill='#8c9881')
    for poly in floor:
        draw.polygon(poly,fill='#adbd9c',outline='#314737')
    for obstacle in geo['obstacles']:
        for cell in obstacle['cells']:
            draw.polygon(polygon(cell),fill='#734854' if obstacle['blocks_sight'] else '#c99152')
    for cells,color in [(geo['hero_spawns'],'#4297dd'),(geo['enemy_spawns'],'#dd5542')]:
        for cell in cells:
            draw.polygon(polygon(cell),fill=color)
    boat=[170,700,450,845]
    draw.ellipse(boat, fill='#9c713e',outline='#e6c080',width=4)
    image.save(OUT/'calibration.png')
    data={'canvas_size':[1920,1200],'allowed_floor_polygon':reserve,
          'shore_polygon':shore,'boat_region':boat,'floor_count':len(floor),
          'room_sha256':hashlib.sha256((ROOM/'room.tres').read_bytes()).hexdigest(),
          'geometry_sha256':hashlib.sha256((ROOM/'geometry_manifest.json').read_bytes()).hexdigest(),
          'legend':'Green cells: engine floor. Red/purple/orange/blue: engine-owned spawns/props. Paint ALL reserve flat, without tiles or props. Brown oval: boat, outside combat.'}
    (OUT/'calibration.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'floor_count':len(floor),'guide':str(OUT/'calibration.png'),'shore':shore}))

if __name__=='__main__': main()
