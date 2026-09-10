"""Encode the exact Blender PNG sequence in Blender's video sequencer."""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/spine_trial/passe_rive_walk_v2'
scene=bpy.context.scene
seq=scene.sequence_editor_create()
for old in list(seq.strips):seq.strips.remove(old)
bg=seq.strips.new_effect('Neutral_background',type='COLOR',channel=1,frame_start=1,length=144)
bg.color=(.68,.71,.70)
strip=seq.strips.new_image('Exact_Blender_cycle',str(OUT/'frames/walk_00.png'),channel=2,frame_start=1)
for i in range(1,144):strip.elements.append(f'walk_{i%36:02}.png')
strip.frame_final_duration=144;strip.blend_type='ALPHA_OVER'
scene.render.resolution_x=640;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.frame_start=1;scene.frame_end=144;scene.render.fps=30
scene.render.film_transparent=False
scene.render.image_settings.media_type='VIDEO'
scene.render.image_settings.file_format='FFMPEG'
scene.render.ffmpeg.format='MPEG4';scene.render.ffmpeg.codec='H264';scene.render.ffmpeg.constant_rate_factor='HIGH';scene.render.ffmpeg.audio_codec='NONE'
scene.render.filepath=str(OUT/'motion_reference.mp4')
scene.view_settings.view_transform='Standard';scene.render.use_sequencer=True
bpy.ops.render.render(animation=True)
print('REFERENCE_VIDEO_READY '+str(OUT/'motion_reference.mp4'))
