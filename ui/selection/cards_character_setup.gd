extends MarginContainer
## The character remains visible while only one preparation decision is open.
signal hero_selected(index: int)
signal launch_requested
signal back_requested
const PAGE := preload("res://ui/selection/cards_choice_page.gd")
const PREVIEW := preload("res://ui/characters/CharacterPreview3D.tscn")
const Catalog := preload("res://core/expedition/class_card_catalog.gd")
const STEPS := ["Personnage", "Classe", "Difficulté", "Départ"]
var selection := Catalog.preset()
var difficulty := "normal"
var step := 0
var reached := 0
var hero := 2
var entries: Array[Dictionary] = []
var start_button: Button
var status: Label
var _nav: VBoxContainer
var _page: VBoxContainer
var _preview: CharacterPreview3D
var _hero_name: Label
var _catalog := ExpeditionBuildCatalog.new()


func configure(value: Array[Dictionary]) -> void:
	entries = value
	hero = mini(2, entries.size() - 1)
	theme = preload("res://ui/expedition/catabase_ui_theme.gd").get_theme()
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 24)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	add_child(root)
	PAGE.text(root, "CATABASE · Préparer ma descente", 29)
	PAGE.text(
		root,
		"Une apparence, une classe, puis cinq cartes choisies parmi quinze au Seuil des Ombres.",
		18,
	)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	root.add_child(columns)
	_nav = VBoxContainer.new()
	_nav.custom_minimum_size.x = 190
	columns.add_child(_nav)
	var stage := VBoxContainer.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_stretch_ratio = 0.75
	columns.add_child(stage)
	_hero_name = PAGE.text(stage, "", 30)
	_preview = PREVIEW.instantiate()
	_preview.custom_minimum_size = Vector2(200, 240)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_child(_preview)
	_preview.set_showcase_mode(true)
	PAGE.text(stage, "2 gestes de secours toujours disponibles\n4 cartes en main à chaque tour", 17)
	_page = VBoxContainer.new()
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.35
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("191916f2")
	surface.border_color = Color("766347")
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(8)
	surface.content_margin_left = 18
	surface.content_margin_right = 18
	surface.content_margin_top = 18
	surface.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", surface)
	columns.add_child(panel)
	panel.add_child(_page)
	status = PAGE.text(root, "", 16)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)
	var back := Button.new()
	back.name = "SetupBack"
	back.text = "← Retour"
	back.custom_minimum_size = Vector2(190, 48)
	back.pressed.connect(
		func():
			if step == 0:
				back_requested.emit()
			else:
				step -= 1
				_render(),
	)
	footer.add_child(back)
	start_button = Button.new()
	start_button.name = "StartAdventure"
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.pressed.connect(
		func():
			if step == 3:
				launch_requested.emit()
			else:
				step += 1
				reached = maxi(reached, step)
				_render(),
	)
	footer.add_child(start_button)
	_update_hero()
	_render()


func payload() -> Dictionary:
	var result := selection.duplicate(true)
	result.difficulty_id = difficulty
	return result


func _update_hero() -> void:
	var entry := entries[hero]
	_hero_name.text = str(entry.display_name)
	_preview.configure(entry.unit)
	for clip in [&"idle_S", &"idle_E"]:
		if _preview.has_clip(clip):
			_preview.play_clip(clip)
			break
	hero_selected.emit(hero)


func _render() -> void:
	for parent in [_nav, _page]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	for index in STEPS.size():
		var button := Button.new()
		button.name = "SetupStep_%d" % index
		button.text = ("✓ " if index < reached else "%d · " % (index + 1)) + STEPS[index]
		button.custom_minimum_size.y = 48
		button.toggle_mode = true
		button.button_pressed = step == index
		button.disabled = index > reached
		button.pressed.connect(
			func():
				step = index
				_render(),
		)
		_nav.add_child(button)
	PAGE.text(_nav, "CLASSE ACTUELLE", 14)
	PAGE.text(_nav, Catalog.CLASSES[selection.class_id][0], 22)
	PAGE.text(_nav, "Maîtrise 2 / 4\nAutres classes : 0 / 2\nSpécialisation au niveau 4", 16)
	start_button.text = "Rejoindre le seuil avec %s →" % entries[hero].display_name if step == 3 else "Confirmer · Suivant →"
	status.text = "Étape %d / 4 · Aucun équipement au départ : vos objets seront trouvés pendant la run." % (
		step + 1
	)
	if step == 3:
		PAGE.text(_page, "Votre départ", 27)
		PAGE.text(
			_page,
			"%s · %s\nDifficulté : %s"
			% [
				entries[hero].display_name,
				Catalog.CLASSES[selection.class_id][0],
				"Normale" if difficulty == "normal" else "Facile",
			],
			23,
		)
		PAGE.text(_page, Catalog.CLASSES[selection.class_id][2], 20)
		PAGE.text(
			_page,
			"Au seuil, choisissez cinq familles parmi quinze : deux copies chacune, dix cartes au total. Votre apparence n'impose aucun équipement.\n\nLa porte : pression physique et archers. Le puits : magie et affaiblissements. La barque : mobilité et placement. Vos choix de cartes vous aideront à préparer ce premier embranchement.",
			18,
		)
		return
	var options: Array = []
	var current := ""
	var prompt := ""
	if step == 0:
		current = str(hero)
		prompt = "L'apparence est indépendante de votre classe."
		for index in entries.size():
			options.append(
				{
					"id": str(index),
					"title": entries[index].display_name,
					"impact": entries[index].appearance,
					"details": "Cette apparence vous suit au seuil et en combat.",
				}
			)
	elif step == 2:
		current = difficulty
		prompt = "Choisissez la résistance de votre traversée."
		options = [
			{ "id": "normal", "title": "Normale", "impact": "Ennemis à leur puissance habituelle." },
			{
				"id": "easy",
				"title": "Facile",
				"impact": "Ennemis : −10 % PV et −20 % dégâts. Soin au refuge : 40 % au lieu de 30 %.",
			},
		]
	else:
		current = selection.class_id
		prompt = "Votre classe détermine vos quinze cartes de départ et votre passif. Les quatre classes partagent les mêmes statistiques initiales."
		for id in Catalog.CLASSES:
			var row: Array = Catalog.CLASSES[id]
			options.append(
				{
					"id": id,
					"title": row[0],
					"icon": Catalog.icon(id),
					"impact": row[1] + "\n\n" + row[2],
					"details": row[3]
					+ "\n\nMaîtrise initiale 2 : +20 % dégâts et garde. Cartes étrangères utilisables dès leur acquisition ; leur maîtrise sera plafonnée à 2. La vôtre pourra atteindre 4.",
				}
			)
	var page := PAGE.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.add_child(page)
	page.configure(STEPS[step], prompt, options, current)
	page.chosen.connect(
		func(id):
			if step == 0:
				hero = int(id)
				_update_hero()
			elif step == 2:
				difficulty = id
			else:
				selection = Catalog.preset(id)
			_render(),
	)
