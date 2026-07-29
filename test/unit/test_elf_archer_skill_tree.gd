extends GutTest

const Factory = preload("res://test/support/factory.gd")
const GameManagerScript = preload("res://core/game_manager.gd")

const ELF_PATH := "res://data/units/alliés/elfe.tres"
const ARCHER_ID := &"archer"
const PRECISE_SHOT_ID := &"elf_precise_shot"

const EAGLE_EYE := &"elf_archer_eagle_eye"
const REPEL_ARROW := &"elf_archer_repel_arrow"
const LONG_RANGE := &"elf_archer_long_range"
const PIERCING_SHOT := &"elf_archer_piercing_shot"
const HINDERING_ARROW := &"elf_archer_hindering_arrow"
const IMPACT_BOLT := &"elf_archer_impact_bolt"
const PERFECT_SIGHT := &"elf_archer_perfect_sight"
const STABILIZATION := &"elf_archer_stabilization"
const BARBED_TIP := &"elf_archer_barbed_tip"
const OPEN_BREACH := &"elf_archer_open_breach"
const PIN_ARROW := &"elf_archer_pin_arrow"
const TACTICAL_RETREAT := &"elf_archer_tactical_retreat"
const SIEGE_BOLT := &"elf_archer_siege_bolt"
const SHATTER := &"elf_archer_shatter"
const PERFECT_SHOT := &"elf_archer_perfect_shot"
const TRANSPIERCING_BOLT := &"elf_archer_transpiercing_bolt"
const SIEGE_ARROW := &"elf_archer_siege_arrow"
const STOPPING_ARROW := &"elf_archer_stopping_arrow"

const RANK_TWO_MIGRATION := [
	[
		"res://data/characters/elf/upgrades/eagle_eye.tres",
		EAGLE_EYE,
		PRECISE_SHOT_ID,
		"res://data/characters/elf/modifiers/eagle_eye.tres",
	],
	[
		"res://data/characters/elf/upgrades/repel_arrow.tres",
		REPEL_ARROW,
		PRECISE_SHOT_ID,
		"res://data/characters/elf/modifiers/repel_arrow.tres",
	],
	[
		"res://data/characters/elf/upgrades/backstab.tres",
		&"elf_assassin_backstab",
		&"elf_sneak_strike",
		"res://data/characters/elf/modifiers/backstab.tres",
	],
	[
		"res://data/characters/elf/upgrades/venomous_blade.tres",
		&"elf_assassin_venomous_blade",
		&"elf_sneak_strike",
		"res://data/characters/elf/modifiers/venomous_blade.tres",
	],
	[
		"res://data/characters/elf/upgrades/incandescent_core.tres",
		&"elf_mage_incandescent_core",
		&"elf_fireball",
		"res://data/characters/elf/modifiers/incandescent_core.tres",
	],
	[
		"res://data/characters/elf/upgrades/persistent_embers.tres",
		&"elf_mage_persistent_embers",
		&"elf_fireball",
		"res://data/characters/elf/modifiers/persistent_embers.tres",
	],
	[
		"res://data/characters/elf/upgrades/abundant_sap.tres",
		&"elf_healer_abundant_sap",
		&"elf_sylvan_heal",
		"res://data/characters/elf/modifiers/abundant_sap.tres",
	],
	[
		"res://data/characters/elf/upgrades/protective_bark.tres",
		&"elf_healer_protective_bark",
		&"elf_sylvan_heal",
		"res://data/characters/elf/modifiers/protective_bark.tres",
	],
]

const RANK_THREE_BY_BRANCH := {
	EAGLE_EYE: [LONG_RANGE, PIERCING_SHOT],
	REPEL_ARROW: [HINDERING_ARROW, IMPACT_BOLT],
}
const RANK_FOUR_BY_PARENT := {
	LONG_RANGE: [PERFECT_SIGHT, STABILIZATION],
	PIERCING_SHOT: [BARBED_TIP, OPEN_BREACH],
	HINDERING_ARROW: [PIN_ARROW, TACTICAL_RETREAT],
	IMPACT_BOLT: [SIEGE_BOLT, SHATTER],
}
const RANK_FIVE_BY_BRANCH := {
	EAGLE_EYE: [PERFECT_SHOT, TRANSPIERCING_BOLT],
	REPEL_ARROW: [SIEGE_ARROW, STOPPING_ARROW],
}

