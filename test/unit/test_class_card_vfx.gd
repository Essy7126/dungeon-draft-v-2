extends GutTest
const Catalog := preload("res://vfx/class_cards/class_card_vfx_catalog.gd")
const Player := preload("res://vfx/class_cards/class_card_vfx_player.gd")
const Factory := preload("res://test/support/factory.gd")
const Cleanup := preload("res://test/support/isolated_battlefield_cleanup.gd")
const Cards := preload("res://core/expedition/class_cards.gd")
const Cel := preload("res://vfx/class_cards/cel/recipes.gd")
var manager: Node
var view: Node2D
var host: BattleHost
var session: ExpeditionSession


func test_cel_catalogue_has_authored_compositions_and_six_pose_assets() -> void:
	assert_eq(Cel.CARDS.size(), Catalog.Cards.pool().size())
	for id in Catalog.Cards.pool():
		assert_has(Cel.CARDS, id)
		var entry := Catalog.recipe(id)
		assert_eq(entry.art_direction, "cel", id)
		assert_has(Cel.CLIPS, entry.cel_clip, id)
		assert_gt(entry.concept.length(), 25, id)
	for clip in Cel.CLIPS:
		var atlas := Cel.texture(clip)
		assert_not_null(atlas, clip)
		assert_eq(atlas.get_size(), Vector2(1536, 1024), "Six square poses: " + clip)
	assert_eq(Cel.frame_at(.7, "brace"), 2, "An intact shield does not play its broken pose")
	assert_eq(Cel.frame_at(.7, "break"), 4, "A broken shield releases separate fragments")
	assert_ne(
		Cel.frame_at(.04, "slash"),
		Cel.frame_at(.5, "slash"),
		"Real pose changes, not only scaling",
	)


func test_cel_status_rail_groups_orders_overflow_and_compact_expiration() -> void:
	var hero := _unit()
	var enemy := _unit("Cible", 1)
	var router: Node = manager._class_card_router
	for effect in ["marked", "bleed", "burn", "root", "slow", "weak", "disrupt", "lure"]:
		enemy.apply_status(Catalog.Cards.status(effect, effect, 2), hero)
	assert_eq(router.holds.size(), 8)
	var slots: Array = []
	for hold in router.holds.values():
		var fx: Node = hold.fx
		slots.append(fx.status_slot)
		assert_eq(fx.status_count, 8)
		fx.sample(3600.0)
		assert_eq(fx.sprites[0].visible, fx.status_slot < 6)
		assert_eq(fx.overflow.visible, fx.status_slot == 5)
		if fx.status_slot == 5:
			assert_eq(fx.overflow.text, "+3")
	slots.sort()
	assert_eq(slots, [0, 1, 2, 3, 4, 5, 6, 7])
	var root_key := "%s:class_root" % enemy.get_instance_id()
	assert_eq(
		router.holds[root_key].fx.status_slot,
		0,
		"Movement restriction has a stable leading slot",
	)
	enemy.remove_status(&"class_root", hero, true)
	router._process(.2)
	assert_eq(router.holds.size(), 7)
	var outros: Array = router.effects.filter(
		func(fx):
			return fx.recipe.get("feedback_phase", "") == "expire" and fx.recipe.get(
					"status_id",
					"",
				) == "class_root",
	)
	assert_eq(outros.size(), 1)
	if not outros.is_empty():
		var outro: Node = outros[0]
		assert_true(outro.badge_mode)
		assert_false(outro.persistent)
		assert_eq(outro.status_slot, 0)
		assert_almost_eq(outro.sprites[0].global_scale.x, outro.badge_size / 256.0, .001)
		outro._process(.6)
		assert_true(outro.closed)


