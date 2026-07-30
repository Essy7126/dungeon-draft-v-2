class_name SkillTreeGrayboxLab
extends Control

const ELF_DATA := preload("res://data/units/alliés/elfe.tres")

enum Scenario {
	RANK_ONE_ZERO_XP,
	RANK_TWO_AVAILABLE,
	EAGLE_RANK_THREE_AVAILABLE,
	REPEL_BRANCH,
	RANK_FOUR_SELECTED,
	RANK_FIVE_AVAILABLE,
	TREE_COMPLETE,
	LOW_RESOLUTION,
}

const SCENARIO_NAMES := [
	"1 · Archer rang 1 — 0 XP",
	"2 · Rang 2 disponible",
	"3 · Œil d’aigle — rang 3 disponible",
	"4 · Branche Flèche de recul",
	"5 · Rang 4 sélectionné",
	"6 · Rang 5 disponible",
	"7 · Arbre terminé",
	"8 · Basse résolution — 1280 × 720",
]

@onready var skill_tree_screen: SkillTreeScreen = %SkillTreeScreen
@onready var scenario_label: Label = %ScenarioLabel
@onready var scenario_selector: OptionButton = %ScenarioSelector

var preview_state: CharacterRunState = null
var current_scenario: Scenario = Scenario.EAGLE_RANK_THREE_AVAILABLE
var _initial_window_size := Vector2i.ZERO


func _ready() -> void:
	_initial_window_size = get_window().size
	for scenario_name in SCENARIO_NAMES:
		scenario_selector.add_item(scenario_name)
	scenario_selector.item_selected.connect(show_scenario)
	scenario_selector.select(Scenario.EAGLE_RANK_THREE_AVAILABLE)
	show_scenario(Scenario.EAGLE_RANK_THREE_AVAILABLE)


func show_rank_one_preview() -> void:
	show_scenario(Scenario.RANK_ONE_ZERO_XP)


func show_eagle_branch_preview() -> void:
	show_scenario(Scenario.EAGLE_RANK_THREE_AVAILABLE)


func show_scenario(scenario_index: int) -> void:
	current_scenario = scenario_index as Scenario
	if current_scenario == Scenario.LOW_RESOLUTION:
		get_window().size = Vector2i(1280, 720)
	elif _initial_window_size != Vector2i.ZERO:
		get_window().size = _initial_window_size
	match current_scenario:
		Scenario.RANK_ONE_ZERO_XP:
			_build_preview_state(0, [])
		Scenario.RANK_TWO_AVAILABLE:
			_build_preview_state(3, [])
		Scenario.EAGLE_RANK_THREE_AVAILABLE:
			_build_preview_state(18, [
				[2, &"elf_archer_eagle_eye"],
			])
		Scenario.REPEL_BRANCH:
			_build_preview_state(7, [
				[2, &"elf_archer_repel_arrow"],
			])
		Scenario.RANK_FOUR_SELECTED:
			_build_preview_state(12, [
				[2, &"elf_archer_eagle_eye"],
				[3, &"elf_archer_long_range"],
				[4, &"elf_archer_perfect_sight"],
			])
		Scenario.RANK_FIVE_AVAILABLE:
			_build_preview_state(18, [
				[2, &"elf_archer_eagle_eye"],
				[3, &"elf_archer_long_range"],
				[4, &"elf_archer_perfect_sight"],
			])
		Scenario.TREE_COMPLETE:
			_build_preview_state(18, [
				[2, &"elf_archer_eagle_eye"],
				[3, &"elf_archer_long_range"],
				[4, &"elf_archer_perfect_sight"],
				[5, &"elf_archer_perfect_shot"],
			])
		Scenario.LOW_RESOLUTION:
			_build_preview_state(18, [
				[2, &"elf_archer_eagle_eye"],
				[3, &"elf_archer_piercing_shot"],
				[4, &"elf_archer_barbed_tip"],
			])
	scenario_label.text = SCENARIO_NAMES[current_scenario]
	scenario_selector.select(current_scenario)


func get_scenario_count() -> int:
	return SCENARIO_NAMES.size()


func _build_preview_state(
		xp: int,
		selections: Array
	) -> void:
	if preview_state != null:
		preview_state.dispose()
	var unit := Unit.from_data(ELF_DATA)
	preview_state = CharacterRunState.new()
	if not preview_state.initialize(unit, ELF_DATA):
		push_error("Impossible de préparer l’état de démonstration Archer.")
		return
	if xp > 0:
		preview_state.add_discipline_xp(&"archer", xp)
	for selection in selections:
		var rank := int(selection[0])
		var node_id := StringName(selection[1])
		if not preview_state.select_upgrade(&"archer", rank, node_id):
			push_error(
				"Scénario invalide : impossible de sélectionner %s."
				% node_id
			)
	skill_tree_screen.open_for_state(preview_state, &"archer")


func _exit_tree() -> void:
	if _initial_window_size != Vector2i.ZERO:
		get_window().size = _initial_window_size
	if preview_state != null:
		preview_state.dispose()
		preview_state = null
