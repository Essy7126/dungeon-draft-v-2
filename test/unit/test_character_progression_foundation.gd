extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")
const ActionBarScript = preload("res://ui/action_bar.gd")

const ELF_PATH := "res://data/units/alliés/elfe.tres"
const LEGACY_FIREBALL_PATH := "res://data/spells/Mage/boule_de_feu.tres"
const LEGACY_MAGE_PATH := "res://data/units/alliés/mage.tres"
const WARRIOR_PATH := "res://data/units/alliés/Guerrier.tres"
const ELF_SPELL_IDS := [
	&"elf_precise_shot",
	&"elf_sneak_strike",
	&"elf_fireball",
	&"elf_sylvan_heal",
]
const ELF_DISCIPLINE_IDS := [&"archer", &"assassin", &"mage", &"healer"]

var manager


func before_each() -> void:
	manager = GameManagerScript.new()


func after_each() -> void:
	if manager != null and is_instance_valid(manager):
		manager._clear_heroes()
		manager.free()


func _make_spell(spell_id: StringName, display_name: String = "Sort") -> Spell:
	var current_spell := Spell.new()
	current_spell.spell_id = spell_id
	current_spell.spell_name = display_name
	return current_spell


func _make_unit_data(
		character_id: StringName,
		starting_spells: Array[Spell],
		starting_disciplines: Array[DisciplineData] = []
	) -> UnitData:
	var data := UnitData.new()
	data.unit_id = character_id
	data.unit_name = "Nom affiché partagé"
	data.spells = starting_spells
	data.disciplines = starting_disciplines
	return data


func test_explicit_unit_id_is_used_by_unit_data_and_runtime_unit() -> void:
	var data := _make_unit_data(&"hero_alpha", [])
	assert_eq(data.get_effective_unit_id(), &"hero_alpha")
	assert_eq(Unit.from_data(data).unit_id, &"hero_alpha")


func test_explicit_spell_ids_do_not_depend_on_identical_display_names() -> void:
	var first := _make_spell(&"first_stable_id", "Même nom")
	var second := _make_spell(&"second_stable_id", "Même nom")
	assert_eq(first.get_effective_spell_id(), &"first_stable_id")
	assert_eq(second.get_effective_spell_id(), &"second_stable_id")
	assert_ne(first.get_effective_spell_id(), second.get_effective_spell_id())


func test_loadout_initializes_four_known_and_equipped_spells_in_order() -> void:
	var spells: Array[Spell] = [
		_make_spell(&"one"),
		_make_spell(&"two"),
		_make_spell(&"three"),
		_make_spell(&"four"),
	]
	var loadout := SpellLoadoutState.new()
	loadout.initialize(spells)
	assert_eq(loadout.get_active_slot_count(), 4)
	assert_eq(loadout.get_known_spells(), spells)
	assert_eq(loadout.get_equipped_spells(), spells)


func test_loadout_refuses_duplicate_ids_and_can_learn_a_new_spell() -> void:
	var loadout := SpellLoadoutState.new()
	loadout.initialize([_make_spell(&"known")])
	assert_false(loadout.learn_spell(_make_spell(&"known", "Autre affichage")))
	assert_true(loadout.learn_spell(_make_spell(&"new_spell")))
	assert_true(loadout.knows_spell_id(&"new_spell"))
	assert_eq(loadout.get_known_spells().size(), 2)


func test_loadout_refuses_unknown_duplicate_and_invalid_equipment() -> void:
	var loadout := SpellLoadoutState.new()
	loadout.initialize([_make_spell(&"one"), _make_spell(&"two")])
	assert_false(loadout.equip_spell(&"unknown", 0))
	assert_false(loadout.equip_spell(&"one", 1), "un même sort ne peut occuper deux slots")
	assert_false(loadout.equip_spell(&"one", -1))
	assert_false(loadout.equip_spell(&"one", 4))


func test_loadout_replaces_and_unequips_slots_in_order() -> void:
	var first := _make_spell(&"one")
	var second := _make_spell(&"two")
	var replacement := _make_spell(&"replacement")
	var loadout := SpellLoadoutState.new()
	loadout.initialize([first, second])
	assert_true(loadout.learn_spell(replacement))
	assert_true(loadout.equip_spell(&"replacement", 0))
	assert_eq(loadout.get_equipped_spells(), [replacement, second])
	loadout.unequip_slot(1)
	assert_eq(loadout.get_equipped_spells(), [replacement])
	loadout.unequip_slot(99)
	assert_eq(loadout.get_equipped_spells(), [replacement])


