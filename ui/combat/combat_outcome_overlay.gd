class_name CombatOutcomeOverlay
extends CanvasLayer

## Feedback local entre le dernier impact et le flow post-combat persistant.
## Il n'orchestre aucune récompense et ne remplace pas PostCombatScreen.

const PREMIUM_UI := preload("res://ui/theme/premium_ui.gd")
const PREMIUM_ORNAMENT := preload("res://ui/theme/premium_panel_ornament.gd")
const VICTORY_LAUREL := preload(
	"res://asset/ui/recraft_hud_v1/frames/achilles_v1/victory_laurel.svg"
)

var _root: Control
var _backdrop: ColorRect
var _panel: PanelContainer
var _crest: TextureRect
var _title: Label
var _subtitle: Label
var _accent: ColorRect
var _victory := false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func present(victory: bool, reduced_motion: bool = false) -> void:
	_victory = victory
	var accent_color := (
		Color(1.0, 0.72, 0.22)
		if victory
		else Color(0.92, 0.30, 0.24)
	)
	_title.text = "VICTOIRE" if victory else "DÉFAITE"
	_subtitle.text = (
		"Le dernier ennemi est tombé"
		if victory
		else "Votre groupe ne peut plus combattre"
	)
	_title.add_theme_color_override("font_color", accent_color)
	_accent.color = accent_color
	_crest.modulate = accent_color if victory else Color(0.48, 0.26, 0.21, 1.0)
	_root.show()
	_root.modulate.a = 1.0 if reduced_motion else 0.0
	_panel.scale = Vector2.ONE if reduced_motion else Vector2(0.96, 0.96)
	_panel.pivot_offset = _panel.size * 0.5
	_title.scale = Vector2.ONE if reduced_motion else Vector2(0.88, 0.88)
	_title.pivot_offset = _title.size * 0.5
	_accent.scale.x = 1.0 if reduced_motion else 0.0
	if reduced_motion:
		return
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_root, "modulate:a", 1.0, 0.22)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.30)
	tween.tween_property(_title, "scale", Vector2.ONE, 0.32)
	tween.tween_property(_accent, "scale:x", 1.0, 0.38)


func hide_overlay() -> void:
	if is_instance_valid(_root):
		_root.hide()


func get_snapshot() -> Dictionary:
	return {
		"visible": is_instance_valid(_root) and _root.visible,
		"victory": _victory,
		"title": _title.text if is_instance_valid(_title) else "",
		"subtitle": _subtitle.text if is_instance_valid(_subtitle) else "",
	}


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	PREMIUM_UI.apply(_root)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.008, 0.012, 0.018, 0.76)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(700.0, 276.0)
	_panel.theme_type_variation = &"PremiumHeader"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_panel)

	var ornament := PREMIUM_ORNAMENT.new() as PremiumPanelOrnament
	ornament.variant = "header"
	ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(ornament)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_bottom", 28)
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(588.0, 220.0)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "COMBAT ACHEVÉ"
	eyebrow.theme_type_variation = &"PremiumEyebrow"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(eyebrow)

	_crest = TextureRect.new()
	_crest.custom_minimum_size = Vector2(160.0, 42.0)
	_crest.texture = VICTORY_LAUREL
	_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_crest)

	_accent = ColorRect.new()
	_accent.custom_minimum_size = Vector2(320.0, 3.0)
	_accent.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_accent.pivot_offset = Vector2(160.0, 1.5)
	_accent.scale.x = 0.0
	_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_accent)

	_title = Label.new()
	_title.theme_type_variation = &"PremiumDisplay"
	_title.add_theme_font_size_override("font_size", 62)
	_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	_title.add_theme_constant_override("outline_size", 8)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_title)

	_subtitle = Label.new()
	_subtitle.theme_type_variation = &"PremiumSubtitle"
	_subtitle.add_theme_font_size_override("font_size", 17)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_subtitle)
	_root.hide()
