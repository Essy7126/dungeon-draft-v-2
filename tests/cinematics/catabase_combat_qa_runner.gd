extends Node

const CATABASE_RUN: RunData = preload("res://data/runs/odyssey.tres")


func _ready() -> void:
	var output_path := _argument_value("--output=")
	if output_path.is_empty():
		push_error("Catabase combat QA : --output est obligatoire.")
		get_tree().quit(2)
		return
	var requested_size := _parse_resolution(_argument_value("--resolution="))
	if requested_size == Vector2i.ZERO:
		push_error("Catabase combat QA : --resolution=WIDTHxHEIGHT est obligatoire.")
		get_tree().quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Catabase combat QA : une sortie GPU est requise pour la capture.")
		get_tree().quit(5)
		return
	var room_index := int(_argument_value("--room-index="))
	if room_index < 0 or room_index >= CATABASE_RUN.rooms.size():
		push_error("Catabase combat QA : --room-index doit etre compris entre 0 et 2.")
		get_tree().quit(2)
		return
	var output_directory := output_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(output_directory)
	get_window().size = requested_size
	# Ce runner reste attache a root pendant que le pipeline GameManager remplace
	# la scene courante par la vraie salle peinte.
	get_tree().current_scene = null
	GameManager.cleanup_run_state()
	if not GameManager.configure_next_run(CATABASE_RUN, 2):
		push_error("Catabase combat QA : configuration du run refusee.")
		get_tree().quit(3)
		return
	if not GameManager.start_configured_run():
		push_error("Catabase combat QA : demarrage du run refuse.")
		get_tree().quit(3)
		return
	# Le run public reste force sur la salle I. Ce contournement est reserve a la
	# capture QA afin de vérifier chaque arène sans simuler les combats précédents.
	GameManager.current_room_index = room_index
	for _frame in range(15):
		await get_tree().process_frame
	GameManager.start_next_battle()
	for _frame in range(45):
		await get_tree().process_frame
	var battle := get_tree().current_scene
	var deployment = battle.get("_deployment") if battle != null else null
	var room := GameManager.rooms[GameManager.current_room_index] as RoomData
	if deployment != null and deployment.is_active():
		deployment.on_cell_clicked(room.hero_spawn_zone[0])
	# Laisser la bannière de tour terminer ses 2 s d'animation afin que la
	# capture vérifie réellement le cadrage, la grille et les silhouettes.
	for _frame in range(150):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Catabase combat QA : capture impossible : %s" % output_path)
		get_tree().quit(4)
		return
	print(
		"CATABASE_COMBAT_QA_CAPTURED room=%s index=%d enemies=%d output=%s"
		% [
			room.room_name,
			GameManager.current_room_index,
			room.enemies.size(),
			output_path,
		]
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
