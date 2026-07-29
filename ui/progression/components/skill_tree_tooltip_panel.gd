class_name SkillTreeTooltipPanel
extends PanelContainer

const XP_REMINDER := (
	"Chaque lancement réussi d’un sort rapporte 1 XP à sa discipline."
)

@onready var _title_label: Label = %TitleLabel
@onready var _summary: RichTextLabel = %Summary
@onready var _reminder_label: Label = %ReminderLabel


func _ready() -> void:
	_reminder_label.text = XP_REMINDER


func refresh_from_state(character_state: CharacterRunState) -> void:
	if character_state == null:
		_title_label.text = "Progression indisponible"
		_summary.text = ""
		return
	_title_label.text = "%s — Progression" % (
		character_state.unit.unit_name
		if character_state.unit != null
		else str(character_state.character_id)
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
		sections.append(
			_discipline_summary(discipline, progress)
		)
	_summary.text = "\n\n".join(sections)


func get_summary_text() -> String:
	return _summary.text if is_instance_valid(_summary) else ""


func _discipline_summary(
		discipline: DisciplineData,
		progress: DisciplineProgressState
	) -> String:
	var next_rank := progress.get_next_rank_data()
	var threshold_text := (
		str(next_rank.required_total_xp)
		if next_rank != null
		else "maximum"
	)
	var selected_names := _selected_names(discipline, progress)
	var pending_text := (
		" — [color=#f1c75b]choix en attente ![/color]"
		if not progress.get_pending_rank_choices().is_empty()
		else ""
	)
	var lines: Array[String] = [
		"[b]%s[/b] — Rang %d%s" % [
			discipline.display_name,
			progress.rank,
			pending_text,
		],
		"XP : %d — prochain seuil : %s" % [
			progress.xp,
			threshold_text,
		],
		"Choix : %s" % (
			", ".join(selected_names)
			if not selected_names.is_empty()
			else "aucun"
		),
	]
	if discipline.discipline_id == &"archer":
		lines.append(
			"Chemin Archer : %s" % (
				" → ".join(selected_names)
				if not selected_names.is_empty()
				else "aucune branche sélectionnée"
			)
		)
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
