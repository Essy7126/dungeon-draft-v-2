extends GutTest

const CATALOG_PATH := "res://data/items/catalogs/default_item_catalog.tres"
const HERO_PATHS := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]
const EXPECTED_ROSTERS := [
	{&"skeleton_normal": 4},
	{&"skeleton_normal": 3, &"skeleton_chief": 1},
	{&"skeleton_normal": 4, &"skeleton_chief": 2},
	{&"skeleton_chief": 3, &"skeleton_centurion": 1},
	{&"skeleton_normal": 4, &"skeleton_chief": 2, &"skeleton_centurion": 2},
	{&"skeleton_chief": 4, &"skeleton_centurion": 4},
]
const EXPECTED_CAPS := [4, 4, 6, 6, 10, 10]
const EXPECTED_NORMAL_BUDGETS := [0, 0, 0, 2, 2, 2]
const EXPECTED_CHIEF_BUDGETS := [0, 0, 0, 0, 1, 1]
const NEW_ITEM_IDS := [
	&"anneau_faille", &"arc_maudit", &"broche", &"caillou",
	&"cape_brume", &"collier_sages", &"couronne", &"excalibur",
	&"hache_executeur", &"harnois", &"manteau_givre",
	&"matraque_troll", &"prisme_elementaire", &"sceau",
]

var _states: Array[CharacterRunState] = []


func after_each() -> void:
	for state in _states:
		if state != null:
			state.dispose()
	_states.clear()


func _encounter(room_number: int) -> EncounterDefinition:
	return load(
		"res://data/encounters/first_run_room_%02d_encounter.tres" % room_number
	) as EncounterDefinition


func _role_counts(definition: EncounterDefinition) -> Dictionary:
	var result := {}
	for unit_data in definition.expanded_roster():
		result[unit_data.tactical_role_id] = int(
			result.get(unit_data.tactical_role_id, 0)
		) + 1
	return result


func _make_states() -> Array[CharacterRunState]:
	var result: Array[CharacterRunState] = []
	for path in HERO_PATHS:
		var data := load(path) as UnitData
		var state := CharacterRunState.new()
		assert_true(state.initialize(Unit.from_data(data), data), path)
		_states.append(state)
		result.append(state)
	return result


func _report(report_index: int) -> CombatReport:
	var report := CombatReport.new()
	report.report_id = StringName("first_run_v2_report_%d" % report_index)
	report.room_index = report_index
	report.victory = true
	report.finalized = true
	return report


func _grid_for_room(room: RoomData) -> GridData:
	var battle := room.battle_scene.instantiate()
	var grid := GridData.new(int(battle.grid_cols), int(battle.grid_rows))
	if room.grid_layout != null:
		room.grid_layout.apply_to_grid(grid)
	else:
		var terrain_layer := battle.get_node_or_null("TerrainLayer") as TileMapLayer
		if terrain_layer != null:
			for cell in terrain_layer.get_used_cells():
				var tile_data := terrain_layer.get_cell_tile_data(cell)
				if tile_data == null:
					continue
				match str(tile_data.get_custom_data("cell_type")):
					"WALL": grid.set_type(cell, GridData.CellType.WALL)
					"HOLE": grid.set_type(cell, GridData.CellType.HOLE)
					"LAVA": grid.set_type(cell, GridData.CellType.LAVA)
					"ICE": grid.set_type(cell, GridData.CellType.ICE)
					"SHADOW": grid.set_type(cell, GridData.CellType.SHADOW)
					"RUNE": grid.set_type(cell, GridData.CellType.RUNE)
					_: grid.set_type(cell, GridData.CellType.NORMAL)
	battle.free()
	return grid


