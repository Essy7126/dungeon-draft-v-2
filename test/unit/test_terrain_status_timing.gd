extends GutTest


func test_01_poison_entry_applies_without_immediate_tick() -> void:
	var fixture := _occupied(&"poison")
	assert_true(fixture.unit.has_status(&"poison"))
	assert_eq(fixture.unit.current_hp, 100)


func test_02_poison_ticks_at_next_activation_start() -> void:
	var fixture := _occupied(&"poison")
	ArenaTerrainStatusTimingService.resolve_activation_start(
		fixture.unit, fixture.runtime.terrain_effects
	)
	assert_eq(fixture.unit.current_hp, 96)


func test_03_poison_uses_resource_duration_and_refreshes_while_standing() -> void:
	var fixture := _occupied(&"poison")
	ArenaTerrainStatusTimingService.resolve_activation_start(
		fixture.unit, fixture.runtime.terrain_effects
	)
	assert_eq(fixture.unit.get_status_remaining(&"poison"), 3)


func test_04_poison_never_duplicates() -> void:
	var fixture := _occupied(&"poison")
	for index in range(3):
		fixture.runtime.terrain_effects.on_turn_start(fixture.unit)
	assert_eq(_status_count(fixture.unit, &"poison"), 1)


func test_05_poison_expires_after_leaving() -> void:
	var fixture := _occupied(&"poison")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i.ZERO))
	for index in range(3):
		ArenaTerrainStatusTimingService.resolve_activation_start(
			fixture.unit, fixture.runtime.terrain_effects
		)
	assert_false(fixture.unit.has_status(&"poison"))


func test_06_lava_entry_damage_and_burn_are_separate() -> void:
	var fixture := _occupied(&"lava")
	assert_eq(fixture.unit.current_hp, 85)
	assert_true(fixture.unit.has_status(&"burn"))


func test_07_burn_ticks_six_on_next_activation() -> void:
	var fixture := _occupied(&"lava")
	ArenaTerrainStatusTimingService.resolve_activation_start(
		fixture.unit, fixture.runtime.terrain_effects
	)
	assert_eq(fixture.unit.current_hp, 79)


func test_08_burn_refreshes_without_duplicate() -> void:
	var fixture := _occupied(&"lava")
	for index in range(3):
		ArenaTerrainStatusTimingService.resolve_activation_start(
			fixture.unit, fixture.runtime.terrain_effects
		)
	assert_eq(_status_count(fixture.unit, &"burn"), 1)
	assert_eq(fixture.unit.get_status_remaining(&"burn"), 3)


func test_09_voluntary_electric_entry_consumes_current_activation_only() -> void:
	var fixture := _electric_fixture()
	fixture.unit.current_ap = 2
	fixture.unit.current_mp = 4
	fixture.runtime.terrain_effects.begin_unit_resolution(fixture.unit, &"movement")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i(1, 1)))
	var result: Dictionary = fixture.runtime.terrain_effects.consume_last_entry_result(fixture.unit)
	assert_true(result.current_activation_consumed)
	assert_eq(fixture.unit.current_ap, 0)
	assert_eq(fixture.unit.current_mp, 0)
	assert_false(fixture.unit.has_status(&"shock"))


func test_10_voluntary_electric_entry_ends_movement() -> void:
	var fixture := _electric_fixture()
	fixture.runtime.terrain_effects.begin_unit_resolution(fixture.unit, &"movement")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i(1, 1)))
	var result: Dictionary = fixture.runtime.terrain_effects.consume_last_entry_result(fixture.unit)
	assert_true(result.end_movement)


func test_11_forced_electric_entry_applies_one_shock() -> void:
	var fixture := _electric_fixture()
	fixture.runtime.terrain_effects.begin_unit_resolution(fixture.unit, &"push")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i(1, 1)))
	assert_true(fixture.unit.has_status(&"shock"))
	assert_eq(_status_count(fixture.unit, &"shock"), 1)


func test_12_forced_shock_skips_exactly_one_activation() -> void:
	var fixture := _electric_fixture()
	fixture.runtime.terrain_effects.begin_unit_resolution(fixture.unit, &"teleport")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i(1, 1)))
	assert_true(ArenaTerrainStatusTimingService.resolve_activation_start(
		fixture.unit, fixture.runtime.terrain_effects
	))
	assert_false(fixture.unit.has_status(&"shock"))
	assert_false(ArenaTerrainStatusTimingService.resolve_activation_start(
		fixture.unit, fixture.runtime.terrain_effects
	))


