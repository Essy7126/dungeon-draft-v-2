extends Node

# Standalone visual review of any registered ArenaDefinition, using production
# assembly and the current Catabase hero profile. No campaign resource is saved.
var _capture_path := ""
var _room_path := ""

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--room="): _room_path=arg.trim_prefix("--room=")
		if arg.begins_with("--capture="): _capture_path=arg.trim_prefix("--capture=")
	_launch.call_deferred()

func _launch() -> void:
	var source := load(_room_path) as ArenaDefinition
	if source == null:
		push_error("MapPreview needs --room=res://... ArenaDefinition")
		get_tree().quit(2)
		return
	var arena := source.duplicate(true) as ArenaDefinition
	if not ArenaRuntimeBridge.sync_runtime_resources(arena):
		get_tree().quit(3)
		return
	var run := RunData.new()
	run.rooms=[arena]
	run.content_profile=load("res://data/runs/profiles/odyssey_content_profile.tres") as RunContentProfile
	run.randomize_seed_each_run=false
	run.default_seed=2401
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run,false)
	var options := ArenaDirectTestConfiguration.resolve(&"real_encounter")
	options["camera_mode"]="PRODUCTION"
	get_tree().current_scene=null
	if not resolution.is_valid() or not GameManager.start_direct_encounter_test(run,resolution.heroes,options):
		get_tree().quit(4)
		return
	if _capture_path.is_empty():
		queue_free()
		return
	var battle: Node=null
	for _frame in range(1200):
		await get_tree().process_frame
		var candidate := get_tree().current_scene
		if candidate != null and bool(candidate.get("registered_terrain_ready")):
			battle=candidate
			break
	if battle==null:
		get_tree().quit(5)
		return
	var deployment := battle.get("_deployment") as DeploymentController
	if deployment!=null and deployment.is_active():
		for cell: Vector2i in arena.hero_spawn_zone:
			if not deployment.is_active(): break
			deployment.on_cell_clicked(cell)
	await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	var destination := ProjectSettings.globalize_path(_capture_path)
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var saved := shot.save_png(destination)
	print("REGISTERED_MAP_PREVIEW "+JSON.stringify({"ok":saved==OK,"room":_room_path,"capture":destination}))
	get_tree().quit(0 if saved==OK else 6)
