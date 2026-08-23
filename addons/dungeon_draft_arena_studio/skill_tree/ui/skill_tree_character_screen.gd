@tool
class_name SkillTreeCharacterScreen
extends HSplitContainer

## Fiche unifiee d'une UnitData. Ce controle ne modifie jamais directement la
## Resource : toutes les editions sont emises vers la SkillTreeEditSession.

signal character_chosen(path: String)
signal property_change_requested(
	target: Object, property_name: StringName, value: Variant, action_name: String
)
signal team_change_requested(unit: UnitData, team: int)
signal spell_edit_requested(spell: Spell)
signal spell_tree_requested(discipline_id: StringName)
signal spell_creation_requested
signal existing_spell_requested(spell: Spell)
signal spell_detach_requested(spell: Spell)

const TAB_NAMES := [
	"Identité", "Combat", "Défenses", "Sorts", "Pilotage", "Présentation", "Avancé",
]
const ACCENT := Color(0.48, 0.86, 1.0)
const MUTED := Color(0.72, 0.77, 0.84)
const WARNING := Color(1.0, 0.72, 0.3)
const ERROR := Color(1.0, 0.48, 0.42)

const COMBAT_FIELDS := [
	[&"max_hp", "PV maximum", "int", 1.0, 99999.0, 1.0],
	[&"initiative", "Initiative", "int", 0.0, 9999.0, 1.0],
	[&"max_ap", "PA maximum", "int", 0.0, 99.0, 1.0],
	[&"max_mp", "PM maximum", "int", 0.0, 99.0, 1.0],
	[&"attack_power", "Puissance d’attaque", "int", 0.0, 9999.0, 1.0],
	[&"force", "Force de déplacement", "float", 0.0, 9999.0, 0.5],
	[&"control_level", "Niveau de contrôle", "enum"],
]
const DEFENSE_FIELDS := [
	[&"armure", "Armure", "float", 0.0, 1000.0, 1.0],
	[&"resist_magique", "Résistance magique", "float", 0.0, 1000.0, 1.0],
	[&"esquive", "Esquive", "percent", 0.0, 100.0, 1.0],
	[&"crit_chance", "Chance critique", "percent", 0.0, 100.0, 1.0],
	[&"crit_multi", "Multiplicateur critique", "float", 1.0, 10.0, 0.05],
]
const AI_FIELDS := [
	[&"ai_behavior", "Comportement", "enum"],
	[&"combat_style", "Style de combat", "enum"],
	[&"preferred_range", "Distance préférée", "int", 1.0, 20.0, 1.0],
	[&"minimum_range", "Distance minimale", "int", 1.0, 20.0, 1.0],
	[&"maximum_range", "Distance maximale", "int", 1.0, 20.0, 1.0],
	[&"keep_distance", "Maintenir la distance", "bool"],
]
const COMMON_TACTICAL_FIELDS := [
	[&"proximity_armor_source", "Source d’armure de proximité", "line"],
	[&"proximity_armor_per_living_neighbor", "Armure par voisin vivant", "int", 0.0, 9999.0, 1.0],
	[&"proximity_armor_max_neighbors", "Voisins pris en compte", "int", 0.0, 99.0, 1.0],
	[&"first_forced_movement_reduction_per_activation", "Réduction du premier déplacement forcé", "int", 0.0, 99.0, 1.0],
]

var search_edit: LineEdit
var character_list: VBoxContainer
var tabs: TabContainer
var summary_box: VBoxContainer
var _tab_boxes: Dictionary = {}
var _heroes: Array[Dictionary] = []
var _current_path := ""
var _unit: UnitData = null
var _messages: Array[SkillTreeValidationMessage] = []
var _guided := true
var _selected_spell: Spell = null
var _editing_spell: Spell = null
## Sorts partagés créés dans la session en cours : ils n'appartiennent encore à
## aucun personnage, mais doivent rester visibles pour pouvoir être rattachés.
var _standalone_spells: Array[Spell] = []
var picker_dialog: AcceptDialog
var picker_filter: LineEdit
var picker_list: ItemList
var _picker_entries: Array[Dictionary] = []


func _ready() -> void:
	split_offset = 280
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_build_catalog())
	var content := HSplitContainer.new()
	content.split_offset = -300
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_build_sheet())
	content.add_child(_build_summary())
	add_child(content)
	_build_spell_picker()
	_rebuild_catalog()
	_refresh_sheet()


func set_catalog(heroes: Array[Dictionary], current_path: String) -> void:
	_heroes = heroes
	_current_path = current_path
	_rebuild_catalog()


