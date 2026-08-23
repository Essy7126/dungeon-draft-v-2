@tool
class_name SpellCreationDialog
extends AcceptDialog

## Popup légère, volontairement sans étapes verrouillées : un sort dispose déjà
## d'une fiche d'édition complète dans l'inspecteur. Le rôle de cette popup est
## seulement de donner un nom, un point de départ et un emplacement de fichier,
## puis de s'effacer.

signal spell_creation_requested(data: Dictionary)

## Un modèle est un préréglage de départ, pas une catégorie. Il n'initialise que
## des champs sans ambiguïté de conception, ne fixe aucune valeur d'équilibrage,
## et ne verrouille ni ne masque aucun groupe ensuite.
const TEMPLATES := [
	[
		&"simple_attack", "Attaque simple",
		"Cible les ennemis. À vous de choisir ensuite les dégâts, le coût et la portée.",
	],
	[
		&"heal", "Soin",
		"Cible les alliés et le lanceur, jamais les ennemis.",
	],
	[
		&"push_area", "Poussée / Zone",
		"Aucune valeur imposée. La forme et la taille de zone se règlent dans l’Inspecteur Godot du sort.",
	],
	[
		&"status", "Statut",
		"Aucune valeur imposée. L’effet de terrain et le statut se règlent dans l’Inspecteur Godot du sort.",
	],
	[
		&"summon", "Invocation",
		"Prépare la résolution différée en mode Invocation. L’unité invoquée se choisit dans l’Inspecteur Godot du sort.",
	],
]
const TEMPLATE_ID := 0
const TEMPLATE_LABEL := 1
const TEMPLATE_HELP := 2

const MUTED := Color(0.72, 0.77, 0.84)

var path_service := SpellIdPathService.new()
var template_option: OptionButton
var template_help: Label
var name_edit: LineEdit
var id_edit: LineEdit
var location_option: OptionButton
var path_label: Label

var _heroes: Array[Dictionary] = []
var _unit: UnitData = null
var _reserved_ids: Array = []


func setup(heroes: Array[Dictionary], unit: UnitData, reserved_ids: Array = []) -> void:
	_heroes = heroes
	_unit = unit
	_reserved_ids = reserved_ids
	_update_proposal(name_edit.text if name_edit != null else "")


func _ready() -> void:
	title = "Nouveau sort"
	ok_button_text = "Créer le sort"
	min_size = Vector2i(560, 400)
	# Sans plafond, les libellés en retour à la ligne automatique gonflent la
	# hauteur demandée et poussent le bouton de validation hors de l'écran.
	max_size = Vector2i(600, 520)
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(520, 340)
	root.add_theme_constant_override("separation", 7)
	add_child(root)
	root.add_child(_label("1. Point de départ"))
	template_option = OptionButton.new()
	for template in TEMPLATES:
		template_option.add_item(str((template as Array)[TEMPLATE_LABEL]))
	template_option.item_selected.connect(_on_template_selected)
	root.add_child(template_option)
	template_help = _info("")
	root.add_child(template_help)
	root.add_child(_label("2. Nom du sort"))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Nom français, visible pendant le combat"
	name_edit.text_changed.connect(_update_proposal)
	root.add_child(name_edit)
	root.add_child(_label("3. Identifiant technique (rempli automatiquement)"))
	id_edit = LineEdit.new()
	id_edit.editable = false
	id_edit.tooltip_text = "Généré à partir du nom, puis rendu unique dans le projet."
	root.add_child(id_edit)
	root.add_child(_label("4. Emplacement du fichier"))
	location_option = OptionButton.new()
	location_option.add_item("Ce personnage")
	location_option.add_item("Partagé (réutilisable par tout le projet)")
	location_option.tooltip_text = (
		"L’emplacement range le fichier. Dans les deux cas, le sort reste une "
		+ "Resource autonome qu’un autre personnage pourra référencer sans copie."
	)
	location_option.item_selected.connect(func(_index: int) -> void:
		_update_proposal(name_edit.text)
	)
	root.add_child(location_option)
	path_label = _info("")
	root.add_child(path_label)
	confirmed.connect(_confirm)
	_on_template_selected(0)


func open_dialog() -> void:
	name_edit.text = "Nouveau sort"
	location_option.select(0)
	template_option.select(0)
	_on_template_selected(0)
	_update_proposal(name_edit.text)
	popup_centered(Vector2i(560, 440))
	name_edit.grab_focus()
	name_edit.select_all()


func _on_template_selected(index: int) -> void:
	var template := TEMPLATES[clampi(index, 0, TEMPLATES.size() - 1)] as Array
	if template_help != null:
		template_help.text = str(template[TEMPLATE_HELP])
	_update_proposal(name_edit.text if name_edit != null else "")


func _update_proposal(value: String) -> void:
	if id_edit == null or path_label == null:
		return
	var spell_id := path_service.suggest_spell_id(
		value,
		_heroes,
		_unit.resource_path if _unit != null else "",
		_reserved_ids
	)
	id_edit.text = str(spell_id)
	path_label.text = "Fichier proposé : %s" % _draft_path(spell_id)


func _draft_path(spell_id: StringName) -> String:
	if _attaches_to_character():
		return path_service.character_draft_path(_unit, spell_id)
	return path_service.shared_draft_path(spell_id)


func _attaches_to_character() -> bool:
	return location_option == null or location_option.selected == 0


func _confirm() -> void:
	if _unit == null or name_edit.text.strip_edges().is_empty():
		return
	var template := TEMPLATES[
		clampi(template_option.selected, 0, TEMPLATES.size() - 1)
	] as Array
	spell_creation_requested.emit({
		"template": StringName(template[TEMPLATE_ID]),
		"display_name": name_edit.text.strip_edges(),
		"attach_to_character": _attaches_to_character(),
	})


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _info(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", MUTED)
	return label
