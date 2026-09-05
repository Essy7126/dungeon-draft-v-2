extends GutTest

## The real caster, mastery command queue, canonical Achilles UnitView and
## Battle movement tween exercise one transaction across a visual wait.
const UNIT_VIEW := preload("res://battle/unit_view.tscn")
const ACHILLES_DATA := preload("res://data/units/allies/achilles.tres")
const DASH := preload("res://data/spells/achilles/fulminant_dash.tres")
const GUARD := preload("res://data/spells/achilles/bronze_guard.tres")
const CATALOG := preload("res://data/characters/achilles/doctrines/achilles_mastery_catalog.tres")
const Factory := preload("res://test/support/factory.gd")
const START := Vector2i(0, 1)
const DESTINATION := Vector2i(3, 1)
const TARGET_START := Vector2i(4, 1)

var _battle: ArrivalBattle
var _hero: Unit
var _enemy: Unit
var _view
var _adapter: MasteryCombatAdapter
var _events: Array[Dictionary] = []
var _arrivals := 0
var _guard_before := 0
var _ap_before := 0
var _uses_before := 0


class ArrivalBattle:
	extends "res://battle/battle.gd"

	func _ready() -> void:
		pass

	# This fixture has no HUD/grid renderer. Choice arbitration itself is
	# covered by the adapter tests and the real graphical kit harness.
	func _process_mastery_choices_at_safe_point() -> void:
		pass

	func grid_cell_to_parent_local(cell: Vector2i, parent: Node2D) -> Vector2:
		var point := Vector2(float(cell.x - cell.y) * 64.0, float(cell.x + cell.y) * 32.0)
		return parent.to_local(to_global(point))


func before_each() -> void:
	_events.clear()
	_arrivals = 0
	_battle = ArrivalBattle.new()
	add_child(_battle)
	_battle.grid = GridData.new(8, 4)
	_battle.pathfinder = Pathfinder.new(_battle.grid)
	_battle.terrain_effects = TerrainEffects.new(_battle.grid)
	_battle.spell_caster = SpellCaster.new(_battle.grid, _battle.pathfinder, _battle.terrain_effects)
	_battle.turn_state = TurnState.new()
	_hero = Unit.from_data(ACHILLES_DATA)
	for spell_name in ["peleid_strike", "fulminant_dash", "pelion_shot", "bronze_guard"]:
		_hero.spells.append(load("res://data/spells/achilles/%s.tres" % spell_name))
	_enemy = Factory.make_unit("Arrival target", 1)
	_hero.initiative.base_value = 100
	_hero.crit_chance.base_value = 0.0
	_hero.esquive.base_value = 0.0
	_enemy.crit_chance.base_value = 0.0
	_enemy.esquive.base_value = 0.0
	assert_true(_battle.grid.place_unit(_hero, START))
	assert_true(_battle.grid.place_unit(_enemy, TARGET_START))
	_battle.units = [_hero, _enemy]
	_battle.turn_queue = TurnQueue.new()
	_battle.turn_queue.setup(_battle.units)
	assert_true(_battle.turn_queue.advance())
	assert_same(_battle.turn_queue.get_current_unit(), _hero)
	# This isolated mechanism fixture equips the production node; the graphical
	# kit harness separately exercises its full legal progression purchase path.
	var bastion := CATALOG.node_catalog()[&"achilles_aeacus_mobile_bastion"] as SkillTreeNodeData
	_hero.mastery_nodes.assign([bastion])
	_hero.mastery_runtime = MasteryReactiveRuntimeService.new()
	assert_true(_hero.mastery_runtime.configure_from_nodes(_hero.mastery_nodes).is_empty())
	_adapter = MasteryCombatAdapter.new()
	_adapter.configure(_battle.grid, _battle.spell_caster, _battle.terrain_effects, _battle.pathfinder, _battle.units)
	_battle._mastery_adapter = _adapter
	var guard_report := _battle.spell_caster.cast(_hero, GUARD, _hero.grid_pos)
	assert_false(guard_report.get("failed", false), str(guard_report))
	_guard_before = _hero.get_shield_value(&"achilles_bronze_guard")
	_ap_before = _hero.current_ap
	_uses_before = _hero.get_spell_uses(DASH)
	assert_gt(_guard_before, 0)
	_view = UNIT_VIEW.instantiate()
	_battle.add_child(_view)
	_view.setup(_hero)
	_view.position = _battle.grid_cell_to_parent_local(START, _battle)
	_battle._unit_views[_hero] = _view
	EventBus.unit_pushed.connect(_battle._on_unit_pushed)
	EventBus.unit_visual_movement_finished.connect(_on_arrived)
	EventBus.health_damage_taken.connect(_on_health_damage)
	EventBus.action_resolved.connect(_on_action_resolved)