func test_loadout_returns_defensive_array_copies() -> void:
	var loadout := SpellLoadoutState.new()
	loadout.initialize([_make_spell(&"one"), _make_spell(&"two")])
	var known_copy := loadout.get_known_spells()
	var equipped_copy := loadout.get_equipped_spells()
	known_copy.clear()
	equipped_copy.clear()
	assert_eq(loadout.get_known_spells().size(), 2)
	assert_eq(loadout.get_equipped_spells().size(), 2)


func test_two_loadouts_keep_independent_known_and_equipped_state() -> void:
	var shared_start := [_make_spell(&"one"), _make_spell(&"two")]
	var first := SpellLoadoutState.new()
	var second := SpellLoadoutState.new()
	first.initialize(shared_start)
	second.initialize(shared_start)
	var learned := _make_spell(&"only_first")
	assert_true(first.learn_spell(learned))
	assert_true(first.equip_spell(&"only_first", 0))
	assert_true(first.knows_spell_id(&"only_first"))
	assert_false(second.knows_spell_id(&"only_first"))
	assert_ne(first.get_equipped_spells(), second.get_equipped_spells())


func test_character_state_owns_id_disciplines_loadout_and_syncs_unit_spells() -> void:
	var discipline := DisciplineData.new()
	discipline.discipline_id = &"open_discipline"
	var first := _make_spell(&"one")
	first.skill_tree = discipline
	var replacement := _make_spell(&"replacement")
	var data := _make_unit_data(&"hero_state", [first])
	var unit := Unit.from_data(data)
	var state := CharacterRunState.new()

	assert_true(state.initialize(unit, data))
	assert_eq(state.character_id, &"hero_state")
	assert_eq(state.get_disciplines(), [discipline])
	assert_eq(state.loadout.get_known_spells(), [first])
	assert_eq(unit.spells, [first])

	assert_true(state.loadout.learn_spell(replacement))
	assert_true(state.loadout.equip_spell(&"replacement", 0))
	assert_eq(unit.spells, [replacement], "le signal changed synchronise sans divergence silencieuse")


func test_two_character_states_never_share_their_loadout() -> void:
	var first_data := _make_unit_data(&"hero_one", [_make_spell(&"one")])
	var second_data := _make_unit_data(&"hero_two", [_make_spell(&"two")])
	var first := CharacterRunState.new()
	var second := CharacterRunState.new()
	assert_true(first.initialize(Unit.from_data(first_data), first_data))
	assert_true(second.initialize(Unit.from_data(second_data), second_data))
	assert_not_same(first.loadout, second.loadout)
	assert_true(first.loadout.learn_spell(_make_spell(&"first_only")))
	assert_false(second.loadout.knows_spell_id(&"first_only"))


func test_game_manager_keeps_three_preconfigured_character_states_independent() -> void:
	var run := RunData.new()
	run.rooms.append(RoomData.new())
	var first_data := _make_unit_data(&"hero_one", [_make_spell(&"spell_one")])
	var second_data := _make_unit_data(&"hero_two", [_make_spell(&"spell_two")])
	var third_data := _make_unit_data(&"hero_three", [_make_spell(&"spell_three")])

	assert_true(manager._prepare_preconfigured_run(run, [first_data, second_data, third_data]))
	assert_eq(manager.heroes.size(), 3)
	assert_eq(manager.character_states.size(), 3)
	var first: CharacterRunState = manager.get_character_state(&"hero_one")
	var second: CharacterRunState = manager.get_character_state(&"hero_two")
	var third: CharacterRunState = manager.get_character_state(&"hero_three")
	assert_not_same(first.loadout, second.loadout)
	assert_not_same(second.loadout, third.loadout)
	assert_true(first.loadout.learn_spell(_make_spell(&"first_only")))
	assert_false(second.loadout.knows_spell_id(&"first_only"))
	assert_false(third.loadout.knows_spell_id(&"first_only"))


