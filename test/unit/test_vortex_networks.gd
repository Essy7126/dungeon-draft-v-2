extends GutTest

const Factory := preload("res://test/support/factory.gd")


class MovementJournalSpy:
	extends SpellModifier

	var destinations: Array[Vector2i] = []

	func on_movement_resolved(ctx) -> void:
		for movement_value in ctx.movement:
			var movement := movement_value as Dictionary
			var destination := movement.get(
				"to", Vector2i(-1, -1)
			) as Vector2i
			destinations.append(destination)


func test_00_composite_placement_finishes_as_one_before_after_transaction() -> void:
	var arena := _arena()
	var entry := TerrainPlaceableCatalogService.entry_by_id(
		arena, &"vortex_portal_two", true
	)
	var definition := entry.get("definition") as TerrainPlaceableDefinition
	assert_not_null(definition)
	var session := TerrainPlacementSession.new()
	var before := arena.to_snapshot().duplicate(true)
	assert_true(session.begin(arena, definition))
	assert_false(bool(session.add_cell(arena, Vector2i(1, 1)).complete))
	assert_true(bool(session.add_cell(arena, Vector2i(3, 3)).complete))
	var transaction := session.finish(arena)
	assert_true(bool(transaction.ok))
	assert_eq(transaction.before, before)
	assert_eq((transaction.after as Dictionary).vortex_networks.size(), 1)
	assert_eq(arena.vortex_networks[0].unique_cells(), [
		Vector2i(1, 1), Vector2i(3, 3),
	])


func test_00b_escape_style_cancel_restores_the_exact_initial_snapshot() -> void:
	var arena := _arena()
	var entry := TerrainPlaceableCatalogService.entry_by_id(
		arena, &"vortex_portal_multi", true
	)
	var definition := entry.get("definition") as TerrainPlaceableDefinition
	var before := arena.to_snapshot().duplicate(true)
	var session := TerrainPlacementSession.new()
	assert_true(session.begin(arena, definition))
	assert_true(bool(session.add_cell(arena, Vector2i(1, 1)).changed))
	assert_true(bool(session.add_cell(arena, Vector2i(3, 3)).changed))
	assert_true(session.cancel(arena))
	assert_eq(arena.to_snapshot(), before)
	assert_false(session.active)


func test_01_migration_pair_to_network_preserves_both_cells() -> void:
	var arena := _arena()
	assert_true(ArenaDynamicEditingService.place_vortex_pair(
		arena, Vector2i(1, 1), Vector2i(3, 3)
	))
	arena.vortex_networks.clear()
	assert_eq(ArenaVortexNetworkService.migrate_legacy_pairs(arena), 1)
	assert_eq(arena.vortex_networks[0].unique_cells(), [Vector2i(1, 1), Vector2i(3, 3)])
	var schema_two := arena.to_snapshot()
	schema_two["schema_version"] = 2
	schema_two["vortex_networks"] = []
	var migrated := ArenaSchemaMigrator.migrate_snapshot(schema_two)
	assert_true(migrated.ok)
	assert_eq(migrated.snapshot.schema_version, ArenaDefinition.CURRENT_SCHEMA_VERSION)
	assert_eq(migrated.snapshot.vortex_networks[0].cells, [[1, 1], [3, 3]])


func test_02_single_vortex_grants_one_current_mp() -> void:
	var fixture := _runtime([Vector2i(1, 1)])
	fixture.unit.current_mp = 3
	_entry(fixture, Vector2i(1, 1), &"movement")
	assert_eq(fixture.unit.current_mp, 4)


func test_03_single_vortex_does_not_accumulate_in_same_round() -> void:
	var fixture := _runtime([Vector2i(1, 1)])
	fixture.unit.current_mp = 3
	_entry(fixture, Vector2i(1, 1), &"movement")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i.ZERO))
	_entry(fixture, Vector2i(1, 1), &"movement")
	assert_eq(fixture.unit.current_mp, 4)


