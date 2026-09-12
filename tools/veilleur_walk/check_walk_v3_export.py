"""Check actual exports and measured contacts; does not judge animation quality."""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'artifacts/spine_trial/veilleur_walk_E_v3'
SRC = ROOT / 'art/source/characters/achilles/veilleur_walk_E_v3'
BASE = ROOT / 'art/source/characters/achilles/veilleur_proportions_v1'
frames = [Image.open(OUT / f'frames/{i:02}.png').convert('RGBA') for i in range(32)]
animation = Image.open(OUT / 'walk.png')
assert animation.n_frames == 32
duration = 0
diffs = []
for i, frame in enumerate(frames):
    animation.seek(i)
    duration += animation.info['duration']
    diffs.append(int(np.any(np.asarray(frame) != np.asarray(animation.convert('RGBA')), axis=2).sum()))
assert max(diffs) == 0 and abs(duration - 480) < .01
atlas = Image.open(OUT / 'atlas.png').convert('RGBA')
assert atlas.size == (4096, 2048)
for i, frame in enumerate(frames):
    tile = atlas.crop(((i % 8) * 512, (i // 8) * 512, (i % 8 + 1) * 512, (i // 8 + 1) * 512))
    assert np.array_equal(np.asarray(frame), np.asarray(tile))
webp = Image.open(OUT / 'walk.webp')
assert webp.n_frames == 32
webp_diffs = []
webp_duration = 0
for i, frame in enumerate(frames):
    webp.seek(i)
    decoded = np.asarray(webp.convert('RGBA'))
    original = np.asarray(frame)
    # RGB under zero alpha has no visual meaning and may be discarded by WebP.
    visible = np.maximum(original[:, :, 3], decoded[:, :, 3]) > 0
    webp_diffs.append(int((np.any(original != decoded, axis=2) & visible).sum()))
    webp_duration += webp.info['duration']
assert max(webp_diffs) == 0 and webp_duration == 480
lock = json.loads((SRC / 'source_lock.json').read_text())
unchanged = {name: hashlib.sha256((BASE / (name + '.png')).read_bytes()).hexdigest() == digest
             for name, digest in lock['source_piece_sha256'].items()}
assert all(unchanged.values())
motion = json.loads((SRC / 'motion.json').read_text())
manifest = json.loads((OUT / 'manifest.json').read_text())
assert len(motion) == len(manifest['frames']) == 32
for pose in motion:
    for side, leg in pose['legs'].items():
        assert all(.48 <= q <= 1 for q in leg['shortening'])
        assert .65 <= leg['boot_shortening'] <= 1
        actual = np.array([np.linalg.norm(np.subtract(leg['knee'], leg['hip'])),
                           np.linalg.norm(np.subtract(leg['ankle'], leg['knee']))])
        assert np.all(actual <= np.array(lock['maximum_projected_lengths'][side]) + 1e-8)
contact_spans = {}
for side, indices in [('L', range(16)), ('R', range(16, 32))]:
    points = np.array([np.array(motion[i]['legs'][side]['sole']) + motion[i]['root']
                       + np.array(manifest['stride']) * i / 32 for i in indices])
    diameter = float(np.linalg.norm(points[:, None, :] - points[None, :, :], axis=2).max())
    contact_spans[side] = {'max_pairwise_output_px': diameter,
                           'max_pairwise_at_112px': diameter * 112 / manifest['reference_height']}
report = {'apng_frame_count': 32, 'duration_ms': duration,
          'apng_changed_pixels_by_frame': diffs, 'atlas_matches_all_frames': True,
          'webp_frame_count': 32, 'webp_duration_ms': webp_duration,
          'webp_changed_visible_pixels_by_frame': webp_diffs,
          'source_pieces_unchanged': unchanged, 'projected_lengths_within_source_maximum': True,
          'annotated_stance_contact_spans': contact_spans,
          'scope': 'Actual pixels, files and estimated landmarks checked. Contacts are manually annotated sole points, not exhaustive pixel tracking. No artistic acceptance.'}
(OUT / 'export_report.json').write_text(json.dumps(report, indent=2))
print(json.dumps({'frames': 32, 'duration_ms': duration, 'atlas_matches': True,
                  'source_unchanged': all(unchanged.values()), 'contact_spans': contact_spans}))
