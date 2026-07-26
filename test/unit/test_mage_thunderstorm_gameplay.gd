extends GutTest

const Factory = preload("res://test/support/factory.gd")

const THUNDERSTORM_PATH := "res://data/spells/Mage/tempete_orageuse.tres"
const VFX_SCENE_PATH := "res://asset/sorts/tempete_orageuse/tempete_orageuse_vfx.tscn"
const VFX_SCRIPT_PATH := "res://asset/sorts/tempete_orageuse/tempete_orageuse_vfx.gd"


class FakeBattleView:
	extends Node2D

	func grid_to_local(cell: Vector2i) -> Vector2:
		return Vector2(cell.x * 64.0, cell.y * 32.0)


func _spell() -> Spell:
	return load(THUNDERSTORM_PATH) as Spell


func _context_with_three_targets() -> Dictionary:
	var battlefield := Factory.make_battlefield(8, 5)
	var mage := Factory.make_unit("Mage", 0)
	battlefield.grid.place_unit(mage, Vector2i(0, 2))
	var targets: Array[Unit] = []
	for cell in [Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3)]:
		var target := Factory.make_unit("Cible", 1)
		battlefield.grid.place_unit(target, cell)
		targets.append(target)
	return {
		"battlefield": battlefield,
		"mage": mage,
		"targets": targets,
		"cell": Vector2i(3, 2),
	}


func test_resource_matches_the_locked_thunderstorm_contract() -> void:
	var spell := _spell()
	assert_eq(spell.spell_id, &"mage_thunderstorm")
	assert_eq(spell.discipline_id, &"mage_lightning")
	assert_eq(spell.spell_name, "Tempête orageuse")
	assert_eq([spell.ap_cost, spell.spell_range, spell.damage], [3, 5, 7])
	assert_true(spell.needs_line_of_sight)
	assert_true(spell.can_target_enemy)
	assert_true(spell.can_target_free_cell)
	assert_eq(spell.aoe_shape, Spell.AoeShape.SQUARE)
	assert_eq(spell.aoe_size, 1)
	assert_eq(spell.element, Spell.Element.LIGHTNING)
	assert_almost_eq(spell.impact_delay_seconds, 0.31, 0.0001)
	assert_eq(spell.vfx_placement, Spell.VfxPlacement.TARGET_CELL)
	assert_eq(spell.vfx_scene.resource_path, VFX_SCENE_PATH)
	assert_null(spell.terrain_effect)
	assert_null(spell.applied_status)
	assert_eq([spell.push_distance, spell.ap_drain], [0, 0])


func test_begin_cast_commits_costs_but_waits_for_one_explicit_resolution() -> void:
	var context_data := _context_with_three_targets()
	var battlefield: Factory.Battlefield = context_data["battlefield"]
	var mage: Unit = context_data["mage"]
	var targets: Array = context_data["targets"]
	var context: CastContext = battlefield.caster.begin_cast(
		mage,
		_spell(),
		context_data["cell"] as Vector2i,
	)
	assert_false(context.failed)
	assert_true(context.costs_committed)
	assert_eq(mage.current_ap, 3)
	assert_true(targets.all(func(target): return target.current_hp == 100))
	var emissions := {"count": 0}
	var callback := func(_caster, _spell_data, _report): emissions["count"] += 1
	EventBus.spell_cast.connect(callback)
	var report: Dictionary = battlefield.caster.resolve_cast(context)
	assert_eq(report["affected_units"].size(), 3)
	assert_true(targets.all(func(target): return target.current_hp == 93))
	battlefield.caster.resolve_cast(context)
	EventBus.spell_cast.disconnect(callback)
	assert_true(targets.all(func(target): return target.current_hp == 93))
	assert_eq(emissions["count"], 1)


func test_refused_cast_spends_nothing_and_cannot_be_scheduled() -> void:
	var battlefield := Factory.make_battlefield(5, 3)
	var mage := Factory.make_unit("Mage", 0)
	battlefield.grid.place_unit(mage, Vector2i(0, 1))
	var context := battlefield.caster.begin_cast(
		mage,
		_spell(),
		Vector2i(99, 99),
	)
	assert_true(context.failed)
	assert_eq(mage.current_ap, 6)
	var scheduler := SpellImpactScheduler.new()
	add_child_autofree(scheduler)
	assert_false(scheduler.schedule(context, 0.31))
	assert_eq(scheduler.get_pending_count(), 0)


