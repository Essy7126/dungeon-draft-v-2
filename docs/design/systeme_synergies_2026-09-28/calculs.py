"""Expériences de conception, sans exécution du moteur Godot.

python docs/design/systeme_synergies_2026-09-28/calculs.py
Réécrit CALCULS.json et CATALOGUE.md dans ce dossier.
"""

from collections import Counter
from hashlib import sha256
from itertools import combinations
from math import comb, floor
from pathlib import Path
import json
import sys

sys.stdout.reconfigure(encoding="utf-8")
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
CATALOG = ROOT / "data/cards/consumable_v2/catalog.json"
raw = CATALOG.read_bytes()
catalog = json.loads(raw)
cards = {card["id"]: card for card in catalog["cards"]}

# INTERPRÉTATIONS DE DESIGN : ces domaines n'existent pas dans le catalogue.
# Une double étiquette désigne une piste de famille, pas un ratio de dégâts.
PROPOSALS = {
    "n01": ("Commun", "Impact simple ; repère neutre"),
    "n02": ("Commun", "Protection simple ; repère neutre"),
    "n03": ("Commun", "Déplacement volontaire ; reste sans élément"),
    "n04": ("Terre", "Poussée courte ; préparer une position"),
    "n05": ("Commun", "Impact distant simple"),
    "n06": ("Nuit", "Préparer une marque, alternative à a01/t03"),
    "n07": ("Eau", "Ralentissement ; attribution thématique à confirmer"),
    "n08": ("Commun", "Accès à la main ; ne doit pas donner de dégâts élémentaires"),
    "a01": ("Nuit", "Préparer une marque"),
    "a02": ("Nuit", "Exploiter une marque ; gros impact direct"),
    "a03": ("Nuit", "Blessure différée ; autre axe que les marques"),
    "a04": ("Nuit/Vent", "Exploiter un déplacement volontaire"),
    "g01": ("Terre", "Préparer de la garde"),
    "g02": ("Terre", "Exploiter la présence de garde"),
    "g03": ("Terre/Vent", "Poussée longue ; attribution double à confirmer"),
    "g04": ("Terre", "Ramener une cible au front"),
    "r01": ("Vent", "Déplacement puis tir et renouvellement de main"),
    "r02": ("Vent", "Poussée distante"),
    "r03": ("Eau/Vent", "Ralentissement distant ; pas encore de transformation hybride"),
    "r04": ("Vent", "Zone distante ; ne possède pas encore de rôle élémentaire distinct"),
    "t01": ("Eau", "Ralentissement et gel de l'eau"),
    "t02": ("Feu", "Brûlure ; vapeur déjà existante sur l'eau"),
    "t03": ("Nuit", "Préparer une marque magique"),
    "t04": ("Eau/Nuit", "Eau existante ; transport de marque proposé, absent du moteur"),
    "a05": ("Nuit/Vent", "Téléportation ; domaine Nuit encore à justifier"),
    "a06": ("Nuit", "Exécuter une cible blessée"),
    "a07": ("Soleil?", "Ignore l'armure ; piste de révélation, aucun système solaire"),
    "g05": ("Terre", "Garde et contre conditionnel"),
    "g06": ("Terre/Vent", "Poussée ; arrêt contre mur fixe donne de la garde, pas des dégâts"),
    "g07": ("Terre/Nuit", "Exploiter la garde absorbée au tour précédent"),
    "r05": ("Vent", "Téléportation longue"),
    "r06": ("Vent", "Zone en ligne ; aucun rôle élémentaire distinct actuellement"),
    "r07": ("Eau/Vent", "Attraction ; aide à faire traverser une surface"),
    "t05": ("Feu/Nuit", "Zone de feu persistante ; domaine Nuit non prouvé par le nom"),
    "t06": ("Eau/Terre", "Zone de glace ; domaine Terre hypothétique"),
    "t07": ("Eau/Nuit", "Drain fondé sur les PV réellement retirés"),
    "a08": ("Nuit/Vent", "Affaiblir la prochaine attaque ; double domaine hypothétique"),
    "a09": ("Nuit", "Dépenser une marque pour neutraliser une activation"),
    "g08": ("Terre", "Forte garde ; pas une condition d'accès au build"),
    "g09": ("Terre", "Sacrifier de la garde pour un impact"),
    "r08": ("Vent", "Permutation ; immunité des boss conservée"),
    "r09": ("Soleil?", "Longue portée ; thème solaire insuffisant en soi"),
    "t08": ("Eau/Vent", "Attraction puis impact de zone"),
    "t09": ("Nuit", "Exploiter une marque avec des dégâts magiques"),
    "l01": ("Vent", "Zone magique ; nom Orage insuffisant pour inventer un type"),
    "l02": ("Terre/Soleil?", "Soin et garde ; piste solaire seulement"),
    "d01": ("Nuit/Soleil?", "Prévenir une mort ; ne peut fonder un build accessible"),
    "i01": ("Eau/Soleil?", "Soin et garde ; contenu exceptionnel, pas moteur de synergie"),
}
assert set(PROPOSALS) == set(cards), "Le catalogue a changé : réexaminer les 48 cartes."


