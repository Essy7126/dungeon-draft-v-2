@tool
class_name ItemDuplicationDialog
extends AcceptDialog

signal duplicate_requested(item_id: StringName, copy_acquisition_tags: bool)

var catalog: ItemStudioCatalogService
var path_service := ItemIdPathService.new()
var id_edit: LineEdit
var tags_check: CheckBox
var path_label: Label


func setup(p_catalog: ItemStudioCatalogService) -> void:
	catalog = p_catalog


func _ready() -> void:
	title = "Dupliquer vers un brouillon"
	ok_button_text = "Créer la copie isolée"
	var root := VBoxContainer.new()
	add_child(root)
	var warning := Label.new()
	warning.text = "L’original ne sera ni remplacé, ni déplacé, ni supprimé."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(warning)
	id_edit = LineEdit.new()
	id_edit.text_changed.connect(func(value): path_label.text = path_service.draft_path(
		StringName(path_service.normalize_item_id(value)), _draft_directory()
	))
	root.add_child(id_edit)
	tags_check = CheckBox.new()
	tags_check.text = "Copier les tags d’acquisition (le tag de récompense reste décoché par défaut)"
	root.add_child(tags_check)
	path_label = Label.new()
	root.add_child(path_label)
	confirmed.connect(_confirm)


func open_for(definition: ItemDefinition) -> void:
	var proposed := path_service.suggest_item_id("%s copie" % definition.display_name, catalog)
	id_edit.text = str(proposed)
	tags_check.button_pressed = false
	path_label.text = path_service.draft_path(proposed, _draft_directory())
	popup_centered(Vector2i(560, 220))


func _confirm() -> void:
	var item_id := StringName(path_service.normalize_item_id(id_edit.text))
	if item_id != &"":
		duplicate_requested.emit(item_id, tags_check.button_pressed)


func _draft_directory() -> String:
	return catalog.draft_directory if catalog != null \
		else ItemStudioCatalogService.DRAFT_DIRECTORY
