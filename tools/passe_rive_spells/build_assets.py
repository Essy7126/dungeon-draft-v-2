"""Package ImageGen key poses; authorized white-background removal, no limb synthesis."""
from pathlib import Path
import json, hashlib, shutil, zipfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT/'art/source/characters/achilles/passe_rive_spells_v1'
OUT = ROOT/'artifacts/spine_trial/passe_rive_spells_v1'
DEL = SRC/'delivery'
CFG = json.loads((Path(__file__).parent/'layout.json').read_text(encoding='utf8'))
W,H = CFG['frame_size']; PIVOT=CFG['pivot']
for p in [DEL/'frames', OUT/'frames', SRC/'cutouts']:
    p.mkdir(parents=True,exist_ok=True)

reports=[]; poses={}; animations=[]
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
contact=Image.new('RGB',(1152,6*326),'#192e2c');draw=ImageDraw.Draw(contact)
for row,act in enumerate(CFG['actions']):
    raw=Image.open(SRC/f"{act['id']}_rgb.png").convert('RGB')
    if raw.size!=(1254,1254):
        raise RuntimeError(f'Unexpected source dimensions {raw.size}; review coordinates before packaging.')
    frames=[]
    for i,(box,anchor) in enumerate(zip(act['boxes'],act['anchors'])):
        matte_path=SRC/'matte_frames'/f"{act['id']}_{i:02}.png"
        if not matte_path.exists():raise RuntimeError('Run cutout.py first; rejected white-key is not a fallback.')
        im=Image.open(matte_path).convert('RGBA'); im.save(SRC/'cutouts'/f"{act['id']}_{i:02}.png")
        sw,sh=round(im.width*act['scale']),round(im.height*act['scale'])
        resized=im.resize((sw,sh),Image.Resampling.LANCZOS)
        dst=(round(PIVOT[0]-(anchor[0]-box[0])*act['scale']),round(PIVOT[1]-(anchor[1]-box[1])*act['scale']))
        frame=Image.new('RGBA',(W,H));frame.paste(resized,dst)
        if frame.getchannel('A').getbbox() is None:raise RuntimeError('Empty pose')
        bounds=frame.getchannel('A').getbbox()
        if min(bounds[:2])<2 or bounds[2]>=W-2 or bounds[3]>=H-2:raise RuntimeError(f'Clipped pose {act["id"]} {i}: {bounds}')
        file=f"frames/{act['id']}_{i:02}.png"
        frame.save(DEL/file);shutil.copy2(DEL/file,OUT/file)
        frames.append({'file':file,'duration_ms':act['durations'][i],'phase':act['phase'][i]})
        reports.append({'action':act['id'],'pose':i,'source_crop':box,'source_anchor':anchor,'fixed_action_scale':act['scale'],'bbox':bounds,'opaque_pixels':int((np.asarray(frame)[:,:,3]>240).sum()),'sha256':hashlib.sha256((DEL/file).read_bytes()).hexdigest()})
        poses[act['id'],i]=frame
        thumb=frame.resize((288,288),Image.Resampling.LANCZOS)
        contact.paste(thumb,(i*288,row*326+30),thumb)
        draw.text((i*288+10,row*326+6),f"{act['name']} · {i+1}",font=font,fill='#d9d6bc')
    atlas=Image.new('RGBA',(W*2,H*2))
    for i in range(4):atlas.paste(poses[act['id'],i],(i%2*W,i//2*H))
    atlas.save(DEL/f"{act['id']}_atlas.png")
    for i in range(4):
        if atlas.crop((i%2*W,i//2*H,i%2*W+W,i//2*H+H)).tobytes()!=poses[act['id'],i].tobytes():raise RuntimeError('Atlas mismatch')
    result={k:v for k,v in act.items() if k not in ['boxes','anchors','scale','durations','phase']}
    result.update(frames=frames,atlas=f"{act['id']}_atlas.png",total_ms=sum(act['durations']))
    animations.append(result)

# The combat idle uses the exact recovery pose of the thrust, eliminating that transition pop.
idle=poses['strike',3];idle.save(DEL/'frames/idle.png');shutil.copy2(DEL/'frames/idle.png',OUT/'frames/idle.png')
# Walk V3 retained as authored. One clip-wide registration, no foot/limb replacement.
walk=[]
for i in range(12):
    original=ROOT/f'art/source/characters/achilles/passe_rive_walk_v3/delivery/frames/walk_{i:02}.png'
    im=Image.open(original).convert('RGBA');scale=1.12
    im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
    frame=Image.new('RGBA',(W,H));frame.paste(im,(round(PIVOT[0]-176*scale),round(PIVOT[1]-428*scale)))
    file=f'frames/walk_{i:02}.png';frame.save(DEL/file);shutil.copy2(DEL/file,OUT/file)
    walk.append({'file':file,'duration_ms':100})
manifest={'schema':1,'name':'Passe-rive — palette de sorts','direction':'E / trois-quarts droite, sans miroir','frame_size':[W,H],'pivot':PIVOT,'actions':animations,'idle':'frames/idle.png','walk':walk,'walk_cycle_stride':[136.64,68.32],'status':'playable_art_trial','generation':'Built-in ImageGen: six sheets plus targeted guard correction','cutout':'Authorized software neutral-white extraction, edge unmatting; no AI rembg model required','native_sheet_size':[1254,1254],'input_buffer_ms':160,'limitations':['Une direction seulement ; le laboratoire ne remplace pas le combat de la campagne.','Quatre poses clés par action, timing tenu ; aucun faux intermédiaire ajouté.','Tir : proposition visuelle de projection de lance, à valider pour le Tir du Pélion.','Moisson et Heurt : propositions de palette, chiffres de laboratoire uniquement.','Idle : pose de garde issue de la récupération ; marche V3 réutilisée.','Dessin génératif : volumes, prise de lance et raccords restent à juger au ralenti.']}
manifest['cutout']='Authorized rembg birefnet-general-lite, decontaminate=True; detached neighboring fragments removed. Neutral-white color key was rejected after visual inspection.'
for folder in [DEL,OUT]: (folder/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
(SRC/'cutout_report.json').write_text(json.dumps({'method':manifest['cutout'],'atlas_pixels_exact':True,'poses':reports},indent=2),encoding='utf8')
contact.save(OUT/'poses_contact.png')
shutil.copy2(ROOT/'asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png',OUT/'map.png')
shutil.copy2(ROOT/'tools/passe_rive_spells/specs.json',SRC/'generation_prompts.json')
shutil.copy2(ROOT/'tools/passe_rive_spells/guard_fix_prompt.txt',SRC/'guard_fix_prompt.txt')
print(json.dumps({'actions':len(animations),'painted_poses':24,'registered_walk_frames':12,'frame_size':[W,H],'atlas_pixels_exact':True,'contact':str(OUT/'poses_contact.png')}))