func test_13_electric_water_also_applies_wet() -> void:
	var fixture := _electric_fixture()
	fixture.runtime.terrain_effects.begin_unit_resolution(fixture.unit, &"movement")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i(1, 1)))
	assert_true(fixture.unit.has_status(&"wet"))


func test_14_same_round_exit_and_reentry_does_not_retrigger() -> void:
	var fixture := _electric_fixture()
	fixture.runtime.terrain_effects.begin_unit_resolution(fixture.unit, &"push")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i(1, 1)))
	fixture.unit.remove_status(&"shock")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i.ZERO))
	fixture.runtime.terrain_effects.begin_unit_resolution(fixture.unit, &"pull")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i(1, 1)))
	assert_false(fixture.unit.has_status(&"shock"))


func test_15_new_round_allows_a_new_shock() -> void:
	var fixture := _electric_fixture()
	fixture.runtime.terrain_effects.begin_unit_resolution(fixture.unit, &"push")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i(1, 1)))
	fixture.unit.remove_status(&"shock")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i.ZERO))
	fixture.runtime.terrain_effects.runtime_service.configure_resolution_context(77, 2)
	fixture.runtime.terrain_effects.begin_unit_resolution(fixture.unit, &"pull")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i(1, 1)))
	assert_true(fixture.unit.has_status(&"shock"))


func test_16_electric_damage_is_not_repeated_by_internal_same_cell_event() -> void:
	var fixture := _electric_fixture()
	var token: StringName = fixture.runtime.terrain_effects.begin_unit_resolution(fixture.unit, &"movement")
	assert_true(fixture.runtime.grid.relocate_unit(fixture.unit, Vector2i(1, 1)))
	var hp: int = fixture.unit.current_hp
	fixture.runtime.terrain_effects.runtime_service.resolve_unit_entry(
		fixture.unit, Vector2i(1, 1), token
	)
	assert_eq(fixture.unit.current_hp, hp)


func test_17_terrain_statuses_tick_before_refresh() -> void:
	var fixture := _occupied(&"poison")
	var entry := _entry(fixture.unit, &"poison")
	entry.remaining = 1
	ArenaTerrainStatusTimingService.resolve_activation_start(
		fixture.unit, fixture.runtime.terrain_effects
	)
	assert_eq(fixture.unit.current_hp, 96)
	assert_eq(fixture.unit.get_status_remaining(&"poison"), 3)


func _occupied(terrain_id: StringName) -> Dictionary:
	var runtime := ArenaRuntimeProjectionService.build(_arena(terrain_id))
	var unit := Unit.new("Timing", 0, 100)
	unit.unit_id = &"timing_unit"
	assert_true(runtime.grid.place_unit(unit, Vector2i(1, 1)))
	return {"runtime": runtime, "unit": unit}


func _electric_fixture() -> Dictionary:
	var runtime := ArenaRuntimeProjectionService.build(_arena(&"electrified_water"))
	runtime.terrain_effects.runtime_service.configure_resolution_context(77, 1)
	var unit := Unit.new("Shock", 0, 100)
	unit.unit_id = &"shock_unit"
	assert_true(runtime.grid.place_unit(unit, Vector2i.ZERO))
	return {"runtime": runtime, "unit": unit}


func _arena(special_id: StringName) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Timing fixture", "timing_fixture")
	arena.grid_size = Vector2i(3, 3)
	for y in range(3):
		for x in range(3):
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), &"neutral")
	ArenaDynamicEditingService.paint_terrain_local(arena, Vector2i(1, 1), special_id)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena


func _status_count(unit: Unit, status_id: StringName) -> int:
	return unit.active_statuses.filter(func(entry):
		var data := entry.get("data") as StatusData
		return data != null and data.get_effective_status_id() == status_id
	).size()


func _entry(unit: Unit, status_id: StringName) -> Dictionary:
	for entry in unit.active_statuses:
		var data := entry.get("data") as StatusData
		if data != null and data.get_effective_status_id() == status_id:
			return entry
	return {}
