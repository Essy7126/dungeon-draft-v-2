extends "res://tools/class_card_vfx/passe_rive_s24/arena.gd"
## Real cc2 SpellCaster requests on the authored Battle, with a seeded review hand.
const CurrentState := preload("res://core/expedition/consumable_cards_state.gd")
const CurrentSpells := preload("res://core/expedition/consumable_card_spells.gd")
const CurrentTurns := preload("res://core/expedition/consumable_card_turns.gd")
const Bindings := preload("res://characters/achilles/2d/passe_rive_card_bindings.gd")
const GestureCatalog := preload("res://characters/achilles/2d/passe_rive_s19_catalog.gd")
const CASES := [
	"n05",
	"r01",
	"r02",
	"r04",
	"r06",
	"r09",
	"a07",
	"t01",
	"t02",
	"t04",
	"n04",
	"n02",
	"n03",
	"r05",
	"g04",
]
var selector: OptionButton
var current_id := "n05"
var cast_cell := Vector2i.ZERO
var record_card := "n04"


func _exercise() -> void:
	var auto_capture := capture_mode
	capture_mode = false
	session.cards = CurrentState.new()
	session.cards.bind(session)
	session.cards.initialize_deck(CurrentSpells.Catalog.preset("arpenteur"))
	CurrentTurns.bind_hero(hero, session.cards)
	session.cards.start_turn()
	await super._exercise()
	get_window().title = "Passe-Rive — Cartes et animations · attribution corrigée"
	capture_mode = auto_capture
	if capture_mode:
		for id in _review_cases():
			await _play_current(id)
		_finish()


func _review_cases() -> Array:
	return CASES


func _prepare_card_fixture(_id: String) -> void:
	pass


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	canvas.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	label = Label.new()
	label.text = "PASSE-RIVE · CARTES ACTUELLES\nChoisis une carte puis joue son animation."
	label.custom_minimum_size = Vector2(340, 100)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	selector = OptionButton.new()
	for id in _review_cases():
		selector.add_item(str(CurrentSpells.definition(id).name))
	box.add_child(selector)
	play_button = Button.new()
	play_button.text = "Jouer la carte"
	play_button.custom_minimum_size.y = 44
	play_button.pressed.connect(
		func():
			_play_current(_review_cases()[selector.selected]),
	)
	box.add_child(play_button)
	var speed := Button.new()
	speed.text = "Vitesse ×1 / ×0,5"
	speed.pressed.connect(
		func():
			Engine.time_scale = .5 if Engine.time_scale == 1.0 else 1.0,
	)
	box.add_child(speed)
	var note := Label.new()
	note.text = "Scène d’essai · vraie carte cc2\nMain et cibles réinitialisées entre essais."
	box.add_child(note)


func _position_pair() -> bool:
	var row := CurrentSpells.definition(current_id)
	var distance := maxi(1, int(row.min))
	if row.op == "pull":
		distance = int(row.max)
	if row.op in ["move", "blink"]:
		distance = int(row.max) + 1
	for cell in _central_cells():
		var valid := true
		for offset in range(distance + 2):
			var at: Vector2i = cell + Vector2i.RIGHT * offset
			valid = (
				valid and battle.grid.is_walkable(at)
				and (not battle.grid.has_unit(at) or at in [hero.grid_pos, target.grid_pos])
			)
		if valid and cell != target.grid_pos and cell + Vector2i.RIGHT * distance != hero.grid_pos:
			_move(hero, cell)
			_move(target, cell + Vector2i.RIGHT * distance)
			for unit in [hero, target]:
				battle._unit_views[unit].synchronize_external_movement()
			cast_cell = hero.grid_pos if int(row.max) == 0 else target.grid_pos
			if row.op in ["move", "blink"]:
				cast_cell = hero.grid_pos + Vector2i.RIGHT * mini(2, int(row.max))
			battle.camera.global_position = (
				battle._unit_views[hero].global_position
				+ battle._unit_views[target].global_position
			) * .5 + Vector2(0, -40)
			return true
	return false


