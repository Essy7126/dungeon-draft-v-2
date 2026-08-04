class_name SkillEvolutionPresentationLab
extends Control

const UPGRADE_PAIRS := [
	["eagle_eye", "repel_arrow"],
	["long_range", "perfect_sight"],
	["hindering_arrow", "impact_bolt"],
	["piercing_shot", "barbed_tip"],
	["tactical_retreat", "stabilization"],
	["perfect_shot", "open_breach"],
]

@export var show_debug_controls := true

@onready var overlay: SkillEvolutionOverlay = %SkillEvolutionOverlay
@onready var toolbar: PanelContainer = %Toolbar
@onready var status_label: Label = %StatusLabel

var pair_index := 0
var reduced_motion := false


func _ready() -> void:
	toolbar.visible = show_debug_controls
	overlay.confirmation_requested.connect(_on_confirmation_requested)
	open_overlay()


func open_overlay() -> void:
	var pair: Array = UPGRADE_PAIRS[pair_index]
	var first := _load_upgrade(str(pair[0]))
	var second := _load_upgrade(str(pair[1]))
	var rank := 5 if pair_index == UPGRADE_PAIRS.size() - 1 else 2 + mini(pair_index, 2)
	var request := EvolutionRequest.create(
		&"elf", &"archer", rank, &"elf_archer_base", 1,
		StringName("skill_evolution_lab_%d" % pair_index),
	)
	overlay.present(request, {
		"character_id": &"elf",
		"character_name": "Elfe",
		"discipline_id": &"archer",
		"discipline_name": "Archer",
		"rank": rank,
		"choices": [first, second],
	}, reduced_motion)
	_update_status()


func select_left() -> void:
	var ids := overlay.get_available_upgrade_ids()
	if ids.size() == 2:
		overlay.select_upgrade_by_id(ids[0])


func select_right() -> void:
	var ids := overlay.get_available_upgrade_ids()
	if ids.size() == 2:
		overlay.select_upgrade_by_id(ids[1])


func set_resolution_for_lab(viewport_size: Vector2i) -> void:
	get_window().size = viewport_size
	overlay.apply_viewport_size_for_test(viewport_size)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1:
			set_resolution_for_lab(Vector2i(1280, 720))
		KEY_F2:
			set_resolution_for_lab(Vector2i(1920, 1080))
		KEY_F3:
			set_resolution_for_lab(Vector2i(2560, 1440))
		KEY_Q:
			pair_index = posmod(pair_index - 1, UPGRADE_PAIRS.size())
			open_overlay()
		KEY_E:
			pair_index = posmod(pair_index + 1, UPGRADE_PAIRS.size())
			open_overlay()
		KEY_R:
			reduced_motion = not reduced_motion
			open_overlay()


func _load_upgrade(file_name: String) -> SkillUpgradeData:
	return load(
		"res://data/characters/elf/upgrades/%s.tres" % file_name
	) as SkillUpgradeData


func _on_confirmation_requested(
		_request_id: StringName,
		_upgrade_id: StringName
	) -> void:
	overlay.resolve_confirmation(false, "Validation simulée : la run n’est pas modifiée.")


func _update_status() -> void:
	status_label.text = (
		"F1/F2/F3 résolution · Q/E paire de cartes · R mouvement réduit\n"
		+ "Paire %d/%d · reduced_motion=%s"
	) % [pair_index + 1, UPGRADE_PAIRS.size(), reduced_motion]
