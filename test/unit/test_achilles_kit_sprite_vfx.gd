extends GutTest

const FX := preload("res://vfx/achilles_kit/achilles_spell_sprite_vfx.gd")
const Factory := preload("res://test/support/factory.gd")
const SHOT: Spell = preload("res://data/spells/achilles/pelion_shot.tres")
const DASH: Spell = preload("res://data/spells/achilles/fulminant_dash.tres")
const STRIKE: Spell = preload("res://data/spells/achilles/peleid_strike.tres")
const GUARD: Spell = preload("res://data/spells/achilles/bronze_guard.tres")
const CATALOG: MasteryCatalogData = preload("res://data/characters/achilles/doctrines/achilles_mastery_catalog.tres")

var _fixtures: Array[Dictionary] = []
var _callbacks: Array[Callable] = []


class GridView:
	extends Node2D

	func grid_to_local(cell: Vector2i) -> Vector2:
		return Vector2((cell.x - cell.y) * 64.0, (cell.x + cell.y) * 32.0)


class EffectManager:
	extends "res://core/vfx_manager.gd"

	# The real manager factory and lifecycle run in every test. Only frame
	# textures are injected so these mechanics do not depend on image import.
	pass

func after_each() -> void:
	for callback in _callbacks:
		if EventBus.spell_visual_resolved.is_connected(callback):
			EventBus.spell_visual_resolved.disconnect(callback)
	_callbacks.clear()
	for fixture in _fixtures:
		fixture.manager.unregister_battle_view()
		fixture.adapter.dispose()
	_fixtures.clear()


func test_projectile_clock_moves_before_confirmation_and_never_invents_impact() -> void:
	var effect := _effect()
	effect.start_flight(0.2)
	effect.set_process(false)
	effect.advance_simulation(0.1)
	assert_eq(effect.get_visual_runtime_state().phase, &"flight")
	assert_false(effect.get_visual_runtime_state().impact_reached)
	assert_almost_eq(effect._sprites[0].global_position, Vector2(50, 20), Vector2(0.001, 0.001))
	effect.advance_simulation(0.2)
	assert_eq(effect.get_visual_runtime_state().phase, &"awaiting_impact")
	assert_false(effect.get_visual_runtime_state().impact_reached)
	effect.confirm_impact([Vector2(100, 20)])
	assert_eq(effect.get_visual_runtime_state().phase, &"impact")
	assert_true(effect.get_visual_runtime_state().impact_reached)


func test_cancelled_or_missed_projectile_does_not_create_a_late_hit() -> void:
	var effect := _effect()
	effect.start_flight(0.2)
	effect.confirm_impact([])
	assert_false(effect.get_visual_runtime_state().impact_reached)
	assert_true(effect.get_visual_runtime_state().closed)
	assert_false(effect.visible)
	var stale := _effect()
	stale.start_flight(0.2)
	stale.advance_simulation(1.3)
	assert_true(stale.get_visual_runtime_state().closed)
	assert_false(stale.get_visual_runtime_state().impact_reached)
	stale.confirm_impact([Vector2(100, 20)])
	assert_false(stale.visible)


func test_hold_stays_on_one_frame_and_bursts_end_without_oscillation() -> void:
	var hold := _effect()
	hold.start_hold()
	var initial := hold._sprites[0].texture
	hold.advance_simulation(60.0)
	assert_eq(hold._sprites[0].texture, initial)
	assert_eq(hold.get_visual_runtime_state().phase, &"hold")
	assert_eq(hold.get_visual_runtime_state().elapsed, 0.0)
	var burst := _effect()
	burst.start_burst(&"guard", 0.24)
	burst.advance_simulation(-1.0)
	assert_eq(burst.get_visual_runtime_state().elapsed, 0.0)
	burst.advance_simulation(0.24)
	assert_true(burst.get_visual_runtime_state().closed)


