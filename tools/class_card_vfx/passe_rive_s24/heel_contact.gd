extends Node2D
## Small physical contact accent for the animatic. No gameplay or displacement.
var elapsed := 0.0


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= .16:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var alpha := 1.0 - elapsed / .16
	var length := 3.0 + elapsed * 25.0
	for angle in [-.8, .2, 1.2]:
		var ray := Vector2.RIGHT.rotated(angle)
		draw_line(ray * 2, ray * (2 + length), Color(.94, .85, .64, alpha), 1.1, true)