var manager = null
var manual_states: Array[CharacterRunState] = []


func after_each() -> void:
	for state in manual_states:
		if state != null:
			state.dispose()
	manual_states.clear()
	if manager != null and is_instance_valid(manager):
		manager.cleanup_run_state()
		manager._exit_tree()
		manager.free()
	manager = null


func _elf_data() -> UnitData:
	return load(ELF_PATH) as UnitData


func _archer_data() -> DisciplineData:
	for discipline in _elf_data().disciplines:
		if discipline != null and discipline.discipline_id == ARCHER_ID:
			return discipline
	return null


func _precise_shot() -> Spell:
	for spell in _elf_data().spells:
		if spell != null and spell.get_effective_spell_id() == PRECISE_SHOT_ID:
			return spell
	return null


func _make_state() -> CharacterRunState:
	var data := _elf_data()
	var state := CharacterRunState.new()
	assert_true(state.initialize(Unit.from_data(data), data))
	manual_states.append(state)
	return state


func _make_run(room_count: int = 2) -> RunData:
	var run := RunData.new()
	for _room_index in range(room_count):
		run.rooms.append(RoomData.new())
	return run


func _prepare_manager_state() -> CharacterRunState:
	manager = GameManagerScript.new()
	manager._ready()
	assert_true(manager._prepare_preconfigured_run(_make_run(), [ELF_PATH]))
	return manager.get_character_state(&"elf")


func _raise_to_five(state: CharacterRunState) -> void:
	var result := state.add_discipline_xp(ARCHER_ID, 18)
	assert_eq(result.get("rank", 0), 5)


func _select_path(
		state: CharacterRunState,
		node_ids: Array
	) -> void:
	if state.get_discipline_progress(ARCHER_ID).rank < 5:
		_raise_to_five(state)
	for index in node_ids.size():
		assert_true(
			state.select_upgrade(ARCHER_ID, index + 2, node_ids[index]),
			"selection %s au rang %d" % [node_ids[index], index + 2]
		)


func _available_ids(
		state: CharacterRunState,
		choice_rank: int
	) -> Array[StringName]:
	var progress := state.get_discipline_progress(ARCHER_ID)
	var result: Array[StringName] = []
	for node in SkillTreeResolver.get_available_nodes(
			_archer_data(),
			choice_rank,
			progress.rank,
			progress.get_pending_rank_choices(),
			progress.get_selected_upgrade_ids()
		):
		result.append(node.upgrade_id)
	return result


func _make_battle(
		state: CharacterRunState,
		caster_pos: Vector2i,
		target_pos: Vector2i,
		cols: int = 12,
		rows: int = 3,
		target_hp: int = 100
	) -> Dictionary:
	var battlefield := Factory.make_battlefield(cols, rows)
	var target := Unit.new("Cible", 1, target_hp)
	state.unit.current_ap = 99
	battlefield.grid.place_unit(state.unit, caster_pos)
	battlefield.grid.place_unit(target, target_pos)
	return {
		"battlefield": battlefield,
		"target": target,
	}


func _cast_battle(
		state: CharacterRunState,
		battle: Dictionary
	) -> Dictionary:
	state.unit.current_ap = 99
	var target := battle["target"] as Unit
	return battle["battlefield"].caster.cast(
		state.unit,
		_precise_shot(),
		target.grid_pos
	)


func _find_status(unit: Unit, status_name: String) -> Dictionary:
	for entry in unit.get_active_statuses():
		var data := entry.get("data") as StatusData
		if data != null and data.status_name == status_name:
			return entry
	return {}


func _count_status(unit: Unit, status_name: String) -> int:
	var count := 0
	for entry in unit.get_active_statuses():
		var data := entry.get("data") as StatusData
		if data != null and data.status_name == status_name:
			count += 1
	return count


