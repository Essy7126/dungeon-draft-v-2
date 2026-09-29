"""Calculs de conception, sans simulation du combat Godot. Python standard uniquement."""
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOURCES = [
    "data/cards/consumable_v2/catalog.json",
    "core/expedition/catabase_route_v6.gd",
    "core/expedition/consumable_cards_state.gd",
    "core/expedition/consumable_card_economy.gd",
    "core/expedition/consumable_cards_integration.gd",
    "core/expedition/consumable_card_math.gd",
]


def mastery(n):
    """Bonus en points de pourcentage, hors équipement et classe."""
    assert isinstance(n, int) and n >= 0
    return 3 * min(n, 4) + 2 * min(max(n - 4, 0), 4) + max(n - 8, 0)


def tiered_cost(rank, block, costs):
    return sum(costs[min(i // block, len(costs) - 1)] for i in range(rank))


def affordable(budget, block, costs):
    rank = 0
    while tiered_cost(rank + 1, block, costs) <= budget:
        rank += 1
    return rank, budget - tiered_cost(rank, block, costs)


def allocations(total, count):
    if count == 1:
        yield (total,)
        return
    for n in range(total + 1):
        for tail in allocations(total - n, count - 1):
            yield (n,) + tail


def best(weights, total=26):
    # Utilité numérique pondérée par la contribution DE BASE, pas par le nombre de cartes.
    rows = [(sum(w * mastery(n) for w, n in zip(weights, a)), a)
            for a in allocations(total, len(weights))]
    score = max(row[0] for row in rows)
    optima = [a for value, a in rows if math.isclose(value, score, abs_tol=1e-9)]
    return {"weights": weights, "best_bonus_pct": round(score, 6), "allocations": optima}


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    catalog = json.loads((ROOT / SOURCES[0]).read_text(encoding="utf-8"))
    rules = catalog["rules"]
    route = (ROOT / SOURCES[1]).read_text(encoding="utf-8")
    economy = (ROOT / SOURCES[3]).read_text(encoding="utf-8")
    depths = json.loads(re.search(r"const COMBAT_DEPTHS := (\[[^\n]+\])", route)[1])
    assert "if int(encounter.index) != 12:" in economy, "Réexaminer le paiement XP du boss."
    assert len(depths) == len(rules["xp"]) == len(rules["prowess"]) == 12
    xp, cadence = 0, []
    for i, reward in enumerate(rules["xp"], start=1):
        paid = reward if i != 12 else 0
        xp += paid
        level = sum(xp >= threshold for threshold in rules["xpThresholds"])
        cadence.append({"combat": i, "depth": depths[i-1], "paid_xp": paid,
                        "cumulative_xp": xp, "level_after": level})
    assert [x["level_after"] for x in cadence] == list(range(2, 13)) + [12]

    levels = []
    for level in range(1, 13):
        points = 4 + 2 * (level - 1)
        aptitudes = sum(level >= n for n in (3, 6, 9))
        old = rules["prowess"][level-1] * (1 + rules["attributes"]["power"] * (level // 2))
        new_factor = 1 + mastery(points) / 100 + .06 * aptitudes
        calibration = old / new_factor
        levels.append({"level": level, "element_points": points, "aptitude_points": aptitudes,
                       "training_slots": sum(level >= n for n in (4, 8, 12)),
                       "specialization": level >= 4,
                       "current_power": rules["prowess"][level-1],
                       "current_hp": rules["hp"][level-1],
                       "old_all_power_proxy": round(old, 6),
                       "proposed_max_direct_factor": round(new_factor, 6),
                       "calibrated_power_reference": round(calibration, 6),
                       "calibrated_power_rounded": math.floor(calibration + .5)})

    dofus_pure, unused = affordable(300, 100, [1, 2, 3, 4])
    dofus_dual, unused_half = affordable(150, 100, [1, 2, 3, 4])
    assert (dofus_pure, unused, dofus_dual, unused_half) == (200, 0, 125, 0)
    assert [mastery(n) for n in (0, 4, 8, 13, 26)] == [0, 12, 20, 25, 38]
    # Pas de rang négatif, gain marginal positif et non croissant sur tout le budget.
    increments = [mastery(n) - mastery(n-1) for n in range(1, 27)]
    assert increments == sorted(increments, reverse=True)

    profiles = {}
    for name, allocation in {"mono": [26, 0, 0, 0, 0, 0], "dual": [13, 13, 0, 0, 0, 0],
                             "triple": [9, 9, 8, 0, 0, 0], "six": [5, 5, 4, 4, 4, 4]}.items():
        assert sum(allocation) == 26
        bonuses = list(map(mastery, allocation))
        profiles[name] = {"points": allocation, "bonus_pct": bonuses,
                          "value_base20_first": round(20 * (1 + bonuses[0]/100), 4),
                          "value_base20_half_first_second": round(20 * (1 + (bonuses[0]+bonuses[1])/200), 4)}

    current_p = rules["prowess"][-1]
    old_proxy = current_p * 1.30
    raw_new = current_p * 1.56
    output = {
        "scope": "Modèle arithmétique de conception, pas des taux de victoire ni une validation Godot.",
        "source_head": subprocess.check_output(["git", "-c", f"safe.directory={ROOT.as_posix()}", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "sha256": {s: hashlib.sha256((ROOT/s).read_bytes()).hexdigest() for s in SOURCES},
        "current_cadence": cadence, "proposed_levels": levels,
        "dofus_budget300": {"pure": [dofus_pure, 0], "dual": [dofus_dual, dofus_dual],
                            "hypothetical_8_plus_8": {"pure": 8*(1+dofus_pure/100)+8,
                                                       "dual": 16*(1+dofus_dual/100)},
                            "hypothetical_16_first": {"pure": 16*(1+dofus_pure/100),
                                                       "dual": 16*(1+dofus_dual/100)}},
        "models_budget26": {
            "linear_2pct": {"mono_pct": 52, "dual_each_pct": 26},
            "cost_1_2_3_per4_ranks_gain3pct": {"mono_rank_remainder": affordable(26, 4, [1,2,3]),
                "dual_each_rank_remainder": affordable(13, 4, [1,2,3])},
            "diminishing_3_2_1": profiles},
        "optimization": [best(w) for w in ([.5,.5], [.65,.35], [.75,.25], [.8,.2], [1.,0.], [1/3,1/3,1/3])],
        "power_budget": {"current_growth": current_p/rules["prowess"][0],
            "old_all_power": old_proxy, "new_mastery_only": current_p*1.38,
            "new_mastery_and_contact": raw_new, "increase_pct": (raw_new/old_proxy-1)*100,
            "if_native10_also_added": current_p*1.66,
            "native10_increase_vs_old_pct": (current_p*1.66/old_proxy-1)*100,
            "old_all_vitality_hp": rules["hp"][-1]*1.36,
            "new_all_vitality_hp": rules["hp"][-1]*1.24},
    }
    (HERE / "CALCULS.json").write_text(json.dumps(output, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    lines = ["# Parcours chiffré du prototype", "", "Généré par `calculs.py`. Les colonnes Points/Aptitudes/Perfectionnements sont cumulées.", "",
             "| Niveau | Après combat / profondeur | XP cumulée actuelle | Points élémentaires | Aptitudes | Perfectionnements | P de référence expérimentale |",
             "|---|---|---|---|---|---|---|"]
    for row in levels:
        i = row["level"]-1
        c = cadence[i-1] if i else None
        lines.append(f'| {i+1} | {str(c["combat"])+" / "+str(c["depth"]) if c else "Départ"} | {c["cumulative_xp"] if c else 0} | {row["element_points"]} | {row["aptitude_points"]} | {row["training_slots"]} | {row["calibrated_power_rounded"]} |')
    lines += ["", "La dernière colonne neutralise seulement un profil théorique de dégâts directs monoélément + Contact. Elle ne valide ni les autres profils, ni l'attaque de base, ni les ennemis. Voir README."]
    (HERE / "PARCOURS.md").write_text("\n".join(lines)+"\n", encoding="utf-8")
    print(json.dumps({"checks": "cadence, coût Dofus, budgets, rendements décroissants : OK",
                      "head": output["source_head"], "final_xp": xp,
                      "experimental_power_curve": [r["calibrated_power_rounded"] for r in levels],
                      "optimization": output["optimization"], "power_budget": output["power_budget"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
