class_name SkillTreeTooltipPanel
extends PanelContainer

const XP_REMINDER := (
	"Chaque lancement réussi d’un sort rapporte 1 XP à sa discipline."
)
const GLYPH_SCENE := preload(
	"res://ui/progression/components/skill_tree_effect_glyph.tscn"
)

@export var skin: SkillTreeSkinData = null

@onready var _title_label: Label = %TitleLabel
@onready var _rows: VBoxContainer = %DisciplineRows
@onready var _reminder_label: Label = %ReminderLabel

var _summary_text := ""


func _ready() -> void:
	_reminder_label.text = XP_REMINDER


func refresh_from_state(character_state: CharacterRunState) -> void:
	_clear_rows()
	if character_state == null:
		_title_label.text = "Progression indisponible"
		_summary_text = ""
		return
	_title_label.text = "%s — PROGRESSION" % (
		character_state.unit.unit_name.to_upper()
		if character_state.unit != null
		else str(character_state.character_id).to_upper()
	)
	var sections: Array[String] = []
	for discipline in character_state.get_disciplines():
		if discipline == null:
			continue
		var progress := character_state.get_discipline_progress(
			discipline.discipline_id
		)
		if progress == null:
			continue
		var section := _discipline_summary(discipline, progress)
		sections.append(section)
		_add_discipline_row(discipline, section)
	_summary_text = "\n\n".join(sections)


func get_summary_text() -> String:
	return _summary_text


func place_near(
		anchor_global_rect: Rect2,
		viewport_rect: Rect2
	) -> void:
	var wanted_size := get_combined_minimum_size()
	size = wanted_size
	var left_position := Vector2(
		anchor_global_rect.position.x - wanted_size.x - 12.0,
		anchor_global_rect.position.y
	)
	var right_position := Vector2(
		anchor_global_rect.end.x + 12.0,
		anchor_global_rect.position.y
	)
	var global_position := (
		left_position
		if left_position.x >= viewport_rect.position.x + 8.0
		else right_position
	)
	global_position.x = clampf(
		global_position.x,
		viewport_rect.position.x + 8.0,
		viewport_rect.end.x - wanted_size.x - 8.0
	)
	global_position.y = clampf(
		global_position.y,
		viewport_rect.position.y + 8.0,
		viewport_rect.end.y - wanted_size.y - 8.0
	)
	var parent_control := get_parent() as Control
	position = (
		global_position - parent_control.global_position
		if parent_control != null
		else global_position
	)


func get_global_bounds() -> Rect2:
	return get_global_rect()


func _add_discipline_row(
		discipline: DisciplineData,
		summary: String
	) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := GLYPH_SCENE.instantiate() as SkillTreeEffectGlyph
	glyph.custom_minimum_size = Vector2(34, 34)
	glyph.configure_discipline(
		StringName("elf_%s" % discipline.discipline_id),
		skin
	)
	row.add_child(glyph)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size = Vector2(314, 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.text = summary
	row.add_child(text)
	_rows.add_child(row)


func _discipline_summary(
		discipline: DisciplineData,
		progress: DisciplineProgressState
	) -> String:
	var next_rank := progress.get_next_rank_data()
	var threshold_text := (
		str(next_rank.required_total_xp)
		if next_rank != null
		else "MAX"
	)
	var selected_names := _selected_names(discipline, progress)
	var pending_text := (
		"  [color=#f1c75b][b]choix en attente ![/b][/color]"
		if not progress.get_pending_rank_choices().is_empty()
		else ""
	)
	var lines: Array[String] = [
		"[b]%s[/b] — Rang %d%s" % [
			discipline.display_name,
			progress.rank,
			pending_text,
		],
		"XP : %d / %s — prochain seuil : %s" % [
			progress.xp,
			threshold_text,
			threshold_text,
		],
	]
	if discipline.discipline_id == &"archer":
		lines.append(
			"Chemin : %s" % (
				" → ".join(selected_names)
				if not selected_names.is_empty()
				else "aucune branche sélectionnée"
			)
		)
	elif not selected_names.is_empty():
		lines.append("Choix : %s" % ", ".join(selected_names))
	return "\n".join(lines)


func _selected_names(
		discipline: DisciplineData,
		progress: DisciplineProgressState
	) -> Array[String]:
	var result: Array[String] = []
	var selected_ids := progress.get_selected_upgrade_ids()
	var ranks: Array[DisciplineRankData] = []
	for rank_data in discipline.ranks:
		if rank_data != null:
			ranks.append(rank_data)
	ranks.sort_custom(
		func(a: DisciplineRankData, b: DisciplineRankData) -> bool:
			return a.rank < b.rank
	)
	for rank_data in ranks:
		for node in rank_data.choices:
			if node != null and selected_ids.has(node.upgrade_id):
				result.append(node.display_name)
	return result


func _clear_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.free()
