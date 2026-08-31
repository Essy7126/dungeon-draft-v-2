extends Node

const CINEMATIC_SCENE := preload("res://cinematics/intro/intro_cinematic.tscn")
const CATABASE_SEQUENCE: CinematicSequenceData = preload(
	"res://cinematics/catabase/catabase_intro_v4.tres"
)
const CAPTURE_TIMES := [
	0.60,
	4.20,
	6.42,
	11.00,
	19.48,
	28.72,
	38.42,
	47.52,
	57.82,
	60.58,
	66.18,
	68.70,
]


func _ready() -> void:
	var output_directory := _argument_value("--output-dir=")
	if output_directory.is_empty():
		push_error("Catabase QA : --output-dir est obligatoire.")
		get_tree().quit(2)
		return
	var requested_size := _parse_resolution(_argument_value("--resolution="))
	if requested_size == Vector2i.ZERO:
		push_error("Catabase QA : --resolution=WIDTHxHEIGHT est obligatoire.")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_directory)
	get_window().size = requested_size
	var cinematic := CINEMATIC_SCENE.instantiate() as IntroCinematic
	cinematic.autoplay = false
	cinematic.sequence_override = CATABASE_SEQUENCE
	add_child(cinematic)
	await get_tree().process_frame
	await get_tree().process_frame
	for capture_time in CAPTURE_TIMES:
		cinematic.synchronize_to_time(capture_time)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var file_name := "%s/catabase_%s_%06.2f.png" % [
			output_directory,
			"%dx%d" % [requested_size.x, requested_size.y],
			capture_time,
		]
		var error := image.save_png(file_name)
		if error != OK:
			push_error("Catabase QA : capture impossible : %s" % file_name)
			get_tree().quit(3)
			return
	print(
		"CATABASE_CINEMATIC_QA_CAPTURED resolution=%dx%d count=%d output=%s"
		% [requested_size.x, requested_size.y, CAPTURE_TIMES.size(), output_directory]
	)
	get_tree().quit()


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _parse_resolution(value: String) -> Vector2i:
	var parts := value.to_lower().split("x")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

