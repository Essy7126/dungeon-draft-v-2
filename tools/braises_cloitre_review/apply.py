"""Bind an immutable original painting to the existing ford geometry."""
import hashlib
import json
from PIL import Image
from prepare import ROOT, ROOM, OUT, BASE

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    calibration = json.loads((OUT/'calibration.json').read_text())
    assert sha(ROOM/'geometry_manifest.json') == calibration['geometry_sha256']
    original = json.loads((BASE/'terrain_plan.json').read_text(encoding='utf-8-sig'))
    current = json.loads((ROOM/'terrain_plan.json').read_text(encoding='utf-8-sig'))
    manifest = OUT/'manifest.json'
    prior = json.loads(manifest.read_text()) if manifest.exists() else {}
    assert current == original or sha(ROOM/'terrain_plan.json') == prior.get('plan_sha256'), 'Concurrent plan change'
    source = OUT/'land.png'
    assert sha(source) == '357c28b6422c06985aefd6758b31ff83dbdd3a3b87aea356db76dc376c4e8cdc', 'Retrace a new source'
    width,height = Image.open(source).size
    assert (width,height) == (1586,992)
    sx,sy = 1920/width,1200/height
    prefix = 'res://assets/catabase/combat/braises_cloitre_v1/'
    plan = json.loads(json.dumps(original))
    plan['land_polygon'] = [[0,0],[1920,0],[1920,1200],[0,1200]]
    plan['combat_ground_band'] = {'enabled':False}
    plan['land'] = {'color':'#ffffff','texture_path':prefix+'land.png','texture_scale':[sx,sy],
                    'texture_repeat':False,'shader_path':prefix+'living.gdshader'}
    plan['water'] = {'color':'#49261f'}
    plan['allowed_floor_polygon'] = calibration['allowed_floor_polygon']
    # Manual continuous courtyard boundary on the retained interior revision.
    # Never a source of gameplay collisions.
    bank = [[0,520],[150,465],[282,421],[329,380],[386,315],[600,246],
            [770,184],[880,184],[950,205],[1060,247],[1160,287],[1250,330],
            [1360,390],[1445,465],[1455,520],[1455,605],[1586,670],
            [1586,992],[550,992],[450,925],[338,850],[215,790],[160,740],
            [60,580],[0,520]]
    plan['shorelines'] = [{'id':'painted_courtyard_limits','points':[[x*sx,y*sy] for x,y in bank],
                           'width':1.0,'color':'#ffffff00'}]
    plan['minimum_floor_shore_clearance_native_px'] = 20
    plan['floor_palette'].update(body='#71787a',shade='#3b4852',light='#a6aca7')
    plan['props_palette'].update(ink='#202e37',top='#899391',left='#5b6b73',right='#374953',highlight='#bd9a5d',bench='#725b42')
    plan['pit_palette'].update(floor='#00000000',back_wall='#3a454d',left_wall='#2c3742')
    plan['world_decor'] = [{'id':'braises_cloitre_living','anchor':[0,0],'layer':'foreground','scene_path':prefix+'Living.tscn'}]
    plan['metadata'].update(biome='basalt',route_stage='expedition IX — braises du cloître',
       current_art_direction={'scene':'Les braises du cloître','reference':'res://asset/map/painted/merchant/hall_v1/hall.png'},
       art_method='Built-in image_gen, approved abyss stone palette and occupancy guide, rock-hewn Greek cloister beside abyss with localized embers; engine geometry preserved')
    for key in ['canvas_size','geometry_manifest_path','ground_details','soil_patches']:
        assert plan[key] == original[key]
    plan_path = ROOM/'terrain_plan.json'
    plan_path.write_text(json.dumps(plan,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    record = {'provider':'image_gen built-in','target_room':'res://'+(ROOM.relative_to(ROOT)/'room.tres').as_posix(),
      'image':prefix+'land.png','image_size':[width,height],'image_sha256':sha(source),
      'provider_source_basename':'exec-bee48266-ddfb-4fae-b02b-586652f9bc2b.png',
      'geometry_sha256':sha(ROOM/'geometry_manifest.json'),'geometry_bytes_unchanged':True,
      'room_before_sha256':sha(BASE/'room.tres'),'plan_sha256':sha(plan_path),
      'guide':'interior-guide-v2.png','guide_sha256':sha(OUT/'interior-guide-v2.png'),'prompts':['PROMPT-v4-abyss.md','PROMPT-v5-clearance.md'],
      'native_canvas':[1920,1200],'texture_scale':[sx,sy],'normalization':'Original pixels retained; UV scale only',
      'validation_status':'pending runtime review'}
    manifest.write_text(json.dumps(record,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps(record))

if __name__ == '__main__': main()