func test_six_encounters_have_exact_compositions_caps_and_shared_budgets() -> void:
	for room_index in 6:
		var definition := _encounter(room_index + 1)
		assert_not_null(definition, "salle %d" % (room_index + 1))
		assert_true(definition.is_valid(), str(definition.validation_errors()))
		assert_eq(definition.room_index, room_index + 1)
		assert_eq(_role_counts(definition), EXPECTED_ROSTERS[room_index])
		assert_eq(definition.living_enemy_cap, EXPECTED_CAPS[room_index])
		assert_eq(
			definition.shared_normal_summon_budget,
			EXPECTED_NORMAL_BUDGETS[room_index],
		)
		assert_eq(
			definition.shared_chief_summon_budget,
			EXPECTED_CHIEF_BUDGETS[room_index],
		)
	assert_true(_encounter(4).disabled_ability_ids.has(&"raise_chief"))
	assert_false(_encounter(5).disabled_ability_ids.has(&"raise_chief"))


func test_run_default_references_the_six_real_rooms_in_order() -> void:
	var run := load("res://data/runs/run_default.tres") as RunData
	assert_not_null(run)
	assert_true(run.is_single_encounter_flow())
	assert_eq(run.maximum_waves_per_room, 1)
	assert_eq(run.rooms.size(), 6)
	for room_index in 6:
		assert_true(run.rooms[room_index].waves.is_empty())
		assert_eq(run.rooms[room_index].minimum_wave_count, 1)
		assert_eq(run.rooms[room_index].maximum_wave_count, 1)
		assert_same(run.rooms[room_index].encounter_definition, _encounter(room_index + 1))
		assert_eq(run.rooms[room_index].enemies.size(), EXPECTED_CAPS[room_index] if room_index < 3 else _encounter(room_index + 1).get_initial_enemy_count())


func test_formation_planner_is_complete_non_overlapping_and_seeded() -> void:
	var grid := GridData.new(18, 14)
	var planner := EncounterFormationPlanner.new(grid, Pathfinder.new(grid))
	var heroes := [Vector2i(1, 5), Vector2i(1, 7), Vector2i(2, 6)]
	var preferred: Array = []
	for y in range(2, 12):
		for x in range(7, 17):
			preferred.append(Vector2i(x, y))
	for room_number in range(1, 7):
		var definition := _encounter(room_number)
		var first := planner.build_plan(definition, heroes, preferred, 1337)
		var repeated := planner.build_plan(definition, heroes, preferred, 1337)
		assert_true(first.get("valid", false), "salle %d: %s" % [room_number, first])
		assert_eq(first, repeated, "le même seed doit reproduire la formation")
		var cells: Array = []
		for placement in first.get("placements", []):
			var cell: Vector2i = placement.get("cell")
			assert_false(cells.has(cell), "aucun spawn superposé")
			cells.append(cell)
		assert_eq(cells.size(), definition.get_initial_enemy_count())


func test_all_six_real_maps_accept_the_full_roster_for_twenty_seeds() -> void:
	var run := load("res://data/runs/run_default.tres") as RunData
	for room_index in 6:
		var room := run.rooms[room_index]
		var grid := _grid_for_room(room)
		var planner := EncounterFormationPlanner.new(grid, Pathfinder.new(grid))
		var formation_ids := {}
		for seed in range(20):
			var plan := planner.build_plan(
				room.encounter_definition,
				room.hero_spawn_zone,
				room.enemy_spawn_zone,
				seed,
			)
			assert_true(
				plan.get("valid", false),
				"salle %d seed %d: %s" % [room_index + 1, seed, plan],
			)
			assert_eq(
				(plan.get("placements", []) as Array).size(),
				room.encounter_definition.get_initial_enemy_count(),
			)
			for placement_value in plan.get("placements", []):
				var cell := (placement_value as Dictionary).get(
					"cell",
					Vector2i(-1, -1),
				) as Vector2i
				assert_false(
					room.encounter_definition.forbidden_initial_spawn_cells.has(cell),
					"aucune unite ne commence dans une zone masquee",
				)
				if room.painted_map_visual_data != null:
					assert_false(
						room.painted_map_visual_data.is_position_fully_occluded(
							room.painted_map_visual_data.cell_to_image(cell)
						),
						"la position doit rester visible sur la peinture",
					)
			formation_ids[plan.get("formation_id")] = true
		assert_gt(formation_ids.size(), 1, "plusieurs formations par salle")


