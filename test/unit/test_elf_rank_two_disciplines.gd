extends GutTest

const Factory = preload("res://test/support/factory.gd")
const GameManagerScript = preload("res://core/game_manager.gd")

const ELF_PATH := "res://data/units/alliés/elfe.tres"

const EAGLE_EYE_ID := &"elf_archer_eagle_eye"
const REPEL_ARROW_ID := &"elf_archer_repel_arrow"
const BACKSTAB_ID := &"elf_assassin_dans_le_dos"
const VENOMOUS_BLADE_ID := &"elf_assassin_lame_venimeuse"
const ABUNDANT_SAP_ID := &"elf_healer_seve_abondante"
const PROTECTIVE_BARK_ID := &"elf_healer_ecorce_protectrice"
const INCANDESCENT_ID := &"elf_mage_cur_incandescent"
const EMBERS_ID := &"elf_mage_braises_persistantes"

const DISCIPLINE_IDS := [&"archer", &"assassin", &"mage", &"healer"]
const NEW_DISCIPLINE_IDS := [&"archer", &"assassin", &"healer"]
const NEW_UPGRADE_IDS := [
	[EAGLE_EYE_ID, REPEL_ARROW_ID],
	[BACKSTAB_ID, VENOMOUS_BLADE_ID],
	[ABUNDANT_SAP_ID, PROTECTIVE_BARK_ID],
]
const TARGET_SPELL_IDS := [
	[&"elf_precise_shot", &"elf_precise_shot"],
	[&"elf_sneak_strike", &"elf_sneak_strike"],
	[&"elf_sylvan_heal", &"elf_sylvan_heal"],
]

var manager


func before_each() -> void:
	manager = GameManagerScript.new()
	manager._ready()


func after_each() -> void:
	if manager != null and is_instance_valid(manager):
		manager.cleanup_run_state()
		manager._exit_tree()
		manager.free()


func _make_run(room_count: int = 2) -> RunData:
	var run := RunData.new()
	for _room_index in range(room_count):
		run.rooms.append(RoomData.new())
	return run


func _prepare_elf() -> CharacterRunState:
	assert_true(manager._prepare_preconfigured_run(_make_run(), [ELF_PATH]))
	return manager.get_character_state(&"elf")


func _elf_spell(index: int) -> Spell:
	return (load(ELF_PATH) as UnitData).spells[index]


func _raise_and_select(
		state: CharacterRunState,
		discipline_id: StringName,
		upgrade_id: StringName
	) -> void:
	var result := state.add_discipline_xp(discipline_id, 5)
	assert_eq(result.get("rank", 0), 2)
	assert_true(state.select_upgrade(discipline_id, 2, upgrade_id))


func _make_enemy_cast(
		state: CharacterRunState,
		spell: Spell,
		caster_pos: Vector2i,
		target_pos: Vector2i,
		target_hp: int = 100,
		cols: int = 10,
		rows: int = 5
	) -> Dictionary:
	var battlefield := Factory.make_battlefield(cols, rows)
	var target := Unit.new("Cible", 1, target_hp)
	state.unit.current_ap = state.unit.max_ap.get_int()
	battlefield.grid.place_unit(state.unit, caster_pos)
	battlefield.grid.place_unit(target, target_pos)
	var report: Dictionary = battlefield.caster.cast(state.unit, spell, target_pos)
	return {
		"battlefield": battlefield,
		"target": target,
		"report": report,
	}


func _make_heal_spell(spell_id: StringName) -> Spell:
	return Factory.make_spell({
		"spell_id": spell_id,
		"spell_range": 5,
		"can_target_enemy": false,
		"can_target_ally": true,
		"can_target_self": true,
		"heal": 7,
	})


func _find_status(unit: Unit, status_name: String) -> Dictionary:
	for entry in unit.get_active_statuses():
		var data := entry.get("data") as StatusData
		if data != null and data.status_name == status_name:
			return entry
	return {}


