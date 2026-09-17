extends Node
const CardText = preload("res://ui/expedition/catabase_card_text.gd")
const CardSkin = preload("res://ui/expedition/catabase_card_skin.gd")
## Presentation adapter mounted inside the persistent action bar.
## All casts still go through Battle and SpellCaster.
var battle: Node
var _panel: VBoxContainer
var _last_state := ""
var _hud: Node


func _ready() -> void:
	_hud = battle.action_bar
	_panel = VBoxContainer.new()
	_panel.name = "CatabaseCardHand"
	_panel.add_theme_constant_override("separation", 4)
	_panel.add_theme_font_override("font", CardSkin.FONT)
	_hud.mount_card_hand(_panel)
	if is_instance_valid(battle.player_combat_log): battle.player_combat_log.visible = false


func _exit_tree() -> void:
	if is_instance_valid(_hud) and is_instance_valid(_panel) and _hud.get("_card_hand_view") == _panel:
		_hud.clear_card_hand()


func _process(_delta: float) -> void:
	var session = GameManager.expedition
	if session == null or session.cards == null or not is_instance_valid(battle) or not is_instance_valid(_panel): return
	var cards: CatabaseCards = session.cards
	_panel.visible = not battle._battle_over and not battle._closing and _hud.get_active_bar_mode() != "item"
	var actor: Unit = session.character.unit
	var selected: String = cards.selected if battle.turn_state.selected_spell != null else ""
	var interactive: bool = battle._can_accept_player_intent() and battle.turn_queue.get_current_unit() == actor
	var reasons := []
	for id in cards.hand:
		for spell in cards.spells_for(id): reasons.append(battle.spell_caster.get_spell_preparation_failure_reason(actor, spell))
	var stamp := str([cards.hand, cards.retained, selected, battle.turn_state.selected_spell, cards.recomposed, cards.draw_pile.size(), cards.discard.size(), cards.exhausted.size(), actor.current_ap, actor.current_mp, actor.activation_index, actor.grid_pos, actor.get_meta("ct_bronze", 0), reasons, interactive])
	if battle.has_method("set_card_hand_top"):
		battle.set_card_hand_top(get_viewport().get_visible_rect().size.y - _hud.CARD_HUD_HEIGHT - 20)
	if is_instance_valid(battle.player_combat_log) and battle.player_combat_log.has_method("set_bottom_inset"):
		battle.player_combat_log.set_bottom_inset(_hud.CARD_HUD_HEIGHT + 20)
	if is_instance_valid(battle.inspect_panel) and battle.inspect_panel.has_method("set_bottom_inset"):
		battle.inspect_panel.set_bottom_inset(_hud.CARD_HUD_HEIGHT + 20)
	if stamp == _last_state: return
	_last_state = stamp
	for child in _panel.get_children():
		_panel.remove_child(child)
		child.queue_free()
	var top := HBoxContainer.new()
	top.custom_minimum_size.y = 25
	_panel.add_child(top)
	var icon := TextureRect.new()
	icon.texture = CardSkin.DECK
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(26, 25)
	top.add_child(icon)
	var heading := Label.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.text = "MAIN %d   ·   Pioche %d   ·   Défausse %d   ·   Épuisées %d" % [cards.hand.size(), cards.draw_pile.size(), cards.discard.size(), cards.exhausted.size()]
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color("dac8a4"))
	top.add_child(heading)
	var journal := Button.new()
	journal.name = "CardCombatJournal"
	journal.text = "Journal"
	journal.tooltip_text = "Afficher ou masquer le journal du combat."
	CardSkin.action(journal, true)
	journal.pressed.connect(func():
		if is_instance_valid(battle.player_combat_log): battle.player_combat_log.visible = not battle.player_combat_log.visible)
	top.add_child(journal)
	var help := Button.new()
	help.text = "?"
	help.custom_minimum_size.x = 26
	help.tooltip_text = "Un Geste propose deux actions : jouer l’une consomme la carte.\nGarder : conserver une carte au prochain tour.\n↻ 1 PA : recomposer une fois par tour.\nSurvolez un sort pour lire ses effets et conditions."
	CardSkin.action(help, true)
	top.add_child(help)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	_panel.add_child(row)
	for id in cards.hand:
		var card := cards.copy_for(id)
		var frame := PanelContainer.new()
		frame.name = "HandCard_" + id
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frame.add_theme_stylebox_override("panel", CardSkin.frame(cards.retained == id or selected == id))
		row.add_child(frame)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 3)
		frame.add_child(column)
		var name_label := Label.new()
		name_label.text = ("◆ " if cards.retained == id else "") + cards.title_for(id)
		name_label.tooltip_text = cards.title_for(id) + " · " + CatabaseCards.NAMES[cards.rarity(str(card.family))]
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.clip_text = true
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", CatabaseCards.COLORS[cards.rarity(str(card.family))])
		column.add_child(name_label)
		for spell in cards.spells_for(id):
			var play := Button.new()
			play.name = "Play_" + id + "_" + str(spell.spell_id)
			play.custom_minimum_size.y = 40
			play.size_flags_vertical = Control.SIZE_EXPAND_FILL
			CardSkin.action(play)
			play.toggle_mode = true
			play.button_pressed = selected == id and battle.turn_state.selected_spell == spell
			var reason: StringName = battle.spell_caster.get_spell_preparation_failure_reason(actor, spell)
			var explanation := CardText.reason_text(reason, actor, spell)
			play.tooltip_text = (explanation + "\n\n" if not explanation.is_empty() else "Choisissez ensuite une cible valide.\n\n") + CardText.details(spell, actor)
			play.disabled = not interactive or reason != &""
			play.pressed.connect(func(): cards.selected = id; battle._on_spell_pressed(spell))
			column.add_child(play)
			_spell_face(play, spell, actor.get_spell_ap_cost(spell))
		var choices := HBoxContainer.new()
		choices.add_theme_constant_override("separation", 3)
		column.add_child(choices)
		var retain := Button.new()
		retain.name = "Retain_" + id
		retain.text = "Gardée" if cards.retained == id else "Garder"
		retain.toggle_mode = true
		retain.button_pressed = cards.retained == id
		retain.custom_minimum_size.y = 24
		retain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		CardSkin.action(retain, true)
		retain.tooltip_text = "Conserver cette carte au prochain tour. Une seule carte gardée."
		retain.disabled = not interactive
		retain.pressed.connect(func(): cards.retained = "" if cards.retained == id else id; cards.changed.emit())
		choices.add_child(retain)
		var exchange := Button.new()
		exchange.name = "Recompose_" + id
		exchange.text = "↻ 1 PA"
		exchange.custom_minimum_size.y = 24
		exchange.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		CardSkin.action(exchange, true)
		exchange.tooltip_text = "Une fois par tour, remplacer cette carte par une autre pour 1 PA."
		exchange.disabled = not interactive or cards.recomposed or actor.current_ap < 1 or (cards.draw_pile.is_empty() and cards.discard.is_empty())
		exchange.pressed.connect(func():
			battle._cancel_action_selection_for_active_unit()
			cards.recompose(id)
		)
		choices.add_child(exchange)


func _spell_face(button: Button, spell: Spell, cost: int) -> void:
	# Bounded two-line names and a separate cost prevent six-card hands from
	# growing below the chassis when a weapon has a long name.
	button.accessibility_name = "%s, %d PA" % [spell.spell_name, cost]
	var face := HBoxContainer.new()
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.offset_left = 4
	face.offset_right = -4
	face.offset_top = 3
	face.offset_bottom = -3
	face.add_theme_constant_override("separation", 3)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(face)
	var icon := TextureRect.new()
	icon.texture = spell.icon
	icon.custom_minimum_size.x = 20
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(icon)
	var title := Label.new()
	title.text = spell.spell_name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(title)
	var price := Label.new()
	price.text = "%d\nPA" % cost
	price.custom_minimum_size.x = 18
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.add_theme_font_size_override("font_size", 12)
	price.add_theme_color_override("font_color", Color("e6c37c"))
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(price)
	face.modulate = Color("9aa49e") if button.disabled else Color.WHITE
