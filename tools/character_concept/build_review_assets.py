"""Build source-preserving concept comparisons and a real local-correction probe."""
from pathlib import Path
import io, json, zipfile, hashlib, shutil, xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageFont
import numpy as np
from ora_export import render, read_layers

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'art/source/characters/achilles/serment_cendre_concept_v1'
OUT = ROOT / 'artifacts/spine_trial/serment_cendre_concept_v1'
PROBE = OUT / 'correction'; PROBE.mkdir(exist_ok=True)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_bytes(image):
    buffer = io.BytesIO(); image.save(buffer, format='PNG'); return buffer.getvalue()


def save_ora(path, size, layers):
    root = ET.Element('image', {'version':'0.0.3', 'w':str(size[0]), 'h':str(size[1]), 'name':'Veilleur — essai de correction locale'})
    stack = ET.SubElement(root, 'stack')
    merged = Image.new('RGBA', size)
    for _, image, xy in layers:
        merged.alpha_composite(image, xy)
    with zipfile.ZipFile(path, 'w') as archive:
        archive.writestr('mimetype', 'image/openraster', compress_type=zipfile.ZIP_STORED)
        for i, (name, image, xy) in enumerate(reversed(layers)):
            member = f'data/layer{i}.png'
            ET.SubElement(stack, 'layer', {'name':name, 'src':member, 'x':str(xy[0]), 'y':str(xy[1]), 'opacity':'1.0', 'visibility':'visible', 'composite-op':'svg:src-over'})
            archive.writestr(member, png_bytes(image))
        archive.writestr('stack.xml', ET.tostring(root, encoding='UTF-8', xml_declaration=True))
        archive.writestr('mergedimage.png', png_bytes(merged))
        thumbnail = merged.copy(); thumbnail.thumbnail((256,256))
        archive.writestr('Thumbnails/thumbnail.png', png_bytes(thumbnail))


# Isolate a small registered patch. It is deliberately NOT an articulated rig part.
canonical = Image.open(SRC / 'candidate_c.png').convert('RGBA')
box = (541,363,623,442)
body = canonical.copy(); ImageDraw.Draw(body).rectangle((541,363,622,441), fill=(0,0,0,0))
before = canonical.crop(box)
generated = Image.open(SRC / 'brooch_trial_raw.png').convert('RGBA').resize(before.size, Image.Resampling.LANCZOS)
# Keep original perimeter and surrounding cloth; use only the generated inner face.
mask = Image.new('L', before.size); ImageDraw.Draw(mask).ellipse((18,17,64,65), fill=255)
after = Image.composite(generated, before, mask)
after.save(SRC / 'brooch_trial.png')
for label, patch in [('before', before), ('after', after)]:
    save_ora(SRC / f'correction_{label}.ora', canonical.size,
             [('body_reference', body, (0,0)), ('brooch_patch', patch, box[:2])])
baseline = render(SRC / 'correction_before.ora')
corrected = render(SRC / 'correction_after.ora')
assert np.array_equal(np.asarray(baseline), np.asarray(canonical)), 'Lossless split/rebuild failed'
source_layers_before = read_layers(SRC / 'correction_before.ora')[1]
source_layers_after = read_layers(SRC / 'correction_after.ora')[1]
assert np.array_equal(np.asarray(source_layers_before[0][1]), np.asarray(source_layers_after[0][1]))
checks = []
for index, dx in enumerate((0, 6, -6)):
    frames = []
    for name, source in [('before', baseline), ('after', corrected)]:
        canvas = Image.new('RGBA', (1280,1280)); canvas.alpha_composite(source,(13+dx,13))
        target = PROBE / f'{name}_{index:02}.png'; canvas.save(target)
        frames.append(np.asarray(Image.open(target)))
    difference = np.any(frames[0] != frames[1], axis=2)
    allowed = np.zeros(difference.shape, dtype=bool)
    allowed[box[1]+13:box[3]+13, box[0]+13+dx:box[2]+13+dx] = True
    assert difference.any() and not np.any(difference & ~allowed)
    checks.append({'frame':index, 'translation':[dx,0], 'changed_pixels':int(difference.sum()), 'outside_patch_changed':0})
report = {'status':'passed', 'source':'OpenRaster layer images and registered offsets',
          'baseline_matches_original':True, 'body_layer_unchanged':True, 'sequence':checks,
          'scope':'One local patch in three translated fixture frames; no animation or full rig validation.',
          'krita_roundtrip':'pending separate export check',
          'before_sha256':sha(SRC/'correction_before.ora'), 'after_sha256':sha(SRC/'correction_after.ora')}
roundtrip = SRC/'correction_krita_roundtrip.ora'
if roundtrip.exists():
    rebuilt = render(roundtrip)
    assert np.array_equal(np.asarray(corrected),np.asarray(rebuilt)), 'Krita roundtrip is stale or differs'
    assert np.array_equal(np.asarray(corrected),np.asarray(Image.open(PROBE/'krita_after.png').convert('RGBA')))
    report['krita_roundtrip'] = {'passed':True,
        'path':'correction_after.ora -> Krita 5.3.3 -> correction_after.kra -> correction_krita_roundtrip.ora -> exporter',
        'changed_pixels':0,'krita_png_changed_pixels':0,
        'layer_names':[name for name,_,_ in read_layers(roundtrip)[1]]}