func test_scheduler_resolves_once_after_the_data_driven_delay() -> void:
	var context_data := _context_with_three_targets()
	var battlefield: Factory.Battlefield = context_data["battlefield"]
	var context: CastContext = battlefield.caster.begin_cast(
		context_data["mage"] as Unit,
		_spell(),
		context_data["cell"] as Vector2i,
	)
	var scheduler := SpellImpactScheduler.new()
	add_child_autofree(scheduler)
	var observed := {"count": 0}
	scheduler.impact_due.connect(
		func(due_context):
			observed["count"] += 1
			battlefield.caster.resolve_cast(due_context)
	)
	assert_true(scheduler.schedule(context, _spell().impact_delay_seconds))
	var timer := scheduler.get_child(0) as Timer
	assert_not_null(timer)
	assert_almost_eq(timer.wait_time, 0.31, 0.0001)
	await get_tree().process_frame
	assert_eq(observed["count"], 0)
	await get_tree().create_timer(0.4).timeout
	assert_eq(observed["count"], 1)
	assert_eq(scheduler.get_pending_count(), 0)
	assert_true(context_data["targets"].all(
		func(target): return target.current_hp == 93
	))


func test_scheduler_cleanup_prevents_late_impact() -> void:
	var context_data := _context_with_three_targets()
	var battlefield: Factory.Battlefield = context_data["battlefield"]
	var context: CastContext = battlefield.caster.begin_cast(
		context_data["mage"] as Unit,
		_spell(),
		context_data["cell"] as Vector2i,
	)
	var scheduler := SpellImpactScheduler.new()
	add_child(scheduler)
	var impacts := {"count": 0}
	scheduler.impact_due.connect(func(_ctx): impacts["count"] += 1)
	assert_true(scheduler.schedule(context, 0.31))
	scheduler.cancel_all()
	remove_child(scheduler)
	scheduler.free()
	await get_tree().create_timer(0.36).timeout
	assert_eq(impacts["count"], 0)
	assert_false(context.resolved)
	assert_true(context_data["targets"].all(
		func(target): return target.current_hp == 100
	))


func test_cast_released_before_caster_death_still_resolves_normally() -> void:
	var context_data := _context_with_three_targets()
	var battlefield: Factory.Battlefield = context_data["battlefield"]
	var mage: Unit = context_data["mage"]
	var context: CastContext = battlefield.caster.begin_cast(
		mage,
		_spell(),
		context_data["cell"] as Vector2i,
	)
	mage.is_alive = false
	mage.current_hp = 0
	var report := battlefield.caster.resolve_cast(context)
	assert_false(report.get("failed", false))
	assert_true(context_data["targets"].all(
		func(target): return target.current_hp == 93
	))


func test_target_cell_vfx_uses_vfx_layer_and_not_projectile_mount_origin() -> void:
	var battle_root := Node2D.new()
	add_child(battle_root)
	var battle_view := FakeBattleView.new()
	battle_root.add_child(battle_view)
	var vfx_layer := Node2D.new()
	vfx_layer.name = "VFXLayer"
	battle_root.add_child(vfx_layer)
	VFXManager.register_battle_view(battle_view)
	var caster := Factory.make_unit("Mage", 0)
	caster.grid_pos = Vector2i(1, 1)
	var target_cell := Vector2i(3, 2)
	var vfx := VFXManager.play_spell_vfx(caster, _spell(), target_cell) as Node2D
	assert_not_null(vfx)
	assert_same(vfx.get_parent(), vfx_layer)
	assert_eq(
		vfx.global_position,
		battle_view.to_global(battle_view.grid_to_local(target_cell)),
	)
	VFXManager.register_battle_view(null)
	battle_root.queue_free()
	await get_tree().process_frame


func test_vfx_is_instantiable_and_cancel_before_impact_emits_nothing_late() -> void:
	var vfx := (load(VFX_SCENE_PATH) as PackedScene).instantiate()
	add_child(vfx)
	var impacts := {"count": 0}
	vfx.connect(&"impact_reached", func(): impacts["count"] += 1)
	await get_tree().create_timer(0.08).timeout
	vfx.call(&"cancel")
	await get_tree().process_frame
	assert_false(is_instance_valid(vfx))
	await get_tree().create_timer(0.3).timeout
	assert_eq(impacts["count"], 0)


func test_vfx_script_has_no_damage_or_gameplay_authority() -> void:
	var source := FileAccess.get_file_as_string(VFX_SCRIPT_PATH).to_lower()
	for forbidden in [
		"take_damage",
		"apply_damage",
		"damage_resolver",
		"eventbus",
		"spellcaster",
		"unit.",
	]:
		assert_false(source.contains(forbidden), forbidden)
	var caster_source := FileAccess.get_file_as_string(
		"res://core/spell_caster.gd"
	).to_lower()
	assert_false(caster_source.contains("mage_thunderstorm"))
	assert_false(caster_source.contains("\"mage\""))