func test_cel_status_rail_replaces_only_status_text_in_its_bound_cards_battle() -> void:
	var hero := _unit()
	var enemy := _unit("Cible", 1)
	var foreign := Factory.make_unit("Autre combat", 1)
	var controller := CombatFeedbackController.new()
	add_child(controller)
	VFXManager.register_battle_view(view)
	var status := CombatEventFact.create(
		&"status_added",
		enemy,
		hero,
		{ "status_id": "class_root" },
	)
	assert_false(
		controller.submit_fact(status),
		"One status presentation, no generic floating duplicate",
	)
	var expired := CombatEventFact.create(
		&"status_expired",
		enemy,
		hero,
		{ "status_id": "class_root" },
	)
	assert_false(controller.submit_fact(expired))
	assert_true(
		controller.submit_fact(
			CombatEventFact.create(&"hp_damage_taken", enemy, hero, { "amount_applied": 9 })
		),
		"Keep actual damage numbers",
	)
	assert_true(
		controller.submit_fact(CombatEventFact.create(&"status_added", foreign, hero)),
		"A different battle retains its normal text",
	)
	hero.remove_meta("ct_session")
	for member in host.units:
		member.remove_meta("ct_session")
	assert_true(controller.submit_fact(status), "Classic retains its status text")
	VFXManager.unregister_battle_view(view)
	controller.queue_free()
	await get_tree().process_frame


func test_cel_secondary_reactions_stay_small_and_partial_absorption_keeps_shield_intact() -> void:
	var tick := Player.new()
	view.add_child(tick)
	tick.configure(Catalog.feedback("fire", "tick"), Vector2.ZERO, 200)
	tick.manual = true
	tick.sample(.12)
	assert_lt(tick.sprites[0].global_scale.x * 256.0, 120.0, "Tick is a small local reaction")
	var absorbed := Player.new()
	view.add_child(absorbed)
	absorbed.configure(Catalog.feedback("guard", "absorb"), Vector2.ZERO, 200)
	absorbed.manual = true
	absorbed.sample(absorbed.duration * .7)
	assert_eq(
		absorbed.sprites[1].material.get_shader_parameter("frame_index"),
		2,
		"Partial absorption does not draw a broken guard",
	)
	var broken := Player.new()
	view.add_child(broken)
	broken.configure(Catalog.feedback("guard", "break"), Vector2.ZERO, 200)
	broken.manual = true
	broken.sample(broken.duration * .7)
	assert_eq(broken.sprites[1].material.get_shader_parameter("frame_index"), 4)
	for fx in [tick, absorbed, broken]:
		fx.cancel()
	await get_tree().process_frame


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
	assert_almost_eq(
		fx.sprites[0].global_scale,
		Vector2.ONE * fx.badge_size / 256.0,
		Vector2.ONE * .001,
	)
	assert_eq(fx.sprites[0].z_index, 3, "Compact badges remain above the actor")
	assert_false(fx.sprites[0].show_behind_parent)
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
	assert_eq(
		router.effects.back().recipe.motif,
		"ember",
		"Pilot terrain ticks keep the authored material",
	)
	assert_eq(router.effects.back().recipe.feedback_phase, "tick")
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


func test_pilot_dagger_uses_confirmed_direction_without_adding_a_gameplay_delay() -> void:
	var hero := _unit()
	var spell := Catalog.Cards.make_spell("a_dagger")
	var router: Node = manager._class_card_router
	assert_eq(spell.impact_delay_seconds, 0.0)
	manager._on_spell_cast(hero, spell, { "visual_impact_cells": [Vector2i(3, 1)] })
	assert_eq(router.effects.size(), 1)
	assert_eq(router.echoes.size(), 1, "An instantaneous hit has an afterimage, not a deferred hit")
	var fx: Node = router.effects[0]
	assert_eq(fx.recipe.motif, "dagger")
	assert_eq(fx.duration, .32)
	fx.sample(.06)
	var direction: Vector2 = fx.sprites[0].material.get_shader_parameter("direction")
	assert_gt(direction.x, 0.0)
	fx.origin = fx.point + Vector2(180, -fx.width * .24)
	fx.sample(.06)
	assert_eq(fx.sprites[0].material.get_shader_parameter("direction"), Vector2.LEFT)
	fx.sample(.4)
	assert_false(fx.sprites[0].visible, "Short weapon read ends before a sustained spell")
	assert_true(router.flights.is_empty())