func test_04_single_vortex_can_trigger_on_new_round() -> void:
	var fixture := _runtime([Vector2i(1, 1)])
	fixture.unit.current_mp = 3
	_entry(fixture, Vector2i(1, 1), &"movement")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i.ZERO))
	fixture.runtime.terrain_effects.runtime_service.configure_resolution_context(42, 2)
	_entry(fixture, Vector2i(1, 1), &"movement")
	assert_eq(fixture.unit.current_mp, 5)


func test_05_two_vortexes_teleport_a_to_b() -> void:
	var fixture := _runtime([Vector2i(1, 1), Vector2i(3, 3)])
	var result := _entry(fixture, Vector2i(1, 1), &"movement")
	assert_true(result.teleported)
	assert_eq(fixture.unit.grid_pos, Vector2i(3, 3))


func test_06_two_vortexes_teleport_b_to_a() -> void:
	var fixture := _runtime([Vector2i(1, 1), Vector2i(3, 3)], Vector2i(4, 3))
	var result := _entry(fixture, Vector2i(3, 3), &"movement")
	assert_true(result.teleported)
	assert_eq(fixture.unit.grid_pos, Vector2i(1, 1))


func test_07_random_network_is_deterministic() -> void:
	var cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(3, 1), Vector2i(3, 3)]
	var first := _runtime(cells)
	var second := _runtime(cells)
	assert_eq(
		_entry(first, Vector2i(1, 1), &"movement").destination,
		_entry(second, Vector2i(1, 1), &"movement").destination
	)


func test_08_four_vortexes_choose_another_cell() -> void:
	var cells: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(3, 1), Vector2i(1, 3), Vector2i(3, 3),
	]
	var fixture := _runtime(cells)
	var result := _entry(fixture, Vector2i(1, 1), &"movement")
	assert_true(result.teleported)
	assert_true(result.destination in cells)
	assert_ne(result.destination, Vector2i(1, 1))


func test_09_occupied_destination_is_excluded() -> void:
	var fixture := _runtime([Vector2i(1, 1), Vector2i(3, 1), Vector2i(3, 3)])
	var network_cells: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(3, 1), Vector2i(3, 3),
	]
	fixture.runtime.grid.set_vortex_network(
		&"vortex_network_001", network_cells, 1, true
	)
	var blocker := Unit.new("Blocker", 1, 100)
	assert_true(fixture.runtime.grid.place_unit(blocker, Vector2i(3, 1)))
	var candidates: Array[Vector2i] = fixture.runtime.grid.valid_vortex_destinations(
		Vector2i(1, 1), fixture.unit
	)
	assert_false(candidates.has(Vector2i(3, 1)))


func test_10_void_destination_is_excluded() -> void:
	var fixture := _runtime([Vector2i(1, 1), Vector2i(3, 1), Vector2i(3, 3)])
	fixture.runtime.grid.set_type(Vector2i(3, 1), GridData.CellType.HOLE)
	assert_false(fixture.runtime.grid.valid_vortex_destinations(
		Vector2i(1, 1), fixture.unit
	).has(Vector2i(3, 1)))


func test_11_no_valid_destination_reports_blocked_without_bonus() -> void:
	var fixture := _runtime([Vector2i(1, 1), Vector2i(3, 1), Vector2i(3, 3)])
	fixture.runtime.grid.set_type(Vector2i(3, 1), GridData.CellType.HOLE)
	fixture.runtime.grid.set_type(Vector2i(3, 3), GridData.CellType.HOLE)
	var mp: int = fixture.unit.current_mp
	var result := _entry(fixture, Vector2i(1, 1), &"movement")
	assert_false(result.teleported)
	assert_eq(result.reason, &"vortex_destination_blocked")
	assert_eq(fixture.unit.current_mp, mp)


func test_12_arrival_does_not_retrigger_same_network() -> void:
	var fixture := _runtime([Vector2i(1, 1), Vector2i(3, 1), Vector2i(3, 3)])
	var result := _entry(fixture, Vector2i(1, 1), &"movement")
	assert_true(result.teleported)
	assert_eq(fixture.unit.grid_pos, result.destination)


