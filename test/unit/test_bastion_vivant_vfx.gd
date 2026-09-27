extends GutTest
const Factory := preload("res://test/support/factory.gd")
const Cards := preload("res://core/expedition/class_card_catalog.gd")
const Player := preload("res://vfx/class_cards/bastion/bastion_player.gd")
var manager: Node
var host: Node2D
var session: ExpeditionSession
var hero: Unit
var router: Node


class Host:
	extends Node2D
	var units: Array = []


class GridView:
	extends Node2D
	func grid_to_local(cell: Vector2i) -> Vector2:
		return Vector2((cell.x - cell.y) * 64, (cell.x + cell.y) * 32)


func before_each() -> void:
	manager = load("res://core/vfx_manager.gd").new()
	add_child(manager)
	host = Host.new()
	add_child(host)
	session = ExpeditionSession.new()
	session.character = CharacterRunState.new()
	session.cards = preload("res://core/expedition/class_cards.gd").new()
	session.cards.bind(session)
	hero = Factory.make_unit("Bastion", 0)
	hero.set_meta("ct_session", weakref(session))
	session.character.unit = hero
	host.units.append(hero)
	var view := GridView.new()
	host.add_child(view)
	manager.register_battle_view(view)
	router = manager._class_card_router


func after_each() -> void:
	manager.unregister_battle_view()
	manager.queue_free()
	hero.clear_combat_effect_history()
	host.units.clear()
	host.queue_free()
	hero = null
	session = null
	await get_tree().process_frame


func _grant() -> void:
	hero.add_sourced_shield(
		Player.SOURCE_ID,
		30,
		hero,
		{ "ability_id": Player.SOURCE_ID, "expires_after_activations": 1 },
	)


func _live(phase: String) -> Array:
	return router.effects.filter(
		func(fx):
			return (
				is_instance_valid(fx) and not fx.closed and fx is Player
				and not fx.persistent and fx.phase == phase
			),
	)


func test_only_confirmed_bastion_deploys_and_refresh_replaces_it() -> void:
	var spell := Cards.make_spell("g_bastion")
	router.resolve(hero, spell, { "failed": true, "shield_increase_total": 30 })
	assert_true(_live("").is_empty())
	router.resolve(hero, spell, { "action_id": "no-grant", "shield_increase_total": 0 })
	assert_true(_live("").is_empty())
	_grant()
	router.resolve(hero, spell, { "action_id": "grant", "shield_increase_total": 30 })
	assert_eq(_live("").size(), 1)
	var before := [hero.current_shield, hero.current_hp, hero.current_ap]
	_live("")[0].manual = true
	_live("")[0].sample(.4)
	assert_eq([hero.current_shield, hero.current_hp, hero.current_ap], before)
	router.resolve(hero, spell, { "action_id": "grant", "shield_increase_total": 30 })
	assert_eq(_live("").size(), 1, "Duplicate report does not repeat deployment")
	router.resolve(hero, spell, { "action_id": "refresh", "shield_increase_total": 10 })
	assert_eq(_live("").size(), 1, "Refresh replaces rather than stacks the large walls")
	router.clear()
	session.cards = null
	router.resolve(hero, spell, { "shield_increase_total": 30 })
	assert_true(router.effects.is_empty(), "Classic is excluded")


func test_source_expiry_returns_to_generic_when_other_shield_remains() -> void:
	_grant()
	var key := "%s:shield" % hero.get_instance_id()
	assert_true(router.holds[key].fx is Player)
	hero.add_sourced_shield(&"other-shield", 20)
	assert_eq(router.holds.size(), 1, "One shield slot for stacked sources")
	hero.start_turn()
	router._process(.2)
	assert_eq(hero.get_shield_value(Player.SOURCE_ID), 0)
	assert_eq(hero.current_shield, 20)
	assert_eq(router.holds.size(), 1)
	assert_false(
		router.holds[key].fx is Player,
		"Expired Bastion cannot borrow another shield's lifetime",
	)
	assert_true(_live("expire").is_empty(), "Replacement keeps a single readable sign")
	hero.clear_shield()
	router.clear()
	_grant()
	hero.start_turn()
	router._process(.2)
	assert_true(router.holds.is_empty())
	assert_eq(_live("expire").size(), 1, "Final guard expiry still has its compact release")


func test_absorption_selects_the_source_that_actually_paid() -> void:
	_grant()
	var fact := CombatEventFact.create(
		&"shield_absorbed",
		hero,
		null,
		{
			"amount_absorbed": 4,
			"source_absorption": [{ "source_id": &"other-shield", "amount_absorbed": 4 }],
			"broken_source_ids": [&"other-shield"],
		},
	)
	router._absorb(fact)
	assert_true(_live("break").is_empty(), "An unrelated break cannot shatter Bastion")
	fact.source_absorption = [{ "source_id": Player.SOURCE_ID, "amount_absorbed": 4 }]
	fact.broken_source_ids.clear()
	router._absorb(fact)
	assert_eq(_live("absorb").size(), 1)
	router._absorb(fact)
	assert_eq(
		_live("absorb").size(),
		1,
		"Rapid hits replace the feedback instead of piling shields",
	)
	hero.clear_shield_source(Player.SOURCE_ID)
	fact.broken_source_ids.assign([Player.SOURCE_ID])
	router._absorb(fact)
	assert_eq(_live("break").size(), 1)
	assert_true(router.holds.is_empty())
	router._process(.2)
	assert_true(_live("expire").is_empty(), "Break does not add another expiration burst")


func test_restore_and_overflow_keep_one_readable_source_scoped_sign() -> void:
	_grant()
	router.clear()
	router._restore_unit_holds()
	var key := "%s:shield" % hero.get_instance_id()
	var held: Node = router.holds[key].fx
	assert_true(held is Player)
	held.manual = true
	held.set_status_slot(5, 8)
	held.sample(60)
	assert_eq(
		hero.get_shield_value(Player.SOURCE_ID),
		30,
		"Presentation seconds never consume activation duration",
	)
	assert_eq(router.holds.size(), 1)
	assert_true(_live("").is_empty(), "Restoring a hold never repeats deployment")
	router.clear(true)
	assert_true(held.closed)


func test_layered_export_has_all_frames_and_verified_hashes() -> void:
	var data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(Player.ATLAS + "provenance.json")
	)
	assert_eq(data.frames, 48.0)
	for layer in ["back", "front"]:
		var texture := load(Player.ATLAS + layer + ".png") as Texture2D
		assert_eq(texture.get_size(), Vector2(3072, 2304))
		assert_eq(data.exports[layer].frames.size(), 48)
		assert_eq(FileAccess.get_sha256(Player.ATLAS + layer + ".png"), data.exports[layer].sha256)