## `standalone` liste les sorts partagés créés dans la session : ils ne figurent
## dans aucune liste de personnage, et disparaîtraient de l'écran sans cela.
func set_document(
		unit: UnitData,
		current_path: String,
		messages: Array[SkillTreeValidationMessage],
		guided: bool,
		standalone: Array[Spell] = []
	) -> void:
	_unit = unit
	_current_path = current_path
	_messages = messages
	_guided = guided
	_standalone_spells = standalone.duplicate()
	if _selected_spell == null or unit == null or not unit.spells.has(_selected_spell):
		_selected_spell = null
		_editing_spell = null
	elif _editing_spell != null and not unit.spells.has(_editing_spell):
		_editing_spell = null
	_refresh_sheet()
	_rebuild_catalog()


func set_guided(value: bool) -> void:
	_guided = value
	_refresh_sheet()


func select_spell(spell: Spell, edit := false) -> void:
	_selected_spell = spell if _unit != null and _unit.spells.has(spell) else null
	_editing_spell = _selected_spell if edit else null
	if tabs != null:
		tabs.current_tab = TAB_NAMES.find("Sorts")
	_refresh_sheet()


func commit_pending_edits() -> void:
	var focused := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()


func _build_catalog() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 250
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_heading("PERSONNAGES"))
	var help := _info("Choisissez le personnage dont vous voulez ouvrir la fiche.")
	box.add_child(help)
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Rechercher un personnage…"
	search_edit.text_changed.connect(func(_value: String) -> void: _rebuild_catalog())
	box.add_child(search_edit)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	character_list = VBoxContainer.new()
	character_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(character_list)
	return panel


func _build_sheet() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_heading("FICHE DU PERSONNAGE"))
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	for tab_name in TAB_NAMES:
		var scroll := ScrollContainer.new()
		scroll.name = tab_name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(scroll)
		var tab_box := VBoxContainer.new()
		tab_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_box.add_theme_constant_override("separation", 9)
		scroll.add_child(tab_box)
		_tab_boxes[tab_name] = tab_box
	return panel


func _build_summary() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 270
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	summary_box = VBoxContainer.new()
	summary_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(summary_box)
	return panel


func _rebuild_catalog() -> void:
	if character_list == null:
		return
	_clear(character_list)
	var query := search_edit.text.strip_edges().to_lower() if search_edit != null else ""
	var groups := {"PERSONNAGES JOUABLES": [], "ENNEMIS": []}
	for entry in _heroes:
		var unit := entry.get("resource") as UnitData
		var display_name := str(entry.get("name", unit.unit_name if unit != null else "Personnage"))
		if not query.is_empty() \
				and not display_name.to_lower().contains(query) \
				and (unit == null \
				or not str(unit.get_effective_unit_id()).to_lower().contains(query)):
			continue
		var is_current := str(entry.get("path", "")) == _current_path
		var is_enemy := _unit.team == 1 if is_current and _unit != null \
			else bool(entry.get("is_enemy", unit != null and unit.team == 1))
		var group_name := "ENNEMIS" if is_enemy else "PERSONNAGES JOUABLES"
		(groups[group_name] as Array).append(entry)
	for group_name in groups:
		var entries := groups[group_name] as Array
		if entries.is_empty():
			continue
		character_list.add_child(_section(str(group_name)))
		for entry in entries:
			_add_character_button(entry as Dictionary)
	if character_list.get_child_count() == 0:
		character_list.add_child(_warning("Aucun personnage ne correspond à la recherche."))


func _add_character_button(entry: Dictionary) -> void:
	var path := str(entry.get("path", ""))
	var current := not path.is_empty() and path == _current_path
	var unit := entry.get("resource") as UnitData
	var button := Button.new()
	button.text = "%s%s" % [
		str(entry.get("name", unit.unit_name if unit != null else "Personnage")),
		"  ·  EN COURS" if current else "",
	]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggle_mode = true
	button.button_pressed = current
	if current:
		button.add_theme_color_override("font_color", ACCENT)
	button.pressed.connect(func() -> void: character_chosen.emit(path))
	character_list.add_child(button)


func _refresh_sheet() -> void:
	if tabs == null:
		return
	for box_value in _tab_boxes.values():
		_clear(box_value as Node)
	_clear(summary_box)
	if _unit == null:
		_box("Identité").add_child(_info(
			"Sélectionnez un personnage dans le catalogue pour ouvrir sa fiche complète."
		))
		summary_box.add_child(_heading("APERÇU"))
		_summary("Sélection", "Aucun personnage")
		_update_advanced_visibility()
		return
	_build_identity()
	_build_fields(_box("Combat"), "CARACTÉRISTIQUES DE COMBAT", COMBAT_FIELDS)
	_build_fields(_box("Défenses"), "PROTECTION", DEFENSE_FIELDS)
	_build_resistances()
	_build_spells()
	_build_piloting()
	_build_presentation()
	_build_advanced()
	_build_summary_content()
	_update_advanced_visibility()


