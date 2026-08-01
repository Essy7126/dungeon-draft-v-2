class_name SkillTreeNodeView
extends Control

signal inspection_requested(node_view)

enum RevealMode {
	FULL,
	NEXT_RANK,
	RANK_GATE,
}

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
@onready var _state_text: Label = %StateText
@onready var _focus_overlay: Panel = %FocusOverlay
@onready var _capstone_halo: Panel = %CapstoneHalo
@onready var _lock_overlay: Control = %LockOverlay
@onready var _darkening_layer: ColorRect = %DarkeningLayer
@onready var _lock_icon: TextureRect = %LockIcon
@onready var _requirement_label: Label = %RequirementLabel

var node_data: SkillUpgradeData = null
var discipline_data: DisciplineData = null
var visual_presentation: Dictionary = {}
var presentation_id: StringName = &""
var is_base_rank := false
var skin: SkillTreeSkinData = null
var node_visual: SkillTreeNodeVisualData = null
var reveal_mode: RevealMode = RevealMode.FULL
var _character_id: StringName = &"elf"
var _rank_gate_rank := 0
var _layout_profile: StringName = PROFILE_LARGE
var _visual_frame_size := 82.0
var _inspection_selected := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_request_inspection)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	gui_input.connect(_on_gui_input)
	_frame_texture.hide()
	_rank_badge_texture.hide()
	_focus_overlay.hide()
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.max_lines_visible = 2
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	apply_layout_profile(_layout_profile)


func configure_node(
		discipline: DisciplineData,
		node: SkillUpgradeData,
		presentation: Dictionary,
		wanted_skin: SkillTreeSkinData = null,
		wanted_visual: SkillTreeNodeVisualData = null,
		character_id: StringName = &"elf",
		wanted_reveal_mode: RevealMode = RevealMode.FULL
	) -> void:
	discipline_data = discipline
	node_data = node
	is_base_rank = false
	presentation_id = node.upgrade_id if node != null else &""
	visual_presentation = presentation.duplicate(true)
	skin = wanted_skin
	node_visual = wanted_visual
	_character_id = character_id
	reveal_mode = wanted_reveal_mode
	_rank_gate_rank = 0
	if not is_node_ready():
		await ready
	var rank := node.rank if node != null else 1
	var config := _config()
	var may_show_name := (
		reveal_mode == RevealMode.FULL
		or (
			reveal_mode == RevealMode.NEXT_RANK
			and config != null
			and config.show_next_rank_names
		)
	)
	_name_label.text = (
		node.display_name
		if node != null and may_show_name
		else "COMPÉTENCE VERROUILLÉE"
	)
	_rank_label.text = "R%d" % rank
	_threshold_label.text = (
		"%d XP" % int(presentation.get("required_xp", 0))
		if reveal_mode == RevealMode.FULL
		else "PROGRESSION REQUISE"
	)
	_configure_skin(rank)
	apply_layout_profile(_layout_profile)
	_configure_glyphs()
	_apply_visual_state()


func configure_base(
		discipline: DisciplineData,
		display_name: String,
		presentation: Dictionary,
		wanted_skin: SkillTreeSkinData = null,
		wanted_visual: SkillTreeNodeVisualData = null,
		base_icon: Texture2D = null,
		character_id: StringName = &"elf"
	) -> void:
	discipline_data = discipline
	node_data = null
	is_base_rank = true
	presentation_id = &"__base_rank_1"
	visual_presentation = presentation.duplicate(true)
	skin = wanted_skin
	node_visual = wanted_visual
	_character_id = character_id
	reveal_mode = RevealMode.FULL
	_rank_gate_rank = 0
	if not is_node_ready():
		await ready
	_name_label.text = display_name
	_rank_label.text = "R1"
	_threshold_label.text = "%d XP" % int(presentation.get("required_xp", 0))
	_configure_skin(1)
	apply_layout_profile(_layout_profile)
	_configure_glyphs(base_icon)
	_apply_visual_state()


