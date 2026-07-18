extends Node3D

const Audit := preload("res://tests/characters/elf/elf_import_audit.gd")
const REVIEW_OUTPUT_DIR := "C:/Blender_AI_Test/Output/godot_elf_review"
const REVIEW_RESULT_FILE := REVIEW_OUTPUT_DIR + "/visual_review.json"
const REVIEW_ORDER: Array[String] = [
	"Elf_Idle",
	"Elf_Walk",
	"Elf_Run",
	"Elf_Cast_Full",
	"Elf_Cast_Start",
	"Elf_Cast_Hold",
	"Elf_Cast_End",
	"Elf_Hit",
	"Elf_Death",
]
const SOURCE_NAME_BY_IMPORTED_NAME := {
	"Elf_Idle": "Elf_Idle-loop",
	"Elf_Walk": "Elf_Walk-loop",
	"Elf_Run": "Elf_Run-loop",
}

@onready var character_pivot: Node3D = $CharacterPivot
@onready var character_instance: Node = $CharacterPivot/GODOT_EXPORT
@onready var camera_three_quarter: Camera3D = $CameraThreeQuarter
@onready var camera_side: Camera3D = $CameraSide
@onready var animation_name_label: Label = $UI/Panel/Margin/VBox/AnimationName
@onready var animation_duration_label: Label = $UI/Panel/Margin/VBox/AnimationDuration
@onready var loop_status_label: Label = $UI/Panel/Margin/VBox/LoopStatus
@onready var time_status_label: Label = $UI/Panel/Margin/VBox/TimeStatus
@onready var speed_status_label: Label = $UI/Panel/Margin/VBox/SpeedStatus
@onready var camera_status_label: Label = $UI/Panel/Margin/VBox/CameraStatus

var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var animation_names: Array[String] = []
var current_animation_index := 0
var playback_speed := 1.0
var paused := false
var using_side_camera := false
var audit_result: Dictionary = {}
var captured_screenshots: Array[String] = []


func _ready() -> void:
	camera_three_quarter.look_at(Vector3(0.0, 0.7, 0.0))
	camera_side.look_at(Vector3(0.0, 0.7, 0.0))
	_set_side_camera(false)
	_find_imported_nodes()
	if animation_player == null:
		push_error("Elf validation: no AnimationPlayer found in the imported GLB instance.")
		return
	_build_dynamic_animation_list()
	audit_result = Audit.audit_instance(character_instance)
	_print_automated_audit()
	if "Elf_Idle" in animation_names:
		current_animation_index = animation_names.find("Elf_Idle")
	_play_current_animation()
	var user_args := OS.get_cmdline_user_args()
	if "--elf-auto-review" in user_args:
		_run_automated_review("--elf-auto-exit" in user_args)


func _process(_delta: float) -> void:
	_update_ui()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_LEFT:
			_step_animation(-1)
		KEY_RIGHT:
			_step_animation(1)
		KEY_SPACE:
			_toggle_pause()
		KEY_R:
			_restart_animation()
		KEY_C:
			_set_side_camera(not using_side_camera)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			var requested_index := int(event.keycode) - int(KEY_1)
			if requested_index < animation_names.size():
				current_animation_index = requested_index
				_play_current_animation()
		KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
			_set_playback_speed(playback_speed + 0.25)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_set_playback_speed(playback_speed - 0.25)


func _find_imported_nodes() -> void:
	var players: Array[Node] = character_instance.find_children("*", "AnimationPlayer", true, false)
	var skeletons: Array[Node] = character_instance.find_children("*", "Skeleton3D", true, false)
	var meshes: Array[Node] = character_instance.find_children("*", "MeshInstance3D", true, false)
	animation_player = players[0] as AnimationPlayer if not players.is_empty() else null
	skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	mesh_instance = meshes[0] as MeshInstance3D if not meshes.is_empty() else null