func test_real_factory_restarts_bursts_after_expiry_and_clears_freed_references() -> void:
	var fixture := _fixture()
	var manager: EffectManager = fixture.manager
	var presentation := {"spell_id": STRIKE.spell_id, "action_family": &"strike"}
	var targets: Array[Vector2] = [Vector2(100, 20)]
	for cycle in 4:
		var effect: Node = manager._burst(presentation, &"impact", Vector2.ZERO, targets, 0.52, 0.24)
		assert_not_null(effect, "The real factory must return each repeated burst")
		if effect == null:
			return
		effect.set_process(false)
		var state: Dictionary = effect.get_visual_runtime_state()
		assert_eq(state.phase, &"impact", "Cycle %d must start before publication" % cycle)
		assert_true(state.impact_reached)
		assert_false(state.closed)
		assert_eq(effect._sprites.size(), 1, "An initialized burst owns a rendered sprite")
		assert_eq(manager._achilles_effects.size(), 1, "The expired predecessor is pruned")
		effect.advance_simulation(0.24)
		assert_true(effect.is_queued_for_deletion())
		await wait_process_frames(2)
		assert_false(is_instance_valid(effect), "The regression requires a freed Object, not just a hidden Node")
	# Clearing a mixed registry exercises shutdown independently of creation's
	# pruning pass. The last expired Object deliberately remains in the array.
	var live: Node = FX.new()
	fixture.view.add_child(live)
	live.configure(_frames(), presentation, Vector2.ZERO, targets, 32.0)
	live.start_hold()
	manager._achilles_effects.append(live)
	assert_eq(manager._achilles_effects.size(), 2)
	manager.unregister_battle_view()
	assert_true(live.get_visual_runtime_state().closed)
	assert_true(manager._achilles_effects.is_empty())


func test_real_shot_has_a_flight_between_cost_commit_and_hp_loss() -> void:
	var fixture := _fixture()
	var hero: Unit = fixture.hero
	var enemy: Unit = fixture.enemy
	var context: CastContext = fixture.field.caster.begin_cast(hero, SHOT, enemy.grid_pos)
	assert_false(context.failed)
	assert_eq(SHOT.impact_delay_seconds, 0.2)
	var hp := enemy.current_hp
	var flight: Node = fixture.manager.play_spell_vfx(hero, SHOT, enemy.grid_pos)
	assert_not_null(flight)
	if flight == null:
		return
	flight.advance_simulation(0.1)
	assert_eq(enemy.current_hp, hp)
	assert_false(flight.get_visual_runtime_state().impact_reached)
	var report: Dictionary = fixture.field.caster.resolve_cast(context)
	assert_false(report.get("failed", false))
	assert_lt(enemy.current_hp, hp)
	assert_eq(flight.get_visual_runtime_state().phase, &"impact")
	assert_true(flight.get_visual_runtime_state().impact_reached)
	assert_true(fixture.manager._achilles_flights.is_empty())
	assert_eq(report.visual_impact_cells, [Vector2i(4, 1)])
	fixture.field.grid.move_unit(enemy.grid_pos, Vector2i(6, 4))
	assert_eq(fixture.manager._resolved_impact_positions(report),
		[fixture.manager._impact_cell_position(Vector2i(4, 1))],
		"The hit remains at its resolved cell even if its victim subsequently moves.")


func test_direct_resolved_shot_has_only_hit_feedback_and_no_late_flight() -> void:
	var fixture := _fixture()
	fixture.field.caster.cast(fixture.hero, SHOT, fixture.enemy.grid_pos)
	var effects := _active_effects(fixture.manager)
	assert_eq(effects.size(), 1)
	for effect in effects:
		assert_eq(effect.get_visual_runtime_state().phase, &"impact")
	assert_true(fixture.manager._achilles_flights.is_empty())