func test_new_preconfigured_run_clears_previous_character_states() -> void:
	var run := RunData.new()
	run.rooms.append(RoomData.new())
	assert_true(manager._prepare_preconfigured_run(
		run,
		[_make_unit_data(&"old_hero", [_make_spell(&"old_spell")])],
	))
	assert_not_null(manager.get_character_state(&"old_hero"))
	assert_true(manager._prepare_preconfigured_run(
		run,
		[_make_unit_data(&"new_hero", [_make_spell(&"new_spell")])],
	))
	assert_null(manager.get_character_state(&"old_hero"))
	assert_not_null(manager.get_character_state(&"new_hero"))
	assert_eq(manager.character_states.size(), 1)


func test_elf_resource_defines_exactly_four_disciplines_and_four_ordered_spells() -> void:
	var data := load(ELF_PATH) as UnitData
	assert_not_null(data)
	assert_eq(data.get_effective_unit_id(), &"elf")
	assert_eq(
		data.disciplines.map(func(item): return item.discipline_id),
		ELF_DISCIPLINE_IDS,
	)
	assert_eq(
		data.spells.map(func(current_spell): return current_spell.get_effective_spell_id()),
		ELF_SPELL_IDS,
	)
	assert_eq(
		data.spells.map(func(current_spell): return current_spell.skill_tree.discipline_id),
		ELF_DISCIPLINE_IDS,
	)
	assert_eq(
		data.spells.map(func(current_spell): return current_spell.spell_name),
		["Tir précis", "Frappe sournoise", "Boule de feu", "Soin sylvestre"],
	)


func test_elf_spell_values_match_the_foundation_contract() -> void:
	var spells: Array[Spell] = (load(ELF_PATH) as UnitData).spells
	assert_eq([spells[0].ap_cost, spells[0].spell_range, spells[0].damage], [2, 7, 7])
	assert_eq(spells[0].damage_type, Spell.DamageType.PHYSICAL)
	assert_eq([spells[1].ap_cost, spells[1].spell_range, spells[1].damage], [2, 1, 7])
	assert_eq(spells[1].damage_type, Spell.DamageType.PHYSICAL)
	assert_eq(spells[2].vfx_scene.resource_path, "res://battle/vfx/boule_de_feu_vfx2.tscn")
	assert_eq([spells[3].ap_cost, spells[3].spell_range, spells[3].heal], [2, 5, 7])
	assert_false(spells[3].can_target_enemy)
	assert_true(spells[3].can_target_ally)
	assert_true(spells[3].can_target_self)


func test_preconfigured_elf_has_an_individual_four_slot_state_without_legacy_build() -> void:
	var run := RunData.new()
	run.rooms.append(RoomData.new())
	assert_true(manager._prepare_preconfigured_run(run, [ELF_PATH]))
	assert_eq(manager.heroes.size(), 1)
	var elf: Unit = manager.heroes[0]
	var state: CharacterRunState = manager.get_character_state(&"elf")
	assert_not_null(state)
	assert_same(state.unit, elf)
	assert_eq(state.loadout.get_known_spells().size(), 4)
	assert_eq(state.loadout.get_equipped_spells(), elf.spells)
	assert_eq(elf.spells.size(), 4)


func test_action_bar_receives_four_ordered_elf_spells_without_overflow() -> void:
	var elf := Unit.from_data(load(ELF_PATH) as UnitData)
	var bar = ActionBarScript.new()
	add_child_autofree(bar)
	bar.update_info(elf)
	bar.build_spell_buttons(elf)
	var buttons: Array = bar.get("_spell_buttons")
	assert_eq(buttons.size(), 4)
	assert_eq(
		buttons.map(func(button): return button.get_meta("spell").get_effective_spell_id()),
		ELF_SPELL_IDS,
	)


func test_elf_fireball_remains_distinct_from_the_elemental_mage_fireball() -> void:
	var elf_data := load(ELF_PATH) as UnitData
	var legacy_fireball := load(LEGACY_FIREBALL_PATH) as Spell
	var legacy_mage := load(LEGACY_MAGE_PATH) as UnitData
	var elf_fireball: Spell = elf_data.spells[2]
	assert_ne(elf_fireball.resource_path, legacy_fireball.resource_path)
	assert_eq(elf_fireball.get_effective_spell_id(), &"elf_fireball")
	assert_eq(legacy_fireball.spell_id, &"mage_fireball")
	assert_eq(legacy_fireball.get_skill_tree_id(), &"mage_pyromancy")
	assert_true(legacy_fireball in legacy_mage.spells)
