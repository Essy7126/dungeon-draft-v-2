# battle/vfx/marque_vfx.gd
extends Node2D

const MARK_TEX    := preload("res://asset/vfx/marque_icon.png")
const DISPLAY_PX  := 52.0

func initialiser(pos: Vector2) -> void:
	global_position = pos
	z_index = 10

	var sprite := Sprite2D.new()
	sprite.texture = MARK_TEX
	var tex_w := float(MARK_TEX.get_width())
	var s     := DISPLAY_PX / tex_w
	sprite.scale   = Vector2.ZERO
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(sprite)

	var tw := create_tween()
	tw.tween_property(sprite, "scale",      Vector2(s, s), 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sprite, "modulate:a", 1.0,      0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.28)
	tw.tween_property(sprite, "modulate:a", 0.0,      0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
