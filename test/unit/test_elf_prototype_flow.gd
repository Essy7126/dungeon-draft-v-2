extends GutTest

const GameManagerScript = preload("res://core/game_manager.gd")
const ActionBarScript = preload("res://ui/action_bar.gd")
const Factory = preload("res://test/support/factory.gd")

const ELF_RUN_PATH := "res://data/runs/elf_prototype_run.tres"
const ELF_PATH := "res://data/units/alliés/elfe.tres"
const RAGE_PATH := "res://data/energy/rage.tres"
const DRAFT_TRAIT_PATH := "res://data/traits/depart_posture_defensive.tres"
const FIRST_REWARD_PATH := "res://data/rewards/reward_marteau_jugement.tres"
const EXPECTED_ROOMS := [
	"res://data/rooms/bible/le_gue.tres",
	"res://data/rooms/bible/la_forge.tres",
	"res://data/rooms/bible/elite_brute.tres",
]

var manager


func before_each() -> void:
	manager = GameManagerScript.new()


func after_each() -> void:
	if manager != null and is_instance_valid(manager):
		manager._clear_heroes()
		manager.free()


func test_elf_run_is_exactly_three_rooms_with_all_progression_pools_empty() -> void:
	var run := load(ELF_RUN_PATH) as RunData
	assert_not_null(run)
	assert_eq(run.run_name, "Prototype Elfe")
	assert_eq(run.rooms.map(func(room): return room.resource_path), EXPECTED_ROOMS)
	assert_true(run.reward_pool.is_empty())
	assert_true(run.relic_pool.is_empty())
	assert_true(run.equipment_pool.is_empty())
	assert_true(run.event_pool.is_empty())
	assert_true(run.boss_malus_pool.is_empty())
	assert_true(run.run_nodes.is_empty())


func test_title_screen_exposes_solo_validation_and_historical_entries_explicitly() -> void:
	var title = load("res://ui/TitreEcran.tscn").instantiate()
	assert_eq(title.get_node("UI/Boutons/BoutonPrototypeElfe").text, "Prototype Elfe")
	assert_eq(
		title.get_node("UI/Boutons/BoutonValidationEquipe").text,
		"Validation technique — équipe de 3",
	)
	assert_eq(
		title.get_node("UI/Boutons/BoutonNouvellePartie").text,
		"Ancien prototype / Draft historique",
	)
	title.free()


func test_preconfigured_elf_has_one_hero_without_energy_or_draft_trait() -> void:
	var run := load(ELF_RUN_PATH) as RunData
	assert_true(manager._prepare_preconfigured_run(run, [ELF_PATH]))
	assert_eq(manager.heroes.size(), 1)
	var elf: Unit = manager.heroes[0]
	assert_eq(elf.unit_name, "Elfe")
	assert_false(elf.has_energy())
	assert_true(elf.traits.is_empty())
	assert_eq(elf.visual_scene.resource_path, "res://characters/elf/ElfIsoUnitView.tscn")
	assert_eq(manager.current_room_index, -1)
	assert_true(manager.run_active)


func test_preconfigured_builder_preserves_energy_owned_by_unit_data() -> void:
	var data := UnitData.new()
	data.unit_id = &"configured_energy_hero"
	data.unit_name = "Héros configuré"
	data.energy_type = Factory.make_energy({}, {"start_energy": 12.0})
	var run := RunData.new()
	run.rooms.append(RoomData.new())

	assert_true(manager._prepare_preconfigured_run(run, [data]))
	var hero: Unit = manager.heroes[0]
	assert_same(hero.energy_type, data.energy_type)
	assert_almost_eq(hero.current_energy, 12.0, 0.0001)
	assert_true(hero.traits.is_empty(), "aucun trait de draft ne doit être injecté")


func test_run_state_duplicates_room_and_reward_arrays() -> void:
	var source_run := RunData.new()
	var room := RoomData.new()
	var reward := RewardData.new()
	source_run.run_name = "Copie isolée"
	source_run.rooms.append(room)
	source_run.reward_pool.append(reward)
	var hero_data := UnitData.new()
	hero_data.unit_id = &"run_copy_hero"

	assert_true(manager._prepare_preconfigured_run(source_run, [hero_data]))
	source_run.rooms.clear()
	source_run.reward_pool.clear()

	assert_eq(manager.rooms, [room])
	assert_eq(manager.reward_pool, [reward])
	assert_eq(manager.current_room_index, -1)
	assert_true(manager.run_active)