func test_all_eight_rank_two_upgrades_migrate_without_contract_loss() -> void:
	for contract in RANK_TWO_MIGRATION:
		var node := load(contract[0]) as SkillUpgradeData
		assert_not_null(node, contract[0])
		assert_true(node is SkillTreeNodeData, contract[0])
		assert_eq(node.upgrade_id, contract[1], contract[0])
		assert_eq(node.rank, 2, contract[0])
		assert_eq(node.target_spell_id, contract[2], contract[0])
		assert_false(node.description.strip_edges().is_empty(), contract[0])
		assert_eq(node.get_spell_modifiers().size(), 1, contract[0])
		assert_eq(
			node.get_spell_modifiers()[0].resource_path,
			contract[3],
			contract[0]
		)
		assert_true(
			(node as SkillTreeNodeData).prerequisite_node_ids.is_empty(),
			contract[0]
		)
		assert_true(
			(node as SkillTreeNodeData).excluded_node_ids.is_empty(),
			contract[0]
		)


func test_archer_tree_has_exact_thresholds_unique_nodes_and_no_diagnostic() -> void:
	var discipline := _archer_data()
	assert_not_null(discipline)
	assert_eq(
		discipline.ranks.map(
			func(rank_data): return rank_data.required_total_xp
		),
		[0, 3, 7, 12, 18]
	)
	assert_eq(
		discipline.ranks.map(func(rank_data): return rank_data.choices.size()),
		[0, 2, 4, 8, 4]
	)
	assert_true(
		SkillTreeResolver.validate_discipline(discipline).is_empty(),
		str(SkillTreeResolver.validate_discipline(discipline))
	)
	var ids: Array[StringName] = []
	for rank_data in discipline.ranks:
		for choice in rank_data.choices:
			assert_true(choice is SkillTreeNodeData)
			assert_false(ids.has(choice.upgrade_id), str(choice.upgrade_id))
			ids.append(choice.upgrade_id)
			assert_eq(choice.discipline_id, ARCHER_ID)
			assert_eq(choice.rank, rank_data.rank)
			assert_eq(choice.target_spell_id, PRECISE_SHOT_ID)
			assert_false(choice.display_name.strip_edges().is_empty())
			assert_false(choice.description.strip_edges().is_empty())
	assert_eq(ids.size(), 18)


func test_rank_three_candidates_follow_the_selected_main_branch() -> void:
	var eagle_state := _make_state()
	_raise_to_five(eagle_state)
	assert_eq(_available_ids(eagle_state, 2), [EAGLE_EYE, REPEL_ARROW])
	assert_true(eagle_state.select_upgrade(ARCHER_ID, 2, EAGLE_EYE))
	assert_eq(
		_available_ids(eagle_state, 3),
		[LONG_RANGE, PIERCING_SHOT]
	)
	assert_false(
		eagle_state.select_upgrade(ARCHER_ID, 3, HINDERING_ARROW)
	)
	assert_eq(
		eagle_state.get_discipline_progress(
			ARCHER_ID
		).get_selected_upgrade_ids(),
		[EAGLE_EYE]
	)

	var repel_state := _make_state()
	_raise_to_five(repel_state)
	assert_true(repel_state.select_upgrade(ARCHER_ID, 2, REPEL_ARROW))
	assert_eq(
		_available_ids(repel_state, 3),
		[HINDERING_ARROW, IMPACT_BOLT]
	)


func test_rank_four_and_five_candidates_follow_the_required_ancestors() -> void:
	for branch in RANK_THREE_BY_BRANCH:
		for rank_three in RANK_THREE_BY_BRANCH[branch]:
			var state := _make_state()
			_raise_to_five(state)
			assert_true(state.select_upgrade(ARCHER_ID, 2, branch))
			assert_true(state.select_upgrade(ARCHER_ID, 3, rank_three))
			assert_eq(
				_available_ids(state, 4),
				RANK_FOUR_BY_PARENT[rank_three]
			)
			assert_true(state.select_upgrade(
				ARCHER_ID,
				4,
				RANK_FOUR_BY_PARENT[rank_three][0]
			))
			assert_eq(
				_available_ids(state, 5),
				RANK_FIVE_BY_BRANCH[branch]
			)


