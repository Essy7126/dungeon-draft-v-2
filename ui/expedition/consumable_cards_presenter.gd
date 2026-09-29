extends RefCounted
const Language := preload("res://ui/expedition/card_player_language.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const SPECS := {
	"execution": "Exécution",
	"relay": "Relais",
	"bastion": "Bastion",
	"crusher": "Briseur",
	"sniper": "Tireur",
	"skirmish": "Escarmouche",
	"pyre": "Brasier",
	"frost": "Givre",
}
const SLOTS := {
	"weapon": "Arme",
	"body": "Armure",
	"head": "Tête",
	"feet": "Pieds",
	"belt": "Ceinture",
	"amulet": "Amulette",
}
const MODS := {
	"mastery_earth": "maîtrise Terre", "mastery_water": "maîtrise Eau", "mastery_fire": "maîtrise Feu",
	"mastery_wind": "maîtrise Vent", "mastery_night": "maîtrise Nuit", "mastery_sun": "maîtrise Soleil",
	"melee": "dégâts au contact",
	"ranged": "dégâts à 3 cases ou plus",
	"range": "portée",
	"mp": "PM",
	"hand": "taille de main",
	"hp": "PV maximaux",
	"armor": "résistance physique",
	"magicResist": "résistance magique",
	"guard": "garde produite",
	"damage": "dégâts des cartes",
	"magic": "dégâts magiques",
	"healing": "soins",
	"openingShield": "garde initiale (P)",
	"firstHitReduction": "réduction du premier coup (P)",
	"lifesteal": "drain de vie",
}
const UNIT_DATA := {
	"brute": "res://data/units/ennemie/skeleton_melee.tres",
	"archer": "res://data/units/ennemie/skeleton_ranged.tres",
	"hound": "res://data/units/enemies/catabase_molosse_styx.tres",
	"mage": "res://data/units/enemies/catabase_lamie_lethe.tres",
	"priest": "res://data/units/enemies/catabase_lamie_lethe.tres",
	"guard": "res://data/units/enemies/catabase_sentinelle_airain.tres",
	"boss": "res://data/units/enemies/catabase_shadow_paris.tres",
}
const REASONS := {
	"choose_specialization": "Choisissez votre spécialisation avant de poursuivre.",
	"write_failed": "Sauvegarde impossible. L'action est annulée. Réessayez avant de continuer.",
	"checkpoint_unavailable": "La sauvegarde doit être réessayée.",
	"preparation": "Préparation impossible : 30 cartes au total, 3 du même sort au maximum.",
	"opening": "L'ouverture doit être une carte normale préparée.",
	"insufficient_gold": "Or insuffisant.",
	"family_or_choice_unavailable": "Sort déjà utilisé ce tour, ou choix à terminer.",
	"choice_pending": "Terminez le choix de rétention ou de Relais.",
	"movement": "Cette case n'est pas accessible avec vos PM.",
	"mechanism_out_of_reach": "Approchez-vous du mécanisme et gardez les PA nécessaires.",
	"mechanism_unavailable": "Mécanisme déjà utilisé ce tour ou PA insuffisants.",
	"upgrade": "Aucun point disponible, ou sort déjà amélioré.",
	"attribute": "Aucun point d'attribut disponible.",
	"trade_unavailable": "Troc indisponible.",
	"normal_copies_required": "Le troc demande trois cartes normales.",
	"sold_out": "Stock épuisé.",
	"boss_cannot_swap": "Pâris ne peut pas être permuté.",
	"requires_mark_without_stasis_immunity": "La cible doit être marquée et ne pas être immunisée à la Stase.",
}


static func reason(id: String) -> String:
	return str(
		REASONS.get(
			id,
			"Action impossible : vérifiez portée, ligne de vue, cible et PA. (" + id + ")",
		)
	)