func test_new_disciplines_reach_rank_two_at_three_xp_once() -> void:
	var state := _prepare_elf()
	for discipline_id in NEW_DISCIPLINE_IDS:
		var progress := state.get_discipline_progress(discipline_id)
		assert_eq(progress.rank, 1, str(discipline_id))
		assert_eq(progress.xp, 0, str(discipline_id))
		assert_true(progress.add_xp(4).is_empty(), str(discipline_id))
		assert_eq(progress.rank, 1, str(discipline_id))
		assert_eq(progress.add_xp(1), [2], str(discipline_id))
		assert_eq(progress.rank, 2, str(discipline_id))
		assert_eq(progress.get_pending_rank_choices(), [2], str(discipline_id))
		var later_reached_ranks := progress.add_xp(16)
		assert_eq(later_reached_ranks, [3, 4], str(discipline_id))
		assert_eq(progress.get_pending_rank_choices(), [2, 3, 4], str(discipline_id))


func test_each_new_rank_has_exactly_two_expected_exclusive_choices() -> void:
	var elf_data := load(ELF_PATH) as UnitData
	for index in NEW_DISCIPLINE_IDS.size():
		var discipline: DisciplineData = elf_data.disciplines[
			DISCIPLINE_IDS.find(NEW_DISCIPLINE_IDS[index])
		]
		assert_eq(discipline.ranks.size(), 5, str(discipline.discipline_id))
		assert_eq([discipline.ranks[0].rank, discipline.ranks[0].required_total_xp], [1, 0])
		assert_eq([discipline.ranks[1].rank, discipline.ranks[1].required_total_xp], [2, 5])
		assert_eq(
			discipline.ranks[1].choices.map(
				func(upgrade): return upgrade.upgrade_id
			),
			NEW_UPGRADE_IDS[index],
		)
		assert_eq(
			discipline.ranks[1].choices.map(
				func(upgrade): return upgrade.target_spell_id
			),
			[&"", &""],
		)


func test_mage_rank_two_data_matches_the_preview_migration() -> void:
	var mage := (load(ELF_PATH) as UnitData).disciplines[2] as DisciplineData
	assert_eq(mage.discipline_id, &"mage")
	assert_eq(mage.ranks.size(), 5)
	assert_eq([mage.ranks[1].rank, mage.ranks[1].required_total_xp], [2, 5])
	assert_eq(
		mage.ranks[1].choices.map(func(upgrade): return upgrade.upgrade_id),
		[INCANDESCENT_ID, EMBERS_ID],
	)


func test_upgrade_selection_is_exclusive_inside_each_new_discipline() -> void:
	var state := _prepare_elf()
	for index in NEW_DISCIPLINE_IDS.size():
		var discipline_id: StringName = NEW_DISCIPLINE_IDS[index]
		state.add_discipline_xp(discipline_id, 5)
		assert_true(state.select_upgrade(discipline_id, 2, NEW_UPGRADE_IDS[index][0]))
		assert_false(state.select_upgrade(discipline_id, 2, NEW_UPGRADE_IDS[index][1]))
		assert_eq(
			state.get_discipline_progress(discipline_id).get_selected_upgrade_ids(),
			[NEW_UPGRADE_IDS[index][0]],
		)


func test_each_elf_spell_grants_xp_only_to_its_display_named_discipline() -> void:
	var state := _prepare_elf()
	var progress_events: Array = []
	manager.discipline_xp_gained.connect(
		func(_character_id, discipline_id, amount, snapshot):
			progress_events.append([
				discipline_id,
				amount,
				snapshot.get("discipline_display_name", ""),
			])
	)
	for spell_index in 3:
		var result := _make_enemy_cast(
			state,
			_elf_spell(spell_index),
			Vector2i(0, 1),
			Vector2i(1, 1) if spell_index == 1 else Vector2i(3, 1),
			1000,
		)
		assert_false(result["report"].get("failed", false))
	var heal_field := Factory.make_battlefield(5, 3)
	var ally := Unit.new("Allié", 0)
	ally.current_hp = 50
	state.unit.current_ap = state.unit.max_ap.get_int()
	heal_field.grid.place_unit(state.unit, Vector2i(0, 1))
	heal_field.grid.place_unit(ally, Vector2i(1, 1))
	heal_field.caster.cast(state.unit, _elf_spell(3), ally.grid_pos)
	assert_eq(
		progress_events,
		[
			[&"archer", 1, "Archer"],
			[&"assassin", 1, "Assassin"],
			[&"mage", 1, "Mage"],
			[&"healer", 1, "Soigneur"],
		],
	)