func _build_dynamic_animation_list() -> void:
	animation_names.clear()
	var imported_names: Array[String] = []
	for imported_name in animation_player.get_animation_list():
		imported_names.append(str(imported_name))
	for preferred_name in REVIEW_ORDER:
		if preferred_name in imported_names:
			animation_names.append(preferred_name)
	for imported_name in imported_names:
		if imported_name not in animation_names:
			animation_names.append(imported_name)


func _play_current_animation() -> void:
	if animation_names.is_empty():
		return
	paused = false
	animation_player.speed_scale = playback_speed
	animation_player.play(animation_names[current_animation_index])
	_update_ui()


func _play_animation_by_name(animation_name: String) -> void:
	var index := animation_names.find(animation_name)
	if index < 0:
		push_error("Elf validation: requested animation not found: %s" % animation_name)
		return
	current_animation_index = index
	_play_current_animation()


func _step_animation(direction: int) -> void:
	if animation_names.is_empty():
		return
	current_animation_index = posmod(current_animation_index + direction, animation_names.size())
	_play_current_animation()


func _toggle_pause() -> void:
	if animation_player == null:
		return
	paused = not paused
	if paused:
		animation_player.pause()
	else:
		animation_player.play()


func _restart_animation() -> void:
	if animation_names.is_empty():
		return
	animation_player.stop()
	_play_current_animation()


func _set_playback_speed(value: float) -> void:
	playback_speed = clampf(value, 0.25, 3.0)
	if animation_player != null:
		animation_player.speed_scale = playback_speed
	_update_ui()


func _set_side_camera(enabled: bool) -> void:
	using_side_camera = enabled
	camera_three_quarter.current = not enabled
	camera_side.current = enabled
	_update_ui()


func _update_ui() -> void:
	if animation_player == null or animation_names.is_empty():
		return
	var animation_name := animation_names[current_animation_index]
	var animation := animation_player.get_animation(animation_name)
	var source_hint := SOURCE_NAME_BY_IMPORTED_NAME.get(animation_name, animation_name) as String
	animation_name_label.text = "Animation : %s" % animation_name
	if source_hint != animation_name:
		animation_name_label.text += "  (GLB : %s)" % source_hint
	animation_duration_label.text = "Durée : %.3f s" % animation.length
	loop_status_label.text = "Boucle : %s" % ("oui" if animation.loop_mode != Animation.LOOP_NONE else "non")
	time_status_label.text = "Lecture : %.3f / %.3f s%s" % [
		animation_player.current_animation_position,
		animation.length,
		"  [PAUSE]" if paused else "",
	]
	speed_status_label.text = "Vitesse : %.2fx" % playback_speed
	camera_status_label.text = "Caméra : %s" % ("latérale" if using_side_camera else "trois-quarts")


