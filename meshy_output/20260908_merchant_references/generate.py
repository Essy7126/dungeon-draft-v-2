"""Generate the three prepared merchant references using the Meshy skill helpers.

Default: local preflight only. --generate submits/resumes paid API jobs.
--key-prompt accepts a hidden key for this process only, never persisted.
"""
from pathlib import Path
import argparse
import base64
import getpass
import json
import os
import sys

BATCH = Path(__file__).resolve().parent
ROOT = BATCH.parent.parent
SKILL = Path('C:/Users/p.montebello/.codex/plugins/cache/openai-curated-remote/meshy-openai-plugin/0.4.1/skills/meshy-3d-generation/scripts')
sys.path.insert(0, str(BATCH / 'deps'))
sys.path.insert(0, str(SKILL))
import meshy_task as meshy
from PIL import Image


def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--generate', action='store_true')
    parser.add_argument('--key-prompt', action='store_true')
    args = parser.parse_args()
    os.chdir(ROOT)
    spec = json.loads((BATCH / 'briefs.json').read_text(encoding='utf-8'))
    references = [BATCH / name for name in spec['reference_images']]
    for reference in references:
        with Image.open(reference) as img:
            img.verify()
        print(f'REFERENCE_OK: {reference.name}')
    assert len(spec['concepts']) == 3
    for concept in spec['concepts']:
        print(f'PREPARED: {concept["title"]}')
    print(f'ESTIMATED_TOTAL_CREDITS: {spec["estimated_total_credits"]}')
    if not args.generate:
        meshy._cmd_check_env(None)
        return
    original_key = os.environ.get('MESHY_API_KEY')
    try:
        if args.key_prompt:
            os.environ['MESHY_API_KEY'] = getpass.getpass('Meshy API key (hidden, session only): ').strip()
        if not meshy.load_api_key():
            raise SystemExit('MESHY_API_KEY missing. No paid task was created.')
        meshy._cmd_balance(None)
        journal_path = BATCH / 'jobs.json'
        journal = json.loads(journal_path.read_text(encoding='utf-8')) if journal_path.exists() else {}
        image_data = ['data:image/png;base64,' + base64.b64encode(p.read_bytes()).decode('ascii') for p in references]
        for concept in spec['concepts']:
            slug = concept['slug']
            if slug not in journal:
                payload = {
                    'ai_model': spec['ai_model'], 'aspect_ratio': spec['aspect_ratio'],
                    'prompt': spec['common_prompt'] + '\n\n' + concept['variant_prompt'],
                    'reference_image_urls': image_data,
                }
                task_id = meshy.create_task(spec['endpoint'], payload)
                journal[slug] = {'task_id': task_id, 'status': 'created'}
                save(journal_path, journal)
            job = journal[slug]
            if 'project_dir' not in job:
                job['project_dir'] = meshy.get_project_dir(job['task_id'], slug)
                save(journal_path, journal)
            project = Path(job['project_dir'])
            (project / '.gdignore').touch()
            save(project / 'prompt.json', {
                'ai_model': spec['ai_model'], 'aspect_ratio': spec['aspect_ratio'],
                'prompt': spec['common_prompt'] + '\n\n' + concept['variant_prompt'],
                'reference_files': [str(p) for p in references],
            })
            if job.get('status') == 'downloaded':
                print(f'ALREADY_DOWNLOADED: {job["image_path"]}')
                continue
            task = meshy.poll_task(spec['endpoint'], job['task_id'], timeout=900)
            save(project / 'task.json', task)
            urls = task.get('image_urls', [])
            url = (urls[0] if urls else None) or task.get('image_url') or task.get('result', {}).get('image_url')
            if not url:
                raise SystemExit(f'No image URL. Inspect {project / "task.json"}; existing job is retained.')
            output = project / f'{slug}.png'
            meshy.download(url, str(output))
            with Image.open(output) as img:
                img.verify()
            if task.get('thumbnail_url'):
                meshy.save_thumbnail(str(project), task['thumbnail_url'])
            meshy.record_task(str(project), job['task_id'], 'image-to-image', 'completed_review_pending', prompt=concept['title'], files=[output.name])
            job.update(status='downloaded', image_path=str(output), consumed_credits=task.get('consumed_credits'))
            save(journal_path, journal)
            print(json.dumps(job, ensure_ascii=False))
        meshy._cmd_balance(None)
    finally:
        if args.key_prompt:
            if original_key is None:
                os.environ.pop('MESHY_API_KEY', None)
            else:
                os.environ['MESHY_API_KEY'] = original_key


if __name__ == '__main__':
    main()
