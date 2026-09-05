extends GutTest

const UNIT_VIEW_SCRIPT := preload("res://battle/unit_view.gd")
const DASH := preload("res://data/spells/achilles/fulminant_dash.tres")
const LEGACY_ADVANCE := preload("res://data/spells/achilles/advance.tres")
const SPECTRE_CLEAVE := preload("res://data/spells/enemies/spectre_heavy_cleave.tres")
const Factory := preload("res://test/support/factory.gd")

var _capture_callbacks: Array[Callable] = []


class ReleaseVisual:
	extends Node2D

	signal cast_release_reached
	signal animation_finished(animation_name: StringName)

	var active := false
	var release_count := 0
	var cancellation_count := 0
	var synchronization_count := 0

	func play_spell_action(_spell: Spell = null) -> bool:
		if active:
			return false
		active = true
		release_count += 1
		cast_release_reached.emit()
		return true

	func cancel_pending_visual_actions() -> void:
		active = false
		cancellation_count += 1

	func synchronize_external_movement() -> void:
		synchronization_count += 1

	func set_facing(_direction: Vector2i) -> void:
		pass

	func play_idle() -> bool:
		return not active


class MovementUnitView:
	extends UNIT_VIEW_SCRIPT

	var visual: ReleaseVisual

	func _instantiate_optional_visual() -> void:
		visual = ReleaseVisual.new()
		_optional_visual = visual
		add_child(visual)
		visual.animation_finished.connect(_on_optional_visual_action_finished)


class MovementBattle:
	extends "res://battle/battle.gd"

	func _ready() -> void:
		pass

	func grid_cell_to_parent_local(cell: Vector2i, parent: Node2D) -> Vector2:
		var projected := Vector2(float(cell.x - cell.y) * 64.0, float(cell.x + cell.y) * 32.0)
		return parent.to_local(to_global(projected))


func after_each() -> void:
	for callback in _capture_callbacks:
		if EventBus.unit_pushed.is_connected(callback):
			EventBus.unit_pushed.disconnect(callback)
	_capture_callbacks.clear()


func test_current_dash_notifies_battle_once_and_reaches_the_resolved_cell() -> void:
	var fixture := _fixture()
	var actor: Unit = fixture.actor
	var battle: MovementBattle = fixture.battle
	var view: MovementUnitView = fixture.view
	var capture := _capture(actor)
	var origin := actor.grid_pos
	var destination := Vector2i(3, 0)
	var initial_mp := actor.current_mp
	_arm_player_movement(fixture, DASH)
	assert_true(await view.prepare_spell_visual(destination, DASH))
	assert_eq(view.visual.release_count, 1)
	assert_eq(actor.grid_pos, origin, "The release visual cannot relocate gameplay")
	assert_true(capture.is_empty())
	var context := battle.spell_caster.begin_cast(actor, DASH, destination)
	assert_false(context.failed)
	assert_eq(actor.grid_pos, origin, "Committing costs does not apply the movement")
	var report := battle.spell_caster.resolve_cast(context)
	assert_false(report.get("failed", false), str(report))
	assert_eq(actor.grid_pos, destination)
	assert_eq(actor.current_mp, initial_mp, "Spell movement does not spend ordinary movement points")
	assert_eq(capture.size(), 1)
	if capture.is_empty():
		return
	assert_eq(capture[0].from, origin)
	assert_eq(capture[0].to, destination)
	assert_false(capture[0].collision)
	assert_eq(context.movement.size(), 1)
	assert_true(context.movement[0].voluntary)
	var expected := battle.grid_cell_to_parent_local(destination, view.get_parent())
	var original_position := battle.grid_cell_to_parent_local(origin, view.get_parent())
	assert_almost_eq(view.position, original_position, Vector2(0.001, 0.001))
	var tween: Tween = battle._spell_movement_feedback_tween
	assert_not_null(tween, "Real SpellCaster event must start Battle's visual tween")
	if tween == null:
		return
	tween.custom_step(0.1)
	assert_gt(view.position.distance_to(original_position), 0.1)
	assert_gt(view.position.distance_to(expected), 0.1)
	assert_true(view.is_action_visual_pending())
	tween.custom_step(1.0)
	assert_almost_eq(view.position, expected, Vector2(0.001, 0.001))
	assert_false(view.is_action_visual_pending())
	assert_false(view.visual.active)
	assert_eq(view.visual.cancellation_count, 1)
	assert_eq(view.visual.synchronization_count, 1)
	assert_null(battle._spell_movement_feedback_tween)
	# Re-resolving an already committed context must not start a second trip.
	battle.spell_caster.resolve_cast(context)
	assert_eq(capture.size(), 1)
	assert_eq(view.visual.release_count, 1)
	assert_null(battle._spell_movement_feedback_tween)


