class_name SkillTreeNodeDetailPanel
extends PanelContainer

@onready var _icon: TextureRect = %Icon
@onready var _placeholder: Label = %Placeholder
@onready var _name_label: Label = %NameLabel
@onready var _meta_label: Label = %MetaLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _spell_label: Label = %SpellLabel
@onready var _prerequisites_label: Label = %PrerequisitesLabel
@onready var _state_label: Label = %StateLabel
@onready var _reason_label: Label = %ReasonLabel

var current_presentation_id: StringName = &""


func configure_node(
		discipline: DisciplineData,
		node: SkillUpgradeData,
		presentation: Dictionary,
		node_names: Dictionary,
		spell_name: String
	) -> void:
	if node == null:
		set_empty()
		return
	current_presentation_id = node.upgrade_id
	_name_label.text = node.display_name.to_upper()
	_meta_label.text = "%s — Rang %d — %d XP" % [
		discipline.display_name if discipline != null else str(node.discipline_id),
		node.rank,
		int(presentation.get("required_xp", 0)),
	]
	_description_label.text = node.description
	_spell_label.text = "Sort affecté : %s" % (
		spell_name if not spell_name.is_empty() else str(node.target_spell_id)
	)
	_prerequisites_label.text = _prerequisite_text(node, node_names)
	var state: SkillTreeVisualPresentation.SkillTreeVisualState = int(
		presentation.get(
			"state",
			SkillTreeVisualPresentation.SkillTreeVisualState.FUTURE
		)
	)
	_state_label.text = "État : %s" % (
		SkillTreeVisualPresentation.state_label(state)
	)
	_reason_label.text = "Raison : %s" % str(
		presentation.get("reason", "")
	)
	_set_icon(node.icon, _initials(node.display_name))


func configure_base(
		discipline: DisciplineData,
		display_name: String,
		description: String,
		presentation: Dictionary
	) -> void:
	current_presentation_id = &"__base_rank_1"
	_name_label.text = display_name.to_upper()
	_meta_label.text = "%s — Rang 1 — %d XP" % [
		discipline.display_name if discipline != null else "Discipline",
		int(presentation.get("required_xp", 0)),
	]
	_description_label.text = description
	_spell_label.text = "Compétence de base"
	_prerequisites_label.text = "Prérequis : aucun"
	_state_label.text = "État : Sélectionné"
	_reason_label.text = "Raison : Compétence de base de la discipline."
	_set_icon(
		discipline.icon if discipline != null else null,
		_initials(display_name)
	)


func set_empty() -> void:
	current_presentation_id = &""
	_name_label.text = "DÉTAIL DU NŒUD"
	_meta_label.text = ""
	_description_label.text = (
		"Survolez un nœud ou placez-y le focus pour consulter ses détails."
	)
	_spell_label.text = ""
	_prerequisites_label.text = ""
	_state_label.text = ""
	_reason_label.text = ""
	_set_icon(null, "?")


func get_detail_text() -> String:
	return "\n".join([
		_name_label.text,
		_meta_label.text,
		_description_label.text,
		_spell_label.text,
		_prerequisites_label.text,
		_state_label.text,
		_reason_label.text,
	])


func _prerequisite_text(
		node: SkillUpgradeData,
		node_names: Dictionary
	) -> String:
	if not node is SkillTreeNodeData:
		return "Prérequis : aucun"
	var prerequisite_names: Array[String] = []
	for prerequisite_id in (
		node as SkillTreeNodeData
	).prerequisite_node_ids:
		prerequisite_names.append(
			str(node_names.get(prerequisite_id, prerequisite_id))
		)
	return (
		"Prérequis : aucun"
		if prerequisite_names.is_empty()
		else "Prérequis :\n%s" % "\n".join(prerequisite_names)
	)


func _set_icon(texture: Texture2D, fallback_text: String) -> void:
	_icon.texture = texture
	_icon.visible = texture != null
	_placeholder.text = fallback_text
	_placeholder.visible = texture == null


func _initials(value: String) -> String:
	var words := value.split(" ", false)
	var result := ""
	for word in words:
		if not word.is_empty():
			result += word.left(1).to_upper()
		if result.length() >= 2:
			break
	return result if not result.is_empty() else "?"