func after_each() -> void:
	EventBus.unit_visual_movement_finished.disconnect(_on_arrived)
	EventBus.health_damage_taken.disconnect(_on_health_damage)
	EventBus.action_resolved.disconnect(_on_action_resolved)
	if is_instance_valid(_battle):
		_battle._begin_battle_shutdown()
		_battle.free()
	_battle = null
	_view = null
	_adapter = null


func test_headless_cast_stays_immediate_and_repeated_resolution_does_not_repay() -> void:
	var context := _battle.spell_caster.begin_cast(_hero, DASH, DESTINATION)
	assert_false(context.failed)
	assert_false(bool(context.get_meta("defer_automatic_reactions", false)))
	var report := _battle.spell_caster.resolve_cast(context)
	_assert_one_payment_and_impact()
	assert_eq(_enemy.grid_pos, Vector2i(5, 1), "The default cast still pushes synchronously")
	assert_eq(_adapter._reaction_commands.size(), 0)
	var snapshot := report.duplicate(true)
	_battle.spell_caster.resolve_cast(context)
	_adapter.flush_automatic()
	_assert_one_payment_and_impact()
	assert_eq(context.report, snapshot, "Deferring presentation must not replace the report contract")


func test_explicit_defer_reserves_but_does_not_execute_or_consume_guard() -> void:
	var context := _battle.spell_caster.begin_cast(_hero, DASH, DESTINATION)
	context.set_meta("defer_automatic_reactions", true)
	_battle.spell_caster.resolve_cast(context)
	assert_eq(_hero.grid_pos, DESTINATION)
	assert_eq(_hero.current_ap, _ap_before - 1)
	assert_eq(_hero.get_spell_uses(DASH), _uses_before + 1)
	_assert_impact_pending()
	assert_eq(_adapter._reaction_commands.size(), 1, "The original command remains in the real queue")
	_battle.spell_caster.resolve_cast(context)
	assert_eq(_adapter._reaction_commands.size(), 1, "An already resolved context cannot enqueue twice")
	_adapter.flush_automatic()
	_adapter.flush_automatic()
	_assert_one_payment_and_impact()


func test_real_battle_waits_for_actual_view_contact_before_bastion_and_action_resolved() -> void:
	assert_true(await _start_real_dash_until_release())
	var context := _battle._deferred_spell_reaction_context
	assert_not_null(context)
	assert_true(bool(context.get_meta("defer_automatic_reactions", false)))
	_assert_impact_pending()
	assert_gt(_view.position.distance_to(_destination_position()), 1.0)
	assert_true(_battle._spell_resolution_pending)
	assert_true(await _until(func(): return not _battle._spell_resolution_pending))
	assert_eq(_arrivals, 1)
	_assert_one_payment_and_impact()
	assert_null(_battle._deferred_spell_reaction_context)
	var damage := _events.filter(func(event): return event.kind == &"damage")
	var finished := _events.filter(func(event): return event.kind == &"action_resolved")
	assert_eq(damage.size(), 1)
	assert_eq(finished.size(), 1)
	if damage.size() == 1 and finished.size() == 1:
		assert_eq(damage[0].arrivals, 1, "Bastion HP loss follows the real movement signal")
		assert_lt(float(damage[0].position_error), 0.01)
		assert_true(damage[0].locked, "The command settles before player input is released")
		assert_lte(int(damage[0].time_usec), int(finished[0].time_usec))
		assert_true(finished[0].locked)
	var snapshot := context.report.duplicate(true)
	_battle.spell_caster.resolve_cast(context)
	_battle._flush_deferred_spell_reactions()
	_assert_one_payment_and_impact()
	assert_eq(context.report, snapshot)


func test_cancel_before_release_never_commits_cost_or_bastion() -> void:
	_battle._on_request_cast_spell(DASH, DESTINATION)
	_battle._abort_spell_resolution(_hero, false)
	await wait_process_frames(3)
	assert_eq(_hero.current_ap, _ap_before)
	assert_eq(_hero.get_spell_uses(DASH), _uses_before)
	assert_eq(_hero.grid_pos, START)
	_assert_impact_pending()
	assert_null(_battle._deferred_spell_reaction_context)
	assert_true(_adapter._reaction_commands.is_empty())