func _play_current(id: String) -> void:
	if busy:
		return
	busy = true
	play_button.disabled = true
	selector.disabled = true
	current_id = id
	selector.select(_review_cases().find(id))
	# Isolate each visual comparison from the previous card's persistent facts.
	for cell in battle.terrain_effects.active_surface_cells():
		battle.terrain_effects.clear_effect(cell)
	CurrentTurns.Terrain.prune(battle.terrain_effects, session.cards)
	for unit: Unit in battle.units:
		CurrentTurns.Effects.states(unit).clear()
		for status in unit.get_active_statuses().duplicate():
			unit.remove_status(status.data.get_effective_status_id())
		unit.clear_shield()
	router.clear()
	router.bind_terrain(battle.terrain_effects)
	_check(_position_pair(), id + " legal review lane")
	original_cell = hero.grid_pos
	original_target = target.grid_pos
	visual.set_facing(Vector2i.RIGHT)
	visual.play_idle()
	var cards = session.cards
	# Each review click is a new activation, including repeated copies of one family.
	hero.start_turn()
	cards.used_families.clear()
	cards.pending_choice.clear()
	for unit: Unit in battle.units:
		unit.current_hp = unit.max_hp.get_int()
		unit.esquive.base_value = 0
	hero.current_ap = hero.max_ap.get_int()
	var before_ap := hero.current_ap
	var spell: Spell = cards.family_spell(id)
	var fallback: bool = cards.is_weapon_spell(spell)
	var copy_id := ""
	if not fallback:
		copy_id = cards.add_copy(id)
		cards.active.append(copy_id)
		cards.hand.assign([copy_id])
	cards.selected = copy_id
	var copies_before: Array = cards.copies.duplicate(true)
	var hand_before: Array = cards.hand.duplicate()
	_prepare_card_fixture(id)
	var failure: StringName = battle.spell_caster.get_cast_failure_reason(hero, spell, cast_cell)
	_check(failure == &"", id + " real preparation: " + str(failure))
	if failure != &"":
		label.text = spell.spell_name + " · " + str(failure)
		busy = false
		play_button.disabled = false
		selector.disabled = false
		return
	var row := CurrentSpells.definition(id, id in cards.upgraded_ids)
	var binding := Bindings.resolve(str(spell.spell_id))
	label.text = spell.spell_name + "\n" + binding.reason
	release_state = { }
	last_report = { }
	releases = 0
	hp_before = target.current_hp
	no_early_effect = true
	recording = capture_mode and id == record_card
	await _capture(id + "_before")
	if recording:
		await get_tree().create_timer(.25).timeout
	battle._on_request_cast_spell(spell, cast_cell)
	var deadline := Time.get_ticks_msec() + 12000
	var contact_saved := false
	while battle._spell_resolution_pending and Time.get_ticks_msec() < deadline:
		if releases == 0:
			no_early_effect = no_early_effect and target.current_hp == hp_before
			if id == "g04":
				no_early_effect = no_early_effect and target.grid_pos == original_target
		if not contact_saved and releases > 0:
			contact_saved = true
			await _capture(id + "_release")
		await get_tree().process_frame
	await get_tree().create_timer(.4).timeout
	recording = false
	var expected := "idle_SE"
	if binding.reference == "kick":
		expected = KickBackend.KICK
	elif binding.reference == "pull":
		expected = KickBackend.PullBody.CLIP
	elif binding.reference == "incantation":
		expected = KickBackend.IncantationBody.CLIP
	elif binding.reference == "drain":
		expected = KickBackend.DrainBody.CLIP
	elif binding.reference == "guard":
		expected = KickBackend.GuardBody.CLIP
	elif binding.reference == "renew":
		expected = KickBackend.RenewBody.CLIP
	elif binding.reference == "blink":
		expected = KickBackend.SpectralBody.CLIP
	elif binding.reference == "dash":
		expected = "dash_SE"
	elif GestureCatalog.Data.CARDS.has(binding.reference):
		expected = GestureCatalog.Data.CARDS[binding.reference].clip
	_check(not battle._spell_resolution_pending, id + " battle unlocked")
	_check(no_early_effect, id + " no early damage")
	_check(releases == 1, id + " one release")
	_check(release_state.get("animation") == expected, id + " actual cast uses " + expected)
	_check(
		not last_report.is_empty() and not last_report.get("failed", false),
		id + " actual card resolves",
	)
	if fallback:
		_check(
			cards.copies == copies_before and cards.hand == hand_before,
			id + " fallback consumes no copy",
		)
		_check(id in cards.used_families, id + " fallback used once this activation")
	else:
		_check(cards.consumed.has(copy_id), id + " actual copy consumed")
	_check(hero.current_ap == before_ap - int(row.ap), id + " actual card cost")
	_check(
		str(visual.sprite_backend.get_runtime_state().animation).begins_with("idle_"),
		id + " native recovery",
	)
	_check(router.accepts(hero, spell), id + " current VFX recipe selected")
	if id == "g04":
		_check(hero.grid_pos == original_cell, "Pull caster remains planted")
		_check(
			target.grid_pos == original_target - CurrentTurns.Effects.axis(original_cell, original_target) * int(row.amount),
			"Real pull distance matches base/upgrade",
		)
		_check(
			not is_instance_valid(visual.pull_tether) or visual.pull_tether.closed,
			"Tether cleans up after recovery",
		)
	casts.append(
		{
			"id": str(spell.spell_id),
			"name": row.name,
			"expected_clip": expected,
			"release": release_state,
			"copy_consumed": cards.consumed.has(copy_id),
			"fallback": fallback,
			"ap_spent": before_ap - hero.current_ap,
			"upgraded": id in cards.upgraded_ids,
			"target_from": str(original_target),
			"target_to": str(target.grid_pos),
		}
	)
	await _capture(id + "_recovery")
	label.text += "\nRetour au repos · " + (
		"garde de secours utilisée" if fallback else "carte consommée"
	)
	busy = false
	play_button.disabled = false
	selector.disabled = false


func _contact(_caster: Unit, _spell: Spell, _report: Dictionary) -> void:
	pass # Production now owns all confirmed impacts, including the heel.
