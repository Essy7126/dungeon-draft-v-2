extends Node2D
## Compact confirmed heel impact. All displacement is owned by Battle.
var recipe: Dictionary = { }
var closed := false
var persistent := false
var elapsed := 0.0
var origin := Vector2.ZERO
var point := Vector2.ZERO


func configure(
	entry: Dictionary,
	at: Vector2,
	width: float,
	_anchor: Node2D = null,
	_hold := false,
) -> void:
	recipe = entry.duplicate(true)
	point = at
	global_position = at
	scale = Vector2.ONE * width / 60.0
	z_index = 4


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= .16:
		cancel()
	else:
		queue_redraw()


func _draw() -> void:
	var alpha := 1.0 - elapsed / .16
	for angle in [-.8, .2, 1.2]:
		var ray := Vector2.RIGHT.rotated(angle)
		draw_line(ray * 2, ray * (5 + elapsed * 25), Color(.94, .85, .64, alpha), 1.1, true)


func cancel() -> void:
	closed = true
	hide()
	queue_free()