func test_eagle_eye_has_no_bonus_at_manhattan_distance_three() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"archer", EAGLE_EYE_ID)
	var result := _make_enemy_cast(
		state, _elf_spell(0), Vector2i(0, 1), Vector2i(3, 1)
	)
	assert_eq(result["target"].current_hp, 93)


func test_eagle_eye_adds_five_at_distance_four() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"archer", EAGLE_EYE_ID)
	var result := _make_enemy_cast(
		state, _elf_spell(0), Vector2i(0, 1), Vector2i(4, 1)
	)
	assert_eq(result["target"].current_hp, 88)


func test_eagle_eye_adds_five_beyond_distance_four() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"archer", EAGLE_EYE_ID)
	var result := _make_enemy_cast(
		state, _elf_spell(0), Vector2i(0, 0), Vector2i(5, 1)
	)
	assert_eq(result["target"].current_hp, 88)


func test_eagle_eye_uses_the_range_system_manhattan_metric() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"archer", EAGLE_EYE_ID)
	var result := _make_enemy_cast(
		state, _elf_spell(0), Vector2i(0, 0), Vector2i(3, 1)
	)
	var battlefield = result["battlefield"]
	assert_eq(battlefield.grid.manhattan(Vector2i(0, 0), Vector2i(3, 1)), 4)
	assert_lt(Vector2(3, 1).length(), 4.0)
	assert_eq(result["target"].current_hp, 88)


func test_eagle_eye_does_not_affect_other_spell_or_caster_or_spell_resource() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"archer", EAGLE_EYE_ID)
	var precise_shot := _elf_spell(0)
	var original_damage := precise_shot.damage
	var other_spell := Factory.make_spell({
		"spell_id": &"other_archer_spell",
		"spell_range": 7,
		"damage": 7,
	})
	var wrong_spell_result := _make_enemy_cast(
		state, other_spell, Vector2i(0, 1), Vector2i(4, 1)
	)
	assert_eq(wrong_spell_result["target"].current_hp, 93)
	var other_caster := Unit.new("Autre", 0)
	var battlefield := Factory.make_battlefield(8, 3)
	var target := Unit.new("Cible", 1)
	battlefield.grid.place_unit(other_caster, Vector2i(0, 1))
	battlefield.grid.place_unit(target, Vector2i(4, 1))
	battlefield.caster.cast(other_caster, precise_shot, target.grid_pos)
	assert_eq(target.current_hp, 93)
	assert_eq(precise_shot.damage, original_damage)


func test_repel_arrow_pushes_exactly_one_cell_even_with_force() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"archer", REPEL_ARROW_ID)
	state.unit.force.base_value = 100.0
	var spell := _elf_spell(0)
	var original_push := spell.push_distance
	var result := _make_enemy_cast(
		state, spell, Vector2i(1, 1), Vector2i(2, 1), 100, 6, 3
	)
	assert_true(result["report"]["pushed"])
	assert_eq(result["target"].grid_pos, Vector2i(3, 1))
	assert_eq(spell.push_distance, original_push)


func test_repel_arrow_respects_wall_and_keeps_cast_valid() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"archer", REPEL_ARROW_ID)
	var battlefield := Factory.make_battlefield(5, 3)
	var target := Unit.new("Cible", 1)
	battlefield.grid.set_type(Vector2i(3, 1), GridData.CellType.WALL)
	battlefield.grid.place_unit(state.unit, Vector2i(1, 1))
	battlefield.grid.place_unit(target, Vector2i(2, 1))
	var report: Dictionary = battlefield.caster.cast(
		state.unit, _elf_spell(0), target.grid_pos
	)
	assert_false(report.get("failed", false))
	assert_false(report["pushed"])
	assert_true(report["collision"])
	assert_eq(target.grid_pos, Vector2i(2, 1))


func test_repel_arrow_respects_grid_boundary() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"archer", REPEL_ARROW_ID)
	var result := _make_enemy_cast(
		state, _elf_spell(0), Vector2i(0, 0), Vector2i(1, 0), 100, 2, 1
	)
	assert_false(result["report"].get("failed", false))
	assert_false(result["report"]["pushed"])
	assert_true(result["report"]["collision"])
	assert_eq(result["target"].grid_pos, Vector2i(1, 0))


