extends Node3D

const SCREENSHOT_DIR := "res://tests/characters/elf/screenshots"
const REVIEW_OUTPUT := "C:/Blender_AI_Test/Output/godot_elf_in_game_preview.json"

@export_range(0.1, 4.0, 0.05) var walk_cells_per_second := 1.0
@export_range(0.1, 6.0, 0.05) var run_cells_per_second := 1.67
@export_range(0.5, 3.0, 0.1) var cell_size := 1.5

@onready var elf_anchor: Node3D = $ElfAnchor
@onready var elf_visual: ElfVisual3D = $ElfAnchor/ElfVisual3D
@onready var isometric_camera: Camera3D = $IsometricCamera
@onready var side_camera: Camera3D = $SideCamera
@onready var animation_label: Label = $UI/Panel/Margin/VBox/AnimationLabel
@onready var speed_label: Label = $UI/Panel/Margin/VBox/SpeedLabel
@onready var camera_label: Label = $UI/Panel/Margin/VBox/CameraLabel
@onready var movement_label: Label = $UI/Panel/Margin/VBox/MovementLabel
@onready var performance_label: Label = $UI/Panel/Margin/VBox/PerformanceLabel

var playback_speed := 1.0
var movement_preview_enabled := false
var _movement_active := false
var _movement_elapsed := 0.0
var _movement_duration := 1.0
var _movement_start := Vector3.ZERO
var _movement_target := Vector3.ZERO
var _using_side_camera := false
var _triangle_count := 0
var _character_aabb := AABB()
var _character_mesh: MeshInstance3D
var _renderer := ""
var _fps_samples: Array[float] = []
var _auto_review_running := false
var _screenshots: Array[String] = []


func _ready() -> void:
	isometric_camera.look_at(Vector3(0.0, 0.72, 0.0))
	side_camera.look_at(Vector3(0.0, 0.72, 0.0))
	_set_side_camera(false)
	_collect_visual_metrics()
	elf_visual.set_socket_debug_visible(false)
	elf_visual.reset_to_idle()
	_print_preview_metrics()
	var user_args := OS.get_cmdline_user_args()
	if "--elf-preview-auto-review" in user_args:
		_auto_review_running = true
		_run_automated_review("--elf-preview-auto-exit" in user_args)


func _process(delta: float) -> void:
	_update_demo_movement(delta)
	_update_ui()
	if _auto_review_running:
		_fps_samples.append(Engine.get_frames_per_second())


func _unhandled_key_input(event: InputEvent) -> void:
	if _auto_review_running or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_play_idle()
		KEY_2:
			_play_walk()
		KEY_3:
			_play_run()
		KEY_4:
			_play_static_animation(ElfVisual3D.ANIM_CAST_FULL)
		KEY_5:
			_play_static_animation(ElfVisual3D.ANIM_HIT)
		KEY_6:
			_play_static_animation(ElfVisual3D.ANIM_DEATH)
		KEY_7:
			_play_static_animation(ElfVisual3D.ANIM_CAST_START)
		KEY_8:
			_play_static_animation(ElfVisual3D.ANIM_CAST_HOLD)
		KEY_9:
			_play_static_animation(ElfVisual3D.ANIM_CAST_END)
		KEY_R:
			_play_idle()
		KEY_C:
			_set_side_camera(not _using_side_camera)
		KEY_M:
			movement_preview_enabled = not movement_preview_enabled
		KEY_L:
			elf_visual.set_socket_debug_visible(not elf_visual.show_socket_debug)
		KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
			_set_playback_speed(playback_speed + 0.25)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_set_playback_speed(playback_speed - 0.25)


func _play_idle() -> void:
	_stop_demo_movement()
	elf_visual.play_idle()


func _play_walk() -> void:
	_stop_demo_movement()
	elf_visual.play_walk(playback_speed)
	if movement_preview_enabled:
		_start_one_cell_movement(walk_cells_per_second)


func _play_run() -> void:
	_stop_demo_movement()
	elf_visual.play_run(playback_speed)
	if movement_preview_enabled:
		_start_one_cell_movement(run_cells_per_second)


func _play_static_animation(animation_name: StringName) -> void:
	_stop_demo_movement()
	elf_visual.play_animation(animation_name, playback_speed)


func _set_playback_speed(value: float) -> void:
	playback_speed = clampf(value, 0.25, 3.0)
	var current := elf_visual.get_current_animation()
	if current != &"" and elf_visual.is_animation_playing():
		elf_visual.play_animation(current, playback_speed, 0.05)


func _start_one_cell_movement(cells_per_second: float) -> void:
	_movement_start = elf_anchor.position
	var center := Vector3.ZERO
	var adjacent := Vector3(cell_size, 0.0, 0.0)
	_movement_target = adjacent if elf_anchor.position.distance_to(center) <= elf_anchor.position.distance_to(adjacent) else center
	_movement_duration = maxf(_movement_start.distance_to(_movement_target) / maxf(cells_per_second * cell_size, 0.001), 0.001)
	_movement_elapsed = 0.0
	_movement_active = true


