extends RefCounted
## Read-only projection of the committed reward, never of the current bag.
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Icons := preload("res://core/expedition/class_icon_catalog.gd")
const Spells := preload("res://core/expedition/consumable_card_spells.gd")
const Presenter := preload("res://ui/expedition/consumable_cards_presenter.gd")
const RARITY_NAMES := {
	"normal": "Normale",
	"elite": "Élite",
	"rare": "Rare",
	"legendary": "Légendaire",
	"god": "Divine",
	"immortal": "Immortelle",
}
const COLORS := {
	"normal": "b8c8b5",
	"elite": "75d9ac",
	"rare": "78bfee",
	"legendary": "ddb776",
	"god": "c29aef",
	"immortal": "f0b5bb",
}
const ITEM_ART := {
	"w_blade": "weapon_lame",
	"w_bow": "weapon_arc",
	"w_staff": "weapon_hampe",
	"b_leather": "armor_legere",
	"b_plate": "armor_airain",
	"b_robe": "armor_sceau",
	"h_watch": "gear_3_0",
	"h_bronze": "gear_3_1",
	"h_sage": "gear_3_3",
	"f_quick": "gear_5_0",
	"f_brace": "gear_5_1",
	"f_flow": "gear_5_2",
	"s_life": "gear_4_0",
	"s_care": "gear_4_2",
	"s_guard": "gear_4_1",
	"j_cup": "gear_2_0",
	"j_shard": "gear_2_3",
	"j_eye": "gear_2_2",
	"thread": "relic_fil",
	"bronze": "relic_urne",
	"embers": "relic_meche",
	"obole": "relic_obole",
	"archive": "relic_clou",
	"mirror": "armor_airain",
	"cup": "relic_coupe",
	"seal": "class_rune_stone",
}


static func encounter_index(session) -> int:
	var current: Dictionary = session.route.get_current_node()
	var index := 1
	for node in session.route.nodes:
		if (
			str(node.id) in session.route.completed_node_ids
			and int(node.depth) < int(current.depth)
			and ExpeditionRouteCatalog.is_combat(str(node.kind))
		):
			index += 1
	return index


static func commitment(session) -> Dictionary:
	var index := encounter_index(session)
	# JSON catalogue numbers stringify as "1.0"; older/manual states may use "1".
	for key in session.cards.loot_commitments:
		if str(key).is_valid_float() and int(float(str(key))) == index:
			return session.cards.loot_commitments[key]
	return { }


static func records_for(session) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var groups := { }
	var receipt: Dictionary = session.cards.battle_results.get(
		str(session.route.current_node_id),
		{ },
	)
	for family in receipt.get("card_families", []):
		var key := "card:" + str(family)
		if not groups.has(key):
			groups[key] = card_record(str(family), str(family) in session.cards.upgraded_ids)
		groups[key].count += 1
	# The final encounter grants no items. Commitments may still exist for it.
	if encounter_index(session) < 12:
		for drop in commitment(session).values():
			if drop.get("forfeited", false):
				continue
			for kind in ["equipment", "relics"]:
				for id in drop.get(kind, []):
					var key: String = str(kind) + ":" + str(id)
					if not groups.has(key):
						groups[key] = item_record(str(id), kind)
					groups[key].count += 1
	for record in groups.values():
		result.append(record)
	return result


static func card_record(id: String, upgraded := false) -> Dictionary:
	var row := Catalog.card(id, upgraded)
	var spell: Spell = Spells.make_spell(id, upgraded)
	return {
		"id": id,
		"kind": "card",
		"title": row.name,
		"icon": spell.icon,
		"rarity": row.rarity,
		"category": "Toutes classes" if row.affinity == "shared" else str(row.affinity).capitalize(),
		"body": preload("res://ui/expedition/consumable_card_description.gd").full_text(row, upgraded),
		"upgraded": upgraded,
		"row": row,
		"count": 0,
	}


static func item_record(id: String, kind: String) -> Dictionary:
	var row := Presenter.item(id)
	return {
		"id": id,
		"kind": kind,
		"title": row.get("name", id),
		"icon": Icons.icon(ITEM_ART.get(id, "relic_obole")),
		"rarity": "normal",
		"category": (
			"Relique"
			if kind == "relics"
			else "%s · palier %d" % [Presenter.SLOTS.get(row.get("slot", ""), "Équipement"), int(
					row.get("tier", 1)
				)]
		),
		"body": Presenter.item_text(row),
		"count": 0,
	}
