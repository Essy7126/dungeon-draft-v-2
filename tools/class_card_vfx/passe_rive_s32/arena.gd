extends "res://tools/class_card_vfx/passe_rive_assignments.gd"
## Forty actual production casts; this fixture cannot write the player's save.
const Production := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
const DIRECTIONS := {
	"E": Vector2i(1, -1),
	"SE": Vector2i.RIGHT,
	"S": Vector2i(1, 1),
	"SW": Vector2i.DOWN,
	"W": Vector2i(-1, 1),
	"NW": Vector2i.LEFT,
	"N": Vector2i(-1, -1),
	"NE": Vector2i.UP,
}


class ReviewRuntime extends "res://battle/consumable_cards_runtime.gd":
	func checkpoint() -> bool:
		return true


var review_direction := "SE"
var scenario := "base"
var before: Dictionary = { }
var contact: Dictionary = { }
var early_unchanged := true
var glyphs_seen := 0
var duplicate_seen := false
var direction_selector: OptionButton
var variant_selector: OptionButton
var record_budget := 0.0


func _review_cases() -> Array:
	return ["n08"]


func _setup_review_backend() -> void:
	_check(visual.sprite_backend.get_script() == Production, "Public production backend")
	visual._sync_cards_mode()


func _build_ui() -> void:
	super._build_ui()
	direction_selector = OptionButton.new()
	for facing in DIRECTIONS:
		direction_selector.add_item(facing)
	direction_selector.select(1)
	direction_selector.item_selected.connect(
		func(index):
			review_direction = DIRECTIONS.keys()[index],
	)
	play_button.get_parent().add_child(direction_selector)
	variant_selector = OptionButton.new()
	for title in [
		"Base · 2 cartes",
		"Améliorée · 3 cartes",
		"Une seule carte disponible",
		"Pioche vide",
		"Main pleine · une place libérée",
	]:
		variant_selector.add_item(title)
	variant_selector.item_selected.connect(
		func(index):
			scenario = ["base", "upgraded", "limited", "empty", "full"][index],
	)
	play_button.get_parent().add_child(variant_selector)


func _exercise() -> void:
	var automated := capture_mode
	capture_mode = false
	current_id = "n08"
	await super._exercise()
	battle._cards_runtime = ReviewRuntime.new()
	battle.add_child(battle._cards_runtime)
	battle._cards_runtime.setup(battle, session)
	get_window().title = "Passe-Rive — Recentrage · huit directions"
	label.text = "RECENTRAGE\nConcentration → pioche réelle → repos\n0,8 s · 1 PA"
	capture_mode = automated
	if automated:
		for direction in DIRECTIONS:
			review_direction = direction
			direction_selector.select(DIRECTIONS.keys().find(direction))
			for version in ["base", "upgraded", "limited", "empty", "full"]:
				scenario = version
				variant_selector.select(
					["base", "upgraded", "limited", "empty", "full"].find(version)
				)
				await _play_current("n08")
		await _reject_without_ap()
		_finish()


func _facts() -> Dictionary:
	return {
		"hp": hero.current_hp,
		"shield": hero.current_shield,
		"ap": hero.current_ap,
		"mp": hero.current_mp,
		"hand": session.cards.hand.duplicate(),
		"pile": session.cards.draw_pile.duplicate(),
		"activation": hero.activation_consumed,
	}