func test_projectile_uses_real_alternate_origin_and_legal_fan_cells() -> void:
	var fixture := _fixture([&"achilles_chiron_centaur_volley"])
	var hero: Unit = fixture.hero
	fixture.adapter._data(hero).origin = {"spell_id": SHOT.spell_id, "cell": Vector2i(2, 1)}
	var flight: Node = fixture.manager.play_spell_vfx(hero, SHOT, fixture.enemy.grid_pos)
	var state: Dictionary = flight.get_visual_runtime_state()
	assert_eq(state.origin, fixture.view.to_global(fixture.view.grid_to_local(Vector2i(2, 1))))
	var cells: Array = fixture.adapter.preview_target_cells(hero, SHOT, fixture.enemy.grid_pos)
	assert_eq(state.targets.size(), cells.size())
	assert_eq(state.targets.size(), 3)
	assert_eq(hero.grid_pos, Vector2i(1, 1), "A projectile origin never relocates the actor.")


func test_automatic_reaction_emits_once_after_real_damage_with_no_cost_or_flight() -> void:
	var fixture := _fixture()
	var hero: Unit = fixture.hero
	var enemy: Unit = fixture.enemy
	fixture.field.grid.move_unit(enemy.grid_pos, Vector2i(2, 1))
	var ap := hero.current_ap
	var hp := enemy.current_hp
	var captures: Array = []
	var callback := func(actor: Unit, spell: Spell, report: Dictionary, presentation: Dictionary) -> void:
		if actor == hero:
			captures.append({"spell": spell, "report": report, "presentation": presentation,
				"hp": enemy.current_hp, "ap": hero.current_ap})
	EventBus.spell_visual_resolved.connect(callback)
	_callbacks.append(callback)
	fixture.adapter.queue_automatic(hero, STRIKE.spell_id, enemy, 0.6, &"counter_test")
	fixture.adapter.flush_automatic()
	assert_eq(captures.size(), 1)
	if captures.is_empty():
		return
	assert_lt(captures[0].hp, hp)
	assert_eq(captures[0].ap, ap)
	assert_true(captures[0].report.automatic)
	assert_true(captures[0].presentation.automatic)
	assert_eq(captures[0].presentation.source_chain, [&"counter_test"])
	assert_true(hero.can_use_spell(STRIKE))
	var effects := _active_effects(fixture.manager)
	assert_eq(effects.size(), 1)
	for effect in effects:
		assert_eq(effect.get_visual_runtime_state().phase, &"impact")
		assert_true(effect.get_visual_runtime_state().automatic)
	assert_true(fixture.manager._achilles_flights.is_empty())


func test_bastion_waits_for_actual_arrival_and_acknowledges_only_once() -> void:
	var fixture := _fixture([&"achilles_aeacus_mobile_bastion"])
	var hero: Unit = fixture.hero
	hero.add_sourced_shield(&"guard_test", 50, hero, {"tags": [&"guard"]})
	var report: Dictionary = fixture.field.caster.cast(hero, DASH, Vector2i(3, 1))
	assert_false(report.get("failed", false), str(report))
	assert_true(report.visual_presentation.guard_active)
	assert_eq(hero.grid_pos, Vector2i(3, 1))
	assert_eq(hero.get_shield_value(&"guard_test"), 40)
	assert_lt(fixture.enemy.current_hp, 100, "Bastion rules already resolved during the logical movement.")
	assert_eq(_animation_count(fixture.manager, &"guard"), 0)
	EventBus.unit_visual_movement_finished.emit(hero)
	assert_eq(_animation_count(fixture.manager, &"guard"), 1)
	assert_eq(_animation_count(fixture.manager, &"impact"), 1)
	EventBus.unit_visual_movement_finished.emit(hero)
	assert_eq(_animation_count(fixture.manager, &"guard"), 1)


