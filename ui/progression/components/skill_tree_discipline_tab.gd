class_name SkillTreeDisciplineTab
extends Button

@onready var _frame_texture: TextureRect = %FrameTexture
@onready var _content_margin: MarginContainer = %ContentMargin
@onready var _content: HBoxContainer = %Content
@onready var _icon: SkillTreeEffectGlyph = %DisciplineIcon
@onready var _name_label: Label = %NameLabel
@onready var _rank_label: Label = %RankLabel
@onready var _pending_badge: SkillTreeEffectGlyph = %PendingBadge
@onready var _active_marker: Label = %ActiveMarker

var discipline_id: StringName = &""
var skin: SkillTreeSkinData = null
var _layout_profile: StringName = &"large"


func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply_layout_profile(_layout_profile)


func configure(
		discipline: DisciplineData,
		progress: DisciplineProgressState,
		wanted_skin: SkillTreeSkinData,
		is_selected: bool
	) -> void:
	skin = wanted_skin
	discipline_id = (
		discipline.discipline_id if discipline != null else &""
	)
	if not is_node_ready():
		await ready
	_frame_texture.texture = (
		skin.discipline_tab_texture if skin != null else null
	)
	var icon_id := StringName("elf_%s" % discipline_id)
	_icon.configure_discipline(icon_id, skin)
	_name_label.text = (
		discipline.display_name if discipline != null else "Discipline"
	)
	_rank_label.text = "R%d" % (
		progress.rank if progress != null else 1
	)
	var has_pending := (
		progress != null
		and not progress.get_pending_rank_choices().is_empty()
	)
	_pending_badge.visible = has_pending
	if has_pending:
		_pending_badge.configure(
			&"pending",
			skin.get_state_texture(&"pending") if skin != null else null
		)
	set_selected(is_selected)


func set_selected(value: bool) -> void:
	button_pressed = value
	_active_marker.visible = value
	_active_marker.text = "✓" if value else ""


func apply_layout_profile(profile: StringName) -> void:
	_layout_profile = profile
	if not is_node_ready():
		return
	var compact := profile == &"compact"
	var medium := profile == &"medium"
	custom_minimum_size = Vector2(
		210.0 if compact else 232.0 if medium else 260.0,
		60.0 if compact else 66.0 if medium else 72.0
	)
	_content_margin.add_theme_constant_override(
		"margin_left",
		11 if compact else 13 if medium else 15
	)
	_content_margin.add_theme_constant_override(
		"margin_right",
		11 if compact else 13 if medium else 15
	)
	_content_margin.add_theme_constant_override(
		"margin_top",
		6 if compact else 7 if medium else 8
	)
	_content_margin.add_theme_constant_override(
		"margin_bottom",
		6 if compact else 7 if medium else 8
	)
	_content.add_theme_constant_override(
		"separation",
		7 if compact else 8 if medium else 10
	)
	_icon.custom_minimum_size = Vector2(
		34.0 if compact else 38.0 if medium else 42.0,
		34.0 if compact else 38.0 if medium else 42.0
	)
	_name_label.add_theme_font_size_override(
		"font_size",
		14 if compact else 15 if medium else 16
	)
	_rank_label.add_theme_font_size_override(
		"font_size",
		14 if compact else 15 if medium else 16
	)
	_active_marker.add_theme_font_size_override(
		"font_size",
		12 if compact else 13 if medium else 14
	)
	_pending_badge.custom_minimum_size = Vector2(
		22.0 if compact else 24.0 if medium else 26.0,
		22.0 if compact else 24.0 if medium else 26.0
	)


func get_layout_snapshot() -> Dictionary:
	return {
		"profile": _layout_profile,
		"minimum_size": custom_minimum_size,
		"icon_size": _icon.custom_minimum_size,
		"name_font": _name_label.get_theme_font_size("font_size"),
		"rank_font": _rank_label.get_theme_font_size("font_size"),
		"active_marker_visible": _active_marker.visible,
	}


func get_discipline_id() -> StringName:
	return discipline_id


func has_pending_badge() -> bool:
	return _pending_badge.visible
