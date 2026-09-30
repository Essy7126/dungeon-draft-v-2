"""Audit reproductible du catalogue actif ; ne modifie aucune donnée de jeu.

python analyse.py [--runtime artifacts/dev/.../observations.json]
Les hypothèses analytiques sont distinctes des observations du vrai moteur.
"""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
ELEMENTS = ("earth", "water", "fire", "wind", "night", "sun")
POWER = (16, 20, 23, 28, 34, 40, 47, 57, 66, 82, 86, 93)
CATALOG_PATH = ROOT / "data/cards/consumable_v2/catalog.json"
CATALOG = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


def mastery(n):
    return .03 * min(n, 4) + .02 * max(0, min(n - 4, 4)) + .01 * max(0, n - 8)


def rounded(x):
    return max(0, math.floor(x + .5))


def optimum(weights, budget):
    # Exact for separable concave mastery: take the largest remaining marginal.
    points = dict.fromkeys(ELEMENTS, 0)
    for _ in range(budget):
        e = max(ELEMENTS, key=lambda e: weights.get(e, 0) * (mastery(points[e] + 1) - mastery(points[e])))
        points[e] += 1
    return {"points": points, "bonus": sum(weights.get(e, 0) * mastery(points[e]) for e in ELEMENTS)}


def component(card, key, power, allocation):
    return power * card.get(key, 0) * (1 + sum(w * mastery(allocation.get(e, 0)) for e, w in card.get("elements", {}).get(key, {}).items()))


