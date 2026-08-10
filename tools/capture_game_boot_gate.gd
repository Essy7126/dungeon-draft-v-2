extends Node

const TITLE_SCENE: PackedScene = preload("res://ui/TitreEcran.tscn")
const TITLE_PATH := "res://ui/TitreEcran.tscn"
const HUB_PATH := "res://hub/StartHub.tscn"
const OUTPUT_PATH := "res://artifacts/game_boot_recovery/start_hub_gate.png"


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	get_window().size = Vector2i(1200, 896)
	var title := TITLE_SCENE.instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	for _frame in range(4):
		await get_tree().process_frame
	if get_tree().current_scene == null \
		or get_tree().current_scene.scene_file_path != TITLE_PATH:
		_fail("la scene principale n'est pas l'ecran-titre attendu")
		return

	var intro: AnimationPlayer = title.get_node("AnimationPlayer")
	var intro_animation := intro.get_animation(&"intro")
	intro.seek(intro_animation.length, true)
	title.get_node("UI/Boutons/BoutonNouvellePartie").pressed.emit()
	for _frame in range(120):
		await get_tree().process_frame
		if get_tree().current_scene != null \
			and get_tree().current_scene.scene_file_path == HUB_PATH:
			break
	if get_tree().current_scene == null \
		or get_tree().current_scene.scene_file_path != HUB_PATH:
		_fail("le bouton Nouvelle partie n'a pas ouvert le Start Hub")
		return

	for _frame in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(output_absolute.get_base_dir())
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("framebuffer vide")
		return
	var error := image.save_png(output_absolute)
	if error != OK:
		_fail("capture impossible: %s" % error_string(error))
		return
	print("GAME_BOOT_MAIN_SCENE=%s" % TITLE_PATH)
	print("GAME_BOOT_CURRENT_SCENE=%s" % get_tree().current_scene.scene_file_path)
	print("GAME_BOOT_CAPTURE=%s" % output_absolute)
	print("GAME_BOOT_RECOVERED")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("GAME_BOOT_GATE: %s" % message)
	get_tree().quit(1)
