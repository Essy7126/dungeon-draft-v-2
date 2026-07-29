class_name SkillTreeStatusButton
extends Button

signal tree_requested(character_id: StringName, discipline_id: StringName)

@export var character_id: StringName = &"elf"
@export var discipline_id: StringName = &"archer"

@onready var _discipline_label: Label = %DisciplineLabel
@onready var _rank_label: Label = %RankLabel
@onready var _xp_label: Label = %XPLabel
@onready var _progress_bar: ProgressBar = %XPProgress
@onready var _pending_badge: Label = %PendingBadge
@onready var _tooltip_panel: SkillTreeTooltipPanel = %TooltipPanel

var progression_controller = null
var _context_visible := true
var _has_character_state := false


func _ready() -> void:
	if progression_controller == null:
		progression_controller = GameManager
	pressed.connect(_on_pressed)
	mouse_entered.connect(_show_structured_tooltip)
	mouse_exited.connect(_hide_structured_tooltip)
	focus_entered.connect(_show_structured_tooltip)
	focus_exited.connect(_hide_structured_tooltip)
	_connect_progression_signal()
	refresh_from_state()


func _exit_tree() -> void:
	_disconnect_progression_signal()


func set_progression_controller(controller) -> void:
	if progression_controller == controller:
		refresh_from_state()
		return
	_disconnect_progression_signal()
	progression_controller = controller
	_connect_progression_signal()
	refresh_from_state()


func set_context_visible(value: bool) -> void:
	_context_visible = value
	visible = _context_visible and _has_character_state
	if not visible:
		_hide_structured_tooltip()


func refresh_from_state() -> void:
	var character_state := _get_character_state()
	_has_character_state = character_state != null
	visible = _context_visible and _has_character_state
	if character_state == null:
		_discipline_label.text = "Archer"
		_rank_label.text = "R—"
		_xp_label.text = "— / —"
		_progress_bar.min_value = 0.0
		_progress_bar.max_value = 1.0
		_progress_bar.value = 0.0
		_pending_badge.hide()
		_tooltip_panel.refresh_from_state(null)
		return
	var discipline := _find_discipline(character_state, discipline_id)
	var progress := character_state.get_discipline_progress(discipline_id)
	if discipline == null or progress == null:
		_has_character_state = false
		visible = false
		return
	_discipline_label.text = discipline.display_name
	_rank_label.text = "R%d" % progress.rank
	var next_rank := progress.get_next_rank_data()
	var next_threshold := (
		next_rank.required_total_xp if next_rank != null else progress.xp
	)
	_xp_label.text = (
		"%d / %d" % [progress.xp, next_threshold]
		if next_rank != null
		else "%d / MAX" % progress.xp
	)
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = maxf(float(next_threshold), 1.0)
	_progress_bar.value = clampf(
		float(progress.xp),
		0.0,
		_progress_bar.max_value
	)
	_pending_badge.visible = not progress.get_pending_rank_choices().is_empty()
	_tooltip_panel.refresh_from_state(character_state)


func get_rank_text() -> String:
	return _rank_label.text


func get_xp_text() -> String:
	return _xp_label.text


func has_pending_badge() -> bool:
	return _pending_badge.visible


func get_tooltip_panel() -> SkillTreeTooltipPanel:
	return _tooltip_panel


func _on_discipline_xp_gained(
		gained_character_id,
		gained_discipline_id,
		_amount,
		_snapshot
	) -> void:
	if StringName(gained_character_id) != character_id \
			or StringName(gained_discipline_id) != discipline_id:
		return
	refresh_from_state()


func _on_pressed() -> void:
	_hide_structured_tooltip()
	tree_requested.emit(character_id, discipline_id)


func _show_structured_tooltip() -> void:
	refresh_from_state()
	if _has_character_state:
		_tooltip_panel.show()


func _hide_structured_tooltip() -> void:
	if is_instance_valid(_tooltip_panel):
		_tooltip_panel.hide()


func _get_character_state() -> CharacterRunState:
	if progression_controller == null \
			or not progression_controller.has_method("get_character_state"):
		return null
	return progression_controller.get_character_state(
		character_id
	) as CharacterRunState


func _find_discipline(
		character_state: CharacterRunState,
		wanted_id: StringName
	) -> DisciplineData:
	for discipline in character_state.get_disciplines():
		if discipline != null and discipline.discipline_id == wanted_id:
			return discipline
	return null


func _connect_progression_signal() -> void:
	if progression_controller == null \
			or not progression_controller.has_signal("discipline_xp_gained"):
		return
	var callback := Callable(self, "_on_discipline_xp_gained")
	if not progression_controller.discipline_xp_gained.is_connected(callback):
		progression_controller.discipline_xp_gained.connect(callback)


func _disconnect_progression_signal() -> void:
	if progression_controller == null \
			or not progression_controller.has_signal("discipline_xp_gained"):
		return
	var callback := Callable(self, "_on_discipline_xp_gained")
	if progression_controller.discipline_xp_gained.is_connected(callback):
		progression_controller.discipline_xp_gained.disconnect(callback)
