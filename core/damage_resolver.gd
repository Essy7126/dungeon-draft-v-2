# core/damage_resolver.gd
# ============================================================
# DAMAGE RESOLVER — Le calcul central des dégâts. Logique pure.
#
# TOUT dégât du jeu passe par compute(). C'est la seule loi physique
# du combat : armure, résistances, esquive, crit, plancher. Une fois
# figée, on n'y touche plus — on l'étend par des crochets (pénétration,
# crit conditionnel) qui restent neutres tant qu'aucun trait ne les pousse.
#
# Réutilise les enums de Spell (DamageType, Element) : un seul vocabulaire
# de types dans tout le projet, pas de doublon.
#
# Modèle de mitigation : LoL (rendement décroissant, constante 100).
#   100 armure → 50% | 200 → 66% | 300 → 75%. Jamais 100%.
# ============================================================

class_name DamageResolver
extends RefCounted

# Constante de la courbe de mitigation. 100 = standard LoL.
const MITIGATION_K := 100.0

# ============================================================
# RÉSULTAT D'UN CALCUL DE DÉGÂTS
# Renvoyé par compute(). Porte le montant final ET les drapeaux,
# pour que battle.gd affiche les retours visuels (crit, esquive)
# et que le futur EventBus émette critical_hit / attack_dodged.
# ============================================================

class DamageResult:
	var amount: int = 0          # dégâts finaux (après tout)
	var raw: int = 0             # dégâts bruts d'entrée (avant mitigation)
	var dodged: bool = false     # l'attaque a été esquivée (amount = 0)
	var is_crit: bool = false    # un critique s'est produit
	var category: int = 0        # Spell.DamageType utilisé
	var element: int = 0         # Spell.Element utilisé

	func _init(p_raw: int = 0) -> void:
		raw = p_raw
		amount = p_raw

# ============================================================
# CONTEXTE D'UN COUP
# Tout ce qui décrit une frappe. Rempli par l'appelant (sort,
# attaque de base, terrain). Des valeurs par défaut neutres
# permettent au terrain (attacker = null) de passer sans souci.
# ============================================================

class HitContext:
	var attacker = null                       # Unit ou null (terrain)
	var raw_damage: int = 0                    # dégâts avant mitigation
	var category: int = Spell.DamageType.PHYSICAL
	var element: int = Spell.Element.NONE

	# Crochets de crit (poussés par les futurs traits ; neutres ici).
	var bonus_crit_chance: float = 0.0         # +proba de crit ponctuelle
	var force_crit: bool = false               # force le critique

	# Crochets de pénétration (poussés par l'équipement plus tard ; neutres).
	var pen_pct: float = 0.0                   # % d'armure/résist ignoré
	var pen_flat: float = 0.0                  # points d'armure/résist ignorés

	# Drapeaux d'exception.
	var ignore_defense: bool = false           # ignore armure ET résist (dégâts vrais)
	var cannot_be_dodged: bool = false         # l'esquive ne s'applique pas

	# Coefficient d'efficacité des dégâts (anti-erreur Dofus). Neutre = 1.0.
	# Détermine quelle PROPORTION des bonus de dégâts PLATS futurs s'applique.
	# Un sort lourd (1 gros coup) = 1.0 ; un poison/multi-hit = ex. 0.2, pour
	# qu'un "+10 dégâts" ne soit pas appliqué en entier sur chaque tic et ne
	# rende pas les builds à fréquence mathématiquement invincibles.
	# Posé maintenant comme crochet ; reste neutre tant qu'aucun bonus plat
	# global n'existe. Le jour où tu ajoutes ces bonus, tu les multiplies
	# par ce coefficient — l'équité est garantie par construction.
	var damage_effectiveness: float = 1.0

# ============================================================
# CALCUL PRINCIPAL
# Ordre : esquive → résistance d'élément → mitigation de catégorie
#         → crit → plancher (min 1).
# ============================================================