func test_pilot_terrain_on_empty_cells_has_no_character_impact_or_fake_projectile() -> void:
	var field = Factory.make_battlefield(8, 6)
	var hero := _unit()
	field.grid.place_unit(hero, Vector2i(1, 2))
	var router: Node = manager._class_card_router
	router.bind_terrain(field.terrain)
	for id in ["t_flamewall", "t_glacier"]:
		hero.current_ap = 10
		session.cards.hand.assign([session.cards.add_copy(id)])
		var report: Dictionary = field.caster.cast(hero, Catalog.Cards.make_spell(id), Vector2i(
				3,
				2,
			))
		assert_false(report.get("failed", false), id)
		assert_eq(router.surface_holds.size(), 5)
		assert_true(router.effects.is_empty(), "Empty ground is not a damaged actor: " + id)
		assert_true(router.echoes.is_empty(), "A ground field is not a missile: " + id)
		for cell in router.surface_holds.keys():
			var fx: Node = router.surface_holds[cell]
			assert_eq(fx.motif, "pyre" if id == "t_flamewall" else "frost_garden")
			assert_not_null(fx.canopy)
			field.terrain.clear_effect(cell)
			assert_true(fx.fading)
		assert_true(router.effects.is_empty(), "Expiry dissolves ground without an actor explosion")
	var profiles := preload("res://vfx/class_cards/class_card_vfx_profiles.gd")
	assert_eq(profiles.ground(Catalog.Cards.make_spell("t_flamewall"), "water"), "")
	assert_eq(profiles.ground(Catalog.Cards.make_spell("t_glacier"), "move"), "")
	router.clear()
	field.terrain.dispose()
	Cleanup.dispose_grid(field.grid)


func test_pilot_burn_separates_ignition_tick_hold_and_removal() -> void:
	var field = Factory.make_battlefield(8, 6)
	var hero := _unit()
	var target := _unit("Cible", 1)
	field.grid.place_unit(hero, Vector2i(1, 2))
	field.grid.place_unit(target, Vector2i(3, 2))
	session.cards.hand.assign([session.cards.add_copy("t_burn")])
	var report: Dictionary = field.caster.cast(hero, Catalog.Cards.make_spell("t_burn"), target.grid_pos)
	assert_false(report.get("failed", false))
	var router: Node = manager._class_card_router
	assert_eq(router.holds.size(), 1)
	var impacts: Array = router.effects.filter(
		func(fx):
			return not fx.persistent,
	)
	assert_eq(impacts.size(), 1, "The status callback must not duplicate the confirmed ignition")
	assert_eq(impacts[0].recipe.motif, "ember")
	var hold: Node = router.holds.values()[0].fx
	hold.sample(600.0)
	assert_true(hold.sprites[0].visible)
	assert_eq(target.get_status_remaining(&"class_burn", hero), 2)
	target.remove_status(&"class_burn", hero, true)
	assert_true(hold.closed)
	assert_eq(router.effects.back().recipe.motif, "ember")
	assert_eq(router.effects.back().recipe.feedback_phase, "expire")
	assert_true(router.holds.is_empty())
	for unit: Unit in [hero, target]:
		unit.clear_combat_effect_history()
	field.terrain.dispose()
	Cleanup.dispose_grid(field.grid)


func test_live_card_contracts_render_and_finish_without_a_gameplay_timer() -> void:
	var concepts := preload("res://vfx/class_cards/class_card_vfx_concepts.gd")
	for id in Catalog.Cards.pool():
		assert_has(concepts.CARDS, id, "Every live card needs an explicit art brief: " + id)
		var entry := Catalog.recipe(id)
		assert_false(str(entry.get("concept", "")).is_empty(), id)
		assert_gte(float(entry.width), 1.5, "Readable screen span: " + id)
		assert_gt(float(entry.duration), .25, "A readable impact tail: " + id)
		var tail_budget := 1.8 if int(entry.get("power", 0)) == 2 else 1.4
		assert_lte(
			float(entry.duration),
			tail_budget,
			"Bounded tail for the authored power tier: " + id,
		)
		var fx := Player.new()
		view.add_child(fx)
		fx.configure(entry, Vector2.ZERO, 160)
		fx.sample(fx.duration * .2)
		assert_true(fx.sprites[1].visible, id)
		fx._process(fx.duration)
		assert_true(fx.closed, "Transient presentation must release its sheets: " + id)
		await get_tree().process_frame


