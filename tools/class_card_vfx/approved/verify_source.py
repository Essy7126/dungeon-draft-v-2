"""Render the saved Blender scenes again; compare RGBA pixels in pack.py's runtime."""
import bpy
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'artifacts/dev/class_card_vfx/approved/reproduced'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/source/vfx/approved_spells/approved_spells.blend'))
manifest=json.loads((ROOT/'art/source/vfx/approved_spells/manifest.json').read_text())
for name,asset in manifest['assets'].items():
    scene=bpy.data.scenes[asset['scene']]
    bpy.context.window.scene=scene
    (OUT/name).mkdir(parents=True,exist_ok=True)
    scene.render.filepath=str(OUT/name/'frame_')
    bpy.ops.render.render(animation=True)
print('APPROVED_CEL_REPRODUCED')
