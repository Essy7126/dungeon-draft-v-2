from pathlib import Path
from PIL import Image
import json
r=Path.cwd();base=r/'artifacts/dev/class_card_vfx/braise'
manifest=json.loads((r/'art/source/vfx/braise/manifest.json').read_text())
checks=[]
for name,asset in manifest['assets'].items():
 for f in range(1,asset['frames']+1):
  a=Image.open(base/'render'/name/f'frame_{f:04}.png').convert('RGBA')
  b=Image.open(base/'reproduced'/name/f'frame_{f:04}.png').convert('RGBA')
  checks.append({'asset':name,'frame':f,'equal':a.size==b.size and a.tobytes()==b.tobytes()})
out={'passed':all(c['equal'] for c in checks),'frames':len(checks),'checks':checks}
(base/'source_verification.json').write_text(json.dumps(out,indent=2))
print(json.dumps({'passed':out['passed'],'frames':len(checks)}))
assert out['passed']

