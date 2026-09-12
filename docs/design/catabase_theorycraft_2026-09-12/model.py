"""Design laboratory; standard library only. Does not execute or alter Godot.

Exact graph enumeration + explicit, deliberately coarse rotation/attrition model.
Enemy order is fixed by threat priority; no tactical grid, AI, dodge or critical RNG.
All proposed combat parameters are below. Rerun: python model.py
"""
from __future__ import annotations
import ast
import csv
import hashlib
import itertools
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOURCE = ROOT / 'core/expedition/expedition_route_itineraries.gd'
HALTS = {'hub', 'merchant', 'sanctuary', 'lore', 'cache', 'event'}

def enumerate_routes(secrets: bool, library_fight: bool, trial_fight: bool, mirrored=False, include_paths=False):
    source = SOURCE.read_text(encoding='utf-8')
    layers = ast.literal_eval(source.split('var layers: Array = ', 1)[1].split('\n\t]', 1)[0] + '\n\t]')
    nodes, rows = {}, []
    for depth, layer in enumerate(layers, 1):
        row = []
        for lane, (kind, title, reward) in enumerate(layer):
            if kind == 'unknown_fight': kind = 'normal'
            if kind == 'unknown_halt': kind = 'normal' if library_fight else 'lore'
            if kind == 'unknown_trial': kind = 'elite' if trial_fight else 'sanctuary'
            node_id = f'd{depth:02}_{lane}'
            nodes[node_id] = dict(kind=kind, title=title, depth=depth, edges=[])
            row.append(node_id)
        rows.append(row)
    for a, b in zip(rows, rows[1:]):
        for i, origin in enumerate(a):
            for j, target in enumerate(b):
                linked = j * len(a) // len(b) == i if len(b) >= len(a) else i * len(b) // len(a) == j
                if linked: nodes[origin]['edges'].append(target)
    if secrets:
        for depth, kind in [(8, 'sanctuary'), (16, 'lore')]:
            node_id = f'd{depth:02}_secret'
            # The shipped implementation connects to the displayed last lane.
            # After a whole-map mirror this is authored lane zero.
            nodes[node_id] = dict(kind=kind, title=node_id, depth=depth,
                                  edges=[rows[depth][0 if mirrored else -1]])
            for parent in rows[depth - 2]: nodes[parent]['edges'].append(node_id)
    paths = []
    def walk(node_id, path):
        path = path + [node_id]
        if not nodes[node_id]['edges']:
            kinds = [nodes[n]['kind'] for n in path]
            assert len(path) == 20
            paths.append(dict(path=path, origin=['puits', 'porte', 'barque'][int(path[1][-1])],
                              fights=sum(k not in HALTS for k in kinds), elites=kinds.count('elite'), hubs=kinds.count('hub')))
        for nxt in nodes[node_id]['edges']: walk(nxt, path)
    walk(rows[0][0], [])
    result = dict(secrets=secrets, library_fight=library_fight, trial_fight=trial_fight,
                mirrored=mirrored, total=len(paths),
                by_origin={o: sum(p['origin'] == o for p in paths) for o in ['puits','porte','barque']},
                fights={str(n): sum(p['fights'] == n for p in paths) for n in sorted({p['fights'] for p in paths})},
                elite_range=[min(p['elites'] for p in paths), max(p['elites'] for p in paths)],
                hub_range=[min(p['hubs'] for p in paths), max(p['hubs'] for p in paths)])
    if include_paths: result.update(paths=paths,nodes=nodes)
    return result

def route_health_budget(path, nodes, normal_loss, salves):
    """Exact health ledger for ASSUMED costs, not a run combat simulator.

    110 constant maximum HP; normal loss n, elite ceil(1.75*n+5), boss45.
    Free hubs heal33; each finite salve heals18 before a fight. Dynamic
    programming tries all timings to avoid blaming a route for greedy healing.
    """
    states={(110,salves)}
    for node_id in path:
        kind=nodes[node_id]['kind']
        if kind=='hub':
            states={(min(110,hp+33),charges) for hp,charges in states}
        elif kind not in HALTS:
            loss=45 if kind=='boss' else math.ceil(1.75*normal_loss+5) if kind=='elite' else normal_loss
            options=set()
            for hp,charges in states:
                for spend in range(charges+1):
                    remaining=min(110,hp+spend*18)-loss
                    if remaining>0: options.add((remaining,charges-spend))
            # Keep the best HP for each remaining charge count.
            states={(max(h for h,c in options if c==charges),charges) for charges in {c for h,c in options}}
        if not states: return None
    return max(hp for hp,charges in states)