(PROBE/'report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
for name, image in [('before',before),('after',after)]:
    image.resize((328,316),Image.Resampling.NEAREST).save(OUT/f'brooch_{name}.png')

# Actual project paints and recorded game screenshots, copied unchanged.
backgrounds = [
 ('sources','Cour des Sources', 'artifacts/catabase_registered_maps_2026-09-05/current_1920x1080/room_01_combat_1920x1080.png',[784,449], 'Capture du jeu du 5 septembre · insertion de comparaison'),
 ('cendres','Porte des Cendres','artifacts/catabase_registered_maps_2026-09-05/current_1920x1080/room_02_combat_1920x1080.png',[784,449], 'Capture du jeu du 5 septembre · insertion de comparaison'),
 ('sanctuaire','Sanctuaire émeraude','asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png',[851,783], 'Peinture du sanctuaire · échelle indicative')]
bgdata = []
for name,title,source,anchor,note in backgrounds:
    shutil.copyfile(ROOT/source, OUT/f'bg_{name}.png')
    im=Image.open(ROOT/source)
    bgdata.append({'id':name,'title':title,'file':f'bg_{name}.png','source':source,'size':list(im.size),'anchor':anchor,'note':note,'sha256':sha(ROOT/source)})

# Fixed-scale construction sheet; no normalization by varying pose bounds.
sheet=Image.new('RGBA',(1536,1024))
for i,x in enumerate((0,564,978)):
    sheet.alpha_composite(Image.open(SRC/f'pose_{i+1}.png').convert('RGBA'),(x,0))
sheet.save(OUT/'construction.png')
flat=Image.new('RGBA',sheet.size,'#1a3035'); flat.alpha_composite(sheet)
flat.convert('RGB').save(OUT/'construction_dark.jpg',quality=94)

if (SRC/'pose_3_v2.png').exists():
    revised=sheet.copy(); revised.paste((0,0,0,0),(978,0,1536,1024))
    twist=Image.open(SRC/'pose_3_v2.png').convert('RGBA')
    # One recorded uniform scale aligns helmet/foot span with the other studies.
    twist=twist.resize((905,905),Image.Resampling.LANCZOS)
    revised.alpha_composite(twist,(820,83))
    revised.save(OUT/'construction_revised.png')

font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',26)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',19)
board=Image.new('RGB',(1500,980),'#12252b'); draw=ImageDraw.Draw(board)
titles=['A · Serment de cendre','B · Cendre liée','C · Veilleur d’airain']
for i,key in enumerate('abc'):
    x=i*500
    draw.text((x+30,25),titles[i],font=font,fill='#e2d8b9')
    img=Image.open(OUT/f'candidate_{key}.png').convert('RGBA')
    show=img.resize((round(img.width*610/img.height),610),Image.Resampling.LANCZOS)
    board.paste(show,(x+(500-show.width)//2,80),show)
    for j,h in enumerate((96,112,128)):
        mini=img.resize((round(img.width*h/img.height),h),Image.Resampling.LANCZOS)
        board.paste(mini,(x+72+j*145-mini.width//2,860-h),mini)
        draw.text((x+47+j*145,880),f'{h} px',font=small,fill='#bbc7c4')
    draw.text((x+30,936),'Piste recommandée' if key=='c' else 'À simplifier davantage',font=small,fill='#bfa66a' if key=='c' else '#9bb1ad')
board.save(OUT/'comparaison.jpg',quality=95)

manifest={'name':'Achille — Veilleur d’airain','working_name':True,'status':'concept_and_static_construction_review',
 'recommended':'c','backgrounds':bgdata,'heights':[96,112,128], 'default_height':112,
 'candidates':[{'id':k,'name':n.split(' · ')[1],'file':f'candidate_{k}.png'} for k,n in zip('abc',titles)],
 'generation':'Built-in ImageGen; original concepts, pose sheet and local brooch correction.',
 'transparency':'Source RGB with painted checkerboard; authorized local rembg birefnet-general-lite extraction.',
 'limits':['Recommandation de concept, acceptation artistique utilisateur en attente.',
 'Photomontages sur captures et peinture du projet, pas une intégration au combat.',
 'Trois poses indépendantes, aucune marche ni animation produite.',
 'La torsion V2 réoriente les deux pieds et le bassin ; le buste effectue une rotation modeste, pas un extrême validé.',
 'La main ouverte ajoute des doigts à la moufle de repos ; une substitution doit être dessinée.',
 'Deux calques dans le test ORA : corps de référence et patch de broche. Pas un personnage entièrement découpé.',
 'La vue de dos et les côtés opposés restent à dessiner.']}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding='utf8')
(SRC/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding='utf8')
print(json.dumps({'assets_ready':True,'correction':report},indent=2))
