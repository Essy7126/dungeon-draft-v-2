"""Consistency checks for the design laboratory; does not test the Godot game."""
import csv
import hashlib
import json
import re
from pathlib import Path
import model

HERE=Path(__file__).resolve().parent
checks=[]
def check(name, condition):
    if not condition: raise AssertionError(name)
    checks.append(name)

data=json.loads((HERE/'results.json').read_text(encoding='utf-8'))
check('Source graph unchanged since model execution',data['sha256']==hashlib.sha256(model.SOURCE.read_bytes()).hexdigest())
graph=model.enumerate_routes(False,False,True,include_paths=True)
# Independent dynamic-programming path total over constructed adjacency,
# compared with the recursive full-path enumeration used for the report.
counts={'d01_0':1}
for node_id,node in sorted(graph['nodes'].items(),key=lambda x:x[1]['depth']):
    for target in node['edges']: counts[target]=counts.get(target,0)+counts.get(node_id,0)
check('Independent DP agrees on 280 non-secret paths',counts['d20_0']==graph['total']==280)
check('Origin partition 160/80/40',graph['by_origin']==dict(puits=160,porte=80,barque=40))
check('14 to 16 combats in mixed uncertainty configuration',set(graph['fights'])=={'14','15','16'})
check('Syntactic loadouts counted exactly',data['syntactic_starts']==67584)
check('Single desired item probability agrees with (7/8)^5',abs(data['loot_at_least_one_in_5_offers']['1_useful']-(1-(7/8)**5))<1e-6)
for name,expected in [('combat_sensitivity.csv',2592),('combat_summary.csv',24),('guard_experiment.csv',648),('run_budget.csv',27)]:
    with (HERE/name).open(encoding='utf-8-sig') as f: rows=list(csv.DictReader(f))
    check(f'{name}: {expected} data rows',len(rows)==expected)

# Hand audit: duellist versus puits, mixed protection, no kit.
# T1: 46.8 damage kills 46-HP conductor; no attack by fondeur on odd turns.
# T2: two hits /1.15 leave fondeur alive; one magical24/1.22 impact.
# T3: first hit kills fondeur. Total loss 19.67213..., rounded19.67.
r=model.fight('duelliste','mixte','aucun','puits')
check('Hand-audited three-turn encounter',r['won'] and r['turns']==3 and r['net_loss']==19.67)
fake_nodes={'a':{'kind':'normal'},'b':{'kind':'hub'},'c':{'kind':'boss'}}
check('Hand-audited healing clamp',model.route_health_budget(['a','b','c'],fake_nodes,8,0)==65)
check('Budget fails strictly at zero HP',model.route_health_budget(['a']*11, fake_nodes,10,0) is None)
check('Finite onguents can rescue that budget',model.route_health_budget(['a']*11,fake_nodes,10,1)==18)
check('No combat rotation exceeds six AP',all(sum(a[0] for a in b['actions'])<=6 for b in model.BUILDS.values()))

catalog=(HERE/'CATALOGUE.md').read_text(encoding='utf-8')
check('24 root technique rows',len(re.findall(r'^\| \*\*T\d\d ',catalog,re.M))==24)
check('16 permanent relic rows',len(re.findall(r'^\| \*\*R\d\d ',catalog,re.M))==16)
check('24 build recipes',len(re.findall(r'^\| \*\*\d+\. ',catalog,re.M))==24)
for filename in ['README.md','CATALOGUE.md']:
    content=(HERE/filename).read_text(encoding='utf-8')
    for target in re.findall(r'\]\(([^)]+)\)',content):
        if not target.startswith(('http:','https:','#')):
            check(f'Local link resolves: {filename} -> {target}',(HERE/target).exists())
summary={'scope':'design artifacts only; no Godot runtime validation',
         'checks_passed':len(checks),'checks':checks,
         'words':{f:len((HERE/f).read_text(encoding='utf-8').split()) for f in ['README.md','CATALOGUE.md']}}
(HERE/'verification.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False,indent=2))
