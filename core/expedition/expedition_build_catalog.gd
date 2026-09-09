class_name ExpeditionBuildCatalog
extends RefCounted

## Stable IDs are the persistence contract. Every advertised technique is a real
## Spell consumed by the existing SpellCaster; no separate simulation is used.
const BASE_PATHS := [
	"res://data/spells/achilles/peleid_strike.tres",
	"res://data/spells/achilles/fulminant_dash.tres",
	"res://data/spells/achilles/pelion_shot.tres",
	"res://data/spells/achilles/bronze_guard.tres",
]
const AXES := {
	"briseur": {"title": "Colère · Briseur", "description": "Rapprocher, regrouper, frapper. Le contact est votre ressource."},
	"sang": {"title": "Colère · Sang héroïque", "description": "Engager vos PV pour une fenêtre de puissance ; récupérer reste limité."},
	"chasseur": {"title": "Chiron · Chasseur", "description": "Ouvrir une ligne, marquer une proie, rentabiliser sa distance."},
	"danseur": {"title": "Chiron · Danseur", "description": "Changer d'appui et d'angle ; l'esquive demeure une probabilité."},
	"airain": {"title": "Éaque · Airain", "description": "Tenir le front et écarter ses menaces ; la posture coûte de la mobilité."},
	"endurance": {"title": "Éaque · Endurance", "description": "Consacrer des actions à survivre, avec une réserve de soin finie."},
	"elements": {"title": "Affinités · Feu, givre, foudre", "description": "Poser un danger, ralentir une route, exploiter les alignements."},
	"serment": {"title": "Serments du Styx", "description": "Une découverte de sanctuaire : engager ses PV pour une protection ou une offensive exclusive."},
}
const DOCTRINES := {
	"colere": {"title": "Colère du Péléide", "description": "Ouvrir la garde adverse, puis choisir le contrôle du contact ou le prix du sang.", "axes": ["briseur", "sang"], "root": "colere.root"},
	"chiron": {"title": "Leçon de Chiron", "description": "Exploiter les lignes de tir, puis choisir la chasse ou la mobilité.", "axes": ["chasseur", "danseur"], "root": "chiron.root"},
	"eaque": {"title": "Égide d'Éaque", "description": "Renforcer sa garde, puis choisir l'armure ou une réserve de vitalité.", "axes": ["airain", "endurance"], "root": "eaque.root"},
}
const DISCOVERY_DEPTHS := {"elements": 4, "serment": 8}
## Semantic combat classifications are explicit, independent of artwork/name.
const ACTION_IDS := {
	CombatActionClassificationData.Classification.MELEE: ["exp_crochet", "exp_entaille", "exp_moisson", "exp_contretemps", "exp_heurt", "exp_crochet_mutation", "exp_crochet_legend", "exp_entaille_mutation", "exp_entaille_legend", "exp_contretemps_signature", "exp_heurt_mutation"],
	CombatActionClassificationData.Classification.PROJECTILE: ["exp_rupture", "exp_marque", "exp_braise", "exp_givre", "exp_marque_signature", "exp_givre_signature"],
	CombatActionClassificationData.Classification.AREA: ["exp_fauchage", "exp_foudre", "exp_fauchage_signature", "exp_moisson_signature", "exp_rupture_mutation", "exp_rupture_legend", "exp_heurt_legend", "exp_braise_mutation", "exp_braise_legend", "exp_tempest"],
	CombatActionClassificationData.Classification.SELF: ["exp_posture", "exp_souffle", "exp_posture_signature", "exp_souffle_mutation", "exp_souffle_legend"],
	CombatActionClassificationData.Classification.MOVEMENT: ["exp_feinte", "exp_marche", "exp_feinte_mutation", "exp_feinte_legend", "exp_marche_signature"],
}

## Authored presentation delay: Battle owns release, flight and impact ordering.
## Includes ranged AREA forms; their gameplay classification stays unchanged.
const PROJECTILE_FLIGHT_IDS := [
	"exp_tir_de_guet", "exp_rupture", "exp_marque", "exp_marque_signature",
	"exp_rupture_mutation", "exp_rupture_legend",
	"exp_braise", "exp_braise_mutation", "exp_braise_legend",
	"exp_givre", "exp_givre_signature", "exp_foudre",
]

var spells: Dictionary = {}
var nodes: Array[Dictionary] = []
var _families: Dictionary = {}
var _card_ids: Dictionary = {}


