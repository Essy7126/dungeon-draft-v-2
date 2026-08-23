extends GutTest

const Factory = preload("res://test/support/factory.gd")
const GameManagerScript = preload("res://core/game_manager.gd")
const ActionBarScript = preload("res://ui/action_bar.gd")

const ELF_PATH := "res://data/units/alliés/elfe.tres"
const MAGE_PATH := "res://data/units/alliés/mage.tres"
const WARRIOR_PATH := "res://data/units/alliés/Guerrier.tres"
const PARTY := [ELF_PATH, MAGE_PATH, WARRIOR_PATH]
const DISCIPLINE_IDS := [
	&"mage_pyromancy",
	&"mage_cryomancy",
	&"mage_fulguromancy",
	&"mage_geomancy",
]
const DISCIPLINE_NAMES := [
	"Pyromancie",
	"Cryomancie",
	"Foudromancie",
	"Géomancie",
]
const SPELL_IDS := [
	&"mage_fireball",
	&"mage_ice_wall",
	&"mage_thunderstorm",
	&"mage_seismic_wave",
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


func _run(room_count: int = 2) -> RunData:
	var run := RunData.new()
	for _index in range(room_count):
		run.rooms.append(RoomData.new())
	return run


func _prepare_party(room_count: int = 2) -> Array[CharacterRunState]:
	assert_true(manager._prepare_preconfigured_run(_run(room_count), PARTY))
	return manager.get_ordered_character_states()


func test_mage_has_four_ordered_complete_disciplines() -> void:
	var data := load(MAGE_PATH) as UnitData
	assert_eq(
		data.disciplines.map(func(discipline): return discipline.discipline_id),
		DISCIPLINE_IDS,
	)
	assert_eq(
		data.disciplines.map(func(discipline): return discipline.display_name),
		DISCIPLINE_NAMES,
	)
	var colors := data.disciplines.map(
		func(discipline): return discipline.presentation_color
	)
	assert_eq(colors.duplicate().reduce(
		func(unique, color):
			if not unique.has(color):
				unique.append(color)
			return unique,
		[]
	).size(), 4)
	for discipline in data.disciplines:
		assert_eq(discipline.ranks.size(), 5, str(discipline.discipline_id))
		assert_eq(discipline.ranks[0].rank, 1)
		assert_eq(discipline.ranks[0].required_total_xp, 0)
		assert_true(discipline.ranks[0].choices.is_empty())
		var progress := DisciplineProgressState.new()
		assert_true(progress.initialize(discipline))
		assert_eq(progress.add_xp(30), [2, 3, 4, 5])
		assert_eq(progress.rank, 5)
		assert_eq(progress.get_pending_rank_choices(), [2, 3, 4, 5])


func test_mage_loadout_has_exactly_four_known_and_equipped_spells_in_order() -> void:
	var states := _prepare_party()
	var mage := states[1]
	assert_eq(
		mage.loadout.get_known_spells().map(
			func(spell): return spell.get_effective_spell_id()
		),
		SPELL_IDS,
	)
	assert_eq(
		mage.loadout.get_equipped_spells().map(
			func(spell): return spell.get_effective_spell_id()
		),
		SPELL_IDS,
	)
	assert_eq(
		mage.loadout.get_equipped_spells().map(
			func(spell): return spell.get_skill_tree_id()
		),
		DISCIPLINE_IDS,
	)
	assert_false(mage.unit.basic_attack_enabled)


func test_action_bar_shows_four_ordered_spells_and_no_basic_attack() -> void:
	var mage := Unit.from_data(load(MAGE_PATH) as UnitData)
	var bar = ActionBarScript.new()
	add_child_autofree(bar)
	bar.update_info(mage)
	bar.build_spell_buttons(mage)
	assert_false(bar.get("_attack_btn").visible)
	assert_eq(
		bar.get("_spell_buttons").map(
			func(button): return button.get_meta("spell").get_effective_spell_id()
		),
		SPELL_IDS,
	)


func test_each_successful_spell_grants_exactly_one_xp_to_its_discipline() -> void:
	var states := _prepare_party()
	var mage := states[1]
	var targets := [
		Vector2i(3, 2),
		Vector2i(4, 2),
		Vector2i(5, 2),
		Vector2i(2, 2),
	]
	for spell_index in range(4):
		var battlefield := Factory.make_battlefield(12, 5)
		battlefield.grid.place_unit(mage.unit, Vector2i(0, 2))
		battlefield.grid.place_unit(
			Unit.new("Cible %d" % spell_index, 1, 1000),
			targets[spell_index],
		)
		mage.unit.current_ap = mage.unit.max_ap.get_value()
		var report: Dictionary = battlefield.caster.cast(
			mage.unit,
			mage.unit.spells[spell_index],
			targets[spell_index],
		)
		assert_false(report.get("failed", false), str(SPELL_IDS[spell_index]))
	for discipline_index in range(4):
		assert_eq(
			mage.get_discipline_progress(DISCIPLINE_IDS[discipline_index]).xp,
			1,
		)
	assert_eq(states[0].get_discipline_progress(&"mage").xp, 0)
	assert_true(states[2].get_discipline_progressions().values().all(
		func(progress): return progress.xp == 0
	))


func test_thunderstorm_aoe_hits_three_targets_but_grants_only_one_xp() -> void:
	var states := _prepare_party()
	var mage := states[1]
	var battlefield := Factory.make_battlefield(8, 5)
	battlefield.grid.place_unit(mage.unit, Vector2i(0, 2))
	var targets: Array[Unit] = []
	for cell in [Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3)]:
		var target := Factory.make_unit("Cible", 1)
		battlefield.grid.place_unit(target, cell)
		targets.append(target)
	var report := battlefield.caster.cast(
		mage.unit,
		mage.unit.spells[2],
		Vector2i(3, 2),
	)
	assert_eq(report["damaged_enemies"].size(), 3)
	assert_true(targets.all(func(target): return target.current_hp == 93))
	assert_eq(mage.get_discipline_progress(&"mage_fulguromancy").xp, 1)
	assert_eq(states[0].get_discipline_progress(&"mage").xp, 0)
	assert_true(states[2].get_discipline_progressions().values().all(
		func(progress): return progress.xp == 0
	))


func test_mage_xp_persists_between_rooms_and_resets_on_new_run() -> void:
	var states := _prepare_party(3)
	var mage := states[1]
	mage.add_discipline_xp(&"mage_fulguromancy", 2)
	manager.current_room_index = 0
	manager._go_to_next_room()
	assert_same(manager.get_character_state(&"mage"), mage)
	assert_eq(mage.get_discipline_progress(&"mage_fulguromancy").xp, 2)
	assert_true(manager._prepare_preconfigured_run(_run(3), PARTY))
	var fresh: CharacterRunState = manager.get_character_state(&"mage")
	assert_not_same(fresh, mage)
	for discipline_id in DISCIPLINE_IDS:
		assert_eq(fresh.get_discipline_progress(discipline_id).xp, 0)
		assert_true(
			fresh.get_discipline_progress(discipline_id)
			.get_pending_rank_choices()
			.is_empty()
		)


func test_accumulated_mage_xp_creates_the_four_complete_pending_choices() -> void:
	var mage := _prepare_party()[1]
	for discipline_id in DISCIPLINE_IDS:
		var result := mage.add_discipline_xp(discipline_id, 50)
		assert_eq(result["rank"], 5)
		assert_eq(result["next_required_total_xp"], -1)
	assert_eq(mage.get_pending_progression_choices().size(), 16)
