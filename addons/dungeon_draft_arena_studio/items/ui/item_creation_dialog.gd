@tool
class_name ItemCreationDialog
extends AcceptDialog

signal create_requested(data: Dictionary)

var catalog: ItemStudioCatalogService
var path_service := ItemIdPathService.new()
var template_option: OptionButton
var name_edit: LineEdit
var id_edit: LineEdit
var compatibility_option: OptionButton
var path_label: Label
var hero_entries: Array[Dictionary] = []


func setup(p_catalog: ItemStudioCatalogService, p_hero_entries: Array[Dictionary] = []) -> void:
	catalog = p_catalog
	hero_entries = p_hero_entries.duplicate(false)


func _ready() -> void:
	title = "Nouvel objet"
	ok_button_text = "Créer l’objet"
	min_size = Vector2i(520, 360)
	max_size = Vector2i(560, 460)
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(480, 300)
	add_child(root)
	root.add_child(_label("1. Modèle"))
	template_option = OptionButton.new()
	for label in ["Arme", "Armure", "Accessoire", "Consommable", "Parchemin", "Relique"]:
		template_option.add_item(label)
	root.add_child(template_option)
	root.add_child(_label("2. Nom"))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Nom français de l’objet"
	name_edit.text_changed.connect(_update_proposal)
	root.add_child(name_edit)
	root.add_child(_label("3. Identifiant technique (rempli automatiquement)"))
	id_edit = LineEdit.new()
	root.add_child(id_edit)
	root.add_child(_label("4. Compatibilité"))
	compatibility_option = OptionButton.new()
	compatibility_option.add_item("Tous")
	compatibility_option.set_item_metadata(0, &"")
	for entry in hero_entries:
		compatibility_option.add_item(str(entry.get("display_name", entry.get("id", "Héros"))))
		compatibility_option.set_item_metadata(
			compatibility_option.item_count - 1,
			StringName(entry.get("id", &"")),
		)
	root.add_child(compatibility_option)
	template_option.item_selected.connect(_on_template_selected)
	path_label = Label.new()
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(path_label)
	confirmed.connect(_confirm)


func open_dialog() -> void:
	name_edit.text = "Nouvel objet"
	_update_proposal(name_edit.text)
	_on_template_selected(template_option.selected)
	popup_centered(Vector2i(520, 420))


func _on_template_selected(index: int) -> void:
	var is_relic := index == ItemDefinition.Category.RELIC
	compatibility_option.disabled = is_relic
	if is_relic:
		compatibility_option.select(0)
	compatibility_option.tooltip_text = (
		"Les reliques sont des bonus partagés et ne demandent aucun héros cible."
		if is_relic
		else "Limite éventuellement l’objet à un héros."
	)


func _update_proposal(value: String) -> void:
	if id_edit == null:
		return
	id_edit.text = str(path_service.suggest_item_id(value, catalog))
	path_label.text = "Brouillon proposé : %s" % path_service.draft_path(
		StringName(id_edit.text), _draft_directory()
	)


func _confirm() -> void:
	var item_id := StringName(path_service.normalize_item_id(id_edit.text))
	if item_id == &"" or name_edit.text.strip_edges().is_empty():
		return
	var compatible: Array[StringName] = []
	if template_option.selected != ItemDefinition.Category.RELIC and compatibility_option.selected > 0:
		var selected_id := StringName(
			compatibility_option.get_item_metadata(compatibility_option.selected)
		)
		if selected_id != &"":
			compatible.append(selected_id)
	create_requested.emit({
		"template": template_option.selected,
		"display_name": name_edit.text.strip_edges(),
		"item_id": item_id,
		"compatible_character_ids": compatible,
		"draft_path": path_service.draft_path(item_id, _draft_directory()),
	})


func _draft_directory() -> String:
	return catalog.draft_directory if catalog != null \
		else ItemStudioCatalogService.DRAFT_DIRECTORY


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label
