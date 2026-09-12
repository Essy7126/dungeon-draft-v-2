"""Apply only the art plan. Canonical geometry and room gameplay stay untouched."""
import hashlib
import json
from PIL import Image
from prepare import ROOT, ROOM, OUT, BASE


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    calibration = json.loads((OUT / 'calibration.json').read_text(encoding='utf-8'))
    assert sha(ROOM / 'geometry_manifest.json') == calibration['geometry_sha256']
    plan_path = ROOM / 'terrain_plan.json'
    original = json.loads((BASE / 'terrain_plan.json').read_text(encoding='utf-8-sig'))
    current = json.loads(plan_path.read_text(encoding='utf-8-sig'))
    prior_path = OUT / 'manifest.json'
    prior = json.loads(prior_path.read_text(encoding='utf-8')) if prior_path.exists() else {}
    assert current == original or sha(plan_path) == prior.get('plan_sha256'), 'Concurrent plan change'
    image = OUT / 'land.png'
    assert sha(image) == '0c2ca24fb89da3d514836a16ba1ac0b3144d8940c30d302ed1939b76302ed14e', 'New artwork requires a new shoreline and shader/QA region calibration'
    width, height = Image.open(image).size
    sx, sy = 1920 / width, 1200 / height
    texture = 'res://assets/catabase/combat/lethe_lances_v1/land.png'
    plan = json.loads(json.dumps(original))
    # Full-canvas art includes its water. Do not clip the boat with the old cave bank.
    plan['land_polygon'] = [[0, 0], [1920, 0], [1920, 1200], [0, 1200]]
    plan['land'] = {'color': '#536663', 'texture_path': texture, 'texture_scale': [sx, sy],
                    'texture_repeat': False,
                    'shader_path': 'res://assets/catabase/combat/lethe_lances_v1/living.gdshader'}
    plan['water'] = {'color': '#103f40'}
    plan['allowed_floor_polygon'] = calibration['allowed_floor_polygon']
    plan['minimum_floor_margin_px'] = 30
    # Authored tracing of the visible inner bank in the retained 1586x992 painting.
    # These points validate support only, never create a collision or a walkable tile.
    bank = [[320,307],[520,193],[905,190],[1016,241],[1106,289],[1260,457],
            [1260,562],[1184,660],[1030,743],[913,784],[735,799],[592,772],
            [473,716],[366,558],[322,445],[320,307]]
    assert (width, height) == (1586, 992), 'Retrace shoreline for a different artwork'
    plan['shorelines'] = [{'id': 'painted_bank', 'points': [[x*sx,y*sy] for x,y in bank],
                          'width': 1.0, 'color': '#ffffff00'}]
    plan['minimum_floor_shore_clearance_native_px'] = 20
    plan['combat_ground_band'] = {'enabled': False}
    plan['floor_palette'].update(body='#7d8973', shade='#46574c', light='#bac2a1',
                                 bevel_flatten_strength=0.82, painted_steps=0.25)
    plan['props_palette'].update(ink='#233d39', top='#a3ae8e', left='#73846f',
                                 right='#46574c', highlight='#c3b887', bench='#84744f')
    plan['pit_palette'].update(floor='#00000000', back_wall='#46574c', left_wall='#354b40')
    plan['world_decor'] = [{'id': 'lethe_lances_living', 'anchor': [0,0], 'layer': 'foreground',
                            'scene_path': 'res://assets/catabase/combat/lethe_lances_v1/Living.tscn'}]
    plan['metadata']['current_art_direction'] = {
        'scene': 'Les lances oubliées — amarrage du Léthé',
        'reference': 'res://asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png',
        'continuity': 'res://assets/catabase/combat/lethe_traces_v1/land.png'}
    plan['metadata'].update(biome='lethe', route_stage='expedition III',
        boat='Brown hull, three benches, curved prow, rope and amber lantern; left mooring',
        art_method='Built-in image_gen with canonical floor guide; engine floor and obstacles retained')
    for key in ['canvas_size', 'geometry_manifest_path', 'ground_details', 'soil_patches']:
        assert plan[key] == original[key], key
    plan_path.write_text(json.dumps(plan, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    record = {'provider': 'image_gen built-in', 'target_room': 'res://'+(ROOM.relative_to(ROOT)/'room.tres').as_posix(),
        'image': texture, 'image_size': [width,height], 'image_sha256': sha(image),
        'provider_source_basename': 'exec-c5341e66-be2e-4abc-81ac-f074b0c024dc.png',
        'geometry_sha256': sha(ROOM/'geometry_manifest.json'), 'geometry_bytes_unchanged': True,
        'room_before_sha256': sha(BASE/'room.tres'), 'plan_sha256': sha(plan_path),
        'guide': 'calibration.png', 'guide_sha256': sha(OUT/'calibration.png'), 'prompt': 'PROMPT.md',
        'native_canvas': [1920,1200], 'texture_scale': [sx,sy],
        'normalization': 'Original generated pixels retained, UV scale only; no crop or repaint',
        'validation_status': 'pending runtime review'}
    prior_path.write_text(json.dumps(record,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps(record))


if __name__ == '__main__':
    main()
