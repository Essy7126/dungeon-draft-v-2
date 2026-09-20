extends VBoxContainer
signal completed
const P := preload("res://ui/expedition/class_card_presentation.gd")
const Tile := preload("res://ui/expedition/class_card_tile.gd")
var chosen := ""
var error_label: Label


func _ready() -> void:
	_render()


func _render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var cards = GameManager.expedition.cards
	var reward: Dictionary = cards.pending_card_reward()
	if reward.is_empty():
		P.label(self, "Choix enregistré. Votre deck est prêt.", 22)
		_button(
			"Continuer",
			func():
				_save(),
		)
	else:
		P.label(self, "UNE CARTE POUR LA SUITE" if chosen == "" else "QUELLE CARTE REMPLACER ?", 22)
		if chosen != "":
			var incoming: Spell = cards.family_spell(chosen)
			P.label(self, incoming.spell_name + " · " + P.numbers(incoming, GameManager.expedition.character.unit) + " · " + P.rule(incoming), 16)
		P.label(
			self,
			"Prenez une technique ou passez. Les autres propositions seront laissées." if chosen
			== "" else "La carte remplacée reste en réserve. Votre deck conserve 10 cartes, au plus 2 exemplaires par technique.",
			16,
		)
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size.y = 290
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(scroll)
		var grid := GridContainer.new()
		grid.columns = 3 if chosen == "" else 5
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)
		for value in (reward.offers if chosen == "" else cards.active):
			var spell: Spell = cards.family_spell(value) if chosen == "" else cards.spells_for(
				value
			)[0]
			var tile := Tile.new()
			tile.name = ("RewardOffer_" if chosen == "" else "RewardReplace_") + str(value)
			grid.add_child(tile)
			tile.configure(
				spell,
				GameManager.expedition.character.unit,
				"Choisir cette technique" if chosen == "" else "Remplacer par "
				+ cards.family_spell(chosen).spell_name,
			)
			tile.pressed.connect(
				func():
					if chosen == "":
						chosen = value
						_render()
					else:
						_choose(chosen, value),
			)
		if chosen == "":
			_button(
				"Passer · Ne prendre aucune carte",
				func():
					_choose("", ""),
			)
		else:
			_button(
				"Prendre en réserve · Deck inchangé",
				func():
					_choose(chosen, ""),
			)
			_button(
				"Retour aux trois propositions",
				func():
					chosen = ""
					_render(),
			)
	error_label = P.label(self, "", 16)


func _button(title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	preload("res://ui/expedition/catabase_card_skin.gd").action(button)
	add_child(button)
	button.pressed.connect(action)


func _choose(family: String, replace_id: String) -> void:
	if not GameManager.expedition.cards.choose_card_reward(family, replace_id):
		error_label.text = "Remplacement impossible : deux exemplaires maximum par technique."
		return
	_render()
	_save()


func _save() -> void:
	if GameManager.save_expedition():
		completed.emit()
	else:
		error_label.text = "Sauvegarde impossible. Votre choix est conservé ici ; réessayez Continuer."