func _build_identity() -> void:
	var box := _box("Identité")
	box.add_child(_section("IDENTITÉ"))
	_add_line(box, &"unit_name", "Nom")
	_add_multiline(box, &"description", "Description")
	var field := _field(box, "Équipe")
	var option := OptionButton.new()
	option.add_item("Personnage jouable")
	option.add_item("Ennemi")
	option.select(clampi(_unit.team, 0, 1))
	option.tooltip_text = "Une confirmation est obligatoire car le classement peut changer."
	option.item_selected.connect(func(index: int) -> void:
		if index != _unit.team:
			team_change_requested.emit(_unit, index)
			option.select(clampi(_unit.team, 0, 1))
	)
	field.add_child(option)


func _build_fields(parent: VBoxContainer, title_text: String, specs: Array) -> void:
	parent.add_child(_section(title_text))
	for spec_value in specs:
		var spec := spec_value as Array
		var property_name := StringName(spec[0])
		var label_text := str(spec[1])
		match str(spec[2]):
			"line":
				_add_line(parent, property_name, label_text)
			"bool":
				_add_bool(parent, property_name, label_text)
			"enum":
				_add_enum(parent, property_name, label_text)
			"int", "float", "percent":
				_add_number(
					parent, property_name, label_text, str(spec[2]),
					float(spec[3]), float(spec[4]), float(spec[5])
				)


func _build_resistances() -> void:
	var box := _box("Défenses")
	box.add_child(HSeparator.new())
	box.add_child(_section("RÉSISTANCES ÉLÉMENTAIRES"))
	box.add_child(_info("Une valeur négative est une vulnérabilité."))
	for element_value in Spell.Element.values():
		var element := int(element_value)
		if element == int(Spell.Element.NONE):
			continue
		var row := HBoxContainer.new()
		box.add_child(row)
		var label := Label.new()
		label.text = _element_label(element)
		label.custom_minimum_size.x = 150
		row.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = -100.0
		spin.max_value = 100.0
		spin.suffix = " %"
		spin.allow_lesser = true
		spin.value = float(_unit.resistances.get(element, 0.0)) * 100.0
		row.add_child(spin)
		var original := spin.value
		var commit := func() -> void:
			if is_equal_approx(spin.value, original):
				return
			var changed := _unit.resistances.duplicate(true)
			var ratio := spin.value / 100.0
			if is_zero_approx(ratio):
				changed.erase(element)
			else:
				changed[element] = ratio
			_emit_change(&"resistances", changed, "Modifier la résistance %s" % label.text)
			original = spin.value
		spin.get_line_edit().focus_exited.connect(commit)


func _build_spells() -> void:
	var box := _box("Sorts")
	_add_bool(box, &"basic_attack_enabled", "Attaque de base disponible")
	_add_number(box, &"active_spell_slots", "Emplacements de sorts actifs", "int", 1.0, 12.0, 1.0)
	box.add_child(_section("SORTS CONNUS"))
	# Seul endroit du Studio où l'on crée, référence et retire un sort. La liste
	# est générique : elle vaut pour un héros comme pour un ennemi, qu'il ait ou
	# non des disciplines.
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 6)
	box.add_child(actions)
	var create := Button.new()
	create.text = "+ Nouveau sort"
	create.tooltip_text = "Créer un sort à partir d’un modèle de départ."
	create.pressed.connect(func() -> void: spell_creation_requested.emit())
	actions.add_child(create)
	var attach := Button.new()
	attach.text = "+ Ajouter un sort existant"
	attach.tooltip_text = "Référencer un sort déjà écrit ailleurs dans le projet, sans en faire de copie."
	attach.pressed.connect(_open_spell_picker)
	actions.add_child(attach)
	if _unit.spells.is_empty():
		box.add_child(_info("Aucun sort n’est associé à ce personnage."))
	var owner_counts := _spell_owner_counts()
	for spell in _unit.spells:
		if spell == null:
			box.add_child(_warning("Une entrée de sort est vide."))
			continue
		var select := Button.new()
		select.text = "%s  ·  %d PA" % [spell.spell_name, spell.ap_cost]
		select.alignment = HORIZONTAL_ALIGNMENT_LEFT
		select.toggle_mode = true
		select.button_pressed = spell == _selected_spell
		select.tooltip_text = _spell_summary(spell)
		select.pressed.connect(func() -> void:
			_selected_spell = spell
			_editing_spell = null
			_refresh_sheet.call_deferred()
		)
		box.add_child(select)
		_add_spell_badges(box, spell, owner_counts)
	if _selected_spell != null:
		_add_spell_actions(box, _selected_spell)
		if _editing_spell == _selected_spell:
			_build_spell_editor(box, _selected_spell)
	if _standalone_spells.is_empty():
		return
	box.add_child(HSeparator.new())
	box.add_child(_section("SORTS PARTAGÉS CRÉÉS DANS CETTE SESSION"))
	box.add_child(_info(
		"Ces sorts n’appartiennent encore à aucun personnage. Ils seront écrits dans le dossier partagé à la prochaine sauvegarde ; ajoutez-les ici si ce personnage doit pouvoir les lancer."
	))
	for spell in _standalone_spells:
		if spell == null:
			continue
		var row := HBoxContainer.new()
		box.add_child(row)
		var label := Label.new()
		label.text = spell.spell_name
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		row.add_child(label)
		var adopt := Button.new()
		adopt.text = "Ajouter à ce personnage"
		adopt.tooltip_text = "Référence le même fichier : aucune copie n’est créée."
		adopt.pressed.connect(func() -> void: existing_spell_requested.emit(spell))
		row.add_child(adopt)


