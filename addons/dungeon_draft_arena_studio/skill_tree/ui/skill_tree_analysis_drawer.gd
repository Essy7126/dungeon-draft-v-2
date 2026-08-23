@tool
# addons/dungeon_draft_arena_studio/skill_tree/ui/skill_tree_analysis_drawer.gd
# ============================================================
# TIROIR D'ANALYSE DU STUDIO DES PERSONNAGES
#
# Même principe que le tiroir de l'éditeur d'objets : une simple barre
# tout en bas de l'écran, qui tient en une ligne, et qui ne déploie ses
# détails que si on le demande. L'écran de travail reste ainsi occupé
# par ce qu'on modifie, pas par des diagnostics qu'on ne lit pas.
# ============================================================

class_name SkillTreeAnalysisDrawer
extends VBoxContainer

signal expanded_changed(expanded: bool)

const ACCENT_COLOR := Color(0.48, 0.86, 1.0)

var summary_label: Label
var toggle_button: Button
var body: PanelContainer

var _expanded := false


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	add_child(_build_bar())
	body = PanelContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	_apply_expanded()


## Le panneau à onglets existant devient le contenu déployable du tiroir.
func attach_body(content: Control) -> void:
	if body == null or content == null:
		return
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(content)


func is_expanded() -> bool:
	return _expanded


func set_expanded(value: bool) -> void:
	if _expanded == value:
		return
	_expanded = value
	_apply_expanded()
	expanded_changed.emit(_expanded)


func open() -> void:
	set_expanded(true)


func _build_bar() -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var title := Label.new()
	title.text = "ANALYSE"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	row.add_child(title)
	summary_label = Label.new()
	summary_label.text = "Commencez par choisir un personnage."
	# clip_text évite qu'un message long impose sa largeur à toute la fenêtre.
	summary_label.clip_text = true
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(summary_label)
	toggle_button = Button.new()
	toggle_button.tooltip_text = (
		"Affiche ou masque les erreurs, statistiques, simulateur et analyses."
	)
	toggle_button.pressed.connect(func(): set_expanded(not _expanded))
	row.add_child(toggle_button)
	return panel


func _apply_expanded() -> void:
	if body != null:
		body.visible = _expanded
	if toggle_button != null:
		toggle_button.text = "Fermer ▾" if _expanded else "Ouvrir ▴"
	# Déployé, le tiroir réclame sa part de hauteur ; replié, il ne prend que
	# celle de sa barre.
	size_flags_vertical = Control.SIZE_EXPAND_FILL if _expanded \
		else Control.SIZE_SHRINK_END
