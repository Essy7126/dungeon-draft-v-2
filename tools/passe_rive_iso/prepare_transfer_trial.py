"""Package existing artwork and inspected motion; submits no external job."""
from pathlib import Path
import json, shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/source/characters/achilles/passe_rive_walk_iso_v1/transfer_trial'
OUT.mkdir(parents=True,exist_ok=True)
source=ROOT/'artifacts/spine_trial/passe_rive_walk_iso_v1/frames/E_keys_00.png'
im=Image.open(source).convert('RGBA')
scale=1.60
canvas=Image.new('RGB',(640,960),'white')
im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
canvas.paste(im,(round(320-384*scale),round(895-662*scale)),im)
canvas.save(OUT/'reference.png')
shutil.copy2(ROOT/'artifacts/spine_trial/passe_rive_walk_v2/motion_reference.mp4',OUT/'motion_4cycles.mp4')
prompt='Transfer only the walking motion from the driving video onto the painted Passe-rive reference. Preserve the exact slender adult character, mask, petrol hood, jade cape, ivory sash, black limbs, bronze cuffs, right-hand spear and left-hand shield. Four repeated 1.2-second walk cycles, fixed elevated front-right three-quarter camera, entire body and all equipment visible, pure white background, no floor shadow or scenery. Alternate LEFT and RIGHT support legs exactly as the driving performance, preserving heel contact, toe-off and limb occlusions. Keep the spear straight with fixed length, shield shape and grip constant. Do not add speech, effects, camera motion, extra limbs or costume changes. Retain the painted game-sprite style.'
(OUT/'prompt.txt').write_text(prompt,encoding='utf8')
manifest={'model':'hf_mult_motion_control','resolution':'720p','source_duration_seconds':4.8,'source_fps':30,'source_size':[640,960],'source_cycle_seconds':1.2,'inputs':{'image':'reference.png','video':'motion_4cycles.mp4'},'scope':'Only E walk. Compare against source for left/right identity, foot contact, spear integrity, mask and costume stability, and cycle closure. Do not approve from a smooth video alone.','submission_status':'NOT_SUBMITTED','free_attempt':'One available; tool requires explicit user choice to spend it.'}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
print('TRANSFER_TRIAL_PREPARED — no upload or generation submitted')
