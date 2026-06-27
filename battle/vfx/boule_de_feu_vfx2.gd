@tool
extends Node2D

@export var speed: float = 600.0

const TRAIL_POINTS := 16
const TRAIL_LENGTH := 34.0

var _target: Vector2 = Vector2.ZERO
var _flying: bool    = false

@onready var _explosion : GPUParticles2D = $Explosion
@onready var _head      : ColorRect      = $FireballHead
@onready var _tail      : Line2D         = $TailLine

# ── FireTrail ────────────────────────────────────────────────────────────────
@export_group("FireTrail")
@export var ft1_velocity_min: float = 8.0:
	set(v): ft1_velocity_min = v; _apply("FireTrail", "initial_velocity_min", v)
@export var ft1_velocity_max: float = 25.0:
	set(v): ft1_velocity_max = v; _apply("FireTrail", "initial_velocity_max", v)
@export var ft1_damping_min: float = 30.0:
	set(v): ft1_damping_min = v; _apply("FireTrail", "damping_min", v)
@export var ft1_damping_max: float = 60.0:
	set(v): ft1_damping_max = v; _apply("FireTrail", "damping_max", v)
@export var ft1_scale_min: float = 0.5:
	set(v): ft1_scale_min = v; _apply("FireTrail", "scale_min", v)
@export var ft1_scale_max: float = 0.75:
	set(v): ft1_scale_max = v; _apply("FireTrail", "scale_max", v)
@export var ft1_spread: float = 3.0:
	set(v): ft1_spread = v; _apply("FireTrail", "spread", v)

# ── FireTrail2 ───────────────────────────────────────────────────────────────
@export_group("FireTrail2")
@export var ft2_velocity_min: float = 6.0:
	set(v): ft2_velocity_min = v; _apply("FireTrail2", "initial_velocity_min", v)
@export var ft2_velocity_max: float = 18.0:
	set(v): ft2_velocity_max = v; _apply("FireTrail2", "initial_velocity_max", v)
@export var ft2_damping_min: float = 28.0:
	set(v): ft2_damping_min = v; _apply("FireTrail2", "damping_min", v)
@export var ft2_damping_max: float = 55.0:
	set(v): ft2_damping_max = v; _apply("FireTrail2", "damping_max", v)
@export var ft2_scale_min: float = 0.36:
	set(v): ft2_scale_min = v; _apply("FireTrail2", "scale_min", v)
@export var ft2_scale_max: float = 0.58:
	set(v): ft2_scale_max = v; _apply("FireTrail2", "scale_max", v)
@export var ft2_spread: float = 4.0:
	set(v): ft2_spread = v; _apply("FireTrail2", "spread", v)

# ── FireTrail3 ───────────────────────────────────────────────────────────────
@export_group("FireTrail3")
@export var ft3_velocity_min: float = 4.0:
	set(v): ft3_velocity_min = v; _apply("FireTrail3", "initial_velocity_min", v)
@export var ft3_velocity_max: float = 12.0:
	set(v): ft3_velocity_max = v; _apply("FireTrail3", "initial_velocity_max", v)
@export var ft3_damping_min: float = 22.0:
	set(v): ft3_damping_min = v; _apply("FireTrail3", "damping_min", v)
@export var ft3_damping_max: float = 45.0:
	set(v): ft3_damping_max = v; _apply("FireTrail3", "damping_max", v)
@export var ft3_scale_min: float = 0.22:
	set(v): ft3_scale_min = v; _apply("FireTrail3", "scale_min", v)
@export var ft3_scale_max: float = 0.4:
	set(v): ft3_scale_max = v; _apply("FireTrail3", "scale_max", v)
@export var ft3_spread: float = 5.0:
	set(v): ft3_spread = v; _apply("FireTrail3", "spread", v)

# ── SmokeTrail ───────────────────────────────────────────────────────────────
@export_group("SmokeTrail")
@export var smoke_velocity_min: float = 5.0:
	set(v): smoke_velocity_min = v; _apply("SmokeTrail", "initial_velocity_min", v)
@export var smoke_velocity_max: float = 14.0:
	set(v): smoke_velocity_max = v; _apply("SmokeTrail", "initial_velocity_max", v)
@export var smoke_damping_min: float = 10.0:
	set(v): smoke_damping_min = v; _apply("SmokeTrail", "damping_min", v)
@export var smoke_damping_max: float = 22.0:
	set(v): smoke_damping_max = v; _apply("SmokeTrail", "damping_max", v)
@export var smoke_scale_min: float = 0.38:
	set(v): smoke_scale_min = v; _apply("SmokeTrail", "scale_min", v)
@export var smoke_scale_max: float = 0.7:
	set(v): smoke_scale_max = v; _apply("SmokeTrail", "scale_max", v)

# ─────────────────────────────────────────────────────────────────────────────

func _apply(node_name: String, property: String, value: float) -> void:
	if not is_node_ready():
		return
	var node := get_node_or_null(node_name)
	if node and node.process_material:
		node.process_material.set(property, value)

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

	_tail.clear_points()
	for i in range(TRAIL_POINTS):
		var t := float(i) / float(TRAIL_POINTS - 1)
		_tail.add_point(Vector2(-TRAIL_LENGTH * t, 0.0))

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _flying:
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
