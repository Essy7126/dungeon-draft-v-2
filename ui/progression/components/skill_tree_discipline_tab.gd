class_name SkillTreeDisciplineTab
extends Button

@onready var _frame_texture: TextureRect = %FrameTexture
@onready var _selection_rail: Panel = %SelectionRail
@onready var _content_margin: MarginContainer = %ContentMargin
@onready var _content: HBoxContainer = %Content
@onready var _icon: SkillTreeEffectGlyph = %DisciplineIcon
@onready var _name_label: Label = %NameLabel
@onready var _rank_label: Label = %RankLabel
@onready var _xp_progress: ProgressBar = %XPProgress
@onready var _xp_label: Label = %XPLabel
@onready var _next_rank_label: Label = %NextRankLabel
@onready var _path_label: Label = %PathLabel
@onready var _pending_badge: SkillTreeEffectGlyph = %PendingBadge
@onready var _active_marker: Label = %ActiveMarker

var discipline_id: StringName = &""
var skin: SkillTreeSkinData = null
var _layout_profile: StringName = &"large"
var _accent := Color(0.76, 0.58, 0.28, 1.0)


func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply_layout_profile(_layout_profile)


func configure(
		discipline: DisciplineData,
		progress: DisciplineProgressState,
		wanted_skin: SkillTreeSkinData,
		is_selected: bool,
		character_id: StringName = &"elf",
		icon_texture: Texture2D = null
	) -> void:
	skin = wanted_skin
	discipline_id = discipline.discipline_id if discipline != null else &""
	if not is_node_ready():
		await ready
	_frame_texture.texture = (
		skin.discipline_tab_texture if skin != null else null
	)
	_accent = (
		discipline.presentation_color
		if discipline != null
		else Color(0.76, 0.58, 0.28, 1.0)
	)
	var icon_id := _icon_id(character_id, discipline_id)
	if icon_texture != null:
		_icon.configure(icon_id, icon_texture)
	else:
		_icon.configure_discipline(icon_id, skin)
	_name_label.text = discipline.display_name if discipline != null else "Discipline"
	_rank_label.text = "RANG %d" % (progress.rank if progress != null else 1)
	_configure_progress(discipline, progress)
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
	tooltip_text = _tooltip_text(discipline, progress)
	set_selected(is_selected)


func set_selected(value: bool) -> void:
	button_pressed = value
	_selection_rail.visible = value
	_selection_rail.modulate = Color(1.0, 0.72, 0.22, 1.0)
	_active_marker.visible = value
	_active_marker.text = "BRANCHE ACTIVE" if value else ""
	_frame_texture.modulate = (
		Color(1.06, 1.01, 0.9, 1.0)
		if value
		else Color(0.62, 0.59, 0.56, 0.86)
	)


func apply_layout_profile(profile: StringName) -> void:
	_layout_profile = profile
	if not is_node_ready():
		return
	var compact := profile == &"compact"
	var medium := profile == &"medium"
	custom_minimum_size = Vector2(
		202.0 if compact else 222.0 if medium else 252.0,
		104.0 if compact else 112.0 if medium else 122.0
	)
	_content_margin.add_theme_constant_override(
		"margin_left", 12 if compact else 14 if medium else 16
	)
	_content_margin.add_theme_constant_override(
		"margin_right", 9 if compact else 11 if medium else 13
	)
	_content_margin.add_theme_constant_override(
		"margin_top", 8 if compact else 9 if medium else 10
	)
	_content_margin.add_theme_constant_override(
		"margin_bottom", 7 if compact else 8 if medium else 9
	)
	_content.add_theme_constant_override(
		"separation", 7 if compact else 8 if medium else 10
	)
	_icon.custom_minimum_size = Vector2(
		34.0 if compact else 38.0 if medium else 44.0,
		34.0 if compact else 38.0 if medium else 44.0
	)
	_name_label.add_theme_font_size_override(
		"font_size", 14 if compact else 15 if medium else 17
	)
	_rank_label.add_theme_font_size_override(
		"font_size", 11 if compact else 12 if medium else 13
	)
	_xp_label.add_theme_font_size_override(
		"font_size", 10 if compact else 11 if medium else 12
	)
	_next_rank_label.add_theme_font_size_override(
		"font_size", 9 if compact else 10 if medium else 11
	)
	_path_label.add_theme_font_size_override(
		"font_size", 9 if compact else 10 if medium else 11
	)
	_active_marker.add_theme_font_size_override(
		"font_size", 9 if compact else 10 if medium else 11
	)
	_pending_badge.custom_minimum_size = Vector2(
		20.0 if compact else 22.0 if medium else 24.0,
		20.0 if compact else 22.0 if medium else 24.0
	)
	_xp_progress.custom_minimum_size.y = 5.0 if compact else 6.0


