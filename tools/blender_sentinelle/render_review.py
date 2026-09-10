"""Render an existing saved study in a separate Blender background process."""
import bpy
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/dev/sentinelle-blender-review-20260910'
OUT.mkdir(parents=True,exist_ok=True)
scene=bpy.context.scene;rig=bpy.data.objects['Sentinelle_Rig']
action=bpy.data.actions['Estoc_Preview'];rig.animation_data.action=action
if action.slots:rig.animation_data.action_slot=action.slots[0]
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
prefs=bpy.context.preferences.addons['cycles'].preferences
prefs.compute_device_type='OPTIX';prefs.refresh_devices()
for dev in prefs.devices:dev.use=dev.type=='OPTIX'
scene.cycles.device='GPU'
scene.render.resolution_x=800;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
renders=[]
for direction in 'ESWN':
    scene.camera=bpy.data.objects['Camera_'+direction]
    frames=range(1,26) if direction=='E' else [1,6,10,13,16,25]
    for frame in frames:
        scene.frame_set(frame)
        path=OUT/f'{direction}_{frame:02d}.png'
        scene.render.filepath=str(path)
        bpy.ops.render.render(write_still=True)
        renders.append({'direction':direction,'frame':frame,'path':str(path)})
        (OUT/'progress.json').write_text(json.dumps({'completed':len(renders),'total':43,'last':renders[-1]}))
(OUT/'report.json').write_text(json.dumps({'passed':len(renders)==43,'renders':renders},indent=2)+'\n')
print('REVIEW_COMPLETE='+str(len(renders)))
