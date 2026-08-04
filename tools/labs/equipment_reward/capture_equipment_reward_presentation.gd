extends Node

const LAB_SCENE := preload(
	"res://tools/labs/equipment_reward/EquipmentRewardPresentationLab.tscn"
)
const OUTPUT_DIR := "res://artifacts/equipment_reward_presentation/captures"

var lab: EquipmentRewardPresentationLab = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	lab = LAB_SCENE.instantiate() as EquipmentRewardPresentationLab
	lab.show_debug_controls = false
	add_child(lab)
	await _set_resolution(Vector2i(1920, 1080))
	await get_tree().create_timer(0.7).timeout
	await _capture("01_neutral")
	lab.simulate_hover(0, true)
	await _settle()
	await _capture("02_hover_left")
	lab.simulate_hover(0, false)
	lab.select_left()
	await _settle(8)
	await _capture("03_selected_left")
	lab.open_overlay()
	lab.select_right()
	await _settle(8)
	await _capture("04_selected_right")
	lab.confirm_selection()
	await _settle(2)
	await _capture("05_confirmation")

	for entry in [
		{"size": Vector2i(1280, 720), "name": "06_resolution_720p"},
		{"size": Vector2i(1920, 1080), "name": "07_resolution_1080p"},
		{"size": Vector2i(2560, 1440), "name": "08_resolution_1440p"},
	]:
		lab.open_overlay()
		await _set_resolution(entry["size"])
		await _capture(entry["name"])

	await _set_resolution(Vector2i(1920, 1080))
	lab.set_reduced_motion_for_lab(true)
	lab.select_left()
	await _settle()
	await _capture("09_reduced_motion")
	lab.set_missing_texture_for_lab(true)
	await _settle()
	await _capture("10_missing_texture_fallback")
	print("EQUIPMENT_REWARD_CAPTURE_VALIDATION=PASS")
	lab.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)


func _set_resolution(viewport_size: Vector2i) -> void:
	lab.set_resolution_for_lab(viewport_size)
	await _settle(4)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, file_name]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Capture impossible : %s" % path)
		get_tree().quit(1)
	else:
		print("CAPTURED %s" % path)


func _settle(frame_count: int = 3) -> void:
	for _index in frame_count:
		await get_tree().process_frame