def rounded(value):
    return max(0, floor(value + 0.5))


def opening_probability(producers, consumers, forced_producer=False):
    """Rôles disjoints ; vérification par énumération des mains physiques."""
    if forced_producer:
        pool, hand = 14, 4
        # Une copie productrice est déjà sélectionnée, les consommateurs restent.
        exact = 1 - comb(pool - consumers, hand) / comb(pool, hand)
        enumerated = sum(
            any(i < consumers for i in draw)
            for draw in combinations(range(pool), hand)
        ) / comb(pool, hand)
    else:
        pool, hand = 15, 5
        safe_comb = lambda n: comb(n, hand) if n >= hand else 0
        exact = 1 - safe_comb(pool - producers) / comb(pool, hand)
        exact -= safe_comb(pool - consumers) / comb(pool, hand)
        exact += safe_comb(pool - producers - consumers) / comb(pool, hand)
        enumerated = sum(
            any(i < producers for i in draw)
            and any(producers <= i < producers + consumers for i in draw)
            for draw in combinations(range(pool), hand)
        ) / comb(pool, hand)
    assert abs(exact - enumerated) < 1e-12
    return {"probability": exact, "percent": round(100 * exact, 4),
            "enumerated_hands": comb(pool, hand)}


linear = [{"water": water, "night": 6 - water,
           "damage_80_20": 40 * (1 + .08 * (.8 * water + .2 * (6 - water)))}
          for water in range(7)]
dual_lines = [8 * (1 + water / 100) + 8 * (1 + (200 - water) / 100)
              for water in range(201)]
assert all(abs(damage - 32) < 1e-10 for damage in dual_lines)

power = 40
braise = cards["t02"]
wave = cards["t04"]
mark = cards["a01"]
finisher = cards["a02"]

