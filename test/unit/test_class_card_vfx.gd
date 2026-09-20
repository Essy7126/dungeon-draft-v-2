extends GutTest
const Catalog := preload("res://vfx/class_cards/class_card_vfx_catalog.gd")
const Player := preload("res://vfx/class_cards/class_card_vfx_player.gd")
const Factory := preload("res://test/support/factory.gd")
const Cleanup := preload("res://test/support/isolated_battlefield_cleanup.gd")
const Cards := preload("res://core/expedition/class_cards.gd")
var manager: Node
var view: Node2D
var host: BattleHost
var session: ExpeditionSession


class BattleHost:
	extends Node2D
	var units: Array = []


func _unit(p_name := "Testeur", team := 0) -> Unit:
	var unit := Factory.make_unit(p_name, team)
	host.units.append(unit)
	if team == 0:
		unit.set_meta("ct_session", weakref(session))
		session.character.unit = unit
	return unit


class GridView:
	extends Node2D
	func grid_to_local(cell: Vector2i) -> Vector2:
		return Vector2((cell.x - cell.y) * 64, (cell.x + cell.y) * 32)


class UnitAnchor:
	extends Node2D
	var unit: Unit


func before_each() -> void:
	manager = load("res://core/vfx_manager.gd").new()
	add_child(manager)
	host = BattleHost.new()
	add_child(host)
	session = ExpeditionSession.new()
	session.character = CharacterRunState.new()
	session.cards = Cards.new()
	session.cards.bind(session)
	_unit("Session témoin")
	view = GridView.new()
	host.add_child(view)
	manager.register_battle_view(view)
	manager._class_card_router.set_process(false)


func after_each() -> void:
	manager.unregister_battle_view()
	manager.queue_free()
	for unit in host.units:
		unit.clear_combat_effect_history()
	host.units.clear()
	host.queue_free()
	session = null
	await get_tree().process_frame


func test_every_current_card_and_basic_gesture_has_a_real_animation() -> void:
	var coverage := Catalog.coverage()
	assert_gte(coverage.cards, 112)
	assert_eq(coverage.missing, [])
	for id in Catalog.Cards.pool() + ["basic_strike", "basic_guard"]:
		var entry := Catalog.recipe(id)
		assert_false(entry.is_empty(), id)
		assert_has(Catalog.FAMILIES, entry.family, id)
		assert_has(Catalog.PALETTES, entry.family, id)
	for family in Catalog.FAMILIES:
		var fx := Player.new()
		view.add_child(fx)
		fx.configure(Catalog.feedback(family), Vector2.ZERO, 150)
		fx.manual = true
		fx.sample(.2)
		assert_eq(fx.sprites.size(), 2, family)
		assert_not_null(fx.sprites[0].material.shader, family)
		fx.cancel()
	assert_true(Catalog.recipe("not_a_card").is_empty())


func test_real_casts_cover_entire_live_catalogue_without_changing_rules() -> void:
	for id in Catalog.Cards.pool():
		var field = Factory.make_battlefield(12, 8)
		var hero := _unit()
		var enemy := _unit("Cible", 1)
		var spell := Catalog.Cards.make_spell(id)
		session.cards.hand.assign([session.cards.add_copy(id)])
		var entry := Catalog.recipe(id)
		field.grid.place_unit(hero, Vector2i(3, 3))
		var cell := Vector2i(3 + maxi(1, spell.minimum_range), 3)
		field.grid.place_unit(
			enemy,
			Vector2i(9, 3) if entry.movement or entry.effect == "guard" else cell,
		)
		if entry.effect == "guard":
			cell = hero.grid_pos
		if entry.effect == "stasis":
			enemy.apply_status(Catalog.Cards.status("marked", "Marqué", 2), hero)
		manager._class_card_router.clear()
		var report: Dictionary = field.caster.cast(hero, spell, cell)
		assert_false(report.get("failed", false), id + ": " + str(report.get("reason", "")))
		assert_gt(manager._class_card_router.effects.size(), 0, id)
		manager._class_card_router._process(.2)
		for unit: Unit in [hero, enemy]:
			for state in unit.get_active_statuses():
				var status_id := str(state.data.get_effective_status_id())
				var key := "%s:%s" % [unit.get_instance_id(), status_id]
				assert_has(manager._class_card_router.holds, key, id + " maintains " + status_id)
		var hp := enemy.current_hp
		var ap := hero.current_ap
		for fx in manager._class_card_router.effects:
			fx.sample(.3)
		assert_eq(enemy.current_hp, hp, id + " VFX cannot damage")
		assert_eq(hero.current_ap, ap, id + " VFX cannot spend AP")
		manager._class_card_router.clear()
		hero.clear_combat_effect_history()
		enemy.clear_combat_effect_history()
		field.terrain.dispose()
		Cleanup.dispose_grid(field.grid)
		host.units.erase(hero)
		host.units.erase(enemy)
		await get_tree().process_frame