func test_13_teleport_ends_movement() -> void:
	var fixture := _runtime([Vector2i(1, 1), Vector2i(3, 3)])
	assert_true(_entry(fixture, Vector2i(1, 1), &"movement").end_movement)


func test_14_push_uses_the_same_runtime_resolution() -> void:
	var fixture := _runtime([Vector2i(1, 1), Vector2i(3, 3)])
	assert_true(_entry(fixture, Vector2i(1, 1), &"push").teleported)


func test_15_team_policy_is_enforced() -> void:
	var arena := _arena()
	var network := ArenaVortexNetworkService.create_network(arena)
	network.cells = [Vector2i(1, 1), Vector2i(3, 3)]
	network.allowed_teams = 1
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var runtime := ArenaRuntimeProjectionService.build(arena)
	var enemy := Unit.new("Enemy", 1, 100)
	assert_true(runtime.grid.place_unit(enemy, Vector2i.ZERO))
	runtime.terrain_effects.begin_unit_resolution(enemy, &"movement")
	assert_true(runtime.grid.relocate_unit(enemy, Vector2i(1, 1)))
	assert_eq(runtime.terrain_effects.consume_last_entry_result(enemy).reason, &"vortex_team_not_allowed")


func test_16_multiple_networks_remain_independent() -> void:
	var arena := _arena()
	var first := ArenaVortexNetworkService.create_network(arena, "Premier")
	var second := ArenaVortexNetworkService.create_network(arena, "Second")
	assert_true(ArenaVortexNetworkService.add_cell(arena, first.network_id, Vector2i(1, 1)))
	assert_true(ArenaVortexNetworkService.add_cell(arena, second.network_id, Vector2i(3, 3)))
	assert_ne(first.network_id, second.network_id)


func test_17_cell_cannot_belong_to_two_networks() -> void:
	var arena := _arena()
	var first := ArenaVortexNetworkService.create_network(arena)
	var second := ArenaVortexNetworkService.create_network(arena)
	assert_true(ArenaVortexNetworkService.add_cell(arena, first.network_id, Vector2i(1, 1)))
	assert_false(ArenaVortexNetworkService.add_cell(arena, second.network_id, Vector2i(1, 1)))


func test_18_snapshot_restore_preserves_network() -> void:
	var arena := _arena()
	var network := ArenaVortexNetworkService.create_network(arena)
	network.cells = [Vector2i(1, 1), Vector2i(3, 3), Vector2i(2, 3)]
	var snapshot := arena.to_snapshot()
	arena.vortex_networks.clear()
	assert_true(arena.restore_snapshot(snapshot))
	assert_eq(arena.vortex_networks[0].unique_cells().size(), 3)


func test_19_two_cell_pathfinder_uses_deterministic_edge() -> void:
	var fixture := _runtime([Vector2i(1, 1), Vector2i(3, 3)])
	var path := Pathfinder.new(fixture.runtime.grid).find_path(
		Vector2i.ZERO, Vector2i(3, 3), fixture.unit
	)
	assert_true(path.has(Vector2i(1, 1)))
	assert_true(path.has(Vector2i(3, 3)))


func test_20_random_network_pathfinder_only_reaches_entry() -> void:
	var fixture := _runtime([Vector2i(1, 1), Vector2i(3, 1), Vector2i(3, 3)])
	var path := Pathfinder.new(fixture.runtime.grid).find_path(Vector2i.ZERO, Vector2i(1, 1), fixture.unit)
	assert_eq(path[-1], Vector2i(1, 1))
	assert_false(Pathfinder.new(fixture.runtime.grid).is_vortex_edge(Vector2i(1, 1), Vector2i(3, 1)))