## Pastilles de sécurité : elles préviennent avant de modifier un sort dont
## dépend autre chose. Les effets s'appuient sur les méthodes déjà portées par
## Spell plutôt que sur une relecture des champs bruts.
func _add_spell_badges(
		parent: VBoxContainer, spell: Spell, owner_counts: Dictionary
	) -> void:
	var labels := PackedStringArray()
	if spell.deals_damage():
		labels.append("Dégâts")
	if spell.is_healing():
		labels.append("Soin")
	if spell.has_terrain_effect():
		labels.append("Terrain")
	if spell.applied_status != null:
		labels.append("Statut")
	if spell.is_summon():
		labels.append("Invocation")
	var discipline := _base_spell_discipline(spell)
	if discipline != null:
		labels.append("Arbre — %s" % discipline.display_name)
	var owners := int(owner_counts.get(spell.resource_path, 0))
	if owners > 1:
		labels.append("Partagé · %d personnages" % owners)
	if spell.resource_path.begins_with(
			SpellIdPathService.SHARED_SPELL_DIRECTORY + "/"
		):
		labels.append("Dossier partagé")
	if labels.is_empty():
		return
	var badges := HFlowContainer.new()
	badges.add_theme_constant_override("h_separation", 4)
	badges.add_theme_constant_override("v_separation", 3)
	parent.add_child(badges)
	for text in labels:
		badges.add_child(_badge(str(text)))


## Combien de personnages du projet référencent chaque fichier de sort.
## SkillTreeReferenceIndex.shared_resources() ne répond pas à cette question :
## son index est construit personnage par personnage, donc un sort référencé une
## seule fois par le personnage ouvert n'y apparaît jamais, même si trois autres
## personnages l'utilisent. Le catalogue est déjà chargé : aucune relecture disque.
func _spell_owner_counts() -> Dictionary:
	var counts := {}
	for entry in _heroes:
		var unit := entry.get("resource") as UnitData
		if unit == null:
			continue
		var seen := {}
		for spell in unit.spells:
			if spell == null or spell.resource_path.is_empty() \
					or seen.has(spell.resource_path):
				continue
			seen[spell.resource_path] = true
			counts[spell.resource_path] = int(
				counts.get(spell.resource_path, 0)
			) + 1
	return counts


func _base_spell_discipline(spell: Spell) -> DisciplineData:
	return spell.skill_tree if spell != null else null


func _build_spell_picker() -> void:
	picker_dialog = AcceptDialog.new()
	picker_dialog.title = "Ajouter un sort existant"
	picker_dialog.ok_button_text = "Ajouter au personnage"
	picker_dialog.min_size = Vector2i(520, 420)
	# Sans plafond, la liste et le libellé en retour à la ligne automatique
	# gonflent la hauteur demandée et poussent le bouton hors de l'écran.
	picker_dialog.max_size = Vector2i(600, 620)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(480, 360)
	picker_dialog.add_child(box)
	box.add_child(_info(
		"Le sort choisi est référencé tel quel : le même fichier servira aux deux personnages, et une modification profitera à tous."
	))
	picker_filter = LineEdit.new()
	picker_filter.placeholder_text = "Rechercher un sort…"
	picker_filter.text_changed.connect(func(_value: String) -> void: _rebuild_spell_picker())
	box.add_child(picker_filter)
	picker_list = ItemList.new()
	picker_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# ItemList avale les retours à la ligne hors ICON_MODE_TOP : l'identifiant et
	# le chemin passent par l'info-bulle, jamais par une deuxième ligne.
	box.add_child(picker_list)
	picker_dialog.confirmed.connect(_confirm_spell_picker)
	add_child(picker_dialog)


