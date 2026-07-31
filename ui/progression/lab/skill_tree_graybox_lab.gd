class_name SkillTreeGrayboxLab
extends Control

const ELF_DATA := preload("res://data/units/alliés/elfe.tres")
const MAGE_DATA := preload("res://data/units/alliés/mage.tres")
const GUARDIAN_DATA := preload("res://data/units/alliés/Gardien.tres")

enum Scenario {
	RANK_ONE_ZERO_XP,
	RANK_TWO_AVAILABLE,
	EAGLE_RANK_THREE_AVAILABLE,
	REPEL_BRANCH,
	RANK_FOUR_SELECTED,
	RANK_FIVE_AVAILABLE,
	TREE_COMPLETE,
	LOW_RESOLUTION,
	ELF_ASSASSIN,
	ELF_MAGE,
	ELF_HEALER,
	MAGE_ROOTS,
	GUARDIAN_UNDEFINED,
}

const SCENARIO_NAMES := [
	"1 · Archer rang 1 — nodes verrouillés",
	"2 · Archer rang 2 — choix disponible",
	"3 · Œil d’aigle — acquis, disponible et exclu",
	"4 · Spécialisation Flèche de recul",
	"5 · Archer rang 4 — chemin acquis",
	"6 · Archer rang 5 — capstone disponible",
	"7 · Archer — rang MAX",
	"8 · Responsive — 1280 × 720",
	"9 · Elfe — branche Assassin",
	"10 · Elfe — branche Mage",
	"11 · Elfe — branche Soigneur",
	"12 · Mage — quatre branches réelles",
	"13 · Gardien — progression non définie",
]

@onready var skill_tree_screen: SkillTreeScreen = %SkillTreeScreen
@onready var scenario_label: Label = %ScenarioLabel
@onready var scenario_selector: OptionButton = %ScenarioSelector
@onready var layout_debug_toggle: CheckButton = %LayoutDebugToggle

var preview_state: CharacterRunState = null
var current_scenario: Scenario = Scenario.EAGLE_RANK_THREE_AVAILABLE
var _initial_window_size := Vector2i.ZERO


func _ready() -> void:
	_initial_window_size = get_window().size
	for scenario_name in SCENARIO_NAMES:
		scenario_selector.add_item(scenario_name)
	scenario_selector.item_selected.connect(show_scenario)
	layout_debug_toggle.toggled.connect(_on_layout_debug_toggled)
	layout_debug_toggle.button_pressed = false
	scenario_selector.select(Scenario.EAGLE_RANK_THREE_AVAILABLE)
	show_scenario(Scenario.EAGLE_RANK_THREE_AVAILABLE)


func show_rank_one_preview() -> void:
	show_scenario(Scenario.RANK_ONE_ZERO_XP)


func show_eagle_branch_preview() -> void:
	show_scenario(Scenario.EAGLE_RANK_THREE_AVAILABLE)


func show_assassin_branch_preview() -> void:
	show_scenario(Scenario.ELF_ASSASSIN)


func show_mage_character_preview() -> void:
	show_scenario(Scenario.MAGE_ROOTS)


func show_guardian_undefined_preview() -> void:
	show_scenario(Scenario.GUARDIAN_UNDEFINED)


func show_scenario(scenario_index: int) -> void:
	current_scenario = scenario_index as Scenario
	if current_scenario == Scenario.LOW_RESOLUTION:
		get_window().size = Vector2i(1280, 720)
	elif _initial_window_size != Vector2i.ZERO:
		get_window().size = _initial_window_size
	match current_scenario:
		Scenario.RANK_ONE_ZERO_XP:
			_build_preview_state(ELF_DATA, &"archer", 0, [])
		Scenario.RANK_TWO_AVAILABLE:
			_build_preview_state(ELF_DATA, &"archer", 3, [])
		Scenario.EAGLE_RANK_THREE_AVAILABLE:
			_build_preview_state(ELF_DATA, &"archer", 18, [
				[2, &"elf_archer_eagle_eye"],
			])
		Scenario.REPEL_BRANCH:
			_build_preview_state(ELF_DATA, &"archer", 7, [
				[2, &"elf_archer_repel_arrow"],
			])
		Scenario.RANK_FOUR_SELECTED:
			_build_preview_state(ELF_DATA, &"archer", 12, [
				[2, &"elf_archer_eagle_eye"],
				[3, &"elf_archer_long_range"],
				[4, &"elf_archer_perfect_sight"],
			])
		Scenario.RANK_FIVE_AVAILABLE:
			_build_preview_state(ELF_DATA, &"archer", 18, [
				[2, &"elf_archer_eagle_eye"],
				[3, &"elf_archer_long_range"],
				[4, &"elf_archer_perfect_sight"],
			])
		Scenario.TREE_COMPLETE:
			_build_preview_state(ELF_DATA, &"archer", 18, [
				[2, &"elf_archer_eagle_eye"],
				[3, &"elf_archer_long_range"],
				[4, &"elf_archer_perfect_sight"],
				[5, &"elf_archer_perfect_shot"],
			])
		Scenario.LOW_RESOLUTION:
			_build_preview_state(ELF_DATA, &"archer", 18, [
				[2, &"elf_archer_eagle_eye"],
				[3, &"elf_archer_piercing_shot"],
				[4, &"elf_archer_barbed_tip"],
			])
		Scenario.ELF_ASSASSIN:
			_build_preview_state(ELF_DATA, &"assassin", 3, [])
		Scenario.ELF_MAGE:
			_build_preview_state(ELF_DATA, &"mage", 3, [])
		Scenario.ELF_HEALER:
			_build_preview_state(ELF_DATA, &"healer", 3, [])
		Scenario.MAGE_ROOTS:
			_build_preview_state(MAGE_DATA, &"mage_fire", 0, [])
		Scenario.GUARDIAN_UNDEFINED:
			_build_preview_state(GUARDIAN_DATA, &"", 0, [])
	scenario_label.text = SCENARIO_NAMES[current_scenario]
	scenario_selector.select(current_scenario)


func get_scenario_count() -> int:
	return SCENARIO_NAMES.size()


func is_layout_debug_enabled() -> bool:
	return skill_tree_screen.get_graph().is_layout_debug_enabled()


func _on_layout_debug_toggled(value: bool) -> void:
	skill_tree_screen.get_graph().set_layout_debug_enabled(value)


func _build_preview_state(
		unit_data: UnitData,
		discipline_id: StringName,
		xp: int,
		selections: Array
	) -> void:
	if preview_state != null:
		preview_state.dispose()
	preview_state = CharacterRunState.new()
	if not preview_state.initialize(Unit.from_data(unit_data), unit_data):
		push_error("Impossible de préparer l’état de démonstration.")
		return
	if xp > 0 and discipline_id != &"":
		preview_state.add_discipline_xp(discipline_id, xp)
	for selection in selections:
		var rank := int(selection[0])
		var node_id := StringName(selection[1])
		if not preview_state.select_upgrade(discipline_id, rank, node_id):
			push_error("Scénario invalide : impossible de sélectionner %s." % node_id)
	skill_tree_screen.open_for_state(preview_state, discipline_id)


func _exit_tree() -> void:
	if _initial_window_size != Vector2i.ZERO:
		get_window().size = _initial_window_size
	if preview_state != null:
		preview_state.dispose()
		preview_state = null