func test_renamed_evolved_movement_uses_metadata_and_any_actor() -> void:
	var fixture := _fixture()
	var actor: Unit = fixture.actor
	actor.unit_id = &"spectre_greatsword"
	var evolved := DASH.duplicate(true) as Spell
	evolved.spell_id = &"different_evolved_mobility_fixture"
	evolved.spell_range = 4
	var capture := _capture(actor)
	_arm_player_movement(fixture, evolved)
	assert_same(fixture.battle._active_spell_movement_caster, actor)
	var report: Dictionary = fixture.battle.spell_caster.cast(actor, evolved, Vector2i(4, 0))
	assert_false(report.get("failed", false), str(report))
	assert_eq(actor.grid_pos, Vector2i(4, 0))
	assert_eq(capture.size(), 1)
	_complete_tween_and_assert_position(fixture, Vector2i(4, 0))


func test_outside_player_resolution_the_same_event_synchronizes_immediately() -> void:
	var fixture := _fixture()
	var battle: MovementBattle = fixture.battle
	var view: MovementUnitView = fixture.view
	assert_false(battle._spell_resolution_pending)
	var report := battle.spell_caster.cast(fixture.actor, DASH, Vector2i(2, 0))
	assert_false(report.get("failed", false), str(report))
	assert_almost_eq(view.position, battle.grid_cell_to_parent_local(Vector2i(2, 0), view.get_parent()), Vector2(0.001, 0.001))
	assert_eq(view.visual.synchronization_count, 1)
	assert_null(battle._spell_movement_feedback_tween)


func test_blocked_dash_never_emits_movement_or_changes_visual_position() -> void:
	var fixture := _fixture()
	var actor: Unit = fixture.actor
	var capture := _capture(actor)
	var initial_position: Vector2 = fixture.view.position
	var initial_ap := actor.current_ap
	var blocker := Factory.make_unit("Blocker", 1)
	assert_true(fixture.battle.grid.place_unit(blocker, Vector2i(1, 0)))
	_arm_player_movement(fixture, DASH)
	var report: Dictionary = fixture.battle.spell_caster.cast(actor, DASH, Vector2i(3, 0))
	assert_true(report.get("failed", false))
	assert_eq(actor.grid_pos, Vector2i.ZERO)
	assert_eq(actor.current_ap, initial_ap)
	assert_eq(fixture.view.position, initial_position)
	assert_true(capture.is_empty())
	assert_null(fixture.battle._spell_movement_feedback_tween)


func test_dash_uses_final_vortex_exit_for_event_and_visual_destination() -> void:
	var arena := ArenaDefinition.new()
	arena.set_identity("Movement sprite regression", "movement_sprite_regression")
	arena.grid_size = Vector2i(5, 5)
	for y in 5:
		for x in 5:
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), &"neutral")
	var network := ArenaVortexNetworkService.create_network(arena)
	var entry := Vector2i(1, 1)
	var destination := Vector2i(4, 4)
	network.cells = [entry, destination]
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var runtime := ArenaRuntimeProjectionService.build(arena)
	runtime.terrain_effects.runtime_service.configure_resolution_context(42, 1)
	var fixture := _fixture(runtime.grid, runtime.terrain_effects, Vector2i(0, 1))
	var actor: Unit = fixture.actor
	var capture := _capture(actor)
	_arm_player_movement(fixture, DASH)
	var context: CastContext = fixture.battle.spell_caster.begin_cast(actor, DASH, entry)
	var report: Dictionary = fixture.battle.spell_caster.resolve_cast(context)
	assert_false(report.get("failed", false), str(report))
	assert_eq(actor.grid_pos, destination)
	assert_same(runtime.grid.get_unit(destination), actor)
	assert_null(runtime.grid.get_unit(entry))
	assert_eq(capture.size(), 1, "Terrain relocation must not add a duplicate presentation trip")
	if capture.is_empty():
		return
	assert_eq(capture[0].from, Vector2i(0, 1))
	assert_eq(capture[0].to, destination)
	assert_eq(context.movement[0].to, destination)
	_complete_tween_and_assert_position(fixture, destination)


