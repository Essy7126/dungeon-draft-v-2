"""Apply calibrated art only; preserve canonical geometry and original gameplay."""
import hashlib
import json
from PIL import Image, ImageChops, ImageDraw, ImageFilter
from prepare import ROOT, ROOM, OUT, BASE, CANVAS


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')


def material_mask(art, calibration):
    """Authored leaf contours and ground locks, with color confidence only for water."""
    width, height = art.size
    protected = Image.new('L', art.size)
    pd = ImageDraw.Draw(protected)
    assert len(calibration['shore_source']) >= 3, 'Trace the retained dry ground before applying'
    pd.polygon([tuple(p) for p in calibration['shore_source']], fill=255)
    for pocket in calibration.get('water_pockets_source', []):
        pd.polygon([tuple(p) for p in pocket], fill=0)
    for polygon in calibration['rigid_polygons_source']:
        pd.polygon([tuple(p) for p in polygon], fill=255)
    # Framing uses the whole rectangle; motion protection follows the silhouette
    # so the water and lantern reflection beside the hull still move naturally.
    geo = read(ROOM/'geometry_manifest.json')
    ox, oy = geo['grid_origin']
    ax, ay = geo['axis_x']
    bx, by = geo['axis_y']
    for x, y in geo['floor_cells']:
        cx, cy = ox+x*ax+y*bx, oy+x*ay+y*by
        pd.polygon([((cx+dx*ax+dy*bx)*width/1920, (cy+dx*ay+dy*by)*height/1200)
                    for dx, dy in [(-.5,-.5),(.5,-.5),(.5,.5),(-.5,.5)]], fill=255)
    # The lock exceeds the largest displacement, including filtered edge pixels.
    protected = protected.filter(ImageFilter.MaxFilter(11))
    leaves = Image.new('L', art.size)
    ld = ImageDraw.Draw(leaves)
    for polygon in calibration['foliage_contours_source']:
        ld.polygon([tuple(p) for p in polygon], fill=255)
    leaves = leaves.filter(ImageFilter.GaussianBlur(2))
    red, green, blue = art.convert('RGB').split()
    water = ImageChops.subtract(ImageChops.darker(green, blue), red).point(
        lambda value: max(0, min(255, (value-9)*13)))
    water = water.filter(ImageFilter.GaussianBlur(1.2))
    free = ImageChops.invert(protected)
    leaves = ImageChops.multiply(leaves, free)
    water = ImageChops.multiply(ImageChops.multiply(water, free), ImageChops.invert(leaves))
    Image.merge('RGB', (water, leaves, protected)).save(OUT/'material_mask.png')