func test_failed_missed_and_empty_casts_never_invent_impacts() -> void:
	var hero := _unit()
	var spell := Catalog.Cards.make_spell("r_shot")
	for report in [
		{ "failed": true },
		{ "damaged_enemies": [], "dodges": [hero] },
		{ "visual_impact_cells": [] },
	]:
		manager._on_spell_cast(hero, spell, report)
	assert_eq(manager._class_card_router.effects.size(), 0)


func test_duplicate_resolution_plays_once_and_keeps_pre_push_position() -> void:
	var hero := _unit()
	var target_view := UnitAnchor.new()
	target_view.unit = _unit("Cible déplacée", 1)
	target_view.unit.grid_pos = Vector2i(4, 1)
	view.add_child(target_view)
	target_view.position = view.grid_to_local(Vector2i(2, 1))
	target_view.add_to_group("unit_views")
	var spell := Catalog.Cards.make_spell("g_push")
	var report := { "action_id": "test_push", "visual_impact_cells": [Vector2i(2, 1)] }
	manager._on_spell_cast(hero, spell, report)
	manager._on_spell_cast(hero, spell, report)
	assert_eq(manager._class_card_router.effects.size(), 1)
	assert_eq(manager._class_card_router.effects[0].point, view.grid_to_local(Vector2i(2, 1)))
	assert_eq(manager._class_card_router.effects[0].anchor, target_view)


func test_healing_requires_positive_applied_amount() -> void:
	var hero := _unit()
	var fact := CombatEventFact.create(
		&"heal_received",
		hero,
		hero,
		{ "ability_id": "class_test", "amount_applied": 0 },
	)
	EventBus.heal_received.emit(fact)
	assert_eq(manager._class_card_router.effects.size(), 0)
	fact.amount_applied = 5
	EventBus.heal_received.emit(fact)
	assert_eq(manager._class_card_router.effects.size(), 1)
	assert_eq(manager._class_card_router.effects[0].recipe.family, "heal")


func test_status_refresh_does_not_multiply_holds_and_expiration_cleans_up() -> void:
	var hero := _unit()
	var enemy := _unit("Cible", 1)
	var status := Catalog.Cards.status("bleed", "Saignement", 2)
	enemy.apply_status(status, hero)
	enemy.apply_status(status, hero)
	assert_eq(manager._class_card_router.holds.size(), 1)
	enemy.remove_status(&"class_bleed", hero, true)
	manager._class_card_router._process(.2)
	assert_eq(manager._class_card_router.holds.size(), 0)


func test_state_tracks_actor_and_clock_can_be_sampled_and_replayed() -> void:
	var anchor := Node2D.new()
	view.add_child(anchor)
	anchor.position = Vector2(60, 80)
	anchor.scale = Vector2.ONE * 1.7
	var fx := Player.new()
	view.add_child(fx)
	fx.configure(Catalog.recipe("g_guard"), anchor.global_position, 160, anchor, true)
	fx.manual = true
	fx.sample(.2)
	var first_time: float = fx.sprites[0].material.get_shader_parameter("progress")
	anchor.position += Vector2(25, 0)
	fx.sample(.2)
	assert_eq(fx.sprites[0].global_position, anchor.global_position)
	assert_eq(fx.sprites[0].material.get_shader_parameter("progress"), first_time)
	assert_almost_eq(fx.sprites[0].global_scale, Vector2.ONE * 192.0 / 256.0, Vector2.ONE * .001)
	assert_eq(fx.sprites[0].z_index, 0, "Rear sheets remain above the map floor")
	assert_true(fx.sprites[0].show_behind_parent)
	assert_lt(fx.sprites[0].get_index(), fx.sprites[1].get_index())
	assert_gt(fx.sprites[1].z_index, 0)
	fx.cancel()


