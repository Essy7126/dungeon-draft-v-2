extends "res://tools/class_card_vfx/passe_rive_assignments.gd"
## Real production casts and turn completion. Seeded hand; enemy AI paused.
const ProductionBackend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")


class ReviewRuntime extends "res://battle/consumable_cards_runtime.gd":
	func checkpoint() -> bool:
		return true # Visual fixture never writes a player's combat save.


var scenario := "base"
var facts_before: Dictionary = { }
var facts_at_contact: Dictionary = { }
var early_unchanged := true
var heal_seen := false
var guard_seen := false
var duplicate_seen := false
var turn_ended_count := 0
var end_saw_idle := false
var record_budget := 0.0
var saved_guard := false


func _review_cases() -> Array:
	return ["i01", "l02"]


func _setup_review_backend() -> void:
	_check(visual.sprite_backend.get_script() == ProductionBackend, "Public S30 production backend")
	visual._sync_cards_mode()


func _exercise() -> void:
	var automated := capture_mode
	capture_mode = false
	current_id = "i01"
	await super._exercise()
	battle._cards_runtime = ReviewRuntime.new()
	battle.add_child(battle._cards_runtime)
	battle._cards_runtime.setup(battle, session)
	EventBus.turn_ended.connect(_turn_ended)
	get_window().title = "Passe-Rive — Seconde aurore et Grâce du bronze"
	selector.select(0)
	label.text = "SECONDE AURORE\nLumière ascendante → soin → protection de bronze\nGrâce du bronze : ouverture plus brève"
	capture_mode = automated
	print("PASSE_RIVE_S30_READY")
	if automated:
		for id in _review_cases():
			for variant in ["base", "upgraded", "full_hp", "guard_cap"]:
				scenario = variant
				session.cards.upgraded_ids.erase(id)
				if variant == "upgraded":
					session.cards.upgraded_ids.append(id)
				record_card = id if id == "i01" and variant == "base" else ""
				await _play_current(id)
		await _reject_without_ap()
		_finish()


func _set_review_facing() -> void:
	visual.set_facing(Vector2i.RIGHT)
	visual.play_idle()


func _facts() -> Dictionary:
	return {
		"hp": hero.current_hp,
		"shield": hero.current_shield,
		"ap": hero.current_ap,
		"mp": hero.current_mp,
		"consumed": hero.activation_consumed,
	}


