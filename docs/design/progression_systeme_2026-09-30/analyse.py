"""Analyse de conception : aucun combat simulé, aucune règle active modifiée.

python analyse.py --output-dir artifacts/dev/<nouveau-dossier>
Les allocations sont exhaustives ; les expériences candidates restent analytiques.
"""
import argparse
import csv
from fractions import Fraction as F
import hashlib
import itertools
import json
import math
from pathlib import Path
import re
import subprocess
from datetime import datetime, timezone

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
ELEMENTS = ("earth", "water", "fire", "wind", "night", "sun")
checks = 0


def require(condition, message):
    global checks
    checks += 1
    if not condition:
        raise ValueError(message)


def mastery(points):
    require(isinstance(points, int) and 0 <= points <= 26, "Allocated points domain")
    return F(3 * min(points, 4) + 2 * min(max(points - 4, 0), 4) + max(points - 8, 0), 100)


M = tuple(mastery(i) for i in range(27))


def rounded(value):
    return max(0, math.floor(value + F(1, 2)))


def allocations(total, dimensions):
    if dimensions == 1:
        yield (total,)
    else:
        for first in range(total + 1):
            for tail in allocations(total - first, dimensions - 1):
                yield (first,) + tail


def factor(weights, points):
    return 1 + sum(F(str(w)) * M[points.get(e, 0)] for e, w in weights.items())


def hands_probability(a, b, opening=False):
    # Disjoint functions, copies physically finite. Explicit enumeration, not RNG.
    deck = ["A"] * a + ["B"] * b + ["N"] * (15 - a - b)
    if opening:
        deck.remove("A")
    total = good = 0
    for indexes in itertools.combinations(range(len(deck)), 4 if opening else 5):
        hand = [deck[i] for i in indexes] + (["A"] if opening else [])
        total += 1
        good += "A" in hand and "B" in hand
    denominator = math.comb(14, 4) if opening else math.comb(15, 5)
    require(total == denominator and good > 0, "Complete hand enumeration")
    return {"providers": a, "consumers": b, "opening": opening,
            "hands": total, "successes": good, "probability": good / total}


