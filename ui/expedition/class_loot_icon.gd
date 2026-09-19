extends Button
const Presentation := preload("res://ui/expedition/class_card_presentation.gd")
var item_title := ""
var item_body := ""
var item_texture: Texture2D


func configure(title: String, texture: Texture2D, body: String, count: int) -> void:
	item_title = title
	item_body = body
	item_texture = texture
	custom_minimum_size = Vector2(60, 60)
	icon = texture
	expand_icon = true
	add_theme_constant_override("icon_max_width", 46)
	preload("res://ui/expedition/catabase_card_skin.gd").action(self)
	tooltip_text = title
	accessibility_name = "%s, quantité %d. %s" % [title, count, body]
	var quantity := Label.new()
	add_child(quantity)
	quantity.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	quantity.offset_left = -26
	quantity.offset_top = -24
	quantity.text = "×%d" % count
	quantity.add_theme_color_override("font_color", Color("ffe2a0"))
	quantity.add_theme_color_override("font_shadow_color", Color.BLACK)
	quantity.add_theme_constant_override("shadow_outline_size", 4)
	quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _make_custom_tooltip(_text: String) -> Object:
	return Presentation.tooltip(item_title, item_texture, item_body)
