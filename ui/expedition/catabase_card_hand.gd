extends Node
const CardText = preload("res://ui/expedition/catabase_card_text.gd")
const CardSkin = preload("res://ui/expedition/catabase_card_skin.gd")
const HoverCard = preload("res://ui/expedition/spell_hover_card.gd")
const ModernCard = preload("res://ui/expedition/consumable_combat_card_view.gd")
const DossierSkin = preload("res://ui/expedition/player_dossier_skin.gd")
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
	_panel.set_meta("expanded_card_faces", GameManager.expedition.cards.rules_revision == 3)
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
	var consumable: bool = session.uses_consumable_cards()
	_panel.visible = not battle._battle_over and not battle._closing and _hud.get_active_bar_mode() != "item"
	var actor: Unit = session.character.unit
	var selected: String = cards.selected if battle.turn_state.selected_spell != null else ""
	var interactive: bool = battle._can_accept_player_intent() and battle.turn_queue.get_current_unit() == actor
	var reasons := []
	for spell in cards.weapon_spells(): reasons.append(_spell_stamp(actor, spell))
	for id in cards.hand:
		for spell in cards.spells_for(id): reasons.append(_spell_stamp(actor, spell))
	var stamp := str([cards.hand, cards.retained, selected, battle.turn_state.selected_spell, cards.recomposed, cards.draw_pile.size(), cards.discard.size(), cards.exhausted.size(), actor.current_ap, actor.current_mp, actor.activation_index, actor.grid_pos, actor.get_meta("ct_bronze", 0), reasons, interactive])
	if consumable:
		stamp += str([cards.pending_choice, cards.action_options, cards.consumed.size(), cards.anchor_available, battle._cards_runtime.save_failed, battle._cards_runtime.room_rules.state, actor.current_hp, actor.max_hp.get_int(), battle.units.map(func(u): return [u.grid_pos, u.is_alive])])
	if battle.has_method("set_card_hand_top"):
		battle.set_card_hand_top(get_viewport().get_visible_rect().size.y - _hud.get_card_hud_height() - 20)
	if is_instance_valid(battle.player_combat_log) and battle.player_combat_log.has_method("set_bottom_inset"):
		battle.player_combat_log.set_bottom_inset(_hud.get_card_hud_height() + 20)
	if is_instance_valid(battle.inspect_panel) and battle.inspect_panel.has_method("set_bottom_inset"):
		battle.inspect_panel.set_bottom_inset(_hud.get_card_hud_height() + 20)
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
	if consumable: heading.text = "MAIN %d   ·   Pioche %d   ·   Défausse %d   ·   Consommées %d" % [cards.hand.size(), cards.draw_pile.size(), cards.discard.size(), cards.consumed.size()]
	heading.add_theme_font_size_override("font_size", 15)
	heading.add_theme_color_override("font_color", Color("dac8a4"))
	top.add_child(heading)
	var deck := Button.new()
	deck.name = "OpenCombatDeck"
	deck.text = "Mon deck · 10 cartes"
	if consumable: deck.text = "Préparées · %d" % cards.active.size()
	deck.tooltip_text = "Voir toutes vos cartes et leurs effets. Consultation pendant le combat."
	CardSkin.action(deck)
	deck.add_theme_font_size_override("font_size", 16)
	top.add_child(deck)
	deck.pressed.connect(func():
		var persistent := GameManager.get_persistent_run_ui()
		if persistent != null: persistent.open_card_collection())
	var piles := Button.new()
	piles.name = "InspectCardPiles"
	piles.text = "Piles"
	piles.visible = cards.rules_revision != 3
	CardSkin.action(piles, true)
	top.add_child(piles)
	piles.pressed.connect(func():
		var dialog := AcceptDialog.new()
		dialog.title = "Pioche, défausse et copies consommées" if consumable else "Pioche, défausse et cartes épuisées"
		var text := ""
		var entries := [["Pioche · ordre masqué", cards.draw_pile], ["Défausse", cards.discard]]
		if not consumable: entries.append(["Épuisées", cards.exhausted])
		for entry in entries:
			var names: Array = entry[1].map(func(id): return cards.title_for(id))
			names.sort()
			text += str(entry[0]) + "\n" + (", ".join(names) if not names.is_empty() else "Vide") + "\n\n"
		if consumable:
			var families := {}
			for copy in cards.consumed.values(): families[copy.family] = int(families.get(copy.family, 0)) + 1
			var names: Array[String] = []
			for family in families: names.append("%d × %s" % [families[family], preload("res://core/expedition/consumable_card_catalog.gd").card(family).name])
			names.sort()
			text += "Copies consommées\n" + (", ".join(names) if not names.is_empty() else "Aucune")
		dialog.dialog_text = text
		dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(dialog)
		dialog.confirmed.connect(dialog.queue_free)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered(Vector2i(mini(680, int(get_viewport().get_visible_rect().size.x) - 40), 360)))
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
	help.tooltip_text = "Deux gestes d'arme fixes, hors pioche. Quatre manœuvres en main.\nGarder : conserver une carte au prochain tour.\n↻ 1 PA : recomposer une fois par tour.\nSurvolez un sort pour lire ses effets et conditions."
	if consumable: help.tooltip_text = "Chaque copie jouée est consommée pour la run. Une même famille se joue une fois par tour.\nLes cartes non jouées sont défaussées puis repiochées. La rétention exige un effet de carte.\nDeux secours restent disponibles, une fois chacun par tour. Pression croissante après le tour 8 ; limite 24 tours."
	CardSkin.action(help, true)
	top.add_child(help)
	if consumable:
		for command in [deck, piles, journal, help]: DossierSkin.button(command)
		heading.add_theme_font_override("font", DossierSkin.FONT)
		heading.add_theme_font_size_override("font_size", 14)
		heading.text = "Main %d · Pioche %d · Défausse %d · Consommées %d" % [cards.hand.size(), cards.draw_pile.size(), cards.discard.size(), cards.consumed.size()]
		heading.clip_text = true
		heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		heading.tooltip_text = heading.text
		_consumable_room(cards, actor, interactive)
		_consumable_choices(cards, actor, interactive)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	_panel.add_child(row)
	var weapons := VBoxContainer.new()
	weapons.name = "FixedWeaponActions"
	weapons.custom_minimum_size.x = 130
	weapons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if consumable: weapons.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(weapons)
	var fixed_label := Label.new()
	fixed_label.text = "SECOURS · hors pioche" if cards.rules_revision in [3, 4] else "ARME · hors pioche"
	fixed_label.add_theme_font_size_override("font_size", 13)
	weapons.add_child(fixed_label)
	for spell in cards.weapon_spells():
		var play := Button.new()
		play.name = "FixedWeapon_" + str(spell.spell_id)
		play.custom_minimum_size.y = 60 if consumable else 48
		play.size_flags_vertical = Control.SIZE_EXPAND_FILL
		CardSkin.action(play)
		var reason: StringName = battle.spell_caster.get_spell_preparation_failure_reason(actor, spell)
		play.disabled = not interactive or reason != &""
		play.tooltip_text = CardText.reason_text(reason, actor, spell) + "\n" + CardText.details(spell, actor)
		play.pressed.connect(func(): cards.selected = ""; battle._on_spell_pressed(spell))
		weapons.add_child(play)
		_spell_face(play, spell, actor.get_spell_ap_cost(spell))
		HoverCard.attach(play, spell, actor, _panel, CardText.reason_text(reason, actor, spell))
	for id in cards.hand:
		var card := cards.copy_for(id)
		var frame := PanelContainer.new()
		frame.name = "HandCard_" + id
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frame.add_theme_stylebox_override("panel", CardSkin.surface(Color("b9caa5"), cards.retained == id or selected == id, 5))
		if consumable: frame.add_theme_stylebox_override("panel", DossierSkin.surface(cards.retained == id or selected == id, 2))
		row.add_child(frame)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 3)
		frame.add_child(column)
		var name_label := Label.new()
		name_label.text = ("◆ " if cards.retained == id else "") + cards.title_for(id)
		name_label.tooltip_text = cards.title_for(id) + " · " + (str(preload("res://core/expedition/consumable_card_catalog.gd").card(str(card.family)).rarity) if consumable else CatabaseCards.NAMES[cards.rarity(str(card.family))])
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.clip_text = true
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", CatabaseCards.COLORS[mini(4, cards.rarity(str(card.family)))])
		column.add_child(name_label)
		name_label.visible = cards.rules_revision != 3 and not consumable
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
			HoverCard.attach(play, spell, actor, _panel, explanation)
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
		if consumable:
			retain.visible = cards.pending_choice.get("kind") == "retain"
			retain.pressed.connect(func(): battle._cards_runtime.choose({"kind": "retain", "uid": id}))
		else:
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
		if consumable: exchange.hide()


