"""Generate review-only 2D concepts using the official Meshy skill helpers.

The API key is entered without echo and exists only in this process environment.
Run from the repository root. No 3D task is created.
"""
from pathlib import Path
import concurrent.futures
import getpass
import json
import os
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'output/sanctuary-meshy-deps'))
sys.path.insert(0, str(Path.home() / '.codex/plugins/cache/openai-curated-remote/meshy-openai-plugin/0.4.1/skills/meshy-3d-generation/scripts'))
import meshy_task as meshy

ENDPOINT = '/openapi/v1/text-to-image'
COMMON = '''Create one exceptionally beautiful professional 2D hand-drawn isometric RPG sanctuary environment illustration, a playable hub for Achilles in an original Greek underworld fantasy. Landscape 16:9. Strict orthographic dimetric game camera, parallel ground axes with slopes +0.5 and -0.5 (2:1 isometric diamonds), no horizon, no perspective convergence. The environment fills the frame like a finished illustrated game map, NOT an isolated floating diorama. Thick-to-thin elegant hand-inked contours, expressive asymmetrical shapes, flat sculpted color masses with rich but restrained painterly gouache texture, selective detailed edges, mature French animated adventure art direction. Clearly and visibly DRAWN, never a 3D render, never photorealistic. Large readable forms at gameplay scale, warm bronze and terracotta accents. Composition: broad quiet connected limestone walking courtyard taking 55 percent of the screen, with a clear generous open foreground entry in the lower center. A small circular mosaic in the middle is an arrival landmark, not a raised plinth. Upper left: a charming compact merchant stall under a faded terracotta awning, ceramic amphorae, hanging bronze scales, a low counter, plenty of walking clearance in front. Upper right: a low oracle shrine with carved limestone, a votive basin and 2 small bronze braziers, clear approach space. Back center: a roofless monumental Greek gateway and cypress silhouettes, a calm destination for a future departure interaction. Right-hand outer edge: a modest inset turquoise water pool or canal with an unambiguous stone lip, visually separate from walking ground. Tree, low vegetation and broken stone framing at far edges only. Foreground kept low and open; no giant foreground columns hiding walkable ground. All destinations connected by wide paths, readable obstacle footprints, ground consistent at a single main walking level. No people or characters, no statues of people, no text, no labels, no UI, no grid overlay, no logos, no watermark, no split panels. Tiny restrained smoke wisps only above braziers, no fog across walking surface. Do not fill the center with stairs, ponds, furniture or architecture.'''
CONCEPTS = [
    ('A_cour_des_sources', 'Cour des Sources', '''Art variant A: a quiet welcoming sacred spring at the threshold of the underworld. Honey-ivory limestone, ochre grout, sage olive foliage, desaturated jade-teal water, small coral-red cloth accents. Pale warm late-afternoon illumination, soft blue-green cast shadows. Graceful stylized wind-shaped olive trees, tall dark cypresses behind the rear colonnade, a little ivy winding into old stone. Rich hand-drawn forms, bold silhouettes, warm inhabited atmosphere. Controlled bright value grouping on walking ground, darker framing edges. A premium illustrated sanctuary, intimate and inviting, melancholy myth rather than horror.'''),
    ('B_refuge_des_braises', 'Refuge des Braises', '''Art variant B: an intimate sacred refuge deeper in the Greek underworld at blue dusk. Warm ash-grey limestone and muted indigo-violet shadows, aged bronze, parchment ivory, desaturated turquoise sacred water, very selective amber firelight and deep oxblood awning. Spectral distant cypresses and an immense shadowed carved rock wall behind the rear gateway. Hand-drawn dark animated-fantasy storybook, beautiful graphic chiaroscuro, precise confident inked lines, warm pools of light around stall and shrine. Walking stone is mid-value and clearly readable; darkness belongs at the periphery. Calm, protective, inhabited and noble, no horror clutter, no neon overload, no volcanic lava.'''),
]

def main():
    os.chdir(ROOT)
    os.environ['MESHY_API_KEY'] = getpass.getpass('Meshy session key (hidden): ').strip()
    try:
        meshy._cmd_balance(None)
        print('PLAN: two 2D nano-banana-pro concepts; estimated 18 credits total. Awaiting command.', flush=True)
        if input('Command (generate/quit): ').strip() != 'generate':
            return
        projects = []
        for slug, title, variant in CONCEPTS:
            payload = {'ai_model': 'nano-banana-pro', 'aspect_ratio': '16:9', 'prompt': COMMON + '\n\n' + variant}
            task_id = meshy.create_task(ENDPOINT, payload)
            project_dir = Path(meshy.get_project_dir(task_id, slug))
            (project_dir / 'payload.json').write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
            (project_dir / 'review_status.json').write_text(json.dumps({'title': title, 'status': 'awaiting_visual_review', 'approved_by_user': False}, ensure_ascii=False, indent=2), encoding='utf-8')
            meshy.record_task(str(project_dir), task_id, 'text-to-image', 'created', prompt=title)
            projects.append((slug, title, task_id, project_dir))
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = [(p, pool.submit(meshy.poll_task, ENDPOINT, p[2], 900)) for p in projects]
            for (slug, title, task_id, project_dir), future in futures:
                task = future.result()
                (project_dir / 'task.json').write_text(json.dumps(task, ensure_ascii=False, indent=2), encoding='utf-8')
                url = next(iter(task.get('image_urls', [])), None) or task.get('image_url') or task.get('result', {}).get('image_url')
                if not url:
                    print('IMAGE_URL_MISSING; saved task JSON for inspection', flush=True)
                    continue
                image_path = project_dir / (slug + '.png')
                meshy.download(url, str(image_path))
                thumbnail = task.get('thumbnail_url')
                if thumbnail:
                    meshy.save_thumbnail(str(project_dir), thumbnail)
                meshy.record_task(str(project_dir), task_id, 'text-to-image', 'completed_review_pending', files=[image_path.name], prompt=title)
                print(json.dumps({'title': title, 'path': str(image_path.resolve()), 'task_id': task_id, 'consumed_credits': task.get('consumed_credits')}, ensure_ascii=False), flush=True)
        meshy._cmd_balance(None)
    finally:
        os.environ.pop('MESHY_API_KEY', None)

if __name__ == '__main__':
    main()
