"""Render the dressed study and its actual reference with identical cameras."""
import bpy
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'artifacts/dev/sentinelle-armor-v1'
PREVIEW = '--preview' in sys.argv
scene = bpy.context.scene
variant = 'armor' if bpy.data.collections.get('Armor_details') else 'reference'
directory = OUT/variant
directory.mkdir(parents=True,exist_ok=True)
rig = bpy.data.objects['Sentinelle_Rig']
action = bpy.data.actions['Estoc_Preview']
rig.animation_data.action = action
if action.slots:
    rig.animation_data.action_slot = action.slots[0]
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
prefs = bpy.context.preferences.addons['cycles'].preferences
prefs.compute_device_type = 'OPTIX'
prefs.refresh_devices()
for dev in prefs.devices:
    dev.use = dev.type == 'OPTIX'
scene.cycles.device = 'GPU'
scene.render.resolution_x = 800
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
renders = []
for direction in 'ESWN':
    scene.camera = bpy.data.objects['Camera_'+direction]
    frames = ([1,13] if direction=='E' else [13]) if PREVIEW else range(1,26)
    for frame in frames:
        scene.frame_set(frame)
        output = directory/f'{direction}_{frame:02d}.png'
        scene.render.filepath = str(output)
        bpy.ops.render.render(write_still=True)
        renders.append({'direction':direction,'frame':frame,'path':str(output)})
        (OUT/f'{variant}_progress.json').write_text(json.dumps({'completed':len(renders),'total':5 if PREVIEW else 100}))
(OUT/f'{variant}_{"preview" if PREVIEW else "report"}.json').write_text(json.dumps({
    'passed':len(renders)==(5 if PREVIEW else 100),'file':bpy.data.filepath,'renders':renders},indent=2)+'\n')
print(json.dumps({'passed':True,'variant':variant,'renders':len(renders)}))