func configure_rank_gate(
		discipline: DisciplineData,
		rank_number: int,
		wanted_skin: SkillTreeSkinData = null,
		character_id: StringName = &"elf",
		gate_suffix: StringName = &""
	) -> void:
	discipline_data = discipline
	node_data = null
	is_base_rank = false
	_rank_gate_rank = rank_number
	presentation_id = StringName("__rank_gate_%d%s" % [
		rank_number,
		"_%s" % gate_suffix if gate_suffix != &"" else "",
	])
	visual_presentation = {
		"state": SkillTreeVisualPresentation.SkillTreeVisualState.FUTURE,
		"required_xp": 0,
	}
	skin = wanted_skin
	node_visual = null
	_character_id = character_id
	reveal_mode = RevealMode.RANK_GATE
	if not is_node_ready():
		await ready
	var config := _config()
	_name_label.text = (
		config.hidden_rank_label_format % rank_number
		if config != null
		else "RANG %d VERROUILLÉ" % rank_number
	)
	_rank_label.text = "R%d" % rank_number
	_threshold_label.text = "PROGRESSEZ POUR RÉVÉLER"
	_configure_skin(rank_number)
	apply_layout_profile(_layout_profile)
	_configure_glyphs()
	_apply_visual_state()
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	tooltip_text = ""


func refresh_presentation(presentation: Dictionary) -> void:
	visual_presentation = presentation.duplicate(true)
	if is_node_ready():
		_apply_visual_state()


func set_inspection_selected(value: bool) -> void:
	_inspection_selected = value
	if is_node_ready():
		_refresh_inspection_frame()


func get_presentation_id() -> StringName:
	return presentation_id


func get_rank() -> int:
	if reveal_mode == RevealMode.RANK_GATE:
		return _rank_gate_rank
	return 1 if is_base_rank or node_data == null else node_data.rank


func get_reveal_mode() -> RevealMode:
	return reveal_mode


func is_content_revealed() -> bool:
	return reveal_mode == RevealMode.FULL


func is_rank_gate() -> bool:
	return reveal_mode == RevealMode.RANK_GATE


func get_display_name() -> String:
	return _name_label.text


func get_requirement_text() -> String:
	return _requirement_label.text


func get_frame_texture() -> Texture2D:
	return null


func get_primary_glyph_id() -> StringName:
	return _primary_glyph.glyph_id


func get_secondary_glyph_id() -> StringName:
	return _secondary_glyph.glyph_id if _secondary_glyph.visible else &""


func get_state_icon_id() -> StringName:
	return _state_icon.glyph_id if _state_icon.visible else &""


func get_rank_badge_text() -> String:
	return _rank_label.text


func apply_layout_profile(profile: StringName) -> void:
	_layout_profile = profile
	if not is_node_ready():
		return
	var rank := get_rank()
	var kind := _node_kind(rank)
	var config := _config()
	_visual_frame_size = (
		config.get_node_size(profile, kind)
		if config != null
		else _fallback_frame_size(profile, kind)
	)
	var control_width := _visual_frame_size + (38.0 if kind == &"capstone" else 28.0)
	var title_height := 42.0 if profile == PROFILE_LARGE else 39.0 if profile == PROFILE_MEDIUM else 36.0
	var control_height := _visual_frame_size + title_height + 46.0
	var control_size := Vector2(control_width, control_height)
	custom_minimum_size = control_size
	size = control_size
	var frame_rect := Rect2(
		Vector2((control_size.x - _visual_frame_size) * 0.5, 0.0),
		Vector2.ONE * _visual_frame_size
	)
	var halo_padding := 6.0 if kind == &"capstone" or kind == &"specialization" else 0.0
	_set_control_rect(_capstone_halo, frame_rect.grow(halo_padding).position, frame_rect.grow(halo_padding).size)
	_set_control_rect(_state_backdrop, frame_rect.position, frame_rect.size)
	_set_control_rect(_frame_texture, frame_rect.position, frame_rect.size)
	_set_control_rect(_focus_overlay, frame_rect.grow(3.0).position, frame_rect.grow(3.0).size)
	_set_control_rect(_lock_overlay, frame_rect.position, frame_rect.size)
	_set_control_rect(_darkening_layer, Vector2.ZERO, frame_rect.size)
	var discipline_size := 22.0 if profile == PROFILE_LARGE else 20.0 if profile == PROFILE_MEDIUM else 18.0
	_set_control_rect(_discipline_icon, frame_rect.position + Vector2(7.0, 7.0), Vector2.ONE * discipline_size)
	var major := kind in [&"root", &"specialization", &"capstone"]
	var icon_size := (
		config.get_icon_size(profile, major)
		if config != null
		else _visual_frame_size * (0.58 if major else 0.54)
	)
	var icon_position := frame_rect.position + (frame_rect.size - Vector2.ONE * icon_size) * 0.5
	_set_control_rect(_icon_override, icon_position, Vector2.ONE * icon_size)
	_set_control_rect(_primary_glyph, icon_position, Vector2.ONE * icon_size)
	var secondary_size := 20.0 if profile == PROFILE_LARGE else 18.0
	_set_control_rect(
		_secondary_glyph,
		Vector2(frame_rect.end.x - secondary_size - 7.0, frame_rect.end.y - secondary_size - 7.0),
		Vector2.ONE * secondary_size
	)
	var state_size := 21.0 if profile == PROFILE_LARGE else 19.0
	_set_control_rect(
		_state_icon,
		Vector2(frame_rect.end.x - state_size - 6.0, frame_rect.position.y + 6.0),
		Vector2.ONE * state_size
	)
	var badge_size := config.get_badge_size(profile) if config != null else Vector2.ONE * 34.0
	var badge_position := Vector2(frame_rect.position.x + 5.0, frame_rect.end.y - badge_size.y - 5.0)
	_set_control_rect(_rank_badge_fallback, badge_position, badge_size)
	_set_control_rect(_rank_label, badge_position, badge_size)
	var lock_size := config.get_lock_icon_size(profile) if config != null else 28.0
	_set_control_rect(
		_lock_icon,
		(frame_rect.size - Vector2.ONE * lock_size) * 0.5 + Vector2(0.0, -8.0),
		Vector2.ONE * lock_size
	)
	_set_control_rect(
		_requirement_label,
		Vector2(4.0, frame_rect.size.y - 29.0),
		Vector2(frame_rect.size.x - 8.0, 25.0)
	)
	var title_top := frame_rect.end.y + 2.0
	_set_control_rect(_name_label, Vector2(0.0, title_top), Vector2(control_size.x, title_height))
	_set_control_rect(_threshold_label, Vector2(0.0, title_top + title_height + 2.0), Vector2(control_size.x, 18.0))
	_set_control_rect(_state_text, Vector2(0.0, title_top + title_height + 23.0), Vector2(control_size.x, 18.0))
	_name_label.add_theme_font_size_override("font_size", 14 if profile == PROFILE_COMPACT else 15 if profile == PROFILE_MEDIUM else 16)
	_rank_label.add_theme_font_size_override("font_size", 10 if profile == PROFILE_COMPACT else 11)
	_threshold_label.add_theme_font_size_override("font_size", 9 if profile == PROFILE_COMPACT else 10)
	_state_text.add_theme_font_size_override("font_size", 9 if profile == PROFILE_COMPACT else 10)
	_requirement_label.add_theme_font_size_override("font_size", 8 if profile == PROFILE_COMPACT else 9)
	_apply_surface_style()


