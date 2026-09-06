"""Author Le Temple du Serment Noir. Python 3 standard library only; no Godot process.

Geometry is authored here. Re-running updates only this arena package, retaining
existing terrain-plan material/art fields while synchronizing its geometry.
Campaign room copies must be prepared separately through ArenaRuntimeBridge.
"""
from __future__ import annotations
import argparse
from collections import deque
import json
import math
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "data/arenas/black_oath_temple_v1"
RES = "res://data/arenas/black_oath_temple_v1"
ASSET = "res://asset/map/painted/underworld/black_oath_temple_v1"
RUNTIME = "res://battle/painted/registered_terrain"
SIZE = (1920, 1200)
GRID = (18, 18)
ORIGIN = (960.0, 125.0)
AX = (51.6, 25.8)
AY = (-51.6, 25.8)
BAND_WIDTH = 0.42
ART_RESERVE = (320.0, 200.0, 1600.0, 950.0)
# The picture is an interior. Its walls are never clipped to the tactical reserve.
LAND = [(0,0),(1920,0),(1920,1200),(0,1200)]
ALLOWED_FLOOR = [(320,200),(1600,200),(1600,950),(320,950)]
SHORELINE = []
CUTS = set()
PITS = [{"id":"west_ritual_recess", "cells":[[1,8],[2,8],[1,9],[2,9]]},
        {"id":"east_ritual_recess", "cells":[[15,8],[16,8],[15,9],[16,9]]}]
BLOCKS = [(5,3),(12,3),(5,5),(12,5),(5,12),(12,12),(5,14),(12,14)]
HEROES = [(7,14),(8,14),(9,14),(10,14)]
ENEMIES = [(7,3),(8,3),(9,3),(10,3)]
DIRECTIONS = [(-1,0),(1,0),(0,-1),(0,1)]

def rectangle(x0,x1,y0,y1):
    return {(x,y) for y in range(y0,y1+1) for x in range(x0,x1+1)}


def ordered(cells):
    return sorted(cells, key=lambda c:(c[1],c[0]))


def project(point):
    return [round(ORIGIN[k]+point[0]*AX[k]+point[1]*AY[k],8) for k in range(2)]


def polygon(cell):
    return [project((cell[0]+dx,cell[1]+dy)) for dx,dy in [(-.5,-.5),(.5,-.5),(.5,.5),(-.5,.5)]]


def area(points):
    return sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(points,points[1:]+points[:1]))/2


def trace_domain(cells):
    edges = set()
    for x,y in cells:
        corners=[(2*x-1,2*y-1),(2*x+1,2*y-1),(2*x+1,2*y+1),(2*x-1,2*y+1)]
        for a,b in zip(corners,corners[1:]+corners[:1]):
            if (b,a) in edges: edges.remove((b,a))
            else: edges.add((a,b))
    edge_count=len(edges)
    outgoing={a:b for a,b in edges}
    assert len(outgoing)==edge_count, "Ambiguous boundary vertex"
    start=min(outgoing); current=start; loop=[]
    while True:
        loop.append(current)
        current=outgoing.pop(current)
        if current==start: break
    assert not outgoing, "Domain contains a hole or another component"
    simple=[]
    for n,p in enumerate(loop):
        a=loop[n-1]; b=loop[(n+1)%len(loop)]
        if (p[0]-a[0])*(b[1]-p[1]) != (p[1]-a[1])*(b[0]-p[0]):
            simple.append((p[0]/2,p[1]/2))
    assert 0<area(simple)==len(cells) and len(simple)<=128
    return simple,edge_count


def offset_miter_orthogonal(points,width):
    result=[]
    for i,p in enumerate(points):
        a=points[i-1]; b=points[(i+1)%len(points)]
        incoming=(p[0]-a[0],p[1]-a[1]); outgoing=(b[0]-p[0],b[1]-p[1])
        il=math.hypot(*incoming); ol=math.hypot(*outgoing)
        normal_a=(incoming[1]/il,-incoming[0]/il)
        normal_b=(outgoing[1]/ol,-outgoing[0]/ol)
        result.append((p[0]+width*(normal_a[0]+normal_b[0]),p[1]+width*(normal_a[1]+normal_b[1])))
    return result


