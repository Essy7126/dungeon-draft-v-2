class_name SkillTreeNodeDetailPanel
extends PanelContainer

@export var skin: SkillTreeSkinData = null

const CODEX_STYLE := preload("res://ui/progression/theme/spell_codex_style.gd")
const DETAIL_TEXT := Color("f2e6d3")
const DETAIL_MUTED := Color("b9ad9c")
const DETAIL_GOLD := Color("d1ae7b")
const DETAIL_LINE := Color("665344")
const DETAIL_BODY := preload("res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf")
const DETAIL_BOLD := preload("res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Bold.otf")
const DETAIL_HEADING := CODEX_STYLE.DISPLAY

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
var _spell_context: Spell = null
var _metrics: VBoxContainer
var _metrics_note: Label
var _cost_value: Label
var _range_value: Label
var _zone_value: Label
var _effect_value: Label
var _casting_value: Label
var _metric_captions: Array[Label] = []


func _ready() -> void:
	_frame_texture.texture = skin.detail_panel_texture if skin != null else null
	_action_button.disabled = true
	_build_spell_metrics()
	_apply_detail_style()
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
	var horizontal_margin := 15 if compact else 18 if medium else 22
	var vertical_margin := 16 if compact else 20 if medium else 24
	_safe_margin.add_theme_constant_override("margin_left", horizontal_margin)
	_safe_margin.add_theme_constant_override("margin_right", horizontal_margin)
	_safe_margin.add_theme_constant_override("margin_top", vertical_margin)
	_safe_margin.add_theme_constant_override("margin_bottom", vertical_margin)
	_content.add_theme_constant_override(
		"separation", 5 if compact else 6 if medium else 7
	)
	_icon_stage.custom_minimum_size.y = (
		100.0 if compact else 108.0 if medium else 116.0
	)
	_name_label.add_theme_font_size_override("font_size", title_font)
	_meta_label.add_theme_font_size_override("font_size", subtitle_font)
	_xp_label.add_theme_font_size_override("font_size", value_font)
	_description_label.add_theme_font_size_override("font_size", description_font)
	_description_label.custom_minimum_size.y = 0.0
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
	_reason_label.custom_minimum_size.y = 0.0
	_action_button.custom_minimum_size.y = (
		40.0 if compact else 42.0 if medium else 46.0
	)
	_action_button.add_theme_font_size_override(
		"font_size", 12 if compact else 13 if medium else 14
	)

	for caption in _metric_captions:
		caption.add_theme_font_size_override("font_size", 10 if compact else 11)
	for metric in [_cost_value, _range_value]:
		(metric as Label).add_theme_font_size_override("font_size", 19 if compact else 22)
	_zone_value.add_theme_font_size_override("font_size", 12 if compact else 14)
	_effect_value.add_theme_font_size_override("font_size", value_font)
	_casting_value.add_theme_font_size_override("font_size", value_font)
	_metrics_note.add_theme_font_size_override("font_size", 10 if compact else 11)
	var art_size := 90.0 if compact else 98.0 if medium else 104.0
	for art in [_icon_override, _primary_glyph]:
		(art as Control).offset_left = -art_size * 0.5
		(art as Control).offset_top = -art_size * 0.5
		(art as Control).offset_right = art_size * 0.5
		(art as Control).offset_bottom = art_size * 0.5


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
	_name_label.text = node.display_name
	var max_rank := _maximum_rank(discipline)
	_meta_label.text = "%s · Rang %d%s" % [
		discipline.display_name if discipline != null else "Discipline",
		node.rank,
		" · Ultime évolution"
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
	_configure_icon(discipline, node.get_card_texture(), node_visual)
	_set_supporting_sections(false)
	_refresh_spell_metrics()
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
	_name_label.text = display_name
	_meta_label.text = "%s · Sort initial" % (
		discipline.display_name if discipline != null else "Discipline"
	)
	_xp_label.text = "%d XP" % int(presentation.get("xp", 0))
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
	_set_supporting_sections(true)
	_reason_label.hide()
	_refresh_spell_metrics()
	_scroll.scroll_vertical = 0


func configure_locked(
		discipline: DisciplineData,
		rank_number: int,
		character_id: StringName = &"elf"
	) -> void:
	current_presentation_id = StringName("__locked_rank_%d" % rank_number)
	_hide_spell_metrics()
	_name_label.text = "Évolution à découvrir"
	_meta_label.text = "%s · Rang %d" % [
		discipline.display_name if discipline != null else "Discipline",
		rank_number,
	]
	_xp_label.text = "RANG %d REQUIS" % rank_number
	_description_label.text = (
		"Atteignez le rang %d de la branche pour révéler cette compétence."
		% rank_number
	)
	_spell_heading.hide()
	_spell_label.hide()
	_spell_label.text = ""
	_prerequisites_label.text = "Non révélé"
	_state_label.text = "Verrouillée par le rang"
	_reason_label.text = "Les informations mécaniques seront révélées avec ce rang."
	_incompatibilities_heading.hide()
	_incompatibilities_label.hide()
	_incompatibilities_label.text = ""
	_action_button.text = "VERROUILLÉ"
	_action_button.disabled = true
	var lock_texture := (
		skin.icon_catalog.locked_icon
		if skin != null and skin.icon_catalog != null
		else null
	)
	_icon_override.texture = lock_texture
	_icon_override.visible = lock_texture != null
	_primary_glyph.visible = lock_texture == null
	if _primary_glyph.visible:
		_primary_glyph.configure(&"locked")
	var discipline_icon_id := StringName(
		"%s_%s" % [
			character_id,
			discipline.discipline_id if discipline != null else &"progression",
		]
	)
	_discipline_icon.configure_discipline(discipline_icon_id, skin)
	_set_supporting_sections(true)
	_scroll.scroll_vertical = 0


func set_empty() -> void:
	current_presentation_id = &""
	_hide_spell_metrics()
	_name_label.text = "Choisissez un sort"
	_meta_label.text = ""
	_xp_label.text = ""
	_description_label.text = (
		"Sélectionnez un sort ou une évolution pour découvrir ses effets."
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
	_action_button.text = "SÉLECTIONNEZ UN SORT"
	_action_button.disabled = true
	_icon_override.hide()
	_primary_glyph.configure(&"generic")
	_primary_glyph.show()
	_discipline_icon.configure(&"generic")
	_set_supporting_sections(true)


func set_progression_undefined(character_name: String) -> void:
	current_presentation_id = &""
	_hide_spell_metrics()
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
	_set_supporting_sections(true)


func set_accent(accent: Color) -> void:
	_accent = accent
	if is_node_ready():
		_name_label.add_theme_color_override(
			"font_color", DETAIL_TEXT
		)
		_state_label.add_theme_color_override(
			"font_color", DETAIL_GOLD
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
		get_spell_metrics_text(),
	])


func get_scroll_container() -> ScrollContainer:
	return _scroll


func get_frame_texture() -> Texture2D:
	return _frame_texture.texture


func get_action_button() -> Button:
	return _action_button


func configure_evolution_action(
		enabled: bool,
		button_text: String = "CHOISIR CETTE ÉVOLUTION",
		rejection_reason: String = ""
	) -> void:
	_action_button.text = button_text
	_action_button.disabled = not enabled
	if not rejection_reason.is_empty():
		_reason_label.text = rejection_reason
		_reason_label.show()


func show_evolution_rejection(reason: String) -> void:
	_action_button.text = "CHOIX REFUSÉ"
	_action_button.disabled = true
	_reason_label.text = reason
	_reason_label.show()
	_reason_label.add_theme_color_override("font_color", Color("e9a89b"))


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
		legacy_icon
		if legacy_icon != null
		else node_visual.icon_override if node_visual != null else null
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
			_action_button.text = "ÉVOLUTION DISPONIBLE"
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


## Context is prepared by the screen before applying its reveal policy.
## Merely supplying a spell never reveals its mechanics.
func set_spell_context(spell: Spell) -> void:
	_spell_context = spell
	if is_node_ready():
		_metrics.hide()


func get_spell_metrics_text() -> String:
	if not is_instance_valid(_metrics) or not _metrics.visible:
		return ""
	return "\n".join([
		_metrics_note.text,
		"%s PA" % _cost_value.text,
		"Portée : %s" % _range_value.text,
		"Zone : %s" % _zone_value.text,
		_effect_value.text,
		_casting_value.text,
	])


func _build_spell_metrics() -> void:
	_metrics = VBoxContainer.new()
	_metrics.name = "SpellMetrics"
	_metrics.add_theme_constant_override("separation", 9)
	_content.add_child(_metrics)
	_content.move_child(_metrics, _spell_label.get_index() + 1)
	_metrics_note = _metric_label("VALEURS DE BASE", DETAIL_MUTED)
	_metrics.add_child(_metrics_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_metrics.add_child(row)
	_cost_value = _metric_tile(row, "PA", "2")
	_range_value = _metric_tile(row, "PORTÉE", "0–7")
	_zone_value = _metric_tile(row, "ZONE", "Cible")
	_effect_value = _metric_label("", DETAIL_TEXT)
	_effect_value.add_theme_font_override("font", DETAIL_BOLD)
	_metrics.add_child(_effect_value)
	var separator := HSeparator.new()
	separator.add_theme_stylebox_override("separator", _detail_line())
	_metrics.add_child(separator)
	_casting_value = _metric_label("", DETAIL_MUTED)
	_metrics.add_child(_casting_value)
	_metrics.hide()


func _metric_tile(parent: HBoxContainer, caption: String, value: String) -> Label:
	var surface := PanelContainer.new()
	surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := _detail_style(Color("211b16"), DETAIL_LINE, 5)
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	surface.add_theme_stylebox_override("panel", style)
	parent.add_child(surface)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	surface.add_child(stack)
	var caption_label := _metric_label(caption, DETAIL_MUTED)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_metric_captions.append(caption_label)
	stack.add_child(caption_label)
	var value_label := _metric_label(value, DETAIL_TEXT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_override("font", DETAIL_BOLD)
	stack.add_child(value_label)
	return value_label


func _metric_label(value: String, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", DETAIL_BODY)
	label.add_theme_color_override("font_color", color)
	return label


func _refresh_spell_metrics() -> void:
	if _spell_context == null:
		_hide_spell_metrics()
		return
	var spell := _spell_context
	_metrics_note.text = "VALEURS DE BASE"
	_cost_value.text = str(spell.ap_cost)
	_range_value.text = (
		str(spell.spell_range) if spell.minimum_range == spell.spell_range
		else "%d–%d" % [spell.minimum_range, spell.spell_range]
	)
	match spell.aoe_shape:
		Spell.AoeShape.CROSS:
			_zone_value.text = "Croix %d" % spell.aoe_size
		Spell.AoeShape.SQUARE:
			_zone_value.text = "Carré %d" % spell.aoe_size
		Spell.AoeShape.LINE:
			_zone_value.text = "Ligne %d" % spell.aoe_size
		_:
			_zone_value.text = "Cible"
	_effect_value.text = _spell_effect_text(spell)
	_effect_value.visible = not _effect_value.text.is_empty()
	_casting_value.text = _spell_casting_text(spell)
	_metrics.show()


func _hide_spell_metrics() -> void:
	_spell_context = null
	if is_instance_valid(_metrics):
		_metrics.hide()
		_cost_value.text = ""
		_range_value.text = ""
		_zone_value.text = ""
		_effect_value.text = ""
		_casting_value.text = ""


func _spell_effect_text(spell: Spell) -> String:
	var effects: Array[String] = []
	if spell.damage > 0:
		var damage_kind := "physiques" if spell.damage_type == Spell.DamageType.PHYSICAL else "magiques"
		effects.append("%d dégâts %s" % [spell.damage, damage_kind])
	if spell.heal > 0:
		effects.append("%d points de soin" % spell.heal)
	if spell.shield_grant > 0:
		effects.append("%d points de bouclier" % spell.shield_grant)
	if spell.push_distance > 0:
		effects.append("Repousse de %d case%s" % [spell.push_distance, "s" if spell.push_distance > 1 else ""])
	if spell.pull_distance > 0:
		effects.append("Attire de %d case%s" % [spell.pull_distance, "s" if spell.pull_distance > 1 else ""])
	if spell.ap_drain > 0:
		effects.append("Retire %d PA" % spell.ap_drain)
	if spell.applied_status != null:
		effects.append("%s · %d tour%s" % [spell.applied_status.status_name, spell.applied_status.duration, "s" if spell.applied_status.duration > 1 else ""])
	if spell.terrain_effect != null:
		effects.append("Terrain : %s" % spell.terrain_effect.effect_name)
	return "\n".join(effects)


func _spell_casting_text(spell: Spell) -> String:
	var lines: Array[String] = []
	var targets: Array[String] = []
	if spell.can_target_enemy:
		targets.append("ennemis")
	if spell.can_target_ally:
		targets.append("alliés")
	if spell.can_target_self:
		targets.append("soi-même")
	if spell.can_target_free_cell:
		targets.append("case libre")
	if not targets.is_empty():
		lines.append("Cibles : %s" % ", ".join(targets))
	if not spell.is_self_only():
		lines.append("Ligne de vue requise" if spell.needs_line_of_sight else "Sans ligne de vue")
	if spell.line_from_caster:
		lines.append("Zone orientée depuis le lanceur")
	if spell.once_per_activation:
		lines.append("1 lancer par activation")
	if spell.cooldown_activations > 0:
		lines.append("Relance : %d activation%s" % [spell.cooldown_activations, "s" if spell.cooldown_activations > 1 else ""])
	if spell.initial_cooldown > 0:
		lines.append("Délai initial : %d activation%s" % [spell.initial_cooldown, "s" if spell.initial_cooldown > 1 else ""])
	if spell.max_uses_per_combat > 0:
		lines.append("%d lancer%s par combat" % [spell.max_uses_per_combat, "s" if spell.max_uses_per_combat > 1 else ""])
	if spell.is_delayed():
		lines.append("Résolution : %s" % spell.telegraph_label)
	return "\n".join(lines)


func _set_supporting_sections(is_base_or_locked: bool) -> void:
	var has_prerequisites := not is_base_or_locked and _prerequisites_label.text != "Aucun"
	%PrerequisitesHeading.visible = has_prerequisites
	_prerequisites_label.visible = has_prerequisites
	%DescriptionHeading.visible = not is_base_or_locked
	%StateHeading.hide()
	%ReasonHeading.hide()
	_reason_label.add_theme_color_override("font_color", DETAIL_MUTED)
	_reason_label.visible = not _reason_label.text.is_empty() and _reason_label.text != "—"
	if is_base_or_locked:
		_spell_heading.hide()
		_spell_label.hide()
	else:
		_spell_heading.text = "SORT CONCERNÉ"
	%SeparatorA.visible = _spell_context != null or _spell_label.visible
	%SeparatorB.visible = not is_base_or_locked
	# The incompatible reason is already presented once under its own heading.
	if _incompatibilities_label.visible:
		_reason_label.hide()


func _apply_detail_style() -> void:
	# The centered artwork identifies the spell; a generic discipline fallback is misleading.
	_discipline_icon.hide()
	_frame_texture.hide()
	%ReadingVeil.hide()
	CODEX_STYLE.panel(self, Color("25201c"), DETAIL_LINE, 8)
	CODEX_STYLE.scroll(_scroll)
	for label in [_meta_label, _xp_label, _prerequisites_label, _reason_label]:
		(label as Label).add_theme_font_override("font", DETAIL_BODY)
		(label as Label).add_theme_color_override("font_color", DETAIL_MUTED)
	for label in [_description_label, _spell_label]:
		(label as Label).add_theme_font_override("font", DETAIL_BODY)
		(label as Label).add_theme_color_override("font_color", DETAIL_TEXT)
	_name_label.add_theme_font_override("font", DETAIL_HEADING)
	_description_label.add_theme_font_override("font", DETAIL_BODY)
	for heading in _section_headings:
		heading.add_theme_font_override("font", DETAIL_BOLD)
		heading.add_theme_color_override("font_color", DETAIL_GOLD)
	for separator in [%SeparatorA, %SeparatorB]:
		(separator as HSeparator).add_theme_stylebox_override("separator", _detail_line())
	CODEX_STYLE.button(_action_button)



func _detail_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _detail_line() -> StyleBoxLine:
	var style := StyleBoxLine.new()
	style.color = Color("594936")
	style.thickness = 1
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
