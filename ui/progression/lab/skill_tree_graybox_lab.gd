class_name SkillTreeGrayboxLab
extends Control

const ELF_DATA := preload("res://data/units/alliés/elfe.tres")

@onready var skill_tree_screen: SkillTreeScreen = %SkillTreeScreen
@onready var scenario_label: Label = %ScenarioLabel
@onready var rank_one_button: Button = %RankOneButton
@onready var eagle_branch_button: Button = %EagleBranchButton

var preview_state: CharacterRunState = null


func _ready() -> void:
	rank_one_button.pressed.connect(show_rank_one_preview)
	eagle_branch_button.pressed.connect(show_eagle_branch_preview)
	show_eagle_branch_preview()


func show_rank_one_preview() -> void:
	_build_preview_state(0, false)
	scenario_label.text = "Scénario : Archer — rang 1 — 0 XP"


func show_eagle_branch_preview() -> void:
	_build_preview_state(18, true)
	scenario_label.text = (
		"Scénario : Œil d’aigle — rang 3 disponible — rang 5 futur"
	)


func _build_preview_state(xp: int, select_eagle_branch: bool) -> void:
	if preview_state != null:
		preview_state.dispose()
	var unit := Unit.from_data(ELF_DATA)
	preview_state = CharacterRunState.new()
	if not preview_state.initialize(unit, ELF_DATA):
		push_error("Impossible de préparer l’état de démonstration Archer.")
		return
	if xp > 0:
		preview_state.add_discipline_xp(&"archer", xp)
	if select_eagle_branch:
		preview_state.select_upgrade(
			&"archer",
			2,
			&"elf_archer_eagle_eye"
		)
	skill_tree_screen.open_for_state(preview_state, &"archer")


func _exit_tree() -> void:
	if preview_state != null:
		preview_state.dispose()
		preview_state = null
