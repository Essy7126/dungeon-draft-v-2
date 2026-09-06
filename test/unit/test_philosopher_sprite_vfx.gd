extends GutTest

const FX := preload("res://vfx/philosopher_mage/philosopher_spell_sprite_vfx.gd")
const Factory := preload("res://test/support/factory.gd")
const AXIOM: Spell = preload("res://data/spells/enemies/philosopher_axiom.tres")
const HEAL: Spell = preload("res://data/spells/enemies/philosopher_mending.tres")
const SHIELD: Spell = preload("res://data/spells/enemies/philosopher_aegis.tres")
const CONTROL: Spell = preload("res://data/spells/enemies/philosopher_aporia.tres")
const REPEL: Spell = preload("res://data/spells/enemies/philosopher_refutation.tres")

var _fixtures: Array[Dictionary] = []


class GridView:
	extends Node2D

	func grid_to_local(cell: Vector2i) -> Vector2:
		return Vector2((cell.x - cell.y) * 64.0, (cell.x + cell.y) * 32.0)


class UnitProxy:
	extends Node2D
	var unit: Unit


class EffectManager:
	extends "res://core/vfx_manager.gd"


func after_each() -> void:
	for fixture in _fixtures:
		fixture.manager.unregister_battle_view()
	_fixtures.clear()


func test_projectile_moves_before_confirmation_and_cannot_invent_damage_feedback() -> void:
	var effect := _effect()
	effect.start_flight(0.2)
	effect.set_process(false)
	effect.advance_simulation(0.1)
	assert_eq(effect.get_debug_state().phase, &"flight")
	assert_eq(effect.get_debug_state().animation, &"bolt")
	assert_eq(effect.get_debug_state().sprite_count, 1)
	assert_false(effect.get_debug_state().impact_reached)
	assert_almost_eq(effect._sprites[0].global_position, Vector2(50, 20), Vector2(0.001, 0.001))
	effect.advance_simulation(0.2)
	assert_eq(effect.get_debug_state().phase, &"awaiting_impact")
	assert_false(effect.get_debug_state().impact_reached)
	effect.confirm_impact([Vector2(100, 20)])
	assert_eq(effect.get_debug_state().phase, &"impact")
	assert_eq(effect.get_debug_state().animation, &"impact")
	assert_true(effect.get_debug_state().impact_reached)


func test_missed_or_stale_projectile_cancels_without_fabricated_impact() -> void:
	var effect := _effect()
	effect.start_flight(0.2)
	effect.confirm_impact([])
	assert_true(effect.get_debug_state().closed)
	assert_false(effect.get_debug_state().impact_reached)
	var stale := _effect()
	stale.start_flight(0.2)
	stale.advance_simulation(1.3)
	assert_true(stale.get_debug_state().closed)
	stale.confirm_impact([Vector2(100, 20)])
	assert_false(stale.visible)
	assert_false(stale.get_debug_state().impact_reached)


func test_real_axiom_flight_is_confirmed_once_after_actual_hp_loss() -> void:
	var fixture := _fixture()
	var context: CastContext = fixture.field.caster.begin_cast(fixture.mage, AXIOM, fixture.hero.grid_pos)
	assert_false(context.failed)
	assert_eq(AXIOM.impact_delay_seconds, 0.2)
	var before_hp := int(fixture.hero.current_hp)
	var effect: Node = fixture.manager.play_spell_vfx(fixture.mage, AXIOM, fixture.hero.grid_pos)
	assert_not_null(effect)
	if effect == null:
		return
	assert_eq(fixture.manager.play_spell_vfx(fixture.mage, AXIOM, fixture.hero.grid_pos), effect,
		"Repeated release presentation does not restart a second projectile")
	effect.set_process(false)
	effect.advance_simulation(0.1)
	assert_eq(fixture.hero.current_hp, before_hp)
	assert_false(effect.get_debug_state().impact_reached)
	var report: Dictionary = fixture.field.caster.resolve_cast(context)
	assert_false(report.get("failed", false))
	assert_lt(fixture.hero.current_hp, before_hp)
	assert_eq(effect.get_debug_state().phase, &"impact")
	assert_true(fixture.manager._philosopher_flights.is_empty())
	fixture.manager._on_spell_cast(fixture.mage, AXIOM, report)
	assert_eq(_active(fixture.manager).size(), 1, "One resolved cast has one visible impact")


func test_direct_axiom_resolution_has_only_real_impact_and_no_late_flight() -> void:
	var fixture := _fixture()
	fixture.field.caster.cast(fixture.mage, AXIOM, fixture.hero.grid_pos)
	assert_eq(_active(fixture.manager).size(), 1)
	assert_eq(_active(fixture.manager)[0].get_debug_state().phase, &"impact")
	assert_true(fixture.manager._philosopher_flights.is_empty())


