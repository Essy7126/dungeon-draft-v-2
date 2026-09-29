extends "res://tools/class_card_vfx/passe_rive_s27/arena.gd"
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
	return ["n02", "g05", "fallback_guard"]


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
	current_id = "n02"
	await super._exercise()
	get_window().title = "Passe-Rive — Parade · trois usages et huit directions"
	capture_mode = automated
	print("PASSE_RIVE_GUARD_DIRECTIONS_READY")
	if automated:
		for direction in DIRECTIONS:
			review_direction = direction
			direction_selector.select(DIRECTIONS.keys().find(direction))
			for id in _review_cases():
				for variant in [false, true]:
					if id == "fallback_guard" and variant:
						continue
					upgraded = variant
					session.cards.upgraded_ids.erase(id)
					if variant:
						session.cards.upgraded_ids.append(id)
					record_card = id if id == "n02" and direction == "SE" and not variant else ""
					await _play_current(id)
					_check(
						release_state.get("authored_direction") == direction,
						id + " correct projected facing " + direction,
					)
					_check(release_state.get("frame") == 5, id + " raised palm at gameplay contact")
					_check(
						not release_state.get("mirrored", true),
						"Authored direction without mirror",
					)
					_check(hero.grid_pos == original_cell, "Caster support stays on original tile")
		_finish()


func _capture(id: String) -> void:
	await super._capture(review_direction + ("_up_" if upgraded else "_base_") + id)


func _prepare_card_fixture(id: String) -> void:
	super._prepare_card_fixture(id)
	visual.set_facing(DIRECTIONS[review_direction])
	visual.play_idle()