func test_archer_tree_has_exactly_sixteen_final_configurations() -> void:
	var configurations := 0
	for branch in RANK_THREE_BY_BRANCH:
		for rank_three in RANK_THREE_BY_BRANCH[branch]:
			for rank_four in RANK_FOUR_BY_PARENT[rank_three]:
				for rank_five in RANK_FIVE_BY_BRANCH[branch]:
					var state := _make_state()
					_select_path(
						state,
						[branch, rank_three, rank_four, rank_five]
					)
					assert_true(
						state.get_discipline_progress(
							ARCHER_ID
						).get_pending_rank_choices().is_empty()
					)
					configurations += 1
	assert_eq(configurations, 16)


func test_eighteen_successful_precise_shots_grant_exact_xp_and_queue_all_ranks() -> void:
	var state := _prepare_manager_state()
	assert_false(state.unit.has_energy())
	var battle := _make_battle(
		state,
		Vector2i(0, 1),
		Vector2i(3, 1),
		8,
		3,
		10000
	)
	for expected_xp in range(1, 19):
		var report := _cast_battle(state, battle)
		assert_false(report.get("failed", false))
		assert_eq(
			state.get_discipline_progress(ARCHER_ID).xp,
			expected_xp
		)
	assert_eq(
		state.get_discipline_progress(
			ARCHER_ID
		).get_pending_rank_choices(),
		[2, 3, 4, 5]
	)
	assert_true(
		_available_ids(state, 3).is_empty(),
		"le rang 2 doit etre resolu avant le rang 3"
	)
	assert_false(state.select_upgrade(ARCHER_ID, 3, LONG_RANGE))
	assert_eq(
		state.get_discipline_progress(
			ARCHER_ID
		).get_selected_upgrade_ids(),
		[]
	)


func test_range_and_damage_bonuses_stack_without_mutating_precise_shot() -> void:
	var state := _make_state()
	_select_path(
		state,
		[EAGLE_EYE, LONG_RANGE, STABILIZATION, PERFECT_SHOT]
	)
	var spell := _precise_shot()
	assert_eq(spell.spell_range, 7)
	var battle := _make_battle(
		state,
		Vector2i(0, 1),
		Vector2i(10, 1),
		12,
		3
	)
	assert_eq(
		battle["battlefield"].caster.get_effective_spell_range(
			state.unit,
			spell
		),
		10
	)
	var report := _cast_battle(state, battle)
	assert_false(report.get("failed", false))
	assert_eq(battle["target"].current_hp, 82)
	assert_eq(spell.spell_range, 7)
	assert_eq(spell.damage, 7)


func test_open_breach_grants_two_refreshing_physical_charges() -> void:
	var state := _make_state()
	_select_path(
		state,
		[EAGLE_EYE, PIERCING_SHOT, OPEN_BREACH, PERFECT_SHOT]
	)
	var battle := _make_battle(
		state,
		Vector2i(0, 1),
		Vector2i(2, 1)
	)
	_cast_battle(state, battle)
	var target := battle["target"] as Unit
	var breach := _find_status(target, "Brèche physique")
	assert_eq(breach.get("charges", 0), 2)
	var attacker := Unit.new("Attaquant", 0)
	target.take_damage(5, attacker, Spell.DamageType.PHYSICAL)
	assert_eq(target.current_hp, 86)
	assert_eq(_find_status(target, "Brèche physique").get("charges", 0), 1)
	target.take_damage(5, attacker, Spell.DamageType.PHYSICAL)
	assert_eq(target.current_hp, 79)
	assert_true(_find_status(target, "Brèche physique").is_empty())
	target.take_damage(5, attacker, Spell.DamageType.PHYSICAL)
	assert_eq(target.current_hp, 74)


func test_barbed_tip_bleeds_at_turn_end_twice_and_refreshes_without_stack() -> void:
	var state := _make_state()
	_select_path(
		state,
		[EAGLE_EYE, PIERCING_SHOT, BARBED_TIP, PERFECT_SHOT]
	)
	var battle := _make_battle(
		state,
		Vector2i(0, 1),
		Vector2i(2, 1)
	)
	_cast_battle(state, battle)
	var target := battle["target"] as Unit
	assert_eq(_find_status(target, "Saignement").get("remaining", 0), 2)
	target.tick_statuses()
	assert_eq(target.current_hp, 91)
	assert_eq(_find_status(target, "Saignement").get("remaining", 0), 1)
	_cast_battle(state, battle)
	assert_eq(_find_status(target, "Saignement").get("remaining", 0), 2)
	assert_eq(_count_status(target, "Saignement"), 1)
	target.tick_statuses()
	target.tick_statuses()
	assert_eq(target.current_hp, 78)
	assert_true(_find_status(target, "Saignement").is_empty())


