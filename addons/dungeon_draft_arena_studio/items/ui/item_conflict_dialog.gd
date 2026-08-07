@tool
class_name ItemConflictDialog
extends AcceptDialog

var label: RichTextLabel


func _ready() -> void:
	title = "Conflits de sauvegarde"
	ok_button_text = "Fermer"
	label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.custom_minimum_size = Vector2(560, 260)
	add_child(label)


func show_conflicts(plan: ItemSavePlan) -> void:
	var lines: Array[String] = ["[b]La sauvegarde est bloquée.[/b]"]
	for conflict in plan.conflicts:
		lines.append("[color=red]✖ %s[/color]\n%s" % [conflict.message, conflict.path])
	label.text = "\n".join(lines)
	popup_centered(Vector2i(620, 330))
