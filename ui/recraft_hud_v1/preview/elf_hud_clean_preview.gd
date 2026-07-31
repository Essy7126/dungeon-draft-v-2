extends Control

const ELF_DATA := preload("res://data/units/alliés/elfe.tres")

enum PreviewSelection {
	NONE,
	MOVE,
	SPELL,
}

@export_category("REFINED — états")
@export var preview_selection := PreviewSelection.SPELL
@export_range(0, 3, 1) var selected_spell_index := 0
@export_range(0, 3, 1) var unavailable_spell_index := 1
@export_range(0, 3, 1) var cooldown_spell_index := 2
@export_range(0, 3, 1) var unaffordable_spell_index := 3
@export var preview_enable_all_utility_buttons := false
@export var preview_low_health := false
@export var preview_special_resource := true

@export_category("REFINED — dimensions")
@export_range(54.0, 72.0, 1.0) var move_icon_size := 64.0
@export_range(44.0, 48.0, 1.0) var utility_button_size := 46.0
@export_range(26, 34, 1) var utility_icon_size := 30

@export_category("REFINED — intensités")
@export_range(0.55, 1.25, 0.05) var dock_contrast := 1.0
@export_range(0.0, 1.0, 0.05) var panel_texture_intensity := 0.68
@export_range(0.0, 1.4, 0.05) var selection_intensity := 1.0
@export_range(0.0, 1.0, 0.05) var desaturation_intensity := 0.62
@export_range(0.2, 0.85, 0.05) var cooldown_opacity := 0.58

@onready var hud = %CombatHUDRecraftV1


func _ready() -> void:
	var elf := Unit.from_data(ELF_DATA)
	hud.set_ui_mode(hud.RunUIMode.COMBAT)
	hud.set_player_controls_enabled(true)
	hud.update_info(elf)
	hud.build_spell_buttons(elf)
	hud.set_refined_polish_tuning(panel_texture_intensity, dock_contrast)
	var move_button = hud.get_node("%MoveButton")
	move_button.set_compact_icon_mode(true, move_icon_size)
	for button_name in ["InventoryButton", "MapButton", "SkillsButton"]:
		var utility_button: Button = hud.get_node("%" + button_name)
		utility_button.custom_minimum_size = Vector2.ONE * utility_button_size
		utility_button.icon_max_width = utility_icon_size
	if preview_enable_all_utility_buttons:
		hud.get_node("%InventoryButton").disabled = false
		hud.get_node("%MapButton").disabled = false
	var slots: Array = hud.get("_spell_buttons")
	for slot in slots:
		slot.set_polish_tuning(
			selection_intensity,
			desaturation_intensity,
			cooldown_opacity
		)
	if preview_selection == PreviewSelection.MOVE:
		hud.set_active_mode("move")
	elif preview_selection == PreviewSelection.SPELL and selected_spell_index < slots.size():
		var selected_slot = slots[selected_spell_index]
		hud.set_active_mode("spell", selected_slot.get_meta("spell"), false)
	if unavailable_spell_index < slots.size() and unavailable_spell_index != selected_spell_index:
		slots[unavailable_spell_index].set_visual_state(RecraftSpellSlotView.VisualState.DISABLED)
	if cooldown_spell_index < slots.size() and cooldown_spell_index != selected_spell_index:
		slots[cooldown_spell_index].set_cooldown(2)
	if unaffordable_spell_index < slots.size() and unaffordable_spell_index != selected_spell_index:
		slots[unaffordable_spell_index].set_visual_state(RecraftSpellSlotView.VisualState.UNAFFORDABLE)
	# Preview-only future resource and statuses; never connected to combat data.
	var energy_bar = hud.get_node("%EnergyBar")
	energy_bar.visible = preview_special_resource
	if preview_special_resource:
		energy_bar.set_resource(64.0, 100.0, Color(0.31, 0.58, 0.34), null, "N", true, false)
	if preview_low_health:
		hud.get_node("%HealthBar").set_resource(
			12.0, 100.0, Color(0.62, 0.12, 0.14), null, "PV", true, false
		)
	var statuses = hud.get_node("%StatusEffectsContainer")
	statuses.visible = true
	for label_text in ["+2", "↑", "3"]:
		var badge := Label.new()
		badge.custom_minimum_size = Vector2(26, 26)
		badge.text = label_text
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		statuses.add_child(badge)