def evidence_hashes():
    paths = [CATALOG_PATH, *[ROOT / "core/expedition" / name for name in (
        "consumable_progression_v1.gd", "consumable_card_math.gd", "consumable_card_economy.gd",
        "consumable_card_effects.gd", "consumable_cards_profile.gd", "consumable_card_spells.gd")],
        ROOT / "tools/consumable_cards/prototype_v1_probe.gd", HERE / "candidats.json", Path(__file__)]
    return {str(p.relative_to(ROOT)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def candidates_check():
    candidate = json.loads((HERE / "candidats.json").read_text(encoding="utf-8"))
    active_ids = {row["id"] for key in ("cards", "equipment", "relics") for row in CATALOG[key]}
    seen = set()
    checks = 0

    def require(condition, label):
        nonlocal checks
        checks += 1
        if not condition:
            raise ValueError(label)

    for section in ("cards", "equipment", "relics", "enemy_traits"):
        for row in candidate[section]:
            require(row["id"] not in seen | active_ids, "Duplicate id: " + row["id"])
            seen.add(row["id"])
            require(row["status"] == "proposal_not_loaded", "Proposal status")
            require(isinstance(row["requires"], list), "Explicit dependencies")
    card_rows = []
    for row in candidate["cards"]:
        require(row["ap"] in range(1, 5) and 0 <= row["range"][0] <= row["range"][1] <= 5, "AP and range")
        require(row["affinity"] in ["shared", *[c["id"] for c in CATALOG["classes"]]], "Class affinity")
        require(row["copies_max"] == 3 and row["uses_per_turn"] == 1 and row["consume_copy"], "Finite copies and family limit")
        require(row["upgrade"] and row["effects"], "Explicit effects and upgrade")
        require(row["rarity"] in ("normal","elite","rare","legendary","god","immortal"), "Rarity")
        for effect in row["effects"]:
            if "weights" in effect:
                require(set(effect["weights"]) <= set(ELEMENTS), "Known elements")
                require(all(0 < n <= 1 for n in effect["weights"].values()), "Positive weights")
                require(math.isclose(sum(effect["weights"].values()), 1), "Weights sum to one")
            if "coefficient" in effect:
                require(math.isfinite(effect["coefficient"]) and effect["coefficient"] > 0 and "weights" in effect, "Finite positive scaled payload")
            if "duration" in effect:
                require(isinstance(effect["duration"],int) and 1 <= effect["duration"] <= 3, "Bounded integer duration")
            if effect["op"] in ("slow", "push", "pull", "exposure"):
                require("weights" not in effect, "Integer utility must not scale with mastery")
            require(effect["target"] in ("self", "enemy", "enemies_in_area"), "Target domain")
        for key, patch in row["upgrade"].items():
            index = int(key)
            require(0 <= index < len(row["effects"]), "Upgrade component exists")
            require(set(patch) <= {"coefficient", "duration", "tiles", "maximum"}, "Upgrade fields")
            require(all(math.isfinite(v) and v > 0 for v in patch.values()), "Positive upgrade quantities")
        for level in (1, 6, 12):
            allocation = {e: 4 + 2 * (level - 1) for e in ELEMENTS}
            # Each row is a distinct mono-element build, NOT all masteries simultaneously.
            for e in ELEMENTS:
                amounts = []
                for effect in row["effects"]:
                    if "coefficient" in effect:
                        raw = POWER[level - 1] * effect["coefficient"] * (1 + effect["weights"].get(e, 0) * mastery(allocation[e]))
                        amounts.append({"op": effect["op"], "raw": raw, "rounded_no_defense": rounded(raw)})
                card_rows.append({"id": row["id"], "level": level, "mono_element": e, "effects": amounts})
    for row in candidate["equipment"]:
        require(row["slot"] == "amulet" and row["stage"] == 2, "Equipment slot and stage")
        require(len(row["mods"]) == 2 and all(n == .08 for n in row["mods"].values()), "Dual mastery budget")
        require(all(k.removeprefix("mastery_") in ELEMENTS for k in row["mods"]), "Known equipment stats")
    for row in candidate["relics"]:
        require(row["cap"]["count"] > 0 and row["cap"]["scope"] in ("round", "combat"), "Relic trigger cap")
        require(row["recursive"] is False and row["trigger"] and row["order"], "Relic provenance and order")
    for row in candidate["enemy_traits"]:
        require(bool(row["stacking"]) and bool(row["boss_rule"]), "Trait stacking and boss contract")
        if "resistance_delta" in row:
            require(set(row["resistance_delta"]) <= set(ELEMENTS), "Trait element domain")
            require(all(-.10 <= v <= .15 for v in row["resistance_delta"].values()), "Bounded trial resistances")
    return {"passed": True, "assertions": checks, "counts": {k: len(candidate[k]) for k in ("cards", "equipment", "relics", "enemy_traits")}, "card_values": card_rows}


def analyse(runtime=None):
    cards = CATALOG["cards"]
    results = {"scope": "Arithmetic audit, not human win-rate. Runtime observations are reported separately.", "source_sha256": evidence_hashes(), "catalog_counts": {k: len(CATALOG[k]) for k in ("cards", "classes", "equipment", "relics")}}
    results["hybrids"] = []
    for weight in (1, .8, .7, .6, .5):
        values = [(n, 26-n, weight*mastery(n)+(1-weight)*mastery(26-n)) for n in range(27)]
        best = max(v[2] for v in values)
        results["hybrids"].append({"weight_primary": weight, "best_bonus": best, "optimal_allocations": [v[:2] for v in values if math.isclose(v[2], best)], "mono_bonus": weight*mastery(26), "13_13_bonus": mastery(13)})
    results["coverage"] = {e: {} for e in ELEMENTS}
    for e in ELEMENTS:
        results["coverage"][e] = {
            "normal_any_component_ge50": [c["id"] for c in cards if c["rarity"] == "normal" and any(ws.get(e, 0) >= .5 for ws in c["elements"].values())],
            "normal_damage_ge50": [c["id"] for c in cards if c["rarity"] == "normal" and c.get("damage", 0) > 0 and c["elements"].get("damage", {}).get(e, 0) >= .5],
            "all_any_component": [c["id"] for c in cards if any(ws.get(e, 0) > 0 for ws in c["elements"].values())]}
    results["drops_normal"] = []
    for cls in CATALOG["classes"]:
        normal = [c for c in cards if c["rarity"] == "normal"]
        native = [c for c in normal if c["affinity"] in ("shared", cls["id"])]
        foreign = [c for c in normal if c not in native]
        for e in ELEMENTS:
            probability = sum(mix * sum(any(w.get(e, 0) >= .5 for w in c["elements"].values()) for c in pool) / len(pool) for pool, mix in ((native,.7), (foreign,.3)))
            results["drops_normal"].append({"class": cls["id"], "element": e, "p_aligned": probability, "p_zero_aligned_after_6_normal_draws": (1-probability)**6})
    eligible = [i for i in CATALOG["equipment"] if i["stage"] <= 1]
    results["early_gear"] = {"eligible_count": len(eligible), "amulet_count": sum(i["slot"] == "amulet" for i in eligible), "mastery_seals": sum(i["id"].startswith("j_mastery_") for i in eligible), "slots": {slot: sum(i["slot"]==slot for i in eligible) for slot in ("weapon","body","head","feet","belt","amulet")}}
    results["fallback_rounding"] = []
    for cls in CATALOG["classes"]:
        basic = cls["basicAttack"]
        for e in ELEMENTS:
            without = 16 * basic["damage"]
            with_points = component(basic, "damage", 16, {e: 4})
            results["fallback_rounding"].append({"class": cls["id"], "element": e, "raw_without": without, "raw_with": with_points, "damage_without": rounded(without), "damage_with": rounded(with_points)})
    results["progression"] = [{"level": i+1, "power": p, "hp": CATALOG["rules"]["hp"][i], "budget": 4+2*i, "mono_multiplier": 1+mastery(4+2*i), "power_gain_previous": None if i==0 else p/POWER[i-1]-1} for i,p in enumerate(POWER)]
    results["copy_vs_ap"] = [{"id":c["id"], "ap":c["ap"], "direct_P_per_copy":c["damage"], "direct_P_per_AP": c["damage"]/c["ap"], "periodic_P_if_all_ticks": c.get("amount",0)*c.get("duration",0) if c["op"] in ("burn","bleed") else 0} for c in cards]
    results["burn_synergies"] = []
    for name, direct, tick, ap in (("Braise tenace",.55,.18,2),("Tison de poche candidat",.30,.10,1)):
        for embers, pyre in ((False,False),(True,False),(True,True)):
            initial=40*direct*(1+mastery(14))
            periodic=40*(tick+.1*embers+.1*pyre)*(1+mastery(14))
            results["burn_synergies"].append({"card":name,"embers":embers,"pyre_first_application":pyre,"ap":ap,"raw_total_if_two_ticks":initial+2*periodic,"rounded_total_no_defense":rounded(initial)+2*rounded(periodic),"rounded_per_AP":(rounded(initial)+2*rounded(periodic))/ap})
    results["candidate_debt_tradeoff"] = [{"allocation":a,"damage":rounded(component({"damage":.6,"elements":{"damage":{"night":1}}},"damage",40,a)),"guard":rounded(component({"amount":.35,"elements":{"amount":{"water":1}}},"amount",40,a))} for a in ({"night":14},{"night":7,"water":7},{"water":14})]
    if runtime:
        observed = json.loads(Path(runtime).read_text(encoding="utf-8"))
        strict = json.loads(Path(runtime).with_name("summary.json").read_text(encoding="utf-8"))
        assert strict["passed"] and not strict["diagnostics"], "Runtime strict report must pass"
        assert observed["completed"] and not observed["failures"]
        assert len(observed["trials"]) in (6,24)
        for trial in observed["trials"]:
            assert trial["casts"] and not any(c["failed"] for c in trial["casts"])
            assert trial["appearance"] == "res://characters/achilles/2d/passe_rive_s19_backend.gd"
        assert len(observed["numerical"]) == 1728
        mismatches = []
        by_id = {c["id"]:c for c in cards}
        for row in observed["numerical"]:
            card = by_id[row["id"]].copy()
            if row["upgraded"]: card.update(card["upgrade"])
            raw = component(card,"damage",POWER[row["level"]-1],{row["element"]:4+2*(row["level"]-1)})
            if not math.isclose(raw,row["raw"],abs_tol=1e-5) or rounded(raw*.8)!=row["damage_r20"]:
                mismatches.append({"row":row,"python_raw":raw})
        results["runtime_crosscheck"] = {"path":str(Path(runtime)), "cases":1728,"mismatches":mismatches, "trials": [{"class":t["class"],"allocation":t["allocation"],"depth":t["depth"],"outcome":t["outcome"],"start":t["start"],"end":t["end"],"combat_end_hp":t["combat_end_hp"],"casts":len(t["casts"]),"failed_casts":sum(bool(c["failed"]) for c in t["casts"]),"enemy_casts":len(t["enemy_casts"])} for t in observed["trials"]]}
        assert not mismatches, mismatches[:3]
    results["candidates"] = candidates_check()
    (HERE/"resultats.json").write_text(json.dumps(results,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    with (HERE/"cartes_par_pa_et_copie.csv").open("w",newline="",encoding="utf-8-sig") as f:
        writer=csv.DictWriter(f,fieldnames=list(results["copy_vs_ap"][0]))
        writer.writeheader();writer.writerows(results["copy_vs_ap"])
    print(json.dumps({k:results[k] for k in ("catalog_counts","hybrids","early_gear")},ensure_ascii=False,indent=2))
    if runtime: print("Godot/Python: 1728 cas concordants ; essais réels:",len(results["runtime_crosscheck"]["trials"]))
    print("Contrats candidats:", results["candidates"]["assertions"], "contrôles réussis")


if __name__ == "__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--runtime")
    args=parser.parse_args();analyse(args.runtime)
