extends "res://test/unit/test_consumable_cards_effects.gd"
const Player := preload("res://vfx/class_cards/braise/player.gd")
const Controller := preload("res://vfx/class_cards/braise/controller.gd")
const Steam := preload("res://vfx/class_cards/braise/steam.gd")
const Turns := preload("res://core/expedition/consumable_card_turns.gd")
const Terrain := preload("res://core/expedition/consumable_card_terrain.gd")
var rigs: Array = []


class Host:
	extends Node2D
	var units: Array = []


class GridView:
	extends Node2D
	func grid_to_local(cell: Vector2i) -> Vector2:
		return Vector2((cell.x - cell.y) * 64, (cell.x + cell.y) * 32)


func rig(f: Dictionary) -> Dictionary:
	var session := ExpeditionSession.new()
	session.cards = f.cards
	f.hero.set_meta("ct_session", weakref(session))
	var host := Host.new()
	add_child(host)
	host.units.assign([f.hero, f.target])
	var grid_view := GridView.new()
	host.add_child(grid_view)
	var manager: Node = load("res://core/vfx_manager.gd").new()
	add_child(manager)
	manager.register_battle_view(grid_view)
	var router: Node = manager._class_card_router
	router.bind_terrain(f.terrain)
	var result := { "host": host, "manager": manager, "router": router, "session": session }
	rigs.append(result)
	return result


func after_each() -> void:
	for r in rigs:
		r.manager.unregister_battle_view()
		r.manager.free()
		r.host.free()
	rigs.clear()
	super.after_each()


func test_cast_preserves_real_payload_and_two_periodic_activations() -> void:
	var f := field_for("thaumaturge")
	var cell: Vector2i = f.target.grid_pos
	var report: Dictionary = f.caster.cast(f.hero, force_hand(f, "t02"), cell)
	assert_false(report.get("failed", false))
	assert_eq(report.card_vfx.targets[0].cell, cell)
	assert_eq(f.target.current_hp, 490)
	assert_eq(f.hero.current_ap, 2)
	assert_eq(Effects.states(f.target).burn.duration, 2)
	assert_almost_eq(Effects.states(f.target).burn.amount, 3.24, .0001)
	assert_true(f.terrain.active_surface_cells().is_empty(), "Dry ground never becomes fire")
	var ticks: Array = []
	var record := func(fact):
		ticks.append(fact)
	EventBus.status_tick.connect(record)
	Turns.apply_activation_statuses(f.target, f.grid)
	assert_eq(f.target.current_hp, 487)
	assert_eq(Effects.states(f.target).burn.duration, 1)
	Turns.apply_activation_statuses(f.target, f.grid)
	assert_eq(f.target.current_hp, 484)
	assert_false(Effects.states(f.target).has("burn"))
	Turns.apply_activation_statuses(f.target, f.grid)
	assert_eq(ticks.size(), 2, "No third pulse after expiration")
	for fact in ticks:
		assert_eq(fact.status_id, &"cc2_burn")
		assert_eq(fact.attack_classification, &"cc2_periodic")
		assert_true(fact.is_periodic)
		assert_eq(fact.amount_applied, 3)
		var settings := preload("res://battle/combat_feedback/combat_feedback_settings.tres")
		var payload := FloatingCombatText.describe_fact(fact, settings.style_for_fact(fact))
		assert_eq(payload.detail_text, "Brûlure")
		assert_eq(payload.style_id, "damage_cc2_burn")
	EventBus.status_tick.disconnect(record)


func test_one_restored_sign_and_only_burn_damage_pulses_it() -> void:
	var f := field_for("thaumaturge")
	var r := rig(f)
	Effects.apply_state(f.target, "burn", 3.24, 2, f.hero)
	r.router._restore_unit_holds()
	var key := "%s:cc2_burn" % f.target.get_instance_id()
	var held: Node = r.router.holds[key].fx
	assert_true(held.persistent)
	assert_gt(held.pulse_age, 1.0, "Restoration is quiet")
	Effects.apply_state(f.target, "burn", 2.0, 1, f.hero)
	r.router._restore_unit_holds()
	assert_same(r.router.holds[key].fx, held)
	assert_eq(r.router.holds.size(), 1)
	assert_almost_eq(Effects.states(f.target).burn.amount, 3.24, .0001)
	Effects.hit(f.target, f.hero, 2.0, true, "periodic")
	assert_gt(held.pulse_age, 1.0, "Fire terrain is not a burn tick")
	Effects.apply_state(f.target, "bleed", 2.0, 1, f.hero)
	Turns.apply_activation_statuses(f.target, f.grid)
	assert_eq(held.pulse_age, 0.0)
	assert_eq(Effects.states(f.target).burn.duration, 1)
	Turns.apply_activation_statuses(f.target, f.grid)
	r.router._process(.16)
	assert_false(r.router.holds.has(key))
	assert_true(held.closed)
	var release: Node = r.router.effects.back()
	assert_false(release.persistent)
	assert_eq(release.pulse_age, 0.0, "The last real tick continues during the sign's release")
	assert_eq(release.sprites.ember.frame, 1)
	Effects.apply_state(f.target, "burn", 2.0, 2, f.hero)
	r.router._restore_unit_holds()
	Effects.hit(f.target, f.hero, 1000)
	assert_false(r.router.holds.has(key), "Death removes the sign immediately")


