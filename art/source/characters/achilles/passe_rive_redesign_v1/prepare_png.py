"""Software cutout authorized in this thread; preserve the generated drawing."""
from pathlib import Path
import json
import os
import numpy as np
from PIL import Image
from scipy import ndimage

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
os.environ['U2NET_HOME'] = str(ROOT / 'artifacts/dev-tools/rembg-models')
os.environ['OMP_NUM_THREADS'] = '4'
from rembg import remove, new_session

source = Image.open(HERE / 'generated.png').convert('RGB')
session = new_session('birefnet-general-lite', providers=['CPUExecutionProvider'])
cutout = remove(source, session=session, decontaminate=True).convert('RGBA')
pixels = np.array(cutout)
labels, _ = ndimage.label(pixels[:, :, 3] > 32)
counts = np.bincount(labels.ravel())
counts[0] = 0
assert counts.max() > 10000
keep = ndimage.binary_dilation(labels == counts.argmax(), iterations=2)
pixels[~keep] = 0
pixels[pixels[:, :, 3] < 5] = 0
cutout = Image.fromarray(pixels)
cutout.save(HERE / 'passe_rive.png')
preview = Image.new('RGBA', cutout.size, (70, 86, 80, 255))
preview.alpha_composite(cutout)
preview.convert('RGB').save(HERE / 'preview.jpg', quality=94)
alpha = pixels[:, :, 3]
assert alpha.min() == 0 and alpha.max() == 255
report = {'size': list(cutout.size), 'mode': cutout.mode,
          'alpha_zero_pixels': int((alpha == 0).sum()),
          'alpha_opaque_pixels': int((alpha == 255).sum()),
          'bbox': cutout.getbbox(), 'generator': 'ImageGen built-in',
          'background_cleanup': 'BiRefNet general lite, existing CPU environment',
          'animation_tested': False, 'autosprite_tested': False}
(HERE / 'metadata.json').write_text(json.dumps(report, indent=2), encoding='utf8')
print(json.dumps(report))
