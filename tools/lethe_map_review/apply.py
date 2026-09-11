"""Apply the calibrated painting to Lethe II only; protect canonical gameplay bytes."""
import hashlib
import json
from pathlib import Path
from PIL import Image
from prepare import ROOT, ROOM, OUT, BASE

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    calibration=json.loads((OUT/'calibration.json').read_text())
    # A later Studio bridge preparation may change the local presentation path.
    assert (BASE/'room.tres').exists()
    assert sha(ROOM/'geometry_manifest.json')==calibration['geometry_sha256']
    plan_path=ROOM/'terrain_plan.json'
    old=json.loads((BASE/'terrain_plan.json').read_text(encoding='utf-8-sig'))
    current=json.loads(plan_path.read_text(encoding='utf-8-sig'))
    image=OUT/'land.png'
    width,height=Image.open(image).size
    texture='res://assets/catabase/combat/lethe_traces_v1/land.png'
    prior=json.loads((OUT/'manifest.json').read_text(encoding='utf-8-sig')) if (OUT/'manifest.json').exists() else {}
    assert current==old or sha(plan_path)==prior.get('plan_sha256'), 'Concurrent plan change'
    plan=json.loads(json.dumps(old))
    plan['land'].update(texture_path=texture,texture_scale=[1920/width,1200/height],texture_repeat=False)
    plan['land']['shader_path']='res://assets/catabase/combat/lethe_traces_v1/living.gdshader'
    plan['world_decor']=[{'id':'lethe_living','scene_path':'res://assets/catabase/combat/lethe_traces_v1/Living.tscn','anchor':[0,0],'layer':'foreground'}]
    plan['allowed_floor_polygon']=calibration['allowed_floor_polygon']
    plan['minimum_floor_margin_px']=30
    # Explicit shoreline traced in painting space; no collision comes from art.
    shore=[[762,130],[952,130],[1434,350],[1434,490],[931,733],[701,733],[274,515],[271,380],[762,130]]
    shore=[[x*1920/1586,y*1200/992] for x,y in shore]
    plan['shorelines']=[{'points':shore,'width':1.0,'color':'#548f7e'}]
    plan['minimum_floor_shore_clearance_native_px']=20
    plan['floor_palette'].update(body='#7d8973',shade='#46574c',light='#bac2a1')
    plan['props_palette'].update(ink='#233d39',top='#a3ae8e',left='#73846f',right='#46574c',highlight='#c3b887')
    # Void remains non-interactive. Its existing vertical edges stay visible,
    # while the obsolete opaque modular backdrop no longer hides the painting.
    plan['pit_palette'].update(floor='#00000000',back_wall='#46574c',left_wall='#354b40')
    plan['metadata'].update(biome='lethe',art_method='image_gen with canonical geometry calibration; engine tiles and props retained',route_stage='Lethe 1/5, expedition II',boat='Same wooden boat, three benches and amber lantern; left mooring, outside combat')
    for key in ['canvas_size','geometry_manifest_path','land_polygon','water','combat_ground_band','ground_details','soil_patches']:
        assert plan[key]==old[key],key
    plan_path.write_text(json.dumps(plan,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    record={'provider':'image_gen built-in','target_room':(ROOM.relative_to(ROOT)/'room.tres').as_posix(),
            'image':texture,'image_size':[width,height],'image_sha256':sha(image),
            'room_sha256':sha(ROOM/'room.tres'),'geometry_sha256':sha(ROOM/'geometry_manifest.json'),
            'plan_sha256':sha(plan_path),
            'geometry_bytes_unchanged':True,'guide':'calibration.png','prompt':'PROMPT.md',
            'native_canvas':[1920,1200],'texture_scale':plan['land']['texture_scale'],
            'validation_status':'pending runtime review'}
    (OUT/'manifest.json').write_text(json.dumps(record,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps(record))

if __name__=='__main__': main()
