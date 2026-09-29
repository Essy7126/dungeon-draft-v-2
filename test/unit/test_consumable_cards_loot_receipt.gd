extends GutTest
const Receipt := preload("res://ui/expedition/consumable_loot_receipt.gd")
const Results := preload("res://ui/expedition/consumable_combat_results.gd")
const Tile := preload("res://ui/expedition/consumable_loot_tile.gd")
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
var manager


class Manager:
	extends "res://core/game_manager.gd"
	func _request_scene_change(
		_path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		pass


	func start_next_battle() -> void:
		pass


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


func before_each() -> void:
	manager = Manager.new()
	add_child(manager)
	manager.select_run_variant("cards")
	manager.expedition_save_path = "user://loot_receipt_test_%d.json" % Time.get_ticks_usec()
	assert_true(manager.start_expedition(33, { }, false, true, "normal", true))


func after_each() -> void:
	ExpeditionSaveService.remove_snapshot(manager.expedition_save_path)
	manager.cleanup_run_state()
	manager.free()


func fixture() -> void:
	var encounter := preload("res://core/expedition/consumable_cards_integration.gd").encounter(
		manager.expedition
	)
	manager.expedition.cards.loot_commitments[str(encounter.index)] = {
		"enemy_a": {
			"cards": ["n01", "n01", "a01"],
			"equipment": ["w_blade"],
			"relics": ["thread"],
			"bags": [],
		},
		"enemy_b": {
			"cards": ["n02"],
			"equipment": ["w_bow"],
			"relics": ["cup"],
			"bags": [],
			"forfeited": true,
		},
	}
	assert_true(manager.expedition.combat_won())


func identities(session) -> Array:
	return Receipt.records_for(session).map(
		func(row):
			return [row.id, row.kind, row.count],
	)


func test_receipt_groups_cards_includes_items_and_excludes_forfeited_loot() -> void:
	fixture()
	assert_eq(
		Receipt.encounter_index(manager.expedition),
		1,
		"Completed current node is not the next encounter",
	)
	assert_eq(
		identities(manager.expedition),
		[
			["n01", "card", 2],
			["a01", "card", 1],
			["w_blade", "equipment", 1],
			["thread", "relics", 1],
		],
	)
	assert_true(manager.expedition.has_class_combat_receipt())
	assert_true(manager.expedition.acknowledge_combat_receipt().success)
	assert_true(manager.expedition.class_combat_receipt_reviewed())
	assert_false(
		manager.expedition.advancement_step.is_empty(),
		"Level follows acknowledgement of the loot",
	)


func test_receipt_survives_sale_consumption_and_snapshot_restore() -> void:
	fixture()
	var expected := identities(manager.expedition)
	var economy = preload("res://core/expedition/consumable_card_economy.gd")
	var cards = manager.expedition.cards
	economy.market(cards, "receipt_test", 1)
	assert_true(economy.transact(cards, "receipt_test", {
			"id": "sale",
			"kind": "sell",
			"copies": [cards.last_drops[0]],
		}).success)
	manager.expedition.gold = cards.gold
	assert_eq(
		identities(manager.expedition),
		expected,
		"Selling a received copy does not edit the receipt",
	)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))
	assert_true(manager.restore_expedition_snapshot(snapshot))
	assert_eq(identities(manager.expedition), expected)
	# Simulate inventory disappearance: receipt projection must not read any of it.
	manager.expedition.cards.copies.clear()
	manager.expedition.cards.equipment_copies.clear()
	manager.expedition.cards.owned_relics.clear()
	manager.expedition.cards.last_drops.clear()
	assert_eq(identities(manager.expedition), expected)


func test_latest_loot_remains_findable_after_leaving_the_reward_node() -> void:
	assert_true(Receipt.latest_records(manager.expedition).is_empty())
	fixture()
	var expected := Receipt.latest_records(manager.expedition).map(
		func(row):
			return [row.id, row.kind, row.count],
	)
	var previous: String = manager.expedition.route.current_node_id
	for node in manager.expedition.route.nodes:
		if str(node.id) != previous:
			manager.expedition.route.current_node_id = str(node.id)
			break
	var before: Dictionary = manager.get_expedition_snapshot()
	assert_eq(
		Receipt.latest_records(manager.expedition).map(
			func(row):
				return [row.id, row.kind, row.count],
		),
		expected,
	)
	assert_eq(
		manager.get_expedition_snapshot(),
		before,
		"inspection never moves the route or edits rewards",
	)
	# Simulate inventory disappearance: receipt projection must not read any of it.
	manager.expedition.cards.copies.clear()
	manager.expedition.cards.equipment_copies.clear()
	manager.expedition.cards.owned_relics.clear()
	manager.expedition.cards.last_drops.clear()
	assert_eq(
		Receipt.latest_records(manager.expedition).map(
			func(row):
				return [row.id, row.kind, row.count],
		),
		expected,
	)


func test_all_card_and_item_definitions_have_art_and_complete_effect_text() -> void:
	var rarities := { }
	for row in Catalog.data().cards:
		var record := Receipt.card_record(row.id)
		assert_not_null(record.icon, str(row.id))
		assert_eq(record.body, row.baseText)
		var upgraded := Receipt.card_record(row.id, true)
		if (
			str(row.upgradeText).begins_with("Effet de base")
			or str(row.upgradeText).begins_with("Même ")
		):
			assert_string_contains(
				upgraded.body,
				str(row.baseText).get_slice(";", 0).strip_edges(),
				"upgraded drops retain their primary action",
			)
			assert_false(str(upgraded.body).begins_with("Effet de base"))
			assert_false(str(upgraded.body).begins_with("Même "))
		else:
			assert_eq(upgraded.body, row.upgradeText)
		assert_eq(upgraded.row.ap, Catalog.card(row.id, true).ap)
		assert_true(Receipt.RARITY_NAMES.has(record.rarity))
		rarities[record.rarity] = true
		var detail := Tile.detail(record, manager.expedition.character.unit)
		assert_eq(detail.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_not_null(detail.find_child("LootEffects", true, false))
		detail.free()
	assert_eq(rarities.size(), 6)
	fixture()
	manager.expedition.cards.upgraded_ids.append("n01")
	var received := Receipt.records_for(manager.expedition)[0]
	assert_eq(
		received.body,
		Catalog.card("n01").upgradeText,
		"New copy inherits its family's improvement",
	)
	assert_eq(received.count, 2)
	for kind in ["equipment", "relics"]:
		for row in Catalog.data()[kind]:
			assert_not_null(Receipt.item_record(row.id, kind).icon, str(row.id))


func test_hover_is_passive_and_does_not_change_rewards() -> void:
	fixture()
	var view := Results.new()
	view.session = manager.expedition
	view.size = Vector2(1000, 450)
	add_child(view)
	await wait_process_frames(3)
	var tile = view.find_child("LootReceipt_n01", true, false)
	assert_not_null(tile)
	var before: Dictionary = manager.get_expedition_snapshot()
	tile.mouse_entered.emit()
	await wait_process_frames(3)
	assert_true(is_instance_valid(view._preview))
	assert_eq(view._preview.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(manager.get_expedition_snapshot(), before)
	tile.mouse_exited.emit()
	assert_null(view._preview)
	view.free()
