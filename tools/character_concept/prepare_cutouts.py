"""Prepare authorized software mattes; never change the character drawing."""
from pathlib import Path
import os, json, hashlib, sys

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'art/source/characters/achilles/serment_cendre_concept_v1'
OUT = ROOT / 'artifacts/spine_trial/serment_cendre_concept_v1'
os.environ['U2NET_HOME'] = str(ROOT / 'artifacts/dev-tools/rembg-models')
os.environ['OMP_NUM_THREADS'] = '4'
from PIL import Image
import numpy as np
from scipy import ndimage
from rembg import remove, new_session

session = None
reports = []
for name in (sys.argv[1:] or ['candidate_a', 'candidate_b', 'candidate_c']):
    raw_path = SRC / f'{name}_raw.png'
    raw = Image.open(raw_path)
    dst = SRC / f'{name}.png'
    if not dst.exists():
        if raw.mode == 'RGBA' and raw.getchannel('A').getextrema()[0] == 0:
            clean = raw.copy()
            method = 'native alpha preserved'
        else:
            if session is None:
                session = new_session('birefnet-general-lite', providers=['CPUExecutionProvider'])
            clean = remove(raw.convert('RGB'), session=session, decontaminate=True)
            px = np.asarray(clean).copy()
            labels, count = ndimage.label(px[:, :, 3] > 32)
            sizes = np.bincount(labels.ravel()); sizes[0] = 0
            support = ndimage.binary_dilation(labels == int(sizes.argmax()), iterations=4)
            px[~support] = 0
            px[px[:, :, 3] < 4] = 0
            clean = Image.fromarray(px)
            method = 'rembg birefnet-general-lite, CPU, decontaminate; detached background removed'
        clean.save(dst)
    else:
        clean = Image.open(dst)
        method = 'cached matte; see original report'
    bbox = clean.getchannel('A').getbbox()
    assert bbox and bbox[0] > 0 and bbox[1] > 0 and bbox[2] < clean.width and bbox[3] < clean.height
    clean.crop(bbox).save(OUT / f'{name}.png')
    for bg, color in [('dark', '#183638'), ('light', '#dad6bc')]:
        flat = Image.new('RGBA', clean.size, color)
        flat.alpha_composite(clean)
        flat.convert('RGB').save(OUT / f'{name}_{bg}.jpg', quality=92)
    reports.append({'asset': name, 'source_mode': raw.mode, 'native_size': list(raw.size),
                    'bbox': list(bbox), 'cutout_size': [bbox[2]-bbox[0], bbox[3]-bbox[1]],
                    'method': method, 'raw_sha256': hashlib.sha256(raw_path.read_bytes()).hexdigest(),
                    'alpha_sha256': hashlib.sha256(dst.read_bytes()).hexdigest()})
    print(json.dumps(reports[-1]), flush=True)
(SRC / ('matte_report_' + '_'.join(sys.argv[1:] or ['candidates']) + '.json')).write_text(json.dumps(reports, indent=2), encoding='utf8')
