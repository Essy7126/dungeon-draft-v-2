class_name SkeletonRangedProjectileVFX
extends Node2D

signal finished

@export_range(0.05, 2.0, 0.01) var travel_duration := 0.22
@export_range(0.1, 5.0, 0.05) var watchdog_seconds := 1.0
@export var projectile_color := Color(0.88, 0.84, 0.70, 1.0)

var _finished := false


func _ready() -> void:
	add_to_group("skeleton_ranged_projectiles")
	_watchdog()


## Interface attendue par VFXManager. Ce noeud est strictement visuel : il ne
## connait ni Unit, ni SpellCaster et n'emet aucun evenement de gameplay.
func initialiser(start_global: Vector2, target_global: Vector2) -> void:
	global_position = start_global
	rotation = (target_global - start_global).angle()
	queue_redraw()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "global_position", target_global, travel_duration)
	await tween.finished
	_finish()


func _draw() -> void:
	draw_line(Vector2(-9.0, 0.0), Vector2(9.0, 0.0), projectile_color, 2.0, true)
	draw_circle(Vector2(8.0, 0.0), 2.2, projectile_color)


func _watchdog() -> void:
	await get_tree().create_timer(watchdog_seconds).timeout
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	finished.emit()
	queue_free()
