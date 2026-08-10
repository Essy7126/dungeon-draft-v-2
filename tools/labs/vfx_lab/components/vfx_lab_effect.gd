class_name VFXLabEffect
extends Node2D

## Base de cycle de vie commune aux prototypes du VFX Lab.
## Elle ne connait aucune regle de combat : toutes les positions et intensites
## sont fournies par l'appelant sous forme de parametres purement visuels.

signal effect_finished(effect: VFXLabEffect)

@export_range(0.1, 10.0, 0.05) var duration := 2.5
@export_range(0.1, 3.0, 0.05) var intensity := 1.0
@export var default_seed := 1337

var elapsed := 0.0
var playback_speed := 1.0
var active := false
var visual_seed := 1337

var _rng := RandomNumberGenerator.new()
var _visual_root: Node2D = null


func _ready() -> void:
	set_process(false)
	_ensure_visual_root()


func play(parameters: Dictionary = {}) -> void:
	stop_and_clear()
	_ensure_visual_root()
	visual_seed = int(parameters.get("seed", default_seed))
	playback_speed = maxf(0.01, float(parameters.get("playback_speed", 1.0)))
	intensity = maxf(0.05, float(parameters.get("intensity", intensity)))
	_rng.seed = visual_seed
	elapsed = 0.0
	active = true
	_build_effect(parameters)
	set_process(true)
	queue_redraw()


func stop_and_clear() -> void:
	if active:
		_before_clear()
	active = false
	set_process(false)
	if is_instance_valid(_visual_root):
		for child in _visual_root.get_children():
			child.free()
	_clear_effect_state()
	elapsed = 0.0
	queue_redraw()


func advance_simulation(delta_seconds: float) -> void:
	if not active:
		return
	var scaled_delta := maxf(0.0, delta_seconds) * playback_speed
	elapsed += scaled_delta
	_update_effect(elapsed, scaled_delta)
	queue_redraw()
	if elapsed >= duration:
		_complete()


func get_visual_node_count() -> int:
	return _count_descendants(_visual_root) if is_instance_valid(_visual_root) else 0


func get_procedural_signature() -> String:
	return "%s:%d" % [name, visual_seed]


func _process(delta: float) -> void:
	advance_simulation(delta)


func _build_effect(_parameters: Dictionary) -> void:
	pass


func _update_effect(_time: float, _delta: float) -> void:
	pass


func _before_clear() -> void:
	pass


func _clear_effect_state() -> void:
	pass


func _complete() -> void:
	if not active:
		return
	_before_clear()
	active = false
	set_process(false)
	if is_instance_valid(_visual_root):
		for child in _visual_root.get_children():
			child.free()
	_clear_effect_state()
	queue_redraw()
	effect_finished.emit(self)


func _ensure_visual_root() -> void:
	if is_instance_valid(_visual_root):
		return
	_visual_root = Node2D.new()
	_visual_root.name = "ProceduralVisuals"
	add_child(_visual_root)


func _count_descendants(node: Node) -> int:
	if node == null:
		return 0
	var total := node.get_child_count()
	for child in node.get_children():
		total += _count_descendants(child)
	return total


func _ease_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _smoothstep(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