def validate_candidates(catalog, candidate):
    active = {c["id"] for key in ("cards", "equipment", "relics") for c in catalog[key]}
    families = {c["id"]: c for c in catalog["cards"]}
    seen = set()
    require(candidate["status"] == "proposal_not_loaded", "Candidates remain proposals")
    require(candidate["training"]["levels"] == catalog["rules"]["trainingLevels"], "No extra training budget")
    require(candidate["training"]["element_prerequisites"] == [], "No elemental build gates")
    for entry in candidate["forms"] + candidate["cards"]:
        require(entry["id"] not in seen | active, "Candidate id collision")
        seen.add(entry["id"])
        require(entry["requires"] and 1 <= entry["ap"] <= 4, "Dependencies and action cost")
        require(0 <= entry["range"][0] <= entry["range"][1] <= 5, "Range bounds")
        if "family" in entry:
            require(entry["family"] in families, "Existing family")
            require(entry["ap"] == families[entry["family"]]["ap"], "No free AP in forms")
            require(entry["max_targets"] in (1, 2), "Bounded geometry")
            if "carry_fraction" in entry:
                require(0 <= entry["carry_fraction"] <= 1, "Guard carry cannot generate guard")
            weights = [entry["weights"]]
        else:
            require(entry["affinity"] == "shared" and entry["rarity"] == "normal", "Accessible prototypes")
            require(entry["copies_max"] == 3 and entry["uses_per_turn"] == 1, "Finite copy and cast limits")
            weights = [effect["weights"] for effect in entry["effects"]]
            for effect in entry["effects"]:
                require(effect["coefficient"] > 0 and effect["scaling"] in ("original", "captured_at_application"), "Explicit scaling")
                require(bool(effect["rounding"]), "Explicit rounding")
            for index, patch in entry["upgrade"].items():
                require(int(index) < len(entry["effects"]) and set(patch) == {"coefficient"}, "Upgrade target")
        for weight in weights:
            require(set(weight) <= set(ELEMENTS), "Known elements")
            require(sum(F(str(w)) for w in weight.values()) == 1, "Weights sum exactly to one")
    for aptitude in candidate["future_aptitudes"]:
        require(aptitude["budget"] == "same_three_aptitude_points" and aptitude["rank_cap"] == 3, "No extra aptitude points")
        require(aptitude["release_condition"] and aptitude["excludes"], "Content and provenance gates")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--runtime", type=Path)
    args = parser.parse_args()
    output = (ROOT / args.output_dir).resolve()
    require(output.is_relative_to(ROOT / "artifacts/dev"), "Reports must remain in artifacts/dev")
    output.mkdir(parents=True, exist_ok=False)
    catalog_path = ROOT / "data/cards/consumable_v2/catalog.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    candidate = json.loads((HERE / "candidats.json").read_text(encoding="utf-8"))
    progression_path = ROOT / "core/expedition/consumable_progression_v1.gd"
    source = progression_path.read_text(encoding="utf-8")
    profile = catalog["rules"].get("prototypeProgression")
    power = profile["power"] if profile else json.loads(re.search(r"const POWER := (\[[^\n]+\])", source)[1])
    require(len(power) == len(catalog["rules"]["hp"]) == 12, "Twelve-level curves")
    require(profile["masteryBands"] == [{"upTo": 4, "gain": .03}, {"upTo": 8, "gain": .02}, {"upTo": 0, "gain": .01}] if profile else "return .03 * mini(points, 4) + .02 * clampi(points - 4, 0, 4) + .01 * maxi(points - 8, 0)" in source, "Reaudit changed mastery rule")
    require((profile["initialElementPoints"], profile["elementPointsPerLevel"], profile["levelCap"]) == (4, 2, 12) if profile else "return 4 + 2 * (clampi(level, 1, 12) - 1)" in source, "Reaudit changed budget")
    validate_candidates(catalog, candidate)

    # Exhaustive legal final allocations, with rational scores (no approximate ties).
    matrix = list(allocations(26, 6))
    require(len(matrix) == math.comb(31, 5) == 169911, "Exhaustive six-element allocation count")
    require(all(sum(a) == 26 and min(a) >= 0 for a in matrix), "Legal final budgets")
    portfolios = [("mono", [1, 0, 0, 0, 0, 0]),
                  ("80_20", [F(4, 5), F(1, 5), 0, 0, 0, 0]),
                  ("65_35", [F(13, 20), F(7, 20), 0, 0, 0, 0]),
                  ("50_50", [F(1, 2), F(1, 2), 0, 0, 0, 0]),
                  ("three_equal", [F(1, 3)] * 3 + [0] * 3)]
    optimization = []
    for name, weights in portfolios:
        best_score, best = F(-1), []
        # Integer mastery percentage: scores exact and cheaper than multiplying fractions 6 times per allocation.
        rational_weights = [F(w) for w in weights]
        denominator = math.lcm(*(w.denominator for w in rational_weights))
        integer_weights = [int(w * denominator) for w in rational_weights]
        mastery_pct = [int(m * 100) for m in M]
        for allocation in matrix:
            score = sum(w * mastery_pct[n] for w, n in zip(integer_weights, allocation))
            if score > best_score:
                best_score, best = score, [allocation]
            elif score == best_score:
                best.append(allocation)
        optimization.append({"portfolio": name, "weights": [float(w) for w in weights],
                             "bonus_pct": float(F(best_score, denominator)), "optima": best})
    require(optimization[1]["optima"] == [(26, 0, 0, 0, 0, 0)], "80/20 mono optimum")
    require(len(optimization[3]["optima"]) == 11, "50/50 plateau includes all 8/18 through 18/8")

    normal = [c for c in catalog["cards"] if c["rarity"] == "normal"]
    coverage, loot = [], []
    for class_id in [c["id"] for c in catalog["classes"]]:
        native = [c for c in normal if c["affinity"] in ("shared", class_id)]
        foreign = [c for c in normal if c not in native]
        for element in ELEMENTS:
            eligible = lambda c: c["damage"] > 0 and c["elements"].get("damage", {}).get(element, 0) >= .5
            native_hits, foreign_hits = sum(map(eligible, native)), sum(map(eligible, foreign))
            probability = F(7, 10) * F(native_hits, len(native)) + F(3, 10) * F(foreign_hits, len(foreign))
            coverage.append({"class": class_id, "element": element,
                             "normal_native_or_shared_dominant_damage": native_hits,
                             "normal_global_dominant_damage": native_hits + foreign_hits})
            loot.append({"class": class_id, "element": element,
                         "p_one_normal_draw": float(probability),
                         "p_at_least_one_in_six_normal_draws": float(1 - (1 - probability) ** 6)})

    visibility = []
    quantitative = catalog["cards"] + [dict(c["basicAttack"], id="basic_" + c["id"], elements=c["basicAttack"]["elements"]) for c in catalog["classes"]]
    for level in range(2, 13):
        budget = 4 + 2 * (level - 1)
        rows = []
        for card in quantitative:
            for element, weight in card["elements"].get("damage", {}).items():
                coefficient = F(str(card.get("damage", 0)))
                if coefficient == 0:
                    continue
                before = coefficient * power[level-1] * (1 + F(str(weight)) * M[budget-2])
                after = coefficient * power[level-1] * (1 + F(str(weight)) * M[budget])
                rows.append({"id": card["id"], "element": element, "before": rounded(before), "after": rounded(after)})
        visibility.append({"level": level, "budget": budget, "cases": len(rows),
                           "unchanged": sum(r["before"] == r["after"] for r in rows), "rows": rows})

    # Do not sum healing and guard. Keep the tradeoff as two separate coordinates.
    pareto = []
    for water in range(15):
        sun = 14 - water
        raw_heal, raw_guard = F(45, 100) * 40 * (1 + M[water]), F(45, 100) * 40 * (1 + M[sun])
        pareto.append({"water": water, "sun": sun, "heal_raw": float(raw_heal), "guard_raw": float(raw_guard),
                       "heal": rounded(raw_heal), "guard": rounded(raw_guard)})

    # Explicit bounded timing fixtures; not encounter wins or AI simulations.
    forms = {f["id"]: f for f in candidate["forms"]}
    burn = []
    for periodic_rank in (0, 1, 3):
        for ticks in (0, 1, 2):
            for name in ("vive", "lente"):
                form = forms["ps30_braise_" + name]
                direct = F(str(form["damage"])) * 40 * (1 + M[14])
                periodic = F(str(form["tick"])) * 40 * (1 + M[14] + F(8 * periodic_rank, 100))
                burn.append({"form": name, "ticks_realized": ticks, "periodic_ranks": periodic_rank,
                             "direct": rounded(direct), "tick": rounded(periodic),
                             "total": rounded(direct) + ticks * rounded(periodic)})
    guard = []
    for incoming_first in (0, 10, 30, 50, 80):
        for name in ("massive", "tissee"):
            form = forms["ps30_garde_" + name]
            initial = rounded(F(str(form["guard"])) * 40 * (1 + M[14]))
            absorbed_first = min(initial, incoming_first)
            carried = rounded((initial - absorbed_first) * F(str(form["carry_fraction"])))
            absorbed_second = min(carried, 50)
            guard.append({"form": name, "incoming_first": incoming_first, "incoming_second": 50,
                          "initial": initial, "absorbed_first": absorbed_first, "carried": carried,
                          "absorbed_total": absorbed_first + absorbed_second})
    require(all(r["absorbed_total"] <= r["initial"] for r in guard), "No guard duplication by carry")
    trait = [{"targets": targets, "precis_total": rounded(F(6, 10) * 40 * (1 + M[14])),
              "traversant_per_target": rounded(F(35, 100) * 40 * (1 + M[14])),
              "traversant_total": targets * rounded(F(35, 100) * 40 * (1 + M[14]))} for targets in (1, 2)]
    require(trait[0]["precis_total"] > trait[0]["traversant_total"] and trait[1]["precis_total"] < trait[1]["traversant_total"], "Trait forms have opposite winning situations")
    require(burn[0]["total"] > burn[1]["total"] and burn[4]["total"] < burn[5]["total"], "Burn forms have opposite winning situations")
    rejected = {"slow_damage": .4, "slow_tick": .3, "ticks": 2,
                "totals_by_ticks_realized": [rounded(F(4, 10) * 40 * (1 + M[14])) + ticks * rounded(F(3, 10) * 40 * (1 + M[14])) for ticks in (0, 1, 2)],
                "fast_totals_by_ticks_realized": [burn[i]["total"] for i in (0, 2, 4)],
                "rejection": "Fast dominates for zero/one tick and ties for two ticks in this fixture. Timing redistribution alone is insufficient."}
    require(all(a >= b for a, b in zip(rejected["fast_totals_by_ticks_realized"], rejected["totals_by_ticks_realized"])), "Reject analytically dominated equal-total form")

    aptitude = []
    for level, (p, hp) in enumerate(zip(power, catalog["rules"]["hp"]), 1):
        # Same P, mastery, card and rounding on both sides; no class/spec/gear.
        b = 4 + 2 * (level - 1)
        baseline = rounded(F(115, 100) * p * (1 + M[b]))
        protected = rounded(F(115, 100) * p * (1 + M[b] + F(1, 10)))
        delta = protected - baseline
        vitality = rounded(F(hp) * F(108, 100)) - hp
        aptitude.append({"level": level, "base_hp": hp, "power": p,
                         "vitality_max_hp_delta": vitality, "protection_guard_firme_delta_per_cast": delta,
                         "fully_absorbed_casts_to_match_max_hp_delta": math.ceil(vitality / delta) if delta else None,
                         "continuous_required_base_guard_coefficient": float(F(8, 10) * hp / p),
                         "guard_cap": rounded(F(5, 2) * p)})
    hand = [hands_probability(3, 3), hands_probability(3, 3, True), hands_probability(6, 6)]
    require(hand[2]["probability"] > hand[1]["probability"] > hand[0]["probability"], "Redundancy improves initial function access")

    runtime = None
    runtime_files = []
    if args.runtime:
        observations_path = (ROOT / args.runtime).resolve()
        summary_path = observations_path.with_name("summary.json")
        observed = json.loads(observations_path.read_text(encoding="utf-8"))
        strict = json.loads(summary_path.read_text(encoding="utf-8"))
        require(strict["passed"] and observed["completed"] and not observed["failures"], "Strict runtime completion")
        require(not strict["diagnostics"] and not strict["process"]["timed_out"], "No runtime diagnostic or timeout")
        expected_keys = set(itertools.product((c["id"] for c in catalog["cards"]), (1, 6, 12), ELEMENTS, (False, True)))
        actual_keys = [(r["id"], r["level"], r["element"], r["upgraded"]) for r in observed["numerical"]]
        require(len(actual_keys) == len(set(actual_keys)) == 1728 and set(actual_keys) == expected_keys, "Complete unique Godot numerical matrix")
        definitions = {c["id"]: c for c in catalog["cards"]}
        for row in observed["numerical"]:
            card = dict(definitions[row["id"]])
            if row["upgraded"]:
                card.update(card["upgrade"])
            budget = 4 + 2 * (row["level"] - 1)
            raw = F(str(card["damage"])) * power[row["level"]-1] * factor(card["elements"].get("damage", {}), {row["element"]: budget})
            require(math.isclose(float(raw), row["raw"], abs_tol=1e-5), "Godot/Python raw impact mismatch")
            require(rounded(raw * F(4, 5)) == row["damage_r20"], "Godot/Python final defense mismatch")
        trials = []
        for trial in observed["trials"]:
            require(trial["casts"] and not any(c["failed"] for c in trial["casts"]), "Actual player casts completed")
            trials.append({"class": trial["class"], "allocation": trial["allocation"], "depth": trial["depth"],
                           "outcome": trial["outcome"], "combat_end_hp": trial["combat_end_hp"],
                           "start": trial["start"], "end": trial["end"],
                           "casts": len(trial["casts"]), "enemy_casts": len(trial["enemy_casts"])})
        runtime = {"observations": observations_path.relative_to(ROOT).as_posix(), "numerical_cases": 1728,
                   "mismatches": 0, "trials": trials}
        runtime_files = [observations_path, summary_path]

    files = [catalog_path, progression_path, HERE / "candidats.json", Path(__file__), *runtime_files,
             *[ROOT / "core/expedition" / name for name in ("consumable_progression_profile.gd", "consumable_card_math.gd", "consumable_card_effects.gd", "consumable_card_turns.gd", "consumable_card_economy.gd")]]
    result = {"scope": "exact_allocation_and_analytic_fixtures_not_combat_or_winrate", "passed": True,
              "timestamp_utc": datetime.now(timezone.utc).isoformat(),
              "head": subprocess.check_output(["git", "-c", "safe.directory=" + ROOT.as_posix(), "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "sha256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
              "checks": checks, "allocations_per_portfolio": len(matrix), "portfolio_count": len(portfolios),
              "optimization": optimization, "coverage": coverage, "normal_loot": loot,
              "point_visibility": visibility, "suture_pareto": pareto,
              "burn_forms": burn, "guard_forms": guard, "trait_forms": trait,
              "rejected_equal_total_burn": rejected,
              "aptitude_comparison": aptitude, "hand_access": hand}
    result["runtime_crosscheck"] = runtime
    (output / "resultats.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    with (output / "couverture.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(coverage[0]))
        writer.writeheader()
        writer.writerows(coverage)
    print(json.dumps({"passed": True, "checks": checks, "allocations_per_portfolio": len(matrix),
                      "portfolio_count": len(portfolios), "report": str(output / "resultats.json"),
                      "optimization": optimization, "aptitude_level6": aptitude[5],
                      "burn": burn[:6], "trait": trait}, ensure_ascii=False))


if __name__ == "__main__":
    main()