func _play_current(id: String) -> void:
	if busy:
		return
	play_button.disabled = true
	selector.disabled = true
	direction_selector.disabled = true
	variant_selector.disabled = true
	current_id = id
	router.clear()
	router.bind_terrain(battle.terrain_effects)
	battle._turn_end_committed = false
	battle.turn_queue.setup([hero, target])
	battle.turn_queue.start()
	battle.turn_state.begin_player_turn()
	hero.start_turn()
	var cards = session.cards
	cards.start_turn()
	cards.used_families.clear()
	cards.pending_choice.clear()
	cards.upgraded_ids.erase(id)
	if scenario == "upgraded":
		cards.upgraded_ids.append(id)
	cards.hand_capacity = 5
	cards.draw_pile.clear()
	cards.discard.clear()
	cards.hand.clear()
	var copy_id: String = cards.add_copy(id)
	cards.active.append(copy_id)
	cards.hand.append(copy_id)
	if scenario == "full":
		for i in 4:
			var held: String = cards.add_copy("n01")
			cards.active.append(held)
			cards.hand.append(held)
	var available := 0 if scenario == "empty" else (1 if scenario == "limited" else 3)
	for i in available:
		var uid: String = cards.add_copy(["n02", "n03", "n04"][i])
		cards.active.append(uid)
		cards.draw_pile.append(uid)
	cards.selected = copy_id
	cards.changed.emit()
	_check(_position_pair(), "Legal grounded self cast")
	original_cell = hero.grid_pos
	visual.set_facing(DIRECTIONS[review_direction])
	visual.play_idle()
	var spell: Spell = cards.family_spell(id)
	var failure: StringName = battle.spell_caster.get_cast_failure_reason(
		hero,
		spell,
		hero.grid_pos,
	)
	_check(failure == &"", "Legal Recentrage " + str(failure))
	if failure != &"":
		return
	before = _facts()
	contact = { }
	last_report = { }
	release_state = { }
	releases = 0
	early_unchanged = true
	glyphs_seen = 0
	duplicate_seen = false
	busy = true
	recording = capture_mode and review_direction == "SE" and scenario == "base"
	label.text = "RECENTRAGE · " + review_direction + " · " + scenario + "\nConcentration → pioche → repos"
	await _capture("before")
	await get_tree().create_timer(.2).timeout
	battle._on_request_cast_spell(spell, hero.grid_pos)
	var deadline := Time.get_ticks_msec() + 10000
	var captured := false
	while battle._spell_resolution_pending and Time.get_ticks_msec() < deadline:
		if glyphs_seen > 0 and not captured:
			captured = true
			await _capture("draw")
		await get_tree().process_frame
	await get_tree().create_timer(.25).timeout
	recording = false
	var expected := mini(available, 3 if scenario == "upgraded" else 2)
	if scenario == "full":
		expected = 1 # Consuming Recentrage frees exactly one slot before its draw.
	_check(not battle._spell_resolution_pending, "Battle unlocks")
	_check(early_unchanged, "No draw cost or glyph before release")
	_check(
		releases == 1 and release_state.get("animation") == Production.RecenterBody.CLIP,
		"One Recentrage release",
	)
	_check(release_state.get("frame") == 6, "Draw marker at pose 6")
	_check(
		release_state.get("authored_direction") == review_direction
		and not release_state.get("mirrored", true),
		"Correct authored direction",
	)
	_check(
		not last_report.is_empty() and not last_report.get("failed", false),
		"Actual card resolves",
	)
	_check(int(last_report.get("cards_drawn", -1)) == expected, "Report counts actual draw")
	_check(
		cards.hand.size() == before.hand.size() - 1 + expected,
		"Hand gains exact number of copies",
	)
	_check(cards.draw_pile.size() == available - expected, "Draw pile loses exact copies")
	var newly_drawn: Array = []
	for uid in cards.hand:
		if uid not in before.hand:
			newly_drawn.append(uid)
	_check(newly_drawn.size() == expected, "Only existing deck copies are drawn")
	for uid in newly_drawn:
		_check(uid in before.pile, "Drawn UID belongs to the original deck")
	_check(cards.consumed.has(copy_id) and copy_id not in cards.hand, "Selected card consumed")
	_check(hero.current_ap == int(before.ap) - 1, "One AP spent")
	_check(
		hero.current_hp == before.hp and hero.current_shield == before.shield,
		"No healing or protection invented",
	)
	_check(
		not hero.activation_consumed and hero.current_mp == before.mp,
		"Activation and movement remain available",
	)
	_check(glyphs_seen == expected, "Glyph count follows actual draw")
	_check(not duplicate_seen, "No duplicate generic protection effect")
	_check(hero.grid_pos == original_cell, "Grounded on original cell")
	_check(
		not visual.sprite_backend.recenter.visible
		and visual.sprite_backend.animated_sprite.self_modulate == Color.WHITE,
		"Native recovery clears all layers",
	)
	casts.append(
		{
			"id": id,
			"scenario": scenario,
			"facing": review_direction,
			"release": release_state,
			"expected": expected,
			"drawn": last_report.get("cards_drawn", -1),
			"glyphs_seen": glyphs_seen,
			"copy_consumed": cards.consumed.has(copy_id),
			"before": before,
			"contact": contact,
		}
	)
	await _capture("recovery")
	busy = false
	play_button.disabled = false
	selector.disabled = false
	direction_selector.disabled = false
	variant_selector.disabled = false
	label.text += "\n%d carte(s) piochée(s) · retour au repos" % expected


func _contact(caster: Unit, _spell: Spell, _report: Dictionary) -> void:
	if busy and caster == hero:
		contact = _facts()


func _process(delta: float) -> void:
	if busy and is_instance_valid(visual):
		var state: Dictionary = visual.sprite_backend.get_runtime_state()
		if releases == 0:
			early_unchanged = (
				early_unchanged and _facts() == before and int(state.get("glyph_count", 0)) == 0
			)
		glyphs_seen = maxi(glyphs_seen, int(state.get("glyph_count", 0)))
		for fx in router.effects:
			if is_instance_valid(fx) and not fx.closed and not fx.persistent:
				duplicate_seen = true
	record_budget += delta
	if record_budget >= 1.0 / 30.0:
		record_budget = fmod(record_budget, 1.0 / 30.0)
		super._process(delta)


func _reject_without_ap() -> void:
	hero.start_turn()
	hero.current_ap = 0
	session.cards.used_families.clear()
	var uid: String = session.cards.add_copy("n08")
	session.cards.active.append(uid)
	session.cards.hand.assign([uid])
	session.cards.selected = uid
	var snapshot := _facts()
	battle._on_request_cast_spell(session.cards.family_spell("n08"), hero.grid_pos)
	await get_tree().create_timer(.25).timeout
	_check(
		_facts() == snapshot and not session.cards.consumed.has(uid),
		"Rejected card changes nothing",
	)
	_check(not visual.sprite_backend.recenter.visible, "Rejected card shows no gesture or glyph")


func _capture(id: String) -> void:
	await super._capture(review_direction + "_" + scenario + "_" + id)
