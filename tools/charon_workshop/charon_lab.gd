extends Control
const Combat = preload("res://tools/charon_workshop/charon_combat.gd")
const Board = preload("res://tools/charon_workshop/charon_board.gd")
var combat: Combat
var board: Board
var status: Label
var intention: Label
var journal: RichTextLabel
var hand: HBoxContainer
var class_choice: OptionButton
var seed_input: SpinBox
var end_button: Button
var terminal_buttons: Dictionary = { }
var selected := ""
var help_label: Label


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("101c26"))
	var theme_data := Theme.new()
	theme_data.default_font_size = 16
	theme = theme_data
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 22)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "CHARON  /  LE PRIX DU PASSAGE"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("eac27b"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	class_choice = OptionButton.new()
	for id in Combat.Catalog.CLASSES:
		class_choice.add_item(Combat.Catalog.CLASSES[id][0])
	class_choice.select(1)
	header.add_child(class_choice)
	seed_input = SpinBox.new()
	seed_input.min_value = 1
	seed_input.max_value = 99999
	seed_input.value = 42
	seed_input.tooltip_text = "Graine de pioche. Rejouer conserve les mêmes conditions."
	header.add_child(seed_input)
	_button(header, "Rejouer", _restart)
	status = Label.new()
	root.add_child(status)
	var center := HBoxContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 22)
	root.add_child(center)
	board = Board.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(450, 280)
	board.cell_clicked.connect(_cell_clicked)
	center.add_child(board)
	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.custom_minimum_size.x = 350
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(sidebar_scroll)
	var sidebar := VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 10)
	sidebar_scroll.add_child(sidebar)
	intention = Label.new()
	intention.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intention.custom_minimum_size.y = 115
	intention.add_theme_color_override("font_color", Color("efb58a"))
	sidebar.add_child(intention)
	var terminals := Label.new()
	terminals.text = "BORNES  ·  1 PA + 1 OBOLE"
	sidebar.add_child(terminals)
	for item in [
		["left", "Tourner à gauche"],
		["right", "Tourner à droite"],
		["gate", "Armer la herse · 35 dégâts"],
	]:
		var action: String = item[0]
		var button := _button(
			sidebar,
			item[1],
			func():
				combat.use_terminal(action),
		)
		button.mouse_entered.connect(
			func():
				board.preview = combat.preview_terminal(action)
				board.queue_redraw(),
		)
		button.mouse_exited.connect(
			func():
				board.preview.clear()
				board.queue_redraw(),
		)
		terminal_buttons[action] = button
	for index in 2:
		var gesture_index: int = index
		_button(
			sidebar,
			"Frappe de secours · 2 PA" if index == 0 else "Se protéger · 1 PA",
			func():
				selected = "gesture_%d" % gesture_index
				_refresh(),
		)
	journal = RichTextLabel.new()
	journal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	journal.custom_minimum_size.y = 95
	journal.fit_content = true
	journal.add_theme_font_size_override("normal_font_size", 14)
	sidebar.add_child(journal)
	help_label = Label.new()
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(help_label)
	hand = HBoxContainer.new()
	hand.add_theme_constant_override("separation", 10)
	root.add_child(hand)
	var footer := HBoxContainer.new()
	root.add_child(footer)
	_button(
		footer,
		"Marcher / annuler [Échap]",
		func():
			selected = ""
			_refresh(),
	)
	_button(
		footer,
		"Conserver la carte choisie",
		func():
			combat.retain(selected),
	)
	_button(
		footer,
		"Recomposer · 1 PA",
		func():
			combat.recompose(selected),
	)
	end_button = _button(
		footer,
		"Terminer le tour [Espace]",
		func():
			selected = ""
			combat.end_turn(),
	)
	end_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_restart()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--charon-capture="):
			await get_tree().process_frame
			await get_tree().process_frame
			combat.end_turn()
			await RenderingServer.frame_post_draw
			var path := argument.trim_prefix("--charon-capture=")
			get_viewport().get_texture().get_image().save_png(path)
			get_tree().quit()


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _restart() -> void:
	if combat != null:
		combat.changed.disconnect(_refresh)
		combat.dispose()
	combat = Combat.new()
	combat.initialize(Combat.Catalog.CLASSES.keys()[class_choice.selected], int(seed_input.value))
	combat.changed.connect(_refresh)
	board.combat = combat
	board.preview.clear()
	selected = ""
	_refresh()