func _open_spell_picker() -> void:
	if _unit == null or picker_dialog == null:
		return
	var known := {}
	for spell in _unit.spells:
		if spell != null:
			known[str(spell.get_effective_spell_id())] = true
	_picker_entries.clear()
	for entry in SkillTreeCatalogService.all_project_spells():
		if known.has(str(entry.get("spell_id", &""))):
			continue
		_picker_entries.append(entry)
	picker_filter.text = ""
	_rebuild_spell_picker()
	picker_dialog.popup_centered(Vector2i(560, 460))


func _rebuild_spell_picker() -> void:
	if picker_list == null:
		return
	picker_list.clear()
	var query := picker_filter.text.strip_edges().to_lower() if picker_filter != null else ""
	for entry in _picker_entries:
		var display_name := str(entry.get("spell_name", ""))
		var spell_id := str(entry.get("spell_id", ""))
		if not query.is_empty() and not display_name.to_lower().contains(query) \
				and not spell_id.to_lower().contains(query):
			continue
		var index := picker_list.add_item(display_name)
		picker_list.set_item_metadata(index, entry)
		picker_list.set_item_tooltip(
			index, "%s\n%s" % [spell_id, str(entry.get("path", ""))]
		)
	if picker_list.item_count > 0:
		picker_list.select(0)
	else:
		picker_list.add_item("Aucun sort disponible")
		picker_list.set_item_disabled(0, true)


func _confirm_spell_picker() -> void:
	if picker_list == null:
		return
	var selected := picker_list.get_selected_items()
	if selected.is_empty():
		return
	var metadata = picker_list.get_item_metadata(selected[0])
	if not metadata is Dictionary:
		return
	var spell := (metadata as Dictionary).get("spell") as Spell
	if spell != null:
		existing_spell_requested.emit(spell)


func _badge(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", MUTED)
	# Sans SHRINK, la pastille peindrait toute la cellule du conteneur.
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.22, 0.28, 1.0)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	label.add_theme_stylebox_override("normal", style)
	return label


func _add_spell_actions(parent: VBoxContainer, spell: Spell) -> void:
	parent.add_child(HSeparator.new())
	parent.add_child(_section("SORT SÉLECTIONNÉ · %s" % spell.spell_name.to_upper()))
	var actions := HFlowContainer.new()
	parent.add_child(actions)
	var edit := Button.new()
	edit.text = "Modifier le sort"
	edit.pressed.connect(func() -> void:
		_editing_spell = spell
		spell_edit_requested.emit(spell)
		_refresh_sheet.call_deferred()
	)
	actions.add_child(edit)
	var remove := Button.new()
	remove.text = "Retirer de ce personnage"
	remove.tooltip_text = "Retire le sort et l’accès à son arbre pour ce personnage. Les fichiers restent sur le disque, et les autres personnages ne changent pas."
	remove.pressed.connect(func() -> void: spell_detach_requested.emit(spell))
	actions.add_child(remove)
	var discipline := _discipline_for_spell(spell)
	if discipline == null:
		parent.add_child(_info("Aucun arbre de progression associé à ce sort."))
		return
	var tree := Button.new()
	tree.text = "Ouvrir l’arbre de progression"
	tree.pressed.connect(func() -> void: spell_tree_requested.emit(discipline.discipline_id))
	actions.add_child(tree)


