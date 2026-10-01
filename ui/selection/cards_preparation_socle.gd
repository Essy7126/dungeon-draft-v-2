extends Control
## Isolated painted props on their stone plinths, matched to the reference.
const SanctuarySkin := preload("res://ui/selection/cards_sanctuary_skin.gd")
const OUTLINE := preload("res://ui/selection/cards_socle_outline.gdshader")
@export_range(0.5, 5.0) var outline_width := 2.0
@export var outline_color := Color("efc66c")
@export_range(0.0, 1.0) var alpha_threshold := 0.35
var kind := "class"
var class_id := "assassin"
var _texture: Texture2D
var _button: BaseButton
var _outline_material: ShaderMaterial
var _hovered := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Use the existing cropped pixels unchanged, with local UVs for alpha sampling.
	_texture = ImageTexture.create_from_image(SanctuarySkin.prop(kind).get_image())
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE
	_outline_material.set_shader_parameter("outline_width", outline_width)
	_outline_material.set_shader_parameter("outline_color", outline_color)
	_outline_material.set_shader_parameter("alpha_threshold", alpha_threshold)
	material = _outline_material
	_button = get_parent() as BaseButton
	_button.mouse_entered.connect(_set_hovered.bind(true))
	_button.mouse_exited.connect(_set_hovered.bind(false))
	_button.focus_entered.connect(_update_highlight)
	_button.focus_exited.connect(_update_highlight)
	_update_highlight()
	resized.connect(queue_redraw)


func _draw() -> void:
	if _texture == null:
		return
	var width: float = { "class": 176, "deck": 216, "elements": 210, "difficulty": 146 }[kind]
	var height := width * _texture.get_height() / _texture.get_width()
	var padding := outline_width + 1.0
	_outline_material.set_shader_parameter("art_size", Vector2(width, height))
	_outline_material.set_shader_parameter("padding", padding)
	draw_texture_rect(
		_texture,
		Rect2((size.x - width) * .5, 149 - height, width, height).grow(padding),
		false,
	)


func _set_hovered(value: bool) -> void:
	_hovered = value
	_update_highlight()


func _update_highlight() -> void:
	_outline_material.set_shader_parameter(
		"highlighted",
		not _button.disabled and (_hovered or _button.has_focus()),
	)
