"""Material refinement via Meshy's GPT Image 2 with local original references."""
import base64
import concurrent.futures
import getpass
import json
import os
from generate_meshy_concepts import ROOT, meshy

ENDPOINT = '/openapi/v1/image-to-image'
PROMPT = '''Edit this exact original game map. Preserve the high-angle isometric camera, the floor geometry, the generous empty walking space and the positions and proportions of all existing objects. The only substantial change should be to the art rendering: MUCH richer hand-painted material texture and surface detail, while keeping a clearly DRAWN illustrated game style. Make the stone feel like porous mineral limestone with fine grains, subtle mottled pigments, tiny chipped edges and dry brushwork. Give the canvas awning a convincing woven linen texture and worn embroidered edges, amphorae granular terracotta and imperfect glazed paint, bronze hammered patina and restrained edge glints, wood real painted grain, olive and cypress foliage finely layered brushstrokes and bark texture. Sophisticated textured gouache and tempera painting with crisp controlled illustrated edges, not photorealism or 3D. Texture each material differently, never apply one generic noise filter. Keep the central paving texture lower contrast than the props, so a small hero remains legible. Preserve the original color palette and light direction. Do not enlarge objects, move the camera, build new architecture, introduce characters, cover the center, add interface/text or invent a new composition. The output canvas may extend vertically for 3:2 framing; do so by gently extending the perimeter while keeping the original view intact, never stretching or tilting the scene.'''
JOBS = [
    ('meshy_output/20260907_191713_a-cour-des-sources_01a07cdf', 'A_cour_des_sources', 'Cour des Sources — matières V4', 'Warm luminous limestone and sage-green olive sanctuary. Complete the original blank white background with quiet painted distant cypress silhouettes and soft pale stone, without hiding existing shapes.'),
    ('meshy_output/20260907_191714_b-refuge-des-braises_01a07cdf', 'B_refuge_des_braises', 'Refuge des Braises — matières V4', 'Preserve the original protective underworld twilight: blue-violet stone shadows, amber firelight, oxblood merchant awning and turquoise water. Do not turn it into daylight or change the altar.'),
]

def main():
    os.chdir(ROOT)
    os.environ['MESHY_API_KEY'] = getpass.getpass('Meshy session key (hidden): ').strip()
    try:
        meshy._cmd_balance(None)
        print('PLAN: two GPT Image 2 material edits via Meshy, estimated 24 credits total.', flush=True)
        futures = {}
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            for folder, original_slug, title, variant in JOBS:
                d = ROOT / folder
                source = d / (original_slug + '.png')
                payload = {'ai_model': 'gpt-image-2', 'aspect_ratio': '3:2', 'reference_image_urls': ['data:image/png;base64,' + base64.b64encode(source.read_bytes()).decode('ascii')], 'prompt': PROMPT + '\n' + variant}
                task_id = meshy.create_task(ENDPOINT, payload)
                saved_payload = dict(payload)
                saved_payload['reference_image_urls'] = ['LOCAL_REFERENCE: ' + str(source.relative_to(ROOT))]
                (d / 'payload_texture_v4.json').write_text(json.dumps(saved_payload, ensure_ascii=False, indent=2), encoding='utf-8')
                meshy.record_task(str(d), task_id, 'image-to-image', 'texture_v4_created', prompt=title)
                futures[pool.submit(meshy.poll_task, ENDPOINT, task_id, 900)] = (d, original_slug + '_texture_v4', title)
            for future in concurrent.futures.as_completed(futures):
                d, slug, title = futures[future]
                task = future.result()
                (d / 'task_texture_v4.json').write_text(json.dumps(task, ensure_ascii=False, indent=2), encoding='utf-8')
                image_path = d / (slug + '.png')
                meshy.download(task['image_urls'][0], str(image_path))
                meshy.record_task(str(d), task['id'], 'image-to-image', 'texture_v4_completed_review_pending', prompt=title, files=[image_path.name])
                (d / 'review_status.json').write_text(json.dumps({'title': title, 'status': 'texture_v4_awaiting_visual_review', 'approved_by_user': False}, ensure_ascii=False, indent=2), encoding='utf-8')
                print(json.dumps({'title': title, 'path': str(image_path), 'task_id': task['id'], 'consumed_credits': task.get('consumed_credits')}, ensure_ascii=False), flush=True)
        meshy._cmd_balance(None)
    finally:
        os.environ.pop('MESHY_API_KEY', None)

if __name__ == '__main__':
    main()
