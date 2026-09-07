"""Material-rich second pass requested by the user; official Meshy helpers only."""
from pathlib import Path
import concurrent.futures
import getpass
import json
import os
from generate_meshy_concepts import ROOT, meshy

ENDPOINT = '/openapi/v1/image-to-image'
BRIEF = '''Refine the supplied original 2D illustrated Greek sanctuary RPG hub into a much more richly TEXTURED, premium hand-painted game environment. The user likes the drawing but explicitly wants substantially more texture. Keep the original identity, camera framing, functional composition and major object positions: merchant stall left, gateway back center, oracle shrine right, sacred water at right, open central walkable courtyard with a circular mosaic. Produce one full landscape image, no panels, no text.

The change must be obvious: replace the smooth flat cartoon fills with sophisticated tactile gouache and tempera painting, expressive layered brushstrokes, fine dry-brush grain, restrained hand-inked edge definition, nuanced warm/cool surface colors. Rich physical material identity everywhere while retaining beautiful drawn shapes. NOT photorealistic, NOT a 3D render, no plastic CGI, no generic procedural noise overlay.

LIMESTONE: irregular warm mineral granules, soft pore detail, chipped corners and hand-chisel marks, worn edges with subtle ochre dust, fine hairline cracks, faint mineral veins, tiny lichen near joints, restrained mottled weathering in stone shadows. Broad stone slabs remain quietly readable and reasonably clean at walking scale. MOSAIC: individually hand-cut irregular tesserae with minute edge wear and pigmented stone variation. CLOTH: visible woven fibers, fading pigment, thick sewn edges and small repairs, folds modeled with confident painterly strokes. POTTERY: granular terracotta, subtle uneven glaze, painted bands with imperfect handmade edges. BRONZE: aged patina, hammered surface, rubbed golden contact edges with green oxidation in recesses. FOLIAGE: overlapping clusters of individually suggested leaves, nuanced sage and cool green brushwork, woody bark and knotted roots; no flat solid-green masses. WATER: translucent layered teal paint, restrained fractured light reflections and depth variations, fine edge ripples with clear stone boundaries. WOOD: subtle carved grain, worn corners and painted warm highlights.

Use selective texture hierarchy: highest texture fidelity and storytelling marks around stall, shrine and perimeter; finer lower-contrast textural detail on the broad central walking ground. Render the scene with beautiful atmospheric depth, warm reflected light and carefully controlled shadow values. Keep the same noble calm Greek underworld sanctuary mood. Improve consistency of parallel 2:1 isometric ground axes without reducing or filling the central walking space. Avoid thick uniform black cartoon outlines; use varied colored ink and painted broken edges. No people, no characters, no labels, no interfaces, no new central obstacles, no giant decorative props, no dense fog over the ground.'''
JOBS = [
    ('meshy_output/20260907_191713_a-cour-des-sources_01a07cdf', 'A_cour_des_sources_texture_v2', 'Cour des Sources — matières peintes', 'Keep the warm honey limestone, muted sage olive leaves, coral awning and pale jade water. Replace the empty white strip at the top with a coherent soft painted background of distant muted cypresses and pale mineral rock, filling the frame as an inhabited sanctuary. Increase rich painted material detail substantially while retaining a luminous welcoming atmosphere.'),
    ('meshy_output/20260907_191714_b-refuge-des-braises_01a07cdf', 'B_refuge_des_braises_texture_v2', 'Refuge des Braises — matières peintes', 'Keep the blue-violet twilight, amber braziers, oxblood awning, turquoise sacred water and protective underworld mood. Add clearly visible hand-painted material texture and subtle warm reflected light into stone and objects. Lift the very darkest perimeter values slightly so brushwork remains visible. Retain a clear quieter center for the hero.'),
]

def main():
    os.chdir(ROOT)
    os.environ['MESHY_API_KEY'] = getpass.getpass('Meshy session key (hidden): ').strip()
    try:
        meshy._cmd_balance(None)
        print('PLAN: two requested image-to-image texture revisions, estimated 18 credits total.', flush=True)
        projects = []
        for folder, slug, title, variant in JOBS:
            project_dir = ROOT / folder
            original = json.loads((project_dir / 'task.json').read_text(encoding='utf-8'))
            payload = {'ai_model': 'nano-banana-pro', 'aspect_ratio': '16:9', 'reference_image_urls': [original['image_urls'][0]], 'prompt': BRIEF + '\n\n' + variant}
            task_id = meshy.create_task(ENDPOINT, payload)
            (project_dir / 'payload_texture_v2.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
            meshy.record_task(str(project_dir), task_id, 'image-to-image', 'texture_v2_created', prompt=title)
            projects.append((slug, title, task_id, project_dir))
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = {pool.submit(meshy.poll_task, ENDPOINT, p[2], 900): p for p in projects}
            for future in concurrent.futures.as_completed(futures):
                slug, title, task_id, project_dir = futures[future]
                task = future.result()
                (project_dir / 'task_texture_v2.json').write_text(json.dumps(task, ensure_ascii=False, indent=2), encoding='utf-8')
                url = next(iter(task.get('image_urls', [])), None) or task.get('image_url')
                if not url:
                    raise ValueError('Missing image URL; full response saved for inspection')
                image_path = project_dir / (slug + '.png')
                meshy.download(url, str(image_path))
                if task.get('thumbnail_url'):
                    meshy.save_thumbnail(str(project_dir), task['thumbnail_url'])
                meshy.record_task(str(project_dir), task_id, 'image-to-image', 'texture_v2_completed_review_pending', prompt=title, files=[image_path.name])
                review = {'title': title, 'status': 'texture_v2_awaiting_visual_review', 'approved_by_user': False, 'user_revision_request': 'Davantage de texture, en conservant le dessin.'}
                (project_dir / 'review_status.json').write_text(json.dumps(review, ensure_ascii=False, indent=2), encoding='utf-8')
                print(json.dumps({'title': title, 'path': str(image_path), 'task_id': task_id, 'consumed_credits': task.get('consumed_credits')}, ensure_ascii=False), flush=True)
        meshy._cmd_balance(None)
    finally:
        os.environ.pop('MESHY_API_KEY', None)

if __name__ == '__main__':
    main()