func test_repel_arrow_respects_occupied_cell_collision() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"archer", REPEL_ARROW_ID)
	var battlefield := Factory.make_battlefield(5, 1)
	var target := Unit.new("Cible", 1)
	var blocker := Unit.new("Bloqueur", 1)
	battlefield.grid.place_unit(state.unit, Vector2i(0, 0))
	battlefield.grid.place_unit(target, Vector2i(1, 0))
	battlefield.grid.place_unit(blocker, Vector2i(2, 0))
	var report: Dictionary = battlefield.caster.cast(
		state.unit, _elf_spell(0), target.grid_pos
	)
	assert_false(report.get("failed", false))
	assert_true(report["collision"])
	assert_false(report["pushed"])
	assert_eq(target.grid_pos, Vector2i(1, 0))
	assert_eq(blocker.grid_pos, Vector2i(2, 0))


func test_repel_arrow_does_not_push_with_another_spell() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"archer", REPEL_ARROW_ID)
	var other_spell := Factory.make_spell({
		"spell_id": &"other_spell",
		"spell_range": 5,
		"damage": 1,
	})
	var result := _make_enemy_cast(
		state, other_spell, Vector2i(0, 0), Vector2i(1, 0), 100, 5, 1
	)
	assert_eq(result["target"].grid_pos, Vector2i(1, 0))
	assert_false(result["report"]["pushed"])


func test_repel_arrow_does_not_leak_to_another_caster() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"archer", REPEL_ARROW_ID)
	var other_caster := Unit.new("Autre archer", 0)
	var target := Unit.new("Cible", 1)
	var battlefield := Factory.make_battlefield(5, 1)
	battlefield.grid.place_unit(other_caster, Vector2i(0, 0))
	battlefield.grid.place_unit(target, Vector2i(1, 0))
	battlefield.caster.cast(other_caster, _elf_spell(0), target.grid_pos)
	assert_eq(target.grid_pos, Vector2i(1, 0))


func test_backstab_adds_five_for_all_logical_facings() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"assassin", BACKSTAB_ID)
	var target_pos := Vector2i(2, 2)
	for facing in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var battlefield := Factory.make_battlefield(5, 5)
		var target := Unit.new("Cible", 1)
		target.facing_dir = facing
		state.unit.current_ap = state.unit.max_ap.get_int()
		battlefield.grid.place_unit(state.unit, target_pos - facing)
		battlefield.grid.place_unit(target, target_pos)
		assert_true(target.is_grid_position_behind(state.unit.grid_pos))
		battlefield.caster.cast(state.unit, _elf_spell(1), target_pos)
		assert_eq(target.current_hp, 88, str(facing))


func test_backstab_has_no_bonus_from_front_or_side() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"assassin", BACKSTAB_ID)
	for caster_pos in [Vector2i(3, 2), Vector2i(2, 1)]:
		var battlefield := Factory.make_battlefield(5, 5)
		var target := Unit.new("Cible", 1)
		target.facing_dir = Vector2i.RIGHT
		state.unit.current_ap = state.unit.max_ap.get_int()
		battlefield.grid.place_unit(state.unit, caster_pos)
		battlefield.grid.place_unit(target, Vector2i(2, 2))
		assert_false(target.is_grid_position_behind(caster_pos))
		battlefield.caster.cast(state.unit, _elf_spell(1), target.grid_pos)
		assert_eq(target.current_hp, 93, str(caster_pos))


func test_backstab_does_not_affect_other_spell_or_caster_or_resource() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"assassin", BACKSTAB_ID)
	var sneak_strike := _elf_spell(1)
	var original_damage := sneak_strike.damage
	var other_spell := Factory.make_spell({
		"spell_id": &"other_melee",
		"spell_range": 1,
		"damage": 7,
	})
	var wrong_spell := _make_enemy_cast(
		state, other_spell, Vector2i(1, 2), Vector2i(2, 2), 100, 5, 5
	)
	wrong_spell["target"].facing_dir = Vector2i.RIGHT
	assert_eq(wrong_spell["target"].current_hp, 93)
	var other_caster := Unit.new("Autre", 0)
	var battlefield := Factory.make_battlefield(5, 5)
	var target := Unit.new("Cible", 1)
	target.facing_dir = Vector2i.RIGHT
	battlefield.grid.place_unit(other_caster, Vector2i(1, 2))
	battlefield.grid.place_unit(target, Vector2i(2, 2))
	battlefield.caster.cast(other_caster, sneak_strike, target.grid_pos)
	assert_eq(target.current_hp, 93)
	assert_eq(sneak_strike.damage, original_damage)


