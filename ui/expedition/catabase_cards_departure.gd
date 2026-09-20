extends VBoxContainer
## Five deliberate card choices, persisted at every confirmed step.
const Catalog := preload("res://core/expedition/class_card_catalog.gd")
const PAGE := preload("res://ui/selection/cards_choice_page.gd")
var session: ExpeditionSession
var commit: Callable
var selection: Dictionary
var step := 0
var _status: Label

func configure(value: ExpeditionSession, action: Callable) -> void:
	session = value
	commit = action
	selection = session.preparation_draft.get("selection", CatabasePreparationCatalog.preset("marteau")).duplicate(true)
	selection["card_families"] = CatabaseCards.starter_families(selection)
	step = int(session.preparation_draft.get("step", 0))
	_render()

func _render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	PAGE.text(self, "AU-DELÀ DU SEUIL · Votre deck", 27)
	var trail := HBoxContainer.new()
	trail.add_theme_constant_override("separation", 8)
	add_child(trail)
	for index in 5:
		var marker := Button.new()
		marker.text = "✓ %d" % (index + 1) if index < step else str(index + 1)
		marker.custom_minimum_size = Vector2(48, 38)
		marker.disabled = index >= step
		marker.pressed.connect(func(): step = index; _render())
		trail.add_child(marker)
	PAGE.text(self, "%s · 10 cartes · main de 4 · 2 gestes de secours hors pioche" % (Catalog.CLASSES[selection.class_id][0] if selection.has("class_id") else CatabasePreparationCatalog.WEAPONS[selection.weapon][0]), 16)
	if step < 5:
		var options: Array = []
		var earlier: Array = selection.card_families.slice(0, step)
		for id in _pool():
			if id in earlier or (id == "exp_ct_repercussion" and selection.relic != "urne"): continue
			var spell := _spell(id)
			options.append({"id": id, "title": spell.spell_name, "icon": spell.icon,
				"impact": preload("res://ui/expedition/catabase_card_text.gd").effect(spell, session.character.unit) + "\n\n" + spell.description,
				"details": "Ajoute 2 copies à votre deck : %d → %d cartes choisies sur 10.\nCette manœuvre sera jouable quand elle sera piochée dans votre main de 4 cartes." % [step * 2, (step + 1) * 2]})
		var family: String = selection.card_families[step]
		if not options.any(func(option): return option.id == family):
			family = str(options[0].id)
			selection.card_families[step] = family
		var page := PAGE.new()
		page.name = "CardsSingleChoice"
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(page)
		page.configure("Manœuvre %d / 5" % (step + 1), "Choisissez une manœuvre. Confirmez ses deux copies avant de découvrir le choix suivant.", options, family)
		page.chosen.connect(func(id): selection.card_families[step] = id; _render())
	else:
		PAGE.text(self, "Votre deck est prêt · 10 cartes", 25)
		PAGE.text(self, "Quatre cartes seront piochées à chaque tour. Vos deux gestes d’arme resteront toujours disponibles.", 18)
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)
		var summary := VBoxContainer.new()
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(summary)
		for family in selection.card_families:
			PAGE.text(summary, "2 × " + _spell(family).spell_name, 22)
	_status = PAGE.text(self, "", 16)
	_status.name = "CardsDepartureStatus"
	var navigation := HBoxContainer.new()
	add_child(navigation)
	var back := Button.new()
	back.text = "← Choix précédent"
	back.name = "CardsPreviousChoice"
	back.disabled = step == 0
	back.custom_minimum_size = Vector2(210, 46)
	back.pressed.connect(func(): step -= 1; _render())
	navigation.add_child(back)
	var next := Button.new()
	next.name = "CardsConfirmChoice" if step < 5 else "ConfirmCatabaseDeparture"
	next.text = "Confirmer ces 2 cartes · Suivant →" if step < 5 else "Entrer dans la run · 10 cartes →"
	next.custom_minimum_size.y = 46
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(next)
	next.pressed.connect(func():
		if step < 5:
			_repair_remaining()
			if not GameManager.save_cards_preparation_draft(selection, step + 1):
				_status.text = "La sauvegarde n’a pas abouti. Réessayez pour conserver ce choix."
				return
			step += 1
			_render()
		else:
			next.disabled = true
			var result: Dictionary = commit.call(selection.duplicate(true))
			_status.text = str(result.get("message", ""))
			if not result.get("success", false): next.disabled = false)

func _repair_remaining() -> void:
	var used: Array = selection.card_families.slice(0, step + 1)
	for index in range(step + 1, 5):
		var family: String = selection.card_families[index]
		if family in used or (family == "exp_ct_repercussion" and selection.relic != "urne"):
			for candidate in _pool():
				if candidate not in used and (candidate != "exp_ct_repercussion" or selection.relic == "urne"):
					family = candidate
					break
		selection.card_families[index] = family
		used.append(family)

func _pool() -> Array:
	return Catalog.starter_pool(selection.class_id) if selection.has("class_id") else CatabasePreparationCatalog.TECHNIQUES

func _spell(id: String) -> Spell:
	return Catalog.make_spell(id, 2) if selection.has("class_id") else session.build.catalog.get_spell(id)
