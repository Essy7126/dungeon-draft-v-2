extends ColorRect

func _ready() -> void:
	var vp = get_viewport_rect()
	position = Vector2.ZERO
	size = vp.size