func _consumable_room(cards, actor: Unit, interactive: bool) -> void:
	var runtime = battle._cards_runtime
	var room = runtime.room_rules
	if cards.round_index >= 8:
		var pressure := Label.new()
		pressure.name = "CardPressureForecast"
		pressure.text = "Pression après cette ronde : %d PV · ronde suivante : %d PV · ignore garde et résistances" % [runtime.Math.pressure(actor.max_hp.get_int(), cards.round_index), runtime.Math.pressure(actor.max_hp.get_int(), cards.round_index + 1)]
		if cards.round_index >= 24: pressure.text = "Dernière ronde · défaite par expiration après les ennemis si le combat continue."
		elif cards.round_index == 23: pressure.text = "Pression après cette ronde : %d PV · ronde suivante : dernière chance avant expiration" % runtime.Math.pressure(actor.max_hp.get_int(), cards.round_index)
		pressure.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pressure.add_theme_font_size_override("font_size", 13)
		pressure.add_theme_color_override("font_color", Color("f0ba8b"))
		_panel.add_child(pressure)
	if room == null or room.room_id.is_empty(): return
	var text := Label.new()
	text.name = "CardRoomIntention"
	text.text = room.description()
	text.tooltip_text = room.help_text()
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.clip_text = true
	text.add_theme_font_size_override("font_size", 13)
	text.add_theme_color_override("font_color", Color("f0cf98"))
	_panel.add_child(text)
	var commands := HFlowContainer.new()
	commands.name = "CardRoomCommands"
	_panel.add_child(commands)
	for entry in room.commands():
		var button := Button.new()
		button.name = "RoomAction_" + str(entry.id)
		button.text = entry.label
		var reason: String = room.failure(str(entry.id))
		button.disabled = not interactive or not cards.pending_choice.is_empty() or not reason.is_empty()
		button.tooltip_text = (reason + "\n" if not reason.is_empty() else "") + room.help_text()
		CardSkin.action(button, true)
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(func(): runtime.use_room_command(str(entry.id)))
		commands.add_child(button)