func _init() -> void:
	for path in BASE_PATHS:
		var spell := load(path) as Spell
		if spell != null:
			_register(spell, String(spell.spell_id))
	_create_martial_spells()
	_create_elemental_spells()
	_create_doctrine_roots()
	_create_nodes()
	_create_serments()
	var tempest := _copy("achilles_peleid_strike", "tempest", "Tempête du Péléide",
		"4 PA · Autour de soi, croix de 1 case · 70 % Prouesse physique à chaque ennemi adjacent. Une utilisation par activation. Forme exclusive de Frappe.")
	_self_area(tempest)
	tempest.ap_cost = 4
	tempest.damage_scaling = _scaling(0.70)
	for projectile_id: String in PROJECTILE_FLIGHT_IDS:
		var projectile := get_spell(projectile_id)
		if projectile != null:
			projectile.impact_delay_seconds = 0.2
	_apply_painted_icons()


func axes() -> Dictionary:
	return AXES.duplicate(true)


func doctrines() -> Dictionary:
	return DOCTRINES.duplicate(true)


func doctrine_for_axis(axis: String) -> String:
	for id in DOCTRINES:
		if DOCTRINES[id].axes.has(axis):
			return String(id)
	return ""


func base_spells() -> Array[Spell]:
	var result: Array[Spell] = []
	for path in BASE_PATHS:
		var original := load(path) as Spell
		if original != null:
			result.append(get_spell(String(original.spell_id)))
	return result


func _apply_painted_icons() -> void:
	for id in spells:
		var painted := CatabasePaintedIconCatalog.spell_icon(String(id))
		if painted == null:
			continue
		# Authored base spells are shared with selection and other adventures.
		var presented := (spells[id] as Spell).duplicate(false) as Spell
		presented.set_path_cache("")
		presented.icon = painted
		spells[id] = presented


func get_spell(id: String) -> Spell:
	return spells.get(id) as Spell


func get_spell_family(id: String) -> String:
	return String(_families.get(id, id))


func get_node(id: String) -> Dictionary:
	for node in nodes:
		if node.id == id:
			return node
	return {}


func card_spell_ids(axis: String = "") -> Array[String]:
	axis = normalize_axis(axis)
	var result: Array[String] = []
	for key in _card_ids:
		if axis.is_empty() or axis == key:
			for id in _card_ids[key]:
				result.append(String(id))
	return result


func get_spell_axis(id: String) -> String:
	var family := get_spell_family(id)
	for axis in _card_ids:
		if _card_ids[axis].has(family):
			return String(axis)
	return ""


func normalize_axis(axis: String) -> String:
	return String({"breaker": "briseur", "blood": "sang", "hunter": "chasseur",
		"dancer": "danseur", "bronze": "airain"}.get(axis, axis))


func all_spells() -> Array[Spell]:
	var result: Array[Spell] = []
	for value in spells.values():
		result.append(value as Spell)
	return result


func get_action_classifications() -> Array[CombatActionClassificationData]:
	var result: Array[CombatActionClassificationData] = []
	for kind in ACTION_IDS:
		for id in ACTION_IDS[kind]:
			var entry := CombatActionClassificationData.new()
			entry.ability_id = StringName(id)
			entry.classification = kind
			result.append(entry)
	for pair in [["exp_frappe_ouverte", CombatActionClassificationData.Classification.MELEE],
		["exp_tir_de_guet", CombatActionClassificationData.Classification.PROJECTILE],
		["exp_garde_eaque", CombatActionClassificationData.Classification.SELF],
		["exp_serment_rempart", CombatActionClassificationData.Classification.SELF],
		["exp_serment_brasier", CombatActionClassificationData.Classification.AREA]]:
		var entry := CombatActionClassificationData.new()
		entry.ability_id = StringName(pair[0])
		entry.classification = pair[1]
		result.append(entry)
	return result


func _create_doctrine_roots() -> void:
	var strike := _copy("achilles_peleid_strike", "frappe_ouverte", "Frappe d'ouverture",
		"Frappe du Péléide conserve ses dégâts et son coût ; après l'impact, la cible perd 15 armure jusqu'à sa prochaine activation. Ouvre Briseur et Sang héroïque.")
	strike.applied_status = _status("armure_ouverte", "Armure ouverte", {"armure": -15.0})
	_node("colere.root", "briseur", "racine", 1, "Colère du Péléide", strike.description, [], 1, String(strike.spell_id))
	var shot := _copy("achilles_pelion_shot", "tir_de_guet", "Tir de guet",
		"Tir du Pélion conserve sa portée et son coût ; +20 % dégâts contre une cible située à au moins 4 cases. Ouvre Chasseur et Danseur.")
	var distance := ItemSpellModifierData.new()
	distance.damage_percent = 0.20
	distance.target_distance_at_least = 4
	shot.modifiers.append(distance)
	_node("chiron.root", "chasseur", "racine", 1, "Leçon de Chiron", shot.description, [], 1, String(shot.spell_id))
	var guard := _copy("achilles_bronze_guard", "garde_eaque", "Garde d'Éaque",
		"Garde d'airain conserve son coût ; bouclier égal à 6 % PV max + 30 % Prouesse et +10 résistance magique jusqu'à la prochaine activation. Ouvre Airain et Endurance.")
	guard.shield_scaling = _scaling(0.30, 0.06)
	var protection := ExpeditionSpellModifier.new()
	protection.temporary_stats = {"resist_magique": 10.0}
	guard.modifiers.append(protection)
	_node("eaque.root", "airain", "racine", 1, "Égide d'Éaque", guard.description, [], 1, String(guard.spell_id))