func test_view_replacement_and_combat_end_clear_every_effect() -> void:
	var hero := _unit()
	manager._on_spell_cast(hero, Catalog.Cards.make_spell("g_guard"), { "shield_increase_total": 5 })
	assert_gt(manager._class_card_router.effects.size(), 0)
	EventBus.combat_ended.emit(true)
	assert_eq(manager._class_card_router.effects.size(), 0)
	manager._on_spell_cast(
		hero,
		Catalog.Cards.make_spell("a_step"),
		{ "caster_movement_from": Vector2i.ZERO, "caster_movement_to": Vector2i.ONE },
	)
	manager.unregister_battle_view()
	assert_eq(manager._class_card_router.effects.size(), 0)
	assert_true(manager._class_card_router.arrivals.is_empty())


func test_movement_arrival_waits_for_body_and_is_not_replayed() -> void:
	var hero := _unit()
	hero.grid_pos = Vector2i(2, 2)
	var anchor := UnitAnchor.new()
	anchor.unit = hero
	view.add_child(anchor)
	anchor.add_to_group("unit_views")
	var report := { "caster_movement_from": Vector2i(1, 2), "caster_movement_to": hero.grid_pos }
	manager._on_spell_cast(hero, Catalog.Cards.make_spell("a_step"), report)
	assert_eq(manager._class_card_router.effects.size(), 1, "Departure only before arrival")
	EventBus.unit_visual_movement_finished.emit(hero)
	assert_eq(manager._class_card_router.effects.size(), 2)
	EventBus.unit_visual_movement_finished.emit(hero)
	assert_eq(manager._class_card_router.effects.size(), 2)


func test_periodic_damage_and_shield_feedback_require_actual_amounts() -> void:
	var hero := _unit()
	var router: Node = manager._class_card_router
	var tick := CombatEventFact.create(
		&"hp_damage_taken",
		hero,
		null,
		{ "status_id": "class_burn", "is_periodic": true },
	)
	EventBus.status_tick.emit(tick)
	assert_eq(router.effects.size(), 0)
	tick.amount_applied = 4
	EventBus.status_tick.emit(tick)
	assert_eq(router.effects.size(), 1)
	assert_eq(router.effects.back().recipe.family, "fire")
	var shield := CombatEventFact.create(
		&"shield_granted",
		hero,
		hero,
		{ "ability_id": "class_g_guard" },
	)
	EventBus.shield_granted.emit(shield)
	assert_eq(router.holds.size(), 0)
	shield.amount_applied = 12
	hero.current_shield = 12
	EventBus.shield_granted.emit(shield)
	assert_eq(router.holds.size(), 1)
	hero.current_shield = 0
	router._process(.2)
	assert_eq(router.holds.size(), 0)


func test_card_surface_ticks_expire_and_disconnect_from_old_battle() -> void:
	var field = Factory.make_battlefield(8, 6)
	var hero := _unit()
	var enemy := _unit("Cible", 1)
	field.grid.place_unit(hero, Vector2i(1, 2))
	field.grid.place_unit(enemy, Vector2i(3, 2))
	var router: Node = manager._class_card_router
	router.bind_terrain(field.terrain)
	session.cards.hand.assign([session.cards.add_copy("t_flamewall")])
	var report: Dictionary = field.caster.cast(hero, Catalog.Cards.make_spell("t_flamewall"), enemy.grid_pos)
	assert_false(report.get("failed", false))
	assert_eq(router.surfaces.size(), 5)
	var before: int = router.effects.size()
	var unrelated := Factory.make_unit("Autre combat", 1)
	unrelated.grid_pos = enemy.grid_pos
	var fact := CombatEventFact.create(
		&"hp_damage_taken",
		unrelated,
		null,
		{ "element": Spell.Element.FIRE },
	)
	fact.amount_applied = 20
	EventBus.hp_damage_taken.emit(fact)
	assert_eq(router.effects.size(), before, "Terrain facts from another battle are ignored")
	field.terrain.on_turn_start(enemy)
	assert_gt(router.effects.size(), before, "The actual terrain damage emits its own pulse")
	field.terrain.clear_effect(enemy.grid_pos)
	assert_false(router.surfaces.has(enemy.grid_pos))
	router.clear()
	assert_null(router.terrain)
	assert_false(field.terrain.surface_cleared.is_connected(router._surface_cleared))
	hero.clear_combat_effect_history()
	enemy.clear_combat_effect_history()
	field.terrain.dispose()
	Cleanup.dispose_grid(field.grid)