func _refresh() -> void:
	if combat == null:
		return
	board.preview.clear()
	var actor := combat.hero
	status.text = "%s   ·   TOUR %d   ·   PV %d/%d   ·   GARDE %d   ·   PA %d   PM %d   ·   OBOLES %d" % [
		combat.outcome if not combat.outcome.is_empty() else "PROTOTYPE CARTES",
		combat.round_number,
		actor.current_hp,
		actor.max_hp.get_int(),
		actor.current_shield,
		actor.current_ap,
		actor.current_mp,
		combat.oboles,
	]
	if selected not in combat.cards.hand and not selected.begins_with("gesture_"):
		selected = ""
	if selected.begins_with("gesture_"):
		board.selected_spell = combat.cards.weapon_spells()[int(selected.trim_prefix("gesture_"))]
	else:
		board.selected_spell = combat.cards.spells_for(selected)[0] if not selected.is_empty() else null
	if combat.pending.is_empty():
		intention.text = "CHARON · %d/%d PV\nCrochet %d + attraction 2 ; rame %d + poussée 2.\nUne traversée se prépare tous les %d tours ennemis." % [
			combat.boss.current_hp,
			combat.boss.max_hp.get_int(),
			combat.profile.hook_damage,
			combat.profile.oar_damage,
			maxi(2, combat.profile.crossing_period),
		]
	elif combat.boss.grid_pos != combat.pending.origin:
		intention.text = "TRAVERSÉE INTERROMPUE\nCharon a quitté son point de départ : sa prochaine activation sera perdue."
	else:
		intention.text = "TRAVERSÉE AU PROCHAIN TOUR\n%d dégâts sur les cases rouges, Porteurs compris.\n" % [
			combat.profile.crossing_damage
		]
		if combat.pending.gate:
			intention.text += "HERSE ARMÉE : attaque annulée, Charon subira %d." % [
				combat.profile.gate_damage
			]
		else:
			intention.text += "Le trajet est fixé. Sortez-en, utilisez une borne ou déplacez Charon."
	terminal_buttons["gate"].text = "Armer la herse · %d dégâts" % [combat.profile.gate_damage]
	for action in terminal_buttons:
		var reason: String = combat.terminal_failure(action)
		terminal_buttons[action].disabled = not reason.is_empty()
		terminal_buttons[action].tooltip_text = reason if not reason.is_empty() else "Survolez pour voir le trajet ; cliquez pour dépenser 1 PA et 1 obole."
	journal.text = "\n".join(combat.messages.slice(maxi(0, combat.messages.size() - 5)))
	help_label.text = "A : Achille · C : Charon · P : Porteur · B : borne · o : obole. Cliquez une case verte pour marcher, ou une carte puis sa cible."
	if board.selected_spell != null:
		help_label.text = board.selected_spell.spell_name + " : " + board.selected_spell.description
	for child in hand.get_children():
		hand.remove_child(child)
		child.queue_free()
	for id: String in combat.cards.hand:
		var spell: Spell = combat.cards.spells_for(id)[0]
		var text := "%s%s\n%d PA · PO %d–%d\n%d dégâts · %d garde" % [
			"◆ " if combat.cards.retained == id else "",
			spell.spell_name,
			spell.ap_cost,
			spell.minimum_range,
			spell.spell_range,
			spell.get_scaled_damage(actor),
			spell.get_scaled_shield(actor),
		]
		var button := _button(
			hand,
			text,
			func():
				selected = id
				_refresh(),
		)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 88
		button.add_theme_font_size_override("font_size", 14)
		button.tooltip_text = spell.description
		button.disabled = not combat.player_turn or not combat.outcome.is_empty()
		button.modulate = Color("79dfcf") if selected == id else Color.WHITE
	end_button.disabled = not combat.player_turn or not combat.outcome.is_empty()
	board.queue_redraw()


func _cell_clicked(cell: Vector2i) -> void:
	var ok := false
	if selected.begins_with("gesture_"):
		ok = combat.play_gesture(int(selected.trim_prefix("gesture_")), cell)
	else:
		ok = combat.move_hero(cell) if selected.is_empty() else combat.play_card(selected, cell)
	if not ok:
		help_label.text = "Action impossible : vérifiez portée, ligne de vue, PA/PM et cible. Aucun coût dépensé."


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if seed_input.has_focus() or seed_input.get_line_edit().has_focus():
			return
		if event.keycode == KEY_ESCAPE:
			selected = ""
			_refresh()
		elif event.keycode == KEY_SPACE:
			selected = ""
			combat.end_turn()


func _exit_tree() -> void:
	if combat != null:
		combat.dispose()
