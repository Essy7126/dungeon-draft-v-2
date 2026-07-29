class_name PersistentRunUI
extends Node

enum RunUIMode {
	COMBAT,
	NON_COMBAT,
	TRANSITION,
}

@onready var combat_hud: CanvasLayer = %CombatHUDRecraftV1
@onready var contextual_ui_layer: CanvasLayer = %ContextualUILayer
@onready var overlay_layer: CanvasLayer = %OverlayLayer
@onready var skill_tree_status_button: SkillTreeStatusButton = (
	%SkillTreeStatusButton
)
@onready var skill_tree_screen: SkillTreeScreen = %SkillTreeScreen

var _ui_mode: RunUIMode = RunUIMode.TRANSITION
var _combat_controls_before_skill_tree := false


func _ready() -> void:
	skill_tree_status_button.tree_requested.connect(
		_on_skill_tree_requested
	)
	skill_tree_screen.screen_closed.connect(
		_on_skill_tree_screen_closed
	)
	set_ui_mode(_ui_mode)


func bind_combat_context(context: Node) -> CanvasLayer:
	if context == null:
		unbind_combat_context()
		return null
	combat_hud.bind_combat_context(context)
	set_ui_mode(RunUIMode.COMBAT)
	skill_tree_status_button.refresh_from_state()
	return combat_hud


func unbind_combat_context(expected_context: Node = null) -> void:
	if not is_instance_valid(combat_hud):
		return
	if (
		expected_context != null
		and combat_hud.get_combat_context() != expected_context
	):
		return
	combat_hud.unbind_combat_context()
	set_ui_mode(RunUIMode.TRANSITION)


func refresh_from_context() -> void:
	if is_instance_valid(combat_hud):
		combat_hud.refresh_from_context()
	if is_instance_valid(skill_tree_status_button):
		skill_tree_status_button.refresh_from_state()


func set_ui_mode(mode: RunUIMode) -> void:
	_ui_mode = mode
	if (
		mode != RunUIMode.COMBAT
		and is_instance_valid(skill_tree_screen)
		and skill_tree_screen.visible
	):
		skill_tree_screen.close_screen()
	if is_instance_valid(combat_hud):
		combat_hud.set_ui_mode(mode)
	if is_instance_valid(contextual_ui_layer):
		contextual_ui_layer.visible = mode == RunUIMode.NON_COMBAT
	if is_instance_valid(overlay_layer):
		overlay_layer.visible = mode != RunUIMode.TRANSITION
	if is_instance_valid(skill_tree_status_button):
		skill_tree_status_button.set_context_visible(
			mode == RunUIMode.COMBAT
		)


func get_ui_mode() -> RunUIMode:
	return _ui_mode


func get_combat_hud() -> CanvasLayer:
	return combat_hud


func get_skill_tree_status_button() -> SkillTreeStatusButton:
	return skill_tree_status_button


func get_skill_tree_screen() -> SkillTreeScreen:
	return skill_tree_screen


func _on_skill_tree_requested(
		character_id: StringName,
		discipline_id: StringName
	) -> void:
	if _ui_mode != RunUIMode.COMBAT or skill_tree_screen.visible:
		return
	_combat_controls_before_skill_tree = bool(
		combat_hud.get("_player_controls_enabled")
	)
	combat_hud.set_player_controls_enabled(false)
	if not skill_tree_screen.open_for_character(
			character_id,
			GameManager,
			discipline_id
		):
		combat_hud.set_player_controls_enabled(
			_combat_controls_before_skill_tree
		)


func _on_skill_tree_screen_closed() -> void:
	if (
		_ui_mode == RunUIMode.COMBAT
		and is_instance_valid(combat_hud)
		and is_instance_valid(combat_hud.get_combat_context())
	):
		combat_hud.set_player_controls_enabled(
			_combat_controls_before_skill_tree
		)
	_combat_controls_before_skill_tree = false