func _create_serments() -> void:
	var rempart := _spell("serment_rempart", "Serment du rempart", 3, 0, 0, 0.0,
		"3 PA + 5 % PV max non létaux · Bouclier de 18 % PV max jusqu'à la prochaine activation. 2 usages/combat. Exclusif du Serment du brasier.")
	_self_only(rempart)
	rempart.max_uses_per_combat = 2
	rempart.shield_scaling = _scaling(0.0, 0.18)
	rempart.shield_duration_activations = 1
	rempart.shield_tags = [&"guard"]
	var price := ExpeditionSpellModifier.new()
	price.sacrifice_fraction = 0.05
	rempart.modifiers.append(price)
	var brasier := _spell("serment_brasier", "Serment du brasier", 4, 0, 0, 0.60,
		"4 PA + 8 % PV max non létaux · Croix autour de soi : 60 % Prouesse + 4 % PV max en dégâts Feu. 2 usages/combat. Exclusif du Serment du rempart.")
	_self_area(brasier)
	brasier.damage_type = Spell.DamageType.MAGICAL
	brasier.element = Spell.Element.FIRE
	brasier.damage_scaling = _scaling(0.60, 0.04)
	brasier.max_uses_per_combat = 2
	price = ExpeditionSpellModifier.new()
	price.sacrifice_fraction = 0.08
	brasier.modifiers.append(price)
	_node("serment.rempart", "serment", "serment", 2, rempart.spell_name, rempart.description, [], 8, String(rempart.spell_id))
	nodes.back()["exclusive_group"] = "serment_styx"
	_node("serment.brasier", "serment", "serment", 2, brasier.spell_name, brasier.description, [], 8, String(brasier.spell_id))
	nodes.back()["exclusive_group"] = "serment_styx"


