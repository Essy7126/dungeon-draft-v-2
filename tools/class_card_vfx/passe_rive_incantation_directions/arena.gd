extends "res://tools/class_card_vfx/passe_rive_s26/arena.gd"
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
var review_only := ""


func _review_cases() -> Array:
	return ["g01", "g08", "a09", "t03", "t06", "t09"]


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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--incantation-card="):
			review_only = arg.trim_prefix("--incantation-card=")
	var automated := capture_mode
	capture_mode = false
	current_id = "t03"
	await super._exercise()
	get_window().title = "Passe-Rive â€” Ramener au front Â· huit lancers rÃ©els"
	capture_mode = automated
	print("PASSE_RIVE_INCANTATION_DIRECTIONS_READY")
	if automated:
		for direction in DIRECTIONS:
			review_direction = direction
			direction_selector.select(DIRECTIONS.keys().find(direction))
			for id in _review_cases():
				if not review_only.is_empty() and id != review_only:
					continue
				for variant in [false, true]:
					upgraded = variant
					session.cards.upgraded_ids.erase(id)
					if variant:
						session.cards.upgraded_ids.append(id)
					record_card = id if id == "t03" and direction == "SE" and not variant else ""
					await _play_current(id)
					_check(
						release_state.get("authored_direction") == direction,
						id + " correct projected facing " + direction,
					)
					_check(release_state.get("frame") == 6, id + " open palms at gameplay contact")
					_check(
						not release_state.get("mirrored", true),
						"Authored direction without mirror",
					)
					_check(hero.grid_pos == original_cell, "Caster support stays on original tile")
		_finish()


func _position_pair() -> bool:
	var delta: Vector2i = DIRECTIONS[review_direction]
	var row := CurrentSpells.definition(current_id)
	var distance := maxi(1, int(row.min))
	if delta.x != 0 and delta.y != 0:
		distance = maxi(1, ceili(float(row.min) / 2.0))
	for cell in _central_cells():
		var target_cell: Vector2i = cell + delta * distance
		var valid: bool = battle.grid.is_walkable(cell) and battle.grid.is_walkable(target_cell)
		for at: Vector2i in [cell, target_cell]:
			valid = valid and (not battle.grid.has_unit(at) or at
					in [hero.grid_pos, target.grid_pos])
		if valid and cell != target.grid_pos and target_cell != hero.grid_pos:
			_move(hero, cell)
			_move(target, target_cell)
			for unit in [hero, target]:
				battle._unit_views[unit].synchronize_external_movement()
			cast_cell = hero.grid_pos if int(row.max) == 0 else target.grid_pos
			battle.camera.global_position = (
				battle._unit_views[hero].global_position
				+ battle._unit_views[target].global_position
			) * .5 + Vector2(0, -40)
			return true
	return false


func _capture(id: String) -> void:
	await super._capture(review_direction + ("_up_" if upgraded else "_base_") + id)


func _prepare_card_fixture(id: String) -> void:
	super._prepare_card_fixture(id)
	visual.set_facing(DIRECTIONS[review_direction])
	visual.play_idle()


func _play_current(id: String) -> void:
	await super._play_current(id)
	if id == "a09":
		var states := CurrentTurns.Effects.states(target)
		_check(states.has("stasis"), "Real stasis applied to the target")
		_check(states.has("stasis_ward"), "Real protection against repeated stasis applied")