# Each rotation has <=6 AP. Damage coefficients multiply attack_power=18.
# category and damage-over-time are separate. Dot bypasses armor in THIS proposal.
# Control removes one action of the highest-priority living enemy, every other turn.
BUILDS = {
 'duelliste': dict(actions=[(3,1.30,'physical'),(3,1.30,'physical')], shield=0, ranged=False),
 'rempart': dict(actions=[(2,0,'guard'),(4,1.50,'physical')], shield=22, ranged=False),
 'briseur': dict(actions=[(4,1.50,'pierce'),(2,.75,'physical')], shield=0, ranged=False),
 'voltigeur': dict(actions=[(2,.80,'physical'),(2,.80,'physical'),(2,0,'retreat')], shield=0, ranged=True),
 'cendre': dict(actions=[(3,.90,'magic'),(2,.75,'physical'),(1,0,'brand')], shield=0, ranged=True),
 'entrave': dict(actions=[(3,.65,'sweep'),(2,0,'guard'),(1,0,'control')], shield=10, ranged=True),
 'sanguin': dict(actions=[(3,1.0,'physical'),(2,.80,'physical'),(1,0,'bleed')], shield=0, ranged=False),
 'foudroyant': dict(actions=[(4,1.30,'chain'),(2,.60,'magic')], shield=0, ranged=True),
}
ARMORS = {'airain':(55,0), 'sceau':(0,55), 'mixte':(22,22), 'legere':(10,10)}
KITS = ['aucun', 'purification', 'ancrage']

def enemy(name, hp, armor, mr, dmg, category, every=1, weak=False):
    return dict(name=name,hp=hp,armor=armor,mr=mr,dmg=dmg,category=category,every=every,weak=weak,dot=0,ticks=0)

def encounter(route):
    # Priority order is explicit and is not an inferred optimal AI.
    return {
      'puits':[enemy('conducteur',46,0,30,12,'magic',weak=True),enemy('fondeur',64,15,20,24,'magic',every=2)],
      'porte':[enemy('archer A',38,0,0,9,'physical'),enemy('archer B',38,0,0,9,'physical'),enemy('brute',90,70,0,18,'physical',every=2)],
      'barque':[enemy('officiant',55,10,25,16,'magic',every=2),enemy('molosse A',50,15,0,9,'physical'),enemy('molosse B',50,15,0,9,'physical')],
    }[route]

def fight(build_name, armor_name, kit, route, hp_scale=1., damage_scale=1., guard_rule='unlimited'):
    build, enemies = BUILDS[build_name], encounter(route)
    for e in enemies: e['hp'] *= hp_scale
    hp, raw_loss, weak, turns, trace = 110., 0., False, 0, []
    while hp > 0 and any(e['hp'] > 0 for e in enemies) and turns < 30:
        turns += 1
        shield, retreat, controlled = 0, False, None
        tax = 0
        # Explicit approximation of access: physical formation initially blocks
        # melee, while water movement periodically costs actions. Not a grid sim.
        if route == 'porte' and turns == 1 and not build['ranged']: tax += 2
        if route == 'barque' and turns % 3 == 1 and kit != 'ancrage': tax += 2
        ap = max(0, 6-tax)
        power = 18 * (.75 if weak and kit != 'purification' else 1.)
        weak = False
        direct_loss = 0
        for cost, coeff, tag in build['actions']:
            # Candidate B: great guard recovers on alternate turns; the free
            # 2 AP slot becomes an ordinary strike. No global turn-pressure.
            if build_name=='rempart' and guard_rule=='alternating' and turns%2==0 and tag=='guard':
                tag, coeff = 'physical', .75
            if cost > ap: continue
            ap -= cost
            living = [e for e in enemies if e['hp'] > 0]
            if not living: break
            target = living[0]
            if tag == 'guard': shield += build['shield']; continue
            if tag == 'retreat': retreat = True; continue
            if tag == 'control':
                if turns % 2 == 1: controlled = target['name']
                continue
            if tag in ('brand','bleed'):
                target['dot'], target['ticks'] = (6 if tag == 'brand' else 8), 2
                continue
            for index, e in enumerate(living[:2] if tag in ('chain','sweep') else [target]):
                defense = e['mr'] if tag in ('magic','chain') else e['armor']
                if tag == 'pierce': defense = 0
                amount = coeff*power*100/(100+defense)
                if tag == 'chain' and index == 1: amount *= .65
                actual = min(e['hp'],amount)
                e['hp'] -= amount
                direct_loss += actual
        if build_name == 'sanguin': hp = min(110,hp+min(5,direct_loss*.15))
        for e in enemies:
            if e['hp'] > 0 and e['ticks'] > 0:
                e['hp'] -= e['dot']; e['ticks'] -= 1
        for e in enemies:
            if e['hp'] <= 0 or e['name'] == controlled or turns % e['every'] != 0: continue
            defense = ARMORS[armor_name][e['category'] == 'magic']
            damage = e['dmg']*damage_scale*100/(100+defense)
            if retreat and e['category'] == 'physical': damage *= .65
            blocked = min(shield, damage)
            shield -= blocked
            damage -= blocked
            hp -= damage; raw_loss += damage
            if e['weak']: weak = True
            if hp <= 0: break
        trace.append(dict(turn=turns,hp=round(hp,2),enemy_hp=[round(max(0,e['hp']),2) for e in enemies]))
    return dict(build=build_name,armor=armor_name,kit=kit,route=route,guard_rule=guard_rule,hp_scale=hp_scale,
                damage_scale=damage_scale,turns=turns,won=hp>0 and all(e['hp']<=0 for e in enemies),
                hp_left=round(max(0,hp),2),net_loss=round(110-max(0,hp),2),gross_loss=round(raw_loss,2),trace=trace)