experiments = []
for per_rank in (.04, .08):
    mono, hybrid = 1 + 6 * per_rank, 1 + 3 * per_rank
    # Valeurs de brûlure actuelles ; seules les maîtrises et l'ébullition sont proposées.
    mono_hit = rounded(power * braise["damage"] * mono)
    hybrid_hit = rounded(power * braise["damage"] * hybrid)
    mono_tick = rounded(power * braise["amount"] * mono)
    hybrid_tick = rounded(power * braise["amount"] * hybrid)
    splash = rounded(power * .30 * hybrid)
    wave_mono = rounded(power * wave["damage"])
    wave_hybrid = rounded(power * wave["damage"] * hybrid)
    # Scénario favorable : trois ennemis distincts dans la croix, tous survivent à l'onde,
    # deux sont adjacents au destinataire de Braise. Aucune résistance, aucun passif.
    setup_comparison = {
        "ap": wave["ap"] + braise["ap"], "copies": 2, "minimum_turns": 2,
        "mono_fire_wave_then_braise_three_targets": 3 * wave_mono + mono_hit + 2 * mono_tick,
        "hybrid_wave_then_ebullition_three_targets": 3 * wave_hybrid + hybrid_hit + 2 * splash,
    }
    # Comparaison distincte, depuis un état après la préparation : A a 6 PV et une marque,
    # B est hors onde. Un impact futur indépendant vaut 20, sans nouvelle maîtrise.
    stored_mark = power * mark["amount"] * hybrid
    current_state_plain = 6 + 20
    current_state_transfer = 6 + rounded(20 + stored_mark)
    experiments.append({
        "bonus_per_rank": per_rank, "P": power,
        "mono_6_fire": {"impact": mono_hit, "burn_tick": mono_tick,
                        "total_two_ticks": mono_hit + 2 * mono_tick,
                        "compression_one_tick_proposal": rounded(power * .32 * mono)},
        "hybrid_3_fire_3_water": {
            "normal_impact": hybrid_hit, "normal_burn_tick": hybrid_tick,
            "normal_total_two_ticks": hybrid_hit + 2 * hybrid_tick,
            "ebullition_by_extra_targets": [hybrid_hit + n * splash for n in range(3)],
            "splash_per_extra_target": splash,
        },
        "wave_setup_three_targets": setup_comparison,
        "night_marked_finisher": {
            "mono_night_6": rounded(power * (finisher["damage"] + finisher["bonus"]) * mono
                                    + power * mark["amount"] * mono),
            "hybrid_night_3_water_3": rounded(power * (finisher["damage"] + finisher["bonus"]) * hybrid
                                             + stored_mark),
        },
        "transfer_from_fixed_state": {
            "normal_useful_hp_damage": current_state_plain,
            "successful_transfer_useful_hp_damage": current_state_transfer,
            "failed_transfer_useful_hp_damage": current_state_plain,
            "stored_mark_unrounded": stored_mark,
            "expected_by_crossing_probability": [
                {"q": q, "useful_damage": current_state_plain
                 + q * (current_state_transfer - current_state_plain)}
                for q in (0, .25, .5, .75, 1)],
            "scope": "état fixé après préparation, pas coût complet d'une rotation",
        },
        "earth_fire_sacrificial_eruption_proposal": {
            "setup_guard_card_ap": cards["g01"]["ap"],
            "attack_card_ap": cards["g02"]["ap"],
            "hybrid_guard_generated": rounded(power * cards["g01"]["amount"] * hybrid),
            "guard_spent": rounded(power * .5 * hybrid),
            "hybrid_direct_hit": rounded(power * .6 * hybrid),
            "explosion_per_target": rounded(1.5 * rounded(power * .5 * hybrid)),
            "total_for_zero_one_two_explosion_targets": [
                rounded(power * .6 * hybrid) + n * rounded(1.5 * rounded(power * .5 * hybrid))
                for n in range(3)],
            "hybrid_normal_g02_with_guard": rounded(power * 1.5 * hybrid),
            "mono_earth_normal_g02_with_guard": rounded(power * 1.5 * mono),
            "scope": "aucune mitigation ; S points de garde réellement sacrifiés, explosion différée, peut toucher le héros",
        },
    })

domains = Counter()
normal_domains = Counter()
rows = []
for card_id, card in cards.items():
    proposal, role = PROPOSALS[card_id]
    for domain in proposal.split("/"):
        domains[domain] += 1
        if card["rarity"] == "normal":
            normal_domains[domain] += 1
    rows.append(f"| {card_id} | {card['name']} | {card['rarity']} | {card['ap']} | {proposal} | {role} |")

fingerprints = {}
for relative in (
    "data/cards/consumable_v2/catalog.json",
    "docs/current/cards_v2.md",
    "core/expedition/consumable_card_math.gd",
    "core/expedition/consumable_card_modifier.gd",
    "core/expedition/consumable_card_terrain.gd",
):
    fingerprints[relative] = sha256((ROOT / relative).read_bytes()).hexdigest()