func test_rampart_uses_only_registered_boundary_cells_and_expires_with_them() -> void:
	var fixture := _fixture()
	var hero: Unit = fixture.hero
	fixture.field.grid.move_unit(hero.grid_pos, Vector2i(1, 0))
	hero.facing_dir = Vector2i.RIGHT
	hero.add_sourced_shield(&"guard_test", 20, hero, {"tags": [&"guard"]})
	fixture.adapter._apply_guard_directive(hero, {"kind": &"temporary_barrier", "line_length": 3})
	fixture.manager._bind_barrier_visuals(fixture.adapter)
	assert_eq(fixture.adapter.barrier_cells().size(), 2)
	assert_eq(_animation_count(fixture.manager, &"barrier"), 2)
	for effect in _active_effects(fixture.manager):
		var state: Dictionary = effect.get_visual_runtime_state()
		assert_eq(state.phase, &"hold")
		assert_true(fixture.adapter.barrier_cells().has(state.cell))
	var snapshot: Array = fixture.adapter.barrier_visual_entries()
	snapshot[0].cells.clear()
	assert_eq(fixture.adapter.barrier_cells().size(), 2, "Presentation cannot edit registered cells.")
	fixture.adapter._on_activation_started(hero)
	assert_true(fixture.adapter.barrier_cells().is_empty())
	assert_eq(_animation_count(fixture.manager, &"barrier"), 0)


func test_departure_cleanup_cancels_flights_barriers_and_arrival_contexts() -> void:
	var fixture := _fixture()
	var flight: Node = fixture.manager.play_spell_vfx(fixture.hero, SHOT, fixture.enemy.grid_pos)
	fixture.manager._achilles_arrivals[fixture.hero] = {"destination": Vector2i(3, 1)}
	fixture.manager.unregister_battle_view()
	assert_true(flight.get_visual_runtime_state().closed)
	assert_true(fixture.manager._achilles_flights.is_empty())
	assert_true(fixture.manager._achilles_arrivals.is_empty())
	assert_true(fixture.manager._barrier_bindings.is_empty())


func _fixture(ids: Array[StringName] = []) -> Dictionary:
	var field = Factory.make_battlefield(9, 5)
	var hero := Factory.make_unit("Achille", 0)
	var enemy := Factory.make_unit("Target", 1)
	hero.unit_id = &"achilles"
	hero.attack_power.base_value = 40
	hero.crit_chance.base_value = 0
	hero.esquive.base_value = 0
	enemy.esquive.base_value = 0
	hero.spells.assign([STRIKE, DASH, SHOT, GUARD])
	field.grid.place_unit(hero, Vector2i(1, 1))
	field.grid.place_unit(enemy, Vector2i(4, 1))
	hero.mastery_runtime = MasteryReactiveRuntimeService.new()
	for node_id in ids:
		var node := CATALOG.node_catalog().get(node_id) as SkillTreeNodeData
		assert_not_null(node, str(node_id))
		if node != null:
			hero.mastery_nodes.append(node)
	assert_true(hero.mastery_runtime.configure_from_nodes(hero.mastery_nodes).is_empty())
	var adapter := MasteryCombatAdapter.new()
	adapter.configure(field.grid, field.caster, field.terrain, field.pathfinder, [hero, enemy])
	var view := GridView.new()
	add_child_autofree(view)
	var manager := EffectManager.new()
	manager._achilles_frames = _frames()
	manager._achilles_source_frames = {
		&"paris": _additional_frames([&"fire", &"frost", &"hellfire", &"impact"]),
		&"philosopher": _additional_frames([&"heal"]),
		&"lightning": _additional_frames([&"arrow_lightning", &"impact_lightning"]),
	}
	add_child_autofree(manager)
	manager.register_battle_view(view)
	var fixture := {"field": field, "hero": hero, "enemy": enemy, "adapter": adapter,
		"view": view, "manager": manager}
	_fixtures.append(fixture)
	return fixture


func _active_effects(manager: EffectManager) -> Array[Node]:
	var result: Array[Node] = []
	for effect in manager._achilles_effects:
		if is_instance_valid(effect) and not effect.get_visual_runtime_state().closed:
			result.append(effect)
	return result


func _animation_count(manager: EffectManager, animation: StringName) -> int:
	var count := 0
	for effect in _active_effects(manager):
		if effect.get_visual_runtime_state().animation == animation:
			count += 1
	return count


func _effect() -> AchillesSpellSpriteVFX:
	var effect := FX.new()
	add_child_autofree(effect)
	effect.configure(_frames(), {"spell_id": SHOT.spell_id, "action_family": &"shot"},
		Vector2(0, 20), [Vector2(100, 20)], 32.0)
	return effect


