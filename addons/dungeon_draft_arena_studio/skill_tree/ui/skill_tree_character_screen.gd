@tool
# addons/dungeon_draft_arena_studio/skill_tree/ui/skill_tree_character_screen.gd
# ============================================================
# ÉCRAN D'ACCUEIL DU STUDIO DES PERSONNAGES
#
# Une seule intention : choisir sur quel personnage on va travailler.
# Tant que ce choix n'est pas fait, aucune donnée de personnage n'est
# affichée — c'est ce qui évite d'ouvrir le Studio sur un mur
# d'informations dont on n'a pas besoin sur le moment.
# ============================================================

class_name SkillTreeCharacterScreen
extends ScrollContainer

signal character_chosen(path: String)

const ACCENT_COLOR := Color(0.48, 0.86, 1.0)
const MUTED_COLOR := Color(0.72, 0.77, 0.84)
const WARNING_COLOR := Color(1.0, 0.72, 0.3)

var list_box: VBoxContainer

var _heroes: Array[Dictionary] = []
var _current_path := ""


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var centering := HBoxContainer.new()
	centering.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(centering)
	var spacer_left := Control.new()
	spacer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering.add_child(spacer_left)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 700
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 10)
	centering.add_child(column)
	var spacer_right := Control.new()
	spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering.add_child(spacer_right)
	var title := Label.new()
	title.text = "CHOISISSEZ UN PERSONNAGE"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	column.add_child(title)
	var help := Label.new()
	help.text = (
		"Le Studio ne vous montrera ensuite que ce personnage. "
		+ "Vous pourrez en changer à tout moment en revenant ici."
	)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", MUTED_COLOR)
	column.add_child(help)
	column.add_child(HSeparator.new())
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 14)
	column.add_child(list_box)
	_rebuild()


func set_catalog(heroes: Array[Dictionary], current_path: String) -> void:
	_heroes = heroes
	_current_path = current_path
	_rebuild()


func _rebuild() -> void:
	if list_box == null:
		return
	for child in list_box.get_children():
		list_box.remove_child(child)
		child.queue_free()
	if _heroes.is_empty():
		var empty := Label.new()
		empty.text = (
			"Aucun personnage trouvé. Un personnage est un fichier déposé "
			+ "dans data/units/alliés/ ou data/units/ennemie/, avec Équipe "
			+ "réglée sur Joueur ou Ennemi."
		)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", WARNING_COLOR)
		list_box.add_child(empty)
		return
	# Jouables et ennemis sont séparés : on cherche rarement les deux en même
	# temps, et les mélanger obligerait à lire chaque ligne pour se repérer.
	var players: Array[Dictionary] = []
	var enemies: Array[Dictionary] = []
	for hero in _heroes:
		if bool(hero.get("is_enemy", false)):
			enemies.append(hero)
		else:
			players.append(hero)
	_build_group("PERSONNAGES JOUABLES", players)
	_build_group("ENNEMIS", enemies)


func _build_group(title_text: String, group: Array[Dictionary]) -> void:
	if group.is_empty():
		return
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	list_box.add_child(title)
	for hero in group:
		_build_card(hero)


func _build_card(hero: Dictionary) -> void:
	var path := str(hero.get("path", ""))
	var is_current := not path.is_empty() and path == _current_path
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)
	list_box.add_child(card)
	var button := Button.new()
	button.text = "%s%s" % [
		str(hero.get("name", "Personnage")),
		"   ·   en cours" if is_current else "",
	]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 52
	button.add_theme_font_size_override("font_size", 18)
	if is_current:
		button.add_theme_color_override("font_color", ACCENT_COLOR)
	button.tooltip_text = "Travailler sur %s" % str(hero.get("name", "ce personnage"))
	button.pressed.connect(func(): character_chosen.emit(path))
	card.add_child(button)
	var details := Label.new()
	details.text = _describe(hero)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_color_override(
		"font_color", WARNING_COLOR if bool(hero.get("invalid", false)) else MUTED_COLOR
	)
	card.add_child(details)


func _describe(hero: Dictionary) -> String:
	var parts := PackedStringArray()
	if bool(hero.get("is_enemy", false)):
		# Les disciplines sont une notion de personnage jouable : pour un
		# ennemi, ce sont ses sorts qui renseignent.
		var spells := int(hero.get("spell_count", 0))
		parts.append(
			"aucun sort" if spells == 0
			else ("1 sort" if spells == 1 else "%d sorts" % spells)
		)
	else:
		var disciplines := int(hero.get("discipline_count", 0))
		parts.append(
			"aucune discipline" if disciplines == 0
			else ("1 discipline" if disciplines == 1 else "%d disciplines" % disciplines)
		)
	parts.append(_describe_animations(hero.get("resource") as UnitData))
	if bool(hero.get("outside_run", false)) and not bool(hero.get("is_enemy", false)):
		parts.append("ne fait pas partie de la partie en cours")
	if bool(hero.get("invalid", false)):
		parts.append("⚠ contient une erreur à corriger")
	return "   ·   ".join(parts)


func _describe_animations(unit: UnitData) -> String:
	var total := CharacterVisual3D.ACTION_ORDER.size()
	if unit == null or unit.animation_set == null:
		return "aucune animation réglée"
	var configured := unit.animation_set.configured_action_ids().size()
	if configured == 0:
		return "aucune animation réglée"
	return "%d animations réglées sur %d" % [configured, total]
