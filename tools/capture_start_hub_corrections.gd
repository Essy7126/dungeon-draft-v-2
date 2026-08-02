extends Node

const OUTPUT_DIR := "res://artifacts/start_hub/corrections"

@onready var hub: Node = $StartHub


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	_capture.call_deferred()


func _capture() -> void:
	for _frame in range(30):
		await get_tree().process_frame
	var controller: StartHubController = hub.get_node("HubController")
	var player: ElfIsoUnitView = controller.player
	var archivist: HubArchivist = controller.archivist
	if OS.get_cmdline_user_args().has("--before-only"):
		player.render_display_scale = 0.22
		archivist.render_sprite.scale = Vector2.ONE * 0.31
		archivist._realign_to_ground()
		await _settle(30)
		if await _save("02_size_before_elf_022_archivist_031.png"):
			print("START_HUB_BEFORE_SIZE_CAPTURE=PASS")
			get_tree().quit(0)
		return
	if controller.is_debug_enabled() \
		or hub.get_node("WorldRoot/GridOverlay").visible \
		or hub.get_node("HubUI/DebugPanel").visible:
		_fail("le debug est visible dans l'etat normal")
		return
	if not await _save("01_normal_no_debug.png"):
		return

	player.render_display_scale = 0.22
	archivist.render_sprite.scale = Vector2.ONE * 0.31
	archivist._realign_to_ground()
	await _settle(30)
	if not await _save("02_size_before_elf_022_archivist_031.png"):
		return
	player.render_display_scale = 0.275
	archivist.render_sprite.scale = Vector2.ONE * 0.37
	archivist._realign_to_ground()
	await _settle(30)
	if not await _save("03_size_after_elf_0275_archivist_037.png"):
		return
	if player.get_character_visual().get_current_animation() != &"Elf_Idle":
		_fail("l'Elfe n'est pas en idle avant la capture")
		return
	if not await _save("04_elf_idle.png"):
		return

	controller.movement.movement_speed = 50.0
	if not controller.request_ground_move(Vector2i(10, 10)):
		_fail("le chemin diagonal de capture est refuse")
		return
	await _settle(30)
	if player.get_character_visual().get_current_animation() != &"Elf_Walk":
		_fail("l'Elfe ne marche pas pendant le deplacement diagonal")
		return
	if not await _save("05_elf_diagonal_walk.png"):
		return
	controller.movement.movement_speed = 1200.0
	if not await _wait_for_movement(controller, 120):
		return

	archivist.click_area.mouse_entered.emit()
	await _settle(3)
	if not await _save("06_archivist_hover.png"):
		return
	archivist.click_area.mouse_exited.emit()
	var body_point := archivist.click_collision.to_global(Vector2(0.0, 45.0))
	if not controller.request_primary_click_at_world(body_point):
		_fail("le clic proxy Archiviste est refuse")
		return
	if not await _wait_for_movement(controller, 120):
		return
	await _settle(3)
	if not controller.archivist_panel.visible:
		_fail("le panneau Archiviste ne s'est pas ouvert")
		return
	if not await _save("07_archivist_panel_after_click.png"):
		return

	controller.archivist_panel.get_node("%LeaveButton").pressed.emit()
	await _settle(2)
	var f1 := InputEventKey.new()
	f1.keycode = KEY_F1
	f1.pressed = true
	controller._unhandled_input(f1)
	await _settle(3)
	if not controller.is_debug_enabled():
		_fail("F1 n'a pas active le debug")
		return
	if not await _save("08_debug_f1.png"):
		return

	print("START_HUB_CORRECTION_CAPTURES=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	get_tree().quit(0)


func _wait_for_movement(controller: StartHubController, max_frames: int) -> bool:
	for _frame in range(max_frames):
		await get_tree().process_frame
		if not controller.movement.is_moving():
			return true
	_fail("le mouvement n'a pas termine")
	return false


func _settle(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().process_frame


func _save(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("framebuffer vide pour %s" % file_name)
		return false
	var error := image.save_png(absolute)
	if error != OK:
		_fail("capture impossible %s: %s" % [file_name, error_string(error)])
		return false
	print("START_HUB_CAPTURE=%s" % absolute)
	return true


func _fail(message: String) -> void:
	push_error("START_HUB_CAPTURE: %s" % message)
	get_tree().quit(1)