func _consumable_choices(cards, actor: Unit, interactive: bool) -> void:
	var choices := HFlowContainer.new()
	_panel.add_child(choices)
	if battle._cards_runtime.save_failed:
		var retry := Button.new()
		retry.text = "Sauvegarde impossible · Réessayer"
		retry.pressed.connect(func(): battle._cards_runtime.checkpoint())
		choices.add_child(retry)
		return
	if cards.pending_choice.get("kind") in ["retain", "relay"]:
		var kind: String = cards.pending_choice.kind
		var skip := Button.new()
		skip.text = "Ne pas conserver de carte" if kind == "retain" else "Ne pas transférer la marque"
		skip.disabled = not interactive
		skip.pressed.connect(func(): battle._cards_runtime.choose({"kind": kind}))
		choices.add_child(skip)
		if kind == "relay":
			for unit in battle.units:
				var origin := Vector2i(cards.pending_choice.cell[0], cards.pending_choice.cell[1])
				if unit.team == actor.team or not unit.is_alive or battle.grid.manhattan(origin, unit.grid_pos) > 2: continue
				var target := Button.new()
				target.text = "Marquer " + unit.unit_name
				target.disabled = not interactive
				target.pressed.connect(func(): battle._cards_runtime.choose({"kind": "relay", "target": str(unit.unit_id)}))
				choices.add_child(target)
		return
	if cards.anchor_available and not cards.anchor_used:
		var anchor := Button.new()
		anchor.text = "Revenir à l'ancre · 1 PM"
		anchor.disabled = not interactive
		anchor.pressed.connect(func(): battle._cards_runtime.choose({"kind": "anchor"}))
		choices.add_child(anchor)
	var definitions: Array = cards.hand.map(func(uid): return preload("res://core/expedition/consumable_card_catalog.gd").card(cards.copy_for(uid).family, cards.copy_for(uid).family in cards.upgraded_ids))
	if definitions.any(func(row): return row.get("choosePull", false)):
		var pull := OptionButton.new()
		pull.add_item("Attraction · 1 case", 1)
		pull.add_item("Attraction · 2 cases", 2)
		pull.select(int(cards.action_options.get("pull", 1)) - 1)
		cards.action_options["pull"] = int(cards.action_options.get("pull", 1))
		pull.item_selected.connect(func(index): cards.action_options["pull"] = index + 1)
		choices.add_child(pull)
	if definitions.any(func(row): return row.get("chooseSacrifice", false)):
		var label := Label.new()
		label.text = "Garde à sacrifier :"
		choices.add_child(label)
		var sacrifice := SpinBox.new()
		sacrifice.max_value = floori(minf(actor.current_shield, .8 * actor.attack_power.get_value()))
		sacrifice.value = mini(int(cards.action_options.get("sacrifice", 0)), int(sacrifice.max_value))
		cards.action_options["sacrifice"] = int(sacrifice.value)
		sacrifice.value_changed.connect(func(value): cards.action_options["sacrifice"] = int(value))
		choices.add_child(sacrifice)


