class_name CatabasePreparationCatalog
extends RefCounted
## First playable tranche. Stable IDs are also validated when loading a save.
const WEAPONS := {
	"marteau": [
		"Marteau funéraire",
		"Rupture : ouvre l'armure et prépare les collisions.",
		"exp_ct_masse",
		"exp_ct_pousse",
		"briseur",
	],
	"xiphos": [
		"Xiphos et bouclier",
		"Salve : amortit plusieurs petits impacts ; vulnérable aux gros coups.",
		"exp_ct_taille",
		"exp_ct_salve",
		"airain",
	],
	"disque": [
		"Disque de bronze",
		"Retour : le disque reste sur sa case de chute jusqu'à sa récupération.",
		"exp_ct_lancer",
		"exp_ct_retour",
		"chasseur",
	],
	"hampe": [
		"Hampe des braises",
		"Combustion : pose puis déplace ses braises ; attention à vos propres zones.",
		"exp_ct_braise",
		"exp_ct_flux",
		"elements",
	],
	"lame": [
		"Lame des cicatrices",
		"Sang : fêlures persistantes et récolte limitée aux PV réellement retirés.",
		"exp_ct_entaille",
		"exp_ct_recolte",
		"sang",
	],
	"arc": [
		"Arc du tribut",
		"Oboles : achète un surcroît de dégâts au prix de ses achats futurs.",
		"exp_ct_trait",
		"exp_ct_peage",
		"chasseur",
	],
}
const ARMORS := {
	"airain": ["Airain", 55, 0, 0, "55 armure · aucune défense magique."],
	"sceau": ["Sceau", 0, 55, 0, "55 défense magique · aucune armure."],
	"mixte": ["Lin gravé", 22, 22, 0, "22 armure et 22 défense magique."],
	"legere": ["Tenue de traverse", 10, 10, 1, "10 dans les deux défenses · +1 PM."],
}
const TECHNIQUES := [
	"exp_crochet",
	"exp_fauchage",
	"exp_moisson",
	"exp_rupture",
	"exp_marque",
	"exp_feinte",
	"exp_contretemps",
	"exp_heurt",
	"exp_posture",
	"exp_souffle",
	"exp_marche",
	"exp_ct_sceau",
	"exp_ct_repercussion",
]
const RELICS := {
	"clou": [
		"Clou des Myrmidons",
		"Vos impacts physiques payés gagnent 20 % contre une cible déjà déplacée pendant cette activation.",
		1,
	],
	"urne": [
		"Urne de bronze",
		"Stocke la moitié de la garde absorbée, maximum 40. Répercussion dépense cette réserve.",
		2,
	],
	"fil": [
		"Fil du retour",
		"Le premier retour de disque réussi de chaque activation rend 1 PM. Aucun PA rendu.",
		3,
	],
	"coupe": [
		"Coupe des blessures",
		"Soigne 15 % des dégâts physiques directs réellement infligés. Réserve de 30 PV par combat, sans soin sur les effets secondaires.",
		4,
	],
	"meche": [
		"Mèche errante",
		"Flux déplace vos braises de 2 cases au lieu d'une. Leur durée restante est conservée.",
		5,
	],
	"obole": [
		"Obole fendue",
		"Chaque élimination directe payée donne 4 oboles, maximum 20 par combat.",
		6,
	],
}
const SUPPLIES := {
	"onguent": ["Dernier onguent", "1 PA · soigne 24 PV · usage unique.", 1],
	"souffle": ["Souffle en fiole", "1 PA · donne 2 PM ce tour · usage unique.", 2],
	"plaque": ["Plaque d'offrande", "1 PA · 24 garde jusqu'au prochain tour · usage unique.", 3],
	"sel": ["Sel blanc", "1 PA · retire les pénalités de PA, PM et statistiques · usage unique.", 4],
}
const PRESETS := {
	"marteau": ["sceau", "exp_crochet", "exp_feinte", "clou", "onguent"],
	"xiphos": ["airain", "exp_ct_repercussion", "exp_souffle", "urne", "sel"],
	"disque": ["legere", "exp_feinte", "exp_marque", "fil", "plaque"],
	"hampe": ["sceau", "exp_crochet", "exp_ct_sceau", "meche", "souffle"],
	"lame": ["mixte", "exp_posture", "exp_marche", "coupe", "onguent"],
	"arc": ["legere", "exp_marque", "exp_feinte", "obole", "plaque"],
}
const LEGACY_WEAPONS := {
	"catabase_levier": "marteau",
	"catabase_lame_sang": "lame",
	"catabase_javeline": "arc",
	"catabase_xiphos_danse": "xiphos",
	"catabase_masse_airain": "marteau",
	"catabase_fer_braise": "hampe",
}


