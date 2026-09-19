extends Button
const Presentation := preload("res://ui/expedition/class_card_presentation.gd")
var _spell: Spell
var _actor: Unit


func configure(spell: Spell, actor: Unit, subtitle: String) -> void:
	_spell = spell
	_actor = actor
	custom_minimum_size = Vector2(185, 226)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip_text = spell.spell_name
	accessibility_name = preload("res://ui/expedition/catabase_card_text.gd").details(spell, actor)
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(
			state,
			preload("res://ui/expedition/catabase_card_skin.gd").frame(state != "normal"),
		)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	margin.add_child(box)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	box.add_child(top)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Presentation.icon(top, spell.icon, 50)
	var cost := Presentation.label(top, "%d PA" % actor.get_spell_ap_cost(spell), 24)
	cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Presentation.label(box, spell.spell_name, 19)
	Presentation.label(box, Presentation.numbers(spell, actor), 16)
	var effect := Presentation.label(box, Presentation.rule(spell), 16)
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	Presentation.label(box, subtitle, 14).modulate = Color("c6d8cc")


func _make_custom_tooltip(_text: String) -> Object:
	return Presentation.tooltip(
		_spell.spell_name,
		_spell.icon,
		preload("res://ui/expedition/catabase_card_text.gd").details(_spell, _actor),
	)