results = {
    "status": "calculs de conception, aucune simulation Godot ni mesure de taux de victoire",
    "catalog_sha256": sha256(raw).hexdigest(), "source_sha256": fingerprints,
    "cards_examined": len(cards), "normal_cards": sum(c["rarity"] == "normal" for c in cards.values()),
    "assumptions": {
        "opening": "15 copies, 5 piochées, sans équipement, rôles disjoints ; accès aux fonctions seulement",
        "damage": "P40, pas de résistance/garde/passif/équipement, arrondi final floor(x+.5) par impact",
        "mastery": "paramètres fictifs 4% et 8% ; ni progression ni équilibrage approuvés",
        "labels": "domaines proposés ; aucun champ élémentaire existant dans le catalogue",
    },
    "linear_80_20_fixed_budget_6": linear,
    "two_lines_8_8_fixed_budget_200": {"allocations": len(dual_lines),
                                          "min": min(dual_lines), "max": max(dual_lines)},
    "opening_probabilities": {
        "one_copy_each": opening_probability(1, 1),
        "three_copies_each": opening_probability(3, 3),
        "forced_producer_three_consumer_copies": opening_probability(3, 3, True),
        "six_producers_six_consumers": opening_probability(6, 6),
    },
    "combat_examples": experiments,
    "bg3_conditional_hits_level_1_to_4": {
        "two_rays_two_actions": 2 * 4.5,
        "create_water_then_ray_two_actions_one_slot": 2 * 4.5,
        "three_rays_three_actions": 3 * 4.5,
        "create_water_then_two_rays_three_actions_one_slot": 2 * 2 * 4.5,
    },
    "dos2_simplified_dual_armor": {
        "target_hp": 100, "physical_armor": 40, "magic_armor": 40,
        "40_physical_plus_40_magic_hp_loss": 0,
        "80_physical_hp_loss": 40,
    },
    "proposal_label_counts_overlapping": dict(domains),
    "proposal_normal_label_counts_overlapping": dict(normal_domains),
    "possible_unordered_pairs": {"five_domains": comb(5, 2), "six_domains": comb(6, 2)},
    "loot_normal_existing": {
        "native": .7 * 4 / 12, "shared": .7 * 8 / 12, "foreign": .3,
        "one_specific_foreign_family_per_normal_copy": .3 / 12,
    },
}
(HERE / "CALCULS.json").write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
audit = """# Audit des 48 sorts — pistes d'affinités, pas données du jeu

Généré par `calculs.py` à partir du catalogue réel et d'une table d'interprétation explicite.
Une double étiquette n'implique ni dégâts partagés, ni réaction déjà codée. Les points
d'interrogation signalent un domaine particulièrement peu étayé. Ces rapprochements
thématiques doivent encore produire des choix de combat avant de devenir du contenu.

| ID | Sort actuel | Rareté | PA | Domaines candidats | Fonction et limite |
|---|---|---|---:|---|---|
""" + "\n".join(rows)
audit += "\n\n## Couverture indicative\n\n| Domaine proposé | Tous rangs | Normaux |\n|---|---:|---:|\n"
for domain, count in domains.items():
    audit += f"| {domain} | {count} | {normal_domains[domain]} |\n"
audit += """
Les comptes se recouvrent : un sort proposé Eau/Nuit apparaît dans deux lignes.
Ils ne prouvent pas qu'une branche possède un moteur complet. Le Feu n'a que Braise
tenace en normal et Bûcher des ombres en élite. Aucun normal ne fournit actuellement
une identité Soleil étayée. Certaines attributions Vent/Terre sont également de
simples hypothèses. Ajouter six statistiques immédiatement produirait des branches
très inégales ; il faut concevoir et distribuer les fonctions manquantes.

La marque a déjà trois préparateurs normaux (n06/a01/t03), mais les consommateurs
spécialisés ne sont pas uniformément accessibles au départ. L'eau dynamique dépend
de t04 en normal ; ralentir avec n07/r03 ne crée pas une flaque. Ne pas compter ces
trois sorts comme trois producteurs d'eau. t04 n'est actuellement proposé au départ
qu'au Thaumaturge. Une lignée hybride interclasse doit modifier l'accès de départ,
pas seulement espérer un butin étranger.
"""
(HERE / "CATALOGUE.md").write_text(audit, encoding="utf-8")
print(json.dumps({"cards_examined": len(cards), "opening": results["opening_probabilities"],
                  "experiments": experiments, "outputs": ["CALCULS.json", "CATALOGUE.md"]},
                 ensure_ascii=False, indent=2))
