extends RefCounted
## Short names below the existing HUD icons; children never capture pointer input.
const D := preload("res://ui/expedition/player_dossier_skin.gd")
const NAMES := ["Sac", "Deck", "Stats", "Carte"]


static func apply(buttons: Array) -> void:
	for index in buttons.size():
		var button: Button = buttons[index]
		var caption := button.get_node_or_null("CardUtilityCaption") as Label
		if caption == null:
			button.set_meta("card_previous_icon_alignment", button.vertical_icon_alignment)
			caption = Label.new()
			caption.name = "CardUtilityCaption"
			caption.text = NAMES[index]
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			caption.add_theme_font_override("font", D.FONT)
			caption.add_theme_font_size_override("font_size", 11)
			caption.add_theme_color_override("font_color", D.PAPER)
			button.add_child(caption)
			caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			caption.offset_top = -17
			caption.offset_bottom = -2
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP


static func clear(buttons: Array) -> void:
	for button: Button in buttons:
		var caption := button.get_node_or_null("CardUtilityCaption")
		if caption != null:
			button.remove_child(caption)
			caption.queue_free()
			button.vertical_icon_alignment = int(button.get_meta("card_previous_icon_alignment"))
			button.remove_meta("card_previous_icon_alignment")
