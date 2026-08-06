@tool
class_name SkillTreeOrphanDialog
extends AcceptDialog

signal action_requested(action: StringName, record: Dictionary, confirmation_token: String)

var records: Array[Dictionary] = []
var tree: Tree
var adopt_button: Button
var archive_button: Button
var delete_button: Button
var delete_dialog: ConfirmationDialog
var delete_token: LineEdit


func _ready() -> void:
	title = "Resources orphelines"
	ok_button_text = "Fermer"
	min_size = Vector2i(880, 480)
	max_size = Vector2i(1180, 680)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(840, 390)
	add_child(box)
	var explanation := Label.new()
	explanation.text = "Une Resource orpheline n’est plus atteignable depuis le personnage. Adopter rattache une discipline ; archiver ou supprimer crée d’abord une copie récupérable."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(explanation)
	tree = Tree.new()
	tree.hide_root = true
	tree.columns = 5
	for index in range(5):
		tree.set_column_title(index, ["Type", "Resource", "Chemin", "Dernier propriétaire", "Raison"][index])
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.item_selected.connect(_update_actions)
	var tree_viewport := Control.new()
	tree_viewport.custom_minimum_size.y = 300
	tree_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_viewport.clip_contents = true
	box.add_child(tree_viewport)
	tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree_viewport.add_child(tree)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	adopt_button = _action(actions, "Adopter", &"ADOPT")
	archive_button = _action(actions, "Archiver", &"ARCHIVE")
	delete_button = Button.new()
	delete_button.text = "Supprimer définitivement…"
	delete_button.pressed.connect(_request_delete)
	actions.add_child(delete_button)
	delete_dialog = ConfirmationDialog.new()
	delete_dialog.title = "Confirmation renforcée"
	delete_dialog.dialog_text = "Saisissez exactement le nom ou l’identifiant affiché. Une archive de récupération sera créée avant le retrait."
	delete_token = LineEdit.new()
	delete_token.placeholder_text = "Identifiant de confirmation"
	delete_dialog.add_child(delete_token)
	delete_dialog.confirmed.connect(func():
		var record := _selected_record()
		if not record.is_empty():
			action_requested.emit(&"DELETE", record, delete_token.text.strip_edges())
	)
	add_child(delete_dialog)
	_update_actions()


func set_records(value: Array[Dictionary]) -> void:
	records = value
	if tree == null:
		return
	tree.clear()
	var root := tree.create_item()
	for index in range(records.size()):
		var record := records[index]
		var resource := record.get("resource") as Resource
		var item := tree.create_item(root)
		item.set_text(0, str(record.get("type", resource.get_class() if resource != null else "Resource")))
		item.set_text(1, _resource_label(resource))
		item.set_text(2, str(record.get("path", "")))
		item.set_text(3, str(record.get("last_owner", "inconnu")))
		item.set_text(4, str(record.get("reason", "")))
		item.set_tooltip_text(4, "Références entrantes : %d" % (record.get("incoming_references", []) as Array).size())
		item.set_metadata(0, index)
	_update_actions()


func _action(parent: Control, label: String, action: StringName) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(func():
		var record := _selected_record()
		if not record.is_empty():
			action_requested.emit(action, record, "")
	)
	parent.add_child(button)
	return button


func _selected_record() -> Dictionary:
	var item := tree.get_selected() if tree != null else null
	if item == null:
		return {}
	var index := int(item.get_metadata(0))
	return records[index] if index >= 0 and index < records.size() else {}


func _update_actions() -> void:
	var record := _selected_record()
	var resource := record.get("resource") as Resource
	var has_selection := resource != null
	if adopt_button != null:
		adopt_button.disabled = not resource is DisciplineData
	if archive_button != null:
		archive_button.disabled = not has_selection or not (record.get("incoming_references", []) as Array).is_empty()
	if delete_button != null:
		delete_button.disabled = not has_selection or not (record.get("incoming_references", []) as Array).is_empty()


func _request_delete() -> void:
	var record := _selected_record()
	if record.is_empty():
		return
	delete_token.text = ""
	delete_dialog.popup_centered(Vector2i(560, 240))
	delete_token.grab_focus.call_deferred()


static func _resource_label(resource: Resource) -> String:
	if resource is DisciplineData:
		return "%s (%s)" % [resource.display_name, resource.discipline_id]
	if resource is SkillUpgradeData:
		return "%s (%s)" % [resource.display_name, resource.upgrade_id]
	if resource is Spell:
		return "%s (%s)" % [resource.spell_name, resource.get_effective_spell_id()]
	if resource is SpellModifier:
		return resource.modifier_name
	return resource.resource_path.get_file() if resource != null else "Resource absente"