def point_in(point,poly):
    x,y=point; inside=False
    for a,b in zip(poly,poly[1:]+poly[:1]):
        if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]: inside=not inside
    return inside


def point_segment(point,a,b):
    dx=b[0]-a[0];dy=b[1]-a[1]
    t=max(0,min(1,((point[0]-a[0])*dx+(point[1]-a[1])*dy)/(dx*dx+dy*dy)))
    return math.hypot(point[0]-a[0]-t*dx,point[1]-a[1]-t*dy)


def edges(poly): return list(zip(poly,poly[1:]+poly[:1]))


def segment_distance(a,b,c,d):
    def cross(u,v,w): return (v[0]-u[0])*(w[1]-u[1])-(v[1]-u[1])*(w[0]-u[0])
    if cross(a,b,c)*cross(a,b,d)<0 and cross(c,d,a)*cross(c,d,b)<0: return 0.0
    return min(point_segment(a,c,d),point_segment(b,c,d),point_segment(c,a,b),point_segment(d,a,b))


def poly_distance(a,b): return min(segment_distance(p,q,r,s) for p,q in edges(a) for r,s in edges(b))


def bounds(polygons):
    points=[p for poly in polygons for p in poly]
    return [min(p[0] for p in points),min(p[1] for p in points),max(p[0] for p in points),max(p[1] for p in points)]


def bfs(walkable,start,target=None):
    parents={start:None}; queue=deque([start])
    while queue:
        x,y=queue.popleft()
        for dx,dy in DIRECTIONS:
            nxt=(x+dx,y+dy)
            if nxt in walkable and nxt not in parents:
                parents[nxt]=(x,y);queue.append(nxt)
    route=[]
    if target is not None:
        current=target
        while current is not None:
            route.append(current);current=parents[current]
        route.reverse()
    return parents,route