func _play_current(id: String) -> void:
	if busy:
		return
	play_button.disabled = true
	selector.disabled = true
	current_id = id
	selector.select(_review_cases().find(id))
	router.clear()
	router.bind_terrain(battle.terrain_effects)
	for unit: Unit in battle.units:
		unit.clear_shield()
		CurrentTurns.Effects.states(unit).clear()
		for status in unit.get_active_statuses().duplicate():
			unit.remove_status(status.data.get_effective_status_id())
	battle._turn_end_committed = false
	battle.turn_queue.setup([hero, target])
	battle.turn_queue.start()
	battle.turn_state.begin_player_turn()
	hero.start_turn()
	var cards = session.cards
	cards.start_turn()
	cards.used_families.clear()
	cards.pending_choice.clear()
	_check(_position_pair(), id + " legal grounded self-cast")
	original_cell = hero.grid_pos
	_set_review_facing()
	hero.current_hp = (
		hero.max_hp.get_int()
		if scenario == "full_hp"
		else maxi(1, hero.max_hp.get_int() / 5)
	)
	if scenario == "guard_cap":
		hero.add_shield(Math.rounded(2.5 * hero.attack_power.get_value()))
	# Remove the setup-only grant burst; the restored hold still shows existing guard.
	router.clear()
	router.bind_terrain(battle.terrain_effects)
	var copy_id: String = cards.add_copy(id)
	cards.active.append(copy_id)
	cards.hand.assign([copy_id])
	cards.selected = copy_id
	var spell: Spell = cards.family_spell(id)
	var row := CurrentSpells.definition(id, id in cards.upgraded_ids)
	var failure: StringName = battle.spell_caster.get_cast_failure_reason(
		hero,
		spell,
		hero.grid_pos,
	)
	_check(failure == &"", id + " actual card legal: " + str(failure))
	if failure != &"":
		play_button.disabled = false
		selector.disabled = false
		return
	facts_before = _facts()
	facts_at_contact = { }
	last_report = { }
	release_state = { }
	releases = 0
	heal_seen = false
	guard_seen = false
	duplicate_seen = false
	saved_guard = false
	early_unchanged = true
	turn_ended_count = 0
	end_saw_idle = false
	label.text = str(row.name) + "\nOuverture → restauration → protection"
	busy = true
	recording = capture_mode and record_card == id
	await _capture(id + "_before")
	await get_tree().create_timer(.20).timeout
	battle._on_request_cast_spell(spell, hero.grid_pos)
	var deadline := Time.get_ticks_msec() + 10000
	var contact_saved := false
	while battle._spell_resolution_pending and Time.get_ticks_msec() < deadline:
		if releases > 0 and not contact_saved:
			contact_saved = true
			await _capture(id + "_release")
		if guard_seen and not saved_guard:
			saved_guard = true
			await _capture(id + "_guard")
		await get_tree().process_frame
	await get_tree().create_timer(.35).timeout
	recording = false
	var healed: int = int(facts_at_contact.get("hp", -1)) - int(facts_before.hp)
	var guarded: int = int(facts_at_contact.get("shield", -1)) - int(facts_before.shield)
	var mods: Dictionary = Math.equipment_mods(cards.equipped)
	var basis: float = hero.max_hp.get_value() if id == "i01" else hero.attack_power.get_value()
	var expected_heal := mini(
		hero.max_hp.get_int() - int(facts_before.hp),
		Math.rounded(basis * float(row.amount) * (1.0 + float(mods.get("healing", 0)))),
	)
	var expected_guard := Math.guard(
		hero.attack_power.get_value(),
		float(row.shield),
		float(mods.get("guard", 0)) + .05 * int(cards.attributes.get("resolve", 0)),
		int(facts_before.shield),
	)
	_check(not battle._spell_resolution_pending, id + " battle unlocked after recovery")
	_check(early_unchanged, id + " no premature healing guard or resource use")
	_check(
		releases == 1 and release_state.get("animation") == ProductionBackend.RenewBody.CLIP,
		id + " one correct gesture release",
	)
	_check(
		not last_report.is_empty() and not last_report.get("failed", false),
		id + " actual spell succeeds",
	)
	_check(cards.consumed.has(copy_id), id + " exactly selected copy consumed")
	_check(
		healed == expected_heal and int(last_report.get("healing_total", -1)) == healed,
		id + " exact capped healing",
	)
	_check(
		guarded == expected_guard and int(last_report.get("shield_increase_total", -1)) == guarded,
		id + " exact capped guard",
	)
	_check(heal_seen == (healed > 0), id + " vitality accent follows actual healing")
	_check(guard_seen == (guarded > 0), id + " bronze facets follow actual guard gain")
	_check(not duplicate_seen, id + " no duplicate generic bursts")
	_check(hero.grid_pos == original_cell, id + " feet stay on original cell")
	_check(
		not visual.sprite_backend.renew.visible
		and visual.sprite_backend.animated_sprite.self_modulate == Color.WHITE,
		id + " layers expire into native idle",
	)
	_check(
		facts_at_contact.get("consumed", false) == (id == "i01"),
		id + " correct activation consumption",
	)
	_check(
		int(facts_at_contact.get("ap", -1))
		== (0 if id == "i01" else int(facts_before.ap) - int(row.ap)),
		id + " correct AP after cast",
	)
	_check(turn_ended_count == (1 if id == "i01" else 0), id + " correct automatic end turn")
	if id == "i01":
		_check(end_saw_idle, id + " turn ends only after native recovery")
		_check(battle.turn_queue.get_current_unit() == target, id + " queue advances to next actor")
		_check(
			int(facts_at_contact.get("mp", -1)) == 0,
			id + " remaining MP cleared by activation end",
		)
	casts.append(
		{
			"id": id,
			"scenario": scenario,
			"release": release_state,
			"healing": healed,
			"guard": guarded,
			"heal_seen": heal_seen,
			"guard_seen": guard_seen,
			"end_turn": turn_ended_count,
			"end_saw_idle": end_saw_idle,
			"copy_consumed": cards.consumed.has(copy_id),
			"before": facts_before,
			"contact": facts_at_contact,
		}
	)
	await _capture(id + "_recovery")
	busy = false
	play_button.disabled = false
	selector.disabled = false
	label.text += "\nRepos · %d PV rendus · %d garde" % [healed, guarded]


func _contact(caster: Unit, _spell: Spell, _report: Dictionary) -> void:
	if caster == hero and busy:
		facts_at_contact = _facts()


func _turn_ended(unit: Unit, _reason: StringName) -> void:
	if busy and unit == hero:
		turn_ended_count += 1
		end_saw_idle = (
			str(visual.sprite_backend.get_runtime_state().animation).begins_with("idle_")
			and not visual.sprite_backend.renew.visible
		)


func _process(delta: float) -> void:
	if busy and is_instance_valid(visual):
		if releases == 0:
			early_unchanged = early_unchanged and _facts() == facts_before
		var state: Dictionary = visual.sprite_backend.get_runtime_state()
		heal_seen = heal_seen or bool(state.get("renew_heal_visible", false))
		guard_seen = guard_seen or bool(state.get("renew_guard_visible", false))
		for fx in router.effects:
			if is_instance_valid(fx) and not fx.closed and not fx.persistent:
				duplicate_seen = duplicate_seen or fx.recipe.get("id", "") in [
						"heal_apply",
						"guard_apply",
					]
	record_budget += delta
	if record_budget >= 1.0 / 30.0:
		record_budget = fmod(record_budget, 1.0 / 30.0)
		super._process(delta)


func _reject_without_ap() -> void:
	battle._turn_end_committed = false
	battle.turn_queue.setup([hero, target])
	battle.turn_queue.start()
	battle.turn_state.begin_player_turn()
	hero.start_turn()
	hero.current_ap = 0
	session.cards.start_turn()
	session.cards.used_families.clear()
	var copy_id: String = session.cards.add_copy("i01")
	session.cards.active.append(copy_id)
	session.cards.hand.assign([copy_id])
	session.cards.selected = copy_id
	var before := _facts()
	var spell: Spell = session.cards.family_spell("i01")
	battle._on_request_cast_spell(spell, hero.grid_pos)
	await get_tree().create_timer(.25).timeout
	_check(
		_facts() == before and not session.cards.consumed.has(copy_id),
		"Rejected restoration changes no resource",
	)
	_check(not visual.sprite_backend.renew.visible, "Rejected restoration has no animation or aura")


func _capture(id: String) -> void:
	await super._capture(scenario + "_" + id)
