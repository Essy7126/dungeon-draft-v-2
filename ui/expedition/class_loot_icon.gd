extends Button
const Presentation := preload("res://ui/expedition/class_card_presentation.gd")
var item_title := ""
var item_body := ""
var item_texture: Texture2D
var _rarity := "common"
var _equipped_mark: Label


func configure(
	title: String,
	texture: Texture2D,
	body: String,
	count: int,
	rarity := "common",
	kind := "",
) -> void:
	item_title = title
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	item_body = body
	item_texture = texture
	_rarity = rarity
	custom_minimum_size = Vector2(60, 60)
	icon = texture
	expand_icon = true
	add_theme_constant_override("icon_max_width", 50)
	set_marked(false)
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
	if not kind.is_empty():
		var badge := Label.new()
		badge.name = "LootKindBadge"
		badge.text = kind
		badge.position = Vector2(4, 1)
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_color_override("font_color", Color("fff0c4"))
		badge.add_theme_color_override("font_shadow_color", Color.BLACK)
		badge.add_theme_constant_override("shadow_outline_size", 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(badge)
	_equipped_mark = Label.new()
	_equipped_mark.name = "EquippedCheck"
	_equipped_mark.text = "✓"
	_equipped_mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_equipped_mark.offset_left = -20
	_equipped_mark.add_theme_color_override("font_color", Color("bdebc4"))
	_equipped_mark.add_theme_color_override("font_shadow_color", Color.BLACK)
	_equipped_mark.add_theme_constant_override("shadow_outline_size", 4)
	_equipped_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipped_mark.hide()
	add_child(_equipped_mark)


func set_marked(selected: bool, equipped := false) -> void:
	const CardSkin := preload("res://ui/expedition/catabase_card_skin.gd")
	var accent: Color = {
		"common": Color("b6b6a0"),
		"uncommon": Color("98cfbb"),
		"rare": Color("ddc08a"),
		"epic": Color("c5aced"),
	}.get(_rarity, Color("b6b6a0"))
	CardSkin.icon_button(self, accent)
	if selected:
		add_theme_stylebox_override("normal", CardSkin.surface(Color("f0d699"), true, 5))
	if is_instance_valid(_equipped_mark):
		_equipped_mark.visible = equipped


func _make_custom_tooltip(_text: String) -> Object:
	return Presentation.tooltip(item_title, item_texture, item_body)