func _update_demo_movement(delta: float) -> void:
	if not _movement_active:
		return
	_movement_elapsed += delta
	var progress := minf(_movement_elapsed / _movement_duration, 1.0)
	elf_anchor.position = _movement_start.lerp(_movement_target, progress)
	if progress >= 1.0:
		_movement_active = false
		elf_visual.play_idle()


func _stop_demo_movement() -> void:
	_movement_active = false


func _set_side_camera(enabled: bool) -> void:
	_using_side_camera = enabled
	isometric_camera.current = not enabled
	side_camera.current = enabled


func _collect_visual_metrics() -> void:
	_renderer = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"))
	var meshes: Array[Node] = elf_visual.find_children("*", "MeshInstance3D", true, false)
	for mesh_node in meshes:
		var candidate := mesh_node as MeshInstance3D
		if candidate.mesh == null or candidate.skin == null:
			continue
		_character_mesh = candidate
		break
	if _character_mesh == null:
		return
	_character_aabb = _character_mesh.get_aabb()
	for surface_index in _character_mesh.mesh.get_surface_count():
		var arrays := _character_mesh.mesh.surface_get_arrays(surface_index)
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		_triangle_count += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3


func _update_ui() -> void:
	if elf_visual == null:
		return
	var animation_name := elf_visual.get_current_animation()
	animation_label.text = "Animation : %s" % (animation_name if animation_name != &"" else &"—")
	speed_label.text = "Vitesse animation : %.2fx" % playback_speed
	camera_label.text = "Caméra : %s" % ("latérale" if _using_side_camera else "isométrique")
	movement_label.text = "Déplacement M : %s%s" % [
		"activé" if movement_preview_enabled else "désactivé",
		" — en cours" if _movement_active else "",
	]
	var active_camera := side_camera if _using_side_camera else isometric_camera
	var screen_height := 0
	if _character_mesh != null and active_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		screen_height = int(_character_aabb.size.y / active_camera.size * get_viewport().get_visible_rect().size.y)
	performance_label.text = "FPS : %d | triangles : %d | renderer : %s | taille écran : ~%d px\nAABB : pos %s — taille %s" % [
		Engine.get_frames_per_second(),
		_triangle_count,
		_renderer,
		screen_height,
		str(_character_aabb.position),
		str(_character_aabb.size),
	]


func _print_preview_metrics() -> void:
	print("\n========== ELF IN-GAME PREVIEW ==========")
	print("Renderer: ", _renderer)
	print("Triangles: ", _triangle_count)
	print("AABB: ", _character_aabb)
	print("Cell size: ", cell_size)
	print("Walk cells/s: ", walk_cells_per_second)
	print("Run cells/s: ", run_cells_per_second)
	print("=========================================\n")


