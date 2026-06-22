extends CanvasLayer

signal fondu_termine

@onready var _rect: ColorRect = $ColorRect

func _ready() -> void:
	_rect.modulate.a = 1.0


func apparaitre(duree: float = 0.5) -> void:
	_rect.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_rect, "modulate:a", 0.0, duree)
	await tween.finished
	emit_signal("fondu_termine")


func disparaitre(duree: float = 0.5) -> void:
	_rect.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_rect, "modulate:a", 1.0, duree)
	await tween.finished
	emit_signal("fondu_termine")
