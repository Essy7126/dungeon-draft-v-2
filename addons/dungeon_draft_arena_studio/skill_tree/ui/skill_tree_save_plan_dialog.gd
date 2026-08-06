@tool
class_name SkillTreeSavePlanDialog
extends ConfirmationDialog

signal navigation_requested(logical_owner: String)

var plan: SkillTreeSavePlan = null
var summary_label: Label
var recovery_label: Label
var change_tree: Tree


func _ready() -> void:
	title = "Changements avant sauvegarde"
	ok_button_text = "Appliquer la transaction"
	min_size = Vector2i(860, 520)
	max_size = Vector2i(1180, 680)
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(820, 420)
	add_child(root)
	var intro := Label.new()
	intro.text = "Chaque ligne nécessaire à la cohérence est indivisible. Vérifiez les créations, mises à jour, détachements, Resources orphelines et conflits avant toute écriture."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(intro)
	summary_label = Label.new()
	root.add_child(summary_label)
	recovery_label = Label.new()
	recovery_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(recovery_label)
	change_tree = Tree.new()
	change_tree.columns = 4
	change_tree.set_column_title(0, "Opération")
	change_tree.set_column_title(1, "Fichier / propriété")
	change_tree.set_column_title(2, "Propriétaire")
	change_tree.set_column_title(3, "État")
	change_tree.column_titles_visible = true
	change_tree.hide_root = true
	change_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	change_tree.item_activated.connect(_on_item_activated)
	var tree_viewport := Control.new()
	tree_viewport.custom_minimum_size.y = 300
	tree_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_viewport.clip_contents = true
	root.add_child(tree_viewport)
	change_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree_viewport.add_child(change_tree)


func set_plan(value: SkillTreeSavePlan) -> void:
	plan = value
	if not is_node_ready():
		await ready
	_refresh()


func _refresh() -> void:
	change_tree.clear()
	var root_item := change_tree.create_item()
	if plan == null:
		summary_label.text = "Aucun plan disponible."
		get_ok_button().disabled = true
		return
	var writable_count := plan.writable_entries().size()
	summary_label.text = "%d entrée(s), %d écriture(s), %d conflit(s)." % [
		plan.entries.size(), writable_count, plan.conflicts.size(),
	]
	recovery_label.text = "Point de récupération : %s" % (
		plan.recovery_path if not plan.recovery_path.is_empty() \
		else SkillTreeSaveService.RECOVERY_ROOT + "/save_<horodatage créé avant l'écriture>"
	)
	for entry in plan.entries:
		var item := change_tree.create_item(root_item)
		item.set_text(0, SkillTreeSavePlanEntry.Operation.keys()[entry.operation])
		item.set_text(1, entry.target_path if not entry.target_path.is_empty() else entry.source_path)
		item.set_text(2, entry.logical_owner)
		item.set_text(3, entry.conflict.message if entry.conflict != null else (
			"Atteignable" if entry.reachable else "Non atteignable"
		))
		item.set_metadata(0, entry.logical_owner)
		if entry.conflict != null:
			item.set_custom_color(3, Color(1.0, 0.42, 0.36))
		elif entry.operation == SkillTreeSavePlanEntry.Operation.ORPHANED:
			item.set_custom_color(0, Color(1.0, 0.68, 0.28))
		for change in entry.changes:
			var child := change_tree.create_item(item)
			child.set_text(0, "PROPRIÉTÉ")
			child.set_text(1, str(change.get("property", "")))
			child.set_text(2, "Avant : %s" % str(change.get("before")))
			child.set_text(3, "Après : %s" % str(change.get("after")))
			child.set_metadata(0, entry.logical_owner)
	get_ok_button().disabled = plan.has_blocking_conflicts() or writable_count == 0


func _on_item_activated() -> void:
	var item := change_tree.get_selected()
	if item == null:
		return
	var owner := str(item.get_metadata(0))
	if not owner.is_empty():
		navigation_requested.emit(owner)
