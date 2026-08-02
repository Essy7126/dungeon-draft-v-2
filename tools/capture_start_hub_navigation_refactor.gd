extends Node

const OUTPUT_DIR := "res://artifacts/start_hub/navigation_refactor"
const LEGACY_GRID_REFERENCE := (
	"res://artifacts/start_hub/corrections/08_debug_f1.png"
)

@onready var hub: Node = $StartHub


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	_capture.call_deferred()


func _capture() -> void:
	await _settle(40)
	var controller: StartHubController = hub.get_node("HubController")
	var region: HubNavigationRegion2D = hub.get_node(
		"WorldRoot/NavigationRegion2D"
	)
	var grid_overlay: HubGridOverlay = hub.get_node("WorldRoot/GridOverlay")
	if not FileAccess.file_exists(LEGACY_GRID_REFERENCE):
		_fail("capture historique avec grille introuvable")
		return
	if controller.player.render_display_scale != 0.47 \
		or controller.archivist.render_display_scale != 0.60:
		_fail("echelles finales inattendues")
		return
	if not await _save("01_scaled_elf_047_archivist_060.png"):
		return

	controller.movement.setup(
		controller.player, region, Vector2(300.0, 1260.0)
	)
	controller.movement.movement_speed = 70.0
	region.set_debug_visible(true)
	grid_overlay.visible = false
	grid_overlay.set_debug_visible(false)
	if not controller.request_ground_move(Vector2(940.0, 820.0)):
		_fail("trajet continu de capture refuse")
		return
	await _settle(18)
	if not controller.movement.is_moving():
		_fail("le joueur doit marcher pendant la capture du trajet")
		return
	if not await _save("02_continuous_path_around_table.png"):
		return
	controller.movement.cancel()
	region.set_debug_visible(false)

	controller.movement.setup(
		controller.player, region, Vector2(1024.0, 1536.0)
	)
	controller.movement.movement_speed = 1200.0
	if controller.request_interaction(controller.archivist) == null:
		_fail("interaction Archiviste refusee")
		return
	if not await _wait_for_movement(controller, 120):
		return
	if not controller.archivist_panel.visible:
		_fail("panneau Archiviste non ouvert")
		return
	if not await _save("03_archivist_interaction.png"):
		return

	controller.archivist_panel.get_node("%LeaveButton").pressed.emit()
	await _settle(5)
	if controller.is_debug_enabled() or grid_overlay.visible \
		or region.debug_visible or hub.get_node("HubUI/DebugPanel").visible:
		_fail("debug visible dans la scene normale")
		return
	if not await _save("04_normal_no_debug.png"):
		return

	print("START_HUB_LEGACY_GRID_REFERENCE=%s" % ProjectSettings.globalize_path(
		LEGACY_GRID_REFERENCE
	))
	print("START_HUB_NAVIGATION_CAPTURES=%s" % ProjectSettings.globalize_path(
		OUTPUT_DIR
	))
	get_tree().quit(0)


func _wait_for_movement(
		controller: StartHubController,
		max_frames: int
	) -> bool:
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
	print("START_HUB_NAV_CAPTURE=%s" % absolute)
	return true


func _fail(message: String) -> void:
	push_error("START_HUB_NAV_CAPTURE: %s" % message)
	get_tree().quit(1)
