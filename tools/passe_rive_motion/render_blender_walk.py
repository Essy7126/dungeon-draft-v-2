"""Render the saved study; never changes the user's open Blender scene."""
import bpy,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/spine_trial/passe_rive_walk_v2';OUT.mkdir(parents=True,exist_ok=True)
scene=bpy.context.scene
quick='--quick' in sys.argv
scene.render.resolution_percentage=100
scene.render.resolution_x=640;scene.render.resolution_y=960
bpy.data.collections['Ground_reference'].hide_render=True
scene.render.film_transparent=True
scene.camera=bpy.data.objects['Camera_E']
scene.camera.data.ortho_scale=2.20
frames=[1,12,19,30] if quick else range(1,37)
dest=OUT/('check' if quick else 'frames');dest.mkdir(exist_ok=True)
completed=[]
for frame in frames:
 scene.frame_set(frame);scene.render.filepath=str(dest/f'walk_{frame-1:02}.png');bpy.ops.render.render(write_still=True)
 completed.append(frame)
 (OUT/'render_progress.json').write_text(json.dumps({'complete':len(completed),'total':len(frames),'frame':frame,'quick':quick}))
if quick:
 scene.camera=bpy.data.objects['Camera_Side']
 for frame in [1,12,19]:
  scene.frame_set(frame);scene.render.filepath=str(dest/f'side_{frame-1:02}.png');bpy.ops.render.render(write_still=True)
print('WALK_RENDERED '+str(len(completed)))
