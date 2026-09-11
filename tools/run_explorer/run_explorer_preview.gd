extends Node
const Catalog = preload("res://tools/run_explorer/route_explorer_catalog.gd")
const Fixture = preload("res://tools/run_explorer/route_explorer_fixture.gd")
var output := ""
var target := ""
var seed_value := 2401
var mode := "play"
var capture_requested := false
var toolbar: CanvasLayer
var closing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--explorer-output="):
			output = arg.trim_prefix("--explorer-output=")
		if arg.begins_with("--explorer-node="):
			target = arg.trim_prefix("--explorer-node=")
		if arg.begins_with("--explorer-seed="):
			seed_value = int(arg.trim_prefix("--explorer-seed="))
		if arg.begins_with("--explorer-mode="):
			mode = arg.trim_prefix("--explorer-mode=")
		if arg == "--explorer-capture":
			capture_requested = true
	_start.call_deferred()


func _start() -> void:
	var absolute := ProjectSettings.globalize_path(output).simplify_path().replace("\\", "/")
	var allowed := ProjectSettings.globalize_path("res://artifacts/dev/").replace("\\", "/")
	var userdata := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if (
		not output.begins_with("res://artifacts/dev/")
		or not absolute.begins_with(allowed)
		or not userdata.begins_with(absolute.to_lower() + "/userdata/") or mode
		not in ["play", "art", "aftermath"]
	):
		_fail("Cet essai exige le lanceur isolé de l'explorateur.")
		return
	if GameManager.run_active:
		_fail("Une partie est déjà active dans ce processus.")
		return
	GameManager.expedition_save_path = output.path_join("checkpoint.json")
	var node := Catalog.entry() if target == "entry" else { }
	for candidate in ExpeditionRouteCatalog.create_nodes(seed_value):
		if str(candidate.id) == target:
			node = candidate
	if node.is_empty():
		_fail("Destination absente du catalogue pour cette graine.")
		return
	if mode == "aftermath" and target != "d01_0":
		_fail("L'exploration après combat est disponible au Seuil uniquement.")
		return
	get_window().title = "Essai Catabase — " + str(node.title)
	# Retain this tool as a root sibling while production scenes change.
	get_tree().current_scene = null
	if target == "entry":
		var entry_run := load("res://data/runs/odyssey.tres").duplicate(false) as RunData
		entry_run.default_seed = seed_value
		entry_run.randomize_seed_each_run = false
		if (
			not GameManager.configure_next_run(entry_run, 0)
			or not GameManager.continue_after_intro()
		):
			_fail("L'entrée des Enfers n'a pas pu être préparée.")
			return
	elif mode == "art":
		if not ExpeditionRouteCatalog.is_combat(str(node.kind)):
			_fail("L'examen sans combat nécessite une arène.")
			return
		var run := RunData.new()
		run.rooms = [ExpeditionRunFactory.make_room(node, seed_value)]
		run.content_profile = load("res://data/runs/profiles/odyssey_content_profile.tres")
		run.randomize_seed_each_run = false
		run.default_seed = seed_value
		var options := ArenaDirectTestConfiguration.resolve(&"view")
		options.camera_mode = "PRODUCTION"
		if not GameManager.start_direct_encounter_test(run, [], options):
			_fail("L'aperçu de cette arène n'a pas démarré.")
			return
	else:
		var snapshot := Fixture.prepare(
			self,
			seed_value,
			target,
			output.path_join("preparation.json"),
		)
		if snapshot.is_empty() or not GameManager.restore_expedition_snapshot(snapshot):
			_fail("La préparation du chemin de laboratoire a échoué.")
			return
		if mode == "aftermath":
			GameManager.begin_combat_report()
			GameManager.on_battle_won()
		elif GameManager.expedition.route.phase == "combat":
			GameManager.start_next_battle()
		else:
			GameManager._request_scene_change(GameManager.get_expedition_destination_scene())
	_add_toolbar()
	_write_report(
		{
			"started": true,
			"node": node,
			"mode": mode,
			"seed": seed_value,
			"isolated_userdata": userdata,
		}
	)
	if capture_requested:
		await _capture_and_exit(node)


func _add_toolbar() -> void:
	toolbar = CanvasLayer.new()
	toolbar.layer = 120
	add_child(toolbar)
	var bar := HBoxContainer.new()
	bar.position = Vector2(8, 8)
	toolbar.add_child(bar)
	var exit_button := Button.new()
	exit_button.text = "Fermer l'essai · F8"
	exit_button.pressed.connect(_close)
	bar.add_child(exit_button)
	var capture := Button.new()
	capture.text = "Capturer · F9"
	capture.pressed.connect(_capture)
	bar.add_child(capture)
	var label := Label.new()
	label.text = "  Laboratoire · " + target
	bar.add_child(label)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			get_viewport().set_input_as_handled()
			_close()
		elif event.keycode == KEY_F9:
			get_viewport().set_input_as_handled()
			_capture()


func _capture() -> void:
	toolbar.hide()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := output.path_join("capture-%d.png" % Time.get_ticks_usec())
	var error := image.save_png(ProjectSettings.globalize_path(path))
	toolbar.show()
	if error != OK:
		push_error("Capture impossible : " + path)


func _capture_and_exit(node: Dictionary) -> void:
	var ready := false
	for frame in 900:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene == null:
			continue
		if mode != "aftermath" and ExpeditionRouteCatalog.is_combat(str(node.kind)):
			ready = bool(scene.get("registered_terrain_ready"))
		elif scene.has_method("is_ready_for_play"):
			ready = scene.is_ready_for_play()
		elif scene is Node2D:
			ready = scene.get("_ready_for_play") == true
		else:
			ready = frame > 10
		if ready:
			break
	if not ready:
		_fail("Délai de chargement de la scène dépassé.")
		return
	await get_tree().create_timer(1.0).timeout
	await _capture()
	var scene := get_tree().current_scene
	_write_report(
		{
			"started": true,
			"ready": true,
			"node": node,
			"mode": mode,
			"scene": scene.scene_file_path,
			"resolution": [get_window().size.x, get_window().size.y],
			"current_node": (
				GameManager.expedition.route.current_node_id
				if GameManager.expedition != null
				else ""
			),
			"isolated_userdata": OS.get_user_data_dir(),
		}
	)
	_close()


func _write_report(value: Dictionary) -> void:
	var file := FileAccess.open(output.path_join("preview.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value, "\t"))


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(2)


func _close() -> void:
	if closing:
		return
	closing = true
	get_tree().paused = false
	var scene := get_tree().current_scene
	if is_instance_valid(scene):
		scene.queue_free()
	await get_tree().process_frame
	GameManager.cleanup_run_state()
	await get_tree().process_frame
	get_tree().quit()