func _create_martial_spells() -> void:
	var s := _spell("crochet", "Crochet", 2, 1, 2, 0.25,
		"2 PA · Portée 1–2 cardinale · 25 % Prouesse physique, attire de 1 case. Une fois par activation.")
	s.line_from_caster = true
	s.pull_distance = 1
	s = _spell("fauchage", "Fauchage", 3, 0, 0, 0.40,
		"3 PA · Croix autour de soi · 40 % Prouesse physique aux ennemis adjacents. Une fois par activation.")
	_self_area(s)
	s = _spell("entaille", "Entaille sacrificielle", 2, 1, 1, 0.80,
		"2 PA + 5 % PV max (arrondis au supérieur, coût non létal) · Portée 1 · 80 % Prouesse physique. Une fois par activation ; le sacrifice ignore les boucliers.")
	var mod := ExpeditionSpellModifier.new()
	mod.sacrifice_fraction = 0.05
	s.modifiers.append(mod)
	s = _spell("moisson", "Moisson vitale", 3, 1, 1, 0.35,
		"3 PA · Portée 1 · 35 % Prouesse physique ; récupère 50 % des PV ennemis effectivement retirés, au plus 5 % des PV max d'entrée. 2 usages par combat ; indisponible l'activation suivante. Consomme la réserve commune de soin.")
	s.max_uses_per_combat = 2
	s.cooldown_activations = 2
	mod = ExpeditionSpellModifier.new()
	mod.lifesteal_fraction = 0.50
	s.modifiers.append(mod)
	s = _spell("rupture", "Trait de rupture", 2, 2, 5, 0.25,
		"2 PA · Portée 2–5 avec ligne de vue · 25 % Prouesse physique, repousse de 1 case. Une fois par activation.")
	s.push_distance = 1
	s = _spell("marque", "Marque du chasseur", 2, 3, 7, 0.20,
		"2 PA · Portée 3–7 avec ligne de vue · 20 % Prouesse physique puis marque : le prochain impact physique reçu gagne 5 dégâts, sous 2 activations de la cible. Une fois par activation.")
	s.applied_status = _mark(1)
	s = _spell("feinte", "Feinte latérale", 2, 1, 2, 0.0,
		"2 PA · Avance de 1–2 cases libres en ligne cardinale ; +25 points de chance d'esquive jusqu'à la prochaine activation. Esquive totale plafonnée à 50 %. Indisponible l'activation suivante.")
	_movement(s)
	s.cooldown_activations = 2
	mod = ExpeditionSpellModifier.new()
	mod.temporary_stats = {"esquive": 0.25}
	s.modifiers.append(mod)
	s = _spell("contretemps", "Contretemps", 2, 1, 1, 0.30,
		"2 PA · Ennemi adjacent · 30 % Prouesse physique puis téléporte derrière la cible si la case est libre. Indisponible l'activation suivante ; aucun déplacement si la case est occupée.")
	s.teleport_behind_target = true
	s.cooldown_activations = 2
	s = _spell("heurt", "Heurt d'airain", 2, 1, 1, 0.25,
		"2 PA · Portée 1 · 25 % Prouesse physique et repousse de 1 case. Une fois par activation. N'exige pas de Garde équipée.")
	s.push_distance = 1
	s = _spell("posture", "Posture d'airain", 2, 0, 0, 0.0,
		"2 PA · Sur soi · +45 armure jusqu'à la prochaine activation ; réduit de 1 les PM disponibles à cette prochaine activation. Bouclier de 20 % Prouesse, même durée. Une fois par activation.")
	_self_only(s)
	mod = ExpeditionSpellModifier.new()
	mod.temporary_stats = {"armure": 45.0}
	mod.next_activation_mp_penalty = 1
	s.modifiers.append(mod)
	s.shield_scaling = _scaling(0.20)
	s.shield_duration_activations = 1
	s.shield_tags = [&"guard"]
	s = _spell("souffle", "Second souffle", 3, 0, 0, 0.0,
		"3 PA · Sur soi · Soigne 8 % des PV max d'entrée en combat. 2 usages par combat, dans la limite de la réserve commune (20 %, ou 30 % avec Souffle profond). Ne recharge pas la réserve.")
	_self_only(s)
	s.heal = 1
	s.max_uses_per_combat = 2
	mod = ExpeditionSpellModifier.new()
	mod.heal_fraction = 0.08
	s.modifiers.append(mod)
	s = _spell("marche", "Marche du survivant", 2, 1, 2, 0.0,
		"2 PA · Avance de 1–2 cases libres en ligne cardinale et soigne 4 % des PV max d'entrée. 2 usages par combat. Consomme la même réserve de soin que Second souffle et Moisson.")
	_movement(s)
	s.max_uses_per_combat = 2
	mod = ExpeditionSpellModifier.new()
	mod.heal_fraction = 0.04
	s.modifiers.append(mod)
	_card_ids = {"briseur": ["exp_crochet", "exp_fauchage"], "sang": ["exp_entaille", "exp_moisson"],
		"chasseur": ["exp_rupture", "exp_marque"], "danseur": ["exp_feinte", "exp_contretemps"],
		"airain": ["exp_heurt", "exp_posture"], "endurance": ["exp_souffle", "exp_marche"]}


func _create_elemental_spells() -> void:
	var s := _spell("braise", "Trait de braise", 3, 1, 5, 0.35,
		"3 PA · Portée 1–5 · 35 % Prouesse magique Feu ; pose une braise 2 tours (3 dégâts magiques Feu au début du tour de l'occupant, alliés inclus). Une fois par activation.")
	s.damage_type = Spell.DamageType.MAGICAL
	s.element = Spell.Element.FIRE
	s.can_target_free_cell = true
	var terrain := TerrainEffectData.new()
	terrain.surface_id = &"expedition_braise"
	terrain.effect_name = "Braise"
	terrain.description = "3 dégâts magiques Feu au début du tour de l'occupant ; 2 tours."
	terrain.damage = 3
	terrain.element = Spell.Element.FIRE
	terrain.duration = 2
	terrain.can_be_dodged = false
	terrain.dangerous_for_ai = true
	terrain.color = Color(0.95, 0.32, 0.10, 0.8)
	terrain.same_surface_policy = TerrainEffectData.SameSurfacePolicy.REFRESH_DURATION
	s.terrain_effect = terrain
	s = _spell("givre", "Entrave de givre", 2, 1, 5, 0.20,
		"2 PA · Portée 1–5 · 20 % Prouesse magique Glace, -1 PM à la prochaine activation de la cible. Une fois par activation.")
	s.damage_type = Spell.DamageType.MAGICAL
	s.element = Spell.Element.ICE
	s.applied_status = _status("givre", "Entrave de givre", {})
	s.applied_status.mp_reduction = 1
	s = _spell("foudre", "Ligne fulgurante", 3, 2, 5, 0.30,
		"3 PA · Ligne cardinale jusqu'à une case à 2–5 de distance · 30 % Prouesse magique Foudre à chaque ennemi de la ligne, -1 PA à sa prochaine activation. Indisponible l'activation suivante.")
	s.damage_type = Spell.DamageType.MAGICAL
	s.element = Spell.Element.LIGHTNING
	s.aoe_shape = Spell.AoeShape.LINE
	s.line_from_caster = true
	s.can_target_free_cell = true
	s.exclude_allies_from_area_effects = true
	s.ap_drain = 1
	s.cooldown_activations = 2
	_card_ids["elements"] = ["exp_braise", "exp_givre", "exp_foudre"]