func test_failed_cast_cancels_a_pending_projectile() -> void:
	var fixture := _fixture()
	var effect: Node = fixture.manager.play_spell_vfx(fixture.mage, AXIOM, fixture.hero.grid_pos)
	fixture.manager._on_spell_cast(fixture.mage, AXIOM, {"failed": true})
	assert_true(effect.get_debug_state().closed)
	assert_false(effect.get_debug_state().impact_reached)
	assert_true(fixture.manager._philosopher_flights.is_empty())


func test_healing_effect_requires_actual_healing_and_belongs_to_recipient() -> void:
	var fixture := _fixture()
	var ally: Unit = fixture.ally
	fixture.field.caster.cast(fixture.mage, HEAL, ally.grid_pos)
	assert_eq(_active(fixture.manager).size(), 0, "Full HP is not a healing benefit")
	fixture.mage.current_ap = 6
	fixture.mage.reset_ability_runtime()
	ally.current_hp -= 40
	var report: Dictionary = fixture.field.caster.cast(fixture.mage, HEAL, ally.grid_pos)
	assert_eq(report.healing_by_unit[ally], 22)
	assert_eq(_active(fixture.manager).size(), 1)
	var effect: Node = _active(fixture.manager)[0]
	assert_eq(effect.get_debug_state().animation, &"heal")
	assert_eq(effect.get_debug_state().targets, [fixture.manager._impact_cell_position(ally.grid_pos)])
	fixture.manager._on_spell_cast(fixture.mage, HEAL, report)
	assert_eq(_active(fixture.manager).size(), 1)


func test_shield_hold_follows_recipient_and_ends_when_its_own_source_is_consumed() -> void:
	var fixture := _fixture()
	var ally: Unit = fixture.ally
	fixture.field.caster.cast(fixture.mage, SHIELD, ally.grid_pos)
	assert_eq(_active(fixture.manager).size(), 1)
	var effect: Node = _active(fixture.manager)[0]
	effect.set_process(false)
	effect.advance_simulation(0.31)
	assert_eq(effect.get_debug_state().phase, &"hold")
	assert_eq(effect.get_debug_state().binding_id, SHIELD.spell_id)
	var target_before: Vector2 = effect.get_debug_state().targets[0]
	var view: Node2D = fixture.ally_view
	view.position += Vector2(32, 16)
	effect.advance_simulation(4.0)
	assert_eq(effect.get_debug_state().targets[0], target_before + Vector2(32, 16))
	ally.add_shield(50, ally, {"shield_source_id": &"other_shield"})
	ally.clear_shield_source(SHIELD.spell_id)
	assert_gt(ally.current_shield, 0)
	effect.advance_simulation(0.01)
	assert_true(effect.get_debug_state().closed, "Other shields cannot keep the philosopher aura alive")


func test_control_hold_ends_on_status_removal_and_does_not_lock_to_cast_cell() -> void:
	var fixture := _fixture()
	var hero: Unit = fixture.hero
	fixture.field.caster.cast(fixture.mage, CONTROL, hero.grid_pos)
	assert_true(hero.has_status(CONTROL.applied_status.get_effective_status_id()))
	assert_eq(_active(fixture.manager).size(), 1)
	var effect: Node = _active(fixture.manager)[0]
	effect.set_process(false)
	effect.advance_simulation(0.31)
	assert_eq(effect.get_debug_state().phase, &"hold")
	assert_eq(effect.get_debug_state().animation, &"control")
	var previous: Vector2 = effect.get_debug_state().targets[0]
	fixture.hero_view.position += Vector2(64, 32)
	effect.advance_simulation(0.01)
	assert_eq(effect.get_debug_state().targets[0], previous + Vector2(64, 32))
	hero.remove_status(CONTROL.applied_status.get_effective_status_id())
	effect.advance_simulation(0.01)
	assert_true(effect.get_debug_state().closed)


func test_refutation_impact_uses_cell_before_push() -> void:
	var fixture := _fixture()
	fixture.field.grid.move_unit(fixture.hero.grid_pos, Vector2i(2, 2))
	var original: Vector2i = fixture.hero.grid_pos
	var report: Dictionary = fixture.field.caster.cast(fixture.mage, REPEL, original)
	assert_true(report.pushed)
	assert_ne(fixture.hero.grid_pos, original)
	assert_eq(_active(fixture.manager).size(), 2)
	var animations: Array[StringName] = []
	for effect in _active(fixture.manager):
		animations.append(effect.get_debug_state().animation)
		assert_eq(effect.get_debug_state().targets, [fixture.manager._impact_cell_position(original)])
	assert_has(animations, &"repel")
	assert_has(animations, &"impact")