func test_classic_and_other_battles_keep_their_existing_vfx() -> void:
	var hero := _unit()
	var enemy := _unit("Adversaire", 1)
	var spells := preload("res://tools/class_card_vfx/enemy_inventory.gd").spells()
	var router: Node = manager._class_card_router
	for spell: Spell in spells.values():
		assert_true(router.accepts(enemy, spell), str(spell.spell_id))
	session.cards = null
	for spell: Spell in spells.values():
		assert_false(router.accepts(enemy, spell), "Classic: " + str(spell.spell_id))
	var spell := (spells["catabase_evolution_massue"] as Spell).duplicate() as Spell
	var original := Node2D.new()
	var scene := PackedScene.new()
	scene.pack(original)
	original.free()
	spell.vfx_scene = scene
	spell.vfx_placement = Spell.VfxPlacement.TARGET_CELL
	var before := view.get_child_count()
	manager._on_spell_cast(enemy, spell, { "cell": Vector2i.ONE, "damaged_enemies": [hero] })
	assert_eq(view.get_child_count(), before + 1, "Classic still instantiates its authored VFX")
	assert_eq(router.effects.size(), 0)
	EventBus.status_added.emit(
		CombatEventFact.create(&"status_added", hero, enemy, { "status_id": "class_bleed" })
	)
	assert_eq(router.holds.size(), 0, "An ID alone must not opt Classic into Cards")
	session.cards = Cards.new()
	var unrelated := Factory.make_unit("Autre combat", 1)
	assert_false(router.accepts(unrelated, spells.values()[0]))


func test_all_enemy_kits_forms_and_summons_have_confirmed_visuals() -> void:
	var spells := preload("res://tools/class_card_vfx/enemy_inventory.gd").spells()
	assert_gte(spells.size(), 48)
	assert_has(spells, "paris_infernal_sweep")
	assert_has(spells, "ecosystem_call_servant")
	for id in spells:
		var spell: Spell = spells[id]
		var entry := Catalog.for_spell(spell)
		assert_false(entry.is_empty(), id)
		var field = Factory.make_battlefield(16, 8)
		var enemy := _unit("Lanceur", 1)
		var hero := _unit("Héros", 0)
		var ally := _unit("Allié blessé", 1)
		ally.current_hp = 10
		enemy.current_hp = 40
		enemy.combat_form_id = spell.required_combat_form
		enemy.add_spell(spell)
		enemy.activation_index = 10 # Let authored initial cooldowns elapse.
		ally.tactical_role_id = StringName(spell.get_meta("catabase_requires_role_nearby", &""))
		field.grid.place_unit(enemy, Vector2i(3, 3))
		field.grid.place_unit(hero, Vector2i(3 + maxi(1, spell.minimum_range), 3))
		field.grid.place_unit(ally, Vector2i(3, 4))
		var cell := hero.grid_pos
		if entry.movement or spell.is_summon():
			cell = Vector2i(3, 3 - maxi(1, spell.minimum_range))
		elif spell.can_target_self:
			cell = enemy.grid_pos
		elif spell.can_target_ally and not spell.can_target_enemy:
			cell = ally.grid_pos
		manager._class_card_router.clear()
		var report: Dictionary = field.caster.cast(enemy, spell, cell)
		assert_false(report.get("failed", false), id + ": " + str(report.get("reason")))
		if spell.is_delayed():
			var resolved: Dictionary = field.caster.resolve_pending_activation(enemy, host.units)
			assert_true(resolved.resolved, id + ": " + str(resolved.reason))
		assert_gt(manager._class_card_router.effects.size(), 0, id)
		var state := [hero.current_hp, enemy.current_hp, enemy.current_ap, ally.current_shield]
		for fx in manager._class_card_router.effects:
			if is_instance_valid(fx):
				fx.sample(.3)
		assert_eq(
			[hero.current_hp, enemy.current_hp, enemy.current_ap, ally.current_shield],
			state,
			id + " is presentation only",
		)
		manager._class_card_router.clear()
		for unit: Unit in field.grid.get_units():
			unit.clear_combat_effect_history()
		field.terrain.dispose()
		Cleanup.dispose_grid(field.grid)
		await get_tree().process_frame


