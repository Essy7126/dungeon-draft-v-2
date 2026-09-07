"""Session-only Meshy production orchestration. Uses bundled plugin API helpers.

stdin commands: balance; batch ID ID ID ID; quit. No automatic paid retries.
"""
import contextlib
import getpass
import io
import json
import os
from pathlib import Path
import sys

import pip._vendor.requests as requests
sys.modules['requests'] = requests
sys.path.insert(0, str(Path.home() / '.codex/plugins/cache/openai-curated-remote/meshy-openai-plugin/0.4.1/skills/meshy-3d-generation/scripts'))
import meshy_task as meshy
ROOT = Path(__file__).resolve().parent.parent
os.chdir(ROOT)
PLAN = ROOT / 'meshy_output/catabase_ui_production_plan.json'
RECEIPT = ROOT / 'meshy_output/catabase_ui_production_receipt.json'


def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')


def cli(*args):
    previous = sys.argv
    sys.argv = ['meshy_task', *args]
    output = io.StringIO()
    try:
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            try:
                meshy.main()
            except SystemExit as exc:
                if exc.code not in (None, 0):
                    raise
    finally:
        sys.argv = previous
    return output.getvalue()


def balance():
    raw = cli('balance')
    result = json.loads(raw[raw.index('{'):])
    print('BALANCE ' + json.dumps(result), flush=True)
    return result


def batch(ids):
    plan = json.loads(PLAN.read_text(encoding='utf-8'))
    available = {job['id']:job for job in plan['jobs']}
    receipt = json.loads(RECEIPT.read_text(encoding='utf-8')) if RECEIPT.exists() else {'phase':plan['phase'],'jobs':[],'initial_balance':balance()}
    if not 1 <= len(ids) <= 4 or len(set(ids)) != len(ids):
        raise ValueError('A batch accepts one to four distinct known job IDs.')
    if any(i not in available for i in ids):
        raise ValueError('Unknown job ID.')
    done_ids = {job['id'] for job in receipt['jobs']}
    if any(i in done_ids for i in ids):
        raise ValueError('Already submitted job: resume its existing task instead of paying twice.')
    current = balance()
    estimate = sum(available[i]['estimated_credits'] for i in ids)
    if float(current.get('balance', 0)) < estimate:
        raise RuntimeError('Insufficient balance for this batch.')
    submitted = []
    for name in ids:
        job = available[name]
        task_id = meshy.create_task(job['endpoint'], job['payload'])
        directory = Path(meshy.get_project_dir(task_id, prompt='catabase-ui-'+name))
        entry = {**job,'task_id':task_id,'project_dir':str(directory),'status':'SUBMITTED'}
        save(directory / 'production_request.json', entry)
        receipt['jobs'].append(entry)
        save(RECEIPT, receipt)
        meshy.record_task(str(directory),task_id,'image-to-image','submitted',prompt=job['payload']['prompt'])
        submitted.append(entry)
        print('SUBMITTED '+name+' '+task_id+' '+str(directory),flush=True)
    for entry in submitted:
        directory = Path(entry['project_dir'])
        task = meshy.poll_task(entry['endpoint'], entry['task_id'], timeout=900)
        save(directory / ('task_'+entry['task_id']+'.json'),task)
        urls = task.get('image_urls',[])
        if not urls:
            raise RuntimeError('Succeeded task returned no image URL.')
        meshy.download(urls[0],str(directory / 'source.png'))
        if task.get('thumbnail_url'):
            meshy.save_thumbnail(str(directory),task['thumbnail_url'])
        entry.update(status=task['status'],consumed_credits=task.get('consumed_credits'),reported_model=task.get('ai_model'),source_path=str(directory / 'source.png'))
        save(directory / 'production_result.json',entry)
        meshy.record_task(str(directory),entry['task_id'],'image-to-image','complete',prompt=entry['payload']['prompt'],files=['source.png'])
        save(RECEIPT,receipt)
        print('COMPLETED '+entry['id']+' '+str(directory / 'source.png'),flush=True)
    receipt['latest_balance'] = balance()
    receipt['consumed_credits'] = sum(job.get('consumed_credits',0) for job in receipt['jobs'])
    save(RECEIPT,receipt)
    print('BATCH_COMPLETE '+','.join(ids)+'; total credits='+str(receipt['consumed_credits']),flush=True)


try:
    os.environ['MESHY_API_KEY'] = getpass.getpass('MESHY_API_KEY (session only): ').strip().replace('\\_', '_')
    raw = cli('check-env')
    key = os.environ['MESHY_API_KEY']
    print(raw.replace(key,'[redacted]').replace(key[:8]+'...','[redacted]'),flush=True)
    for line in sys.stdin:
        args = line.strip().split()
        if not args:
            continue
        try:
            if args[0] == 'balance':
                balance()
            elif args[0] == 'batch':
                batch(args[1:])
            elif args[0] == 'quit':
                break
            else:
                print('Commands: balance; batch ID [ID ...]; quit',flush=True)
        except BaseException as exc:
            print('ERROR '+type(exc).__name__+': '+str(exc),flush=True)
finally:
    os.environ.pop('MESHY_API_KEY',None)