func test_cancel_after_release_snaps_and_settles_committed_command_once() -> void:
	assert_true(await _start_real_dash_until_release())
	_assert_impact_pending()
	_battle._abort_spell_resolution(_hero, false)
	assert_lt(_view.position.distance_to(_destination_position()), 0.01)
	assert_eq(_arrivals, 1, "A committed snap acknowledges its actual destination before reactions")
	_assert_one_payment_and_impact()
	var damage := _events.filter(func(event): return event.kind == &"damage")
	if damage.size() == 1:
		assert_eq(damage[0].arrivals, 1)
		assert_lt(float(damage[0].position_error), 0.01)
	assert_null(_battle._deferred_spell_reaction_context)
	assert_false(_battle._spell_resolution_pending)
	_battle._abort_spell_resolution(_hero, false)
	await wait_process_frames(4)
	_assert_one_payment_and_impact()
	assert_eq(_arrivals, 1, "Cancelling twice cannot acknowledge a second arrival")
	assert_true(_events.filter(func(event): return event.kind == &"action_resolved").is_empty(),
		"The cancelled wait must not publish a stale completion")


func test_shutdown_discards_the_owned_command_without_late_damage_or_reexecution() -> void:
	assert_true(await _start_real_dash_until_release())
	_assert_impact_pending()
	_battle._begin_battle_shutdown()
	assert_eq(_arrivals, 0, "Shutdown must not acknowledge travel that never arrived")
	assert_null(_battle._deferred_spell_reaction_context)
	assert_true(_adapter._reaction_commands.is_empty())
	_adapter.flush_automatic()
	await wait_process_frames(4)
	_assert_impact_pending()
	assert_eq(_hero.current_ap, _ap_before - 1, "Committed costs remain committed at scene shutdown")
	assert_eq(_hero.get_spell_uses(DASH), _uses_before + 1)
	assert_true(_events.filter(func(event): return event.kind == &"action_resolved").is_empty())


func test_dead_caster_cannot_execute_its_deferred_bastion_after_cancel() -> void:
	assert_true(await _start_real_dash_until_release())
	_hero.take_damage(_hero.current_hp + _hero.current_shield + 100, _enemy,
		Spell.DamageType.PHYSICAL, Spell.Element.NONE,
		{"cannot_be_dodged": true, "ignore_defense": true, "action_id": &"arrival_death_fixture"})
	assert_false(_hero.is_alive)
	_battle._abort_spell_resolution(_hero, false)
	assert_eq(_arrivals, 0, "A dead caster cannot acknowledge a live reaction arrival")
	assert_null(_battle._deferred_spell_reaction_context)
	assert_true(_adapter._reaction_commands.is_empty())
	assert_eq(_enemy.current_hp, 100)
	assert_eq(_enemy.grid_pos, TARGET_START)
	await wait_process_frames(4)
	assert_eq(_enemy.current_hp, 100)


func _start_real_dash_until_release() -> bool:
	await wait_process_frames(3)
	_battle._on_request_cast_spell(DASH, DESTINATION)
	return await _until(func(): return _hero.grid_pos == DESTINATION \
		and _battle._deferred_spell_reaction_context != null)


func _assert_impact_pending() -> void:
	assert_eq(_enemy.current_hp, 100)
	assert_eq(_enemy.grid_pos, TARGET_START)
	assert_eq(_hero.get_shield_value(&"achilles_bronze_guard"), _guard_before)
	assert_true(_events.filter(func(event): return event.kind == &"damage").is_empty())


func _assert_one_payment_and_impact() -> void:
	var consumed := int(round(float(_guard_before) * 0.2))
	var damage := mini(consumed, int(round(float(_hero.max_hp.get_int()) * 0.08)))
	assert_eq(_hero.current_ap, _ap_before - 1)
	assert_eq(_hero.get_spell_uses(DASH), _uses_before + 1)
	assert_eq(_hero.get_shield_value(&"achilles_bronze_guard"), _guard_before - consumed)
	assert_eq(_enemy.current_hp, 100 - damage)
	assert_eq(_events.filter(func(event): return event.kind == &"damage").size(), 1)


func _destination_position() -> Vector2:
	return _battle.grid_cell_to_parent_local(DESTINATION, _view.get_parent())


func _on_arrived(unit: Unit) -> void:
	if unit == _hero:
		_arrivals += 1


func _on_health_damage(target: Unit, _attacker: Unit, _amount: int, _category: Variant, _element: Variant, _critical: bool) -> void:
	if target == _enemy:
		_events.append({"kind": &"damage", "arrivals": _arrivals, "time_usec": Time.get_ticks_usec(),
			"position_error": _view.position.distance_to(_destination_position()),
			"locked": _battle._spell_resolution_pending})


func _on_action_resolved(unit: Unit, _action_id: StringName, _kind: StringName, _report: Dictionary) -> void:
	if unit == _hero:
		_events.append({"kind": &"action_resolved", "time_usec": Time.get_ticks_usec(),
			"locked": _battle._spell_resolution_pending})


func _until(predicate: Callable, timeout_ms: int = 3500) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await get_tree().process_frame
	return false