static func weapon_for_item(id: String) -> String:
	if LEGACY_WEAPONS.has(id):
		return LEGACY_WEAPONS[id]
	var weapon := id.trim_prefix("catabase_ct_")
	return weapon if WEAPONS.has(weapon) else ""


static func preset(weapon: String) -> Dictionary:
	if not PRESETS.has(weapon):
		return { }
	var p: Array = PRESETS[weapon]
	return {
		"weapon": weapon,
		"armor": p[0],
		"techniques": [p[1], p[2]],
		"relic": p[3],
		"supply": p[4],
	}


static func valid(selection: Dictionary) -> bool:
	if (
		not WEAPONS.has(selection.get("weapon")) or not ARMORS.has(selection.get("armor")) \
				or not RELICS.has(selection.get("relic"))
		or not SUPPLIES.has(selection.get("supply"))
	):
		return false
	var techniques: Variant = selection.get("techniques")
	return (
		techniques is Array and techniques.size() == 2 and techniques[0] != techniques[1] \
				and techniques[0] in TECHNIQUES
		and techniques[1] in TECHNIQUES
	)


static func spell_ids(selection: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	if valid(selection):
		ids.assign([WEAPONS[selection.weapon][2], WEAPONS[selection.weapon][3]])
		for id in selection.techniques:
			ids.append(String(id))
	return ids


static func add_items(catalog) -> void:
	for id in WEAPONS:
		var row: Array = WEAPONS[id]
		var item: ItemDefinition = catalog._item(
			"ct_" + id,
			row[0],
			ItemDefinition.EquipmentSlot.WEAPON,
			[row[4]],
			row[1],
		)
		item.icon = choice_icon("weapon", id)
		item.inventory_icon = item.icon
		item.card_texture = null
		var mod := CatabaseCombatModifier.new()
		mod.mode = "weapon"
		mod.weapon_id = id
		item.spell_modifiers.append(mod)
	for id in ARMORS:
		var row: Array = ARMORS[id]
		var item: ItemDefinition = catalog._item(
			"ct_" + id,
			row[0],
			ItemDefinition.EquipmentSlot.ARMOR,
			["airain"],
			row[4],
		)
		item.icon = choice_icon("armor", id)
		item.inventory_icon = item.icon
		item.card_texture = null
		if int(row[1]) != 0:
			catalog._stat(item, &"armure", row[1])
		if int(row[2]) != 0:
			catalog._stat(item, &"resist_magique", row[2])
		if int(row[3]) > 0:
			catalog._stat(item, &"max_mp", row[3])


static func relic_items() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for id in RELICS:
		var row: Array = RELICS[id]
		var item := _relic("ct_relic_" + id, row[0], row[1])
		item.reactive_effects.append(
			_effect(&"ct_passive", int(row[2]), ItemReactiveEffectData.TRIGGER_COMBAT_START)
		)
		if id == "urne":
			item.reactive_effects.append(
				_effect(&"ct_bronze", 1, ItemReactiveEffectData.TRIGGER_SHIELD_ABSORPTION)
			)
		result.append(item)
	for id in SUPPLIES:
		var row: Array = SUPPLIES[id]
		var item := _relic("ct_supply_" + id, row[0], row[1])
		item.tags.append(&"ephemeral")
		item.reactive_effects.append(
			_effect(&"ct_supply", int(row[2]), ItemReactiveEffectData.TRIGGER_MANUAL_ACTIVATION)
		)
		result.append(item)
	return result


static func _relic(id: String, title: String, description: String) -> ItemDefinition:
	var item := ItemDefinition.new()
	item.item_id = StringName(id)
	item.display_name = title
	item.description = description
	item.category = ItemDefinition.Category.RELIC
	item.tags.assign([&"catabase_build"])
	item.icon = choice_icon(
		"relic" if id.begins_with("ct_relic_") else "supply",
		id.trim_prefix("ct_relic_").trim_prefix("ct_supply_"),
	)
	item.inventory_icon = item.icon
	return item


static func _effect(id: StringName, value: int, trigger: StringName) -> ItemReactiveEffectData:
	var effect := ItemReactiveEffectData.new()
	effect.result_id = id
	effect.value = value
	effect.trigger_id = trigger
	return effect


static func choice_icon(group: String, id: String) -> Texture2D:
	var path := "res://assets/catabase/preparation/%s_%s.svg" % [group, id]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