func test_hindering_pin_and_tactical_retreat_apply_next_turn_movement_once() -> void:
	var retreat_state := _make_state()
	_select_path(
		retreat_state,
		[REPEL_ARROW, HINDERING_ARROW, TACTICAL_RETREAT]
	)
	var retreat_battle := _make_battle(
		retreat_state,
		Vector2i(0, 1),
		Vector2i(2, 1)
	)
	_cast_battle(retreat_state, retreat_battle)
	var hindered := retreat_battle["target"] as Unit
	hindered.start_turn()
	retreat_state.unit.start_turn()
	assert_eq(hindered.current_mp, 2)
	assert_eq(retreat_state.unit.current_mp, 4)

	var pin_state := _make_state()
	_select_path(pin_state, [REPEL_ARROW, HINDERING_ARROW, PIN_ARROW])
	var pin_battle := _make_battle(
		pin_state,
		Vector2i(0, 1),
		Vector2i(2, 1)
	)
	_cast_battle(pin_state, pin_battle)
	var pinned := pin_battle["target"] as Unit
	pinned.start_turn()
	assert_eq(pinned.current_mp, 1)


func test_impact_siege_bolt_and_shatter_resolve_collision_totals_once() -> void:
	var siege_state := _make_state()
	_select_path(siege_state, [REPEL_ARROW, IMPACT_BOLT, SIEGE_BOLT])
	var siege_battle := _make_battle(
		siege_state,
		Vector2i(0, 1),
		Vector2i(1, 1),
		6,
		3
	)
	siege_battle["battlefield"].grid.set_type(
		Vector2i(2, 1),
		GridData.CellType.WALL
	)
	var siege_report := _cast_battle(siege_state, siege_battle)
	assert_true(siege_report["collision"])
	assert_eq(siege_battle["target"].current_hp, 89)

	var shatter_state := _make_state()
	_select_path(shatter_state, [REPEL_ARROW, IMPACT_BOLT, SHATTER])
	var shatter_battle := _make_battle(
		shatter_state,
		Vector2i(0, 1),
		Vector2i(1, 1),
		6,
		3
	)
	shatter_battle["battlefield"].grid.set_type(
		Vector2i(2, 1),
		GridData.CellType.WALL
	)
	_cast_battle(shatter_state, shatter_battle)
	assert_eq(shatter_battle["target"].current_hp, 85)


func test_siege_arrow_enforces_exact_three_push_and_eight_collision_damage() -> void:
	var open_state := _make_state()
	_select_path(
		open_state,
		[REPEL_ARROW, IMPACT_BOLT, SHATTER, SIEGE_ARROW]
	)
	var open_battle := _make_battle(
		open_state,
		Vector2i(0, 1),
		Vector2i(1, 1),
		8,
		3
	)
	_cast_battle(open_state, open_battle)
	assert_eq(open_battle["target"].grid_pos, Vector2i(4, 1))

	var wall_state := _make_state()
	_select_path(
		wall_state,
		[REPEL_ARROW, IMPACT_BOLT, SHATTER, SIEGE_ARROW]
	)
	var wall_battle := _make_battle(
		wall_state,
		Vector2i(0, 1),
		Vector2i(1, 1),
		6,
		3
	)
	wall_battle["battlefield"].grid.set_type(
		Vector2i(2, 1),
		GridData.CellType.WALL
	)
	_cast_battle(wall_state, wall_battle)
	assert_eq(wall_battle["target"].current_hp, 85)


