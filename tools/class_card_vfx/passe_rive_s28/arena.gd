extends "res://tools/class_card_vfx/passe_rive_assignments.gd"
## Actual card casts through the public renderer, with edge cases for confirmed siphon.
const ProductionBackend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")
var scenario := "base"
var facts_before: Dictionary = { }
var facts_resolved: Dictionary = { }
var early_unchanged := true
var siphon_seen := false
var glint_seen := false
var stock_heal_seen := false


func _review_cases() -> Array:
	return ["t07"]


func _setup_review_backend() -> void:
	_check(visual.sprite_backend.get_script() == ProductionBackend, "Public production backend")
	visual._sync_cards_mode()


func _exercise() -> void:
	var automated := capture_mode
	capture_mode = false
	current_id = "t07"
	await super._exercise()
	get_window().title = "Passe-Rive — Prélèvement"
	selector.select(0)
	label.text = "PRÉLÈVEMENT\nViser → saisir → absorber → relâcher\n0,94 s · soin selon les PV retirés"
	record_card = "t07"
	capture_mode = automated
	print("PASSE_RIVE_S28_GAME_READY")
	if automated:
		for variant in ["base", "upgraded", "full_hp", "shielded", "lethal"]:
			scenario = variant
			session.cards.upgraded_ids.erase("t07")
			if variant == "upgraded":
				session.cards.upgraded_ids.append("t07")
			await _play_current("t07")
			record_card = ""
		# Let the target finish its death before synchronous PNG export stalls frames.
		await get_tree().create_timer(2.0).timeout
		_finish()


func _prepare_card_fixture(_id: String) -> void:
	if scenario != "full_hp":
		hero.current_hp = maxi(1, hero.max_hp.get_int() / 2)
	if scenario == "shielded":
		target.add_shield(10000)
	if scenario == "lethal":
		# Keep the fixture in battle through recovery; victory rewards otherwise
		# restore HP/AP and replace the scene before the visual assertions.
		battle._begin_outcome_deferral()
		target.current_hp = 1
	facts_before = _facts()
	facts_resolved = { }
	early_unchanged = true
	siphon_seen = false
	glint_seen = false
	stock_heal_seen = false


func _facts() -> Dictionary:
	return {
		"hero_hp": hero.current_hp,
		"target_hp": target.current_hp,
		"shield": target.current_shield,
	}


func _resolved(unit: Unit, action: StringName, kind: StringName, report: Dictionary) -> void:
	super._resolved(unit, action, kind, report)
	if unit == hero and kind == &"spell":
		facts_resolved = _facts()


func _process(delta: float) -> void:
	if busy and not facts_before.is_empty():
		if releases == 0:
			early_unchanged = early_unchanged and _facts() == facts_before
		var state: Dictionary = visual.sprite_backend.get_runtime_state()
		siphon_seen = siphon_seen or bool(state.get("siphon_visible", false))
		glint_seen = glint_seen or bool(state.get("healing_glint", false))
		for effect in router.effects:
			if is_instance_valid(effect) and not effect.closed:
				stock_heal_seen = stock_heal_seen or effect.recipe.get("id", "") == "heal_apply"
	super._process(delta)


func _play_current(id: String) -> void:
	await super._play_current(id)
	var damage: int = int(facts_before.target_hp) - target.current_hp
	var healing: int = hero.current_hp - int(facts_before.hero_hp)
	var bonus := float(Math.equipment_mods(session.cards.equipped).get("healing", 0))
	var expected := mini(
		hero.max_hp.get_int() - int(facts_before.hero_hp),
		Math.rounded(damage * 0.5 * (1.0 + bonus)),
	)
	_check(early_unchanged, scenario + " no HP or shield changes before release")
	_check(release_state.get("frame", -1) == 5, scenario + " grasp owns release")
	_check(hero.grid_pos == original_cell, scenario + " caster remains planted")
	_check(int(last_report.get("hp_damage_total", -1)) == damage, scenario + " actual HP damage")
	_check(int(last_report.get("healing_total", -1)) == healing, scenario + " actual healing")
	_check(healing == expected, scenario + " heal uses actual damage, modifiers and HP cap")
	_check(
		_facts() == facts_resolved,
		scenario + " return VFX cannot apply damage or healing again",
	)
	_check(siphon_seen == (damage > 0), scenario + " thread requires HP damage")
	_check(glint_seen == (healing > 0), scenario + " glint requires actual healing")
	_check(not stock_heal_seen, scenario + " small hand accent replaces the oversized stock pulse")
	_check(not visual.sprite_backend.drain.visible, scenario + " body recovers to idle")
	_check(not visual.sprite_backend.drain.siphon.visible, scenario + " siphon expires")
	if scenario == "shielded":
		_check(damage == 0 and healing == 0, "Full absorption grants no vitality")
	if scenario == "full_hp":
		_check(damage > 0 and healing == 0, "Full HP has a siphon without a healing glint")
	if scenario == "lethal":
		_check(damage == 1 and not target.is_alive, "Overkill uses the one HP actually removed")
	casts.back().merge(
		{
			"scenario": scenario,
			"damage": damage,
			"healing": healing,
			"siphon_seen": siphon_seen,
			"glint_seen": glint_seen,
			"same_facts_after_return": _facts() == facts_resolved,
		}
	)


func _capture(id: String) -> void:
	await super._capture(scenario + "_" + id)
