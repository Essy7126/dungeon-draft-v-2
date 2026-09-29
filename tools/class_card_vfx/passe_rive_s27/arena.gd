extends "res://tools/class_card_vfx/passe_rive_assignments.gd"
## The real public renderer and SpellCaster; fallback must not spend a card copy.
const GUARDS := ["n02", "g05", "fallback_guard"]
const ProductionBackend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
var capture_prefix := "base_"
var facts_before: Dictionary = { }
var early_facts_unchanged := true
var ward_seen := false
var contre_arm_seen := false
const ContrePlayer := preload("res://vfx/class_cards/contre/player.gd")


func _review_cases() -> Array:
	return GUARDS


func _setup_review_backend() -> void:
	_check(
		visual.sprite_backend.get_script() == ProductionBackend,
		"Unmodified public production backend",
	)
	visual._sync_cards_mode()


func _exercise() -> void:
	var automated := capture_mode
	capture_mode = false
	current_id = "n02"
	await super._exercise()
	get_window().title = "Passe-Rive — Sceau de parade · 3 cartes"
	selector.select(0)
	label.text = "SCEAU DE PARADE\nGarde brève · Contre préparé · secours\nNouveau geste SE · 0,72 s"
	record_card = "n02"
	capture_mode = automated
	print("PASSE_RIVE_S27_GAME_READY")
	if automated:
		for id in GUARDS:
			await _play_current(id)
		capture_prefix = "upgraded_"
		record_card = ""
		for id in ["n02", "g05"]:
			session.cards.upgraded_ids.append(id)
			await _play_current(id)
		_finish()


func _prepare_card_fixture(_id: String) -> void:
	facts_before = _facts()
	early_facts_unchanged = true
	ward_seen = false
	contre_arm_seen = false


func _facts() -> Dictionary:
	return {
		"hero_hp": hero.current_hp,
		"shield": hero.current_shield,
		"target_hp": target.current_hp,
		"hero_states": CurrentTurns.Effects.states(hero).duplicate(true),
	}


func _process(delta: float) -> void:
	if busy and not facts_before.is_empty():
		if releases == 0:
			early_facts_unchanged = early_facts_unchanged and _facts() == facts_before
		ward_seen = ward_seen or visual.sprite_backend.get_runtime_state().get(
				"ward_visible",
				false,
			)
		for effect in router.effects:
			if is_instance_valid(effect) and effect.get_script() == ContrePlayer:
				contre_arm_seen = contre_arm_seen or (effect.mode == "arm" and not effect.closed)
	super._process(delta)


func _play_current(id: String) -> void:
	await super._play_current(id)
	_check(early_facts_unchanged, id + " no shield or counter before release")
	_check(release_state.get("frame", -1) == 5, id + " raised palm at release")
	_check(hero.grid_pos == original_cell, id + " caster remains planted")
	_check(hero.current_shield > 0, id + " actual shield granted")
	_check(target.current_hp == int(facts_before.target_hp), id + " no immediate attack")
	if id == "g05":
		_check(contre_arm_seen, "Confirmed counter uses dedicated arming effect")
		_check(not ward_seen, "Counter does not duplicate the generic guard arc")
		var hold: Dictionary = router.holds.get("%s:cc2_counter" % hero.get_instance_id(), { })
		_check(
			is_instance_valid(hold.get("fx")),
			"Counter readiness token persists until incoming hit",
		)
	else:
		_check(ward_seen, id + " bronze arc follows confirmed shield grant")
	_check(not visual.sprite_backend.guard.visible, id + " guard body hidden on recovery")
	_check(not visual.sprite_backend.guard.ward.visible, id + " bronze arc finishes")
	casts.back()["shield_granted"] = hero.current_shield
	casts.back()["ward_seen"] = ward_seen
	casts.back()["contre_arm_seen"] = contre_arm_seen
	if id == "fallback_guard":
		_check(
			battle.spell_caster.get_cast_failure_reason(
				hero,
				session.cards.family_spell(id),
				hero.grid_pos,
			) != &"",
			"Fallback cannot be used twice in the same activation",
		)
	if id == "g05":
		_check(CurrentTurns.Effects.states(hero).has("counter"), "Counter waits for incoming hit")
		var hp := target.current_hp
		CurrentTurns.Effects.hit(hero, target, 1.0, false, "attack")
		_check(target.current_hp < hp, "Real incoming adjacent hit triggers the counter")
		_check(not CurrentTurns.Effects.states(hero).has("counter"), "Counter consumed once on hit")
		_check(not router.holds.has("%s:cc2_counter" % hero.get_instance_id()), "Consumed counter token removed")
		var ripostes := 0
		for effect in router.effects:
			if (
				is_instance_valid(effect) and effect.get_script() == ContrePlayer
				and effect.mode == "riposte"
			):
				ripostes += 1
		_check(ripostes == 1, "Actual incoming hit creates one dedicated riposte")
		casts.back()["counter_damage"] = hp - target.current_hp
		hp = target.current_hp
		CurrentTurns.Effects.hit(hero, target, 1.0, false, "attack")
		_check(target.current_hp == hp, "Second hit cannot repeat consumed counter")


func _capture(id: String) -> void:
	await super._capture(capture_prefix + id)
