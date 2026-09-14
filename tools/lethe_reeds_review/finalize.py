"""Record explicit completed reports after their captures have been inspected."""
import argparse
from pathlib import Path
from apply import ROOT, ROOM, OUT, read, write, sha

parser = argparse.ArgumentParser()
parser.add_argument('--gpu', type=Path, required=True)
parser.add_argument('--expedition', type=Path, required=True)
parser.add_argument('--unit', type=Path, required=True)
parser.add_argument('--inspected', action='store_true', required=True)
args = parser.parse_args()
gpu, expedition, unit = read(args.gpu), read(args.expedition), read(args.unit)
assert gpu['passed'] is True and len(gpu['results']) == 2
assert expedition['passed'] is True and expedition['node_id'] == 'd05_1'
assert unit['verdict'] == 'PASS' and unit['counts']['tests_executed'] > 0
assert unit['counts']['assertions_passed'] == unit['counts']['assertions_total']
record = read(OUT/'manifest.json')
assert sha(OUT/'land.png') == record['image_sha256']
assert sha(ROOM/'geometry_manifest.json') == record['geometry_sha256']
assert sha(ROOM/'terrain_plan.json') == record['plan_sha256']
reports = [read(Path(result['report'])) for result in gpu['results']]
for report in reports:
    assert report['ok'] is True
    assert report['gameplay_fingerprint'] == record['gameplay_fingerprint']
    assert report['painted_decor']['boat']['ok'] is True
    assert report['painted_decor']['reduced_motion_gpu_freezes'] is True
record['validation_status'] = 'PASS: saved gameplay, full floor support, GPU at two sizes, route units and real expedition launch'
record['validation_reports'] = {
    'gpu': args.gpu.as_posix(), 'expedition': args.expedition.as_posix(),
    'unit': args.unit.as_posix(),
    'dry_support': 'artifacts/dev/lethe-reeds/final-dry-surface-audit.json',
    'prepare': 'artifacts/dev/20260912-134019-lethe-reeds-prepare-fc3ac9b8/summary.json',
    'shared_lances_oracle': 'artifacts/dev/20260912-125743-lethe-lances-review-d5c7b8e5/summary.json',
}
record['visual_review'] = {
    'inspected': ['1920x1080_after_move_guard','1200x896_after_move_guard','1600x900_real_deployment'],
    'boat_fully_visible': True, 'hud_overlap': False,
    'source_pixels_unchanged': True,
    'camera_offset': [-120,50],
    'limits': 'Movement and guard verified; no complete victory or free boat navigation. Production Explorer report does not expose instantiated enemy roles.'
}
record['runtime_asset_sha256'] = {name: sha(OUT/name) for name in [
    'land.png','material_mask.png','living.gd','living.gdshader','pit_water.gdshader',
    'Living.tscn','presentation.tres','fx.json','visual_review.json','art_calibration.json']}
record['room_sha256'] = sha(ROOM/'room.tres')
write(OUT/'manifest.json', record)
print(record['validation_status'])
