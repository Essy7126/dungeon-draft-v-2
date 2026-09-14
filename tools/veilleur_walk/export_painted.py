"""Extract once; subsequently rebuild the walk from editable OpenRaster layers.

The 362-pixel source cells share one camera. No per-pose bounding-box resizing.
Software background removal and sprite processing are authorized for this project.
"""
from pathlib import Path
import os, sys, json, io, zipfile, hashlib, xml.etree.ElementTree as ET
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'art/source/characters/achilles/veilleur_walk_E_v1'
OUT = ROOT / 'artifacts/spine_trial/veilleur_walk_E_v1'
sys.path.insert(0, str(ROOT / 'tools/character_concept'))
from ora_export import read_layers

def png(image):
    buffer = io.BytesIO()
    image.save(buffer, format='PNG')
    return buffer.getvalue()

source = SRC / 'painted_frames.ora'
if not source.exists():
    os.environ['U2NET_HOME'] = str(ROOT / 'artifacts/dev-tools/rembg-models')
    os.environ['OMP_NUM_THREADS'] = '4'
    from rembg import remove, new_session
    session = new_session('birefnet-general-lite', providers=['CPUExecutionProvider'])
    raw = Image.open(SRC / 'cleanup_sheet_raw.png').convert('RGB')
    assert raw.width % 4 == 0 and raw.height % 3 == 0
    w, h = raw.width // 4, raw.height // 3
    assert w == h
    folder = SRC / 'painted_cells'
    folder.mkdir(exist_ok=True)
    layers = []
    for i in range(12):
        path = folder / f'{i:02}.png'
        if not path.exists():
            x, y = (i % 4) * w, (i // 4) * h
            clean = remove(raw.crop((x, y, x+w, y+h)), session=session, decontaminate=True)
            pixels = np.asarray(clean).copy()
            labels, _ = ndimage.label(pixels[:, :, 3] > 32)
            counts = np.bincount(labels.ravel()); counts[0] = 0
            assert counts.max() > 1000
            keep = ndimage.binary_dilation(labels == counts.argmax(), iterations=2)
            pixels[~keep] = 0
            pixels[pixels[:, :, 3] < 5] = 0
            Image.fromarray(pixels).save(path)
        layers.append(Image.open(path).convert('RGBA'))
        print(f'CUTOUT {i+1}/12', flush=True)
    root = ET.Element('image', {'version':'0.0.3', 'w':str(raw.width), 'h':str(raw.height), 'name':'Veilleur — douze dessins de marche E'})
    stack = ET.SubElement(root, 'stack')
    merged = Image.new('RGBA', raw.size)
    with zipfile.ZipFile(source, 'w') as archive:
        archive.writestr('mimetype', 'image/openraster', compress_type=zipfile.ZIP_STORED)
        for i, layer in enumerate(layers):
            x, y = (i % 4) * w, (i // 4) * h
            member = f'data/pose_{i:02}.png'
            ET.SubElement(stack, 'layer', {'name':f'pose_{i:02}', 'src':member, 'x':str(x), 'y':str(y), 'opacity':'1.0', 'visibility':'visible', 'composite-op':'svg:src-over'})
            archive.writestr(member, png(layer))
            merged.alpha_composite(layer, (x, y))
        archive.writestr('stack.xml', ET.tostring(root, encoding='UTF-8', xml_declaration=True))
        archive.writestr('mergedimage.png', png(merged))
        thumb = merged.copy(); thumb.thumbnail((256, 256))
        archive.writestr('Thumbnails/thumbnail.png', png(thumb))

# The ORA is the actual rebuild input, including offsets after native retouching.
size, layers = read_layers(source)
assert size[0] % 4 == 0 and size[1] % 3 == 0
w, h = size[0] // 4, size[1] // 3
assert w == h
assert {name for name, _, _ in layers} == {f'pose_{i:02}' for i in range(12)}
indexed = {name:(image, xy) for name, image, xy in layers}
frame_dir = OUT / 'painted_frames'; frame_dir.mkdir(exist_ok=True)
frames, checks = [], []
for i in range(12):
    image, xy = indexed[f'pose_{i:02}']
    cell = Image.new('RGBA', (w,h))
    cell.alpha_composite(image, (xy[0]-(i%4)*w, xy[1]-(i//4)*h))
    bbox = cell.getchannel('A').getbbox()
    assert bbox and min(bbox[:2]) > 1 and bbox[2] < w-1 and bbox[3] < h-1, (i,bbox)
    # Uniform enlargement for compatibility with the guide's 512-square camera.
    frame = cell.convert('RGBa').resize((512,512), Image.Resampling.LANCZOS).convert('RGBA')
    frame.save(frame_dir / f'{i:02}.png')
    frames.append(frame)
    checks.append({'frame':i,'native_cell_size':[w,h],'source_bbox':bbox,'unclipped':True,'visible_pixels':int(np.sum(np.asarray(cell)[:,:,3]>32))})

atlas = Image.new('RGBA',(2048,1536))
for i, frame in enumerate(frames): atlas.alpha_composite(frame,((i%4)*512,(i//4)*512))
atlas.save(OUT/'painted_walk_E_atlas.png')
durations = [92,92,91]*4  # Exactly 1100 ms, without a duplicated final pose.
frames[0].save(OUT/'painted_walk_E.png',save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=0,blend=0)
frames[0].save(OUT/'painted_walk_E.webp',save_all=True,append_images=frames[1:],duration=durations,loop=0,lossless=True)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
board = Image.new('RGB',(1536,1152),'#263d43')
for i, frame in enumerate(frames):
    small=frame.resize((384,384),Image.Resampling.LANCZOS)
    board.paste(small,((i%4)*384,(i//4)*384),small)
    ImageDraw.Draw(board).text(((i%4)*384+12,(i//4)*384+12),f'{i+1:02}',font=font,fill='#dfd8c0')
board.save(OUT/'painted_poses.jpg',quality=94)
edges=Image.new('RGB',(1024,512),'#edf0e7')
edges.paste('#182f36',(512,0,1024,512))
edges.paste(frames[0],(0,0),frames[0]);edges.paste(frames[0],(512,0),frames[0])
edges.save(OUT/'cutout_review.png')
manifest={'name':'Veilleur d’airain — marche E redessinée','status':'rough_walk_art_review',
    'frame_count':12,'frame_size':[512,512],'source_cell_size':[w,h],
    'pivot':[256,432],'stride':[170,85],'duration_ms':1100,'frame_durations_ms':durations,
    'reference_height':1168*.32,'frames':[f'painted_frames/{i:02}.png' for i in range(12)],
    'source':'painted_frames.ora','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
    'method':'ImageGen cleanup of twelve posed 2D guide frames; local cutout; uniform grid export',
    'limits':['Une direction, sans équipement.','Démarche encore fléchie ; amplitudes et continuité à revoir.',
        'Les mesures géométriques du guide ne mesurent pas les pieds repeints.',
        'Le dessin natif mesure 362 pixels par case ; le 512 est un agrandissement uniforme.',
        'Aucune intégration dans la campagne.']}
(OUT/'painted_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
report={'scope':'Fichiers, cadrage, source et durée uniquement ; pas validation artistique des appuis.',
    'source_sha256':manifest['source_sha256'],'checks':checks,'duration_ms':sum(durations),
    'apng_frames':Image.open(OUT/'painted_walk_E.png').n_frames,'webp_frames':Image.open(OUT/'painted_walk_E.webp').n_frames}
assert report['apng_frames']==report['webp_frames']==12
(OUT/'painted_export_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PAINTED_EXPORT_READY',json.dumps({'frames':12,'native_cell':[w,h],'duration_ms':sum(durations)}),flush=True)
