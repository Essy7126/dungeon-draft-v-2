"""Meshy produit les vues fixes ; les animations sont créées localement."""
from pathlib import Path
import base64
import concurrent.futures
import getpass
import hashlib
import importlib
import json
import os
import sys

from creature_specs import ROOT, CREATURES


def load_meshy_helpers():
    """Charge le plugin uniquement à l'exécution de la commande distante."""
    sys.path.insert(0, str(ROOT / 'output/monster-meshy-deps'))
    sys.path.insert(0, str(Path.home() / '.codex/plugins/cache/openai-curated-remote/meshy-openai-plugin/0.4.1/skills/meshy-3d-generation/scripts'))
    return importlib.import_module('meshy_task')

BATCH = ROOT / 'meshy_output/20260908_monster_views_v1'
ENDPOINT = '/openapi/v1/image-to-image'
COMMON = '''Produce a precise CHARACTER TURNAROUND REFERENCE from the supplied approved monster illustration. This image contains exactly FOUR fixed neutral idle views of the SAME character. This is NOT an animation sprite sheet. All four views have identical equipment, colors, body proportions and anatomy, preserving the exact hand-drawn painted/cel-shaded graphic style, linework and materials of the approved reference.
LAYOUT: perfectly regular 2 columns by 2 rows, one complete isolated character in each quadrant, on pure solid magenta #FF00FF background including all holes between limbs and equipment. No magenta on character. All feet, tails, horns, staffs, spearheads and shields remain entirely inside their quadrant with generous 12 percent margins. Never crop or overlap neighboring drawings. No text, labels, numbers, dividers or grid lines. No shadows, floor, scenery, particles, spells or extra props.
FIXED ORTHOGRAPHIC GAME CAMERA, looking down25 degrees. EXACT VIEW PLACEMENT:
TOP LEFT: front three-quarter facing diagonally DOWN-RIGHT toward the viewer, front chest visible, face looking right.
TOP RIGHT: front three-quarter facing diagonally DOWN-LEFT toward the viewer, front chest visible, face looking left.
BOTTOM LEFT: REAR three-quarter facing diagonally UP-RIGHT away from the viewer, BACK of head and back of torso visible; do not draw front face/chest here.
BOTTOM RIGHT: REAR three-quarter facing diagonally UP-LEFT away from the viewer, BACK of head and back of torso visible; do not draw front face/chest here.
Draw four real views, not mirrored duplicates. The anatomical left and right hands keep the same equipment in all four views: front and back must be physically coherent. In each view choose an alert neutral idle stance with legs clearly separated and arms a little away from torso so joints can be articulated later. Every body part remains present. All four figures have the SAME scale, each occupying no more than70 percent of quadrant height. Shared upper-left neutral lighting. Include no alternate poses or actions. Preserve large clean dark contours and grouped painted shapes so the result remains legible as a small tactical game character.'''

def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')

def main():
    meshy = load_meshy_helpers()
    os.chdir(ROOT)
    BATCH.mkdir(parents=True, exist_ok=True)
    (BATCH / '.gdignore').touch()
    registry_path = BATCH / 'tasks.json'
    registry = json.loads(registry_path.read_text(encoding='utf-8')) if registry_path.exists() else {}
    os.environ['MESHY_API_KEY'] = getpass.getpass('Meshy session key (hidden): ').strip()
    try:
        meshy._cmd_balance(None)
        print('Fixed-view generation: four turnaround references, 48 credits estimated.', flush=True)
        pending=[]
        for slug, spec in CREATURES.items():
            if slug in registry:
                continue
            source = ROOT / spec['source']
            prompt = COMMON + '\nEXACT CHARACTER IDENTITY: ' + spec['identity']
            payload = {'ai_model':'gpt-image-2', 'aspect_ratio':'1:1', 'prompt':prompt, 'reference_image_urls':['data:image/png;base64,'+base64.b64encode(source.read_bytes()).decode('ascii')]}
            task_id=meshy.create_task(ENDPOINT,payload)
            directory=Path(meshy.get_project_dir(task_id,slug+'-fixed-views'))
            (directory/'.gdignore').touch()
            record={'slug':slug,'task_id':task_id,'project_dir':str(directory),'prompt':prompt,'model':'gpt-image-2','reference_path':str(source),'reference_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'view_cells':{'E':[0,0],'S':[1,0],'N':[0,1],'W':[1,1]},'status':'created'}
            registry[slug]=record
            save(directory/'request_metadata.json',record)
            save(registry_path,registry)
            meshy.record_task(str(directory),task_id,'image-to-image','created',prompt=slug+' fixed orientation reference')
            pending.append(record)
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            futures={pool.submit(meshy.poll_task,ENDPOINT,r['task_id'],1200):r for r in pending}
            for future in concurrent.futures.as_completed(futures):
                r=futures[future]
                directory=Path(r['project_dir'])
                try:
                    task=future.result()
                    save(directory/'task.json',task)
                    url=(task.get('image_urls') or [task.get('image_url')])[0]
                    image=directory/'source.png'
                    meshy.download(url,str(image))
                    if task.get('thumbnail_url'): meshy.save_thumbnail(str(directory),task['thumbnail_url'])
                    r.update(status='downloaded_pending_review',source_path=str(image),sha256=hashlib.sha256(image.read_bytes()).hexdigest(),consumed_credits=task.get('consumed_credits'))
                    meshy.record_task(str(directory),r['task_id'],'image-to-image','complete',files=['source.png'],prompt=r['slug']+' fixed views')
                    print(json.dumps({k:r[k] for k in ['slug','source_path','consumed_credits']},ensure_ascii=False),flush=True)
                except BaseException as exc:
                    r.update(status='failed',error=str(exc))
                    print('FAILED: '+str(exc),flush=True)
                save(registry_path,registry)
        meshy._cmd_balance(None)
    finally:
        os.environ.pop('MESHY_API_KEY',None)

if __name__=='__main__':main()
