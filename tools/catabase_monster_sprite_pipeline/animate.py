"""Author 48 articulated poses from each independent Meshy fixed painting.

Local layered skeletons, foot IK and authored action timing preserve the painted
identity. Meshy provides references only; no remote generation or texture flips.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'output/monster-meshy-deps'))
from PIL import Image, ImageDraw
from build import pack_frames, write_sprite_frames, SLUGS, ACTION_FRAMES
from articulated_animation import PaintedSkeleton, pose_for
from humanoid_parts import build_parts as humanoid_parts
from creature_parts import build_parts as creature_parts

SOURCE=ROOT/'art/source/characters/catabase_monsters'
PORTRAITS={'sentinelle_airain':[168,32,75,86], 'rejeton_braise':[207,88,108,106],
           'molosse_styx':[270,151,91,87], 'lamie_lethe':[249,48,58,80]}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--slug',default='all',choices=['all',*SLUGS])
    parser.add_argument('--direction',default='all',choices=['all',*'NESW'])
    parser.add_argument('--review-only',action='store_true')
    args=parser.parse_args()
    slugs=SLUGS if args.slug=='all' else [args.slug]
    directions='NESW' if args.direction=='all' else args.direction
    for slug in slugs:
        for direction in directions:
            source=SOURCE/slug/f'base_frame_{direction}.png'
            base=Image.open(source).convert('RGBA')
            factory=humanoid_parts if slug in SLUGS[:2] else creature_parts
            parts=factory(slug,direction,base)
            puppet=PaintedSkeleton(base,parts,slug,direction)
            poses=[pose_for(slug,direction,index,parts) for index in range(48)]
            frames=[base.copy()]+[puppet.render(pose) for pose in poses[1:]]
            review=ROOT/'output/catabase_monsters_v2/review'/slug
            review.mkdir(parents=True,exist_ok=True)
            indices=[0,2,6,8,11,14,17,22,24,30,32,37,42,44,46]
            board=Image.new('RGB',(5*384,3*312),'#27363d');pen=ImageDraw.Draw(board)
            for cell,index in enumerate(indices):
                x,y=cell%5*384,cell//5*312
                frame=frames[index].resize((384,288),Image.Resampling.LANCZOS)
                board.paste(frame,(x,y+20),frame)
                pen.text((x+10,y+5),f'{index} {poses[index]["action"]}',fill='white')
            board.save(review/f'poses_{direction}.jpg',quality=94)
            for index in indices:frames[index].save(review/f'{direction}_{index:02d}.png')
            for action,indices in ACTION_FRAMES.items():
                clips=[]
                for index in indices:
                    canvas=Image.new('RGB',(512,384),'#27363d')
                    canvas.paste(frames[index],(0,0),frames[index]);clips.append(canvas)
                clips[0].save(review/f'{direction}_{action}.gif',save_all=True,append_images=clips[1:],duration=140 if action=='idle' else 90,loop=0)
            if args.review_only:
                print(f'REVIEW_READY: {slug}/{direction}',flush=True)
                continue
            modules=['animate.py','articulated_animation.py','humanoid_parts.py' if slug in SLUGS[:2] else 'creature_parts.py']
            provenance={'reference_view':source.relative_to(ROOT).as_posix(),
                'reference_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                'method':'Locally authored rigid painted parts with reconstructed occlusions, two-link planted-foot IK and independent hand/ankle joints; flexible snake coil only; no texture mirroring.',
                'renderer_files':{name:hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest() for name in modules},
                'parts':[{k:v for k,v in part.items() if k not in ('image','source_image','underpaint')} for part in puppet.parts],
                'pose_recipes':poses,'render_sampling':'premultiplied RGBA bicubic rigid transforms; separate underpaint/source passes',
                'source_bbox':list(base.getchannel('A').getbbox())}
            report=pack_frames(slug,direction,frames,provenance)
            print(json.dumps({'slug':slug,'direction':direction,'frames':len(frames),'raster_error':report['raster_max_error'],'atlas_size':report['atlas_size']}),flush=True)
        if args.direction=='all' and not args.review_only:
            write_sprite_frames(slug,PORTRAITS[slug])
            print('FAMILY_COMPLETE: '+slug,flush=True)

if __name__=='__main__':main()