func test_shared_summon_budget_is_not_multiplied_by_centurions() -> void:
	var definition := _encounter(5)
	var runtime := EncounterRuntimeState.new()
	assert_true(runtime.initialize(definition))
	var centurion_data := load(
		"res://data/units/ennemie/skeleton_snow_centurion.tres"
	) as UnitData
	var first := Unit.from_data(centurion_data)
	var second := Unit.from_data(centurion_data)
	var call_bones: Spell = null
	var raise_chief: Spell = null
	for spell in first.spells:
		if spell.get_effective_spell_id() == &"call_bones":
			call_bones = spell
		elif spell.get_effective_spell_id() == &"raise_chief":
			raise_chief = spell
	assert_not_null(call_bones)
	assert_not_null(raise_chief)
	assert_eq(runtime.can_prepare_summon(first, call_bones, 8), &"")
	assert_true(runtime.commit_prepared_summon(first, call_bones))
	runtime.clear_pending(first)
	assert_eq(runtime.can_prepare_summon(second, call_bones, 8), &"")
	assert_true(runtime.commit_prepared_summon(second, call_bones))
	runtime.clear_pending(second)
	assert_eq(runtime.can_prepare_summon(first, call_bones, 8), &"normal_summon_budget")
	assert_true(runtime.commit_prepared_summon(first, raise_chief))
	runtime.clear_pending(first)
	assert_eq(runtime.can_prepare_summon(second, raise_chief, 8), &"chief_summon_budget")
	assert_eq(runtime.snapshot().get("normal_summons_committed"), 2)
	assert_eq(runtime.snapshot().get("chief_summons_committed"), 1)


func test_all_fourteen_new_item_definitions_are_valid_unique_and_visual() -> void:
	var catalog := load(CATALOG_PATH) as ItemCatalog
	assert_not_null(catalog)
	var validation := catalog.validate_catalog()
	assert_true(validation.get("valid", false), str(validation.get("errors", [])))
	assert_gte(int(validation.get("definition_count", 0)), 19)
	var seen := {}
	for item_id in NEW_ITEM_IDS:
		var definition := catalog.get_definition(item_id)
		assert_not_null(definition, str(item_id))
		assert_true(definition.is_valid(), str(item_id))
		assert_not_null(definition.icon, str(item_id))
		assert_not_null(definition.card_texture, str(item_id))
		assert_true(definition.is_equippable(), str(item_id))
		assert_false(seen.has(definition.item_id), str(item_id))
		seen[definition.item_id] = true
	assert_eq(seen.size(), 14)


func test_item_definition_directory_auto_populates_the_reward_pool() -> void:
	var catalog := ItemCatalog.new()
	catalog.auto_discovery_directories = PackedStringArray([
		"res://data/items/definitions",
	])
	assert_true(catalog.rebuild_index())
	var expected_reward_ids: Array[StringName] = []
	for definition in catalog.get_definitions():
		if definition != null and (definition.is_equippable() or definition.is_relic()) \
				and definition.tags.has(FirstRunEquipmentRewardService.POOL_TAG):
			expected_reward_ids.append(definition.item_id)
	expected_reward_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return str(a) < str(b)
	)
	var service := FirstRunEquipmentRewardService.new()
	assert_true(service.reset(catalog, 2026))
	var snapshot := service.snapshot()
	var actual_reward_ids: Array[StringName] = []
	for value in snapshot.get("eligible_ids", []) as Array:
		actual_reward_ids.append(StringName(value))
	assert_eq(actual_reward_ids, expected_reward_ids)
	assert_eq(actual_reward_ids.size(), 8)
	for item_id in actual_reward_ids:
		assert_true(catalog.get_definition(item_id).is_relic(), str(item_id))