func _frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	for animation in [&"arrow", &"impact", &"sweep", &"guard", &"dust", &"barrier"]:
		frames.add_animation(animation)
		for _index in 4:
			var texture := GradientTexture2D.new()
			texture.width = 16
			texture.height = 16
			frames.add_frame(animation, texture)
	return frames


func test_authored_evolution_clips_are_selected_for_flight_and_the_confirmed_hit() -> void:
	var frames := _evolved_frames()
	for variant in ["reach", "heavy", "piercing", "death_line", "volley"]:
		var effect := FX.new()
		add_child_autofree(effect)
		var projectile := StringName("arrow_" + variant)
		var impact := StringName("impact_" + variant)
		effect.configure(frames, {"action_family": &"shot", "projectile_animation": projectile,
			"impact_animation": impact, "projectile_scale": Vector2(1.3, 0.7)},
			Vector2(0, 20), [Vector2(100, 20)], 32.0)
		effect.start_flight(0.2)
		effect.set_process(false)
		assert_eq(effect.get_visual_runtime_state().animation, projectile)
		assert_false(effect.get_visual_runtime_state().used_animation_fallback)
		assert_eq(effect._sprites[0].texture, frames.get_frame_texture(projectile, 0))
		assert_eq(effect._sprites[0].global_scale, Vector2(2, 2), "Native art keeps its authored proportions.")
		effect.advance_simulation(0.2)
		assert_false(effect.get_visual_runtime_state().impact_reached)
		effect.confirm_impact([Vector2(100, 20)])
		assert_eq(effect.get_visual_runtime_state().animation, impact)
		assert_eq(effect._sprites[0].texture, frames.get_frame_texture(impact, 0))
		assert_true(effect.get_visual_runtime_state().impact_reached)


func test_legacy_effect_atlas_has_an_explicit_readable_evolution_fallback() -> void:
	var effect := FX.new()
	add_child_autofree(effect)
	effect.configure(_frames(), {"action_family": &"shot", "projectile_animation": &"arrow_piercing",
		"impact_animation": &"impact_piercing", "projectile_scale": Vector2(1.2, 0.8)},
		Vector2(0, 20), [Vector2(100, 20)], 32.0)
	effect.start_flight(0.2)
	effect.set_process(false)
	var state := effect.get_visual_runtime_state()
	assert_eq(state.requested_animation, &"arrow_piercing")
	assert_eq(state.animation, &"arrow")
	assert_true(state.used_animation_fallback)
	assert_almost_eq(effect._sprites[0].global_scale, Vector2(2.4, 1.6), Vector2.ONE * 0.001)
	effect.confirm_impact([Vector2(100, 20)])
	assert_eq(effect.get_visual_runtime_state().requested_animation, &"impact_piercing")
	assert_eq(effect.get_visual_runtime_state().animation, &"impact")
	assert_true(effect.get_visual_runtime_state().used_animation_fallback)


func test_trails_remain_behind_each_real_arrow_and_are_removed_on_confirmation() -> void:
	var effect := FX.new()
	add_child_autofree(effect)
	var points: Array[Vector2] = [Vector2(100, 20), Vector2(100, 60), Vector2(100, -20)]
	effect.configure(_evolved_frames(), {"action_family": &"shot",
		"projectile_animation": &"arrow_volley", "impact_animation": &"impact_volley",
		"projectile_trail_count": 2}, Vector2(0, 20), points, 32.0)
	effect.start_flight(0.2)
	effect.set_process(false)
	assert_eq(effect.get_visual_runtime_state().head_count, 3)
	assert_eq(effect.get_visual_runtime_state().trail_count, 6)
	effect.advance_simulation(0.1)
	for index in points.size():
		var head := effect._sprites[index]
		assert_eq(head.global_position, Vector2(0, 20).lerp(points[index], 0.5))
		for tail_index in 2:
			var tail := effect._trails[index * 2 + tail_index]
			assert_gte(tail.global_position.x, 0.0)
			assert_lt(tail.global_position.x, head.global_position.x)
			assert_gt(tail.modulate.a, 0.0)
			assert_lte(tail.modulate.a, 0.3)
	assert_eq(effect.get_visual_runtime_state().targets, points, "Trails never fabricate fan cells.")
	effect.confirm_impact([points[1]])
	assert_true(effect._trails.is_empty())
	assert_eq(effect.get_visual_runtime_state().head_count, 1)
	assert_eq(effect._sprites[0].global_position, points[1], "Only the actual damaged cell receives an impact.")


