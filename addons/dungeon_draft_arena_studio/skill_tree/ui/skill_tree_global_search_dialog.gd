@tool
class_name SkillTreeGlobalSearchDialog
extends AcceptDialog

signal result_requested(result: Dictionary)

var heroes: Array[Dictionary] = []
var query_edit: LineEdit
var result_tree: Tree
var results: Array[Dictionary] = []


func _ready() -> void:
	title = "Recherche globale"
	ok_button_text = "Fermer"
	min_size = Vector2i(760, 520)
	var box := VBoxContainer.new()
	add_child(box)
	query_edit = LineEdit.new()
	query_edit.placeholder_text = "Nom, identifiant, description ou résumé d’effet…"
	query_edit.clear_button_enabled = true
	query_edit.text_changed.connect(_refresh)
	box.add_child(query_edit)
	result_tree = Tree.new()
	result_tree.hide_root = true
	result_tree.columns = 3
	result_tree.set_column_title(0, "Type")
	result_tree.set_column_title(1, "Résultat")
	result_tree.set_column_title(2, "Contexte")
	result_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_tree.custom_minimum_size.y = 390
	result_tree.item_activated.connect(_activate_selected)
	box.add_child(result_tree)


func set_catalog(value: Array[Dictionary]) -> void:
	heroes = value
	if query_edit != null:
		_refresh(query_edit.text)


func open_and_focus() -> void:
	popup_centered_ratio(0.66)
	query_edit.grab_focus.call_deferred()
	query_edit.select_all.call_deferred()


func _refresh(query: String) -> void:
	if result_tree == null:
		return
	results = SkillTreeGlobalSearchService.search(heroes, query)
	result_tree.clear()
	var root := result_tree.create_item()
	for index in range(results.size()):
		var result := results[index]
		var item := result_tree.create_item(root)
		item.set_text(0, str(result.get("kind", "")))
		item.set_text(1, str(result.get("label", "")))
		item.set_text(2, "%s · %s · R%s" % [
			result.get("discipline_id", "—"), result.get("node_id", "—"),
			result.get("rank", "—"),
		])
		item.set_metadata(0, index)


func _activate_selected() -> void:
	var item := result_tree.get_selected()
	if item == null:
		return
	var index := int(item.get_metadata(0))
	if index < 0 or index >= results.size():
		return
	hide()
	result_requested.emit(results[index])
