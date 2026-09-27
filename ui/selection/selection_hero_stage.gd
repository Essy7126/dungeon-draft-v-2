extends Control
## Painted stage under the animated hero; no input interception.
var _texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_texture = load("res://assets/catabase/selection/hero_pedestal_v1.png")
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.y < 60.0 or _texture == null:
		return
	var width := minf(size.x * 0.8, 390.0)
	var height := width / 3.0
	draw_texture_rect(
		_texture,
		Rect2((size.x - width) * 0.5, size.y - height, width, height),
		false,
	)