func test_resolved_automatic_shot_uses_its_dedicated_impact_without_a_flight() -> void:
	var effect := FX.new()
	add_child_autofree(effect)
	effect.configure(_evolved_frames(), {"action_family": &"shot",
		"projectile_animation": &"arrow_death_line", "impact_animation": &"impact_death_line",
		"automatic": true, "projectile_trail_count": 3},
		Vector2(0, 20), [Vector2(100, 20)], 32.0)
	effect.start_burst(&"impact", 0.16)
	effect.set_process(false)
	assert_eq(effect.get_visual_runtime_state().animation, &"impact_death_line")
	assert_true(effect.get_visual_runtime_state().automatic)
	assert_eq(effect.get_visual_runtime_state().trail_count, 0)
	assert_true(effect.get_visual_runtime_state().impact_reached)


func test_real_factory_uses_evolved_art_and_preserves_the_chosen_origin_snapshot() -> void:
	var fixture := _fixture([&"achilles_chiron_centaur_volley"])
	fixture.manager._achilles_frames = _evolved_frames()
	fixture.adapter._data(fixture.hero).origin = {"spell_id": SHOT.spell_id, "cell": Vector2i(2, 1)}
	var flight: Node = fixture.manager.play_spell_vfx(fixture.hero, SHOT, fixture.enemy.grid_pos)
	flight.set_process(false)
	var state: Dictionary = flight.get_visual_runtime_state()
	assert_eq(state.animation, &"arrow_volley")
	assert_false(state.used_animation_fallback)
	assert_eq(state.head_count, 3)
	assert_eq(state.cast_distance, 2)
	assert_true(state.alternate_origin)
	assert_eq(fixture.hero.grid_pos, Vector2i(1, 1))
	assert_eq(fixture.adapter.projectile_origin(fixture.hero, SHOT), Vector2i(2, 1),
		"Reading presentation does not consume the chosen origin.")


func _evolved_frames() -> SpriteFrames:
	var frames := _frames()
	for variant in ["reach", "heavy", "piercing", "death_line", "volley"]:
		for prefix in ["arrow_", "impact_"]:
			var animation := StringName(prefix + variant)
			frames.add_animation(animation)
			for _index in 4:
				var texture := GradientTexture2D.new()
				texture.width = 16
				texture.height = 16
				frames.add_frame(animation, texture)
	return frames