func test_bound_effect_cleans_up_on_recipient_death_and_view_removal() -> void:
	var fixture := _fixture()
	fixture.field.caster.cast(fixture.mage, SHIELD, fixture.ally.grid_pos)
	var effect: Node = _active(fixture.manager)[0]
	fixture.ally.is_alive = false
	effect.advance_simulation(0.01)
	assert_true(effect.get_debug_state().closed)
	fixture.ally.is_alive = true
	var next: Node = fixture.manager._bind_philosopher_effect(SHIELD, fixture.ally, &"shield", &"shield", SHIELD.spell_id)
	fixture.ally_view.queue_free()
	next.advance_simulation(0.01)
	assert_true(next.get_debug_state().closed)


func test_factory_prunes_freed_nodes_and_unregister_clears_every_effect_registry() -> void:
	var fixture := _fixture()
	var targets: Array[Vector2] = [Vector2(100, 20)]
	for _cycle in 4:
		var effect: Node = fixture.manager._philosopher_burst(AXIOM, &"impact", Vector2.ZERO,
			targets, 0.6, 0.24)
		assert_not_null(effect)
		effect.set_process(false)
		assert_eq(fixture.manager._philosopher_effects.size(), 1)
		effect.advance_simulation(0.24)
		await wait_process_frames(2)
		assert_false(is_instance_valid(effect))
	fixture.field.caster.cast(fixture.mage, SHIELD, fixture.ally.grid_pos)
	var live := _active(fixture.manager)
	assert_eq(live.size(), 1)
	fixture.manager.unregister_battle_view()
	assert_true(live[0].get_debug_state().closed)
	assert_true(fixture.manager._philosopher_effects.is_empty())
	assert_true(fixture.manager._philosopher_holds.is_empty())
	assert_true(fixture.manager._philosopher_flights.is_empty())
	assert_true(fixture.manager._philosopher_resolved_actions.is_empty())


func test_unrelated_caster_cannot_receive_philosopher_art_by_spell_id_alone() -> void:
	var fixture := _fixture()
	assert_false(fixture.manager._is_philosopher_spell(fixture.hero, AXIOM))
	assert_true(fixture.manager._is_philosopher_spell(fixture.mage, AXIOM))
	var unrelated := Spell.new()
	unrelated.spell_id = &"achilles_bronze_guard"
	assert_false(fixture.manager._is_philosopher_spell(fixture.mage, unrelated))




func test_shield_hold_expires_at_the_real_second_recipient_activation() -> void:
	var fixture := _fixture()
	var ally: Unit = fixture.ally
	fixture.field.caster.cast(fixture.mage, SHIELD, ally.grid_pos)
	var effect: Node = _active(fixture.manager)[0]
	effect.set_process(false)
	effect.advance_simulation(0.31)
	ally.start_turn()
	effect.advance_simulation(0.01)
	assert_gt(ally.get_shield_value(SHIELD.spell_id), 0)
	assert_false(effect.get_debug_state().closed)
	ally.start_turn()
	effect.advance_simulation(0.01)
	assert_eq(ally.get_shield_value(SHIELD.spell_id), 0)
	assert_true(effect.get_debug_state().closed)


func _fixture() -> Dictionary:
	var field := Factory.make_battlefield(8, 6)
	var mage := Factory.make_unit("Philosophe", 1)
	var hero := Factory.make_unit("Adversaire", 0)
	var ally := Factory.make_unit("Allie", 1)
	mage.unit_id = &"philosopher_mage"
	mage.spells.assign([AXIOM, HEAL, SHIELD, CONTROL, REPEL])
	field.grid.place_unit(mage, Vector2i(1, 2))
	field.grid.place_unit(hero, Vector2i(3, 2))
	field.grid.place_unit(ally, Vector2i(1, 3))
	var view := GridView.new()
	add_child_autofree(view)
	var hero_view := UnitProxy.new()
	hero_view.unit = hero
	hero_view.add_to_group("unit_views")
	hero_view.position = view.grid_to_local(hero.grid_pos)
	view.add_child(hero_view)
	var ally_view := UnitProxy.new()
	ally_view.unit = ally
	ally_view.add_to_group("unit_views")
	ally_view.position = view.grid_to_local(ally.grid_pos)
	view.add_child(ally_view)
	var manager := EffectManager.new()
	manager._philosopher_frames = _frames()
	add_child_autofree(manager)
	manager.register_battle_view(view)
	var result := {"field": field, "mage": mage, "hero": hero, "ally": ally,
		"view": view, "hero_view": hero_view, "ally_view": ally_view, "manager": manager}
	_fixtures.append(result)
	return result


func _active(manager: EffectManager) -> Array[Node]:
	var result: Array[Node] = []
	for effect in manager._philosopher_effects:
		if is_instance_valid(effect) and not effect.get_debug_state().closed:
			result.append(effect)
	return result


