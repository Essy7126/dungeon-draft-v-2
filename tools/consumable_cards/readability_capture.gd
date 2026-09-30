extends "res://tools/consumable_cards/integrated_capture.gd"
## Extends the real entry/Battle/cast path with bounded presentation checks.
const Spells := preload("res://core/expedition/consumable_card_spells.gd")


func capture(label: String) -> void:
	await super.capture(label)
	if label != "03_combat_main":
		return
	var cards = GameManager.expedition.cards
	var hand: Control = scene.action_bar._card_hand_view
	check(hand != null, "actual hand mounted")
	if hand == null:
		return
	var captions: Array[Node] = scene.action_bar.find_children(
		"CardUtilityCaption",
		"Label",
		true,
		false,
	)
	check(captions.size() == 4, "all four HUD shortcuts have a visible name")
	for caption: Label in captions:
		check(caption.get_parent().get_global_rect().encloses(caption.get_global_rect()), "HUD name inside shortcut")
		check(
			caption.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"HUD name leaves shortcut clickable",
		)
	_check_hand(hand, 5)
	var button: Button = hand.find_children("Play_*", "Button", true, false)[0]
	var hover = button.get_node("SpellHoverController")
	button.grab_focus()
	await get_tree().create_timer(.3).timeout
	check(hover._panel != null and hover._panel.visible, "keyboard explanation")
	await super.capture("03a_survol_clavier")
	button.release_focus()
	check(not hover._panel.visible, "focus exit closes explanation")
	var original: Spell = hover.spell
	# Every printed form is measured in the actual combat viewport, with its
	# longest unavailable-action context. No fabricated targets or balance result.
	for row in Catalog.data().cards:
		for upgraded in [false, true]:
			hover.spell = Spells.make_spell(str(row.id), upgraded)
			hover.context = "Terminez le choix de rétention ou de Relais."
			hover._pointer = true
			hover._show()
			for _frame in 3:
				await get_tree().process_frame
			_check_hover(hover._panel, hand, str(row.id) + str(upgraded))
			if str(row.id) == "t02" and upgraded:
				await super.capture("03b_effets_detailles")
	hover.spell = original
	hover._pointer = false
	hover._hide()
	var previous_hand: Array = cards.hand.duplicate()
	var previous_draw: Array = cards.draw_pile.duplicate()
	while cards.hand.size() < 7 and not cards.draw_pile.is_empty():
		cards.hand.append(cards.draw_pile.pop_back())
	await super.capture("03c_main_sept")
	_check_hand(hand, 7)
	var actor: Unit = GameManager.expedition.character.unit
	var ap: int = actor.current_ap
	actor.current_ap = 0
	await super.capture("03d_cartes_indisponibles")
	for play in hand.find_children("Play_*", "Button", true, false):
		check(play.disabled, "zero AP disables paid cards")
	actor.current_ap = ap
	cards.hand.assign(previous_hand)
	cards.draw_pile.assign(previous_draw)
	for _frame in 4:
		await get_tree().process_frame


func _check_hand(hand: Control, count: int) -> void:
	var buttons := hand.find_children("Play_*", "Button", true, false)
	check(buttons.size() == count, "hand size " + str(count))
	var viewport := get_viewport().get_visible_rect()
	for button in buttons:
		check(viewport.encloses(button.get_global_rect()), "card stays on screen")
		var art: Control = button.find_child("CardArtwork", true, false)
		check(art != null and art.size.x >= 52 and art.size.y >= 52, "readable art " + str(count))
		var range_label: Label = button.find_child("CardRange", true, false)
		check(range_label != null and not range_label.text.is_empty(), "effective range visible")
		check(button.find_child("CardAffinity", true, false) != null, "class affinity visible")
		check(
			button.find_child("CardRarityName", true, false) != null,
			"rarity named, not only colored",
		)
		check(button.find_child("CardElements", true, false) != null, "element symbols visible")
		for child in button.find_children("*", "Control", true, false):
			check(button.get_global_rect().grow(1).encloses(child.get_global_rect()), "face fits "
				+ str(child.name))


func _check_hover(panel: Control, hand: Control, id: String) -> void:
	check(get_viewport().get_visible_rect().encloses(panel.get_global_rect()), id
		+ " hover on screen")
	check(not panel.get_global_rect().intersects(hand.get_global_rect()), id
		+ " does not cover selection")
	for child in panel.find_children("*", "Control", true, false):
		if child.is_visible_in_tree():
			check(
				child.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				id + " passive hover " + str(child.name),
			)