func test_projectile_respects_authored_delay_and_miss_cancels_without_impact() -> void:
	var enemy := _unit("Archer", 1)
	var spell: Spell = load("res://data/spells/enemies/paris/fire_arrow.tres")
	var fx: Node = manager.play_spell_vfx(enemy, spell, Vector2i(3, 1))
	assert_not_null(fx)
	assert_eq(fx.duration, spell.impact_delay_seconds)
	fx._process(.05)
	assert_eq(manager._class_card_router.effects.size(), 0, "A flight alone is not an impact")
	manager._on_spell_cast(enemy, spell, { "failed": true })
	assert_true(fx.closed)
	assert_true(manager._class_card_router.flights.is_empty())
	assert_eq(manager._class_card_router.effects.size(), 0)


func test_cancelled_telegraph_leaves_no_persistent_vfx() -> void:
	var field = Factory.make_battlefield(10, 5)
	var enemy := _unit("Fondeur", 1)
	var hero := _unit()
	field.grid.place_unit(enemy, Vector2i(1, 2))
	field.grid.place_unit(hero, Vector2i(3, 2))
	var spell: Spell = load("res://data/spells/catabase_monsters/braise_fournaise.tres")
	enemy.add_spell(spell)
	enemy.activation_index = 5
	var report: Dictionary = field.caster.cast(enemy, spell, hero.grid_pos)
	assert_false(report.get("failed", false))
	assert_eq(manager._class_card_router.pending.size(), 1)
	assert_eq(hero.current_hp, 100, "Warning does no damage")
	field.caster.cancel_pending_for_unit(enemy)
	assert_true(manager._class_card_router.pending.is_empty())
	assert_true(
		manager._class_card_router.effects.all(
			func(fx):
				return fx.closed,
		)
	)
	manager._class_card_router.clear()
	field.terrain.dispose()
	Cleanup.dispose_grid(field.grid)


func test_delayed_shield_hit_confirms_only_at_resolution() -> void:
	var field = Factory.make_battlefield(10, 5)
	var enemy := _unit("Fondeur", 1)
	var hero := _unit()
	field.grid.place_unit(enemy, Vector2i(1, 2))
	field.grid.place_unit(hero, Vector2i(3, 2))
	var spell: Spell = load("res://data/spells/catabase_monsters/braise_fournaise.tres")
	enemy.add_spell(spell)
	enemy.activation_index = 5
	hero.current_shield = 100
	var report: Dictionary = field.caster.cast(enemy, spell, hero.grid_pos)
	assert_false(report.get("failed", false))
	var router: Node = manager._class_card_router
	var unrelated := CombatEventFact.create(&"hp_damage_taken", hero, enemy, { })
	unrelated.amount_applied = 4
	EventBus.hp_damage_taken.emit(unrelated)
	assert_false(
		router.pending[enemy].confirmed,
		"Preparation damage cannot confirm the pending hit",
	)
	var result: Dictionary = field.caster.resolve_pending_activation(enemy, host.units)
	assert_true(result.resolved)
	assert_eq(hero.current_hp, 100)
	assert_true(router.pending.is_empty())
	assert_true(
		router.effects.any(
			func(fx):
				return not fx.closed and fx.recipe.id == str(spell.spell_id),
		),
		"Fully shielded fire still has a confirmed impact",
	)
	manager._class_card_router.clear()
	field.terrain.dispose()
	Cleanup.dispose_grid(field.grid)


func test_existing_states_restore_without_application_bursts_and_attach_to_late_actor() -> void:
	var hero := _unit()
	manager.unregister_battle_view()
	hero.apply_status(Catalog.Cards.status("marked", "Marqué", 2))
	hero.current_shield = 15
	manager.register_battle_view(view)
	var router: Node = manager._class_card_router
	router._process(.2)
	assert_eq(router.holds.size(), 2)
	assert_true(
		router.effects.all(
			func(fx):
				return fx.persistent,
		)
	)
	var anchor := UnitAnchor.new()
	anchor.unit = hero
	view.add_child(anchor)
	anchor.add_to_group("unit_views")
	anchor.position = Vector2(40, 70)
	router._process(.2)
	for hold in router.holds.values():
		assert_eq(hold.fx.anchor, anchor)
		anchor.position += Vector2(20, 10)
		hold.fx.sample(20.0)
		assert_eq(hold.fx.sprites[0].global_position, anchor.global_position)
	EventBus.combat_ended.emit(true)
	router._process(.4)
	assert_true(
		router.holds.is_empty(),
		"Combat end must not restore still-present gameplay states",
	)
	assert_true(router.effects.is_empty())


