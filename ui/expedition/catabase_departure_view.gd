extends VBoxContainer
## Choices stay local until the final departure confirmation.
const TILE := preload("res://ui/expedition/catabase_choice_tile.gd")
const STEPS := ["weapon", "armor", "technique_0", "technique_1", "relic", "supply", "review"]
const TITLES := [
	"Votre arme, votre façon de combattre",
	"De quoi vous protéger ?",
	"Votre première technique libre",
	"Votre seconde technique libre",
	"Une relique pour toute la descente",
	"Une ressource pour les moments difficiles",
	"Achille est prêt à descendre",
]
const HELP := [
	"L'arme donne deux actions. Choisir une arme prépare aussi un ensemble conseillé : les fenêtres suivantes vous permettent de tout ajuster.",
	"Porte : les squelettes frappent surtout au physique. Puits : préparez une défense magique. Barque : dégâts mixtes, déplacements et accès difficiles. Aucune protection ne couvre tout.",
	"Ajoutez une action à vos deux sorts d'arme. Pensez à ce qui vous manque : atteindre un tireur, vous protéger ou déplacer une cible.",
	"Quatre actions au départ : deux liées à l'arme, deux libres. Choisissez une technique différente de la première. Vos PA sont partagés entre toutes vos actions.",
	"Une relique permanente agit depuis l'inventaire. Vérifiez son déclencheur : une urne sans garde ni Répercussion ne vous aidera pas.",
	"Les reliques éphémères s'activent depuis l'inventaire en combat. Elles coûtent 1 PA et disparaissent après usage : gardez-les pour un tour décisif.",
	"Première salle : placez Achille, observez la portée des ennemis, puis essayez vos deux actions d'arme ensemble. Les défis sont facultatifs et influencent le combat suivant. Après une montée de niveau : caractéristiques, sorts, puis butin.",
]
var selection := CatabasePreparationCatalog.preset("marteau")
var session: ExpeditionSession
var commit: Callable
var step := 0
var status: Label
var confirm: Button
var _content: VBoxContainer
var _next: Button


func configure(value: ExpeditionSession, action: Callable) -> void:
	session = value
	commit = action
	add_theme_constant_override("separation", 12)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_render()


func _render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_label(self, "PRÉPARER LA DESCENTE  ·  %d / 7" % (step + 1), 14)
	_label(self, TITLES[step], 27)
	_label(self, HELP[step], 17)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)
	var entries := _entries()
	var grid := GridContainer.new()
	grid.columns = 3 if get_viewport_rect().size.x >= 1000 else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_content.add_child(grid)
	for id in entries:
		var row: Array = entries[id]
		var tile := TILE.new()
		tile.name = ("Preset_" if step == 0 else "DepartureChoice_") + String(id)
		grid.add_child(tile)
		tile.configure(row[0], row[1], row[2], _selected_id() == id)
		if step == 6:
			tile.disabled = true
		else:
			tile.pressed.connect(
				func():
					_select(id),
			)
	status = _label(self, "", 15)
	status.name = "DepartureStatus"
	var actions := HBoxContainer.new()
	add_child(actions)
	var back := Button.new()
	back.text = "← Retour"
	back.disabled = step == 0
	back.custom_minimum_size = Vector2(120, 48)
	actions.add_child(back)
	back.pressed.connect(
		func():
			step -= 1
			_render(),
	)
	_next = Button.new()
	_next.name = "ConfirmCatabaseDeparture" if step == 6 else "DepartureNext"
	_next.text = "Entrer dans la première salle  →" if step == 6 else "Valider ce choix  →"
	_next.custom_minimum_size.y = 48
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_next)
	_next.pressed.connect(_confirm if step == 6 else _advance)
	confirm = _next if step == 6 else null
	_sync()
	_focus_next.call_deferred()


func _focus_next() -> void:
	if (
		is_instance_valid(_next) and _next.is_inside_tree()
		and _next.is_visible_in_tree() and not _next.disabled
	):
		_next.grab_focus()


func _entries() -> Dictionary:
	var entries := { }
	var key: String = STEPS[step]
	if step == 6:
		for group in ["weapon", "armor", "relic", "supply"]:
			var source: Dictionary = _catalog(group)
			var id: String = selection[group]
			entries[group] = [
				source[id][0],
				source[id][4 if group == "armor" else 1],
				CatabasePreparationCatalog.choice_icon(group, id),
			]
		for id in CatabasePreparationCatalog.spell_ids(selection):
			var spell := session.build.catalog.get_spell(id)
			entries[id] = [spell.spell_name, spell.description, spell.icon]
		return entries
	if key.begins_with("technique_"):
		for id in CatabasePreparationCatalog.TECHNIQUES:
			var spell := session.build.catalog.get_spell(id)
			entries[id] = [spell.spell_name, spell.description, spell.icon]
	else:
		var source := _catalog(key)
		for id in source:
			entries[id] = [
				source[id][0],
				source[id][4 if key == "armor" else 1],
				CatabasePreparationCatalog.choice_icon(key, id),
			]
	return entries


func _catalog(key: String) -> Dictionary:
	return {
		"weapon": CatabasePreparationCatalog.WEAPONS,
		"armor": CatabasePreparationCatalog.ARMORS,
		"relic": CatabasePreparationCatalog.RELICS,
		"supply": CatabasePreparationCatalog.SUPPLIES,
	}[key]


func _selected_id() -> String:
	var key: String = STEPS[step]
	return (
		String(selection.techniques[int(key.right(1))])
		if key.begins_with("technique_")
		else String(selection.get(key, ""))
	)


func _select(id: String) -> void:
	var key: String = STEPS[step]
	if key == "weapon":
		selection = CatabasePreparationCatalog.preset(id)
	elif key.begins_with("technique_"):
		selection.techniques[int(key.right(1))] = id
	else:
		selection[key] = id
	for tile in _content.get_child(0).get_children():
		tile.set_pressed_no_signal(String(tile.name).trim_prefix("Preset_").trim_prefix(
				"DepartureChoice_"
			) == id)
	_sync()


func _sync() -> void:
	var duplicate: bool = step in [2, 3] and selection.techniques[0] == selection.techniques[1]
	_next.disabled = duplicate or (step == 6 and not CatabasePreparationCatalog.valid(selection))
	status.text = (
		"Choisissez deux techniques différentes."
		if duplicate
		else "Choix : " + str(_entries().get(_selected_id(), ["Préparation complète"])[0])
	)
	if not duplicate and step < 6:
		status.text += " · " + str(_entries()[_selected_id()][1])
	if step == 0:
		var weapon: Array = CatabasePreparationCatalog.WEAPONS[selection.weapon]
		status.text += "\nActions : %s + %s." % [
			session.build.catalog.get_spell(weapon[2]).spell_name,
			session.build.catalog.get_spell(weapon[3]).spell_name,
		]


func _advance() -> void:
	if _next.disabled:
		return
	step += 1
	_render()


func _confirm() -> void:
	if step != 6 or not CatabasePreparationCatalog.valid(selection):
		return
	confirm.disabled = true
	var result: Dictionary = commit.call(selection.duplicate(true))
	status.text = String(result.get("message", result.get("reason", "")))
	confirm.disabled = bool(result.get("success", false))


func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label
