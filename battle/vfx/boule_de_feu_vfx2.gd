extends Node2D

@export var speed: float = 600.0

const TRAIL_POINTS  := 16
const TRAIL_LENGTH  := 34.0

var _target: Vector2 = Vector2.ZERO
var _flying: bool    = false

@onready var _explosion : GPUParticles2D = $Explosion
@onready var _head      : ColorRect      = $FireballHead
@onready var _tail      : Line2D         = $TailLine

func initialiser(depuis: Vector2, vers: Vector2) -> void:
	global_position = depuis
	_target         = vers
	_flying         = true
	rotation        = (vers - depuis).angle()
	var dir         := (vers - depuis).normalized()

	for node_name in ["SmokeTrail", "FireTrail", "FireTrail2", "FireTrail3"]:
		var child := get_node_or_null(node_name)
		if child and child.process_material:
			child.process_material = child.process_material.duplicate()
			child.process_material.direction = Vector3(-dir.x, -dir.y, 0.0)

	# Points fixes en espace local : queue derrière la tête le long de -X
	_tail.clear_points()
	for i in range(TRAIL_POINTS):
		var t := float(i) / float(TRAIL_POINTS - 1)
		_tail.add_point(Vector2(-TRAIL_LENGTH * t, 0.0))

func _process(delta: float) -> void:
	if not _flying:
		return
	var dir := _target - global_position
	if dir.length() < 8.0:
		_arriver()
		return
	global_position += dir.normalized() * speed * delta

func _arriver() -> void:
	_flying = false
	set_process(false)
	_head.visible = false
	_tail.visible = false
	for child in get_children():
		if child is GPUParticles2D and child != _explosion:
			child.emitting = false
	_explosion.emitting = true

func _on_explosion_finished() -> void:
	queue_free()
