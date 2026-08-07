@tool
class_name ItemSavePlanDialog
extends ConfirmationDialog

signal plan_confirmed(plan: ItemSavePlan)

var plan: ItemSavePlan = null
var content: RichTextLabel


func _ready() -> void:
	title = "Plan de sauvegarde"
	ok_button_text = "Confirmer l’écriture"
	cancel_button_text = "Annuler"
	content = RichTextLabel.new()
	content.bbcode_enabled = true
	content.custom_minimum_size = Vector2(650, 390)
	add_child(content)
	confirmed.connect(func(): plan_confirmed.emit(plan))


func show_plan(p_plan: ItemSavePlan) -> void:
	plan = p_plan
	var lines: Array[String] = []
	if plan == null:
		lines.append("Plan absent.")
	else:
		for entry in plan.entries:
			lines.append("[b]%s %s[/b]" % [entry.operation, entry.status])
			lines.append("Source : %s" % (entry.source_path if not entry.source_path.is_empty() else "nouvel objet"))
			lines.append("Destination : %s" % entry.destination_path)
			lines.append("item_id : %s" % entry.item_id)
			lines.append("Empreinte : %s → %s" % [entry.old_fingerprint.left(12), entry.new_fingerprint.left(12)])
			lines.append("Sous-ressources : %d" % entry.subresource_count)
		lines.append("Catalogue : %s" % plan.catalog_path)
		lines.append("Tag de récompense modifié : %s" % ("oui" if plan.reward_tag_changed else "non"))
		for conflict in plan.conflicts:
			lines.append("[color=red]✖ %s[/color]" % conflict.message)
		for warning in plan.warnings:
			lines.append("[color=orange]⚠ %s[/color]" % warning)
	content.text = "\n".join(lines)
	get_ok_button().disabled = plan == null or not plan.is_valid()
	popup_centered(Vector2i(720, 500))
