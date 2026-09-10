"""Package verified render pairs into a synchronized review and native media."""
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'artifacts/dev/sentinelle-armor-v1'
STUDY=ROOT/'art/source/blender/sentinelle_armor_v1'
OUT=STUDY/'review'
WEB=ROOT/'artifacts/spine_trial/sentinelle_armor_v1'
OUT.mkdir(parents=True,exist_ok=True)
WEB.mkdir(parents=True,exist_ok=True)
build=json.loads((STUDY/'build_report.json').read_text())
assert build['technical_passed'] and build['animation_sha256_before']==build['animation_sha256_after']
asset_hashes={}
for variant in ('armor','reference'):
    report=json.loads((SRC/f'{variant}_report.json').read_text())
    assert report['passed'] and len(report['renders'])==100
    stamp=Path(report['file']).stat().st_mtime
    expected={(d,f) for d in 'ESWN' for f in range(1,26)}
    assert {(r['direction'],r['frame']) for r in report['renders']}==expected
    (WEB/variant).mkdir(exist_ok=True)
    for r in report['renders']:
        p=Path(r['path'])
        assert p.stat().st_mtime>=stamp, f'Stale render: {p}'
        with Image.open(p) as im:
            assert im.size==(800,720)
            im.convert('RGB').save(WEB/variant/(p.stem+'.jpg'),quality=92,subsampling=0)
        asset_hashes[variant+'/'+p.name]=hashlib.sha256(p.read_bytes()).hexdigest()

keys=[1,6,10,13,16,25]
labels=['Garde','Charge','Appui','Contact','Freinage','Retour']
font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',17)
title=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',24)
sheet=Image.new('RGB',(1500,1020),(18,28,34))
draw=ImageDraw.Draw(sheet)
draw.text((20,12),'SENTINELLE / HABILLAGE BRONZE / ESTOC',font=title,fill=(231,219,193))
for row,d in enumerate('ESWN'):
    frames=[]
    for f in range(1,26):
        with Image.open(SRC/'armor'/f'{d}_{f:02d}.png') as im:
            frames.append(im.convert('RGB').resize((600,540),Image.Resampling.LANCZOS))
    frames[0].save(OUT/f'estoc_{d}.gif',save_all=True,append_images=frames[1:],duration=[30,30,40]*8+[500],loop=0,disposal=2)
    for col,(f,label) in enumerate(zip(keys,labels)):
        with Image.open(SRC/'armor'/f'{d}_{f:02d}.png') as im:
            sheet.paste(im.convert('RGB').resize((250,225),Image.Resampling.LANCZOS),(col*250,55+row*240))
        draw.text((col*250+8,257+row*240),f'{d} / {label}',font=font,fill=(245,236,219),stroke_width=1,stroke_fill=(20,25,30))
sheet.save(OUT/'poses_four_views.jpg',quality=92)
with Image.open(ROOT/'art/source/characters/catabase_monsters/sentinelle_airain/fixed_views_contact.png') as im:
    im.convert('RGB').save(WEB/'art_reference.jpg',quality=92)
shutil.copy2(ROOT/'tools/blender_sentinelle/armor_review.html',WEB/'review.html')
shutil.copy2(SRC/'armor/E_01.png',OUT/'guard_E.png')
shutil.copy2(SRC/'armor/E_13.png',OUT/'contact_E.png')
manifest={'technical_passed':True,'artistic_approved':False,'renders_per_variant':100,
          'duration_seconds':.8,'release_seconds':.4,'gif_pause_at_end_ms':500,
          'source_blend_sha256':hashlib.sha256((STUDY/'source_pose.blend').read_bytes()).hexdigest(),
          'armor_blend_sha256':hashlib.sha256((STUDY/'sentinelle_armor_v1.blend').read_bytes()).hexdigest(),
          'animation_sha256':build['animation_sha256_after'],'render_sha256':asset_hashes,
          'url':'http://127.0.0.1:8734/files/sentinelle_armor_v1/review.html'}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({k:v for k,v in manifest.items() if k!='render_sha256'}))