func _run_automated_review(exit_when_done: bool) -> void:
	var absolute_screenshot_dir := ProjectSettings.globalize_path(SCREENSHOT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_screenshot_dir)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if _character_mesh == null:
		errors.append("MeshInstance3D skinné introuvable")
	if elf_visual.get_animation_player() == null:
		errors.append("AnimationPlayer introuvable")
	if elf_visual.get_skeleton() == null:
		errors.append("Skeleton3D introuvable")
	if not errors.is_empty():
		_finish_auto_review(errors, warnings, {}, exit_when_done)
		return
	_set_side_camera(false)
	elf_anchor.position = Vector3.ZERO
	movement_preview_enabled = false
	elf_visual.set_socket_debug_visible(false)
	_play_idle()
	await get_tree().create_timer(0.7).timeout
	await _capture("elf_idle_isometric.png")
	_play_walk()
	await get_tree().create_timer(0.5).timeout
	await _capture("elf_walk_in_place_isometric.png")
	await get_tree().create_timer(0.6).timeout
	movement_preview_enabled = true
	_play_walk()
	await get_tree().create_timer(0.5 / walk_cells_per_second).timeout
	await _capture("elf_walk_isometric.png")
	await get_tree().create_timer(0.55 / walk_cells_per_second).timeout
	var walk_end := elf_anchor.position
	var walk_finished_idle := elf_visual.get_current_animation() == ElfVisual3D.ANIM_IDLE
	movement_preview_enabled = false
	_play_run()
	await get_tree().create_timer(0.3).timeout
	await _capture("elf_run_in_place_isometric.png")
	await get_tree().create_timer(0.35).timeout
	movement_preview_enabled = true
	_play_run()
	await get_tree().create_timer(0.5 / run_cells_per_second).timeout
	await _capture("elf_run_moving_isometric.png")
	await get_tree().create_timer(0.55 / run_cells_per_second).timeout
	var run_end := elf_anchor.position
	var run_finished_idle := elf_visual.get_current_animation() == ElfVisual3D.ANIM_IDLE
	movement_preview_enabled = false
	_play_static_animation(ElfVisual3D.ANIM_CAST_FULL)
	await get_tree().create_timer(1.65).timeout
	await _capture("elf_cast_isometric.png")
	_play_static_animation(ElfVisual3D.ANIM_CAST_START)
	await get_tree().create_timer(0.53).timeout
	await _capture("elf_cast_start_isometric.png")
	_play_static_animation(ElfVisual3D.ANIM_CAST_HOLD)
	await get_tree().create_timer(0.73).timeout
	await _capture("elf_cast_hold_isometric.png")
	_play_static_animation(ElfVisual3D.ANIM_CAST_END)
	await get_tree().create_timer(0.4).timeout
	await _capture("elf_cast_end_isometric.png")
	_play_static_animation(ElfVisual3D.ANIM_HIT)
	await get_tree().create_timer(1.4).timeout
	await _capture("elf_hit_isometric.png")
	var death_anchor_start := elf_anchor.position
	_play_static_animation(ElfVisual3D.ANIM_DEATH)
	await get_tree().create_timer(3.35).timeout
	await _capture("elf_death_isometric.png")
	var death_anchor_end := elf_anchor.position
	_set_side_camera(true)
	_play_static_animation(ElfVisual3D.ANIM_DEATH)
	await get_tree().create_timer(3.35).timeout
	await _capture("elf_death_side.png")
	_set_side_camera(false)
	elf_visual.set_socket_debug_visible(true)
	_play_idle()
	await get_tree().create_timer(0.5).timeout
	await _capture("elf_sockets_isometric.png")
	elf_visual.set_socket_debug_visible(false)
	var expected_adjacent := Vector3(cell_size, 0.0, 0.0)
	if not walk_end.is_equal_approx(expected_adjacent):
		errors.append("Walk n’a pas terminé exactement sur la case adjacente : %s" % walk_end)
	if not run_end.is_equal_approx(Vector3.ZERO):
		errors.append("Run n’a pas terminé exactement sur la case centrale : %s" % run_end)
	if not walk_finished_idle:
		errors.append("Walk ne revient pas à Idle à la fin d’une case")
	if not run_finished_idle:
		errors.append("Run ne revient pas à Idle à la fin d’une case")
	if not death_anchor_start.is_equal_approx(death_anchor_end):
		errors.append("Death a déplacé ElfAnchor")
	warnings.append("La synchronisation fine du glissement des pieds doit être confirmée visuellement en lecture interactive.")
	warnings.append("Death conserve le déplacement interne de Hips et peut dépasser la case centrale.")
	var average_fps := 0.0
	if not _fps_samples.is_empty():
		for fps in _fps_samples:
			average_fps += fps
		average_fps /= _fps_samples.size()
	var metrics := {
		"renderer": _renderer,
		"triangles": _triangle_count,
		"aabb_position": [_character_aabb.position.x, _character_aabb.position.y, _character_aabb.position.z],
		"aabb_size": [_character_aabb.size.x, _character_aabb.size.y, _character_aabb.size.z],
		"cell_size": cell_size,
		"walk_cells_per_second": walk_cells_per_second,
		"run_cells_per_second": run_cells_per_second,
		"walk_end": [walk_end.x, walk_end.y, walk_end.z],
		"run_end": [run_end.x, run_end.y, run_end.z],
		"death_anchor_start": [death_anchor_start.x, death_anchor_start.y, death_anchor_start.z],
		"death_anchor_end": [death_anchor_end.x, death_anchor_end.y, death_anchor_end.z],
		"average_fps": average_fps,
		"fps_sample_count": _fps_samples.size(),
	}
	elf_anchor.position = Vector3.ZERO
	_set_side_camera(false)
	elf_visual.set_socket_debug_visible(false)
	_play_idle()
	_finish_auto_review(errors, warnings, metrics, exit_when_done)


func _capture(filename: String) -> String:
	await RenderingServer.frame_post_draw
	var resource_path := "%s/%s" % [SCREENSHOT_DIR, filename]
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(absolute_path)
	if result != OK:
		push_warning("Impossible d’enregistrer %s" % absolute_path)
		return ""
	_screenshots.append(resource_path)
	return resource_path


func _finish_auto_review(
	errors: Array[String],
	warnings: Array[String],
	metrics: Dictionary,
	exit_when_done: bool
) -> void:
	var verdict := "ELF_IN_GAME_PREVIEW_REJECTED" if not errors.is_empty() else (
		"ELF_IN_GAME_PREVIEW_VALIDATED_WITH_WARNINGS" if not warnings.is_empty() else "ELF_IN_GAME_PREVIEW_VALIDATED"
	)
	var result := {
		"verdict": verdict,
		"errors": errors,
		"warnings": warnings,
		"metrics": metrics,
		"screenshots": _screenshots,
	}
	var output := FileAccess.open(REVIEW_OUTPUT, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(result, "  "))
		output.close()
	print("ELF_IN_GAME_PREVIEW_RESULT=", JSON.stringify(result))
	_auto_review_running = false
	if exit_when_done:
		get_tree().quit(0 if errors.is_empty() else 8)
