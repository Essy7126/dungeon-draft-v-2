extends Node

const OUTPUT_DIR := "res://artifacts/vfx_lab_v1"
const LAB_SCENE := preload("res://tools/labs/vfx_lab/VFXLab.tscn")
const VIEWPORT_SIZE := Vector2i(1200, 896)
const EFFECT_IDS := ["fireball", "ice_wall", "seismic_wave", "charge", "guard", "lightning_storm"]
const CAPTURE_TIMES := [
	[0.18, 0.72, 1.18],
	[0.22, 0.76, 1.34],
	[0.28, 0.92, 1.52],
	[0.16, 0.62, 1.08],
	[0.28, 0.88, 1.20],
	[0.38, 0.76, 1.62],
]
const HERO_FRAME_INDEX := [2, 2, 2, 1, 2, 2]

var lab: Node2D = null
var failures := 0
var captured_files: Array[String] = []
var maximum_visual_nodes := 0


func _ready() -> void:
	call_deferred("_capture_all")


func _capture_all() -> void:
	get_window().size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	lab = LAB_SCENE.instantiate() as Node2D
	add_child(lab)
	await _settle(5)
	lab.clear_effect()
	for effect_index in EFFECT_IDS.size():
		await _capture_effect(effect_index)
	_validate_stress_cleanup()
	_save_metrics()
	_validate_outputs()
	print("VFX_LAB_CAPTURE_FAILURES=%d" % failures)
	print("VFX_LAB_CAPTURE_COUNT=%d" % captured_files.size())
	get_tree().quit(1 if failures > 0 else 0)


func _capture_effect(effect_index: int) -> void:
	var effect_id: String = str(EFFECT_IDS[effect_index])
	var frame_dir: String = OUTPUT_DIR.path_join(effect_id + "_frames")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(frame_dir))
	var effect: Node = lab.play_effect(effect_index, 1337)
	effect.set_process(false)
	var previous_time := 0.0
	for frame_index in CAPTURE_TIMES[effect_index].size():
		var target_time: float = CAPTURE_TIMES[effect_index][frame_index]
		await _advance(effect, target_time - previous_time)
		previous_time = target_time
		maximum_visual_nodes = maxi(maximum_visual_nodes, effect.get_visual_node_count())
		var frame_name: String = frame_dir.path_join("frame_%02d.png" % [frame_index + 1])
		await _capture(frame_name)
		if frame_index == HERO_FRAME_INDEX[effect_index]:
			await _capture(OUTPUT_DIR.path_join(effect_id + ".png"))
	lab.clear_effect()
	if lab.current_effect != null or lab.world.get_child_count() != 4:
		push_error("Cleanup incomplet apres %s" % effect_id)
		failures += 1
	await _settle(2)


func _advance(effect: Node, seconds: float) -> void:
	var frames := maxi(1, ceili(seconds * 60.0))
	var step := seconds / float(frames)
	for _frame in frames:
		effect.advance_simulation(step)
		await get_tree().process_frame
	await _settle(2)


func _capture(relative_path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Image vide : %s" % relative_path)
		failures += 1
		return
	var error := image.save_png(ProjectSettings.globalize_path(relative_path))
	if error != OK:
		push_error("Echec capture %s : %s" % [relative_path, error_string(error)])
		failures += 1
	else:
		captured_files.append(relative_path)
		print("CAPTURED %s" % relative_path)


func _validate_stress_cleanup() -> void:
	for effect_index in EFFECT_IDS.size():
		for iteration in 20:
			lab.play_effect(effect_index, 7000 + iteration)
			lab.clear_effect()
			if lab.world.get_child_count() != 4:
				failures += 1
				push_error("Accumulation effet %d iteration %d" % [effect_index, iteration])


func _save_metrics() -> void:
	var metrics := {
		"godot": Engine.get_version_info().get("string", "unknown"),
		"renderer": RenderingServer.get_rendering_device() != null,
		"effects": EFFECT_IDS,
		"seed": 1337,
		"captures": captured_files,
		"maximum_visual_nodes": maximum_visual_nodes,
		"stress_replays_per_effect": 20,
		"remaining_stage_children": lab.world.get_child_count(),
		"external_visual_assets": 0,
	}
	var file := FileAccess.open(OUTPUT_DIR.path_join("validation_metrics.json"), FileAccess.WRITE)
	if file == null:
		failures += 1
		return
	file.store_string(JSON.stringify(metrics, "  "))
	captured_files.append(OUTPUT_DIR.path_join("validation_metrics.json"))


func _validate_outputs() -> void:
	for effect_id in EFFECT_IDS:
		if not FileAccess.file_exists(OUTPUT_DIR.path_join(effect_id + ".png")):
			push_error("Capture principale absente : %s" % effect_id)
			failures += 1
		for frame_index in 3:
			var frame_path: String = OUTPUT_DIR.path_join(effect_id + "_frames/frame_%02d.png" % [frame_index + 1])
			if not FileAccess.file_exists(frame_path):
				push_error("Frame absente : %s" % frame_path)
				failures += 1


func _settle(frame_count: int) -> void:
	for _frame in frame_count:
		await get_tree().process_frame