def main():
    guide = read(OUT/'calibration.json')
    art_calibration = read(OUT/'art_calibration.json')
    assert sha(ROOM/'geometry_manifest.json') == guide['geometry_sha256'], 'Geometry changed'
    plan_path = ROOM/'terrain_plan.json'
    original, current = read(BASE/'terrain_plan.json'), read(plan_path)
    prior_path = OUT/'manifest.json'
    prior = read(prior_path) if prior_path.exists() else {}
    assert current == original or sha(plan_path) == prior.get('plan_sha256'), 'Concurrent plan change'
    image = OUT/'land.png'
    assert sha(image) == art_calibration['image_sha256'], 'New art requires new calibration'
    art = Image.open(image)
    width, height = art.size
    assert list(art.size) == art_calibration['image_size']
    sx, sy = CANVAS[0]/width, CANVAS[1]/height
    material_mask(art, art_calibration)
    texture = 'res://assets/catabase/combat/lethe_reeds_v1/land.png'
    plan = json.loads(json.dumps(original))
    plan['land_polygon'] = [[0,0],[1920,0],[1920,1200],[0,1200]]
    plan['land'] = {'color':'#788673', 'texture_path':texture, 'texture_scale':[sx,sy],
                    'texture_repeat':False,
                    'shader_path':'res://assets/catabase/combat/lethe_reeds_v1/living.gdshader'}
    plan['water'] = {'color':'#16494b'}
    # The accepted painting is traced, including its inlet; a convex guide hull
    # cannot prove that the inner tactical corners rest on dry top-facing stone.
    plan['allowed_floor_polygon'] = [[x*sx,y*sy] for x,y in art_calibration['shore_source']]
    plan['minimum_floor_margin_px'] = 30
    plan['shorelines'] = [{'id':'painted_bank', 'points':[[x*sx,y*sy] for x,y in art_calibration['shore_source']],
                          'closed':True, 'width':1.0, 'color':'#ffffff00'}]
    plan['minimum_floor_shore_clearance_native_px'] = 20
    if art_calibration.get('water_pockets_source'):
        plan['excluded_floor_polygons'] = [
            {'id':f'painted_water_{index}', 'polygon':[[x*sx,y*sy] for x,y in points]}
            for index, points in enumerate(art_calibration['water_pockets_source'])]
        for index, points in enumerate(art_calibration['water_pockets_source']):
            plan['shorelines'].append({'id':f'inner_shore_{index}',
                'points':[[x*sx,y*sy] for x,y in points], 'closed':True,'width':1.0,'color':'#ffffff00'})
    plan['combat_ground_band'] = {'enabled':False}
    plan['floor_palette'].update(body='#77866a', shade='#435846', light='#a4ad85',
                                 bevel_flatten_strength=0.82, painted_steps=0.25)
    plan['props_palette'].update(ink='#253f3d', top='#a3ac86', left='#79896f',
                                 right='#4e6351', highlight='#c3bf92')
    # Existing VOID cells remain visibly flooded even where the safety reserve
    # broadened the painted bank. Platform draws the canonical water boundary.
    plan['pit_palette'].update(floor='#194e4d', back_wall='#4b6457', left_wall='#3b5147')
    plan['world_decor'] = [{'id':'lethe_reeds_living', 'anchor':[0,0], 'layer':'foreground',
                            'scene_path':'res://assets/catabase/combat/lethe_reeds_v1/Living.tscn'}]
    plan['metadata']['current_art_direction'] = {
        'scene':'Les roseaux du tireur — le chenal des roseaux',
        'reference':'res://asset/map/painted/merchant/hall_v1/hall.png',
        'continuity':'res://assets/catabase/combat/lethe_traces_v1/land.png'}
    plan['metadata'].update(biome='lethe', route_stage='expedition V',
        boat='Brown hull, three benches, curved prow, rope and one enclosed amber lantern',
        art_method='Built-in image_gen with canonical floor guide; engine floor and obstacles retained')
    for key in ['canvas_size','geometry_manifest_path','ground_details','soil_patches']:
        assert plan[key] == original[key], key
    write(plan_path, plan)
    fx = {'lamp': {'center':[art_calibration['lamp_center_source'][0]*sx,art_calibration['lamp_center_source'][1]*sy],
                   'radius':[art_calibration['lamp_radius_source'][0]*sx,art_calibration['lamp_radius_source'][1]*sy]},
          'foliage_strength':1.7, 'foliage_speed':0.85}
    write(OUT/'fx.json', fx)
    def rect(value):
        x,y,w,h=value
        return [x*sx,y*sy,w*sx,h*sy]
    x,y,x2,y2=art_calibration['boat_bounds_source']
    visual={'controller':'WorldDecor_lethe_reeds_living', 'boat_region':rect([x,y,x2-x,y2-y]),
            'regions':{name:rect(value) for name,value in art_calibration['review_regions_source'].items()}}
    write(OUT/'visual_review.json', visual)
    record = {'provider':'image_gen built-in',
        'target_room':'res://'+(ROOM.relative_to(ROOT)/'room.tres').as_posix(),
        'image':texture,'image_size':[width,height],'image_sha256':sha(image),
        'provider_source_basename':art_calibration['provider_source_basename'],
        'geometry_sha256':sha(ROOM/'geometry_manifest.json'),'geometry_bytes_unchanged':True,
        'room_before_sha256':sha(BASE/'room.tres'),'plan_sha256':sha(plan_path),
        'guide':'calibration.png','guide_sha256':sha(OUT/'calibration.png'),
        'prompt':'PROMPT-west-bank.md','initial_prompt':'PROMPT.md',
        'art_calibration_sha256':sha(OUT/'art_calibration.json'),
        'material_mask_sha256':sha(OUT/'material_mask.png'),
        'native_canvas':list(CANVAS),'texture_scale':[sx,sy],
        'normalization':'Final built-in output retained byte-for-byte; UV scale only, no crop or postprocessing',
        'validation_status':'pending runtime review'}
    write(prior_path, record)
    print(json.dumps(record))


if __name__ == '__main__':
    main()
