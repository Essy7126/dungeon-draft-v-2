"""Analyse de conception uniquement ; ne modifie ni ne simule le moteur Godot."""
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CATALOG = ROOT / "data/cards/consumable_v2/catalog.json"
data = json.loads(CATALOG.read_text(encoding="utf-8"))
cards = data["cards"]
rules = data["rules"]


def rounded(value):
    return max(0, math.floor(value + 0.5))


def native_probability(rarity, class_id):
    pool = [c for c in cards if c["rarity"] == rarity]
    preferred = [c for c in pool if c["affinity"] in (class_id, "shared")]
    foreign = [c for c in pool if c not in preferred]
    if not preferred:
        return 0.0
    preferred_probability = 0.7 if foreign else 1.0
    return preferred_probability * sum(c["affinity"] == class_id for c in preferred) / len(preferred)


results = {
    "status": "Proposition non implementee ; arithmetique, pas equilibrage valide",
    "observed_head": "5b3553c07472180d4af08ce4ebdd5ed42362766f",
    "catalog_sha256": hashlib.sha256(CATALOG.read_bytes()).hexdigest(),
    "source_sha256": {
        str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in [ROOT / "core/expedition/consumable_card_math.gd", ROOT / "core/expedition/consumable_card_economy.gd"]
    },
    "loot_assumptions": "Tirages independants par canal/copie ; un ennemi eligible, aucun abandon de butin ; boss final exclu.",
    "classes": {},
}
checks = 0
for cls in data["classes"]:
    cid = cls["id"]
    normal_pool = [c for c in cards if c["rarity"] == "normal"]
    counts = {
        "native": sum(c["affinity"] == cid for c in normal_pool),
        "shared": sum(c["affinity"] == "shared" for c in normal_pool),
        "foreign": sum(c["affinity"] not in (cid, "shared") for c in normal_pool),
    }
    assert counts == {"native": 4, "shared": 8, "foreign": 12}
    checks += 1
    stages = []
    for rates in rules["loot"]["rates"]:
        copies = native = 0.0
        no_native = 1.0
        for rate, size, rarity in zip(rates, rules["loot"]["sizes"], rules["loot"]["tiers"]):
            probability = native_probability(rarity, cid)
            copies += rate * size
            native += rate * size * probability
            no_native *= 1 - rate + rate * (1 - probability) ** size
        stages.append({"expected_copies": copies, "expected_native_copies": native, "probability_no_native": no_native})
    p = native_probability("normal", cid)
    assert math.isclose(p, 7 / 30)
    assert math.isclose(stages[0]["expected_copies"], 3.105)
    assert math.isclose(stages[0]["expected_native_copies"], .7735)
    checks += 3
    results["classes"][cid] = {
        "normal_counts": counts, "normal_native_probability": p,
        "normal_shared_probability": .7 * counts["shared"] / (counts["shared"] + counts["native"]),
        "normal_foreign_probability": .3,
        "stages": stages,
        "first_stage_one_enemy_after_guaranteed_native_replacement": stages[0]["expected_native_copies"] + 1 - p,
    }

# Un remplacement porte sur une copie normale identifiee avant de voir son tirage,
# une fois par victoire, pas une fois par monstre. S'il etait natif, il reste natif.
# Modele du choix systematique ; conserver le tirage original reste une option.
results["replacement_assumptions"] = "Une copie normale predesignee devient une normale native choisie ; nombre et rarete inchanges. Calcul pour un ennemi ; ne pas multiplier le gain par le nombre de monstres."
results["normal_four_copy_batch"] = {
    "current_probability_no_native": (1 - 7 / 30) ** 4,
    "alternative_50_percent_probability_no_native": .5 ** 4,
    "note": "Lot fixe de 4 copies : distinct du nombre aleatoire de copies par ennemi.",
}

p = rules["prowess"][4]
by_id = {c["id"]: c for c in cards}
results["level_5_no_equipment_no_resistance_no_passive"] = {
    "P": p,
    "fallback_current": rounded(p * rules["fallbackDamage"]),
    "estoc_Force0": rounded(p * by_id["n01"]["damage"]),
    "estoc_Force4": rounded(p * by_id["n01"]["damage"] * 1.2),
    "trait_court_Finesse0": rounded(p * by_id["n05"]["damage"]),
    "trait_court_Finesse4": rounded(p * by_id["n05"]["damage"] * 1.2),
    "garde_ferme_Tenacite0": rounded(p * by_id["g01"]["amount"]),
    "garde_ferme_Tenacite4": rounded(p * by_id["g01"]["amount"] * 1.2),
    "braise_impact_Esprit0": rounded(p * by_id["t02"]["damage"]),
    "braise_impact_Esprit4": rounded(p * by_id["t02"]["damage"] * 1.2),
    "braise_tick_Esprit0": rounded(p * by_id["t02"]["amount"]),
    "braise_tick_Esprit4": rounded(p * by_id["t02"]["amount"] * 1.2),
}
results["basic_prototypes_P40_attributes0"] = {
    "assassin": {"impact": rounded(.22*p), "impact_isolated_with_passive": rounded((.22+.25)*p), "mark_for_next_card": rounded(.15*p)},
    "gardien": {"impact": rounded(.20*p), "guard": rounded(.20*p), "conditional_existing_retaliation": rounded(.25*p)},
    "arpenteur": {"impact": rounded(.28*p), "range": [2, 4], "anchor_cost_mp": 1},
    "thaumaturge": {"impact": rounded(.15*p), "one_tick": rounded(.08*p), "conditional_existing_passive_guard": rounded(.20*p)},
}
results["multipliers"] = {
    "base": 40,
    "native_25_percent": 40*1.25,
    "three_separate_25_percent_multipliers": 40*1.25**3,
    "three_additive_25_percent_bonuses": 40*(1+.25+.25+.25),
}
results["mobility_discrete"] = {
    "free_mp_increment_from_3_to_4_percent": (4/3 - 1)*100,
    "one_extra_cell_on_two_cell_movement_percent": 50,
}
results["budget"] = {
    "proposed_innate_attribute_points": 3,
    "existing_earned_points_at_level_12": 6,
    "proposed_per_attribute_cap": 8,
    "proposed_max_tagged_effect_bonus_percent": 40,
    "proposed_Tenacite_max_hp_bonus_percent": 24,
}
assert results["level_5_no_equipment_no_resistance_no_passive"]["garde_ferme_Tenacite4"] == 55
assert results["basic_prototypes_P40_attributes0"]["assassin"]["impact_isolated_with_passive"] == 19
checks += 2
results["arithmetic_checks"] = checks
destination = Path(__file__).with_name("CALCULS.json")
destination.write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"checks": checks, "result": str(destination), "example": results["classes"]["assassin"]["stages"][0], "effects": results["level_5_no_equipment_no_resistance_no_passive"]}, ensure_ascii=False))