func test_21_ai_report_has_average_worst_and_no_seed_mutation() -> void:
	var fixture := _runtime([Vector2i(1, 1), Vector2i(3, 1), Vector2i(3, 3)])
	var report := ArenaVortexNetworkService.evaluate_for_ai(
		fixture.runtime.grid, Vector2i(1, 1), Vector2i(4, 4), fixture.unit
	)
	assert_true(report.has("average_utility"))
	assert_true(report.has("worst_utility"))
	assert_true(report.has("catastrophic_exit"))


func test_22_editor_behavior_summary_covers_all_cardinalities() -> void:
	var network := ArenaVortexNetworkDefinition.new()
	for expected in ["Aucune", "impulsion", "deux cases", "plusieurs sorties"]:
		assert_string_contains(ArenaVortexNetworkService.behavior_summary(network), expected)
		network.cells.append(Vector2i(network.cells.size(), 0))


func test_23_rush_uses_vortex_exit_as_resolved_destination() -> void:
	var entry := Vector2i(1, 1)
	var exit := Vector2i(4, 4)
	var fixture := _runtime([entry, exit], Vector2i(0, 1))
	var runtime: ArenaRuntimeState = fixture.runtime
	var caster: Unit = fixture.unit
	var target := Unit.new("Cible de ruée", 1, 100)
	assert_true(runtime.grid.place_unit(target, Vector2i(2, 1)))
	var spell := Factory.make_spell({
		"spell_id": &"vortex_rush",
		"ap_cost": 1,
		"minimum_range": 2,
		"spell_range": 3,
	})
	var rush := SpellModSkillTreeEffect.new()
	rush.effect_type = SpellModSkillTreeEffect.EffectType.MOVE_CASTER_TO_TARGET
	rush.movement_requires_clear_path = true
	var journal := MovementJournalSpy.new()
	spell.modifiers = [rush, journal]
	var emitted_destinations := _capture_pushed_destinations(caster)
	var spell_caster := SpellCaster.new(
		runtime.grid, Pathfinder.new(runtime.grid), runtime.terrain_effects
	)

	var report := spell_caster.cast(caster, spell, target.grid_pos)

	_stop_capturing_pushed_destinations(emitted_destinations)
	assert_false(report.get("failed", false), str(report))
	assert_eq(caster.grid_pos, exit)
	assert_eq(journal.destinations, [exit])
	assert_eq(emitted_destinations.values, [exit])
	assert_eq(report.get("movement_count"), 1)


func test_24_push_uses_vortex_exit_for_journal_and_event() -> void:
	var entry := Vector2i(2, 1)
	var exit := Vector2i(4, 4)
	var fixture := _runtime([entry, exit], Vector2i(0, 1))
	var runtime: ArenaRuntimeState = fixture.runtime
	var caster: Unit = fixture.unit
	var target := Unit.new("Cible poussée", 1, 100)
	assert_true(runtime.grid.place_unit(target, Vector2i(1, 1)))
	var spell := Factory.make_spell({
		"spell_id": &"vortex_push",
		"ap_cost": 1,
		"spell_range": 1,
		"push_distance": 1,
	})
	var journal := MovementJournalSpy.new()
	spell.modifiers = [journal]
	var emitted_destinations := _capture_pushed_destinations(target)
	var spell_caster := SpellCaster.new(
		runtime.grid, Pathfinder.new(runtime.grid), runtime.terrain_effects
	)

	var report := spell_caster.cast(caster, spell, target.grid_pos)

	_stop_capturing_pushed_destinations(emitted_destinations)
	assert_false(report.get("failed", false), str(report))
	assert_true(report.get("pushed", false))
	assert_eq(target.grid_pos, exit)
	assert_eq(journal.destinations, [exit])
	assert_eq(emitted_destinations.values, [exit])