func _build_spell_editor(parent: VBoxContainer, spell: Spell) -> void:
	parent.add_child(HSeparator.new())
	parent.add_child(_section("MODIFICATION DU SORT"))
	_add_target_line(parent, spell, &"spell_name", "Nom du sort")
	_add_target_multiline(parent, spell, &"description", "Description")
	_add_target_line(parent, spell, &"spell_id", "Identifiant stable du sort")
	_add_target_resource(parent, spell, &"skill_tree", "Arbre de progression", "DisciplineData")
	parent.add_child(_section("COÛT ET PORTÉE"))
	_add_target_number(parent, spell, &"ap_cost", "Coût en PA", "int", 0.0, 99.0, 1.0)
	_add_target_number(parent, spell, &"minimum_range", "Portée minimale", "int", 0.0, 99.0, 1.0)
	_add_target_number(parent, spell, &"spell_range", "Portée maximale", "int", 0.0, 99.0, 1.0)
	_add_target_bool(parent, spell, &"needs_line_of_sight", "Ligne de vue nécessaire")
	_add_target_number(parent, spell, &"cooldown_activations", "Temps de recharge", "int", 0.0, 99.0, 1.0)
	_add_target_number(parent, spell, &"max_uses_per_combat", "Utilisations maximales", "int", 0.0, 999.0, 1.0)
	_add_target_bool(parent, spell, &"once_per_activation", "Une fois par activation")
	parent.add_child(_section("CIBLES"))
	_add_target_bool(parent, spell, &"can_target_enemy", "Cibler les ennemis")
	_add_target_bool(parent, spell, &"can_target_ally", "Cibler les alliés")
	_add_target_bool(parent, spell, &"can_target_self", "Se cibler soi-même")
	_add_target_bool(parent, spell, &"can_target_free_cell", "Cibler une case libre")
	parent.add_child(_section("EFFETS PRINCIPAUX"))
	_add_target_number(parent, spell, &"damage", "Dégâts de base", "int", 0.0, 99999.0, 1.0)
	_add_target_number(parent, spell, &"heal", "Soin de base", "int", 0.0, 99999.0, 1.0)
	_add_target_enum(parent, spell, &"damage_type", "Type de dégâts")
	_add_target_enum(parent, spell, &"element", "Élément")
	_add_target_number(parent, spell, &"crit_chance", "Chance critique du sort", "percent", 0.0, 100.0, 1.0)
	_add_target_number(parent, spell, &"push_distance", "Distance de poussée", "int", 0.0, 99.0, 1.0)
	_add_target_number(parent, spell, &"pull_distance", "Distance d’attraction", "int", 0.0, 99.0, 1.0)
	_add_target_number(parent, spell, &"shield_grant", "Bouclier accordé", "int", 0.0, 99999.0, 1.0)
	parent.add_child(_section("PRÉSENTATION DU SORT"))
	_add_target_resource(parent, spell, &"icon", "Icône", "Texture2D")
	_add_target_resource(parent, spell, &"vfx_scene", "Effet visuel", "PackedScene")
	_add_target_resource(parent, spell, &"sound_cast", "Son de lancement", "AudioStream")
	var close := Button.new()
	close.text = "Terminer la modification du sort"
	close.pressed.connect(func() -> void:
		_editing_spell = null
		_refresh_sheet.call_deferred()
	)
	parent.add_child(close)


func _build_piloting() -> void:
	var box := _box("Pilotage")
	box.add_child(_section("MODE"))
	_add_readonly(box, "Mode de pilotage", "Pilotage joueur" if _unit.team == 0 else "Intelligence artificielle")
	if _unit.team == 1:
		_build_fields(box, "DÉCISIONS DE L’IA", AI_FIELDS)
		_add_resource(box, &"ai_profile", "Profil d’IA", "EnemyAIProfile")
		var actions := HFlowContainer.new()
		box.add_child(actions)
		for label_text in ["Choisir", "Créer", "Modifier", "Dupliquer", "Retirer"]:
			var button := Button.new()
			button.text = label_text
			button.disabled = true
			button.tooltip_text = "Action prévue avec le futur catalogue de profils d’IA."
			actions.add_child(button)
	_build_fields(box, "RÈGLES TACTIQUES COMMUNES", COMMON_TACTICAL_FIELDS)


func _build_presentation() -> void:
	var box := _box("Présentation")
	box.add_child(_section("LANGAGE JOUEUR"))
	_add_line(box, &"role", "Rôle")
	_add_multiline(box, &"presentation_summary", "Résumé de présentation")
	_add_line(box, &"progression_summary", "Résumé de progression")
	_add_line(box, &"presentation_badge", "Badge")
	box.add_child(_section("VISUEL"))
	_add_resource(box, &"sprite_frames", "Animations 2D", "SpriteFrames")
	_add_number(box, &"sprite_scale", "Échelle du sprite", "float", 0.01, 100.0, 0.05)
	_add_line(box, &"idle_animation", "Animation de repos 2D")
	_add_resource(box, &"visual_scene", "Scène visuelle", "PackedScene")
	_add_resource(box, &"preview_visual_scene", "Scène de présentation", "PackedScene")
	_add_readonly(box, "Fiche d’animations", _resource_label(_unit.animation_set))
	box.add_child(_info("L’éditeur complet des animations reste dans l’espace Animations."))


func _build_advanced() -> void:
	var box := _box("Avancé")
	box.add_child(_section("IDENTIFIANTS TECHNIQUES"))
	for spec in [
		[&"unit_id", "Identifiant du personnage"],
		[&"faction_id", "Faction"],
		[&"tactical_role_id", "Rôle tactique"],
		[&"linked_commander_role_id", "Rôle de commandant lié"],
	]:
		_add_line(box, StringName(spec[0]), str(spec[1]))
	_add_vector2i(box, &"facing_dir", "Direction initiale")
	box.add_child(_section("STOCKAGE"))
	_add_readonly(box, "Chemin", _unit.resource_path if not _unit.resource_path.is_empty() else "Resource non enregistrée")