func test_elemental_sources_keep_their_art_palette_and_confirmed_impact() -> void:
	var fixture := _fixture()
	var catalog := ExpeditionBuildCatalog.new()
	for entry in [
		["exp_braise", &"paris", &"fire", &"hellfire"],
		["exp_givre", &"paris", &"frost", &"frost"],
		["exp_foudre", &"lightning", &"arrow_lightning", &"impact_lightning"],
	]:
		var spell := catalog.get_spell(entry[0])
		var hp: int = fixture.enemy.current_hp
		var flight: Node = fixture.manager.play_spell_vfx(fixture.hero, spell, fixture.enemy.grid_pos)
		assert_not_null(flight, entry[0])
		if flight == null:
			continue
		flight.set_process(false)
		var state: Dictionary = flight.get_visual_runtime_state()
		assert_eq(state.effects_source, entry[1])
		assert_eq(state.animation, entry[2])
		assert_false(state.used_source_fallback)
		var frames: SpriteFrames = fixture.manager._achilles_source_frames[entry[1]]
		assert_eq(flight._sprites[0].texture, frames.get_frame_texture(entry[2], 0))
		assert_eq(flight._sprites[0].modulate, Color.WHITE, "Authored elemental colors stay intact.")
		flight.advance_simulation(0.1)
		assert_eq(fixture.enemy.current_hp, hp, "Rendering does not apply combat damage.")
		assert_false(flight.get_visual_runtime_state().impact_reached)
		fixture.manager._on_spell_cast(fixture.hero, spell, {"cell": fixture.enemy.grid_pos,
			"visual_impact_cells": [fixture.enemy.grid_pos], "damaged_enemies": [fixture.enemy]})
		assert_eq(flight.get_visual_runtime_state().animation, entry[3])
		assert_eq(flight._sprites[0].texture, frames.get_frame_texture(entry[3], 0))
		assert_true(flight.get_visual_runtime_state().impact_reached)
		assert_true(fixture.manager._achilles_flights.is_empty())


func test_native_expedition_volley_uses_actual_cross_cells_and_line_keeps_one_arrow() -> void:
	var fixture := _fixture()
	var catalog := ExpeditionBuildCatalog.new()
	var spell := catalog.get_spell("exp_braise_mutation")
	var target: Vector2i = fixture.enemy.grid_pos
	var flight: Node = fixture.manager.play_spell_vfx(fixture.hero, spell, target)
	assert_not_null(flight)
	if flight == null:
		return
	flight.set_process(false)
	var cells: Array = fixture.field.caster.get_aoe_cells(spell, target, fixture.hero.grid_pos)
	var expected: Array[Vector2] = []
	for cell in cells:
		expected.append(fixture.manager._impact_cell_position(cell))
	assert_gt(cells.size(), 1)
	assert_eq(flight.get_visual_runtime_state().targets, expected)
	assert_eq(flight.get_visual_runtime_state().head_count, cells.size())
	var line := catalog.get_spell("exp_rupture_legend")
	var piercing: Node = fixture.manager.play_spell_vfx(fixture.hero, line, target)
	assert_not_null(piercing)
	if piercing != null:
		piercing.set_process(false)
		assert_eq(piercing.get_visual_runtime_state().head_count, 1)
		assert_eq(piercing.get_visual_runtime_state().target, fixture.manager._impact_cell_position(target))


func test_failed_elemental_cast_cancels_flight_and_ground_change_has_only_real_impact() -> void:
	var fixture := _fixture()
	var spell := ExpeditionBuildCatalog.new().get_spell("exp_braise")
	var flight: Node = fixture.manager.play_spell_vfx(fixture.hero, spell, fixture.enemy.grid_pos)
	assert_not_null(flight)
	if flight == null:
		return
	fixture.manager._on_spell_cast(fixture.hero, spell, {"failed": true})
	assert_true(flight.get_visual_runtime_state().closed)
	assert_false(flight.get_visual_runtime_state().impact_reached)
	assert_true(fixture.manager._achilles_flights.is_empty())
	# A direct/no-delay resolution never starts a projectile after its fact.
	spell = spell.duplicate(true) as Spell
	spell.impact_delay_seconds = 0.0
	var ground := Vector2i(3, 2)
	fixture.manager._on_spell_cast(fixture.hero, spell, {
		"cell": ground, "visual_impact_cells": [], "terrain_changed": [ground]})
	var effects := _active_effects(fixture.manager)
	assert_eq(effects.size(), 1)
	if effects.is_empty():
		return
	assert_eq(effects[0].get_visual_runtime_state().animation, &"hellfire")
	assert_eq(effects[0].get_visual_runtime_state().targets,
		[fixture.manager._impact_cell_position(ground)])
	assert_eq(effects[0].get_visual_runtime_state().phase, &"impact")
	assert_true(fixture.manager._achilles_flights.is_empty())