func _create_nodes() -> void:
	for axis in _card_ids:
		var ids: Array = _card_ids[axis]
		var doctrine := doctrine_for_axis(String(axis))
		var prerequisites: Array = [doctrine + ".root"] if not doctrine.is_empty() else []
		for index in ids.size():
			var spell := get_spell(ids[index])
			_node("%s.learn_%s" % [axis, char(97 + index)], axis, "apprentissage", 1,
				spell.spell_name, spell.description, prerequisites, 1, String(spell.spell_id))
	_create_axis("briseur", "crochet", "fauchage", ["force", 1.0, false], ["attack_power", 0.08, true],
		"Levier", "+1 Force : renforce les déplacements forcés selon leurs règles communes.", "Élan brutal", "+8 % Prouesse.")
	_create_axis("sang", "entaille", "moisson", ["max_hp", 0.15, true], ["attack_power", 0.08, true],
		"Sang dense", "+15 % PV max ; ne soigne pas les blessures existantes.", "Prix du courage", "+8 % Prouesse.")
	_create_axis("chasseur", "rupture", "marque", ["initiative", 3.0, false], ["attack_power", 0.08, true],
		"Lecture du terrain", "+3 initiative.", "Œil du Pélion", "+8 % Prouesse.")
	_create_axis("danseur", "feinte", "contretemps", ["max_mp", 1.0, false], ["esquive", 0.08, false],
		"Appuis légers", "+1 PM par activation.", "Angle mort", "+8 points de chance d'esquive ; plafond commun de 50 %.")
	_create_axis("airain", "heurt", "posture", ["armure", 18.0, false], ["resist_magique", 12.0, false],
		"Bronze épais", "+18 armure.", "Bronze gravé", "+12 résistance magique.")
	_create_axis("endurance", "souffle", "marche", ["max_hp", 0.10, true], ["heal_budget", 0.10, true],
		"Réserve du héros", "+10 % PV max ; ne soigne pas les blessures existantes.", "Souffle profond", "La réserve commune de soin passe de 20 à 30 % des PV max d'entrée dès le prochain combat.")
	_create_axis("elements", "braise", "givre", ["resist_magique", 12.0, false], ["attack_power", 0.08, true],
		"Accord des éléments", "+12 résistance magique.", "Conduction", "+8 % Prouesse pour vos techniques et sorts élémentaires.")


func _create_axis(axis: String, first: String, second: String, stat_a: Array, stat_b: Array,
		title_a: String, desc_a: String, title_b: String, desc_b: String) -> void:
	var mutation := _copy("exp_" + first, first + "_mutation", "", "")
	var signature := _copy("exp_" + second, second + "_signature", "", "")
	var legend := _copy("exp_" + first, first + "_legend", "", "")
	_configure_forms(axis, mutation, signature, legend)
	_node(axis + ".mutation", axis, "mutation", 2, mutation.spell_name, mutation.description,
		[axis + ".learn_a"], 2, String(mutation.spell_id))
	_node(axis + ".liaison_a", axis, "liaison", 1, title_a, desc_a, [axis + ".learn_a"], 0, "", stat_a)
	_node(axis + ".liaison_b", axis, "liaison", 1, title_b, desc_b, [axis + ".learn_b"], 0, "", stat_b)
	_node(axis + ".signature", axis, "signature", 2, signature.spell_name, signature.description,
		[axis + ".learn_b"], 6, String(signature.spell_id))
	_node(axis + ".legend", axis, "légende", 2, legend.spell_name, legend.description,
		[axis + ".mutation", axis + ".signature"], 12, String(legend.spell_id))