static func status_entries(unit: Unit) -> Array:
	# Presentation copies only: never apply these StatusData to the simulation.
	var result: Array = unit.get_active_statuses().duplicate()
	var names := {
		"mark": "Marque",
		"slow": "Entrave",
		"burn": "Brûlure",
		"bleed": "Saignement",
		"weak": "Affaiblissement",
		"stasis": "Stase",
		"stasis_ward": "Immunité à la Stase",
		"parry": "Parade",
		"counter": "Riposte",
		"edict": "Édit",
	}
	var effects: Dictionary = unit.get_meta("cc2_effects", { })
	for key in effects:
		var value: Dictionary = effects[key]
		var amount := float(value.amount)
		var data := StatusData.new()
		data.status_id = StringName("cc2_" + str(key))
		data.status_name = names.get(key, str(key))
		data.color = Color("d7bd87")
		match str(key):
			"mark":
				data.description = "+%.1f dégâts sur le prochain impact direct, puis consommée." % amount
			"slow":
				data.description = "−%d PM à la prochaine activation." % int(amount)
			"burn", "bleed":
				data.description = "%.1f dégâts avant résistance à chaque début d'activation." % amount
			"weak":
				data.description = "−%.0f %% de dégâts sur la prochaine attaque." % (amount * 100)
			"stasis":
				data.description = "La prochaine activation est sautée ; l'attaque annoncée est annulée."
			"stasis_ward":
				data.description = "Empêche une nouvelle Stase pendant les activations indiquées."
			"parry":
				data.description = "Réduit le prochain impact physique de %.1f avant résistance." % amount
			"counter":
				data.description = "Riposte de %.1f au prochain impact adjacent, avant la prochaine activation." % amount
			"edict":
				data.description = "Empêche une mort jusqu'à la prochaine activation, sauf pression de fin de combat."
		result.append({ "data": data, "remaining": int(value.duration) })
	var variant := str(unit.get_meta("cc2_variant", ""))
	var rules: Dictionary = {
		"formation": [
			"Porteur de formation",
			"Au début de son activation, protège les alliés adjacents de 0,25 P si le héros n'est pas adjacent. La protection expire à sa prochaine activation.",
		],
		"support": [
			"Soutien",
			"Une activation sur deux, protège un allié à trois cases avec ligne de vue au lieu d'attaquer : 0,40 P de garde.",
		],
		"parry": [
			"Parade finie",
			"À chaque activation, prépare une réduction de 0,40 P contre le prochain impact physique direct. Les autres effets de la carte restent applicables.",
		],
		"execution": [
			"Exécuteur",
			"Prépare une frappe au contact : la case annoncée est frappée à sa prochaine activation. Déplacez-vous ou interrompez-le.",
		],
	}
	if rules.has(variant):
		var passive := StatusData.new()
		passive.status_id = StringName("cc2_variant_" + variant)
		passive.status_name = rules[variant][0]
		passive.description = Language.plain(rules[variant][1])
		passive.color = Color("d7bd87")
		result.append({ "data": passive, "remaining": -1 })
	return result


static func item(id: String) -> Dictionary:
	for key in ["equipment", "relics"]:
		for row in Catalog.data()[key]:
			if row.id == id:
				return row
	return { }


static func item_text(row: Dictionary) -> String:
	if row.has("rule"):
		return Language.plain(row.rule)
	var parts: Array[String] = []
	for key in row.get("mods", { }):
		var n := float(row.mods[key])
		if key in ["openingShield", "firstHitReduction"]:
			parts.append(
				("%+.0f %% de Puissance · " % (n * 100)) + str(MODS[key]).replace(" (P)", "")
			)
			continue
		parts.append(
			("%+d " % int(n) if key in ["range", "mp", "hand"] else "%+.0f %% " % (n * 100))
			+ str(MODS.get(key, key))
		)
	return " · ".join(parts)


static func apply_visuals(battle, variant: Dictionary) -> void:
	var hero_data: UnitData = load("res://data/units/allies/achilles.tres").duplicate(true)
	RunHeroVisualVariants.apply_to_runtime(hero_data, variant)
	battle.hero.visual_scene = hero_data.visual_scene
	battle.hero.unit_name = "Passe-rive" if variant.get("achilles") == "passe_rive" else "Achille"
	for enemy in battle.enemies:
		var data: UnitData = load(UNIT_DATA[str(enemy.get_meta("cc2_kind"))])
		enemy.visual_scene = data.visual_scene


