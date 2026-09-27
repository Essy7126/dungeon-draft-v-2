extends "res://tools/class_card_vfx/passe_rive_assignments.gd"
## Real cards on the public production backend, including status prerequisites.
const INCANTATIONS := ["g01", "g08", "l02", "t03", "a09", "t06", "t09"]
const ProductionBackend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
var capture_prefix := "base_"
var early_facts_unchanged := true
var facts_before: Dictionary = { }


func _review_cases() -> Array:
	return INCANTATIONS


func _setup_review_backend() -> void:
	_check(
		visual.sprite_backend.get_script() == ProductionBackend,
		"Public profile uses production backend without replacement",
	)
	visual._sync_cards_mode()


func _exercise() -> void:
	var automated := capture_mode
	capture_mode = false
	current_id = "t03"
	await super._exercise()
	get_window().title = "Passe-Rive — Incantation intégrée · 7 cartes"
	selector.select(INCANTATIONS.find("t03"))
	label.text = "INCANTATION DU SCEAU\nSept cartes · leurs effets réels\nSud-est : nouveau geste · autres vues : geste existant"
	record_card = "t03"
	capture_mode = automated
	print("PASSE_RIVE_S26_GAME_READY")
	if automated:
		for id in INCANTATIONS:
			await _play_current(id)
		capture_prefix = "upgraded_"
		record_card = ""
		for id in INCANTATIONS:
			session.cards.upgraded_ids.append(id)
			await _play_current(id)
		_finish()


func _prepare_card_fixture(id: String) -> void:
	if id in ["a09", "t09"]:
		CurrentTurns.Effects.apply_state(target, "mark", .4, 2, hero)
	if id == "l02":
		hero.current_hp = maxi(1, hero.max_hp.get_int() / 2)
	facts_before = _facts()
	early_facts_unchanged = true


func _facts() -> Dictionary:
	return {
		"hero_hp": hero.current_hp,
		"shield": hero.current_shield,
		"target_hp": target.current_hp,
		"target_states": CurrentTurns.Effects.states(target).duplicate(true),
		"surfaces": battle.terrain_effects.active_surface_cells().duplicate(),
	}


func _process(delta: float) -> void:
	if busy and releases == 0 and not facts_before.is_empty():
		early_facts_unchanged = early_facts_unchanged and _facts() == facts_before
	super._process(delta)


func _play_current(id: String) -> void:
	await super._play_current(id)
	_check(
		early_facts_unchanged,
		id + " no damage, healing, shield, status or terrain before release",
	)
	_check(release_state.get("frame", -1) == 6, id + " open palms at committed release")
	_check(hero.grid_pos == original_cell, id + " caster remains planted")
	if id in ["g01", "g08", "l02"]:
		_check(hero.current_shield > 0, id + " grants the real shield")
	if id == "l02":
		_check(hero.current_hp > int(facts_before.hero_hp), "Real healing occurs")
	if id == "t03":
		_check(CurrentTurns.Effects.states(target).has("mark"), "Real mark applied")
	if id == "a09":
		_check(
			not CurrentTurns.Effects.states(target).has("mark"),
			"Stasis consumes its mark prerequisite",
		)
	if id == "t06":
		_check(
			not battle.terrain_effects.active_surface_cells().is_empty(),
			"Actual ice terrain created",
		)
	if id == "t09":
		_check(target.current_hp < int(facts_before.target_hp), "Real resonance deals damage")


func _capture(id: String) -> void:
	await super._capture(capture_prefix + id)
