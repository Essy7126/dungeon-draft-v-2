extends Control
## Isolated painted props on their stone plinths, matched to the reference.
const SanctuarySkin := preload("res://ui/selection/cards_sanctuary_skin.gd")
var kind := "class"
var class_id := "assassin"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)


func _draw() -> void:
	var texture := SanctuarySkin.prop(kind)
	var width: float = { "class": 176, "deck": 216, "elements": 210, "difficulty": 146 }[kind]
	var height := width * texture.get_height() / texture.get_width()
	draw_texture_rect(texture, Rect2((size.x - width) * .5, 149 - height, width, height), false)
