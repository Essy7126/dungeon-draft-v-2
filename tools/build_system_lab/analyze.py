"""Reproducible audit, not a combat/win-rate simulator. Standard library only.

Reads Godot's exported facts; exact DP for route budgets and loot roles. The
role model deliberately assumes all setup/payoff cards of one class connect.
It is an optimistic opportunity model, NOT a playable hybrid probability.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from collections import defaultdict
from pathlib import Path


def route_budgets(nodes, include_secrets):
    by_id = {n["id"]: n for n in nodes if include_secrets or not n["hidden"]}
    ways = defaultdict(lambda: defaultdict(int))
    roots = [n for n in by_id.values() if n["depth"] == 1]
    assert len(roots) == 1
    ways[roots[0]["id"]][(0, 0)] = 1
    endings = defaultdict(int)
    for n in sorted(by_id.values(), key=lambda n: (n["depth"], n["id"])):
        for (fights, xp), count in list(ways[n["id"]].items()):
            budget = fights + (n["xp"] > 0), xp + n["xp"]
            edges = [edge for edge in n["edges"] if edge in by_id]
            assert all(by_id[e]["depth"] > n["depth"] for e in edges)
            if not edges:
                assert n["depth"] == 20, f"Premature dead end: {n['id']}"
                endings[budget] += count
            for edge in edges:
                ways[edge][budget] += count
    return [dict(fights=k[0], xp=k[1], paths=v) for k, v in sorted(endings.items())]


def loot_roles(mode):
    # state: counts of foreign cards (capped at 2), role mask for each class.
    # The first foreign class is relabelled zero, exploiting symmetric pools.
    dist = {((0, 0, 0), (0, 0, 0)): 1.0}
    checkpoints = {}
    for fight in range(1, 12):
        base_p = 0.15 if fight <= 3 else 0.35 if fight <= 8 else 0.45
        nxt = defaultdict(float)
        for (counts, masks), mass in dist.items():
            any_foreign = any(counts)
            p = 1.0 if mode != "baseline" and fight == 3 and not any_foreign else base_p
            nxt[(counts, masks)] += mass * (1 - p)
            classes = [(0, 1.0)] if not any_foreign else list(enumerate(
                [0.6, 0.2, 0.2] if mode == "focused_after_refuge" and fight >= 6
                else [1 / 3] * 3
            ))
            for cls, cls_p in classes:
                # 15 hypothetical foreign cards: 3 setup, 3 payoff, 9 others.
                for role, role_p in [(1, 0.2), (2, 0.2), (0, 0.6)]:
                    nc, nm = list(counts), list(masks)
                    nc[cls] = min(2, nc[cls] + 1)
                    nm[cls] |= role
                    nxt[(tuple(nc), tuple(nm))] += mass * p * cls_p * role_p
        dist = nxt
        assert abs(sum(dist.values()) - 1) < 1e-10
        if fight in (3, 5, 6, 8, 11):
            checkpoints[fight] = {
                "at_least_one_foreign": sum(p for (c, _), p in dist.items() if any(c)),
                "two_same_foreign_class": sum(p for (c, _), p in dist.items() if 2 in c),
                "setup_and_payoff_same_class": sum(p for (_, m), p in dist.items() if 3 in m),
            }
    return checkpoints


def pioche():
    result = []
    for n in (8, 10, 12, 14):
        den = math.comb(n, 4)
        result.append({
            "deck": n,
            "at_least_one_of_two_core_copies": 1 - math.comb(n - 2, 4) / den,
            "two_distinct_singletons_together": math.comb(n - 2, 2) / den,
            "at_least_one_of_each_of_two_pairs": (
                1 - 2 * math.comb(n - 2, 4) / den + math.comb(n - 4, 4) / den
            ),
        })
    return result


def catalog_growth():
    # A desired class owns 15 cards. Adding foreign content should not silently
    # change the probability of drawing that class.
    return [dict(classes=c, flat_pool_native_probability=1 / c,
                 category_first_native_probability=0.65,
                 target_foreign_class_probability=0.35 / (c - 1))
            for c in (4, 8, 12)]


def run(engine):
    routes = []
    for r in engine["routes"]:
        for secrets in (False, True):
            budgets = route_budgets(r["nodes"], secrets)
            assert len(budgets) == 1 and budgets[0]["fights"] == 12
            routes.append(dict(seed=r["seed"], secrets=secrets, budgets=budgets))
    loot = {mode: loot_roles(mode) for mode in
            ("baseline", "first_foreign_by_three", "focused_after_refuge")}
    no_collision = [1.0, 0.0, 0.0, 0.0]
    for p in [0.15] * 3 + [0.35] * 5:
        nxt = [0.0] * 4
        for distinct, mass in enumerate(no_collision):
            nxt[distinct] += mass * (1 - p)
            if distinct < 3:
                nxt[distinct + 1] += mass * p * (3 - distinct) / 3
        no_collision = nxt
    assert math.isclose(loot["baseline"][8]["two_same_foreign_class"], 1 - sum(no_collision), abs_tol=1e-10)
    assert loot["first_foreign_by_three"][3]["at_least_one_foreign"] > 0.999999
    assert loot["focused_after_refuge"][11]["setup_and_payoff_same_class"] > loot["first_foreign_by_three"][11]["setup_and_payoff_same_class"]
    points = engine["legacy_points"]
    return {
        "scope": "exact opportunities, no enemy AI, no victory estimates",
        "engine_schema": engine["schema"], "routes": routes,
        "legacy_points": points,
        "production_expected_card_drops_before_boss": 11 + 3 + 11 * 0.25,
        "progression": engine["progression"], "loot_role_models": loot,
        "draw_probabilities": pioche(), "content_growth": catalog_growth(),
        "five_pairs_hand_four": {
            "probability_a_duplicate_family": 1 - math.comb(5, 4) * 2**4 / math.comb(10, 4),
            "expected_distinct_families": 5 * (1 - math.comb(8, 4) / math.comb(10, 4)),
            "meaning": "If every family is limited to one play per activation, duplicate copies cannot all be spent that turn.",
        },
        "assumptions": [
            "Loot model: 11 single-card rewards, 4 classes, all victories assumed; not current production drops.",
            "Role pairs are optimistic: any of 3 setup cards connects to any of 3 payoffs in the same class; 9 other cards.",
            "Focus variant: first foreign class selected, 60/20/20 conditional foreign weights from fight 6; unchanged foreign frequency.",
            "No claim that compatible ownership implies legal/effective use, simultaneous draw, or a good build.",
            "No secret discovery conditions evaluated: routes with secrets are potential topology only.",
            "Progression: legal sequential attribute spending, guaranteed victories, no glory, gear, passives or combat attrition.",
        ],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", type=Path, default=Path("artifacts/dev/build_system_lab/engine_audit.json"))
    parser.add_argument("--out", type=Path, default=Path("artifacts/dev/build_system_lab/analysis.json"))
    parser.add_argument("--validation", type=Path, required=True,
                        help="Passing dev.ps1 summary.json for the current laboratory tests")
    args = parser.parse_args()
    validation = json.loads(args.validation.read_text(encoding="utf-8-sig"))
    assert validation.get("passed") and validation.get("tests", 0) >= 10, "Incomplete or failed Godot validation"
    engine = json.loads(args.engine.read_text(encoding="utf-8"))
    assert engine.get("source_sha256"), "Export has no source fingerprints"
    for name, digest in engine["source_sha256"].items():
        assert hashlib.sha256(Path(name).read_bytes()).hexdigest() == digest, f"Stale export: {name}"
    report = run(engine)
    report["source_sha256"] = engine["source_sha256"]
    report["analysis_sha256"] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    report["validation"] = str(args.validation)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
