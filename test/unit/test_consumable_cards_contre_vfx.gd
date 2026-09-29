extends "res://test/unit/test_consumable_cards_effects.gd"
const Player := preload("res://vfx/class_cards/contre/player.gd")
const Controller := preload("res://vfx/class_cards/contre/controller.gd")
var rigs: Array = []
const Turns := preload("res://core/expedition/consumable_card_turns.gd")


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
	host.units.assign(f.grid.get_units())
	var grid_view := GridView.new()
	host.add_child(grid_view)
	var manager: Node = load("res://core/vfx_manager.gd").new()
	add_child(manager)
	manager.register_battle_view(grid_view)
	var result := {
		"host": host,
		"manager": manager,
		"router": manager._class_card_router,
		"session": session,
	}
	rigs.append(result)
	return result


func after_each() -> void:
	for r in rigs:
		r.manager.unregister_battle_view()
		r.manager.free()
		r.host.free()
	rigs.clear()
	super.after_each()


func modes(router: Node, mode: String) -> Array:
	return router.effects.filter(
		func(fx):
			return is_instance_valid(fx) and not fx.closed and fx is Player and fx.mode == mode,
	)


func test_arm_once_and_only_the_actual_counter_emits_one_return_stroke() -> void:
	for upgraded in [false, true]:
		var f := field_for("gardien")
		if upgraded:
			f.cards.upgraded_ids.append("g05")
		f.cards.active_relics.append("mirror")
		var r := rig(f)
		var spell := force_hand(f, "g05")
		var report: Dictionary = f.caster.cast(f.hero, spell, f.hero.grid_pos)
		assert_false(report.get("failed", false))
		assert_eq(f.hero.current_ap, 2)
		assert_eq(modes(r.router, "arm").size(), 1)
		assert_eq(modes(r.router, "token").size(), 1)
		assert_eq(
			r.router.effects.size(),
			3,
			"Only assembly, counter token and shield badge; no large generic ward",
		)
		assert_true(Controller.active(f.hero))
		var guard: int = f.hero.current_shield
		r.router.resolve(f.hero, spell, report)
		assert_eq(modes(r.router, "arm").size(), 1, "No duplicate cast")
		watch_signals(EventBus)
		Effects.hit(f.hero, f.target, 5, false, "attack")
		assert_eq(
			modes(r.router, "riposte").size(),
			1,
			"Neither class passive nor mirror draws a counter",
		)
		assert_eq(modes(r.router, "token").size(), 0)
		assert_false(Controller.active(f.hero))
		assert_gt(f.hero.current_shield, 0, "Guard survives the spent counter")
		assert_lt(f.hero.current_shield, guard)
		var facts: Array = []
		for i in get_signal_emit_count(EventBus, "hit_resolved"):
			var fact: CombatEventFact = get_signal_parameters(EventBus, "hit_resolved", i)[0]
			if fact.status_id == &"cc2_counter" and fact.source == f.hero:
				facts.append(fact)
		assert_eq(facts.size(), 1)
		assert_eq(facts[0].attack_classification, &"cc2_indirect", "Damage policy unchanged")
		r.router._counter(facts[0])
		assert_eq(modes(r.router, "riposte").size(), 1, "Repeated fact cannot replay")
		Effects.hit(f.hero, f.target, 5, false, "attack")
		assert_eq(modes(r.router, "riposte").size(), 1, "Only one counter charge")


func test_distant_periodic_and_friendly_damage_do_not_fire_the_counter() -> void:
	var f := field_for("gardien")
	var r := rig(f)
	f.caster.cast(f.hero, force_hand(f, "g05"), f.hero.grid_pos)
	f.grid.relocate_unit(f.target, Vector2i(0, 0))
	Effects.hit(f.hero, f.target, 1, false, "attack")
	f.grid.relocate_unit(f.target, Vector2i(3, 3))
	Effects.hit(f.hero, f.target, 1, false, "periodic")
	Effects.hit(f.hero, f.hero, 1, false, "attack")
	assert_true(Controller.active(f.hero))
	assert_true(modes(r.router, "riposte").is_empty())
	assert_eq(modes(r.router, "token").size(), 1)


