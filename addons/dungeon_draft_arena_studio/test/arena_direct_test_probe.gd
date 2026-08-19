class_name ArenaDirectTestProbe
extends Node

const MAX_FRAMES := 360

var request := {}
var provenance := {}
var elapsed_frames := 0


func configure(request_data: Dictionary, provenance_data: Dictionary) -> void:
	request = request_data.duplicate(true)
	provenance = provenance_data.duplicate(true)
	name = "ArenaDirectTestProbe"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	elapsed_frames += 1
	var scene := get_tree().current_scene
	if ArenaRuntimeSceneProbeService.is_ready_for_inspection(scene):
		_finalize(inspect_runtime_scene(scene, request, provenance))
		return
	if elapsed_frames >= MAX_FRAMES:
		var timeout_result := provenance.duplicate(true)
		timeout_result.merge({
			"ok": false,
			"runtime_scene_inspected": false,
			"runtime_ready": false,
			"error": "runtime_scene_timeout",
			"errors": [{
				"code": &"RUNTIME_SCENE_TIMEOUT",
				"domain": &"runtime",
				"message": "La scene runtime n'a pas publie runtime_ready a temps.",
				"details": {"elapsed_frames": elapsed_frames},
			}],
		}, true)
		_finalize(timeout_result)


static func inspect_runtime_scene(
		scene: Node,
		request_data: Dictionary,
		provenance_data: Dictionary
	) -> Dictionary:
	return ArenaRuntimeSceneProbeService.inspect(
		scene, request_data, provenance_data
	)


func _finalize(result: Dictionary) -> void:
	var cleanup_required := bool(request.get("cleanup_on_load", false))
	var cleanup_ok := true
	if cleanup_required:
		cleanup_ok = ArenaDirectTestService.cleanup_context(request)
	var quit_after_probe := bool(request.get("quit_after_probe", false))
	if quit_after_probe:
		var game_manager := get_node_or_null("/root/GameManager")
		if game_manager != null and game_manager.has_method("cleanup_run_state"):
			game_manager.cleanup_run_state()
		else:
			cleanup_ok = false
	result["cleanup_required"] = cleanup_required
	result["cleanup_ok"] = cleanup_ok
	result["probe_pending"] = false
	var result_path := str(request.get(
		"result_path", ArenaDirectTestService.LAST_RESULT_PATH
	))
	var absolute := ProjectSettings.globalize_path(result_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(result_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "  "))
		file.close()
	var console_result := result.duplicate(true)
	console_result.erase("visual_report")
	print("ARENA_STUDIO_RUNTIME_PROBE ", JSON.stringify(console_result))
	queue_free()
	if quit_after_probe:
		get_tree().quit(0 if bool(result.get("ok", false)) and cleanup_ok else 11)