func test_preparation_cancel_and_confirmed_hit_never_duplicate_projectiles() -> void:
	var f := field_for("thaumaturge")
	var r := rig(f)
	var spell := force_hand(f, "t02")
	var fx: Node = r.router.prepare_sentence(f.hero, spell, f.target.grid_pos)
	fx.manual = true
	fx.sample(.9)
	assert_false(fx.sprites.impact.visible)
	assert_lt(fx._clock, Player.CONTACT)
	r.router.resolve(f.hero, spell, { "failed": true })
	assert_true(fx.closed)
	assert_eq(f.hero.current_ap, 4)
	fx = r.router.prepare_sentence(f.hero, spell, f.target.grid_pos)
	fx.manual = true
	var report: Dictionary = f.caster.cast(f.hero, spell, f.target.grid_pos)
	assert_true(fx.confirmed)
	assert_true(fx.sprites.impact.visible)
	assert_false(fx.sprites.coal.visible)
	var count: int = r.router.effects.size()
	r.router.resolve(f.hero, spell, report)
	assert_eq(r.router.effects.size(), count, "Duplicate report does not replay")
	assert_true(r.router.flights.is_empty() and r.router.echoes.is_empty())
	fx.sample(.71)
	assert_false(fx.sprites.impact.visible)


func test_lethal_impact_keeps_original_cell_without_burn_hold() -> void:
	var f := field_for("thaumaturge")
	var r := rig(f)
	f.target.current_hp = 1
	var cell: Vector2i = f.target.grid_pos
	var report: Dictionary = f.caster.cast(f.hero, force_hand(f, "t02"), cell)
	assert_false(f.target.is_alive)
	assert_eq(report.card_vfx.targets[0].cell, cell)
	assert_true(
		r.router.holds.keys().filter(
			func(k):
				return "cc2_burn" in k,
		).is_empty()
	)
	var bursts: Array = r.router.effects.filter(
		func(fx):
			return is_instance_valid(fx) and fx is Player and not fx.badge_mode,
	)
	assert_eq(bursts.size(), 1)
	assert_eq(bursts[0].point, r.manager._grid_cell_global(cell))


func test_dynamic_water_steam_lifetime_and_saved_visual_identity() -> void:
	for upgraded in [false, true]:
		var f := field_for("thaumaturge")
		var r := rig(f)
		if upgraded:
			f.cards.upgraded_ids.append("t02")
		var cell: Vector2i = f.target.grid_pos
		var placed: Dictionary = f.terrain.place_effect(
			cell,
			Terrain.effect("water", 2),
			f.hero,
			null,
			2,
		)
		assert_true(placed.changed)
		f.caster.cast(f.hero, force_hand(f, "t02"), cell)
		var state: CellSurfaceState = f.terrain.get_surface_state(cell)
		assert_eq(state.surface_id, &"steam")
		assert_eq(state.remaining_duration, 2 if upgraded else 1)
		assert_eq(state.gameplay_flags.cc2_vfx, "braise_steam")
		assert_true(r.router.surface_holds[cell] is Steam)
		var held: Node = r.router.surface_holds[cell]
		assert_true(Controller.active(f.target), "Burn and steam have separate lifetimes")
		state.source_spell = null
		r.router.bind_terrain(null)
		r.router.bind_terrain(f.terrain)
		assert_true(r.router.surface_holds[cell] is Steam, "Saved flags restore the same style")
		assert_eq(r.router.surface_holds[cell].sprite.frame, 9, "No reaction replay on restore")
		for _turn in (2 if upgraded else 1):
			f.terrain.tick_all_effects()
		assert_false(r.router.surface_holds.has(cell))
		assert_true(Controller.active(f.target), "Surface expiration does not clear the burn")
		assert_true(held.closed)


func test_blocked_damage_does_not_invent_a_periodic_flare() -> void:
	var f := field_for("thaumaturge")
	var r := rig(f)
	Effects.apply_state(f.target, "burn", 3.24, 2, f.hero)
	f.target.add_shield(20)
	r.router._restore_unit_holds()
	var held: Node = r.router.holds["%s:cc2_burn" % f.target.get_instance_id()].fx
	var hp: int = f.target.current_hp
	Turns.apply_activation_statuses(f.target, f.grid)
	assert_eq(f.target.current_hp, hp)
	assert_gt(held.pulse_age, 1.0)
	assert_eq(Effects.states(f.target).burn.duration, 1)


func test_compact_badge_overflow_and_no_actor_mutation() -> void:
	var anchor := Node2D.new()
	add_child(anchor)
	anchor.position = Vector2(80, 100)
	anchor.scale = Vector2(1.2, .8)
	var fx := Player.new()
	add_child(fx)
	fx.configure({ "braise_badge": true }, anchor.position, 128, anchor, true)
	fx.set_status_slot(5, 8)
	assert_false(fx.sprites.ember.visible)
	assert_true(fx.overflow.visible)
	assert_eq(fx.overflow.text, "+3")
	fx.set_status_slot(1, 3)
	assert_true(fx.sprites.ember.visible)
	assert_false(fx.overflow.visible)
	fx.cancel()
	assert_eq(anchor.position, Vector2(80, 100))
	assert_eq(anchor.scale, Vector2(1.2, .8))
	assert_true(anchor.visible)
	anchor.queue_free()
	await wait_process_frames(1)


func test_all_original_atlases_match_their_export_manifest() -> void:
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(Player.ART + "provenance.json")
	)
	var count := 0
	for id in manifest.assets:
		var asset: Dictionary = manifest.assets[id]
		assert_eq(FileAccess.get_sha256(Player.ART + id + ".png"), asset.sha256)
		count += int(asset.frames)
	assert_eq(count, 39)
	assert_eq(manifest.assets.size(), 4)
