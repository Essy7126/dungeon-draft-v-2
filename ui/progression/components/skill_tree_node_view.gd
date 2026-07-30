class_name SkillTreeNodeView
extends Control

signal inspection_requested(node_view)

@onready var _state_backdrop: Panel = %StateBackdrop
@onready var _frame_texture: TextureRect = %FrameTexture
@onready var _icon_override: TextureRect = %IconOverride
@onready var _discipline_icon: SkillTreeEffectGlyph = %DisciplineIcon
@onready var _primary_glyph: SkillTreeEffectGlyph = %EffectGlyphPrimary
@onready var _secondary_glyph: SkillTreeEffectGlyph = %EffectGlyphSecondary
@onready var _state_icon: SkillTreeEffectGlyph = %StateIcon
@onready var _rank_badge_texture: TextureRect = %RankBadgeTexture
@onready var _rank_badge_fallback: PanelContainer = %RankBadgeFallback
@onready var _rank_label: Label = %RankLabel
@onready var _name_label: Label = %NameLabel
@onready var _threshold_label: Label = %ThresholdLabel
@onready var _focus_overlay: Panel = %FocusOverlay
@onready var _capstone_halo: Panel = %CapstoneHalo

var node_data: SkillUpgradeData = null
var discipline_data: DisciplineData = null
var visual_presentation: Dictionary = {}
var presentation_id: StringName = &""
var is_base_rank := false
var skin: SkillTreeSkinData = null
var node_visual: SkillTreeNodeVisualData = null
var _state_icon_id: StringName = &"future"


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_request_inspection)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	gui_input.connect(_on_gui_input)
	_focus_overlay.hide()


func configure_node(
		discipline: DisciplineData,
		node: SkillUpgradeData,
		presentation: Dictionary,
		wanted_skin: SkillTreeSkinData = null,
		wanted_visual: SkillTreeNodeVisualData = null
	) -> void:
	discipline_data = discipline
	node_data = node
	is_base_rank = false
	presentation_id = node.upgrade_id if node != null else &""
	visual_presentation = presentation.duplicate(true)
	skin = wanted_skin
	node_visual = wanted_visual
	if not is_node_ready():
		await ready
	_name_label.text = node.display_name if node != null else "Évolution"
	var rank := node.rank if node != null else 1
	_rank_label.text = "R%d" % rank
	_threshold_label.text = "%d XP" % int(
		presentation.get("required_xp", 0)
	)
	_configure_skin(rank)
	_configure_glyphs(node.icon if node != null else null)
	_apply_visual_state()


func configure_base(
		discipline: DisciplineData,
		display_name: String,
		presentation: Dictionary,
		wanted_skin: SkillTreeSkinData = null,
		wanted_visual: SkillTreeNodeVisualData = null
	) -> void:
	discipline_data = discipline
	node_data = null
	is_base_rank = true
	presentation_id = &"__base_rank_1"
	visual_presentation = presentation.duplicate(true)
	skin = wanted_skin
	node_visual = wanted_visual
	if not is_node_ready():
		await ready
	_name_label.text = display_name
	_rank_label.text = "R1"
	_threshold_label.text = "%d XP" % int(
		presentation.get("required_xp", 0)
	)
	_configure_skin(1)
	_configure_glyphs(null)
	_apply_visual_state()


func refresh_presentation(presentation: Dictionary) -> void:
	visual_presentation = presentation.duplicate(true)
	if is_node_ready():
		_apply_visual_state()


func get_presentation_id() -> StringName:
	return presentation_id


func get_rank() -> int:
	return 1 if is_base_rank or node_data == null else node_data.rank


func get_frame_texture() -> Texture2D:
	return _frame_texture.texture


func get_primary_glyph_id() -> StringName:
	return _primary_glyph.glyph_id


func get_secondary_glyph_id() -> StringName:
	return (
		_secondary_glyph.glyph_id
		if _secondary_glyph.visible
		else &""
	)


func get_state_icon_id() -> StringName:
	return _state_icon_id


func get_rank_badge_text() -> String:
	return _rank_label.text


func get_connection_anchor(side: StringName) -> Vector2:
	var frame_rect := _frame_texture.get_rect()
	var frame_center := frame_rect.position + frame_rect.size * 0.5
	return (
		Vector2(frame_rect.end.x, frame_center.y)
		if side == &"right"
		else Vector2(frame_rect.position.x, frame_center.y)
	)


