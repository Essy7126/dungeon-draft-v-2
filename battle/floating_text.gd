# battle/floating_text.gd
# ============================================================
# FLOATING TEXT — Un texte flottant réutilisable (pool).
# Un montant (gros) + une source optionnelle (petit, dessous).
# Monte de RISE_PX et s'estompe en LIFETIME secondes, puis se rend
# au pool via le signal `finished` (jamais de queue_free en rafale).
# ============================================================

extends Node2D

signal finished(instance)

const RISE_PX := 40.0
const LIFETIME := 0.8

@onready var _amount: Label = $Amount
@onready var _source: Label = $Source

var _tween: Tween = null

# Lance l'affichage. `font_size` permet les variantes (crit plus gros).
func play(text: String, color: Color, source_text: String = "", font_size: int = 14) -> void:
	visible = true
	modulate = Color(1, 1, 1, 1)
	_amount.text = text
	_amount.add_theme_color_override("font_color", color)
	_amount.add_theme_font_size_override("font_size", font_size)
	_source.visible = source_text != ""
	_source.text = source_text
	_source.add_theme_color_override("font_color", Color(color.r, color.g, color.b, 0.85))
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var start_y := position.y
	_tween = create_tween()
	_tween.tween_property(self, "position:y", start_y - RISE_PX, LIFETIME)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, LIFETIME)
	_tween.tween_callback(_on_done)

func _on_done() -> void:
	visible = false
	finished.emit(self)