func test_venomous_blade_deals_two_damage_for_exactly_two_turn_starts() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"assassin", VENOMOUS_BLADE_ID)
	var result := _make_enemy_cast(
		state, _elf_spell(1), Vector2i(1, 1), Vector2i(2, 1)
	)
	var target: Unit = result["target"]
	var status := _find_status(target, "Poison")
	assert_not_null(status.get("data"))
	assert_eq(status.get("remaining"), 2)
	var after_strike := target.current_hp
	target.process_statuses()
	assert_eq(target.current_hp, after_strike - 2)
	target.tick_statuses()
	target.process_statuses()
	assert_eq(target.current_hp, after_strike - 4)
	target.tick_statuses()
	assert_true(_find_status(target, "Poison").is_empty())
	target.process_statuses()
	assert_eq(target.current_hp, after_strike - 4)


func test_venomous_blade_reapplication_refreshes_duration_without_stack() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"assassin", VENOMOUS_BLADE_ID)
	var result := _make_enemy_cast(
		state, _elf_spell(1), Vector2i(1, 1), Vector2i(2, 1)
	)
	var battlefield = result["battlefield"]
	var target: Unit = result["target"]
	target.process_statuses()
	target.tick_statuses()
	assert_eq(_find_status(target, "Poison").get("remaining"), 1)
	state.unit.current_ap = state.unit.max_ap.get_int()
	battlefield.caster.cast(state.unit, _elf_spell(1), target.grid_pos)
	assert_eq(target.get_active_statuses().size(), 1)
	assert_eq(_find_status(target, "Poison").get("remaining"), 2)
	var after_reapplication := target.current_hp
	target.process_statuses()
	target.tick_statuses()
	target.process_statuses()
	target.tick_statuses()
	assert_eq(target.current_hp, after_reapplication - 4)
	assert_true(_find_status(target, "Poison").is_empty())
	target.process_statuses()
	assert_eq(target.current_hp, after_reapplication - 4)


func test_venomous_blade_is_not_applied_on_refused_or_other_spell() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"assassin", VENOMOUS_BLADE_ID)
	var battlefield := Factory.make_battlefield(5, 1)
	var target := Unit.new("Cible", 1)
	battlefield.grid.place_unit(state.unit, Vector2i(0, 0))
	battlefield.grid.place_unit(target, Vector2i(1, 0))
	state.unit.current_ap = 0
	var refused: Dictionary = battlefield.caster.cast(
		state.unit, _elf_spell(1), target.grid_pos
	)
	assert_true(refused.get("failed", false))
	assert_true(target.get_active_statuses().is_empty())
	state.unit.current_ap = state.unit.max_ap.get_int()
	var other_spell := Factory.make_spell({
		"spell_id": &"other_melee",
		"spell_range": 1,
		"damage": 1,
	})
	battlefield.caster.cast(state.unit, other_spell, target.grid_pos)
	assert_true(target.get_active_statuses().is_empty())


func test_venomous_blade_does_not_leak_to_another_caster() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"assassin", VENOMOUS_BLADE_ID)
	var other_caster := Unit.new("Autre assassin", 0)
	var target := Unit.new("Cible", 1)
	var battlefield := Factory.make_battlefield(5, 1)
	battlefield.grid.place_unit(other_caster, Vector2i(0, 0))
	battlefield.grid.place_unit(target, Vector2i(1, 0))
	battlefield.caster.cast(other_caster, _elf_spell(1), target.grid_pos)
	assert_true(target.get_active_statuses().is_empty())


func test_venomous_blade_never_mutates_its_data_driven_modifier() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"assassin", VENOMOUS_BLADE_ID)
	var modifier := state.unit.get_progression_spell_modifiers()[0] as SpellModSkillTreeEffect
	var original_duration := modifier.duration
	var original_damage := modifier.amount
	var result := _make_enemy_cast(
		state, _elf_spell(1), Vector2i(1, 1), Vector2i(2, 1)
	)
	result["target"].process_statuses()
	result["target"].tick_statuses()
	assert_eq(modifier.duration, original_duration)
	assert_eq(modifier.amount, original_damage)