func test_quiet_restoration_then_expiry_without_an_invented_attack() -> void:
	var f := field_for("gardien")
	var r := rig(f)
	f.caster.cast(f.hero, force_hand(f, "g05"), f.hero.grid_pos)
	r.router.clear()
	r.router._restore_unit_holds()
	assert_true(modes(r.router, "arm").is_empty())
	assert_eq(modes(r.router, "token").size(), 1)
	var token: Node = modes(r.router, "token")[0]
	assert_eq(token.appear_after, 0.0)
	assert_true(token.sprites.token.visible)
	Turns.begin_hero(f.hero, f.cards, f.terrain, false)
	r.router._process(.16)
	assert_false(Controller.active(f.hero))
	assert_true(modes(r.router, "riposte").is_empty())
	assert_true(token.closed)
	assert_true(r.router.holds.has("%s:shield" % f.hero.get_instance_id()))


func test_absorbed_and_lethal_counter_keep_the_actual_contact_position() -> void:
	for lethal in [false, true]:
		var f := field_for("assassin")
		var r := rig(f)
		f.caster.cast(f.hero, force_hand(f, "g05"), f.hero.grid_pos)
		var destination: Vector2 = r.manager._grid_cell_global(f.target.grid_pos)
		if lethal:
			f.target.current_hp = 1
		else:
			f.target.add_shield(100)
		Effects.hit(f.hero, f.target, 1, false, "attack")
		assert_eq(modes(r.router, "riposte").size(), 1)
		var fx: Node = modes(r.router, "riposte")[0]
		assert_eq(fx.target, destination)
		assert_eq(f.target.is_alive, not lethal)
		var values := [
			f.hero.current_hp,
			f.hero.current_shield,
			f.target.current_hp,
			f.cards.snapshot(),
		]
		for time in [0.0, .0667, .2, .38]:
			fx.sample(time)
		assert_eq(
			[f.hero.current_hp, f.hero.current_shield, f.target.current_hp, f.cards.snapshot()],
			values,
		)
		assert_false(fx.sprites.contact.visible)
		assert_false(fx.sprites.slash.visible)


func test_passive_kills_first_or_hero_dies_without_a_false_counter() -> void:
	for hero_dies in [false, true]:
		var f := field_for("gardien")
		var r := rig(f)
		f.caster.cast(f.hero, force_hand(f, "g05"), f.hero.grid_pos)
		if not hero_dies:
			f.target.current_hp = 1
		Effects.hit(f.hero, f.target, 999 if hero_dies else 1, false, "attack")
		r.router._process(.16)
		assert_true(modes(r.router, "riposte").is_empty())
		assert_false(Controller.active(f.hero))
		assert_false(r.router.holds.has("%s:cc2_counter" % f.hero.get_instance_id()))


func test_invalid_cast_shutdown_and_other_battle_scope() -> void:
	var f := field_for("gardien")
	var r := rig(f)
	f.hero.current_ap = 0
	var spell := force_hand(f, "g05")
	var report: Dictionary = f.caster.cast(f.hero, spell, f.hero.grid_pos)
	r.router.resolve(f.hero, spell, report)
	assert_true(report.get("failed", false))
	assert_true(modes(r.router, "arm").is_empty())
	f.hero.current_ap = 4
	f.caster.cast(f.hero, spell, f.hero.grid_pos)
	r.router.clear(true)
	assert_true(r.router.effects.is_empty() and r.router.holds.is_empty())
	Effects.hit(f.hero, f.target, 1, false, "attack")
	assert_true(r.router.effects.is_empty())
	assert_false(Controller.handles({ "id": "g_counter" }))


func test_badge_overflow_is_compact_and_arm_and_contact_are_finite() -> void:
	var f := field_for("gardien")
	var r := rig(f)
	f.caster.cast(f.hero, force_hand(f, "g05"), f.hero.grid_pos)
	var token: Node = modes(r.router, "token")[0]
	token.set_status_slot(5, 8)
	assert_true(token.overflow.visible)
	assert_eq(token.overflow.text, "+3")
	assert_false(token.sprites.token.visible)
	token.set_status_slot(6, 8)
	assert_false(token.overflow.visible)
	var arm: Node = modes(r.router, "arm")[0]
	arm.sample(.48)
	assert_false(arm.sprites.arm.visible)
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(Player.ART + "provenance.json")
	)
	var poses := 0
	for id: String in manifest.assets:
		poses += int(manifest.assets[id].frames)
		assert_eq(FileAccess.get_sha256(Player.ART + id + ".png"), manifest.assets[id].sha256)
	assert_eq(poses, 32)