func test_expedition_melee_fire_uses_its_zone_and_impact_art() -> void:
	var fixture := _fixture()
	var spell := ExpeditionBuildCatalog.new().get_spell("exp_serment_brasier")
	fixture.manager._on_spell_cast(fixture.hero, spell, {
		"cell": fixture.hero.grid_pos, "visual_impact_cells": [fixture.enemy.grid_pos]})
	var effects := _active_effects(fixture.manager)
	assert_eq(effects.size(), 2, "One area gesture and one confirmed victim impact.")
	for effect in effects:
		assert_eq(effect.get_visual_runtime_state().animation, &"hellfire")
		assert_eq(effect.get_visual_runtime_state().effects_source, &"paris")
		assert_false(effect.get_visual_runtime_state().used_animation_fallback)


func test_expedition_heal_requires_recovery_and_movement_heal_waits_for_arrival_once() -> void:
	var fixture := _fixture()
	var catalog := ExpeditionBuildCatalog.new()
	var heal := catalog.get_spell("exp_souffle")
	fixture.manager._on_spell_cast(fixture.hero, heal,
		{"cell": fixture.hero.grid_pos, "healing_total": 0, "healed_units": []})
	assert_eq(_animation_count(fixture.manager, &"heal"), 0)
	fixture.manager._on_spell_cast(fixture.hero, heal,
		{"cell": fixture.hero.grid_pos, "healing_total": 12, "healed_units": [fixture.hero]})
	assert_eq(_animation_count(fixture.manager, &"heal"), 1)
	var recovery: Node = _active_effects(fixture.manager)[0]
	assert_eq(recovery.get_visual_runtime_state().effects_source, &"philosopher")
	assert_eq(recovery.get_visual_runtime_state().target,
		fixture.manager._impact_cell_position(fixture.hero.grid_pos))
	var march := catalog.get_spell("exp_marche")
	var presentation := AchillesSpellVisualResolver.resolve(march, fixture.hero)
	presentation["origin_cell"] = fixture.hero.grid_pos
	var destination := Vector2i(3, 1)
	fixture.field.grid.move_unit(fixture.hero.grid_pos, destination)
	fixture.manager._on_spell_cast(fixture.hero, march, {
		"cell": destination, "movement_count": 2, "healing_total": 8,
		"healed_units": [fixture.hero], "visual_presentation": presentation})
	assert_eq(_animation_count(fixture.manager, &"heal"), 1, "The second heal waits for visible arrival.")
	EventBus.unit_visual_movement_finished.emit(fixture.hero)
	assert_eq(_animation_count(fixture.manager, &"heal"), 2)
	EventBus.unit_visual_movement_finished.emit(fixture.hero)
	assert_eq(_animation_count(fixture.manager, &"heal"), 2, "Repeated arrival does not replay recovery.")


func test_elemental_source_can_borrow_utility_clip_then_restore_its_native_source() -> void:
	var fixture := _fixture()
	var frames: SpriteFrames = fixture.manager._achilles_source_frames[&"paris"]
	var effect := FX.new()
	add_child_autofree(effect)
	effect.configure(frames, {"effects_source": &"paris", "projectile_animation": &"fire",
		"impact_animation": &"hellfire"}, Vector2.ZERO, [Vector2(100, 20)], 32, _frames())
	effect.start_burst(&"guard")
	effect.set_process(false)
	assert_eq(effect.get_visual_runtime_state().animation, &"guard")
	assert_true(effect.get_visual_runtime_state().used_source_fallback)
	effect.start_flight(0.2)
	effect.set_process(false)
	assert_eq(effect.get_visual_runtime_state().animation, &"fire")
	assert_false(effect.get_visual_runtime_state().used_source_fallback)
	assert_eq(effect._sprites[0].texture, frames.get_frame_texture(&"fire", 0))


func _additional_frames(names: Array[StringName]) -> SpriteFrames:
	var frames := SpriteFrames.new()
	for animation in names:
		frames.add_animation(animation)
		for _index in 4:
			var texture := GradientTexture2D.new()
			texture.width = 16
			texture.height = 16
			frames.add_frame(animation, texture)
	return frames