def make_geometry():
    nave=rectangle(5,12,2,15)
    west_wing=rectangle(1,4,6,11); east_wing=rectangle(13,16,6,11)
    passage=rectangle(6,11,2,15)
    domain=nave|west_wing|east_wing
    pit_cells={tuple(c) for pit in PITS for c in pit["cells"]}
    floor=domain-pit_cells; blocked=set(BLOCKS); walk=floor-blocked
    assert len(domain)==160 and len(floor)==152 and len(blocked)==8
    assert pit_cells<=domain and blocked<=floor and passage<=walk
    assert set(HEROES+ENEMIES)<=walk and not set(HEROES)&set(ENEMIES)
    reached,route=bfs(walk,HEROES[0],ENEMIES[0]); assert set(reached)==walk
    for group in PITS:
        cells={tuple(c) for c in group["cells"]}; assert set(bfs(cells,next(iter(cells)))[0])==cells
    contour,edge_count=trace_domain(domain)
    expanded_grid=offset_miter_orthogonal(contour,BAND_WIDTH)
    expanded=[project(p) for p in expanded_grid]
    floor_polygons=[polygon(c) for c in ordered(floor)]
    assert all(point_in(p,LAND) for p in expanded), "Band leaves Land"
    floor_clearance=min(poly_distance(poly,LAND) for poly in floor_polygons)
    band_clearance=poly_distance(expanded,LAND)
    allowed_clearance=min(poly_distance(poly,ALLOWED_FLOOR) for poly in floor_polygons)
    floor_shore_clearance=None; band_shore_clearance=None
    assert all(point_in(p,ALLOWED_FLOOR) for poly in floor_polygons for p in poly)
    assert min(band_clearance,floor_clearance,allowed_clearance)>=60
    b=bounds([expanded]); assert ART_RESERVE[0]<=b[0] and ART_RESERVE[1]<=b[1] and b[2]<=ART_RESERVE[2] and b[3]<=ART_RESERVE[3]
    obstacles=[]
    for index,cell in enumerate(BLOCKS):
        column=False
        obstacles.append({"id":("east_marker_column" if column else "column_base_%02d"%(index+1)),
            "cells":[list(cell)],"blocks_sight":column,
            "height_px":(54 if column else 30)*51.6/54,
            "scene_path":RUNTIME+"/props/"+("BrokenColumn" if column else "StonePlinth")+".tscn"})
    cell_data=[]
    for y in range(GRID[1]):
        for x in range(GRID[0]):
            cell_data.append({"cell":[x,y],"center_px":project((x,y)),"polygon_px":polygon((x,y)),"floor_rendered":(x,y) in floor})
    anchors=[(6,3),(11,3),(6,14),(11,14)]
    report={"ok":True,"scope":"Independent Python authoring checks, not a Godot/GPU validation",
        "floor_cells":len(floor),"void_cells":GRID[0]*GRID[1]-len(floor),"blocked_cells":len(blocked),
        "walkable_cells":len(walk),"connected_walkable_cells":len(reached),"pit_cells":len(pit_cells),"pit_groups":len(PITS),
        "domain_cells":len(domain),"passage_width_cells":6,"passage_length_cells":14,
        "all_passage_cells_walkable":True,"route_cells":len(route),"hero_to_enemy_route":[list(c) for c in route],
        "boundary_edges":edge_count,"simplified_contour_vertices":len(contour),
        "floor_bounds_px":bounds(floor_polygons),"band_bounds_px":b,
        "minimum_floor_land_clearance_native_px":floor_clearance,
        "minimum_floor_allowed_clearance_native_px":allowed_clearance,
        "minimum_floor_shoreline_clearance_native_px":floor_shore_clearance,
        "minimum_band_shoreline_clearance_native_px":band_shore_clearance,
        "minimum_band_land_clearance_native_px":band_clearance,"art_reserve_native_rect":list(ART_RESERVE)}
    manifest={"arena_id":"black_oath_temple_v1","title":"Le Temple du Serment Noir","display_name":"Le Temple du Serment Noir",
        "geometry_version":1,"image_size":list(SIZE),"grid_size":list(GRID),"grid_origin":list(ORIGIN),"axis_x":list(AX),"axis_y":list(AY),
        "image_offset":[0,0],"image_scale":[1,1],"camera_offset":[0,0],"camera_zoom":1.0,
        "background_path":RES+"/grid_reference.png","tile_footprint":[103.2,51.6],
        "floor_cells":[list(c) for c in ordered(floor)],"corner_cuts":[list(c) for c in ordered(CUTS)],
        "pits":PITS,"obstacles":obstacles,"perimeter_props":[],"hero_spawns":[list(c) for c in HEROES],"enemy_spawns":[list(c) for c in ENEMIES],
        "expected_floor_count":len(floor),"expected_void_count":GRID[0]*GRID[1]-len(floor),"expected_blocked_count":len(blocked),
        "expected_walkable_count":len(walk),"expected_pit_cells":len(pit_cells),"expected_pit_group_count":len(PITS),"expected_perimeter_prop_count":0,
        "calibration_cells":[list(c) for c in anchors],"calibration_pixels":[project(c) for c in anchors],
        "cells":cell_data,"ascii_rows":["".join("." if (x,y) in floor else "X" for x in range(GRID[0])) for y in range(GRID[1])],
        "floor_bounds_px":report["floor_bounds_px"],"outer_contour_grid":[list(p) for p in contour],
        "art_contract":{"native_canvas_size":list(SIZE),"quiet_reserve_rect":list(ART_RESERVE),"combat_band_bounds":b,"world_decor":[],
            "description":"Central nave and two side wings. Six-cell clear aisle; no painted tactical tiles or central column masses. Full-canvas interior, no shore or visible water."},
        "authoring_source":"res://tools/registered_terrain_authoring/generate_black_oath_temple.py","authoring_validation":report}
    return manifest,report,floor,pit_cells,blocked,expanded


