"""Install the well painting; preserve canonical cells and encounter data."""
import hashlib
import json
from PIL import Image
from prepare import ROOT, ROOM, OUT, BASE


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    calibration = json.loads((OUT / 'calibration.json').read_text(encoding='utf-8'))
    assert sha(ROOM / 'geometry_manifest.json') == calibration['geometry_sha256']
    original = json.loads((BASE / 'terrain_plan.json').read_text(encoding='utf-8-sig'))
    current = json.loads((ROOM / 'terrain_plan.json').read_text(encoding='utf-8-sig'))
    prior_path = OUT / 'manifest.json'
    prior = json.loads(prior_path.read_text()) if prior_path.exists() else {}
    assert current == original or sha(ROOM / 'terrain_plan.json') == prior.get('plan_sha256'), 'Concurrent plan change'
    image = OUT / 'land.png'
    assert sha(image) == 'c68aa46a894b1da5af347e5406ffbc40f6842a2def97fb6e1723471efad8aadc', 'Retrace a new painting'
    width, height = Image.open(image).size
    assert (width, height) == (1586, 992)
    sx, sy = 1920 / width, 1200 / height
    prefix = 'res://assets/catabase/combat/puits_descent_v1/'
    plan = json.loads(json.dumps(original))
    plan['land'] = {'color': '#ffffff', 'texture_path': prefix + 'land.png',
                    'texture_scale': [sx, sy], 'texture_repeat': False,
                    'shader_path': prefix + 'living.gdshader'}
    plan['water'] = {'color': '#252936'}
    plan['allowed_floor_polygon'] = calibration['allowed_floor_polygon']
    # Manually traced inner lip on this retained image. Support oracle only.
    bank = [[350,405],[430,304],[690,170],[910,135],[1110,245],[1350,333],
            [1460,417],[1400,494],[1230,605],[1060,680],[940,735],[760,800],
            [650,775],[410,685],[335,560],[330,470],[350,405]]
    plan['shorelines'] = [{'id': 'painted_basalt_ledge', 'points': [[x*sx,y*sy] for x,y in bank],
                          'width': 1.0, 'color': '#ffffff00'}]
    plan['minimum_floor_shore_clearance_native_px'] = 20
    plan['floor_palette'].update(body='#71787a', shade='#3b4852', light='#a6aca7')
    plan['props_palette'].update(ink='#202e37', top='#899391', left='#5b6b73',
                                 right='#374953', highlight='#bd9a5d', bench='#725b42')
    plan['pit_palette'].update(floor='#00000000', back_wall='#3a454d', left_wall='#2c3742')
    plan['world_decor'] = [{'id': 'puits_descent_living', 'anchor': [0,0], 'layer': 'foreground',
                            'scene_path': prefix + 'Living.tscn'}]
    plan['metadata'].update(biome='basalt', route_stage='expedition II — passage du puits',
        current_art_direction={'scene': 'Le pied du puits', 'reference': 'res://asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png'},
        art_method='Built-in image_gen, canonical floor guide, painted basalt/lava/bones; engine geometry preserved')
    for key in ['canvas_size', 'geometry_manifest_path', 'ground_details', 'soil_patches']:
        assert plan[key] == original[key]
    plan_path = ROOM / 'terrain_plan.json'
    plan_path.write_text(json.dumps(plan, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    record = {'provider': 'image_gen built-in', 'target_room': 'res://'+(ROOM.relative_to(ROOT)/'room.tres').as_posix(),
        'image': prefix+'land.png', 'image_size': [width,height], 'image_sha256': sha(image),
        'provider_source_basename': 'exec-28e663ea-702f-4cd3-9eac-3bf76c851fff.png',
        'geometry_sha256': sha(ROOM/'geometry_manifest.json'), 'geometry_bytes_unchanged': True,
        'room_before_sha256': sha(BASE/'room.tres'), 'plan_sha256': sha(plan_path),
        'guide': 'calibration.png', 'guide_sha256': sha(OUT/'calibration.png'), 'prompts': ['PROMPT.md','PROMPT-v2.md'],
        'native_canvas': [1920,1200], 'texture_scale': [sx,sy],
        'normalization': 'Original pixels retained; UV scale only', 'validation_status': 'pending runtime review'}
    prior_path.write_text(json.dumps(record,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps(record))


if __name__ == '__main__':
    main()