static func compute(defender, ctx: HitContext) -> DamageResult:
	var result := DamageResult.new(ctx.raw_damage)
	result.category = ctx.category
	result.element = ctx.element

	# Rien à faire si pas de dégâts bruts.
	if ctx.raw_damage <= 0:
		result.amount = 0
		return result

	# --- 1. ESQUIVE ---
	if not ctx.cannot_be_dodged:
		var dodge_chance := _get_dodge(defender)
		if dodge_chance > 0.0 and randf() < dodge_chance:
			result.dodged = true
			result.amount = 0
			return result

	var dmg := float(ctx.raw_damage)

	# --- 2. RÉSISTANCE D'ÉLÉMENT (%) ---
	# Résistance par sous-type (feu, glace...). Peut être négative
	# (vulnérabilité → dégâts augmentés). Ignorée si dégâts vrais.
	if not ctx.ignore_defense:
		var elem_resist := _get_element_resist(defender, ctx.element)
		dmg *= (1.0 - elem_resist)

	# --- 3. MITIGATION DE CATÉGORIE (formule LoL) ---
	# Armure pour le physique, résist magique pour le magique.
	# La pénétration s'applique ICI (neutre tant que pen = 0).
	if not ctx.ignore_defense:
		var defense := _get_category_defense(defender, ctx.category)
		defense = _apply_penetration(defense, ctx.pen_pct, ctx.pen_flat)
		var mitig := mitigation(defense)
		dmg *= (1.0 - mitig)

	# --- 4. CRITIQUE ---
	# Chance = crit de l'unité attaquante + bonus ponctuel (traits).
	# force_crit court-circuite le jet. Le multiplicateur vient de l'attaquant.
	var crit_chance := ctx.bonus_crit_chance
	var crit_multi := 1.5
	if ctx.attacker != null:
		crit_chance += _get_crit_chance(ctx.attacker)
		crit_multi = _get_crit_multi(ctx.attacker)
	if ctx.force_crit or (crit_chance > 0.0 and randf() < crit_chance):
		result.is_crit = true
		dmg *= crit_multi

	# --- 5. PLANCHER ---
	# Un coup qui touche fait toujours au moins 1 (sauf esquive totale).
	result.amount = max(1, int(round(dmg)))
	return result

# ============================================================
# LA FORMULE DE MITIGATION (rendement décroissant)
# Publique : réutilisable par l'UI pour afficher "X% de réduction".
# ============================================================

static func mitigation(defense: float) -> float:
	if defense >= 0.0:
		return defense / (defense + MITIGATION_K)
	# Défense négative = vulnérabilité, bornée et symétrique.
	return defense / (MITIGATION_K - defense)

static func _apply_penetration(defense: float, pen_pct: float, pen_flat: float) -> float:
	# % d'abord, plat ensuite (ordre LoL). Neutre tant que pen = 0.
	return max(0.0, defense * (1.0 - pen_pct) - pen_flat)

# ============================================================
# LECTURE DES STATS DÉFENSIVES
# Tolérant : si l'unité n'a pas encore une stat (ancien code),
# renvoie une valeur neutre au lieu de planter.
# ============================================================

static func _get_category_defense(defender, category: int) -> float:
	if category == Spell.DamageType.MAGICAL:
		if defender.resist_magique != null:
			return defender.resist_magique.get_value()
		return 0.0
	# PHYSICAL par défaut.
	if defender.armure != null:
		return defender.armure.get_value()
	return 0.0

static func _get_element_resist(defender, element: int) -> float:
	# NONE = pas de sous-type, aucune résistance élémentaire.
	if element == Spell.Element.NONE:
		return 0.0
	# Les résistances sont désormais des Stat (lues via le helper de l'unité).
	# get_resistance_value renvoie 0.0 si l'élément n'est pas géré, sans rien créer.
	if defender.has_method("get_resistance_value"):
		return defender.get_resistance_value(element)
	return 0.0

static func _get_dodge(defender) -> float:
	if defender.esquive != null:
		return defender.esquive.get_value()
	return 0.0

static func _get_crit_chance(attacker) -> float:
	if attacker.crit_chance != null:
		return attacker.crit_chance.get_value()
	return 0.0

static func _get_crit_multi(attacker) -> float:
	if attacker.crit_multi != null:
		return attacker.crit_multi.get_value()
	return 1.5
