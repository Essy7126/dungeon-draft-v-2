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
@onready var _spell_label: Label = %SpellLabel
@onready var _prerequisites_label: Label = %PrerequisitesLabel
@onready var _state_label: Label = %StateLabel
@onready var _reason_label: Label = %ReasonLabel
@onready var _scroll: ScrollContainer = %ContentScroll
@onready var _section_headings: Array[Label] = [
	%DescriptionHeading,
	%SpellHeading,
	%PrerequisitesHeading,
	%StateHeading,
	%ReasonHeading,
]

var current_presentation_id: StringName = &""
var _layout_profile: StringName = &"large"


func _ready() -> void:
	_frame_texture.texture = skin.detail_panel_texture if skin != null else null
	apply_layout_profile(_layout_profile)


func apply_layout_profile(profile: StringName) -> void:
	_layout_profile = profile
	if not is_node_ready():
		return
	var compact := profile == &"compact"
	var medium := profile == &"medium"
	var title_font := 20 if compact else 22 if medium else 24
	var subtitle_font := 14 if compact else 15 if medium else 16
	var description_font := 14 if compact else 15 if medium else 16
	var heading_font := 12 if compact else 12 if medium else 13
	var value_font := 13 if compact else 14 if medium else 15
	var horizontal_margin := 28 if compact else 34 if medium else 40
	var vertical_margin := 24 if compact else 30 if medium else 36
	_safe_margin.add_theme_constant_override(
		"margin_left",
		horizontal_margin
	)
	_safe_margin.add_theme_constant_override(
		"margin_right",
		horizontal_margin
	)
	_safe_margin.add_theme_constant_override(
		"margin_top",
		vertical_margin
	)
	_safe_margin.add_theme_constant_override(
		"margin_bottom",
		vertical_margin
	)
	_content.add_theme_constant_override(
		"separation",
		6 if compact else 7 if medium else 8
	)
	_icon_stage.custom_minimum_size.y = (
		68.0 if compact else 78.0 if medium else 88.0
	)
	_name_label.add_theme_font_size_override("font_size", title_font)
	_meta_label.add_theme_font_size_override("font_size", subtitle_font)
	_xp_label.add_theme_font_size_override("font_size", value_font)
	_description_label.add_theme_font_size_override(
		"font_size",
		description_font
	)
	_description_label.custom_minimum_size.y = (
		78.0 if compact else 92.0 if medium else 108.0
	)
	for heading in _section_headings:
		heading.add_theme_font_size_override("font_size", heading_font)
	for value_label in [
		_spell_label,
		_prerequisites_label,
		_state_label,
		_reason_label,
	]:
		(value_label as Label).add_theme_font_size_override(
			"font_size",
			value_font
		)
	_reason_label.custom_minimum_size.y = (
		44.0 if compact else 50.0 if medium else 58.0
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
	_meta_label.text = "%s — Rang %d" % [
		discipline.display_name if discipline != null else "Discipline",
		node.rank,
	]
	_xp_label.text = "%d XP requis" % int(
		presentation.get("required_xp", 0)
	)
	_description_label.text = node.description
	_spell_label.text = (
		spell_name if not spell_name.is_empty() else "Sort de la discipline"
	)
	_prerequisites_label.text = _prerequisite_text(node, node_names)
	var state: SkillTreeVisualPresentation.SkillTreeVisualState = int(
		presentation.get(
			"state",
			SkillTreeVisualPresentation.SkillTreeVisualState.FUTURE
		)
	)
	_state_label.text = SkillTreeVisualPresentation.state_label(state)
	_reason_label.text = str(presentation.get("reason", ""))
	_configure_icon(
		discipline,
		node.icon,
		node_visual
	)
	_scroll.scroll_vertical = 0


func configure_base(
		discipline: DisciplineData,
		display_name: String,
		description: String,
		presentation: Dictionary,
		node_visual: SkillTreeNodeVisualData = null
	) -> void:
	current_presentation_id = &"__base_rank_1"
	_name_label.text = display_name.to_upper()
	_meta_label.text = "%s — Rang 1" % (
		discipline.display_name if discipline != null else "Discipline"
	)
	_xp_label.text = "%d XP requis" % int(
		presentation.get("required_xp", 0)
	)
	_description_label.text = description
	_spell_label.text = display_name
	_prerequisites_label.text = "Aucun"
	_state_label.text = "Sélectionné"
	_reason_label.text = "Compétence de base de la discipline."
	_configure_icon(discipline, null, node_visual)
	_scroll.scroll_vertical = 0


func set_empty() -> void:
	current_presentation_id = &""
	_name_label.text = "DÉTAIL DU NŒUD"
	_meta_label.text = ""
	_xp_label.text = ""
	_description_label.text = (
		"Survolez un nœud ou placez-y le focus pour consulter ses détails."
	)
	_spell_label.text = "—"
	_prerequisites_label.text = "—"
	_state_label.text = "—"
	_reason_label.text = "—"
	_icon_override.hide()
	_primary_glyph.configure(&"generic")
	_primary_glyph.show()
	_discipline_icon.configure(&"generic")


func get_detail_text() -> String:
	return "\n".join([
		_name_label.text,
		_meta_label.text,
		_xp_label.text,
		_description_label.text,
		_spell_label.text,
		_prerequisites_label.text,
		_state_label.text,
		_reason_label.text,
	])


func get_scroll_container() -> ScrollContainer:
	return _scroll


func get_frame_texture() -> Texture2D:
	return _frame_texture.texture


func _prerequisite_text(
		node: SkillUpgradeData,
		node_names: Dictionary
	) -> String:
	if not node is SkillTreeNodeData:
		return "Aucun"
	var prerequisite_names: Array[String] = []
	for prerequisite_id in (
		node as SkillTreeNodeData
	).prerequisite_node_ids:
		var player_name := str(node_names.get(prerequisite_id, ""))
		if not player_name.is_empty():
			prerequisite_names.append(player_name)
	return (
		"Aucun"
		if prerequisite_names.is_empty()
		else "\n".join(prerequisite_names)
	)


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
