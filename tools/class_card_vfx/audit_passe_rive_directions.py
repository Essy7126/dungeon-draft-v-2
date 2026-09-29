from pathlib import Path
from PIL import Image
import json,hashlib
G=Path(__file__).resolve().parents[2]
result={}
for gesture in ['kick','pull','incantation','guard','drain','spectral','renew']:
    file='passage' if gesture=='spectral' else gesture
    p=G/f'assets/characters/PasseRive/sprites_s31_{gesture}/{file}.json'
    catalog=json.loads(p.read_text(encoding='utf8'))
    assert set(catalog['views'])=={'E','SE','S','SW','W','NW','N','NE'},gesture
    details={}
    for direction,data in catalog['views'].items():
        texture=G/data['texture'].removeprefix('res://')
        digest=hashlib.sha256(texture.read_bytes()).hexdigest()
        if 'source_sha256' in data:assert digest==data['source_sha256'],(gesture,direction,'hash mismatch')
        w,h=Image.open(texture).size
        for f in data['frames']:
            x,y,rw,rh=f['region']
            assert x>=0 and y>=0 and x+rw<=w and y+rh<=h,(gesture,direction,'region')
        assert data['source_height']>0 and data['width_factor']>0
        details[direction]=dict(texture=data['texture'],sha256=digest,source_height=data['source_height'],frames=len(data['frames']),inherited_status=data.get('status'))
    result[gesture]=details
out=G/'art/source/passe_rive_s31/source_audit.json'
out.write_text(json.dumps(dict(passed=True,gestures=7,views=56,details=result),indent=2),encoding='utf8')
print('PASS: 7 gestures / 56 views; sources, hashes, regions and fixed calibrations.')