func test_stopping_arrow_applies_two_mp_loss_and_one_collision_bonus() -> void:
	var state := _make_state()
	_select_path(
		state,
		[REPEL_ARROW, HINDERING_ARROW, PIN_ARROW, STOPPING_ARROW]
	)
	var battle := _make_battle(
		state,
		Vector2i(0, 1),
		Vector2i(1, 1),
		5,
		3
	)
	battle["battlefield"].grid.set_type(
		Vector2i(2, 1),
		GridData.CellType.WALL
	)
	_cast_battle(state, battle)
	var target := battle["target"] as Unit
	assert_eq(target.current_hp, 89)
	target.start_turn()
	assert_eq(target.current_mp, 1)


func test_transpiercing_bolt_hits_one_aligned_enemy_once_without_extra_xp() -> void:
	var state := _prepare_manager_state()
	_raise_to_five(state)
	_select_path(
		state,
		[EAGLE_EYE, LONG_RANGE, STABILIZATION, TRANSPIERCING_BOLT]
	)
	var battlefield := Factory.make_battlefield(8, 3)
	var primary := Unit.new("Principale", 1)
	var secondary := Unit.new("Secondaire", 1)
	state.unit.current_ap = 99
	battlefield.grid.place_unit(state.unit, Vector2i(0, 1))
	battlefield.grid.place_unit(primary, Vector2i(2, 1))
	battlefield.grid.place_unit(secondary, Vector2i(4, 1))
	var xp_before := state.get_discipline_progress(ARCHER_ID).xp
	var report := battlefield.caster.cast(
		state.unit,
		_precise_shot(),
		primary.grid_pos
	)
	assert_false(report.get("failed", false))
	assert_eq(primary.current_hp, 91)
	assert_eq(secondary.current_hp, 96)
	assert_eq(
		state.get_discipline_progress(ARCHER_ID).xp,
		xp_before + 1
	)
	assert_eq(report["damaged_enemies"].count(primary), 1)
	assert_eq(report["damaged_enemies"].count(secondary), 1)


func test_transpiercing_bolt_stops_at_a_grid_obstacle() -> void:
	var state := _make_state()
	_select_path(
		state,
		[EAGLE_EYE, LONG_RANGE, STABILIZATION, TRANSPIERCING_BOLT]
	)
	var battlefield := Factory.make_battlefield(8, 3)
	var primary := Unit.new("Principale", 1)
	var secondary := Unit.new("Secondaire", 1)
	state.unit.current_ap = 99
	battlefield.grid.place_unit(state.unit, Vector2i(0, 1))
	battlefield.grid.place_unit(primary, Vector2i(2, 1))
	battlefield.grid.set_type(Vector2i(3, 1), GridData.CellType.WALL)
	battlefield.grid.place_unit(secondary, Vector2i(4, 1))
	battlefield.caster.cast(state.unit, _precise_shot(), primary.grid_pos)
	assert_eq(primary.current_hp, 91)
	assert_eq(secondary.current_hp, 100)


func test_archer_choices_and_modifiers_persist_then_reset_on_new_run() -> void:
	var state := _prepare_manager_state()
	_raise_to_five(state)
	_select_path(
		state,
		[EAGLE_EYE, LONG_RANGE, STABILIZATION, PERFECT_SHOT]
	)
	var selected := state.get_discipline_progress(
		ARCHER_ID
	).get_selected_upgrade_ids()
	var modifier_count := state.unit.get_progression_spell_modifiers().size()
	assert_false(state.unit.has_energy())
	manager.current_room_index = 0
	manager._go_to_next_room()
	assert_same(manager.get_character_state(&"elf"), state)
	assert_eq(
		state.get_discipline_progress(
			ARCHER_ID
		).get_selected_upgrade_ids(),
		selected
	)
	state._sync_progression_modifiers_to_unit()
	state._sync_progression_modifiers_to_unit()
	assert_eq(
		state.unit.get_progression_spell_modifiers().size(),
		modifier_count
	)

	assert_true(manager._prepare_preconfigured_run(_make_run(), [ELF_PATH]))
	var fresh := manager.get_character_state(&"elf") as CharacterRunState
	assert_not_same(fresh, state)
	assert_true(
		fresh.get_discipline_progress(
			ARCHER_ID
		).get_selected_upgrade_ids().is_empty()
	)
	assert_true(fresh.unit.get_progression_spell_modifiers().is_empty())
	assert_false(fresh.unit.has_energy())