func test_real_stasis_distinguishes_skip_from_paris_ap_penalty_and_preserves_outro() -> void:
	for paris in [false, true]:
		var field = Factory.make_battlefield(8, 6)
		var hero := _unit()
		var enemy := _unit("Paris" if paris else "Cible", 1)
		enemy.unit_id = &"enemy_paris" if paris else &"enemy_witness"
		field.grid.place_unit(hero, Vector2i(1, 2))
		field.grid.place_unit(enemy, Vector2i(3, 2))
		var spell := Catalog.Cards.make_spell("t_hourglass")
		session.cards.hand.assign([session.cards.add_copy("t_hourglass")])
		var router: Node = manager._class_card_router
		router.clear()
		var refused: Dictionary = field.caster.cast(hero, spell, enemy.grid_pos)
		assert_true(refused.get("failed", false), "Stasis requires an actual mark")
		assert_true(router.effects.is_empty(), "No dream visual for a refused cast")
		enemy.apply_status(Catalog.Cards.status("marked", "Marqué", 1), hero)
		var report: Dictionary = field.caster.cast(hero, spell, enemy.grid_pos)
		assert_false(report.get("failed", false))
		var key := "%s:ecosystem_stasis" % enemy.get_instance_id()
		assert_has(router.holds, key)
		var fx: Node = router.holds[key].fx
		assert_eq(fx.recipe.motif, "discord" if paris else "dream")
		var power_casts: Array = router.effects.filter(
			func(effect):
				return not effect.persistent and effect.recipe.get("power", 0) == 2,
		)
		assert_eq(
			power_casts.size(),
			1,
			"The confirmed stasis owns one epic cast, independent of its hold",
		)
		if not power_casts.is_empty():
			var material: ShaderMaterial = power_casts[0].sprites[0].material
			assert_eq(material.shader, Player.CEL)
			assert_eq(power_casts[0].playback.clip, "seal" if paris else "hourglass")
		assert_true(router.echoes.is_empty(), "Stasis application is not a projectile")
		fx.sample(3600.0)
		assert_true(fx.sprites[1].visible, "Waiting does not consume an activation")
		enemy.tick_statuses()
		assert_false(router.holds.has(key))
		assert_true(router.holds.has("%s:ecosystem_stasis_ward" % enemy.get_instance_id()), "Ward outlives stasis")
		assert_true(
			router.effects.any(
				func(effect):
					return (
						effect.recipe.get("feedback_phase", "") == "expire"
						and effect.recipe.get("motif", "") == ("discord" if paris else "dream")
					),
			),
			"Outro preserves the actual effect on Paris",
		)
		router.clear()
		for unit: Unit in [hero, enemy]:
			unit.clear_combat_effect_history()
			host.units.erase(unit)
		field.terrain.dispose()
		Cleanup.dispose_grid(field.grid)
		await get_tree().process_frame