func test_25_pull_uses_vortex_exit_for_journal_and_event() -> void:
	var entry := Vector2i(1, 1)
	var exit := Vector2i(4, 4)
	var fixture := _runtime([entry, exit], Vector2i(0, 1))
	var runtime: ArenaRuntimeState = fixture.runtime
	var caster: Unit = fixture.unit
	var target := Unit.new("Cible attirée", 1, 100)
	assert_true(runtime.grid.place_unit(target, Vector2i(3, 1)))
	var spell := Factory.make_spell({
		"spell_id": &"vortex_pull",
		"ap_cost": 1,
		"spell_range": 3,
		"pull_distance": 2,
	})
	var journal := MovementJournalSpy.new()
	spell.modifiers = [journal]
	var emitted_destinations := _capture_pushed_destinations(target)
	var spell_caster := SpellCaster.new(
		runtime.grid, Pathfinder.new(runtime.grid), runtime.terrain_effects
	)

	var report := spell_caster.cast(caster, spell, target.grid_pos)

	_stop_capturing_pushed_destinations(emitted_destinations)
	assert_false(report.get("failed", false), str(report))
	assert_true(report.get("pushed", false))
	assert_eq(target.grid_pos, exit)
	assert_eq(journal.destinations, [exit])
	assert_eq(emitted_destinations.values, [exit])


func test_26_teleport_uses_vortex_exit_for_journal_event_and_report() -> void:
	var entry := Vector2i(2, 1)
	var exit := Vector2i(4, 4)
	var fixture := _runtime([entry, exit], Vector2i(0, 1))
	var runtime: ArenaRuntimeState = fixture.runtime
	var caster: Unit = fixture.unit
	var target := Unit.new("Cible de téléportation", 1, 100)
	assert_true(runtime.grid.place_unit(target, Vector2i(1, 1)))
	var spell := Factory.make_spell({
		"spell_id": &"vortex_teleport",
		"ap_cost": 1,
		"spell_range": 1,
		"teleport_behind_target": true,
	})
	var journal := MovementJournalSpy.new()
	spell.modifiers = [journal]
	var emitted_destinations := _capture_pushed_destinations(caster)
	var spell_caster := SpellCaster.new(
		runtime.grid, Pathfinder.new(runtime.grid), runtime.terrain_effects
	)

	var report := spell_caster.cast(caster, spell, target.grid_pos)

	_stop_capturing_pushed_destinations(emitted_destinations)
	assert_false(report.get("failed", false), str(report))
	assert_false(report.get("angle_advantage", true))
	assert_eq(caster.grid_pos, exit)
	assert_eq(journal.destinations, [exit])
	assert_eq(emitted_destinations.values, [exit])


func _capture_pushed_destinations(unit: Unit) -> Dictionary:
	var capture := {"values": []}
	var callback := func(moved_unit, _from, to, _collision) -> void:
		if moved_unit == unit:
			(capture.values as Array).append(to)
	capture["callback"] = callback
	EventBus.unit_pushed.connect(callback)
	return capture


func _stop_capturing_pushed_destinations(capture: Dictionary) -> void:
	var callback := capture.get("callback", Callable()) as Callable
	if callback.is_valid() and EventBus.unit_pushed.is_connected(callback):
		EventBus.unit_pushed.disconnect(callback)


func _entry(fixture: Dictionary, cell: Vector2i, reason: StringName) -> Dictionary:
	fixture.runtime.terrain_effects.begin_unit_resolution(fixture.unit, reason)
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, cell))
	return fixture.runtime.terrain_effects.consume_last_entry_result(fixture.unit)


func _runtime(cells: Array[Vector2i], start := Vector2i.ZERO) -> Dictionary:
	var arena := _arena()
	var network := ArenaVortexNetworkService.create_network(arena)
	network.cells = cells.duplicate()
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var runtime := ArenaRuntimeProjectionService.build(arena)
	runtime.terrain_effects.runtime_service.configure_resolution_context(42, 1)
	var unit := Unit.new("Vortex", 0, 100)
	unit.unit_id = &"vortex_fixture_unit"
	assert_true(runtime.grid.place_unit(unit, start))
	return {"runtime": runtime, "unit": unit, "network": network}


func _arena() -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Vortex fixture", "vortex_fixture")
	arena.grid_size = Vector2i(5, 5)
	for y in range(5):
		for x in range(5):
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), &"neutral")
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena
