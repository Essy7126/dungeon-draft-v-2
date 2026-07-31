class_name SkillTreeNodeDetailPanel
extends PanelContainer

@export var skin: SkillTreeSkinData = null

@onready var _frame_texture: NinePatchRect = %FrameTexture
@onready var _safe_margin: MarginContainer = %SafeMargin
@onready var _content: VBoxContainer = %Content
@onready var _icon_stage: Control = %IconStage
@onready var _icon_override: TextureRect = %IconOverride
@onready var _discipline_icon: SkillTreeEffectGlyph = %DisciplineIcon
@onready var _primary_glyph: SkillTreeEffectGlyph = %PrimaryGlyph
@onready var _name_label: Label = %NameLabel
@onready var _meta_label: Label = %MetaLabel
@onready var _xp_label: Label = %XPLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _spell_heading: Label = %SpellHeading
@onready var _spell_label: Label = %SpellLabel
@onready var _prerequisites_label: Label = %PrerequisitesLabel
@onready var _incompatibilities_heading: Label = %IncompatibilitiesHeading
@onready var _incompatibilities_label: Label = %IncompatibilitiesLabel
@onready var _state_label: Label = %StateLabel
@onready var _reason_label: Label = %ReasonLabel
@onready var _action_button: Button = %ActionButton
@onready var _scroll: ScrollContainer = %ContentScroll
@onready var _section_headings: Array[Label] = [
	%DescriptionHeading,
	%SpellHeading,
	%PrerequisitesHeading,
	%IncompatibilitiesHeading,
	%StateHeading,
	%ReasonHeading,
]

var current_presentation_id: StringName = &""
var _layout_profile: StringName = &"large"
var _accent := Color(0.76, 0.58, 0.28, 1.0)


func _ready() -> void:
	_frame_texture.texture = skin.detail_panel_texture if skin != null else null
	_action_button.disabled = true
	apply_layout_profile(_layout_profile)
	set_accent(_accent)


func apply_layout_profile(profile: StringName) -> void:
	_layout_profile = profile
	if not is_node_ready():
		return
	var compact := profile == &"compact"
	var medium := profile == &"medium"
	var title_font := 19 if compact else 21 if medium else 23
	var subtitle_font := 13 if compact else 14 if medium else 15
	var description_font := 13 if compact else 14 if medium else 15
	var heading_font := 10 if compact else 11 if medium else 12
	var value_font := 12 if compact else 13 if medium else 14
	var horizontal_margin := 22 if compact else 28 if medium else 34
	var vertical_margin := 20 if compact else 24 if medium else 28
	_safe_margin.add_theme_constant_override("margin_left", horizontal_margin)
	_safe_margin.add_theme_constant_override("margin_right", horizontal_margin)
	_safe_margin.add_theme_constant_override("margin_top", vertical_margin)
	_safe_margin.add_theme_constant_override("margin_bottom", vertical_margin)
	_content.add_theme_constant_override(
		"separation", 5 if compact else 6 if medium else 7
	)
	_icon_stage.custom_minimum_size.y = (
		58.0 if compact else 66.0 if medium else 74.0
	)
	_name_label.add_theme_font_size_override("font_size", title_font)
	_meta_label.add_theme_font_size_override("font_size", subtitle_font)
	_xp_label.add_theme_font_size_override("font_size", value_font)
	_description_label.add_theme_font_size_override("font_size", description_font)
	_description_label.custom_minimum_size.y = (
		64.0 if compact else 76.0 if medium else 88.0
	)
	for heading in _section_headings:
		heading.add_theme_font_size_override("font_size", heading_font)
	for value_label in [
		_spell_label,
		_prerequisites_label,
		_incompatibilities_label,
		_state_label,
		_reason_label,
	]:
		(value_label as Label).add_theme_font_size_override(
			"font_size", value_font
		)
	_reason_label.custom_minimum_size.y = (
		38.0 if compact else 44.0 if medium else 50.0
	)
	_action_button.custom_minimum_size.y = (
		36.0 if compact else 40.0 if medium else 44.0
	)
	_action_button.add_theme_font_size_override(
		"font_size", 12 if compact else 13 if medium else 14
	)


