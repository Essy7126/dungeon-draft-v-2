@tool
class_name SkillTreeCatalogPanel
extends VBoxContainer

signal character_requested(path: String)
signal discipline_requested(discipline_id: StringName)
signal discipline_document_requested(path: String, discipline_id: StringName)
signal new_discipline_requested
signal duplicate_discipline_requested
signal rename_discipline_requested
signal delete_discipline_requested

var search_edit: LineEdit
var filter_option: OptionButton
var tree: Tree
var help_label: Label
var _heroes: Array[Dictionary] = []
var _current_character_path := ""
var _current_discipline_id: StringName = &""
var _dirty := false


func _ready() -> void:
	custom_minimum_size.x = 270
	add_theme_constant_override("separation", 7)
	var title := Label.new()
	title.text = "1 · CATALOGUE"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.48, 0.86, 1.0))
	add_child(title)
	help_label = Label.new()
	help_label.text = "Choisissez d’abord un personnage, puis l’une de ses disciplines."
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.add_theme_color_override("font_color", Color(0.72, 0.77, 0.84))
	add_child(help_label)
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Rechercher un personnage ou une discipline…"
	search_edit.tooltip_text = "Filtre le catalogue sans modifier les Resources."
	search_edit.text_changed.connect(func(_value): _rebuild())
	add_child(search_edit)
	filter_option = OptionButton.new()
	filter_option.add_item("Toutes les ressources")
	filter_option.add_item("Ressources invalides")
	filter_option.add_item("Document modifié")
	filter_option.tooltip_text = "Affiche tout le catalogue ou seulement les éléments à vérifier."
	filter_option.item_selected.connect(func(_index): _rebuild())
	add_child(filter_option)
	tree = Tree.new()
	tree.hide_root = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size.y = 300
	tree.item_selected.connect(_on_item_selected)
	add_child(tree)
	var create_button := Button.new()
	create_button.text = "+ Nouvelle discipline"
	create_button.tooltip_text = "Crée une discipline vide avec un assistant pas à pas."
	create_button.pressed.connect(func(): new_discipline_requested.emit())
	add_child(create_button)
	var actions := HBoxContainer.new()
	add_child(actions)
	var duplicate := Button.new()
	duplicate.text = "Dupliquer"
	duplicate.tooltip_text = "Crée une copie indépendante de la discipline sélectionnée."
	duplicate.pressed.connect(func(): duplicate_discipline_requested.emit())
	actions.add_child(duplicate)
	var rename := Button.new()
	rename.text = "Renommer"
	rename.tooltip_text = "Change le nom affiché. L’identifiant stable reste inchangé."
	rename.pressed.connect(func(): rename_discipline_requested.emit())
	actions.add_child(rename)
	var delete := Button.new()
	delete.text = "Supprimer"
	delete.tooltip_text = "Retire la discipline après avoir présenté toutes les conséquences."
	delete.pressed.connect(func(): delete_discipline_requested.emit())
	actions.add_child(delete)


func set_catalog(
		heroes: Array[Dictionary],
		current_character_path := "",
		current_discipline_id: StringName = &"",
		dirty := false
	) -> void:
	_heroes = heroes
	_current_character_path = current_character_path
	_current_discipline_id = current_discipline_id
	_dirty = dirty
	_rebuild()


func set_guided(value: bool) -> void:
	if help_label != null:
		help_label.visible = value


func _rebuild() -> void:
	if tree == null:
		return
	tree.clear()
	var root := tree.create_item()
	var query := search_edit.text.strip_edges().to_lower() if search_edit != null else ""
	for hero_entry in _heroes:
		var hero := hero_entry.get("resource") as UnitData
		if hero == null or not _passes_filter(hero_entry, hero):
			continue
		var discipline_rows := SkillTreeCatalogService.disciplines_for(hero)
		var hero_matches := query.is_empty() \
			or hero.unit_name.to_lower().contains(query) \
			or str(hero.get_effective_unit_id()).to_lower().contains(query)
		var visible_disciplines: Array[Dictionary] = []
		for discipline_entry in discipline_rows:
			if hero_matches or str(discipline_entry.get("name", "")).to_lower().contains(query) \
					or str(discipline_entry.get("id", "")).to_lower().contains(query):
				visible_disciplines.append(discipline_entry)
		if not hero_matches and visible_disciplines.is_empty():
			continue
		var hero_item := tree.create_item(root)
		hero_item.set_text(0, ("● " if str(hero_entry.get("path", "")) == _current_character_path else "") + hero.unit_name)
		hero_item.set_tooltip_text(0, "Personnage — %d discipline(s)" % hero.disciplines.size())
		hero_item.set_metadata(0, {"kind": "hero", "path": hero_entry.get("path", "")})
		hero_item.set_collapsed(false)
		for discipline_entry in visible_disciplines:
			var discipline_item := tree.create_item(hero_item)
			var discipline_id := StringName(discipline_entry.get("id", &""))
			var spell := discipline_entry.get("spell") as Spell
			var spell_suffix := " — sort : %s" % spell.spell_name \
				if spell != null else " — aucun sort"
			var prefix := "⚠ " if bool(discipline_entry.get("invalid", false)) else ""
			if discipline_id == _current_discipline_id \
					and str(hero_entry.get("path", "")) == _current_character_path:
				prefix = ("● MODIFIÉ · " if _dirty else "● ") + prefix
			discipline_item.set_text(
				0, prefix + str(discipline_entry.get("name", "Discipline")) + spell_suffix
			)
			discipline_item.set_tooltip_text(
				0,
				"Discipline « %s »%s — cliquez pour afficher son arbre." % [discipline_id, spell_suffix]
			)
			discipline_item.set_metadata(0, {
				"kind": "discipline",
				"character_path": hero_entry.get("path", ""),
				"discipline_id": discipline_id,
			})


func _passes_filter(hero_entry: Dictionary, hero: UnitData) -> bool:
	match filter_option.selected if filter_option != null else 0:
		1:
			if bool(hero_entry.get("invalid", false)):
				return true
			return SkillTreeCatalogService.disciplines_for(hero).any(
				func(entry: Dictionary) -> bool: return bool(entry.get("invalid", false))
			)
		2:
			return _dirty and str(hero_entry.get("path", "")) == _current_character_path
		_:
			return true


func _on_item_selected() -> void:
	var item := tree.get_selected()
	if item == null:
		return
	var metadata = item.get_metadata(0)
	if not metadata is Dictionary:
		return
	if metadata.get("kind") == "hero":
		character_requested.emit(str(metadata.get("path", "")))
	elif metadata.get("kind") == "discipline":
		var character_path := str(metadata.get("character_path", ""))
		if character_path != _current_character_path:
			discipline_document_requested.emit(
				character_path, StringName(metadata.get("discipline_id", &""))
			)
		else:
			discipline_requested.emit(StringName(metadata.get("discipline_id", &"")))