func _configure_forms(axis: String, m: Spell, s: Spell, l: Spell) -> void:
	match axis:
		"briseur":
			m.spell_name = "Harpon du Péléide"
			m.ap_cost = 3; m.pull_distance = 2; m.spell_range = 3
			m.damage_scaling = _scaling(0.35)
			m.description = "3 PA · Portée 1–3 cardinale · 35 % Prouesse physique et attire de 2 cases. Remplace la forme de Crochet ; gagne en portée au prix de 1 PA."
			s.spell_name = "Fracas circulaire"
			s.ap_cost = 4; s.damage_scaling = _scaling(0.60); s.push_distance = 1; s.push_affected_units = true
			s.description = "4 PA · Croix autour de soi · 60 % Prouesse physique et repousse chaque ennemi adjacent de 1 case. Forme exclusive de Fauchage : dispersion contre dégâts."
			l.spell_name = "Hameçon du destin"
			l.pull_distance = 2; l.spell_range = 3; l.ap_drain = 1; l.cooldown_activations = 2
			l.damage_scaling = _scaling(0.15)
			l.description = "2 PA · Portée 1–3 cardinale · 15 % Prouesse physique, attire de 2 cases et retire 1 PA au prochain tour. Indisponible l'activation suivante. Forme exclusive de Crochet : contrôle plutôt que puissance brute."
		"sang":
			m.spell_name = "Veine ouverte"
			m.damage_scaling = _scaling(1.10); m.cooldown_activations = 2
			(m.modifiers[0] as ExpeditionSpellModifier).sacrifice_fraction = 0.08
			m.description = "2 PA + 8 % PV max non létaux · Portée 1 · 110 % Prouesse physique. Indisponible l'activation suivante. Forme exclusive d'Entaille : burst plus risqué."
			s.spell_name = "Moisson de guerre"
			_self_area(s); s.ap_cost = 4; s.damage_scaling = _scaling(0.40)
			(s.modifiers[0] as ExpeditionSpellModifier).lifesteal_cap_fraction = 0.10
			s.description = "4 PA · Croix autour de soi · 40 % Prouesse physique aux ennemis adjacents, soigne 50 % des PV retirés, au plus 10 % PV max d'entrée. 2 usages/combat, réserve commune, indisponible l'activation suivante. Forme exclusive de Moisson."
			l.spell_name = "Serment du talon"
			l.damage_scaling = _scaling(0.20, 0.08); l.cooldown_activations = 2
			(l.modifiers[0] as ExpeditionSpellModifier).sacrifice_fraction = 0.08
			l.description = "2 PA + 8 % PV max non létaux · Portée 1 · Dégâts physiques : 20 % Prouesse + 8 % PV max. Indisponible l'activation suivante. Forme exclusive d'Entaille : votre vitalité devient une arme."
		"chasseur":
			m.spell_name = "Tir de traverse"
			_line(m); m.ap_cost = 3; m.damage_scaling = _scaling(0.35); m.push_distance = 0
			m.description = "3 PA · Ligne cardinale jusqu'à une case à 2–5 de distance · 35 % Prouesse physique à chaque ennemi traversé. Forme exclusive de Trait de rupture : perd la poussée, gagne une trajectoire multiple."
			s.spell_name = "Sentence du guetteur"
			s.ap_cost = 3; s.damage_scaling = _scaling(0.35); s.applied_status = _mark(2)
			s.description = "3 PA · Portée 3–7 · 35 % Prouesse physique puis marque : les 2 prochains impacts physiques gagnent 5 dégâts, sous 2 activations de la cible. Forme exclusive de Marque : prépare un combo à deux coups."
			l.spell_name = "Horizon percé"
			_line(l); l.ap_cost = 4; l.minimum_range = 3; l.spell_range = 7; l.push_distance = 0; l.damage_scaling = _scaling(0.65)
			l.description = "4 PA · Ligne cardinale jusqu'à une case à 3–7 de distance · 65 % Prouesse physique à chaque ennemi traversé. Forme exclusive de Trait de rupture : exige distance et alignement."
		"danseur":
			m.spell_name = "Pas sans retour"
			m.ap_cost = 1; m.spell_range = 3
			(m.modifiers[0] as ExpeditionSpellModifier).temporary_stats = {}
			m.description = "1 PA · Avance de 1–3 cases libres en ligne cardinale. Indisponible l'activation suivante. Forme exclusive de Feinte : perd l'esquive temporaire pour libérer 1 PA."
			s.spell_name = "Revers du Danseur"
			s.ap_cost = 3; s.damage_scaling = _scaling(0.55); s.ap_drain = 1
			s.description = "3 PA · Portée 1 · 55 % Prouesse physique, retire 1 PA au prochain tour et passe derrière si la case est libre. Indisponible l'activation suivante. Forme exclusive de Contretemps."
			l.spell_name = "Sillage trompeur"
			l.ap_cost = 3; l.spell_range = 4; l.movement_requires_clear_path = false
			l.description = "3 PA · Bond vers une case libre à 1–4 cases en ligne cardinale, traverse les obstacles ; +25 points d'esquive jusqu'à la prochaine activation (plafond 50 %). Indisponible l'activation suivante. Forme exclusive de Feinte."
		"airain":
			m.spell_name = "Bélier d'airain"
			m.ap_cost = 3; m.push_distance = 2; m.collision_damage = 6; m.damage_scaling = _scaling(0.30)
			m.description = "3 PA · Portée 1 · 30 % Prouesse physique, pousse de 2 cases ; collision de base 6 dégâts selon les règles de Force. Forme exclusive de Heurt : exige un obstacle bien placé."
			s.spell_name = "Bastion mobile"
			s.ap_cost = 3
			(s.modifiers[0] as ExpeditionSpellModifier).temporary_stats = {"armure": 30.0}
			(s.modifiers[0] as ExpeditionSpellModifier).next_activation_mp_penalty = 0
			s.shield_scaling = _scaling(0.65)
			s.description = "3 PA · Sur soi · +30 armure et bouclier de 65 % Prouesse jusqu'à la prochaine activation. Forme exclusive de Posture : retire le malus PM, coûte 1 PA de plus."
			l.spell_name = "Cercle de bronze"
			_self_area(l); l.ap_cost = 4; l.push_affected_units = true; l.push_distance = 2; l.damage_scaling = _scaling(0.35)
			l.description = "4 PA · Croix autour de soi · 35 % Prouesse physique et pousse chaque ennemi adjacent de 2 cases. Forme exclusive de Heurt : libère le front au prix de l'alignement offensif."
		"endurance":
			m.spell_name = "Souffle retenu"
			m.ap_cost = 2; m.cooldown_activations = 2
			(m.modifiers[0] as ExpeditionSpellModifier).heal_fraction = 0.06
			m.description = "2 PA · Soigne 6 % PV max d'entrée, 2 usages/combat, réserve commune. Indisponible l'activation suivante. Forme exclusive de Second souffle : soin plus faible, tour plus ouvert."
			s.spell_name = "Marche purificatrice"
			s.ap_cost = 3; s.spell_range = 3
			(s.modifiers[0] as ExpeditionSpellModifier).cleanse_movement = true
			s.description = "3 PA · Avance de 1–3 cases libres en ligne cardinale, soigne 4 % PV max d'entrée et retire les statuts réduisant PA ou PM. 2 usages/combat, réserve commune. Forme exclusive de Marche."
			l.spell_name = "Serment de survie"
			l.ap_cost = 4; l.max_uses_per_combat = 1
			(l.modifiers[0] as ExpeditionSpellModifier).heal_fraction = 0.15
			l.shield_scaling = _scaling(0.40); l.shield_duration_activations = 1
			l.description = "4 PA · Soigne 15 % PV max d'entrée (réserve commune) et donne un bouclier de 40 % Prouesse jusqu'à la prochaine activation. 1 usage/combat. Forme exclusive de Second souffle : une seule grande fenêtre."
		"elements":
			m.spell_name = "Brasier cruciforme"
			m.ap_cost = 4; m.aoe_shape = Spell.AoeShape.CROSS; m.damage_scaling = _scaling(0.25); m.exclude_allies_from_area_effects = true
			m.description = "4 PA · Portée 1–5, croix de 1 case · 25 % Prouesse magique Feu par ennemi et 5 cases de braise (3 dégâts Feu au début du tour, alliés inclus, 2 tours). Forme exclusive de Trait de braise : investir dans le terrain."
			s.spell_name = "Verrou de givre"
			s.ap_cost = 3; s.applied_status = _status("verrou", "Verrou de givre", {}); s.applied_status.mp_reduction = 2; s.damage_scaling = _scaling(0.15)
			s.description = "3 PA · Portée 1–5 · 15 % Prouesse magique Glace ; -2 PM à la prochaine activation de la cible. Forme exclusive d'Entrave : échange dégâts et PA contre contrôle."
			l.spell_name = "Couronne de braise"
			l.ap_cost = 4; l.aoe_shape = Spell.AoeShape.CROSS; l.damage_scaling = _scaling(0.45); l.cooldown_activations = 2; l.exclude_allies_from_area_effects = true
			l.terrain_effect = l.terrain_effect.duplicate(true); l.terrain_effect.damage = 5
			l.description = "4 PA · Portée 1–5, croix de 1 case · 45 % Prouesse magique Feu par ennemi, braises de 5 dégâts Feu pendant 2 tours (alliés inclus). Indisponible l'activation suivante. Forme exclusive de Trait de braise."
	# Mutation descriptions share the same baseline quota unless overridden above.
	for spell in [m, s, l]:
		spell.description += " Une forme par famille équipée."