func get_layout_profile() -> StringName:
	return _layout_profile


func get_visual_frame_size() -> Vector2:
	return Vector2.ONE * _visual_frame_size


func get_visual_frame_rect() -> Rect2:
	return _state_backdrop.get_rect()


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


func is_inspection_selected() -> bool:
	return _inspection_selected


func get_connection_anchor(side: StringName) -> Vector2:
	var frame_rect := _state_backdrop.get_rect()
	var frame_center := frame_rect.position + frame_rect.size * 0.5
	return Vector2(frame_rect.end.x, frame_center.y) if side == &"right" else Vector2(frame_rect.position.x, frame_center.y)


func is_consultative() -> bool:
	return true


func _set_control_rect(control: Control, wanted_position: Vector2, wanted_size: Vector2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = wanted_position
	control.size = wanted_size


func _configure_skin(rank: int) -> void:
	_frame_texture.texture = null
	_frame_texture.hide()
	_rank_badge_texture.texture = null
	_rank_badge_texture.hide()
	_rank_badge_fallback.show()
	_capstone_halo.visible = _node_kind(rank) in [&"specialization", &"capstone"]


func _configure_glyphs(legacy_icon: Texture2D = null) -> void:
	var catalog := _catalog()
	var discipline_id := discipline_data.discipline_id if discipline_data != null else &""
	var branch_icon := catalog.get_branch_badge(_character_id, discipline_id) if catalog != null else null
	_discipline_icon.configure(StringName("%s:%s" % [_character_id, discipline_id]), branch_icon)
	var icon: Texture2D = null
	var icon_id := &"upgrade"
	if reveal_mode == RevealMode.RANK_GATE:
		icon = catalog.hidden_icon if catalog != null else null
		icon_id = &"hidden"
	elif is_base_rank:
		icon = catalog.get_root_icon(_character_id, discipline_id) if catalog != null else legacy_icon
		icon_id = &"root"
	elif node_data != null:
		icon_id = node_data.upgrade_id
		if catalog != null:
			var config := _config()
			if (
				reveal_mode == RevealMode.NEXT_RANK
				and config != null
				and not config.show_next_rank_icons
			):
				icon = catalog.hidden_icon
				icon_id = &"hidden"
			else:
				var kind := _node_kind(node_data.rank)
				if kind == &"capstone":
					icon = catalog.get_capstone_icon(node_data.upgrade_id)
				elif kind == &"specialization":
					icon = catalog.get_specialization_icon(node_data.upgrade_id)
				else:
					icon = catalog.get_node_icon(
						node_data.upgrade_id,
						_semantic_category()
					)
	if icon == null:
		icon = legacy_icon
	_icon_override.texture = icon
	_icon_override.visible = icon != null
	_primary_glyph.visible = icon == null
	if _primary_glyph.visible:
		_primary_glyph.configure(icon_id)
	_secondary_glyph.hide()


func _apply_visual_state() -> void:
	if reveal_mode == RevealMode.NEXT_RANK:
		_apply_locked_reveal()
		return
	if reveal_mode == RevealMode.RANK_GATE:
		_apply_rank_gate()
		return
	var state: SkillTreeVisualPresentation.SkillTreeVisualState = int(visual_presentation.get(
		"state", SkillTreeVisualPresentation.SkillTreeVisualState.FUTURE
	))
	_lock_overlay.hide()
	_state_icon.show()
	_state_icon.configure(_state_glyph_id(state), _state_texture(state))
	_state_text.text = _short_state_label(state)
	tooltip_text = ""
	match state:
		SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED:
			self_modulate = Color.WHITE
			_set_state_colors(Color(0.64, 0.84, 0.72), Color(0.64, 0.84, 0.72))
		SkillTreeVisualPresentation.SkillTreeVisualState.AVAILABLE:
			self_modulate = Color.WHITE
			_set_state_colors(Color(0.82, 0.68, 0.42), Color(0.88, 0.72, 0.42))
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_BRANCH:
			self_modulate = Color(0.66, 0.66, 0.68, 1.0)
			_set_state_colors(Color(0.56, 0.48, 0.48), Color(0.72, 0.48, 0.48))
		_:
			self_modulate = Color(0.76, 0.78, 0.8, 1.0)
			_set_state_colors(Color(0.42, 0.47, 0.52), Color(0.64, 0.68, 0.72))
	_apply_surface_style()
	_refresh_inspection_frame()


func _apply_locked_reveal() -> void:
	var rank := get_rank()
	var config := _config()
	_lock_overlay.show()
	_darkening_layer.color = Color(0.015, 0.02, 0.025, 0.68)
	_lock_icon.texture = config.lock_icon_texture if config != null else null
	_requirement_label.text = (
		config.locked_rank_label_format % rank
		if config != null
		else "RANG %d REQUIS" % rank
	)
	_state_icon.hide()
	_threshold_label.text = ""
	_state_text.text = "À DÉCOUVRIR"
	_rank_badge_fallback.hide()
	_rank_label.hide()
	var opacity := config.locked_node_opacity if config != null else 0.42
	_icon_override.modulate = Color(0.72, 0.75, 0.78, maxf(opacity, 0.32))
	_primary_glyph.modulate = _icon_override.modulate
	_name_label.add_theme_color_override("font_color", Color(0.66, 0.68, 0.7))
	_threshold_label.add_theme_color_override("font_color", Color(0.5, 0.53, 0.56))
	tooltip_text = "Compétence verrouillée — Rang %d requis" % rank
	_apply_surface_style()
	_refresh_inspection_frame()


func _apply_rank_gate() -> void:
	var config := _config()
	_lock_overlay.show()
	_darkening_layer.color = Color(0.012, 0.016, 0.02, 0.76)
	_lock_icon.texture = config.lock_icon_texture if config != null else null
	_requirement_label.text = "INCONNU"
	_state_icon.hide()
	_threshold_label.text = ""
	_state_text.text = "CONTENU MASQUÉ"
	_rank_badge_fallback.hide()
	_rank_label.hide()
	var opacity := config.hidden_node_opacity if config != null else 0.22
	_icon_override.modulate = Color(0.66, 0.68, 0.7, opacity)
	_primary_glyph.modulate = _icon_override.modulate
	_discipline_icon.hide()
	_name_label.add_theme_color_override("font_color", Color(0.48, 0.51, 0.54))
	_threshold_label.add_theme_color_override("font_color", Color(0.4, 0.43, 0.46))
	_apply_surface_style()
	_refresh_inspection_frame()


func _apply_surface_style() -> void:
	if not is_node_ready():
		return
	var style := StyleBoxFlat.new()
	var accent := discipline_data.presentation_color if discipline_data != null else Color(0.65, 0.52, 0.34)
	style.bg_color = Color(0.055, 0.065, 0.076, 0.98)
	style.border_color = accent.darkened(0.1)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	if reveal_mode == RevealMode.RANK_GATE:
		style.bg_color = Color(0.035, 0.041, 0.049, 0.98)
		style.border_color = Color(0.28, 0.31, 0.34, 0.9)
		style.set_border_width_all(1)
	elif reveal_mode == RevealMode.NEXT_RANK:
		style.bg_color = Color(0.045, 0.052, 0.061, 0.98)
		style.border_color = Color(0.38, 0.4, 0.42, 0.95)
	elif int(visual_presentation.get("state", -1)) == SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED:
		style.bg_color = Color(0.07, 0.09, 0.095, 0.98)
		style.border_color = accent.lightened(0.2)
		style.set_border_width_all(2)
	elif int(visual_presentation.get("state", -1)) == SkillTreeVisualPresentation.SkillTreeVisualState.AVAILABLE:
		style.border_color = Color(0.82, 0.68, 0.42, 0.98)
		style.set_border_width_all(2)
	_state_backdrop.add_theme_stylebox_override("panel", style)
	var halo := StyleBoxFlat.new()
	halo.bg_color = Color(0, 0, 0, 0)
	halo.border_color = accent.darkened(0.05)
	halo.set_border_width_all(1)
	halo.corner_radius_top_left = 10
	halo.corner_radius_top_right = 10
	halo.corner_radius_bottom_left = 10
	halo.corner_radius_bottom_right = 10
	_capstone_halo.add_theme_stylebox_override("panel", halo)


func _set_state_colors(border: Color, text_color: Color) -> void:
	_state_text.add_theme_color_override("font_color", text_color)
	_name_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
	_threshold_label.add_theme_color_override("font_color", Color(0.58, 0.62, 0.66))


func _refresh_inspection_frame() -> void:
	_focus_overlay.visible = (
		reveal_mode != RevealMode.RANK_GATE
		and (_inspection_selected or has_focus())
	)


func _short_state_label(state: SkillTreeVisualPresentation.SkillTreeVisualState) -> String:
	match state:
		SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED:
			return "ACQUIS"
		SkillTreeVisualPresentation.SkillTreeVisualState.AVAILABLE:
			return "DISPONIBLE"
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_XP:
			return "XP REQUISE"
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_BRANCH:
			return "EXCLU"
	return "VERROUILLÉ"


func _state_glyph_id(state: SkillTreeVisualPresentation.SkillTreeVisualState) -> StringName:
	match state:
		SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED:
			return &"selected"
		SkillTreeVisualPresentation.SkillTreeVisualState.AVAILABLE:
			return &"pending"
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_BRANCH:
			return &"excluded"
	return &"locked"


func _state_texture(state: SkillTreeVisualPresentation.SkillTreeVisualState) -> Texture2D:
	var catalog := _catalog()
	return catalog.get_state_icon(_state_glyph_id(state)) if catalog != null else null


func _node_kind(rank: int) -> StringName:
	if reveal_mode == RevealMode.RANK_GATE:
		return &"rank_gate"
	if is_base_rank or rank <= 1:
		return &"root"
	if rank == 2:
		return &"specialization"
	if rank >= 5:
		return &"capstone"
	return &"standard"


func _semantic_category() -> StringName:
	if node_visual != null and node_visual.primary_glyph_id != &"":
		return node_visual.primary_glyph_id
	return &"upgrade"


func _fallback_frame_size(profile: StringName, kind: StringName) -> float:
	var base := 82.0 if profile == PROFILE_LARGE else 78.0 if profile == PROFILE_MEDIUM else 76.0
	if kind == &"root" or kind == &"specialization":
		return base + 10.0
	if kind == &"capstone":
		return base + 26.0
	if kind == &"rank_gate":
		return base + 6.0
	return base


func _config() -> SkillTreeRefinedConfig:
	return skin.refined_config if skin != null else null


func _catalog() -> SkillTreeIconCatalog:
	return skin.icon_catalog if skin != null else null


func _request_inspection() -> void:
	if reveal_mode != RevealMode.RANK_GATE:
		inspection_requested.emit(self)


func _on_focus_entered() -> void:
	_refresh_inspection_frame()
	_request_inspection()


func _on_focus_exited() -> void:
	_refresh_inspection_frame()


func _on_gui_input(event: InputEvent) -> void:
	if reveal_mode == RevealMode.RANK_GATE:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		_request_inspection()