func is_consultative() -> bool:
	return true


func _configure_skin(rank: int) -> void:
	_frame_texture.texture = (
		skin.get_node_frame(rank) if skin != null else null
	)
	_rank_badge_texture.texture = (
		skin.rank_badge_texture if skin != null else null
	)
	_rank_badge_texture.visible = _rank_badge_texture.texture != null
	_rank_badge_fallback.visible = not _rank_badge_texture.visible
	_capstone_halo.visible = rank >= 5


func _configure_glyphs(legacy_icon: Texture2D) -> void:
	var discipline_icon_id := (
		node_visual.discipline_icon_id
		if node_visual != null and node_visual.discipline_icon_id != &""
		else StringName("elf_%s" % (
			discipline_data.discipline_id
			if discipline_data != null
			else &"archer"
		))
	)
	_discipline_icon.configure_discipline(discipline_icon_id, skin)
	var override := (
		node_visual.icon_override
		if node_visual != null and node_visual.icon_override != null
		else legacy_icon
	)
	_icon_override.texture = override
	_icon_override.visible = override != null
	var primary_id := (
		node_visual.primary_glyph_id
		if node_visual != null
		else &""
	)
	_primary_glyph.visible = override == null
	if _primary_glyph.visible:
		_primary_glyph.configure_effect(
			primary_id if primary_id != &"" else discipline_icon_id,
			skin
		)
	var secondary_id := (
		node_visual.secondary_glyph_id
		if node_visual != null
		else &""
	)
	_secondary_glyph.visible = secondary_id != &""
	if _secondary_glyph.visible:
		_secondary_glyph.configure_effect(secondary_id, skin)


func _apply_visual_state() -> void:
	var state: SkillTreeVisualPresentation.SkillTreeVisualState = int(
		visual_presentation.get(
			"state",
			SkillTreeVisualPresentation.SkillTreeVisualState.FUTURE
		)
	)
	_state_backdrop.theme_type_variation = _backdrop_variation(state)
	_state_icon_id = _state_glyph_id(state)
	_state_icon.configure(
		_state_icon_id,
		skin.get_state_texture(_state_icon_id) if skin != null else null
	)
	match state:
		SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED:
			self_modulate = Color.WHITE
			_frame_texture.modulate = Color(0.84, 1.0, 0.82, 1.0)
		SkillTreeVisualPresentation.SkillTreeVisualState.AVAILABLE:
			self_modulate = Color.WHITE
			_frame_texture.modulate = Color(1.0, 0.82, 0.47, 1.0)
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_XP:
			self_modulate = Color(0.62, 0.65, 0.68, 1.0)
			_frame_texture.modulate = Color(0.58, 0.62, 0.66, 1.0)
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_BRANCH:
			self_modulate = Color(0.48, 0.48, 0.5, 1.0)
			_frame_texture.modulate = Color(0.5, 0.42, 0.44, 1.0)
		SkillTreeVisualPresentation.SkillTreeVisualState.FUTURE:
			self_modulate = Color(0.76, 0.78, 0.8, 1.0)
			_frame_texture.modulate = Color(0.72, 0.76, 0.82, 1.0)


func _backdrop_variation(
		state: SkillTreeVisualPresentation.SkillTreeVisualState
	) -> StringName:
	match state:
		SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED:
			return &"SkillTreeNodeBackdropSelected"
		SkillTreeVisualPresentation.SkillTreeVisualState.AVAILABLE:
			return &"SkillTreeNodeBackdropAvailable"
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_XP:
			return &"SkillTreeNodeBackdropLockedXp"
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_BRANCH:
			return &"SkillTreeNodeBackdropLockedBranch"
	return &"SkillTreeNodeBackdropFuture"


func _state_glyph_id(
		state: SkillTreeVisualPresentation.SkillTreeVisualState
	) -> StringName:
	match state:
		SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED:
			return &"selected"
		SkillTreeVisualPresentation.SkillTreeVisualState.AVAILABLE:
			return &"pending"
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_XP:
			return &"locked"
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_BRANCH:
			return &"excluded"
	return &"future"


func _request_inspection() -> void:
	inspection_requested.emit(self)


func _on_focus_entered() -> void:
	_focus_overlay.show()
	_request_inspection()


func _on_focus_exited() -> void:
	_focus_overlay.hide()


func _on_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		grab_focus()
		_request_inspection()
