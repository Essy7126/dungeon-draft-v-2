extends Node

const CINEMATIC_SCENE := preload("res://cinematics/intro/intro_cinematic.tscn")
const OUTPUT := "res://artifacts/start_hub/start_hub_intro_from_hub_1920x1080.png"

@onready var hub: Node = $StartHub


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	_capture.call_deferred()


func _capture() -> void:
	for _frame in range(20):
		await get_tree().process_frame
	var controller: StartHubController = hub.get_node("HubController")
	controller.movement.movement_speed = 2400.0
	controller.transition_fade_duration = 0.0
	var opened_cinematic: Array[IntroCinematic] = []
	controller.cinematic_open_callable = func(scene_path: String) -> bool:
		if scene_path != CINEMATIC_SCENE.resource_path:
			return false
		var cinematic := CINEMATIC_SCENE.instantiate() as IntroCinematic
		cinematic.autoplay = false
		add_child(cinematic)
		hub.visible = false
		hub.get_node("HubUI").visible = false
		opened_cinematic.append(cinematic)
		return true

	controller.request_interaction(controller.archivist)
	for _frame in range(160):
		await get_tree().process_frame
		if controller.archivist_panel.visible:
			break
	if not controller.archivist_panel.visible:
		push_error("Capture intro impossible : panneau Archiviste non ouvert")
		get_tree().quit(1)
		return
	controller.archivist_panel.get_node("%RunButton").pressed.emit()
	for _frame in range(6):
		await get_tree().process_frame
	if opened_cinematic.is_empty():
		push_error("Capture intro impossible : cinematique non ouverte depuis le hub")
		get_tree().quit(1)
		return
	var cinematic := opened_cinematic[0]
	cinematic.synchronize_to_time(42.0)
	cinematic.black_fade.color.a = 0.0
	for _frame in range(4):
		await get_tree().process_frame
	if not _save_viewport(OUTPUT):
		get_tree().quit(1)
		return
	print("START_HUB_INTRO_CAPTURE=%s" % ProjectSettings.globalize_path(OUTPUT))
	get_tree().quit(0)


func _save_viewport(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return false
	return image.save_png(absolute) == OK