def write_arena(manifest):
    paths=[("Script","addons/dungeon_draft_arena_studio/domain/arena_definition.gd","1_arena"),
        ("Script","addons/dungeon_draft_arena_studio/domain/arena_cell_definition.gd","2_cell"),
        ("Script","addons/dungeon_draft_arena_studio/domain/arena_modular_visual_profile.gd","3_modular"),
        ("Script","addons/dungeon_draft_arena_studio/domain/arena_obstacle_definition.gd","4_obstacle"),
        ("Script","addons/dungeon_draft_arena_studio/domain/arena_spawn_definition.gd","5_spawn"),
        ("Script","addons/dungeon_draft_arena_studio/domain/arena_decoration_definition.gd","6_decoration"),
        ("PackedScene","battle/painted/registered_terrain/RegisteredTerrainBattle.tscn","7_battle"),
        ("Resource","data/encounters/catabase_room_05_encounter.tres","8_encounter")]
    text=['[gd_resource type="Resource" script_class="ArenaDefinition" format=3]']
    text += ['[ext_resource type="%s" path="res://%s" id="%s"]'%p for p in paths]
    text += ['[sub_resource type="Resource" id="ModularProfile"]\nscript = ExtResource("3_modular")\ntheme_id = &"forest"\nhybrid_floor_policy = 2\nbase_terrain_id = &"stone"']
    references={"cells":[],"obstacles":[],"decorations":[],"spawns":[]}
    for x,y in manifest["floor_cells"]:
        name=f"Cell_{x}_{y}";references["cells"].append(name)
        text.append(f'[sub_resource type="Resource" id="{name}"]\nscript = ExtResource("2_cell")\ncoordinate = Vector2i({x}, {y})\nterrain_id = &"stone"')
    for obstacle in manifest["obstacles"]:
        for x,y in obstacle["cells"]:
            name=f"Obstacle_{x}_{y}";references["obstacles"].append(name)
            sight=str(obstacle["blocks_sight"]).lower();preset=0 if obstacle["blocks_sight"] else 1
            text.append(f'[sub_resource type="Resource" id="{name}"]\nscript = ExtResource("4_obstacle")\nobstacle_id = &"{obstacle["id"]}"\ncell = Vector2i({x}, {y})\npreset = {preset}\nblocks_line_of_sight = {sight}\nblocks_projectiles = {sight}')
            name=f"Decor_{x}_{y}";references["decorations"].append(name)
            text.append(f'[sub_resource type="Resource" id="{name}"]\nscript = ExtResource("6_decoration")\ndecoration_id = &"{obstacle["id"]}"\nscene_path = "{obstacle["scene_path"]}"\ncell = Vector2i({x}, {y})\nlayer = &"y_sorted_props"')
    for index,cell in enumerate(HEROES+ENEMIES):
        name=f"Spawn_{index}";references["spawns"].append(name)
        text.append(f'[sub_resource type="Resource" id="{name}"]\nscript = ExtResource("5_spawn")\nspawn_id = &"{name}"\nkind = {0 if index<len(HEROES) else 3}\ncell = Vector2i({cell[0]}, {cell[1]})')
    main=['[resource]','script = ExtResource("1_arena")','arena_id = &"black_oath_temple_v1"',
        'display_name = "Le Temple du Serment Noir"','room_name = "Catabase V — Le Temple du Serment Noir"',
        f'registered_terrain_plan_path = "{RES}/terrain_plan.json"','visual_mode = 2','theme_id = &"forest"',
        'modular_visual_profile = SubResource("ModularProfile")',f'background_path = "{RES}/grid_reference.png"',
        'source_image_size = Vector2i(1920, 1200)','grid_size = Vector2i(18, 18)',
        'grid_origin = Vector2(960, 125)','axis_x = Vector2(51.6, 25.8)','axis_y = Vector2(-51.6, 25.8)',
        'image_offset = Vector2(0, 0)','image_scale = Vector2(1, 1)','camera_offset = Vector2(0, 0)','camera_zoom = 1.0',
        f'presentation_profile_path = "{RES}/presentation.tres"','battle_scene = ExtResource("7_battle")',
        'encounter_definition = ExtResource("8_encounter")','minimum_wave_count = 1','maximum_wave_count = 1',
        'production_notes = "Central nave with two side wings; 152 real stone tiles, two symmetric four-cell recesses and eight low column bases. Six-cell clear aisle. Full-canvas interior; no separate cosmetic decor. Runtime projections are prepared separately."']
    for key,typ in [("calibration_cells","Vector2i"),("calibration_pixels","Vector2")]:
        entries=', '.join(f'{typ}({p[0]}, {p[1]})' for p in manifest[key])
        main.append(f'{key} = Array[{typ}]([{entries}])')
    for key,ref in [("cells","2_cell"),("obstacles","4_obstacle"),("decorations","6_decoration"),("spawns","5_spawn")]:
        entries=', '.join(f'SubResource("{name}")' for name in references[key])
        main.append(f'{key} = Array[ExtResource("{ref}")]([{entries}])')
    text.append('\n'.join(main));(PACKAGE/'arena.tres').write_text('\n\n'.join(text)+'\n',encoding='utf-8')