func get_layout_snapshot() -> Dictionary:
	return {
		"profile": _layout_profile,
		"minimum_size": custom_minimum_size,
		"icon_size": _icon.custom_minimum_size,
		"name_font": _name_label.get_theme_font_size("font_size"),
		"rank_font": _rank_label.get_theme_font_size("font_size"),
		"active_marker_visible": _active_marker.visible,
		"xp_text": _xp_label.text,
		"next_rank_text": _next_rank_label.text,
		"path_text": _path_label.text,
		"progress_visible": _xp_progress.visible,
	}


func get_discipline_id() -> StringName:
	return discipline_id


func has_pending_badge() -> bool:
	return _pending_badge.visible


func _configure_progress(
		discipline: DisciplineData,
		progress: DisciplineProgressState
	) -> void:
	if progress == null:
		_xp_progress.hide()
		_xp_label.text = "XP indisponible"
		_next_rank_label.text = "Progression non définie"
		_path_label.text = "Aucun choix acquis"
		return
	var next_rank := progress.get_next_rank_data()
	var has_defined_future := next_rank != null
	var has_any_choice := false
	if discipline != null:
		for rank_data in discipline.ranks:
			if rank_data != null and not rank_data.choices.is_empty():
				has_any_choice = true
				break
	_xp_progress.visible = has_defined_future or has_any_choice
	if next_rank != null:
		_xp_progress.min_value = 0.0
		_xp_progress.max_value = maxf(float(next_rank.required_total_xp), 1.0)
		_xp_progress.value = clampf(
			float(progress.xp), 0.0, _xp_progress.max_value
		)
		_xp_label.text = "%d / %d XP" % [
			progress.xp, next_rank.required_total_xp
		]
		_next_rank_label.text = "Prochain rang : %d" % next_rank.rank
	elif has_any_choice:
		_xp_progress.min_value = 0.0
		_xp_progress.max_value = maxf(float(progress.xp), 1.0)
		_xp_progress.value = _xp_progress.max_value
		_xp_label.text = "%d XP · MAX" % progress.xp
		_next_rank_label.text = "RANG MAXIMUM"
	else:
		_xp_label.text = "%d XP" % progress.xp
		_next_rank_label.text = "Progression non définie"
	var selected := progress.get_selected_upgrades()
	if selected.is_empty():
		_path_label.text = "Aucun choix acquis"
	else:
		_path_label.text = " › ".join(
			selected.map(func(upgrade): return upgrade.display_name)
		)


func _icon_id(
		character_id: StringName,
		wanted_discipline_id: StringName
	) -> StringName:
	if character_id == &"elf":
		return StringName("elf_%s" % wanted_discipline_id)
	return wanted_discipline_id


func _tooltip_text(
		discipline: DisciplineData,
		progress: DisciplineProgressState
	) -> String:
	if discipline == null:
		return "Progression non définie"
	var lines := [discipline.display_name, discipline.description]
	if progress != null:
		lines.append("Rang %d · %d XP" % [progress.rank, progress.xp])
	return "\n".join(lines)
