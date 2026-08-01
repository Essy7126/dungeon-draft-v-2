class_name SkillTreeGrayboxLab
extends Control

const ELF_DATA := preload("res://data/units/alliés/elfe.tres")
const MAGE_DATA := preload("res://data/units/alliés/mage.tres")
const GUARDIAN_DATA := preload("res://data/units/alliés/Gardien.tres")

enum Scenario {
	RANK_ONE_BRANCH,
	NEXT_RANK_LOCKED,
	FUTURE_RANK_HIDDEN,
	RANK_TWO_BRANCH,
	RANK_FOUR_BRANCH,
	TREE_MAXIMUM,
	NODE_ACQUIRED,
	NODE_AVAILABLE,
	PREREQUISITE_LOCKED,
	NODE_EXCLUDED,
	SPECIALIZATION,
	CAPSTONE,
	GUARDIAN_UNDEFINED,
	MAGE_ROOTS,
	RESOLUTION_720P,
	RESOLUTION_1080P,
	RESOLUTION_1440P,
}

const SCENARIO_NAMES := [
	"1 · Branche Archer · rang 1",
	"2 · Prochain rang visible et verrouillé",
	"3 · Rangs lointains cachés par RankGate",
	"4 · Branche Archer · rang 2",
	"5 · Branche Archer · rang 4",
	"6 · Branche Archer · rang MAX",
	"7 · Node acquis",
	"8 · Node disponible",
	"9 · Node verrouillé par prérequis",
	"10 · Node exclu",
	"11 · Spécialisation",
	"12 · Capstone",
	"13 · Gardien · progression non définie",
	"14 · Mage · racines réelles uniquement",
	"15 · Responsive · 1280 × 720",
	"16 · Responsive · 1920 × 1080",
	"17 · Responsive · 2560 × 1440",
]

@onready var skill_tree_screen: SkillTreeScreen = %SkillTreeScreen
@onready var scenario_label: Label = %ScenarioLabel
@onready var scenario_selector: OptionButton = %ScenarioSelector
@onready var layout_debug_toggle: CheckButton = %LayoutDebugToggle

var preview_state: CharacterRunState = null
var current_scenario: Scenario = Scenario.NODE_AVAILABLE
var _initial_window_size := Vector2i.ZERO


func _ready() -> void:
	_initial_window_size = get_window().size
	for scenario_name in SCENARIO_NAMES:
		scenario_selector.add_item(scenario_name)
	scenario_selector.item_selected.connect(show_scenario)
	layout_debug_toggle.toggled.connect(_on_layout_debug_toggled)
	layout_debug_toggle.button_pressed = false
	scenario_selector.select(Scenario.NODE_AVAILABLE)
	show_scenario(Scenario.NODE_AVAILABLE)


func show_rank_one_preview() -> void:
	show_scenario(Scenario.RANK_ONE_BRANCH)


func show_eagle_branch_preview() -> void:
	show_scenario(Scenario.NODE_AVAILABLE)


func show_assassin_branch_preview() -> void:
	show_scenario(Scenario.SPECIALIZATION)


func show_mage_character_preview() -> void:
	show_scenario(Scenario.MAGE_ROOTS)


func show_guardian_undefined_preview() -> void:
	show_scenario(Scenario.GUARDIAN_UNDEFINED)


func show_scenario(scenario_index: int) -> void:
	current_scenario = scenario_index as Scenario
	if current_scenario == Scenario.RESOLUTION_720P:
		get_window().size = Vector2i(1280, 720)
	elif current_scenario == Scenario.RESOLUTION_1080P:
		get_window().size = Vector2i(1920, 1080)
	elif current_scenario == Scenario.RESOLUTION_1440P:
		get_window().size = Vector2i(2560, 1440)
	elif _initial_window_size != Vector2i.ZERO:
		get_window().size = _initial_window_size
	match current_scenario:
		Scenario.RANK_ONE_BRANCH, Scenario.NEXT_RANK_LOCKED, Scenario.FUTURE_RANK_HIDDEN:
			_build_preview_state(ELF_DATA, &"archer", 0, [])
		Scenario.RANK_TWO_BRANCH:
			_build_preview_state(ELF_DATA, &"archer", 3, [])
		Scenario.RANK_FOUR_BRANCH:
			_build_preview_state(ELF_DATA, &"archer", 12, [
				[2, &"elf_archer_eagle_eye"],
				[3, &"elf_archer_long_range"],
				[4, &"elf_archer_perfect_sight"],
			])
		Scenario.TREE_MAXIMUM:
			_build_preview_state(ELF_DATA, &"archer", 18, [
				[2, &"elf_archer_eagle_eye"],
				[3, &"elf_archer_long_range"],
				[4, &"elf_archer_perfect_sight"],
				[5, &"elf_archer_perfect_shot"],
			])
		Scenario.NODE_ACQUIRED, Scenario.NODE_AVAILABLE:
			_build_preview_state(ELF_DATA, &"archer", 7, [
				[2, &"elf_archer_eagle_eye"],
			])
		Scenario.PREREQUISITE_LOCKED:
			_build_preview_state(ELF_DATA, &"archer", 18, [
				[2, &"elf_archer_eagle_eye"],
			])
		Scenario.NODE_EXCLUDED:
			_build_preview_state(ELF_DATA, &"archer", 18, [
				[2, &"elf_archer_eagle_eye"],
				[3, &"elf_archer_long_range"],
			])
		Scenario.SPECIALIZATION:
			_build_preview_state(ELF_DATA, &"archer", 3, [])
		Scenario.CAPSTONE:
			_build_preview_state(ELF_DATA, &"archer", 18, [
				[2, &"elf_archer_eagle_eye"],
				[3, &"elf_archer_long_range"],
				[4, &"elf_archer_perfect_sight"],
			])
		Scenario.GUARDIAN_UNDEFINED:
			_build_preview_state(GUARDIAN_DATA, &"", 0, [])
		Scenario.MAGE_ROOTS:
			_build_preview_state(MAGE_DATA, &"mage_fire", 0, [])
		Scenario.RESOLUTION_720P, Scenario.RESOLUTION_1080P, Scenario.RESOLUTION_1440P:
			_build_preview_state(ELF_DATA, &"archer", 12, [
				[2, &"elf_archer_eagle_eye"],
				[3, &"elf_archer_long_range"],
				[4, &"elf_archer_perfect_sight"],
			])
	_select_scenario_focus()
	scenario_label.text = SCENARIO_NAMES[current_scenario]
	scenario_selector.select(current_scenario)


func _select_scenario_focus() -> void:
	var node_id := &""
	match current_scenario:
		Scenario.NEXT_RANK_LOCKED, Scenario.SPECIALIZATION:
			node_id = &"elf_archer_eagle_eye"
		Scenario.NODE_ACQUIRED:
			node_id = &"elf_archer_eagle_eye"
		Scenario.NODE_AVAILABLE:
			node_id = &"elf_archer_long_range"
		Scenario.PREREQUISITE_LOCKED, Scenario.NODE_EXCLUDED:
			node_id = &"elf_archer_barbed_tip"
		Scenario.CAPSTONE, Scenario.TREE_MAXIMUM:
			node_id = &"elf_archer_perfect_shot"
	if node_id != &"":
		skill_tree_screen.get_graph().inspect_node_by_id(node_id)


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
