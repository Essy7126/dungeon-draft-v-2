extends "res://tools/class_card_vfx/passe_rive_s29/arena.gd"
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
var review_direction := "SE"
var upgraded := false
var direction_selector: OptionButton


func _review_cases() -> Array:
	return ["a05", "r05", "r08"]


func _setup_review_backend() -> void:
	_check(visual.sprite_backend.get_script() == Production, "Public production backend")
	visual._sync_cards_mode()


func _build_ui() -> void:
	super._build_ui()
	direction_selector = OptionButton.new()
	for facing in DIRECTIONS:
		direction_selector.add_item(facing)
	direction_selector.item_selected.connect(
		func(index):
			review_direction = DIRECTIONS.keys()[index],
	)
	play_button.get_parent().add_child(direction_selector)


func _exercise() -> void:
	var automated := capture_mode
	capture_mode = false
	current_id = "a05"
	await super._exercise()
	get_window().title = "Passe-Rive — Passage spectral · huit directions"
	capture_mode = automated
	if automated:
		for direction in DIRECTIONS:
			review_direction = direction
			direction_selector.select(DIRECTIONS.keys().find(direction))
			for id in _review_cases():
				for version in ["base", "upgraded"]:
					variant = version
					session.cards.upgraded_ids.erase(id)
					if version == "upgraded":
						session.cards.upgraded_ids.append(id)
					record_card = "a05" if direction == "SE" and id == "a05" and version == "base" else ""
					await _play_current(id)
		review_direction = "SE"
		await _rejected_cast()
		_finish()


func _play_current(id: String) -> void:
	await super._play_current(id)
	_check(
		release_state.get("authored_direction") == review_direction,
		"Correct authored facing " + review_direction,
	)
	_check(not release_state.get("mirrored", true), "No mirrored body")
	casts.back()["facing"] = review_direction


func _position_pair() -> bool:
	var delta: Vector2i = DIRECTIONS[review_direction]
	var diagonal := delta.x != 0 and delta.y != 0
	var steps := 1 if diagonal else 2
	for cell in _central_cells():
		var landing: Vector2i = cell + delta * steps
		var foe: Vector2i = landing if current_id == "r08" else cell + delta * (steps + 1)
		var crossing: Vector2i = cell + Vector2i(delta.x, 0) if diagonal else cell + delta
		var valid := true
		for at: Vector2i in [cell, landing, foe, crossing]:
			valid = (
				valid and battle.grid.is_walkable(at)
				and (not battle.grid.has_unit(at) or at in [hero.grid_pos, target.grid_pos])
			)
		if valid and cell != target.grid_pos and foe != hero.grid_pos:
			_move(hero, cell)
			_move(target, foe)
			for unit in [hero, target]:
				battle._unit_views[unit].synchronize_external_movement()
			cast_cell = landing
			battle.camera.global_position = (
				battle._unit_views[hero].global_position
				+ battle.grid_cell_to_parent_local(landing, battle._unit_views[hero].get_parent())
			) * .5 + Vector2(0, -40)
			return true
	return false


func _prepare_card_fixture(id: String) -> void:
	arrival_seen = false
	invisible_release = false
	no_early_move = true
	no_route_interpolation = true
	duplicate_portal = false
	from_world = battle._unit_views[hero].position
	to_world = battle.grid_cell_to_parent_local(cast_cell, battle._unit_views[hero].get_parent())
	if id != "r08":
		var delta: Vector2i = DIRECTIONS[review_direction]
		blocked_cell = hero.grid_pos + (
			Vector2i(delta.x, 0) if delta.x != 0 and delta.y != 0 else delta
		)
		previous_terrain = battle.grid.get_terrain_properties(blocked_cell).duplicate(true)
		battle.grid.set_terrain_properties(
			blocked_cell,
			{ "walkable": false, "transparent": false },
		)
	visual.set_facing(DIRECTIONS[review_direction])
	visual.play_idle()


func _capture(id: String) -> void:
	await super._capture(review_direction + "_" + id)