func test_legacy_modifier_advance_keeps_one_movement_event() -> void:
	var fixture := _fixture()
	var actor: Unit = fixture.actor
	var target := Factory.make_unit("Legacy advance target", 1)
	assert_true(fixture.battle.grid.place_unit(target, Vector2i(3, 0)))
	var capture := _capture(actor)
	_arm_player_movement(fixture, LEGACY_ADVANCE)
	assert_same(fixture.battle._active_spell_movement_caster, actor)
	var report: Dictionary = fixture.battle.spell_caster.cast(actor, LEGACY_ADVANCE, target.grid_pos)
	assert_false(report.get("failed", false), str(report))
	assert_eq(actor.grid_pos, Vector2i(2, 0))
	assert_eq(capture.size(), 1)
	_complete_tween_and_assert_position(fixture, Vector2i(2, 0))


func test_stationary_spectre_cleave_keeps_both_position_and_movement_stream_unchanged() -> void:
	var fixture := _fixture()
	var actor: Unit = fixture.actor
	actor.unit_id = &"spectre_greatsword"
	actor.team = 1
	var target := Factory.make_unit("Hero target", 0)
	assert_true(fixture.battle.grid.place_unit(target, Vector2i(1, 0)))
	var capture := _capture(actor)
	var original_position: Vector2 = fixture.view.position
	_arm_player_movement(fixture, SPECTRE_CLEAVE)
	assert_null(fixture.battle._active_spell_movement_caster)
	var report: Dictionary = fixture.battle.spell_caster.cast(actor, SPECTRE_CLEAVE, target.grid_pos)
	assert_false(report.get("failed", false), str(report))
	assert_eq(actor.grid_pos, Vector2i.ZERO)
	assert_eq(fixture.view.position, original_position)
	assert_true(capture.is_empty())
	assert_null(fixture.battle._spell_movement_feedback_tween)


func _fixture(existing_grid: GridData = null, existing_terrain: TerrainEffects = null, start := Vector2i.ZERO) -> Dictionary:
	var battle := MovementBattle.new()
	add_child_autofree(battle)
	battle.grid = existing_grid if existing_grid != null else GridData.new(8, 5)
	battle.terrain_effects = existing_terrain if existing_terrain != null else TerrainEffects.new(battle.grid)
	battle.pathfinder = Pathfinder.new(battle.grid)
	battle.spell_caster = SpellCaster.new(battle.grid, battle.pathfinder, battle.terrain_effects)
	var actor := Factory.make_unit("Movement actor")
	assert_true(battle.grid.place_unit(actor, start))
	var parent := Node2D.new()
	parent.position = Vector2(41.0, -28.0)
	parent.scale = Vector2(1.3, 0.9)
	battle.add_child(parent)
	var view := MovementUnitView.new()
	parent.add_child(view)
	view.setup(actor, false)
	view.position = battle.grid_cell_to_parent_local(start, parent)
	battle._unit_views[actor] = view
	EventBus.unit_pushed.connect(battle._on_unit_pushed)
	return {"battle": battle, "actor": actor, "view": view}


func _arm_player_movement(fixture: Dictionary, spell: Spell) -> void:
	fixture.battle._spell_resolution_pending = true
	fixture.battle._active_spell_movement_caster = fixture.actor \
		if fixture.battle.spell_caster.spell_moves_caster(fixture.actor, spell) else null


func _capture(actor: Unit) -> Array:
	var events: Array = []
	var callback := func(unit, origin, destination, collision) -> void:
		if unit == actor:
			events.append({"from": origin, "to": destination, "collision": collision})
	EventBus.unit_pushed.connect(callback)
	_capture_callbacks.append(callback)
	return events


func _complete_tween_and_assert_position(fixture: Dictionary, destination: Vector2i) -> void:
	var tween: Tween = fixture.battle._spell_movement_feedback_tween
	assert_not_null(tween, "Caster movement event should create presentation tween")
	if tween == null:
		return
	tween.custom_step(1.0)
	var expected: Vector2 = fixture.battle.grid_cell_to_parent_local(destination, fixture.view.get_parent())
	assert_almost_eq(fixture.view.position, expected, Vector2(0.001, 0.001))
	assert_eq(fixture.actor.grid_pos, destination)
	assert_null(fixture.battle._spell_movement_feedback_tween)
