extends Node

const START_HUB_PATH := "res://hub/StartHub.tscn"
const TALK_CAPTURE := (
	"res://artifacts/start_hub/corrections/09_menu_to_hub_archivist_talk.png"
)


func start(title: Node) -> void:
	GameManager.run_active = true
	await get_tree().process_frame
	title.get_node("UI/Boutons/BoutonNouvellePartie").pressed.emit()
	for _frame in range(30):
		await get_tree().process_frame
		if get_tree().current_scene != null \
			and get_tree().current_scene.scene_file_path == START_HUB_PATH:
			break
	var passed := get_tree().current_scene != null \
		and get_tree().current_scene.scene_file_path == START_HUB_PATH \
		and not GameManager.run_active
	if not passed:
		push_error("MENU_START_HUB_FLOW_VERIFY: Nouvelle partie n'ouvre pas un hub sans run active.")
		get_tree().quit(1)
		return

	var hub := get_tree().current_scene
	var controller: StartHubController = hub.get_node("HubController")
	if controller.is_debug_enabled() \
		or hub.get_node("WorldRoot/GridOverlay").visible \
		or hub.get_node("HubUI/DebugPanel").visible:
		push_error("MENU_START_HUB_FLOW_VERIFY: le debug est visible apres Nouvelle partie.")
		get_tree().quit(1)
		return
	controller.movement.movement_speed = 2400.0
	var body_world := controller.archivist.click_collision.to_global(Vector2(0.0, 45.0))
	var body_screen := get_viewport().get_canvas_transform() * body_world
	var motion := InputEventMouseMotion.new()
	motion.position = body_screen
	motion.global_position = body_screen
	Input.parse_input_event(motion)
	await get_tree().physics_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = body_screen
	click.global_position = body_screen
	click.pressed = true
	Input.parse_input_event(click)
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	for _frame in range(160):
		await get_tree().process_frame
		if controller.archivist_panel.visible:
			break
	if not controller.archivist_panel.visible:
		push_error("MENU_START_HUB_FLOW_VERIFY: le clic visible Archiviste n'ouvre pas le panneau.")
		get_tree().quit(1)
		return
	controller.archivist_panel.get_node("%TalkButton").pressed.emit()
	await get_tree().process_frame
	if not controller.archivist_panel.is_dialogue_open():
		push_error("MENU_START_HUB_FLOW_VERIFY: Parler n'ouvre pas le dialogue.")
		get_tree().quit(1)
		return
	if not DisplayServer.get_name().contains("headless"):
		await RenderingServer.frame_post_draw
		var absolute := ProjectSettings.globalize_path(TALK_CAPTURE)
		DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
		var image := get_viewport().get_texture().get_image()
		if image == null or image.is_empty() or image.save_png(absolute) != OK:
			push_error("MENU_START_HUB_FLOW_VERIFY: capture visible Parler impossible.")
			get_tree().quit(1)
			return
		print("MENU_START_HUB_TALK_CAPTURE=%s" % absolute)
	print("MENU_START_HUB_FLOW_VERIFY: PASS")
	get_tree().current_scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
