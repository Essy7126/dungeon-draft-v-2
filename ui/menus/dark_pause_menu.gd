class_name DarkPauseMenu
extends CanvasLayer

signal resume_requested
signal return_to_title_requested(reason: StringName)
signal equipment_requested
signal reduced_motion_changed(enabled: bool)

const UNAVAILABLE_ACTIONS := [
	&"characters",
	&"compendium",
]

@onready var _pause_root: Control = %PauseRoot
@onready var _menu_panel: Control = %MenuPanel
@onready var _content_margin: MarginContainer = %ContentMargin
@onready var _layout: VBoxContainer = %Layout
@onready var _header_slot: Control = %HeaderSlot
@onready var _title_label: Label = %TitleLabel
@onready var _main_buttons: VBoxContainer = %MainButtons
@onready var _bottom_slot: Control = %BottomSlot
@onready var _close_button: TextureButton = %CloseButton
@onready var _confirmation: ConfirmationDialog = %ExitConfirmation
@onready var _resume_button: DarkMenuButton = %ResumeButton
@onready var _characters_button: DarkMenuButton = %CharactersButton
@onready var _equipment_button: DarkMenuButton = %EquipmentButton
@onready var _compendium_button: DarkMenuButton = %CompendiumButton
@onready var _options_button: DarkMenuButton = %OptionsButton
@onready var _abandon_button: DarkMenuButton = %AbandonButton
@onready var _return_button: Button = %ReturnButton

var _actions: Dictionary = {}
var _pending_exit_reason: StringName = &""
var _open_tween: Tween = null
var _layout_profile: StringName = &"large"
var _reduced_motion := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PremiumUI.apply(_pause_root)
	_actions = {
		&"resume": _resume_button,
		&"characters": _characters_button,
		&"equipment": _equipment_button,
		&"compendium": _compendium_button,
		&"options": _options_button,
		&"abandon": _abandon_button,
		&"return_to_title": _return_button,
	}
	_resume_button.configure("REPRENDRE")
	_characters_button.configure("PERSONNAGES", false)
	_equipment_button.configure("ÉQUIPEMENTS", true)
	_compendium_button.configure("COMPENDIUM", false)
	_options_button.configure("ANIMATIONS : STANDARD")
	_abandon_button.configure("ABANDONNER LA RUN")
	_resume_button.pressed.connect(_request_resume)
	_equipment_button.pressed.connect(func() -> void: equipment_requested.emit())
	_options_button.pressed.connect(_toggle_reduced_motion)
	_close_button.pressed.connect(_request_resume)
	_abandon_button.pressed.connect(
		_request_exit_confirmation.bind(&"abandon")
	)
	_return_button.pressed.connect(
		_request_exit_confirmation.bind(&"return_to_title")
	)
	_confirmation.confirmed.connect(_on_exit_confirmed)
	_confirmation.canceled.connect(_restore_primary_focus)
	_confirmation.title = "Confirmer"
	_confirmation.get_ok_button().text = "CONFIRMER"
	_confirmation.get_cancel_button().text = "ANNULER"
	_close_button.mouse_entered.connect(_set_close_emphasis.bind(true))
	_close_button.mouse_exited.connect(_set_close_emphasis.bind(false))
	_close_button.focus_entered.connect(_set_close_emphasis.bind(true))
	_close_button.focus_exited.connect(_set_close_emphasis.bind(false))
	_pause_root.resized.connect(_on_root_resized)
	_pause_root.hide()
	_configure_focus_navigation()
	_apply_responsive_layout(_pause_root.size)


func open_menu() -> void:
	if is_open():
		return
	_pending_exit_reason = &""
	_confirmation.hide()
	_pause_root.show()
	_pause_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_menu_panel.scale = Vector2.ONE * 0.965
	_update_panel_pivot()
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	if _reduced_motion:
		_pause_root.modulate = Color.WHITE
		_menu_panel.scale = Vector2.ONE
		_resume_button.grab_focus.call_deferred()
		return
	_open_tween = create_tween().set_parallel(true)
	_open_tween.set_trans(Tween.TRANS_QUAD)
	_open_tween.set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(
		_pause_root,
		"modulate",
		Color.WHITE,
		0.14
	)
	_open_tween.tween_property(
		_menu_panel,
		"scale",
		Vector2.ONE,
		0.16
	)
	_resume_button.grab_focus.call_deferred()


