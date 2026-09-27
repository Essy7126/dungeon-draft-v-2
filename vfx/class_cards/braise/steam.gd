extends Node2D
## Quiet held vapour, retired by the real surface's clear/replace event.
const Art := preload("player.gd")
var family := "move"
var motif := "braise_steam"
var remaining := 1
var closed := false
var elapsed := 0.0
var manual := false
var releasing := false
var sprite: Sprite2D
var width := 128.0


func configure(
	_family: String,
	polygon: PackedVector2Array,
	turns: int,
	_seed: float,
	_motif: String,
) -> void:
	remaining = turns
	var center := Vector2.ZERO
	for vertex in polygon:
		center += vertex
	global_position = center / maxf(1, polygon.size())
	width = polygon[0].distance_to(polygon[2]) if polygon.size() == 4 else 128.0
	sprite = Sprite2D.new()
	sprite.texture = load(Art.ART + "steam.png")
	var asset: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		Art.ART + "provenance.json"
	)).assets.steam
	sprite.hframes = int(asset.columns)
	sprite.vframes = int(asset.rows)
	sprite.offset = Vector2.ONE * float(asset.size) * .5 - Vector2(asset.pivot[0], asset.pivot[1])
	sprite.scale = Vector2.ONE * width * 1.2 / float(asset.size)
	add_child(sprite)
	sample(0)


func sample(time: float) -> void:
	elapsed = maxf(time, 0)
	sprite.frame = 9 if releasing else mini(9, int(elapsed * 30))
	sprite.modulate.a = .72 * (1.0 - clampf(elapsed / .22, 0, 1) if releasing else 1.0)


func _process(delta: float) -> void:
	if closed or manual:
		return
	sample(elapsed + delta)
	if releasing and elapsed >= .22:
		cancel()


func release() -> void:
	if not releasing:
		releasing = true
		elapsed = 0


func cancel() -> void:
	closed = true
	hide()
	queue_free()
