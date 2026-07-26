class_name CharacterPresentationCard
extends PanelContainer

@onready var name_label: Label = $Margin/Content/Name
@onready var role_label: Label = $Margin/Content/Role
@onready var preview: CharacterPreview3D = $Margin/Content/Preview
@onready var summary_label: Label = $Margin/Content/Summary
@onready var spell_count_label: Label = $Margin/Content/SpellCount
@onready var disciplines_label: Label = $Margin/Content/Disciplines
@onready var badge_label: Label = $Margin/Content/Badge

var character_data: UnitData = null


func configure(data: UnitData) -> void:
	character_data = data
	if data == null:
		name_label.text = "Personnage indisponible"
		role_label.text = ""
		summary_label.text = ""
		spell_count_label.text = "0 sort"
		disciplines_label.text = ""
		badge_label.visible = false
		preview.configure(null)
		return

	name_label.text = data.unit_name
	role_label.text = data.role
	summary_label.text = data.presentation_summary
	spell_count_label.text = "%d sort%s" % [
		data.spells.size(),
		"" if data.spells.size() == 1 else "s",
	]
	var discipline_names: Array[String] = []
	for discipline in data.disciplines:
		if discipline != null:
			discipline_names.append(discipline.display_name)
	if not discipline_names.is_empty():
		disciplines_label.text = "Disciplines : %s" % ", ".join(discipline_names)
	else:
		disciplines_label.text = data.progression_summary
	badge_label.text = data.presentation_badge
	badge_label.visible = not data.presentation_badge.strip_edges().is_empty()
	preview.configure(data)


func _exit_tree() -> void:
	if is_instance_valid(preview):
		preview.clear_preview()