func _print_automated_audit() -> void:
	print("\n========== ELF IMPORT VALIDATION ==========")
	print("Godot: ", Engine.get_version_info().get("string", "unknown"))
	print("Renderer: ", ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"))
	print("Hierarchy:")
	for line in audit_result.get("hierarchy", []):
		print("  ", line)
	print("Skeleton count: ", audit_result.get("skeleton_count", 0))
	print("Bone count: ", (audit_result.get("skeleton", {}) as Dictionary).get("bone_count", 0))
	print("Root bones: ", (audit_result.get("skeleton", {}) as Dictionary).get("roots", []))
	print("Mesh/Skin/Material/Texture: ", [
		audit_result.get("mesh_instance_count", 0),
		audit_result.get("skin_present", false),
		audit_result.get("material_present", false),
		audit_result.get("texture_present", false),
	])
	print("AABB position/size: ", audit_result.get("aabb_position", []), " / ", audit_result.get("aabb_size", []))
	print("Surfaces/vertices/indices: ", [
		audit_result.get("surface_count", 0),
		audit_result.get("total_vertices", 0),
		audit_result.get("total_indices", 0),
	])
	print("Animations:")
	for animation_data in audit_result.get("animations", []):
		print("  %s | %.6f s | loop=%s | tracks=%d" % [
			animation_data.get("name", ""),
			animation_data.get("length", 0.0),
			animation_data.get("loops", false),
			animation_data.get("track_count", 0),
		])
	print("Weight audit:")
	for surface_data in audit_result.get("surfaces", []):
		print(JSON.stringify(surface_data, "  "))
	print("Errors: ", audit_result.get("errors", []))
	print("Warnings: ", audit_result.get("warnings", []))
	print("===========================================\n")


func _run_automated_review(exit_when_done: bool) -> void:
	DirAccess.make_dir_recursive_absolute(REVIEW_OUTPUT_DIR)
	var plan := [
		{"name": "Elf_Idle", "cycles": 2.0},
		{"name": "Elf_Walk", "cycles": 2.0},
		{"name": "Elf_Run", "cycles": 3.0},
		{"name": "Elf_Cast_Full", "cycles": 1.0},
		{"name": "Elf_Cast_Start", "cycles": 1.0},
		{"name": "Elf_Cast_Hold", "cycles": 1.0},
		{"name": "Elf_Cast_End", "cycles": 1.0},
		{"name": "Elf_Hit", "cycles": 1.0},
		{"name": "Elf_Death", "cycles": 1.0},
	]
	var observations: Array[Dictionary] = []
	for item in plan:
		var animation_name := item["name"] as String
		if animation_name not in animation_names:
			observations.append({"name": animation_name, "error": "missing"})
			continue
		_set_side_camera(false)
		_play_animation_by_name(animation_name)
		await get_tree().process_frame
		var animation := animation_player.get_animation(animation_name)
		var duration := animation.length
		var cycles := float(item["cycles"])
		var files: Array[String] = []
		files.append(await _capture_frame(animation_name, "threequarter_start"))
		await get_tree().create_timer(duration * 0.5).timeout
		files.append(await _capture_frame(animation_name, "threequarter_mid"))
		await get_tree().create_timer(duration * 0.45).timeout
		files.append(await _capture_frame(animation_name, "threequarter_end"))
		var remaining_time := duration * cycles - duration * 0.95
		if remaining_time > 0.0:
			await get_tree().create_timer(remaining_time).timeout
		observations.append({
			"name": animation_name,
			"duration_seconds": duration,
			"cycles_observed": cycles,
			"observation_seconds": duration * cycles,
			"screenshots": files,
		})
	if "Elf_Death" in animation_names:
		_set_side_camera(true)
		_play_animation_by_name("Elf_Death")
		var death_animation := animation_player.get_animation("Elf_Death")
		for sample in [
			{"suffix": "side_start", "time": 0.0},
			{"suffix": "side_mid", "time": death_animation.length * 0.5},
			{"suffix": "side_end", "time": death_animation.length},
		]:
			animation_player.seek(sample["time"], true)
			await get_tree().process_frame
			await _capture_frame("Elf_Death", sample["suffix"])
	_set_side_camera(false)
	_play_animation_by_name("Elf_Idle")
	var review_result := {
		"godot_version": Engine.get_version_info(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"),
		"audit_errors": audit_result.get("errors", []),
		"audit_warnings": audit_result.get("warnings", []),
		"observations": observations,
		"captured_screenshots": captured_screenshots,
	}
	var result_file := FileAccess.open(REVIEW_RESULT_FILE, FileAccess.WRITE)
	if result_file != null:
		result_file.store_string(JSON.stringify(review_result, "  "))
		result_file.close()
	else:
		push_error("Unable to write visual review result: %s" % REVIEW_RESULT_FILE)
	print("ELF_VISUAL_REVIEW_COMPLETE=", JSON.stringify(review_result))
	if exit_when_done:
		get_tree().quit(0 if (audit_result.get("errors", []) as Array).is_empty() else 5)


func _capture_frame(animation_name: String, suffix: String) -> String:
	await RenderingServer.frame_post_draw
	var safe_name := animation_name.to_lower().replace("elf_", "")
	var output_path := "%s/%s_%s.png" % [REVIEW_OUTPUT_DIR, safe_name, suffix]
	var image := get_viewport().get_texture().get_image()
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Unable to save review screenshot %s (error %d)" % [output_path, save_error])
		return ""
	captured_screenshots.append(output_path)
	return output_path