static func room_text(battle) -> String:
	var p: float = battle.reference_power()
	match str(battle.encounter.map):
		"forge":
			return "Forge : ligne %d frappée en fin de phase ennemie (%d sur le héros, %d sur les ennemis, avant résistance). Levier en (0,3), 1 PA." % [
				int(battle.room.rail),
				roundi(.6 * p),
				roundi(1.3 * p),
			]
		"garden":
			return "Jardin : anneau de rayon %d autour du premier ennemi vivant, en fin de phase ennemie. Déplacez son centre ou sortez de l'anneau." % int(
				[2, 3, 1][(battle.cards.round_index - 1) % 3]
			)
		"convoy":
			return "Convoi : deux porteurs gagnent le relais (3,0) et renforcent leur chef. Scellez au levier (0,3), 2 PA."
		"hourglass":
			return "Sablier : croix de rayon 2 centrée en (%d,%d). Levier (0,3) : retarde une fois, 1 PA ; prochaine frappe ×1,5." % [
				int(battle.room.clock[0]),
				int(battle.room.clock[1]),
			]
		"reservoir":
			return "Réservoirs (0,3) et (6,3) : stockent vos PA restants à proximité. Charges %d / %d. Décharge 1 PA ; chaque charge inflige %d dégâts." % [
				int(battle.room.charges[0]),
				int(battle.room.charges[1]),
				roundi(.5 * p),
			]
	return "Lisez les intentions, économisez vos copies et préparez votre prochain tour."


static func unit_text(unit: Unit) -> String:
	var lines: Array[String] = [
		"%s · %d/%d PV · %d garde"
		% [unit.unit_name, unit.current_hp, unit.max_hp.get_int(), unit.current_shield]
	]
	lines.append(
		"Case (%d,%d) · puissance %.1f · portée %d · %d PM\nRésistance physique %.0f %% · magique %.0f %%"
		% [
			unit.grid_pos.x,
			unit.grid_pos.y,
			unit.attack_power.get_value(),
			unit.maximum_range,
			unit.max_mp.get_int(),
			minf(40, unit.armure.get_value()),
			minf(40, unit.resist_magique.get_value()),
		]
	)
	var names := {
		"mark": "Marque",
		"burn": "Brûlure",
		"weak": "Affaibli",
		"stasis": "Stase",
		"stasis_ward": "Immunité à la Stase",
		"parry": "Parade",
		"slow": "Entrave",
	}
	for key in unit.get_meta("cc2_effects", { }):
		var state: Dictionary = unit.get_meta("cc2_effects")[key]
		lines.append(
			"%s : %.1f · durée %d" % [names.get(key, key), float(state.amount), int(state.duration)]
		)
	var variant := str(unit.get_meta("cc2_variant", ""))
	var behavior := {
		"execution": "Prépare une exécution adjacente ; sortez de la case annoncée ou interrompez-la.",
		"support": "Une activation sur deux : protège un allié à 3 cases avec ligne de vue.",
		"formation": "Protège les alliés adjacents tant que le héros reste à distance.",
		"parry": "Renouvelle une parade de 0,40 P de référence ; consommée par la prochaine carte directe.",
	}
	if behavior.has(variant):
		lines.append(behavior[variant])
	if unit.get_meta("cc2_kind", "") == "priest":
		lines.append("Une activation sur deux : protège l'allié le plus blessé puis attaque.")
	if unit.get_meta("cc2_boss", false):
		lines.append(
			"Pâris · phase %d/2 · changement à 50 %% PV" % int(unit.get_meta("cc2_phase", 1))
		)
	var intent: Dictionary = unit.get_meta("cc2_intent", { })
	if not intent.is_empty():
		lines.append(
			"INTENTION · prochaine activation · %.1f dégâts bruts · cases %s"
			% [
				unit.attack_power.get_value() * float(intent.multiplier),
				JSON.stringify(intent.cells),
			]
		)
	return "\n".join(lines)