func test_abundant_sap_adds_five_healing_and_reports_real_amount() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"healer", ABUNDANT_SAP_ID)
	var battlefield := Factory.make_battlefield(5, 3)
	var ally := Unit.new("Allié", 0)
	ally.current_hp = 50
	battlefield.grid.place_unit(state.unit, Vector2i(0, 1))
	battlefield.grid.place_unit(ally, Vector2i(1, 1))
	var healed_events: Array = []
	var callback := func(unit, amount):
		if unit == ally:
			healed_events.append(amount)
	EventBus.unit_healed.connect(callback)
	var spell := _elf_spell(3)
	var original_heal := spell.heal
	var report: Dictionary = battlefield.caster.cast(state.unit, spell, ally.grid_pos)
	EventBus.unit_healed.disconnect(callback)
	assert_eq(ally.current_hp, 62)
	assert_eq(report["healing_by_unit"].get(ally), 12)
	assert_true(report["healed_units"].has(ally))
	assert_eq(healed_events, [12])
	assert_eq(spell.heal, original_heal)


func test_abundant_sap_clamps_to_max_without_overheal_shield() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"healer", ABUNDANT_SAP_ID)
	var battlefield := Factory.make_battlefield(5, 3)
	var ally := Unit.new("Allié", 0)
	ally.current_hp = 95
	battlefield.grid.place_unit(state.unit, Vector2i(0, 1))
	battlefield.grid.place_unit(ally, Vector2i(1, 1))
	var report: Dictionary = battlefield.caster.cast(
		state.unit, _elf_spell(3), ally.grid_pos
	)
	assert_eq(ally.current_hp, 100)
	assert_eq(ally.current_shield, 0)
	assert_eq(report["healing_by_unit"].get(ally), 5)
	assert_false(report["shielded_units"].has(ally))


func test_abundant_sap_does_not_affect_another_heal_or_damage() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"healer", ABUNDANT_SAP_ID)
	var battlefield := Factory.make_battlefield(5, 3)
	var ally := Unit.new("Allié", 0)
	ally.current_hp = 50
	battlefield.grid.place_unit(state.unit, Vector2i(0, 1))
	battlefield.grid.place_unit(ally, Vector2i(1, 1))
	battlefield.caster.cast(
		state.unit, _make_heal_spell(&"other_heal"), ally.grid_pos
	)
	assert_eq(ally.current_hp, 57)
	assert_eq(ally.current_shield, 0)
	var damage_spell := Factory.make_spell({
		"spell_id": &"other_damage",
		"spell_range": 2,
		"damage": 5,
	})
	var enemy := Unit.new("Ennemi", 1)
	battlefield.grid.place_unit(enemy, Vector2i(2, 1))
	state.unit.current_ap = state.unit.max_ap.get_int()
	battlefield.caster.cast(state.unit, damage_spell, enemy.grid_pos)
	assert_eq(enemy.current_hp, 95)


func test_abundant_sap_does_not_leak_to_another_caster() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"healer", ABUNDANT_SAP_ID)
	var other_caster := Unit.new("Autre soigneur", 0)
	var ally := Unit.new("Allié", 0)
	ally.current_hp = 50
	var battlefield := Factory.make_battlefield(5, 3)
	battlefield.grid.place_unit(other_caster, Vector2i(0, 1))
	battlefield.grid.place_unit(ally, Vector2i(1, 1))
	battlefield.caster.cast(other_caster, _elf_spell(3), ally.grid_pos)
	assert_eq(ally.current_hp, 57)
	assert_eq(ally.current_shield, 0)


func test_protective_bark_applies_shield_after_self_heal() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"healer", PROTECTIVE_BARK_ID)
	var battlefield := Factory.make_battlefield(5, 3)
	state.unit.current_hp = 50
	battlefield.grid.place_unit(state.unit, Vector2i(1, 1))
	var event_order: Array = []
	var heal_callback := func(unit, _amount):
		if unit == state.unit:
			event_order.append("heal")
	var shield_callback := func(unit, amount):
		if unit == state.unit:
			event_order.append("shield:%d" % amount)
	EventBus.unit_healed.connect(heal_callback)
	EventBus.shield_gained.connect(shield_callback)
	var report: Dictionary = battlefield.caster.cast(
		state.unit, _elf_spell(3), state.unit.grid_pos
	)
	EventBus.unit_healed.disconnect(heal_callback)
	EventBus.shield_gained.disconnect(shield_callback)
	assert_eq(state.unit.current_hp, 57)
	assert_eq(state.unit.current_shield, 5)
	assert_eq(event_order, ["heal", "shield:5"])
	assert_true(report["shielded_units"].has(state.unit))