func test_durable_burn_animates_and_survives_until_its_last_source_is_removed() -> void:
	var hero := _unit()
	var source := _unit("Seconde source", 1)
	var target := _unit("Cible", 1)
	var status := Catalog.Cards.status("burn", "Brûlure", 2)
	status.unique_per_source = true
	status.damage_per_turn = 4
	status.element = Spell.Element.FIRE
	target.apply_status(status, hero)
	target.apply_status(status, source)
	var router: Node = manager._class_card_router
	assert_eq(router.holds.size(), 1)
	var fx: Node = router.holds.values()[0].fx
	fx.sample(2.0)
	var mat: ShaderMaterial = fx.sprites[0].material
	var first_flow: float = mat.get_shader_parameter("flow_time")
	fx.sample(20.0)
	assert_gt(float(mat.get_shader_parameter("flow_time")), first_flow)
	assert_true(mat.get_shader_parameter("holding"))
	assert_true(fx.sprites[0].visible)
	assert_eq(
		target.get_status_remaining(&"class_burn", hero),
		2,
		"Visual time never ages gameplay",
	)
	target.remove_status(&"class_burn", hero, true)
	assert_eq(router.holds.size(), 1)
	target.remove_status(&"class_burn", source, true)
	assert_true(router.holds.is_empty(), "Forced removal is immediate, not dependent on polling")
	assert_true(fx.closed)


func test_card_ground_effects_refresh_expire_and_follow_the_actual_surface() -> void:
	var field = Factory.make_battlefield(8, 6)
	var hero := _unit()
	field.grid.place_unit(hero, Vector2i(1, 2))
	var router: Node = manager._class_card_router
	router.bind_terrain(field.terrain)
	var spell := Catalog.Cards.make_spell("t_flamewall")
	session.cards.hand.assign([session.cards.add_copy("t_flamewall")])
	var report: Dictionary = field.caster.cast(hero, spell, Vector2i(3, 2))
	assert_false(report.get("failed", false))
	assert_eq(router.surface_holds.size(), 5)
	var center: Node = router.surface_holds[Vector2i(3, 2)]
	assert_eq(center.family, "fire")
	assert_eq(center.get_child(0).polygon.size(), 4)
	center.sample(600.0)
	assert_eq(field.terrain.get_remaining_duration(Vector2i(3, 2)), 2)
	field.terrain.tick_all_effects()
	assert_eq(router.surface_holds[Vector2i(3, 2)], center)
	assert_eq(center.remaining, 1)
	field.terrain.tick_all_effects()
	assert_true(router.surface_holds.is_empty())
	assert_true(center.fading)
	center._process(.5)
	assert_true(center.closed)
	var ice := preload("res://core/expedition/card_ecosystem_effects.gd").surface("ice_field", 2)
	field.terrain.place_effect(Vector2i(3, 2), ice, hero, Catalog.Cards.make_spell("t_glacier"))
	assert_eq(router.surface_holds[Vector2i(3, 2)].family, "ice")
	router.bind_terrain(null)
	assert_true(router.surface_holds.is_empty())
	assert_false(field.terrain.surface_applied.is_connected(router._surface_updated))
	field.terrain.dispose()
	Cleanup.dispose_grid(field.grid)


func test_equipment_and_reaction_states_get_a_durable_visual() -> void:
	var hero := _unit()
	for id in ["wet", "shock", "poison", "equipment_regeneration"]:
		var status := StatusData.new()
		status.status_id = StringName(id)
		if id == "equipment_regeneration":
			status.heal_per_turn = 3
		hero.apply_status(status)
	var router: Node = manager._class_card_router
	assert_eq(router.holds.size(), 4)
	for family in ["water", "lightning", "poison", "heal"]:
		assert_true(
			router.holds.values().any(
				func(hold):
					return hold.fx.recipe.family == family,
			),
			family,
		)
	for state in hero.get_active_statuses().duplicate():
		hero.remove_status(state.data.get_effective_status_id())
	assert_true(router.holds.is_empty())