func test_reward_deck_recycles_declined_relics_for_five_non_final_rooms() -> void:
	var catalog := load(CATALOG_PATH) as ItemCatalog
	var service := FirstRunEquipmentRewardService.new()
	assert_true(service.reset(catalog, 1337))
	var states := _make_states()
	var inventory := RunInventory.new()
	assert_true(inventory.initialize(catalog, 24))
	var equipment := EquipmentService.new()
	assert_true(equipment.initialize(catalog))
	var offered := {}
	for room_index in 5:
		var report := _report(room_index)
		var options := service.build_options(report, states, inventory)
		assert_eq(options.size(), 2, "salle %d" % (room_index + 1))
		assert_ne(options[0].get("item_id"), options[1].get("item_id"))
		for option in options:
			var item_id := StringName(option.get("item_id", &""))
			if room_index < 4:
				assert_false(offered.has(item_id), "pioche fraîche avant recyclage")
			else:
				assert_true(offered.has(item_id), "relique refusée attendue au recyclage")
			offered[item_id] = true
			assert_true((option.get("definition") as ItemDefinition).is_relic())
			assert_true((option.get("compatible_character_ids", []) as Array).is_empty())
		var chosen := options[0] as Dictionary
		var result := service.apply(
			report,
			chosen.get("item_id"),
			&"",
			states,
			inventory,
			equipment,
		)
		assert_true(result.get("success", false), str(result))
		assert_eq(result.get("target_character_id"), &"")
		assert_false(result.get("equipped", true), str(result))
		for state in states:
			assert_true(state.equipment_loadout.get_equipped_items().is_empty())
		assert_false(service.apply(
			report,
			chosen.get("item_id"),
			&"",
			states,
			inventory,
			equipment,
		).get("success", true))
	assert_eq(offered.size(), 8)


func test_xp_requires_real_effect_limits_same_spell_and_caps_combat_at_five() -> void:
	var state := _make_states()[0]
	var service := CharacterProgressionService.new()
	var states := {state.character_id: state}
	var spell := state.unit.spells[0] as Spell
	var empty := service.grant_cast_xp(states, state.unit, spell, {"effective_cast": false})
	assert_false(empty.get("granted", true))
	assert_eq(empty.get("refusal_reason"), &"no_combat_state_change")
	state.unit.start_turn()
	var first := service.grant_cast_xp(states, state.unit, spell, {"effective_cast": true})
	assert_true(first.get("granted", false))
	var duplicate := service.grant_cast_xp(states, state.unit, spell, {"effective_cast": true})
	assert_false(duplicate.get("granted", true))
	assert_eq(duplicate.get("refusal_reason"), &"same_spell_already_awarded_this_activation")
	for _index in 4:
		state.unit.start_turn()
		assert_true(service.grant_cast_xp(
			states, state.unit, spell, {"effective_cast": true}
		).get("granted", false))
	state.unit.start_turn()
	var capped := service.grant_cast_xp(states, state.unit, spell, {"effective_cast": true})
	assert_false(capped.get("granted", true))
	assert_eq(capped.get("refusal_reason"), &"combat_cap_reached")
	assert_eq(service.get_combat_xp(state.character_id, spell.spell_id), 5)


func test_specialized_progression_reaches_ranks_only_on_rooms_1_3_5_6() -> void:
	var state := _make_states()[0]
	var service := CharacterProgressionService.new()
	var states := {state.character_id: state}
	var spell := state.unit.spells[0] as Spell
	var ranks: Array[int] = []
	for _room_index in 6:
		service.begin_combat()
		for _cast_index in 5:
			state.unit.start_turn()
			assert_true(service.grant_cast_xp(
				states, state.unit, spell, {"effective_cast": true}
			).get("granted", false))
		ranks.append(state.get_spell_progress(spell.spell_id).rank)
	assert_eq(ranks, [2, 2, 3, 3, 4, 5])


func test_all_twelve_trees_keep_thresholds_valid_nodes_and_sixteen_leaves() -> void:
	for state in _make_states():
		for discipline in state.get_disciplines():
			assert_eq(
				discipline.ranks.map(func(rank): return rank.required_total_xp),
				[0, 5, 12, 21, 30],
				str(discipline.discipline_id),
			)
			assert_true(
				SkillTreeResolver.validate_discipline(discipline).is_empty(),
				str(SkillTreeResolver.validate_discipline(discipline)),
			)
			for rank_data in discipline.ranks:
				for choice in rank_data.choices:
					assert_false(choice.get_spell_modifiers().is_empty(), str(choice.upgrade_id))
					for modifier in choice.get_spell_modifiers():
						assert_not_null(modifier, str(choice.upgrade_id))
			assert_eq(discipline.ranks[4].choices.size(), 4)
