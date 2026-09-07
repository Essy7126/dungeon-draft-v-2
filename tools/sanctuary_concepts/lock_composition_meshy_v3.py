"""Correct the framing drift found during the independent texture review."""
import concurrent.futures
import getpass
import json
import os
from generate_meshy_concepts import ROOT, meshy

ENDPOINT = '/openapi/v1/image-to-image'
PROMPT = '''Image 1 is the composition master. Image 2 is ONLY a reference for hand-painted MATERIAL TEXTURE.
Repaint IMAGE 1 with richer tactile hand-painted material texture, matching the texture sophistication of image 2. Preserve image 1's EXACT high-angle isometric camera, framing, scale, floor plan and every object silhouette and position. This is a texture and painted-surface refinement of image 1, NOT a new scene. The result must immediately be recognizable as the same view as image 1. Do not copy image 2's composition, architecture or camera.
Retain image 1's open courtyard, modest center mosaic, merchant stall upper left, oracle shrine upper right, gateway back center and water at the right edge. Preserve the large visible floor area. Do not add buildings, roofs, objects, foreground awnings, stairs or water. Never lower the camera or turn this into a frontal view.
Within the existing shapes, paint limestone with subtle mineral granules, worn edge chips and dry-brush pore texture; cloth with visible woven fibers and softened painterly folds; amphorae with earthy glaze and terracotta grain; bronze with aged patina; wood with restrained grain; foliage with layered leaf brushstrokes. Varied colored ink edges and beautiful gouache painting, visibly illustrated, not photographic or 3D. Real material-specific texture, not a uniform noise overlay. Central walking slabs remain quiet, low contrast and clearly readable. Preserve image 1's lighting and palette. No characters, text or interface.'''
JOBS = [
    ('meshy_output/20260907_191713_a-cour-des-sources_01a07cdf', 'A_cour_des_sources_texture_v3', 'Cour des Sources — texture et cadrage V3'),
    ('meshy_output/20260907_191714_b-refuge-des-braises_01a07cdf', 'B_refuge_des_braises_texture_v3', 'Refuge des Braises — texture et cadrage V3'),
]

def main():
    os.chdir(ROOT)
    os.environ['MESHY_API_KEY'] = getpass.getpass('Meshy session key (hidden): ').strip()
    try:
        meshy._cmd_balance(None)
        print('PLAN: two geometry-preserving texture revisions, 18 estimated credits.', flush=True)
        futures = {}
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            for folder, slug, title in JOBS:
                d = ROOT / folder
                original = json.loads((d / 'task.json').read_text(encoding='utf-8'))
                material = json.loads((d / 'task_texture_v2.json').read_text(encoding='utf-8'))
                payload = {'ai_model': 'nano-banana-pro', 'aspect_ratio': '16:9', 'reference_image_urls': [original['image_urls'][0], material['image_urls'][0]], 'prompt': PROMPT}
                task_id = meshy.create_task(ENDPOINT, payload)
                (d / 'payload_texture_v3.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
                meshy.record_task(str(d), task_id, 'image-to-image', 'texture_v3_created', prompt=title)
                futures[pool.submit(meshy.poll_task, ENDPOINT, task_id, 900)] = (d, slug, title)
            for future in concurrent.futures.as_completed(futures):
                d, slug, title = futures[future]
                task = future.result()
                (d / 'task_texture_v3.json').write_text(json.dumps(task, ensure_ascii=False, indent=2), encoding='utf-8')
                image_path = d / (slug + '.png')
                meshy.download(task['image_urls'][0], str(image_path))
                meshy.record_task(str(d), task['id'], 'image-to-image', 'texture_v3_completed_review_pending', prompt=title, files=[image_path.name])
                (d / 'review_status.json').write_text(json.dumps({'title': title, 'status': 'texture_v3_awaiting_visual_review', 'approved_by_user': False}, ensure_ascii=False, indent=2), encoding='utf-8')
                print(json.dumps({'title': title, 'path': str(image_path), 'task_id': task['id'], 'consumed_credits': task.get('consumed_credits')}, ensure_ascii=False), flush=True)
        meshy._cmd_balance(None)
    finally:
        os.environ.pop('MESHY_API_KEY', None)

if __name__ == '__main__':
    main()