func _spell_face(button: Button, spell: Spell, cost: int) -> void:
	if str(spell.spell_id).begins_with("cc2_"):
		ModernCard.face(button, spell, GameManager.expedition.character.unit, cost)
		return
	if str(spell.spell_id).begins_with("class_") and not str(spell.spell_id).begins_with("class_basic_"):
		_class_spell_face(button, spell, cost)
		return
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
	title.text = spell.spell_name + "\nPO " + CardText.range_text(spell, GameManager.expedition.character.unit)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 3
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


func _class_spell_face(button: Button, spell: Spell, cost: int) -> void:
	const P := preload("res://ui/expedition/class_card_presentation.gd")
	var definition := preload("res://core/expedition/class_card_catalog.gd").row(str(spell.spell_id).trim_prefix("class_"))
	CardSkin.icon_button(button, preload("res://core/expedition/card_ecosystem_catalog.gd").CLASS_COLORS[str(definition[1])])
	var actor := GameManager.expedition.character.unit
	button.accessibility_name = CardText.details(spell, actor)
	var face := VBoxContainer.new()
	button.add_child(face)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.offset_left = 5
	face.offset_right = -5
	face.offset_top = 4
	face.offset_bottom = -4
	face.add_theme_constant_override("separation", 2)
	const Ecology := preload("res://core/expedition/card_ecosystem_catalog.gd")
	var tier := Ecology.tier(str(definition[0]))
	P.label(face, Ecology.TIER_NAMES[tier] + " · " + str(definition[9]), 12).modulate = Ecology.TIER_COLORS[tier]
	var title := P.label(face, spell.spell_name, 15)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var artwork := P.icon(face, spell.icon, 52)
	artwork.name = "CardArtwork"
	artwork.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var badges := HBoxContainer.new()
	face.add_child(badges)
	var price := P.label(badges, "%d PA" % cost, 15)
	price.modulate = Color("ffe0a0")
	var reach := P.label(badges, "PO " + CardText.range_text(spell, actor), 14)
	reach.name = "CardRange"
	reach.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reach.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reach.tooltip_text = "Portée minimale–maximale en cases."
	var amount := "%d dégâts · " % spell.get_scaled_damage(actor) if spell.get_scaled_damage(actor) > 0 else "%d garde · " % spell.get_scaled_shield(actor) if spell.get_scaled_shield(actor) > 0 else ""
	var effect := P.label(face, amount + P.rule(spell), 12)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.max_lines_visible = 2
	effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	effect.modulate = Ecology.role_color(str(definition[9]))
	HoverCard._ignore_pointer(face)
	face.modulate.a = .55 if button.disabled else 1.0


func _spell_stamp(actor: Unit, spell: Spell) -> Array:
	return [battle.spell_caster.get_spell_preparation_failure_reason(actor, spell), actor.get_spell_ap_cost(spell), CardText.range_text(spell, actor), spell.get_scaled_damage(actor), spell.get_scaled_shield(actor)]
