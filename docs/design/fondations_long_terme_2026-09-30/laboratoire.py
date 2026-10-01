"""Expériences de conception exactes ; aucun combat, aucune règle active changée.

python laboratoire.py --output-dir artifacts/dev/<nouveau-dossier>
Les niveaux 13+ et les scénarios d'approvisionnement sont des hypothèses.
"""
import argparse
from collections import Counter
from datetime import datetime, timezone
from fractions import Fraction as F
import hashlib
import itertools
import json
import math
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
CHECKS = 0


def require(condition, message):
    global CHECKS
    CHECKS += 1
    if not condition:
        raise ValueError(message)


def rounded(x):
    return max(0, math.floor(x + F(1, 2)))


def mastery(n):
    # Extrapolation mathématique après 26 ; le moteur actif borne le niveau à 12.
    require(isinstance(n, int) and 0 <= n <= 50, "Domaine expérimental des points")
    return F(3 * min(n, 4) + 2 * min(max(n - 4, 0), 4) + max(n - 8, 0), 100)


M = [mastery(n) for n in range(51)]


def encoded(value):
    if isinstance(value, F):
        return {"exact": str(value), "decimal": float(value)}
    if isinstance(value, dict):
        return {str(k): encoded(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [encoded(v) for v in value]
    return value


def hand_probability(n, a, b, opening=False):
    require(0 < a and 0 < b and a + b <= n, "Fonctions disjointes et stock fini")
    draw = 4 if opening else 5
    count = n - 1 if opening else n
    successes = (
        math.comb(count, draw) - math.comb(count - b, draw) if opening else
        math.comb(n, 5) - math.comb(n - a, 5) - math.comb(n - b, 5)
        + math.comb(n - a - b, 5)
    )
    # Vérification indépendante par énumération de toutes les mains physiques.
    labels = ["A"] * (a - int(opening)) + ["B"] * b + ["N"] * (n - a - b)
    enumerated = sum(
        (opening or any(labels[i] == "A" for i in hand))
        and any(labels[i] == "B" for i in hand)
        for hand in itertools.combinations(range(count), draw)
    )
    require(enumerated == successes, "Accord formule hypergéométrique/énumération")
    return {"deck": n, "providers": a, "consumers": b, "opening_provider": opening,
            "hands": math.comb(count, draw), "successes": successes,
            "probability": F(successes, math.comb(count, draw))}


def at_least(n, p, needed):
    return sum(F(math.comb(n, k)) * p**k * (1 - p)**(n - k) for k in range(needed, n + 1))


def curve_experiments(power, hp):
    rows = []
    for level in range(12, 19):
        delta = level - 12
        moderate_p = rounded(F(power[-1]) * F(26, 25)**delta)
        moderate_h = rounded(F(hp[-1]) * F(26, 25)**delta)
        # Géométrie : extrapoler le taux moyen global des onze gains de l'acte I.
        naive_p = rounded(power[-1] * (power[-1] / power[0])**(delta / 11))
        naive_h = rounded(hp[-1] * (hp[-1] / hp[0])**(delta / 11))
        budget = 26 + 2 * delta
        base_factor = 1 + M[26]
        rows.append({"level_hypothesis": level, "points": budget,
                     "fixed_level_12": {"power": power[-1], "hp": hp[-1], "points": 26},
                     "moderate_4_percent": {"power": moderate_p, "hp": moderate_h,
                         "mono_direct_gain_over_level12": F(moderate_p, power[-1]) * (1 + M[budget]) / base_factor - 1},
                     "geometric_act1_extrapolation": {"power": naive_p, "hp": naive_h,
                         "mono_direct_gain_over_level12": F(naive_p, power[-1]) * (1 + M[budget]) / base_factor - 1}})
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()
    output = (ROOT / args.output_dir).resolve()
    require(output.is_relative_to((ROOT / "artifacts/dev").resolve()), "Sorties limitées à artifacts/dev")
    require(not output.exists(), "Nouveau dossier de preuve obligatoire")
    catalog_path = ROOT / "data/cards/consumable_v2/catalog.json"
    progression_path = ROOT / "core/expedition/consumable_progression_v1.gd"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8-sig"))
    progression = progression_path.read_text(encoding="utf-8-sig")
    profile = catalog["rules"].get("prototypeProgression")
    power = profile["power"] if profile else json.loads(re.search(r"const POWER := (\[[^\]]+\])", progression)[1])
    hp = catalog["rules"]["hp"]
    require(len(power) == len(hp) == 12, "Courbes actives de douze niveaux")
    require(profile["levelCap"] == 12 if profile else "clampi(level, 1, 12)" in progression, "Extrapolations non actives")
    require((catalog["rules"]["ap"], catalog["rules"]["initialCards"], catalog["rules"]["hand"]) == (4, 15, 5), "Budgets actifs")
    require([M[i] for i in (4, 8, 13, 26)] == [F(12, 100), F(20, 100), F(25, 100), F(38, 100)], "Ancrages de maîtrise")
    for i in range(1, 50):
        require(M[i] >= M[i - 1] and M[i + 1] - M[i] <= M[i] - M[i - 1], "Croissance concave")

    allocations = []
    for budget in (26, 38, 50):
        portfolios = []
        for weight in (F(1), F(4, 5), F(13, 20), F(1, 2)):
            scores = [weight * M[a] + (1 - weight) * M[budget - a] for a in range(budget + 1)]
            best = max(scores)
            marginal = sorted([w * (M[n + 1] - M[n]) for w in (weight, 1 - weight)
                               for n in range(budget)], reverse=True)
            require(sum(marginal[:budget]) == best, "Optimum exact par deux méthodes")
            optima = [(a, budget - a) for a, score in enumerate(scores) if score == best]
            portfolios.append({"weight_first": weight, "best_bonus": best, "optimal_allocations": optima})
        allocations.append({"points": budget, "six_element_allocations": math.comb(budget + 5, 5),
                            "mono_bonus": M[budget], "mono_relative_gain_over_26": (1 + M[budget]) / (1 + M[26]) - 1,
                            "portfolios": portfolios})
    require(allocations[0]["six_element_allocations"] == 169911, "Nombre actif exact")
    require([len(x["portfolios"][-1]["optimal_allocations"]) for x in allocations] == [11, 23, 35], "Plateaux biélémentaires")

    normal = [c for c in catalog["cards"] if c["rarity"] == "normal"]
    supply = []
    for cls in catalog["classes"]:
        native = [c for c in normal if c["affinity"] in ("shared", cls["id"])]
        foreign = [c for c in normal if c not in native]
        require(len(native) == len(foreign) == 12, "Pools normaux de la version étudiée")
        def probability(card):
            return F(7, 10 * len(native)) if card in native else F(3, 10 * len(foreign))
        functional = [c for c in normal if F(str(c.get("elements", {}).get("damage", {}).get("sun", 0))) >= F(1, 2)]
        p = sum(probability(c) for c in functional)
        require(at_least(60, p, 3) == 1 - sum(F(math.comb(60, k)) * p**k * (1-p)**(60-k)
                                           for k in range(3)), "Binomiale complète et complément")
        supply.append({"class": cls["id"], "solar_direct_families": [c["id"] for c in functional],
                       "solar_direct_probability_one_normal_draw": p,
                       "hypothesis_60_normal_draws": {"expected_additional_copies": 60 * p,
                           "probability_at_least_three_new_copies": at_least(60, p, 3)},
                       "healing_normal_families": [c["id"] for c in native if c["op"] in ("heal", "renew", "drain")],
                       "periodic_normal_families": [c["id"] for c in native if c["op"] in ("burn", "bleed", "firefield")]})
    require(all(not r["healing_normal_families"] for r in supply), "Absence actuelle de soins normaux")

    gear_slots = Counter(item["slot"] for item in catalog["equipment"])
    early_slots = Counter(item["slot"] for item in catalog["equipment"] if item["stage"] == 1)
    full_loadouts = math.prod(gear_slots.values())
    relic_pairs = math.comb(len(catalog["relics"]), 2)
    # Trois points dans quatre aptitudes, rang max trois ; classe et deux spécialités.
    aptitude_allocations = math.comb(3 + 4 - 1, 4 - 1)
    prefilter_product = full_loadouts * relic_pairs * aptitude_allocations * 8 * math.comb(31, 5)
    content_count = sum(len(catalog[k]) for k in ("cards", "equipment", "relics"))
    require(content_count == 80 and full_loadouts == 2187, "Produit de catalogue courant")

    resistance = [{"resistance": F(r, 100), "effective_hp_factor": 1 / (1 - F(r, 100))}
                  for r in (0, 10, 20, 30, 40)]
    require(resistance[-1]["effective_hp_factor"] == F(5, 3), "Résistance active au plafond")
    bonus_examples = [{"current_damage_bonus": b, "relative_gain_from_10pp": F(1, 10) / (1 + b)}
                      for b in (F(0), F(38, 100), F(80, 100))]

    # Falsification : fusionner séparément maxima d'intensité et de durée crée
    # une application que ni la source A ni la source B n'a payée.
    statuses = {"A": {"amount": 17, "remaining_ticks": 1}, "B": {"amount": 5, "remaining_ticks": 3}}
    synthetic = max(x["amount"] for x in statuses.values()) * max(x["remaining_ticks"] for x in statuses.values())
    independent = sum(x["amount"] * x["remaining_ticks"] for x in statuses.values())
    require((synthetic, independent) == (51, 32), "Contre-exemple de rafraîchissement")

    # Budget isolé de six nouveaux combats, sans magasin ni variabilité des drops.
    # C'est un besoin de ravitaillement, pas une prédiction de la run actuelle.
    stock_scenarios = [{"consumable_casts_per_fight": casts, "new_fights": 6,
                        "remaining_copies_at_transition": 6, "new_usable_copies": 12,
                        "ending_stock": 18 - 6 * casts} for casts in (2, 3, 4, 5)]
    require([x["ending_stock"] for x in stock_scenarios] == [6, 0, -6, -12], "Identité de stock")

    report = {
        "status": "analytical_checks_passed_not_gameplay_validation",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "scope": "Conception : aucune campagne Monte-Carlo ou moteur exécutée par ce script.",
        "active_curves": {"power": power, "hp": hp,
                          "hp_to_power": [F(h, p) for h, p in zip(hp, power)]},
        "allocation_experiments": allocations,
        "act2_curve_hypotheses": curve_experiments(power, hp),
        "hand_experiments": [hand_probability(n, a, b, opener) for n, a, b, opener in
                             ((15, 3, 3, False), (15, 3, 3, True), (30, 3, 3, False),
                              (30, 6, 6, False), (15, 6, 6, False))],
        "supply_experiments": supply,
        "gear_distribution": {"definitions_by_slot": dict(gear_slots), "early_definitions_by_slot": dict(early_slots),
                              "early_amulet_probability_definition_uniform": F(early_slots["amulet"], sum(early_slots.values())),
                              "early_amulet_probability_slot_uniform_hypothesis": F(1, len(early_slots))},
        "state_space": {"fully_equipped_catalog_loadouts": full_loadouts, "exactly_two_distinct_relics": relic_pairs,
                        "three_points_four_aptitudes": aptitude_allocations,
                        "prefilter_product_excluding_deck_and_training": prefilter_product,
                        "warning": "Produit cartésien sans possession, accès, équivalence ni compatibilité ; pas un nombre de builds viables.",
                        "content_definitions": content_count, "unfiltered_pairs": math.comb(content_count, 2),
                        "unfiltered_triples": math.comb(content_count, 3)},
        "resistance_experiments": resistance, "damage_bonus_experiments": bonus_examples,
        "resistance_30_to40_relative_effective_hp_gain": F(7, 6) - 1,
        "status_counterexample": {"applications": statuses, "synthetic_maxima_total": synthetic,
                                  "independent_sources_total": independent,
                                  "replacement_whole_B_total": 15, "keep_whole_A_total": 17,
                                  "warning": "Scénario abstrait ; aucune nouvelle règle de cumul sélectionnée par le script."},
        "stock_identity_experiments": stock_scenarios,
        "threshold_example": {"target_hp": 80, "damage_39_hits_needed": math.ceil(80 / 39),
                              "damage_40_hits_needed": math.ceil(80 / 40),
                              "warning": "Seuil isolé, pas une mesure du catalogue ou des tours réels."},
    }
    # Empreintes : anciennes preuves moteur explicitement réutilisées, non relancées.
    old_path = ROOT / "artifacts/dev/20260930-progression-systeme-final/resultats.json"
    old = json.loads(old_path.read_text(encoding="utf-8-sig")) if old_path.exists() else {}
    require(old.get("passed") is True and old.get("sha256"), "Preuve antérieure disponible")
    old_checks = {}
    for relative, expected in old["sha256"].items():
        path = (ROOT / relative).resolve()
        require(path.is_relative_to(ROOT), "Provenance locale confinée")
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        old_checks[relative] = actual == expected
        require(actual == expected, "Preuve antérieure périmée : " + relative)
    report["prior_evidence_rechecked_not_rerun"] = {
        "report": str(old_path.relative_to(ROOT)).replace("\\", "/"),
        "sha256": hashlib.sha256(old_path.read_bytes()).hexdigest(),
        "all_input_hashes_match": old_checks,
        "warning": "La concordance des entrées conserve la portée des essais anciens ; aucun nouveau combat exécuté."
    }
    paths = [catalog_path, progression_path, Path(__file__),
             *[ROOT / ("core/expedition/" + name) for name in (
                 "consumable_progression_profile.gd", "consumable_card_math.gd", "consumable_card_effects.gd", "consumable_card_economy.gd",
                 "consumable_card_turns.gd", "consumable_cards_state.gd", "consumable_cards_checkpoint.gd",
                 "consumable_cards_integration.gd", "consumable_enemy_profile.gd")]]
    report["source_sha256"] = {str(path.relative_to(ROOT)).replace("\\", "/"): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
    report["head"] = subprocess.check_output(["git", "-c", f"safe.directory={ROOT.as_posix()}", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    report["checks"] = CHECKS
    output.mkdir(parents=True)
    (output / "resultats.json").write_text(json.dumps(encoded(report), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": report["status"], "checks": CHECKS, "output": str(output),
                      "hand_cases": len(report["hand_experiments"]), "curve_cases": len(report["act2_curve_hypotheses"])}, ensure_ascii=False))


if __name__ == "__main__":
    main()