func test_historical_draft_still_overrides_energy_and_adds_selected_trait() -> void:
	manager._build_heroes_from_draft([ELF_PATH], [RAGE_PATH], [DRAFT_TRAIT_PATH])
	assert_eq(manager.heroes.size(), 1)
	var hero: Unit = manager.heroes[0]
	assert_eq(hero.energy_type.resource_path, RAGE_PATH)
	assert_almost_eq(hero.current_energy, 12.0, 0.0001)
	assert_true(
		hero.traits.any(func(active_trait): return active_trait.display_name == "Posture Defensive"),
		"le trait choisi dans le draft historique doit rester appliqué",
	)


func test_empty_reward_pool_skips_even_the_first_forced_reward() -> void:
	manager.current_room_index = 0
	manager.reward_pool = []
	assert_true(manager._build_reward_offer().is_empty())


func test_filled_historical_pool_keeps_the_first_forced_reward() -> void:
	manager.current_room_index = 0
	manager.reward_pool = [RewardData.new()]
	var offer: Array = manager._build_reward_offer()
	assert_gt(offer.size(), 0)
	assert_eq(offer[0].resource_path, FIRST_REWARD_PATH)


func test_result_state_keeps_outcome_and_run_name() -> void:
	var run := RunData.new()
	run.run_name = "Run terminal"
	var hero_data := UnitData.new()
	hero_data.unit_id = &"terminal_result_hero"
	assert_true(manager._prepare_preconfigured_run(run, [hero_data]))
	manager._record_run_result(false)
	assert_eq(manager.get_last_run_result(), {
		"victory": false,
		"run_name": "Run terminal",
	})


func test_no_energy_unit_hides_the_whole_energy_hud_group() -> void:
	var bar = ActionBarScript.new()
	add_child_autofree(bar)
	bar.update_info(Factory.make_unit())

	assert_true(bar.get("_ap_label").visible)
	for property in [
		"_fervor_label",
		"_fervor_bar",
		"_awakening_btn",
		"_reaction_btn",
		"_energy_separator_before",
		"_energy_separator_after",
	]:
		assert_false(bar.get(property).visible, "%s doit être masqué" % property)


func test_energy_unit_restores_the_whole_energy_hud_group() -> void:
	var bar = ActionBarScript.new()
	add_child_autofree(bar)
	var unit := Factory.make_unit()
	unit.energy_type = Factory.make_energy()
	bar.update_info(unit)

	for property in [
		"_fervor_label",
		"_fervor_bar",
		"_awakening_btn",
		"_reaction_btn",
		"_energy_separator_before",
		"_energy_separator_after",
	]:
		assert_true(bar.get(property).visible, "%s doit être visible" % property)


func test_imprint_button_exists_only_for_units_with_energy() -> void:
	var bar = ActionBarScript.new()
	add_child_autofree(bar)
	var unit := Factory.make_unit()
	unit.spells = [Factory.make_spell({"imprint_fervor_cost": 10.0})]

	bar.build_spell_buttons(unit)
	assert_eq(bar.get("_spell_buttons").size(), 1)

	unit.energy_type = Factory.make_energy()
	bar.build_spell_buttons(unit)
	assert_eq(bar.get("_spell_buttons").size(), 2)


func test_result_screen_displays_both_outcomes_and_run_name() -> void:
	var screen = load("res://ui/RunResultScreen.tscn").instantiate()
	add_child_autofree(screen)
	screen.call("_apply_result", {"victory": true, "run_name": "Prototype Elfe"})
	assert_eq(screen.get_node("Background/Center/Panel/Content/Result").text, "Victoire")
	assert_eq(screen.get_node("Background/Center/Panel/Content/RunName").text, "Run : Prototype Elfe")
	screen.call("_apply_result", {"victory": false, "run_name": "Prototype Elfe"})
	assert_eq(screen.get_node("Background/Center/Panel/Content/Result").text, "Défaite")
