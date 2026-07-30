class_name SkillTreeNodeView
extends Control

signal inspection_requested(node_view)

const PROFILE_LARGE := &"large"
const PROFILE_MEDIUM := &"medium"
const PROFILE_COMPACT := &"compact"

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
var _layout_profile: StringName = PROFILE_LARGE
var _visual_frame_size := 132.0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_request_inspection)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	gui_input.connect(_on_gui_input)
	_focus_overlay.hide()
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.max_lines_visible = 2
	_name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	apply_layout_profile(_layout_profile)


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
	apply_layout_profile(_layout_profile)
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
	apply_layout_profile(_layout_profile)
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


func apply_layout_profile(profile: StringName) -> void:
	_layout_profile = profile
	if not is_node_ready():
		return
	var rank := get_rank()
	var metrics := _layout_metrics(profile, rank)
	_visual_frame_size = float(metrics["frame"])
	var control_size: Vector2 = metrics["control"]
	custom_minimum_size = control_size
	size = control_size

	var frame_left := (control_size.x - _visual_frame_size) * 0.5
	var frame_rect := Rect2(
		Vector2(frame_left, 0.0),
		Vector2(_visual_frame_size, _visual_frame_size)
	)
	var halo_padding := float(metrics["halo_padding"])
	_set_control_rect(
		_capstone_halo,
		frame_rect.grow(halo_padding).position,
		frame_rect.grow(halo_padding).size
	)
	_set_control_rect(_state_backdrop, frame_rect.position, frame_rect.size)
	_set_control_rect(_frame_texture, frame_rect.position, frame_rect.size)
	_set_control_rect(_focus_overlay, frame_rect.grow(3.0).position, frame_rect.grow(3.0).size)

	var discipline_size := float(metrics["discipline_icon"])
	_set_control_rect(
		_discipline_icon,
		frame_rect.position + Vector2(10.0, 9.0),
		Vector2(discipline_size, discipline_size)
	)
	var primary_size := float(metrics["primary_glyph"])
	var primary_position := (
		frame_rect.position
		+ (frame_rect.size - Vector2(primary_size, primary_size)) * 0.5
		+ Vector2(0.0, -2.0)
	)
	_set_control_rect(
		_icon_override,
		primary_position,
		Vector2(primary_size, primary_size)
	)
	_set_control_rect(
		_primary_glyph,
		primary_position,
		Vector2(primary_size, primary_size)
	)
	var secondary_size := float(metrics["secondary_glyph"])
	_set_control_rect(
		_secondary_glyph,
		Vector2(
			frame_rect.end.x - secondary_size - 12.0,
			frame_rect.position.y + _visual_frame_size * 0.5
		),
		Vector2(secondary_size, secondary_size)
	)
	var state_size := float(metrics["state_icon"])
	_set_control_rect(
		_state_icon,
		Vector2(
			frame_rect.end.x - state_size - 8.0,
			frame_rect.position.y + 8.0
		),
		Vector2(state_size, state_size)
	)
	var badge_size: Vector2 = metrics["rank_badge"]
	var badge_position := Vector2(
		frame_rect.position.x + 7.0,
		frame_rect.position.y + _visual_frame_size * 0.58
	)
	_set_control_rect(_rank_badge_texture, badge_position, badge_size)
	_set_control_rect(_rank_badge_fallback, badge_position, badge_size)
	_set_control_rect(_rank_label, badge_position, badge_size)

	var title_top := float(metrics["title_top"])
	var title_height := float(metrics["title_height"])
	_set_control_rect(
		_name_label,
		Vector2(0.0, title_top),
		Vector2(control_size.x, title_height)
	)
	var threshold_top := float(metrics["threshold_top"])
	_set_control_rect(
		_threshold_label,
		Vector2(0.0, threshold_top),
		Vector2(
			control_size.x,
			control_size.y - threshold_top
		)
	)
	_name_label.add_theme_font_size_override(
		"font_size",
		int(metrics["name_font"])
	)
	_name_label.add_theme_color_override(
		"font_outline_color",
		Color(0.02, 0.025, 0.03, 0.96)
	)
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rank_label.add_theme_font_size_override(
		"font_size",
		int(metrics["rank_font"])
	)
	_threshold_label.add_theme_font_size_override(
		"font_size",
		int(metrics["xp_font"])
	)