func _build_summary_content() -> void:
	summary_box.add_child(_heading("APERÇU"))
	var name := Label.new()
	name.text = _unit.unit_name
	name.add_theme_font_size_override("font_size", 20)
	summary_box.add_child(name)
	_summary("Équipe", "Personnage jouable" if _unit.team == 0 else "Ennemi")
	_summary("Pilotage", "Joueur" if _unit.team == 0 else "Intelligence artificielle")
	summary_box.add_child(HSeparator.new())
	for pair in [["PV", _unit.max_hp], ["PA", _unit.max_ap], ["PM", _unit.max_mp],
			["Initiative", _unit.initiative], ["Sorts", _unit.spells.size()]]:
		_summary(str(pair[0]), str(pair[1]))
	var errors := 0
	var warnings := 0
	for message in _messages:
		if message.is_error():
			errors += 1
		else:
			warnings += 1
	var status := Label.new()
	status.text = "Validation · %s" % (
		"aucun problème" if errors == 0 and warnings == 0
		else "%d erreur(s), %d avertissement(s)" % [errors, warnings]
	)
	status.add_theme_color_override("font_color", ERROR if errors > 0 else WARNING if warnings > 0 else ACCENT)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_box.add_child(status)


func _add_line(parent: VBoxContainer, property_name: StringName, label_text: String) -> void:
	_add_target_line(parent, _unit, property_name, label_text)


func _add_target_line(
		parent: VBoxContainer, target: Object, property_name: StringName, label_text: String
	) -> void:
	var edit := LineEdit.new()
	edit.text = str(target.get(property_name))
	_field(parent, label_text).add_child(edit)
	var original := edit.text
	var commit := func() -> void:
		if edit.text == original:
			return
		var current: Variant = target.get(property_name)
		var value: Variant = StringName(edit.text.strip_edges()) if current is StringName else edit.text
		_emit_target_change(target, property_name, value, "Modifier %s" % label_text)
		original = edit.text
	edit.text_submitted.connect(func(_text: String) -> void: commit.call())
	edit.focus_exited.connect(commit)


func _add_multiline(parent: VBoxContainer, property_name: StringName, label_text: String) -> void:
	_add_target_multiline(parent, _unit, property_name, label_text)


func _add_target_multiline(
		parent: VBoxContainer, target: Object, property_name: StringName, label_text: String
	) -> void:
	var edit := TextEdit.new()
	edit.text = str(target.get(property_name))
	edit.custom_minimum_size.y = 90
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_field(parent, label_text).add_child(edit)
	var original := edit.text
	edit.focus_exited.connect(func() -> void:
		if edit.text != original:
			_emit_target_change(target, property_name, edit.text, "Modifier %s" % label_text)
			original = edit.text
	)


func _add_number(
		parent: VBoxContainer, property_name: StringName, label_text: String,
		kind: String, minimum: float, maximum: float, step: float
	) -> void:
	_add_target_number(
		parent, _unit, property_name, label_text, kind, minimum, maximum, step
	)


func _add_target_number(
		parent: VBoxContainer, target: Object, property_name: StringName,
		label_text: String, kind: String, minimum: float, maximum: float, step: float
	) -> void:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.allow_greater = true
	var percent := kind == "percent"
	spin.suffix = " %" if percent else ""
	spin.value = float(target.get(property_name)) * (100.0 if percent else 1.0)
	_field(parent, label_text).add_child(spin)
	var original := spin.value
	var commit := func() -> void:
		if is_equal_approx(spin.value, original):
			return
		var value: Variant
		if percent:
			value = spin.value / 100.0
		elif kind == "int":
			value = int(spin.value)
		else:
			value = spin.value
		_emit_target_change(target, property_name, value, "Modifier %s" % label_text)
		original = spin.value
	spin.get_line_edit().focus_exited.connect(commit)


func _add_bool(parent: VBoxContainer, property_name: StringName, label_text: String) -> void:
	_add_target_bool(parent, _unit, property_name, label_text)


func _add_target_bool(
		parent: VBoxContainer, target: Object, property_name: StringName, label_text: String
	) -> void:
	var check := CheckBox.new()
	check.text = label_text
	check.button_pressed = bool(target.get(property_name))
	check.toggled.connect(func(value: bool) -> void:
		_emit_target_change(target, property_name, value, "Modifier %s" % label_text)
	)
	parent.add_child(check)


func _add_enum(parent: VBoxContainer, property_name: StringName, label_text: String) -> void:
	_add_target_enum(parent, _unit, property_name, label_text)


func _add_target_enum(
		parent: VBoxContainer, target: Object, property_name: StringName, label_text: String
	) -> void:
	var option := OptionButton.new()
	var hint := ""
	for property in target.get_property_list():
		if StringName(property.get("name", &"")) == property_name:
			hint = str(property.get("hint_string", ""))
			break
	for entry in hint.split(",", false):
		var parts := entry.split(":", false, 1)
		var value := int(parts[1]) if parts.size() > 1 else option.item_count
		option.add_item(str(parts[0]))
		option.set_item_metadata(option.item_count - 1, value)
		if value == int(target.get(property_name)):
			option.select(option.item_count - 1)
	option.item_selected.connect(func(index: int) -> void:
		_emit_target_change(
			target, property_name, int(option.get_item_metadata(index)),
			"Modifier %s" % label_text
		)
	)
	_field(parent, label_text).add_child(option)


