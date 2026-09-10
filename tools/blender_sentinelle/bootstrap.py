"""Enable the installed matching MCP addon and open a scoped working copy."""
import bpy
import addon_utils
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / 'art/source/blender/sentinelle_blocking_v1'
OUTPUT.mkdir(parents=True, exist_ok=True)
(OUTPUT / '.gdignore').write_text('')
source = bpy.data.filepath
if 'blender_mcp_addon' in bpy.context.preferences.addons:
    addon_utils.disable('blender_mcp_addon', default_set=True)
addon_utils.enable('blender_mcp', default_set=True, persistent=True)
bpy.context.scene.blendermcp_auto_start_server = True
bpy.context.scene.blendermcp_port = 9876
bpy.ops.wm.save_userpref()
working_file = OUTPUT / 'sentinelle_blocking_v1.blend'
if not working_file.exists():
    bpy.ops.wm.save_as_mainfile(filepath=str(working_file))
audit = {'source': source, 'working_file': str(working_file),
         'blender': bpy.app.version_string, 'enabled_addons': list(bpy.context.preferences.addons.keys()),
         'server_running': bool(getattr(bpy.types, 'blendermcp_server', None) and bpy.types.blendermcp_server.running)}
(ROOT / 'artifacts/dev/blender-sentinelle-bootstrap.json').write_text(json.dumps(audit, indent=2), encoding='utf-8')
print('SENTINELLE_BOOTSTRAP=' + json.dumps(audit))