func _effect() -> PhilosopherSpellSpriteVFX:
	var effect := FX.new()
	add_child_autofree(effect)
	effect.configure(_frames(), AXIOM.spell_id, Vector2(0, 20), [Vector2(100, 20)], 32.0)
	return effect


func _frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	for animation in [&"bolt", &"impact", &"heal", &"control", &"shield", &"repel"]:
		frames.add_animation(animation)
		for _index in 4:
			# Synthetic test textures exercise the production timing/factory;
			# all player-visible artwork is supplied by the authored atlas.
			var texture := GradientTexture2D.new()
			texture.width = 16
			texture.height = 16
			frames.add_frame(animation, texture)
	return frames


func test_real_vortex_to_water_preserves_aura_anchor_and_next_projectile_origin_at_height() -> void:
	var fixture := _fixture()
	var mage: Unit = fixture.mage
	mage.visual_scene = load("res://characters/philosopher_mage/PhilosopherMageIsoUnitView.tscn") as PackedScene
	var view_script := load("res://battle/unit_view.gd") as Script
	var mage_view := view_script.new() as Node2D
	var grid_view: Node2D = fixture.view
	grid_view.position = Vector2(240, 180)
	grid_view.scale = Vector2.ONE * 0.85
	grid_view.add_child(mage_view)
	mage_view.setup(mage, false)
	mage_view.position = grid_view.grid_to_local(mage.grid_pos)
	mage_view.apply_painted_presentation(BattlePresentationProfile.new())
	var body := mage_view.get_optional_visual() as Node2D
	body.set_process(false)
	var shield_report: Dictionary = fixture.field.caster.cast(mage, SHIELD, mage.grid_pos)
	assert_false(shield_report.get("failed", false))
	var aura: Node = _active(fixture.manager)[0]
	aura.set_process(false)
	aura.advance_simulation(0.31)
	var aura_offset: Vector2 = aura.get_debug_state().targets[0] - mage_view.global_position

	var entry := Vector2i(2, 2)
	var destination := Vector2i(5, 4)
	assert_true(fixture.field.grid.set_vortex_link(entry, destination))
	fixture.field.terrain.place_effect(destination,
		load("res://data/terrain/eau.tres") as TerrainEffectData)
	fixture.field.terrain.begin_unit_resolution(mage, &"movement")
	mage_view.begin_movement_feedback(mage.grid_pos, entry)
	mage_view.update_movement_stride(0, 1.0)
	assert_true(fixture.field.grid.relocate_unit(mage, entry))
	var relocation: Dictionary = fixture.field.terrain.consume_last_entry_result(mage)
	fixture.field.terrain.end_unit_resolution(mage)
	assert_true(relocation.teleported)
	assert_true(relocation.end_movement)
	assert_eq(mage.grid_pos, destination)
	assert_true(mage.has_status(&"wet"), "The actual destination surface resolves after teleport")
	# Battle projects the resolved cell at its map elevation, then ends feedback.
	mage_view.position = grid_view.grid_to_local(mage.grid_pos) + Vector2(0, -48)
	mage_view.synchronize_external_movement()
	mage_view.end_movement_feedback()
	body.advance_simulation(0.5)
	aura.advance_simulation(0.01)
	assert_eq(body.get_visual_runtime_state().stem, "idle")
	assert_false(aura.get_debug_state().closed)
	assert_almost_eq(aura.get_debug_state().targets[0],
		mage_view.global_position + aura_offset, Vector2(0.001, 0.001))
	assert_almost_eq(aura._sprites[0].global_position,
		mage_view.global_position + aura_offset, Vector2(0.001, 0.001))
	assert_eq(_active(fixture.manager).size(), 1, "Teleport does not duplicate the persistent aura")

	var context: CastContext = fixture.field.caster.begin_cast(mage, AXIOM, fixture.hero.grid_pos)
	assert_false(context.failed)
	var expected_origin: Vector2 = mage_view.get_cast_effect_origin_global()
	var bolt: Node = fixture.manager.play_spell_vfx(mage, AXIOM, fixture.hero.grid_pos)
	assert_not_null(bolt)
	if bolt == null:
		return
	bolt.set_process(false)
	assert_almost_eq(bolt.get_debug_state().origin, expected_origin, Vector2(0.001, 0.001))
	assert_almost_eq(bolt._sprites[0].global_position, expected_origin, Vector2(0.001, 0.001))
	assert_ne(expected_origin, grid_view.to_global(grid_view.grid_to_local(entry)),
		"The projectile cannot originate at the old portal entrance")
	var report: Dictionary = fixture.field.caster.resolve_cast(context)
	assert_false(report.get("failed", false))
	assert_true(bolt.get_debug_state().impact_reached)
	fixture.manager.unregister_battle_view()
	assert_true(aura.get_debug_state().closed)
	assert_true(bolt.get_debug_state().closed)
