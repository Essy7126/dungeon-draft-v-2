@tool
class_name EmbeddedStudioHost
extends Control

signal reintegrate_requested
signal focus_window_requested

var workspace: StudioWorkspace = null
var placeholder: CenterContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_placeholder()


func attach_workspace(value: StudioWorkspace) -> void:
	workspace = value
	if workspace == null:
		show_detached_placeholder()
		return
	if workspace.get_parent() != null:
		workspace.get_parent().remove_child(workspace)
	add_child(workspace)
	workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	workspace.show()
	if placeholder != null:
		placeholder.hide()


func show_detached_placeholder() -> void:
	if workspace != null and workspace.get_parent() == self:
		remove_child(workspace)
	if placeholder != null:
		placeholder.show()


func _build_placeholder() -> void:
	placeholder = CenterContainer.new()
	placeholder.name = "DetachedPlaceholder"
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(placeholder)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 190)
	placeholder.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "STUDIO OUVERT DANS UNE FENETRE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.48, 0.86, 1.0))
	box.add_child(title)
	var explanation := Label.new()
	explanation.text = "La session, la selection et l'historique restent actifs."
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(explanation)
	var reintegrate := Button.new()
	reintegrate.text = "Reintegrer dans Godot"
	reintegrate.pressed.connect(func(): reintegrate_requested.emit())
	box.add_child(reintegrate)
	var focus := Button.new()
	focus.text = "Mettre la fenetre au premier plan"
	focus.pressed.connect(func(): focus_window_requested.emit())
	box.add_child(focus)
	placeholder.hide()
