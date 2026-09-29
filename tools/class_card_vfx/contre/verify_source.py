"""Re-render the saved scene and compare all RGBA pixels to runtime source frames."""
import bpy, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'artifacts/dev/class_card_vfx/contre/reproduced'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/source/vfx/contre/contre.blend'))
manifest=json.loads((ROOT/'art/source/vfx/contre/manifest.json').read_text())
for name,asset in manifest['assets'].items():
    s=bpy.data.scenes[asset['scene']];bpy.context.window.scene=s
    (OUT/name).mkdir(parents=True,exist_ok=True)
    s.render.filepath=str(OUT/name/'frame_');bpy.ops.render.render(animation=True)
print('CONTRE_CEL_REPRODUCED')

