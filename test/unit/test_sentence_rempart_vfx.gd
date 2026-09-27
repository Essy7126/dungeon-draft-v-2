extends GutTest
const Factory := preload("res://test/support/factory.gd")
const Cards := preload("res://core/expedition/class_card_catalog.gd")
const Player := preload("res://vfx/class_cards/sentence/hammer_player.gd")
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
	hero = Factory.make_unit("Sentence", 0)
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


func test_preparation_holds_before_contact_until_confirmed() -> void:
	var spell := Cards.make_spell("g_crash")
	var fx: Node = router.prepare_sentence(hero, spell, Vector2i(1, 0))
	assert_not_null(fx)
	fx.manual = true
	fx.sample(.6)
	assert_false(fx.confirmed)
	assert_eq(fx.sprites[0].frame, 14, "No contact pose before the resolved cast")
	var hp := hero.current_hp
	var ap := hero.current_ap
	router.resolve(
		hero,
		spell,
		{ "action_id": "sentence-hit", "visual_impact_cells": [Vector2i(1, 0)] },
	)
	assert_true(fx.confirmed)
	assert_eq(fx.sprites[0].frame, 15)
	assert_true(router.sentence_preparations.is_empty())
	assert_eq(router.effects.size(), 1, "Confirmation reuses the prepared hammer")
	assert_eq([hero.current_hp, hero.current_ap], [hp, ap])
	router.resolve(
		hero,
		spell,
		{ "action_id": "sentence-hit", "visual_impact_cells": [Vector2i(1, 0)] },
	)
	assert_eq(router.effects.size(), 1, "Repeated report does not double the impact")
	var next: Node = router.prepare_sentence(hero, spell, Vector2i(1, 0))
	next.manual = true
	router.resolve(
		hero,
		spell,
		{ "action_id": "sentence-hit", "visual_impact_cells": [Vector2i(1, 0)] },
	)
	assert_eq(
		router.sentence_preparations.get(hero),
		next,
		"Old duplicate cannot steal a new preparation",
	)
	assert_false(next.confirmed)


func test_failed_and_missed_casts_cancel_without_contact() -> void:
	var spell := Cards.make_spell("g_crash")
	for report in [{ "failed": true }, { "visual_impact_cells": [] }]:
		var fx: Node = router.prepare_sentence(hero, spell, Vector2i(1, 0))
		fx.manual = true
		router.resolve(hero, spell, report)
		assert_true(fx.closed)
		assert_false(fx.confirmed)
		assert_true(router.sentence_preparations.is_empty())


func test_direct_cast_starts_at_contact_and_classic_has_no_preparation() -> void:
	var spell := Cards.make_spell("g_crash")
	router.resolve(hero, spell, { "visual_impact_cells": [Vector2i(1, 0)] })
	assert_eq(router.effects.size(), 1)
	var fx: Node = router.effects[0]
	assert_eq(fx.get_script(), Player)
	assert_true(fx.confirmed)
	assert_eq(fx.sprites[0].frame, 15, "No late windup after an immediate cast")
	assert_true(router.echoes.is_empty())
	router.clear()
	session.cards = null
	assert_null(router.prepare_sentence(hero, spell, Vector2i(1, 0)))
	assert_true(router.effects.is_empty())


func test_closing_cancels_preparation_and_other_cards_use_existing_reader() -> void:
	assert_null(router.prepare_sentence(hero, Cards.make_spell("g_hit"), Vector2i(1, 0)))
	var fx: Node = router.prepare_sentence(hero, Cards.make_spell("g_crash"), Vector2i(1, 0))
	router.clear(true)
	assert_true(fx.closed)
	assert_false(fx.confirmed)
	assert_true(router.sentence_preparations.is_empty())


func test_export_has_all_poses_and_transparent_margin() -> void:
	var atlas := load(Player.ART) as Texture2D
	assert_eq(atlas.get_size(), Vector2(3072, 2304))
	var data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://vfx/class_cards/sentence/provenance.json")
	)
	assert_eq(data.rendered_frames.size(), 48)
	assert_eq(data.contact_frame, 16.0)
	assert_eq(FileAccess.get_sha256(Player.ART), data.atlas_sha256)


func test_cancelled_preparation_cannot_leave_a_freed_reference_for_the_next_cast() -> void:
	var spell := Cards.make_spell("g_crash")
	var fx: Node = router.prepare_sentence(hero, spell, Vector2i(1, 0))
	fx.cancel()
	assert_true(router.sentence_preparations.is_empty())
	await get_tree().process_frame
	var next: Node = router.prepare_sentence(hero, spell, Vector2i(1, 0))
	assert_not_null(next)
	assert_false(next.closed)