func test_protective_bark_applies_five_to_ally_and_replaces_without_stacking() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"healer", PROTECTIVE_BARK_ID)
	var battlefield := Factory.make_battlefield(5, 3)
	var ally := Unit.new("Allié", 0)
	ally.current_hp = 50
	ally.current_shield = 2
	battlefield.grid.place_unit(state.unit, Vector2i(0, 1))
	battlefield.grid.place_unit(ally, Vector2i(1, 1))
	battlefield.caster.cast(state.unit, _elf_spell(3), ally.grid_pos)
	assert_eq(ally.current_shield, 5)
	state.unit.current_ap = state.unit.max_ap.get_int()
	battlefield.caster.cast(state.unit, _elf_spell(3), ally.grid_pos)
	assert_eq(ally.current_shield, 5, "le bouclier remplace et ne se cumule pas")
	ally.current_shield = 5
	state.unit.current_ap = state.unit.max_ap.get_int()
	battlefield.caster.cast(state.unit, _elf_spell(3), ally.grid_pos)
	assert_eq(ally.current_shield, 5, "un bouclier existant plus fort est conservé")


func test_protective_bark_does_not_affect_other_heal_or_spell_resource() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"healer", PROTECTIVE_BARK_ID)
	var sylvan_heal := _elf_spell(3)
	var original_shield := sylvan_heal.shield_grant
	var battlefield := Factory.make_battlefield(5, 3)
	var ally := Unit.new("Allié", 0)
	ally.current_hp = 50
	battlefield.grid.place_unit(state.unit, Vector2i(0, 1))
	battlefield.grid.place_unit(ally, Vector2i(1, 1))
	battlefield.caster.cast(
		state.unit, _make_heal_spell(&"other_heal"), ally.grid_pos
	)
	assert_eq(ally.current_shield, 0)
	assert_eq(sylvan_heal.shield_grant, original_shield)


func test_protective_bark_does_not_leak_to_another_caster() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"healer", PROTECTIVE_BARK_ID)
	var other_caster := Unit.new("Autre soigneur", 0)
	var ally := Unit.new("Allié", 0)
	ally.current_hp = 50
	var battlefield := Factory.make_battlefield(5, 3)
	battlefield.grid.place_unit(other_caster, Vector2i(0, 1))
	battlefield.grid.place_unit(ally, Vector2i(1, 1))
	battlefield.caster.cast(other_caster, _elf_spell(3), ally.grid_pos)
	assert_eq(ally.current_hp, 57)
	assert_eq(ally.current_shield, 0)


func test_cross_discipline_choices_install_independent_targeted_modifiers() -> void:
	var state := _prepare_elf()
	_raise_and_select(state, &"archer", EAGLE_EYE_ID)
	_raise_and_select(state, &"assassin", VENOMOUS_BLADE_ID)
	_raise_and_select(state, &"healer", PROTECTIVE_BARK_ID)
	_raise_and_select(state, &"mage", INCANDESCENT_ID)
	var modifiers_by_spell := state.get_active_progression_spell_modifiers_by_spell()
	assert_eq(modifiers_by_spell.size(), 4)
	assert_true(modifiers_by_spell.has(&"elf_precise_shot"))
	assert_true(modifiers_by_spell.has(&"elf_sneak_strike"))
	assert_true(modifiers_by_spell.has(&"elf_sylvan_heal"))
	assert_true(modifiers_by_spell.has(&"elf_fireball"))
	assert_true(modifiers_by_spell.values().all(
		func(modifiers): return not modifiers.is_empty()
	))
	state._sync_progression_modifiers_to_unit()
	for spell_id in modifiers_by_spell:
		assert_eq(
			state.unit.get_progression_spell_modifiers_for(spell_id),
			modifiers_by_spell[spell_id],
		)