def write_plan(report):
    target=PACKAGE/'terrain_plan.json'
    plan=json.loads(target.read_text(encoding='utf-8-sig')) if target.exists() else {
        "version":1,"water":{"color":"#111218","texture_path":"","shader_path":""},
        "land":{"color":"#272833","texture_path":ASSET+"/temple_composed.png","texture_scale":[1,1],"texture_repeat":False,"tint":"#ffffff"},
        "floor_palette":{"shade":"#30303a","body":"#60606b","light":"#929099","warmth":[-.035,-.01,.015,.03],"painted_steps":.18,"bevel_flatten_strength":.92,"shader_parameters":{"interior_joint_land_weight":0.0}},
        "props_palette":{},"pit_palette":{"floor":"#101118","back_wall":"#383641","left_wall":"#292a35","depth_native_px":16},
        "combat_ground_band":{"enabled":True,"width_cells":BAND_WIDTH,"minimum_shore_clearance_native_px":20.0,"shader_path":RUNTIME+"/shaders/combat_ground_band.gdshader","shader_parameters":{"band_earth":"#45434d","band_light":"#53505b","band_shadow":"#353540"}},
        "world_decor":[],"ground_details":{"enabled":False,"mode":"contacts_only"},"soil_patches":[]}
    plan["combat_ground_band"]["width_cells"] = BAND_WIDTH
    # Only geometry fields are regenerated after the art handoff.
    plan.update({"canvas_size":list(SIZE),"geometry_manifest_path":"geometry_manifest.json",
        "land_polygon":LAND,"allowed_floor_polygon":ALLOWED_FLOOR,"excluded_floor_polygons":[],
        "minimum_floor_margin_px":60.0,
        "shorelines":[],
        "authoring_geometry":{"source":"res://tools/registered_terrain_authoring/generate_black_oath_temple.py","art_reserve_native_rect":list(ART_RESERVE),"measured_band_bounds_native":report["band_bounds_px"],"minimum_band_to_bank_native_px":report["minimum_band_shoreline_clearance_native_px"]}})
    target.write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


def write_presentation():
    profiles=[('elf','elf'),('mage','mage'),('warrior','warrior'),('achilles','achilles'),('standard','skeleton_standard'),('elite','skeleton_elite')]
    lines=['[gd_resource type="Resource" script_class="BattlePresentationProfile" format=3]',
        '[ext_resource type="Script" path="res://data/maps/painted/battle_presentation_profile.gd" id="profile"]',
        '[ext_resource type="Script" path="res://data/maps/painted/unit_visual_profile.gd" id="unit_profile"]']
    lines += [f'[ext_resource type="Resource" path="res://data/maps/painted/unit_profile_{path}.tres" id="{name}"]' for name,path in profiles]
    lines += ['[resource]','script = ExtResource("profile")','profile_id = &"black_oath_temple_v1"','camera_zoom_multiplier = 1.0','camera_offset_adjustment = Vector2(160, 0)','camera_keep_painting_in_view = true','global_unit_scale_multiplier = 1.08',
        'unit_profiles = Array[ExtResource("unit_profile")](['+', '.join(f'ExtResource("{name}")' for name,_ in profiles)+'])',
        'ally_outline_color = Color(0.63, 0.9, 1, 0.34)','enemy_outline_color = Color(1, 0.77, 0.39, 0.38)']
    (PACKAGE/'presentation.tres').write_text('\n'.join(lines)+'\n',encoding='utf-8')


