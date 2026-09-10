"""User-authorized local background removal; originals remain untouched."""
import os
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
os.environ['U2NET_HOME'] = str(ROOT/'artifacts/dev-tools/rembg-models')
os.environ['OMP_NUM_THREADS'] = '4'
import argparse
import hashlib
import json
import numpy as np
from PIL import Image
from rembg import new_session, remove

parser=argparse.ArgumentParser()
parser.add_argument('--revision', default='v1')
parser.add_argument('--white-cleanup', action='store_true')
parser.add_argument('files', nargs='+')
args=parser.parse_args()
session=new_session('birefnet-general-lite', providers=['CPUExecutionProvider'])
for item in args.files:
    src=ROOT/item
    suffix='' if args.revision=='v1' else '_'+args.revision
    dst=src.with_name(src.stem.replace('_rgb','')+'_rgba'+suffix+'.png')
    if dst.exists():
        raise RuntimeError(f'Output already exists: {dst}')
    im=Image.open(src).convert('RGB')
    result=remove(im,session=session,alpha_matting=False,decontaminate=args.white_cleanup)
    white_removed=0
    if args.white_cleanup:
        original=np.asarray(im)
        rgba=np.array(result)
        # Only applies to these explicitly generated uniform white backdrops.
        # Ivory costume colors retain chroma and do not satisfy this predicate.
        near_white=(original.min(axis=2)>=248)&(np.ptp(original,axis=2)<=8)
        white_removed=int(((rgba[:,:,3]>0)&near_white).sum())
        rgba[near_white,3]=0
        result=Image.fromarray(rgba)
    result.save(dst)
    pixels=np.array(result)
    alpha=pixels[:,:,3]
    bbox=result.getchannel('A').getbbox()
    report={'input':str(src.relative_to(ROOT)), 'output':str(dst.relative_to(ROOT)),
            'method':'rembg 2.0.84 / birefnet-general-lite / CPU', 'size':list(result.size),
            'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),
            'output_sha256':hashlib.sha256(dst.read_bytes()).hexdigest(),
            'alpha_range':[int(alpha.min()),int(alpha.max())],
            'transparent_fraction':float((alpha==0).mean()),'bbox':bbox,
            'white_background_cleanup_pixels':white_removed,
            'edge_decontamination':args.white_cleanup,'visual_approval':False}
    dst.with_suffix('.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report),flush=True)
