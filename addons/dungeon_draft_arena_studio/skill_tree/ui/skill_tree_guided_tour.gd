@tool
class_name SkillTreeGuidedTour
extends AcceptDialog

const PAGES := [
	{
		"title": "Bienvenue dans le Skill Studio",
		"body": "Vous allez modifier les vraies données du jeu sans ouvrir manuellement les fichiers .tres. Rien n’est écrit avant le bouton Sauvegarder.",
	},
	{
		"title": "Qu’est-ce qu’une discipline ?",
		"body": "Une discipline est un chemin de progression rattaché à un sort de base. Par exemple, Pyromancie regroupe les améliorations de Boule de feu.",
	},
	{
		"title": "Rang et XP",
		"body": "Un rang est une étape. Son seuil indique l’XP totale nécessaire. Passer de 5 XP au rang 2 à 12 XP au rang 3 demande donc 7 XP supplémentaires.",
	},
	{
		"title": "Branches et prérequis",
		"body": "Une branche est une suite de choix reliés. Une liaison signifie que le nœud précédent doit déjà être acquis. Plusieurs prérequis sont tous obligatoires : ils signifient ET.",
	},
	{
		"title": "Exclusions",
		"body": "Une exclusion empêche deux améliorations d’être possédées dans la même progression. Elle sert à créer des choix réellement différents.",
	},
	{
		"title": "Sort ciblé et modificateur",
		"body": "Le sort ciblé est le sort transformé. Le modificateur décrit la transformation : dégâts supplémentaires, portée, statut, poussée, soin ou autre effet existant.",
	},
	{
		"title": "Identifiants stables",
		"body": "Les identifiants techniques sont utilisés par les sauvegardes. Vous pouvez renommer l’affichage sans les changer. Ne modifiez un identifiant stable qu’après avoir lu le rapport de références.",
	},
	{
		"title": "Tester puis sauvegarder",
		"body": "Le simulateur ne touche jamais à une run réelle. Après validation, Sauvegarder écrit les Resources et crée d’abord un point de récupération.",
	},
]

var _page := 0
var _title_label: Label
var _body_label: Label
var _counter_label: Label
var _previous_button: Button
var _next_button: Button


func _ready() -> void:
	title = "Visite guidée du Studio des compétences"
	min_size = Vector2i(620, 360)
	get_ok_button().hide()
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.48, 0.86, 1.0))
	root.add_child(_title_label)
	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(570, 180)
	_body_label.add_theme_font_size_override("font_size", 15)
	root.add_child(_body_label)
	var footer := HBoxContainer.new()
	root.add_child(footer)
	_counter_label = Label.new()
	_counter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_counter_label)
	_previous_button = Button.new()
	_previous_button.text = "← Précédent"
	_previous_button.pressed.connect(func():
		_page = maxi(0, _page - 1)
		_refresh()
	)
	footer.add_child(_previous_button)
	_next_button = Button.new()
	_next_button.pressed.connect(_next)
	footer.add_child(_next_button)
	_refresh()


func start() -> void:
	_page = 0
	_refresh()
	popup_centered()


func _next() -> void:
	if _page >= PAGES.size() - 1:
		hide()
		return
	_page += 1
	_refresh()


func _refresh() -> void:
	if _title_label == null:
		return
	var page := PAGES[_page] as Dictionary
	_title_label.text = str(page.get("title", ""))
	_body_label.text = str(page.get("body", ""))
	_counter_label.text = "Étape %d sur %d" % [_page + 1, PAGES.size()]
	_previous_button.disabled = _page == 0
	_next_button.text = "Terminer" if _page == PAGES.size() - 1 else "Suivant →"