func _node(id: String, axis: String, kind: String, cost: int, title: String, description: String,
		prerequisites: Array, depth: int = 0, spell_id: String = "", stat: Array = []) -> void:
	nodes.append({"id": id, "axis": axis, "kind": kind, "cost": cost, "title": title,
		"description": description, "prerequisites": prerequisites, "minimum_depth": depth,
		"spell_id": spell_id, "stat": stat})


func _spell(id: String, title: String, ap: int, minimum: int, maximum: int, prowess: float, description: String) -> Spell:
	var spell := Spell.new()
	spell.spell_id = StringName("exp_" + id)
	spell.spell_name = title
	spell.description = description
	spell.ap_cost = ap
	spell.minimum_range = minimum
	spell.spell_range = maximum
	spell.damage_type = Spell.DamageType.PHYSICAL
	spell.once_per_activation = true
	if prowess > 0.0:
		spell.damage_scaling = _scaling(prowess)
	_register(spell, String(spell.spell_id))
	return spell


func _copy(source_id: String, id: String, title: String, description: String) -> Spell:
	var source := get_spell(source_id)
	# Never recursively duplicate the historical skill tree attached to Frappe.
	# Only the combat payloads of this experimental form need mutable copies.
	var spell := source.duplicate(false) as Spell
	spell.damage_scaling = source.damage_scaling.duplicate(true) if source.damage_scaling != null else null
	spell.shield_scaling = source.shield_scaling.duplicate(true) if source.shield_scaling != null else null
	spell.applied_status = source.applied_status.duplicate(true) if source.applied_status != null else null
	spell.terrain_effect = source.terrain_effect.duplicate(true) if source.terrain_effect != null else null
	spell.modifiers = []
	for modifier in source.modifiers:
		spell.modifiers.append(modifier.duplicate(true) as SpellModifier)
	spell.spell_id = StringName("exp_" + id)
	spell.spell_name = title
	spell.description = description
	spell.skill_tree = null
	_register(spell, get_spell_family(source_id))
	return spell


