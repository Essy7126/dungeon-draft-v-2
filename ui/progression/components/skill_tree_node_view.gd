class_name SkillTreeNodeView
extends PanelContainer

signal inspection_requested(node_view)

@onready var _icon: TextureRect = %Icon
@onready var _placeholder: Label = %Placeholder
@onready var _name_label: Label = %NameLabel
@onready var _rank_label: Label = %RankLabel
@onready var _state_symbol: Label = %StateSymbol
@onready var _state_hint: Label = %StateHint
@onready var _capstone_frame: Panel = %CapstoneFrame

var node_data: SkillUpgradeData = null
var discipline_data: DisciplineData = null
var visual_presentation: Dictionary = {}
var presentation_id: StringName = &""
var is_base_rank := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_request_inspection)
	focus_entered.connect(_request_inspection)


func configure_node(
		discipline: DisciplineData,
		node: SkillUpgradeData,
		presentation: Dictionary
	) -> void:
	discipline_data = discipline
	node_data = node
	is_base_rank = false
	presentation_id = node.upgrade_id if node != null else &""
	visual_presentation = presentation.duplicate(true)
	if not is_node_ready():
		await ready
	_name_label.text = node.display_name if node != null else "Évolution"
	_rank_label.text = "R%d · %d XP" % [
		node.rank if node != null else 1,
		int(presentation.get("required_xp", 0)),
	]
	_set_icon(node.icon if node != null else null, _initials(_name_label.text))
	_apply_visual_state()
	_capstone_frame.visible = node != null and node.rank == 5


func configure_base(
		discipline: DisciplineData,
		display_name: String,
		presentation: Dictionary
	) -> void:
	discipline_data = discipline
	node_data = null
	is_base_rank = true
	presentation_id = &"__base_rank_1"
	visual_presentation = presentation.duplicate(true)
	if not is_node_ready():
		await ready
	_name_label.text = display_name
	_rank_label.text = "R1 · %d XP" % int(
		presentation.get("required_xp", 0)
	)
	_set_icon(
		discipline.icon if discipline != null else null,
		_initials(display_name)
	)
	_apply_visual_state()
	_capstone_frame.visible = false


func refresh_presentation(presentation: Dictionary) -> void:
	visual_presentation = presentation.duplicate(true)
	if is_node_ready():
		_apply_visual_state()


func get_presentation_id() -> StringName:
	return presentation_id


func is_consultative() -> bool:
	return true


func _apply_visual_state() -> void:
	var state: SkillTreeVisualPresentation.SkillTreeVisualState = int(
		visual_presentation.get(
			"state",
			SkillTreeVisualPresentation.SkillTreeVisualState.FUTURE
		)
	)
	theme_type_variation = _variation_for_state(state)
	_state_symbol.text = SkillTreeVisualPresentation.symbol_for_state(state)
	_state_hint.text = SkillTreeVisualPresentation.state_label(state)
	self_modulate = (
		Color(0.72, 0.72, 0.72, 1)
		if state == SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_BRANCH
		else Color.WHITE
	)


func _variation_for_state(
		state: SkillTreeVisualPresentation.SkillTreeVisualState
	) -> StringName:
	match state:
		SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED:
			return &"SkillTreeNodeSelected"
		SkillTreeVisualPresentation.SkillTreeVisualState.AVAILABLE:
			return &"SkillTreeNodeAvailable"
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_XP:
			return &"SkillTreeNodeLockedXp"
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_BRANCH:
			return &"SkillTreeNodeLockedBranch"
		SkillTreeVisualPresentation.SkillTreeVisualState.FUTURE:
			return &"SkillTreeNodeFuture"
	return &"SkillTreeNodeFuture"


func _set_icon(texture: Texture2D, fallback_text: String) -> void:
	_icon.texture = texture
	_icon.visible = texture != null
	_placeholder.text = fallback_text
	_placeholder.visible = texture == null


func _initials(value: String) -> String:
	var words := value.split(" ", false)
	var result := ""
	for word in words:
		if not word.is_empty():
			result += word.left(1).to_upper()
		if result.length() >= 2:
			break
	return result if not result.is_empty() else "?"


func _request_inspection() -> void:
	inspection_requested.emit(self)