func close_menu() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = null
	_confirmation.hide()
	_pending_exit_reason = &""
	_pause_root.hide()
	_pause_root.modulate = Color.WHITE
	_menu_panel.scale = Vector2.ONE


func is_open() -> bool:
	return is_instance_valid(_pause_root) and _pause_root.visible


func has_open_confirmation() -> bool:
	return is_instance_valid(_confirmation) and _confirmation.visible


func dismiss_confirmation() -> bool:
	if not has_open_confirmation():
		return false
	_confirmation.hide()
	_pending_exit_reason = &""
	_restore_primary_focus()
	return true


func set_action_available(action_id: StringName, available: bool) -> void:
	var button := _actions.get(action_id) as BaseButton
	if button == null or action_id in [&"resume", &"return_to_title"]:
		return
	button.disabled = not available
	if button is DarkMenuButton:
		(button as DarkMenuButton).tooltip_text = (
			""
			if available
			else "Cette section n'est pas encore disponible."
		)
	_configure_focus_navigation()


func get_action_button(action_id: StringName) -> BaseButton:
	return _actions.get(action_id) as BaseButton


func get_close_button() -> TextureButton:
	return _close_button


func get_confirmation_dialog() -> ConfirmationDialog:
	return _confirmation


func get_layout_profile() -> StringName:
	return _layout_profile


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	for button in [
		_resume_button,
		_characters_button,
		_equipment_button,
		_compendium_button,
		_options_button,
		_abandon_button,
	]:
		if button != null:
			button.set_reduced_motion(enabled)
	if enabled and is_open():
		if _open_tween != null and _open_tween.is_valid():
			_open_tween.kill()
		_open_tween = null
		_pause_root.modulate = Color.WHITE
		_menu_panel.scale = Vector2.ONE
	if is_instance_valid(_options_button):
		_options_button.configure(
			"ANIMATIONS : RÉDUITES" if enabled else "ANIMATIONS : STANDARD"
		)
		_options_button.tooltip_text = (
			"Transitions instantanées et mouvements d’interface limités."
			if enabled
			else "Activer la réduction des mouvements d’interface."
		)


func is_reduced_motion_enabled() -> bool:
	return _reduced_motion


func _toggle_reduced_motion() -> void:
	set_reduced_motion(not _reduced_motion)
	reduced_motion_changed.emit(_reduced_motion)


func get_layout_snapshot() -> Dictionary:
	return {
		"profile": _layout_profile,
		"viewport": _pause_root.get_rect(),
		"panel": _menu_panel.get_global_rect(),
		"header": _header_slot.get_global_rect(),
		"main_buttons": _main_buttons.get_global_rect(),
		"bottom": _bottom_slot.get_global_rect(),
		"close": _close_button.get_global_rect(),
	}


func apply_viewport_size_for_test(viewport_size: Vector2) -> void:
	_pause_root.size = viewport_size
	_apply_responsive_layout(viewport_size)


func _request_resume() -> void:
	if has_open_confirmation():
		dismiss_confirmation()
		return
	resume_requested.emit()


func _request_exit_confirmation(reason: StringName) -> void:
	_pending_exit_reason = reason
	_confirmation.dialog_text = (
		"Abandonner la run en cours et revenir au menu principal ?"
		if reason == &"abandon"
		else "Quitter la run et revenir au menu principal ?"
	)
	_confirmation.popup_centered(Vector2i(460, 190))


func _on_exit_confirmed() -> void:
	var reason := _pending_exit_reason
	_pending_exit_reason = &""
	if reason != &"":
		return_to_title_requested.emit(reason)


func _restore_primary_focus() -> void:
	if is_open():
		_resume_button.grab_focus.call_deferred()


