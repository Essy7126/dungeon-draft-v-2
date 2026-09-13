extends VBoxContainer
## A selection is local until the player commits; no inventory rerolls on refresh.
var selection := CatabasePreparationCatalog.preset("marteau")
var session: ExpeditionSession
var commit: Callable
var fields: Dictionary = { }
var summary: Label
var confirm: Button
var status: Label


func configure(value: ExpeditionSession, action: Callable) -> void:
	session = value
	commit = action
	add_theme_constant_override("separation", 14)
	_label("Quel Achille descendra ?", 28)
	_label(
		"Puits : magie, faiblesse et contrôle · un camp après deux salles.\nPorte : écran blindé et tireurs · un marchand après un élite.\nBarque : traction, dégâts mixtes et accès difficiles · une mémoire à découvrir.",
		18,
	)
	_label(
		"Choisissez votre préparation avant le premier combat. Vous pourrez ensuite apprendre des techniques, changer d'arme et trouver des reliques. Départ : 110 PV, 6 PA, 3 PM et 60 oboles.",
		17,
	)
	var presets := GridContainer.new()
	presets.columns = 3
	presets.add_theme_constant_override("h_separation", 10)
	presets.add_theme_constant_override("v_separation", 8)
	add_child(presets)
	for id in CatabasePreparationCatalog.WEAPONS:
		var button := Button.new()
		button.text = String(CatabasePreparationCatalog.WEAPONS[id][0])
		button.name = "Preset_" + String(id)
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		presets.add_child(button)
		button.pressed.connect(
			func():
				selection = CatabasePreparationCatalog.preset(id)
				_sync(),
		)
	_picker("weapon", "Arme · deux actions", CatabasePreparationCatalog.WEAPONS)
	_picker("armor", "Protection", CatabasePreparationCatalog.ARMORS)
	var techniques := { }
	for id in CatabasePreparationCatalog.TECHNIQUES:
		var spell := session.build.catalog.get_spell(id)
		techniques[id] = [spell.spell_name, spell.description]
	_picker("technique_0", "Technique libre 1", techniques)
	_picker("technique_1", "Technique libre 2", techniques)
	_picker("relic", "Relique permanente", CatabasePreparationCatalog.RELICS)
	_picker("supply", "Relique éphémère · une charge", CatabasePreparationCatalog.SUPPLIES)
	summary = _label("", 17)
	summary.name = "DepartureSummary"
	status = _label("", 17)
	status.name = "DepartureStatus"
	confirm = Button.new()
	confirm.name = "ConfirmCatabaseDeparture"
	confirm.text = "Engager cette préparation et entrer dans Catabase  →"
	confirm.custom_minimum_size.y = 54
	add_child(confirm)
	confirm.pressed.connect(_confirm)
	_sync()


func _picker(key: String, title: String, entries: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 240
	row.add_child(label)
	var picker := OptionButton.new()
	picker.name = "Departure_" + key
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size.y = 44
	row.add_child(picker)
	for id in entries:
		picker.add_item(String(entries[id][0]))
		picker.set_item_metadata(picker.item_count - 1, String(id))
	fields[key] = picker
	picker.item_selected.connect(
		func(index):
			var id := String(picker.get_item_metadata(index))
			if key.begins_with("technique_"):
				selection.techniques[int(key.right(1))] = id
			else:
				selection[key] = id
			_sync(),
	)


func _sync() -> void:
	for key in fields:
		var picker: OptionButton = fields[key]
		var id := (
			String(selection.techniques[int(String(key).right(1))])
			if String(key).begins_with("technique_")
			else String(selection[key])
		)
		for index in picker.item_count:
			if picker.get_item_metadata(index) == id:
				picker.select(index)
	if summary == null:
		return
	var text := String(CatabasePreparationCatalog.WEAPONS[selection.weapon][1]) + "\n" + String(
		CatabasePreparationCatalog.ARMORS[selection.armor][4]
	)
	for id in CatabasePreparationCatalog.spell_ids(selection):
		var spell := session.build.catalog.get_spell(id)
		text += "\n\n" + spell.spell_name + " — " + spell.description
	text += "\n\n" + String(CatabasePreparationCatalog.RELICS[selection.relic][1])
	text += "\n" + String(CatabasePreparationCatalog.SUPPLIES[selection.supply][1])
	summary.text = text
	confirm.disabled = not CatabasePreparationCatalog.valid(selection)
	status.text = "Choisissez deux techniques différentes." if confirm.disabled else "Les deux actions d'arme suivent l'arme équipée ; les deux autres techniques restent votre choix."


func _confirm() -> void:
	confirm.disabled = true
	var result: Dictionary = commit.call(selection.duplicate(true))
	status.text = String(result.get("message", result.get("reason", "")))
	confirm.disabled = (
		bool(result.get("success", false)) or not CatabasePreparationCatalog.valid(selection)
	)


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	add_child(label)
	return label