func get_layout_profile() -> StringName:
	return _layout_profile


func get_visual_frame_size() -> Vector2:
	return Vector2(_visual_frame_size, _visual_frame_size)


func get_visual_frame_rect() -> Rect2:
	return _frame_texture.get_rect()


func get_name_layout_snapshot() -> Dictionary:
	return {
		"text": _name_label.text,
		"bounds": _name_label.get_rect(),
		"line_count": _name_label.get_line_count(),
		"font_size": _name_label.get_theme_font_size("font_size"),
		"truncated": is_name_truncated(),
	}


func is_name_truncated() -> bool:
	return _name_label.get_line_count() > 2


func get_connection_anchor(side: StringName) -> Vector2:
	var frame_rect := _frame_texture.get_rect()
	var frame_center := frame_rect.position + frame_rect.size * 0.5
	return (
		Vector2(frame_rect.end.x, frame_center.y)
		if side == &"right"
		else Vector2(frame_rect.position.x, frame_center.y)
	)


func _layout_metrics(profile: StringName, rank: int) -> Dictionary:
	var frame := 120.0
	var control_width := 148.0
	var name_font := 16
	var rank_font := 14
	var xp_font := 13
	var title_height := 36.0
	var discipline_icon := 24.0
	var primary_glyph := 54.0
	var secondary_glyph := 28.0
	var state_icon := 28.0
	var rank_badge := Vector2(44.0, 22.0)
	if profile == PROFILE_MEDIUM:
		frame = 108.0
		control_width = 136.0
		name_font = 15
		rank_font = 13
		xp_font = 12
		title_height = 34.0
		discipline_icon = 22.0
		primary_glyph = 49.0
		secondary_glyph = 25.0
		state_icon = 25.0
		rank_badge = Vector2(40.0, 20.0)
	elif profile == PROFILE_COMPACT:
		frame = 98.0
		control_width = 124.0
		name_font = 13
		rank_font = 12
		xp_font = 11
		title_height = 31.0
		discipline_icon = 20.0
		primary_glyph = 44.0
		secondary_glyph = 23.0
		state_icon = 23.0
		rank_badge = Vector2(38.0, 19.0)
	if rank <= 1:
		frame = (
			132.0
			if profile == PROFILE_LARGE
			else 120.0 if profile == PROFILE_MEDIUM else 106.0
		)
		control_width += 12.0
	elif rank >= 5:
		frame = (
			148.0
			if profile == PROFILE_LARGE
			else 134.0 if profile == PROFILE_MEDIUM else 120.0
		)
		control_width += (
			26.0
			if profile == PROFILE_LARGE
			else 22.0 if profile == PROFILE_MEDIUM else 18.0
		)
		primary_glyph = frame * 0.45
	var title_top := frame * (
		0.68 if rank >= 5 else 0.75
	)
	var threshold_top := title_top + title_height - 3.0
	var control_height := threshold_top + float(xp_font) + 7.0
	return {
		"frame": frame,
		"control": Vector2(control_width, control_height),
		"name_font": name_font,
		"rank_font": rank_font,
		"xp_font": xp_font,
		"title_top": title_top,
		"title_height": title_height,
		"threshold_top": threshold_top,
		"discipline_icon": discipline_icon,
		"primary_glyph": primary_glyph,
		"secondary_glyph": secondary_glyph,
		"state_icon": state_icon,
		"rank_badge": rank_badge,
		"halo_padding": (
			7.0 if rank >= 5 else 0.0
		),
	}


func _set_control_rect(
		control: Control,
		wanted_position: Vector2,
		wanted_size: Vector2
	) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = wanted_position
	control.size = wanted_size


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