def write_csv(name, rows):
    with (HERE/name).open('w',encoding='utf-8-sig',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=list(rows[0]))
        writer.writeheader(); writer.writerows(rows)

def main():
    graphs = [enumerate_routes(*args) for args in itertools.product([False,True],repeat=4)]
    rows=[]
    for args in itertools.product(BUILDS, ARMORS, KITS, ['puits','porte','barque'], [.8,1.,1.2], [.8,1.,1.2]):
        rows.append(fight(*args))
    assert all(sum(a[0] for a in b['actions'])<=6 for b in BUILDS.values())
    assert fight('duelliste','airain','aucun','porte')['trace'] == fight('duelliste','airain','aucun','porte')['trace']
    assert 100/(100+55) < 100/(100+22)
    # Defensive upgrades must never worsen the matching single-category encounter.
    for b in BUILDS:
        assert fight(b,'airain','aucun','porte')['net_loss'] <= fight(b,'sceau','aucun','porte')['net_loss']
        assert fight(b,'sceau','aucun','puits')['net_loss'] <= fight(b,'airain','aucun','puits')['net_loss']
    write_csv('combat_sensitivity.csv',[{k:v for k,v in r.items() if k!='trace'} for r in rows])
    baseline=[r for r in rows if r['hp_scale']==r['damage_scale']==1]
    summary=[]
    for b in BUILDS:
        for route in ['puits','porte','barque']:
            options=[r for r in baseline if r['build']==b and r['route']==route]
            best=min(options,key=lambda r:(not r['won'],r['net_loss'],r['turns']))
            worst=max(options,key=lambda r:(not r['won'],r['net_loss'],r['turns']))
            summary.append(dict(build=b,route=route,best_loss=best['net_loss'],best_turns=best['turns'],
                                best_armor=best['armor'],best_kit=best['kit'],worst_loss=worst['net_loss'],worst_turns=worst['turns']))
    write_csv('combat_summary.csv',summary)
    variants=[fight('rempart',armor,kit,route,hs,ds,rule) for armor,kit,route,hs,ds,rule in
              itertools.product(ARMORS,KITS,['puits','porte','barque'],[.8,1.,1.2],[.8,1.,1.2],['unlimited','alternating'])]
    write_csv('guard_experiment.csv',[{k:v for k,v in r.items() if k!='trace'} for r in variants])
    budget_graph=enumerate_routes(False,False,True,include_paths=True)
    budgets=[]
    for normal_loss,salves,origin in itertools.product([8,12,16],[0,2,4],['puits','porte','barque']):
        paths=[p for p in budget_graph['paths'] if p['origin']==origin]
        outcomes=[route_health_budget(p['path'],budget_graph['nodes'],normal_loss,salves) for p in paths]
        budgets.append(dict(normal_loss=normal_loss,elite_loss=math.ceil(1.75*normal_loss+5),
                            boss_loss=45,salves=salves,origin=origin,paths=len(paths),
                            feasible_paths=sum(h is not None for h in outcomes),
                            highest_final_hp=max((h for h in outcomes if h is not None),default=0)))
    write_csv('run_budget.csv',budgets)
    starts=8*4*math.comb(12,2)*8*4
    # Independent offers; duplicates across offers permitted, no replacement within an offer.
    loot={f'{useful}_useful':round(1-(math.comb(24-useful,3)/math.comb(24,3))**5,6) for useful in [1,3,6]}
    result=dict(source=str(SOURCE.relative_to(ROOT)),sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                route_counts=graphs, syntactic_starts=starts,loot_at_least_one_in_5_offers=loot,
                simulations=len(rows),guard_comparisons=len(variants),model='deterministic rotation abstraction, not Godot playtests',
                baseline_examples=[r for r in baseline if r['build'] in ['duelliste','rempart','foudroyant'] and r['armor']=='mixte' and r['kit']=='aucun'])
    (HERE/'results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k not in ['baseline_examples','route_counts']},ensure_ascii=False,indent=2))
    print('ROUTES '+str([(g['secrets'],g['mirrored'],g['total']) for g in graphs if not g['library_fight'] and not g['trial_fight']]))
    print('COMBAT SUMMARY\n'+(HERE/'combat_summary.csv').read_text(encoding='utf-8-sig'))

if __name__=='__main__': main()