func _register(spell: Spell, family: String) -> void:
	spells[String(spell.spell_id)] = spell
	_families[String(spell.spell_id)] = family


func _scaling(prowess: float, hp: float = 0.0) -> SpellScalingData:
	var scaling := SpellScalingData.new()
	scaling.prowess_coefficient = prowess
	scaling.max_hp_coefficient = hp
	return scaling


func _self_only(spell: Spell) -> void:
	spell.can_target_enemy = false
	spell.can_target_free_cell = false
	spell.can_target_self = true
	spell.minimum_range = 0
	spell.spell_range = 0
	spell.needs_line_of_sight = false


func _self_area(spell: Spell) -> void:
	_self_only(spell)
	spell.aoe_shape = Spell.AoeShape.CROSS
	spell.aoe_size = 1
	spell.exclude_caster_from_area_effects = true
	spell.exclude_allies_from_area_effects = true
	spell.line_from_caster = false


func _movement(spell: Spell) -> void:
	spell.can_target_enemy = false
	spell.can_target_free_cell = true
	spell.line_from_caster = true
	spell.caster_movement = Spell.CasterMovement.TARGET_CELL
	spell.movement_requires_clear_path = true
	spell.needs_line_of_sight = false


func _line(spell: Spell) -> void:
	spell.aoe_shape = Spell.AoeShape.LINE
	spell.line_from_caster = true
	spell.can_target_free_cell = true
	spell.exclude_allies_from_area_effects = true


func _status(id: String, title: String, stats: Dictionary) -> StatusData:
	var status := StatusData.new()
	status.status_id = StringName("exp_" + id)
	status.status_name = title
	status.duration = 1
	status.stat_modifiers = stats
	status.modifier_source = StringName("exp_status_" + id)
	return status


func _mark(charges: int) -> ChargedDamageVulnerabilityData:
	var status := ChargedDamageVulnerabilityData.new()
	status.status_id = &"exp_hunter_mark"
	status.status_name = "Proie désignée"
	status.duration = 2
	status.bonus_damage = 5
	status.max_charges = charges
	status.trigger_damage_type = Spell.DamageType.PHYSICAL
	return status