func _add_resource(
		parent: VBoxContainer, property_name: StringName, label_text: String, base_type: String
	) -> void:
	_add_target_resource(parent, _unit, property_name, label_text, base_type)


func _add_target_resource(
		parent: VBoxContainer, target: Object, property_name: StringName,
		label_text: String, base_type: String
	) -> void:
	var field := _field(parent, label_text)
	if not Engine.is_editor_hint():
		_add_readonly(field, "Resource", _resource_label(target.get(property_name) as Resource))
		return
	var picker := EditorResourcePicker.new()
	picker.base_type = base_type
	picker.edited_resource = target.get(property_name) as Resource
	picker.resource_changed.connect(func(resource: Resource) -> void:
		_emit_target_change(target, property_name, resource, "Modifier %s" % label_text)
	)
	field.add_child(picker)


func _add_readonly(parent: VBoxContainer, label_text: String, value: String) -> void:
	var edit := LineEdit.new()
	edit.text = value
	edit.editable = false
	_field(parent, label_text).add_child(edit)


func _add_vector2i(
		parent: VBoxContainer, property_name: StringName, label_text: String
	) -> void:
	var current := _unit.get(property_name) as Vector2i
	var row := HBoxContainer.new()
	_field(parent, label_text).add_child(row)
	var x := SpinBox.new()
	var y := SpinBox.new()
	for spin in [x, y]:
		spin.min_value = -1
		spin.max_value = 1
		spin.step = 1
		spin.custom_minimum_size.x = 100
		row.add_child(spin)
	x.prefix = "X "
	y.prefix = "Y "
	x.value = current.x
	y.value = current.y
	var commit := func() -> void:
		var value := Vector2i(int(x.value), int(y.value))
		if value != current:
			_emit_change(property_name, value, "Modifier %s" % label_text)
			current = value
	x.get_line_edit().focus_exited.connect(commit)
	y.get_line_edit().focus_exited.connect(commit)


func _field(parent: VBoxContainer, label_text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	parent.add_child(box)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	box.add_child(label)
	return box


func _summary(label_text: String, value: String) -> void:
	var row := HBoxContainer.new()
	summary_box.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", MUTED)
	row.add_child(label)
	var content := Label.new()
	content.text = value
	row.add_child(content)


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", ACCENT)
	return label


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", ACCENT)
	return label


func _info(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", MUTED)
	return label


func _warning(text: String) -> Label:
	var label := _info("⚠ " + text)
	label.add_theme_color_override("font_color", WARNING)
	return label


func _clear(parent: Node) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		child.queue_free()


func _box(tab_name: String) -> VBoxContainer:
	return _tab_boxes[tab_name] as VBoxContainer


func _update_advanced_visibility() -> void:
	var index := TAB_NAMES.find("Avancé")
	if tabs != null and index >= 0:
		tabs.set_tab_hidden(index, _guided)


func _emit_change(property_name: StringName, value: Variant, action_name: String) -> void:
	_emit_target_change(_unit, property_name, value, action_name)


func _emit_target_change(
		target: Object, property_name: StringName, value: Variant, action_name: String
	) -> void:
	property_change_requested.emit(target, property_name, value, action_name)


func _discipline_for_spell(spell: Spell) -> DisciplineData:
	return spell.skill_tree if spell != null and _unit != null else null


func _spell_summary(spell: Spell) -> String:
	var parts := PackedStringArray(["%d PA" % spell.ap_cost])
	if spell.damage > 0:
		parts.append("%d dégâts" % spell.damage)
	if spell.heal > 0:
		parts.append("%d soins" % spell.heal)
	parts.append("portée %d à %d" % [spell.minimum_range, spell.spell_range])
	if not spell.description.strip_edges().is_empty():
		parts.append(spell.description.strip_edges())
	return " · ".join(parts)


func _resource_label(resource: Resource) -> String:
	if resource == null:
		return "Aucune"
	return resource.resource_path if not resource.resource_path.is_empty() else resource.get_class()


func _element_label(element: int) -> String:
	var keys := Spell.Element.keys()
	var key := str(keys[element]) if element >= 0 and element < keys.size() else str(element)
	return {
		"FIRE": "Feu", "ICE": "Glace", "LIGHTNING": "Foudre",
		"SHADOW": "Ombre", "HOLY": "Sacré", "EARTH": "Terre",
	}.get(key, key.capitalize())
