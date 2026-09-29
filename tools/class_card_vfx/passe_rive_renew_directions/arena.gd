extends "res://tools/class_card_vfx/passe_rive_s30/arena.gd"
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
	return ["i01", "l02"]


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
	current_id = "i01"
	await super._exercise()
	get_window().title = "Passe-Rive — Restauration · huit directions"
	capture_mode = automated
	if automated:
		for direction in DIRECTIONS:
			review_direction = direction
			direction_selector.select(DIRECTIONS.keys().find(direction))
			for id in _review_cases():
				for version in ["base", "upgraded", "full_hp", "guard_cap"]:
					scenario = version
					session.cards.upgraded_ids.erase(id)
					if version == "upgraded":
						session.cards.upgraded_ids.append(id)
					record_card = "i01" if direction == "SE" and id == "i01" and version == "base" else ""
					await _play_current(id)
		await _reject_without_ap()
		_finish()


func _set_review_facing() -> void:
	visual.set_facing(DIRECTIONS[review_direction])
	visual.play_idle()


func _play_current(id: String) -> void:
	await super._play_current(id)
	_check(
		release_state.get("authored_direction") == review_direction,
		"Correct authored facing " + review_direction,
	)
	_check(not release_state.get("mirrored", true), "No mirrored body")
	_check(release_state.get("frame") == (6 if id == "i01" else 4), "Correct long or compact pose")
	casts.back()["facing"] = review_direction


func _capture(id: String) -> void:
	await super._capture(review_direction + "_" + id)
