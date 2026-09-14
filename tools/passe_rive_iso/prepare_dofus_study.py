"""Build a local reference study, never runtime character assets.

Inputs are public portfolio GIFs cached for analysis in artifacts/dev/dofus-research.
The original source, encoded timings and study interval are preserved in the manifest.
"""
from pathlib import Path
import hashlib
import json
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / 'artifacts/dev/dofus-research'
OUT = ROOT / 'artifacts/spine_trial/dofus_motion_study'
OUT.mkdir(parents=True, exist_ok=True)
urls = json.loads((CACHE / 'puppet_gif_urls.json').read_text(encoding='utf-8-sig'))
clips = []
for index, name in [(8, 'Marche · corps seul'), (9, 'Marche · avec équipement')]:
    source = CACHE / f'puppet_{index}.gif'
    gif = Image.open(source)
    durations = []
    samples = []
    for i in range(32):
        gif.seek(i)
        samples.append(gif.convert('RGBA'))
        durations.append(gif.info.get('duration', 0))
    atlas = Image.new('RGBA', (gif.width * 8, gif.height * 2))
    for i, frame in enumerate(samples[:16]):
        atlas.paste(frame, ((i % 8) * gif.width, (i // 8) * gif.height))
    atlas.save(OUT / f'reference_{index}.png')
    exact_repeats = [samples[i].tobytes() == samples[i+16].tobytes() for i in range(16)]
    if not all(exact_repeats):
        raise ValueError(f'{source.name}: the 16-frame study interval is not a verified cycle')
    clips.append(dict(id=index, label=name, image=f'reference_{index}.png', width=gif.width,
        height=gif.height, columns=8, count=16, durations_ms=durations[:16],
        source_url=urls[index], source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        interval='first 16 encoded GIF frames; no time interpolation',
        exact_repeat_after_16_frames=exact_repeats))
(OUT / 'references.json').write_text(json.dumps(clips, indent=2, ensure_ascii=False), encoding='utf8')
shutil.copy2(ROOT / 'tools/passe_rive_iso/dofus_motion_study.html', OUT / 'review.html')
print(json.dumps({'out': str(OUT), 'clips': [{k:c[k] for k in ['id','count','exact_repeat_after_16_frames']} for c in clips]}, indent=2))