func _configure_focus_navigation() -> void:
	if not is_node_ready():
		return
	var enabled: Array[Control] = []
	for action_id in [
		&"resume",
		&"characters",
		&"equipment",
		&"compendium",
		&"options",
		&"abandon",
		&"return_to_title",
	]:
		var action := _actions.get(action_id) as BaseButton
		if action != null and not action.disabled:
			enabled.append(action)
	if enabled.is_empty():
		return
	for index in range(enabled.size()):
		var current := enabled[index]
		var previous := enabled[
			(index - 1 + enabled.size()) % enabled.size()
		]
		var following := enabled[(index + 1) % enabled.size()]
		current.focus_neighbor_top = current.get_path_to(previous)
		current.focus_neighbor_bottom = current.get_path_to(following)
	_close_button.focus_neighbor_left = _close_button.get_path_to(
		_resume_button
	)
	_close_button.focus_neighbor_bottom = _close_button.get_path_to(
		_resume_button
	)


func _on_root_resized() -> void:
	_apply_responsive_layout(_pause_root.size)


func _apply_responsive_layout(viewport_size: Vector2) -> void:
	if not is_node_ready() or viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var compact := viewport_size.x <= 1366.0 or viewport_size.y <= 760.0
	var medium := viewport_size.x <= 2000.0 or viewport_size.y <= 1120.0
	_layout_profile = (
		&"compact" if compact else &"medium" if medium else &"large"
	)
	var frame_size := minf(
		minf(viewport_size.x, viewport_size.y) * 0.91,
		860.0
	)
	frame_size = maxf(frame_size, 560.0)
	_menu_panel.custom_minimum_size = Vector2(frame_size, frame_size)
	var horizontal_inset: float = round(frame_size * 0.12)
	var vertical_inset: float = round(frame_size * 0.09)
	_content_margin.add_theme_constant_override(
		"margin_left",
		int(horizontal_inset)
	)
	_content_margin.add_theme_constant_override(
		"margin_right",
		int(horizontal_inset)
	)
	_content_margin.add_theme_constant_override(
		"margin_top",
		int(vertical_inset)
	)
	_content_margin.add_theme_constant_override(
		"margin_bottom",
		int(vertical_inset)
	)
	_layout.add_theme_constant_override(
		"separation",
		4 if compact else 7
	)
	_main_buttons.add_theme_constant_override(
		"separation",
		1 if compact else 3
	)
	_header_slot.custom_minimum_size.y = (
		72.0 if compact else 88.0 if medium else 94.0
	)
	_bottom_slot.custom_minimum_size.y = (
		58.0 if compact else 70.0 if medium else 76.0
	)
	var button_size := Vector2(
		minf(460.0, frame_size - horizontal_inset * 2.0),
		58.0 if compact else 62.0 if medium else 66.0
	)
	for action_id in [
		&"resume",
		&"characters",
		&"equipment",
		&"compendium",
		&"options",
		&"abandon",
	]:
		var button := _actions.get(action_id) as DarkMenuButton
		if button != null:
			button.minimum_button_size = button_size
			button.add_theme_font_size_override(
				"font_size",
				16 if compact else 18 if medium else 19
			)
	_title_label.add_theme_font_size_override(
		"font_size",
		23 if compact else 27 if medium else 29
	)
	_return_button.add_theme_font_size_override(
		"font_size",
		14 if compact else 16
	)
	var close_size := (
		56.0 if compact else 68.0 if medium else 74.0
	)
	_close_button.offset_left = -close_size - frame_size * 0.055
	_close_button.offset_top = frame_size * 0.045
	_close_button.offset_right = -frame_size * 0.055
	_close_button.offset_bottom = frame_size * 0.045 + close_size
	_update_panel_pivot.call_deferred()


func _update_panel_pivot() -> void:
	if is_instance_valid(_menu_panel):
		_menu_panel.pivot_offset = _menu_panel.size * 0.5


func _set_close_emphasis(emphasized: bool) -> void:
	if not is_instance_valid(_close_button):
		return
	_close_button.self_modulate = (
		Color(1.08, 1.04, 1.02, 1.0)
		if emphasized
		else Color.WHITE
	)
