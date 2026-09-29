extends "res://tools/class_card_vfx/passe_rive_assignments.gd"
## Production battle, real card consumption and authoritative relocation.
const ProductionBackend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
var variant := "base"
var arrival_seen := false
var invisible_release := false
var no_early_move := true
var no_route_interpolation := true
var from_world := Vector2.ZERO
var to_world := Vector2.ZERO
var blocked_cell := Vector2i(-1, -1)
var previous_terrain: Dictionary = { }
var recording_budget := 0.0
var duplicate_portal := false


func _review_cases() -> Array:
	return ["a05", "r05", "r08"]


func _setup_review_backend() -> void:
	_check(visual.sprite_backend.get_script() == ProductionBackend, "Public S29 production backend")
	visual._sync_cards_mode()


func _exercise() -> void:
	var automated := capture_mode
	capture_mode = false
	current_id = "a05"
	await super._exercise()
	get_window().title = "Passe-Rive — Passage spectral"
	selector.select(0)
	label.text = "PASSAGE SPECTRAL\nPivot → disparition → réapparition\nBond spectral · Au-delà du front · Permutation"
	capture_mode = automated
	if automated:
		for id in _review_cases():
			for version in ["base", "upgraded"]:
				variant = version
				session.cards.upgraded_ids.erase(id)
				if version == "upgraded":
					session.cards.upgraded_ids.append(id)
				record_card = "a05" if id == "a05" and version == "base" else ""
				await _play_current(id)
		await _rejected_cast()
		_finish()


func _prepare_card_fixture(id: String) -> void:
	arrival_seen = false
	invisible_release = false
	no_early_move = true
	no_route_interpolation = true
	duplicate_portal = false
	from_world = battle._unit_views[hero].position
	to_world = battle.grid_cell_to_parent_local(cast_cell, battle._unit_views[hero].get_parent())
	if id != "r08":
		# Both blink cards must cross an actual blocking cell without a route tween.
		blocked_cell = hero.grid_pos + Vector2i.RIGHT
		previous_terrain = battle.grid.get_terrain_properties(blocked_cell).duplicate(true)
		battle.grid.set_terrain_properties(
			blocked_cell,
			{ "walkable": false, "transparent": false },
		)


func _process(delta: float) -> void:
	if busy and is_instance_valid(visual):
		var state: Dictionary = visual.sprite_backend.get_runtime_state()
		if releases == 0:
			no_early_move = (
				no_early_move and hero.grid_pos == original_cell
				and target.grid_pos == original_target
			)
		arrival_seen = arrival_seen or bool(state.get("arrival_confirmed", false))
		var position: Vector2 = battle._unit_views[hero].position
		no_route_interpolation = (
			no_route_interpolation
			and (position.is_equal_approx(from_world) or position.is_equal_approx(to_world))
		)
		if current_id != "r08":
			for fx in router.effects:
				if is_instance_valid(fx) and not fx.closed and fx.recipe.get("effect", "") == "blink":
					duplicate_portal = true
	recording_budget += delta
	if recording_budget >= 1.0 / 30.0:
		recording_budget = fmod(recording_budget, 1.0 / 30.0)
		super._process(delta)


func _release() -> void:
	super._release()
	invisible_release = is_zero_approx(float(release_state.get("spectral_alpha", 1.0)))


func _play_current(id: String) -> void:
	await super._play_current(id)
	_check(no_early_move, id + " neither unit moves before release")
	_check(invisible_release, id + " body absent at relocation marker")
	_check(arrival_seen, id + " actual relocation confirms reappearance")
	_check(no_route_interpolation, id + " no walking through intermediate cells")
	_check(hero.grid_pos == cast_cell, id + " caster reaches requested cell")
	_check(
		target.grid_pos == (original_cell if id == "r08" else original_target),
		id + " correct second occupant",
	)
	_check(not visual.sprite_backend.spectral.visible, id + " spectral layers expire")
	_check(
		visual.sprite_backend.animated_sprite.self_modulate == Color.WHITE,
		id + " native visibility restored",
	)
	_check(not router.arrivals.has(hero), id + " arrival VFX queue drained")
	_check(not duplicate_portal, id + " no duplicate generic portals")
	casts.back().merge(
		{
			"variant": variant,
			"arrival_seen": arrival_seen,
			"invisible_release": invisible_release,
			"no_route_interpolation": no_route_interpolation,
			"hero_from": str(original_cell),
			"hero_to": str(hero.grid_pos),
		}
	)
	if blocked_cell != Vector2i(-1, -1):
		battle.grid.set_terrain_properties(blocked_cell, previous_terrain)
		blocked_cell = Vector2i(-1, -1)


func _rejected_cast() -> void:
	current_id = "a05"
	_check(_position_pair(), "Rejected cast fixture lane")
	hero.start_turn()
	session.cards.used_families.clear()
	var copy_id: String = session.cards.add_copy("a05")
	session.cards.active.append(copy_id)
	session.cards.hand.assign([copy_id])
	session.cards.selected = copy_id
	var spell: Spell = session.cards.family_spell("a05")
	var before_ap := hero.current_ap
	var before_cell := hero.grid_pos
	var before_releases := releases
	_check(
		battle.spell_caster.get_cast_failure_reason(hero, spell, target.grid_pos) != &"",
		"Occupied blink destination rejected",
	)
	battle._on_request_cast_spell(spell, target.grid_pos)
	await get_tree().create_timer(.2).timeout
	_check(
		hero.grid_pos == before_cell and hero.current_ap == before_ap,
		"Rejected blink keeps position and AP",
	)
	_check(not session.cards.consumed.has(copy_id), "Rejected blink consumes no card")
	_check(
		releases == before_releases and not visual.sprite_backend.spectral.visible,
		"Rejected blink creates no departure",
	)


func _capture(id: String) -> void:
	await super._capture(variant + "_" + id)
