extends Node2D

const VFX_SCENE: PackedScene = preload(
	"res://asset/sorts/tempete_orageuse/tempete_orageuse_vfx.tscn"
)
const SELF_TEST_ARGUMENT := "--vfx-self-test"
const SELF_TEST_TIMEOUT_SECONDS := 2.0

@onready var _status_label: Label = $Status

var _active_vfx: Node2D
var _replay_in_progress := false
var _self_test_running := false
var _casts_started := 0
var _casts_finished := 0
var _impacts_reached := 0


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)
	_self_test_running = SELF_TEST_ARGUMENT in OS.get_cmdline_user_args()
	if _self_test_running:
		call_deferred("_run_self_test")
	else:
		call_deferred("_spawn_vfx")


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var center := viewport_size * 0.5
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("101525"))
	draw_line(
		Vector2(0.0, center.y + 2.0),
		Vector2(viewport_size.x, center.y + 2.0),
		Color("384666"),
		2.0
	)
	draw_circle(center, 7.0, Color("63dcff"))
	draw_circle(center, 18.0, Color(0.39, 0.86, 1.0, 0.18), false, 2.0)


func _unhandled_key_input(event: InputEvent) -> void:
	if (
		not _self_test_running
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode in [KEY_SPACE, KEY_ENTER]
	):
		get_viewport().set_input_as_handled()
		_replay()


func _replay() -> void:
	if _replay_in_progress:
		return

	_replay_in_progress = true
	if is_instance_valid(_active_vfx):
		var outgoing_vfx := _active_vfx
		outgoing_vfx.call(&"cancel")
		await outgoing_vfx.tree_exited
	_spawn_vfx()
	_replay_in_progress = false


func _spawn_vfx() -> void:
	var instance := VFX_SCENE.instantiate() as Node2D
	instance.position = get_viewport_rect().size * 0.5
	instance.connect(&"impact_reached", _on_impact_reached)
	instance.tree_exited.connect(
		_on_vfx_tree_exited.bind(instance),
		CONNECT_ONE_SHOT
	)
	_active_vfx = instance
	_casts_started += 1
	add_child(instance)
	_update_status()


func _on_impact_reached() -> void:
	_impacts_reached += 1
	_update_status()


func _on_vfx_tree_exited(instance: Node2D) -> void:
	_casts_finished += 1
	if _active_vfx == instance:
		_active_vfx = null
	_update_status()


func _update_status() -> void:
	if not is_instance_valid(_status_label):
		return

	var active_count := get_tree().get_nodes_in_group(
		&"tempete_orageuse_vfx"
	).size()
	_status_label.text = (
		"Lectures : %d  |  Terminées : %d  |  Impacts : %d  |  Instances actives : %d"
		% [_casts_started, _casts_finished, _impacts_reached, active_count]
	)


func _run_self_test() -> void:
	await get_tree().process_frame
	for cast_index in 2:
		_spawn_vfx()
		if not await _wait_until_vfx_freed():
			_fail_self_test("l'instance %d n'a pas été libérée" % (cast_index + 1))
			return
		await get_tree().process_frame
		if not get_tree().get_nodes_in_group(&"tempete_orageuse_vfx").is_empty():
			_fail_self_test("une instance reste active après la lecture")
			return

	if _casts_started != 2 or _casts_finished != 2 or _impacts_reached != 2:
		_fail_self_test(
			"compteurs inattendus (lancées=%d, terminées=%d, impacts=%d)"
			% [_casts_started, _casts_finished, _impacts_reached]
		)
		return

	var impacts_before_cancel := _impacts_reached
	_spawn_vfx()
	await get_tree().process_frame
	_active_vfx.call(&"cancel")
	if not await _wait_until_vfx_freed():
		_fail_self_test("l'instance annulée n'a pas été libérée")
		return
	await get_tree().process_frame
	if (
		not get_tree().get_nodes_in_group(&"tempete_orageuse_vfx").is_empty()
		or _impacts_reached != impacts_before_cancel
		or _casts_started != 3
		or _casts_finished != 3
	):
		_fail_self_test("le nettoyage après annulation est incorrect")
		return

	print(
		"TEMPETE_ORAGEUSE_VFX_SELF_TEST: PASS "
		+ "(2 lectures, 2 impacts visuels, 1 annulation, 0 instance active)"
	)
	get_tree().quit()


func _wait_until_vfx_freed() -> bool:
	var deadline := (
		Time.get_ticks_msec()
		+ int(SELF_TEST_TIMEOUT_SECONDS * 1000.0)
	)
	while is_instance_valid(_active_vfx):
		if Time.get_ticks_msec() >= deadline:
			return false
		await get_tree().process_frame
	return true


func _fail_self_test(message: String) -> void:
	push_error("TEMPETE_ORAGEUSE_VFX_SELF_TEST: FAIL - " + message)
	get_tree().quit(1)