func get_layout_profile() -> StringName:
	return _layout_profile


func get_typography_snapshot() -> Dictionary:
	return {
		"title": _name_label.get_theme_font_size("font_size"),
		"subtitle": _meta_label.get_theme_font_size("font_size"),
		"description": _description_label.get_theme_font_size("font_size"),
		"section": (
			_section_headings[0].get_theme_font_size("font_size")
			if not _section_headings.is_empty()
			else 0
		),
		"value": _spell_label.get_theme_font_size("font_size"),
	}


func get_section_labels() -> Array[String]:
	var result: Array[String] = []
	for heading in _section_headings:
		result.append(heading.text)
	return result


func configure_node(
		discipline: DisciplineData,
		node: SkillUpgradeData,
		presentation: Dictionary,
		node_names: Dictionary,
		spell_name: String,
		node_visual: SkillTreeNodeVisualData = null
	) -> void:
	if node == null:
		set_empty()
		return
	current_presentation_id = node.upgrade_id
	_name_label.text = node.display_name.to_upper()
	var max_rank := _maximum_rank(discipline)
	_meta_label.text = "%s · Rang %d%s" % [
		discipline.display_name if discipline != null else "Discipline",
		node.rank,
		" · SPÉCIALISATION FINALE"
		if max_rank >= 5 and node.rank == max_rank
		else "",
	]
	_xp_label.text = "%d / %d XP" % [
		int(presentation.get("xp", 0)),
		int(presentation.get("required_xp", 0)),
	]
	_description_label.text = node.description
	var has_spell_name := not spell_name.is_empty()
	_spell_heading.visible = has_spell_name
	_spell_label.visible = has_spell_name
	_spell_label.text = spell_name
	_prerequisites_label.text = _prerequisite_text(node, node_names)
	var state: SkillTreeVisualPresentation.SkillTreeVisualState = int(
		presentation.get(
			"state",
			SkillTreeVisualPresentation.SkillTreeVisualState.FUTURE
		)
	)
	_state_label.text = SkillTreeVisualPresentation.state_label(state)
	_reason_label.text = str(presentation.get("reason", ""))
	var is_incompatible := (
		state
		== SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_BRANCH
	)
	_incompatibilities_heading.visible = is_incompatible
	_incompatibilities_label.visible = is_incompatible
	_incompatibilities_label.text = (
		str(presentation.get("reason", "")) if is_incompatible else ""
	)
	_configure_action(state)
	_configure_icon(discipline, node.icon, node_visual)
	_scroll.scroll_vertical = 0


func configure_base(
		discipline: DisciplineData,
		display_name: String,
		description: String,
		presentation: Dictionary,
		node_visual: SkillTreeNodeVisualData = null,
		base_icon: Texture2D = null
	) -> void:
	current_presentation_id = &"__base_rank_1"
	_name_label.text = display_name.to_upper()
	_meta_label.text = "%s · Rang 1 · ARCHÉTYPE INITIAL" % (
		discipline.display_name if discipline != null else "Discipline"
	)
	_xp_label.text = "%d XP · acquis" % int(presentation.get("xp", 0))
	_description_label.text = description
	_spell_heading.show()
	_spell_label.show()
	_spell_label.text = display_name
	_prerequisites_label.text = "Aucun"
	_state_label.text = "Acquis"
	_reason_label.text = "Compétence de base de la discipline."
	_incompatibilities_heading.hide()
	_incompatibilities_label.hide()
	_incompatibilities_label.text = ""
	_configure_action(
		SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED
	)
	_configure_icon(discipline, base_icon, node_visual)
	_scroll.scroll_vertical = 0


func set_empty() -> void:
	current_presentation_id = &""
	_name_label.text = "DÉTAIL DU NODE"
	_meta_label.text = ""
	_xp_label.text = ""
	_description_label.text = (
		"Survolez un node ou placez-y le focus pour consulter ses détails."
	)
	_spell_heading.hide()
	_spell_label.hide()
	_spell_label.text = ""
	_prerequisites_label.text = "—"
	_state_label.text = "—"
	_reason_label.text = "—"
	_incompatibilities_heading.hide()
	_incompatibilities_label.hide()
	_incompatibilities_label.text = ""
	_action_button.text = "SÉLECTIONNEZ UN NODE"
	_action_button.disabled = true
	_icon_override.hide()
	_primary_glyph.configure(&"generic")
	_primary_glyph.show()
	_discipline_icon.configure(&"generic")


func set_progression_undefined(character_name: String) -> void:
	current_presentation_id = &""
	_name_label.text = "PROGRESSION NON DÉFINIE"
	_meta_label.text = character_name.to_upper()
	_xp_label.text = ""
	_description_label.text = (
		"Aucune branche de progression n’est définie dans les données de ce personnage."
	)
	_spell_heading.hide()
	_spell_label.hide()
	_spell_label.text = ""
	_prerequisites_label.text = "—"
	_state_label.text = "Indisponible"
	_reason_label.text = "Aucun node ni rang fictif n’est affiché."
	_incompatibilities_heading.hide()
	_incompatibilities_label.hide()
	_incompatibilities_label.text = ""
	_action_button.text = "INDISPONIBLE"
	_action_button.disabled = true
	_icon_override.hide()
	_primary_glyph.configure(&"future")
	_primary_glyph.show()
	_discipline_icon.configure(&"future")


func set_accent(accent: Color) -> void:
	_accent = accent
	if is_node_ready():
		_name_label.add_theme_color_override(
			"font_color", _accent.lightened(0.26)
		)
		_state_label.add_theme_color_override(
			"font_color", _accent.lightened(0.24)
		)


func get_detail_text() -> String:
	return "\n".join([
		_name_label.text,
		_meta_label.text,
		_xp_label.text,
		_description_label.text,
		_spell_label.text,
		_prerequisites_label.text,
		_incompatibilities_label.text,
		_state_label.text,
		_reason_label.text,
		_action_button.text,
	])


func get_scroll_container() -> ScrollContainer:
	return _scroll


func get_frame_texture() -> Texture2D:
	return _frame_texture.texture


func get_action_button() -> Button:
	return _action_button


func _prerequisite_text(
		node: SkillUpgradeData,
		node_names: Dictionary
	) -> String:
	if not node is SkillTreeNodeData:
		return "Aucun"
	var prerequisite_names: Array[String] = []
	for prerequisite_id in (node as SkillTreeNodeData).prerequisite_node_ids:
		var player_name := str(node_names.get(prerequisite_id, ""))
		if not player_name.is_empty():
			prerequisite_names.append(player_name)
	return "Aucun" if prerequisite_names.is_empty() else "\n".join(prerequisite_names)


func _configure_icon(
		discipline: DisciplineData,
		legacy_icon: Texture2D,
		node_visual: SkillTreeNodeVisualData
	) -> void:
	var discipline_icon_id := (
		node_visual.discipline_icon_id
		if node_visual != null and node_visual.discipline_icon_id != &""
		else StringName("elf_%s" % (
			discipline.discipline_id if discipline != null else &"archer"
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
	_primary_glyph.visible = override == null
	if _primary_glyph.visible:
		var glyph_id := (
			node_visual.primary_glyph_id
			if node_visual != null and node_visual.primary_glyph_id != &""
			else discipline_icon_id
		)
		_primary_glyph.configure_effect(glyph_id, skin)


func _configure_action(
		state: SkillTreeVisualPresentation.SkillTreeVisualState
	) -> void:
	_action_button.disabled = true
	match state:
		SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED:
			_action_button.text = "ACQUIS"
		SkillTreeVisualPresentation.SkillTreeVisualState.AVAILABLE:
			_action_button.text = "CHOISIR APRÈS LE COMBAT"
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_XP:
			_action_button.text = "XP INSUFFISANTE"
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_BRANCH:
			_action_button.text = "CHOIX EXCLU"
		SkillTreeVisualPresentation.SkillTreeVisualState.FUTURE:
			_action_button.text = "VERROUILLÉ"


func _maximum_rank(discipline: DisciplineData) -> int:
	var result := 1
	if discipline == null:
		return result
	for rank_data in discipline.ranks:
		if rank_data != null:
			result = maxi(result, rank_data.rank)
	return result