def write_guides(floor,pits,blocked,expanded):
    width,height=SIZE; pixels=bytearray(bytes((77,128,131))*(width*height))
    def fill(poly,color):
        for y in range(max(0,math.floor(min(p[1] for p in poly))),min(height,math.ceil(max(p[1] for p in poly)))):
            yy=y+.5; xs=[]
            for a,b in edges(poly):
                if (a[1]>yy)!=(b[1]>yy): xs.append(a[0]+(yy-a[1])*(b[0]-a[0])/(b[1]-a[1]))
            xs.sort()
            for left,right in zip(xs[::2],xs[1::2]):
                first=max(0,math.ceil(left-.5));last=min(width,math.ceil(right-.5))
                if last>first: pixels[(y*width+first)*3:(y*width+last)*3]=bytes(color)*(last-first)
    def line(a,b,color):
        steps=max(1,int(max(abs(b[0]-a[0]),abs(b[1]-a[1]))))
        for n in range(steps+1):
            x=round(a[0]+(b[0]-a[0])*n/steps);y=round(a[1]+(b[1]-a[1])*n/steps)
            if 0<=x<width and 0<=y<height: pixels[(y*width+x)*3:(y*width+x)*3+3]=bytes(color)
    def svg_poly(poly,color): return '<polygon points="'+' '.join(f'{p[0]:.3f},{p[1]:.3f}' for p in poly)+f'" fill="{color}" stroke="#647166" stroke-width="1"/>'
    svg=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">','<rect width="1920" height="1200" fill="#4d8083"/>']
    fill(LAND,(160,170,137));svg.append(svg_poly(LAND,'#a0aa89'))
    fill(expanded,(191,179,147));svg.append(svg_poly(expanded,'#bfb393'))
    for cell in ordered(floor|pits):
        color=(39,58,60) if cell in pits else ((205,152,99) if cell in blocked else (225,218,192))
        poly=polygon(cell);fill(poly,color)
        for a,b in edges(poly):line(a,b,(100,113,102))
        svg.append(svg_poly(poly,'#%02x%02x%02x'%color))
    for cells,label,color in [(HEROES,'H','#456dad'),(ENEMIES,'E','#b95550')]:
        for cell in cells:
            p=project(cell);svg.append(f'<circle cx="{p[0]}" cy="{p[1]}" r="6" fill="{color}"/><text x="{p[0]+9}" y="{p[1]+5}" fill="{color}" font-size="15">{label}</text>')
            fill([(p[0]-5,p[1]-5),(p[0]+5,p[1]-5),(p[0]+5,p[1]+5),(p[0]-5,p[1]+5)],(69,109,173) if label=='H' else (185,85,80))
    svg.append('</svg>');(PACKAGE/'grid_reference.svg').write_text('\n'.join(svg)+'\n',encoding='utf-8')
    def chunk(name,data):return struct.pack('!I',len(data))+name+data+struct.pack('!I',zlib.crc32(name+data)&0xffffffff)
    scan=b''.join(b'\0'+pixels[y*width*3:(y+1)*width*3] for y in range(height))
    png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!IIBBBBB',width,height,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(scan,8))+chunk(b'IEND',b'')
    (PACKAGE/'grid_reference.png').write_bytes(png)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--validate-only',action='store_true');parser.add_argument('--terrain-only',action='store_true');args=parser.parse_args()
    manifest,report,floor,pits,blocked,expanded=make_geometry()
    if not args.validate_only:
        PACKAGE.mkdir(parents=True,exist_ok=True)
        (PACKAGE/'geometry_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        (PACKAGE/'authoring_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        if not args.terrain_only:
            write_arena(manifest);write_presentation()
        write_plan(report);write_guides(floor,pits,blocked,expanded)
    print(json.dumps(report,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