func test_epic_hierarchy_covers_real_tier_and_does_not_escalate_ticks_or_holds() -> void:
	var power := preload("res://vfx/class_cards/class_card_vfx_power.gd")
	var ecosystem := preload("res://core/expedition/card_ecosystem_catalog.gd")
	assert_eq(power.EPIC.size(), ecosystem.EPIC.size())
	for id in ecosystem.EPIC:
		assert_has(power.EPIC, id)
		var entry := Catalog.recipe(id)
		assert_eq(entry.power, 2, id)
		assert_gt(float(entry.width), 2.70, "A clear silhouette jump above ordinary casts: " + id)
		assert_false(power.shape(entry, false).is_empty(), id)
		for phase in ["", "tick", "expire", "break", "hold"]:
			var sample := entry.duplicate(true)
			sample["feedback_phase"] = phase
			var holding: bool = phase == "hold"
			var fx := Player.new()
			view.add_child(fx)
			fx.configure(sample, Vector2.ZERO, 220, null, holding)
			assert_eq(fx.sprites[0].material.shader, Player.CEL)
			assert_eq(fx.playback.minor, phase != "", id + ": " + phase)
			assert_eq(fx.playback.copies, 1 if phase != "" else entry.cel_copies)
			fx.sample(3.0)
			assert_eq(fx.sprites[0].visible, holding, "Only actual holds outlive the visual tail")
			fx.cancel()
			await get_tree().process_frame
	for pair in [
		["a_dagger", "a_reap"],
		["g_guard", "g_bastion"],
		["r_shot", "r_bounty"],
		["t_burn", "t_cataclysm"],
	]:
		var ordinary := Catalog.recipe(pair[0])
		var epic := Catalog.recipe(pair[1])
		assert_eq(ordinary.power, 0)
		assert_gt(float(epic.width), float(ordinary.width) * 1.35)
		assert_gt(float(epic.duration), float(ordinary.duration))
	for id in power.MAJOR:
		assert_eq(Catalog.recipe(id).power, 1, "Major attacks remain below epic treatment: " + id)
	for id in Catalog.Cards.pool():
		if str(id).begins_with("i_"):
			assert_eq(Catalog.recipe(id).power, 0, "Initiations preserve the contrast: " + id)


func test_authored_guard_tracks_one_or_two_actual_owner_activations() -> void:
	for upgraded in [false, true]:
		var field = Factory.make_battlefield(8, 6)
		var hero := _unit()
		field.grid.place_unit(hero, Vector2i(1, 2))
		session.cards.hand.assign([session.cards.add_copy("g_bastion")])
		var spell := Catalog.Cards.make_spell("g_bastion", 3, upgraded)
		var report: Dictionary = field.caster.cast(hero, spell, hero.grid_pos)
		assert_false(report.get("failed", false))
		var router: Node = manager._class_card_router
		var key := "%s:shield" % hero.get_instance_id()
		assert_has(router.holds, key)
		var fx: Node = router.holds[key].fx
		assert_eq(fx.recipe.motif, "aegis")
		fx.sample(600.0)
		assert_gt(hero.current_shield, 0)
		hero.start_turn()
		router._process(.2)
		assert_eq(
			router.holds.has(key),
			upgraded,
			"Use actual shield lifetime, including upgraded cards",
		)
		if upgraded:
			hero.start_turn()
			router._process(.2)
		assert_false(router.holds.has(key))
		assert_true(fx.closed)
		router.clear()
		hero.clear_combat_effect_history()
		host.units.erase(hero)
		field.terrain.dispose()
		Cleanup.dispose_grid(field.grid)
		await get_tree().process_frame


func test_all_five_authored_fields_use_real_cells_and_real_two_round_lifetimes() -> void:
	var profiles := preload("res://vfx/class_cards/class_card_vfx_profiles.gd")
	for id in profiles.GROUNDS:
		var field = Factory.make_battlefield(8, 6)
		var hero := _unit()
		field.grid.place_unit(hero, Vector2i(1, 2))
		var router: Node = manager._class_card_router
		router.bind_terrain(field.terrain)
		session.cards.hand.assign([session.cards.add_copy(id)])
		var report: Dictionary = field.caster.cast(hero, Catalog.Cards.make_spell(id), Vector2i(
				3,
				2,
			))
		assert_false(report.get("failed", false), id)
		assert_eq(router.surface_holds.size(), 5, id)
		assert_true(router.effects.is_empty(), "No actor impacts on empty ground: " + id)
		for fx in router.surface_holds.values():
			fx.sample(3600.0)
			assert_eq(fx.remaining, 2)
			assert_eq(fx.motif, profiles.GROUNDS[id][1])
		field.terrain.tick_all_effects()
		assert_eq(router.surface_holds.size(), 5)
		field.terrain.tick_all_effects()
		assert_true(router.surface_holds.is_empty())
		for fx in router.ground_effects:
			assert_true(fx.fading)
		router.clear()
		hero.clear_combat_effect_history()
		host.units.erase(hero)
		field.terrain.dispose()
		Cleanup.dispose_grid(field.grid)
		await get_tree().process_frame
