extends Node

const REQUEST_PATH := "user://arena_studio/test_request.json"
const DirectTestConfiguration = preload(
	"res://addons/dungeon_draft_arena_studio/services/arena_direct_test_configuration.gd"
)
const DirectTestProbe = preload(
	"res://addons/dungeon_draft_arena_studio/test/arena_direct_test_probe.gd"
)
const DEFAULT_HEROES := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]


func _ready() -> void:
	var request := _load_request()
	var arena_path := str(request.get("arena_path", ""))
	var arena := ResourceLoader.load(
		arena_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ArenaDefinition if ResourceLoader.exists(arena_path) else null
	if arena == null:
		push_error("Arena Studio : la ressource de test est introuvable.")
		get_tree().quit(1)
		return
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var report := ArenaValidator.validate(arena, false)
	if not report.is_valid():
		for message in report.messages:
			if message.severity == ArenaValidationMessage.Severity.ERROR:
				push_error("Arena Studio [%s] : %s" % [message.code, message.message])
		push_error("Arena Studio : la map de test n'est pas valide.")
		get_tree().quit(2)
		return

	var provenance := _provenance(request, arena_path, arena)
	if int(request.get("contract_version", 0)) >= 2 \
			and not bool(provenance.get("fingerprints_identical", false)):
		_write_launch_result(request, false, arena, provenance)
		push_error("Arena Studio : les fingerprints working/temp/runtime divergent.")
		_cleanup_temporary_request(request)
		get_tree().quit(5)
		return
	if bool(provenance.get("produced_bundle_loaded", false)):
		_write_launch_result(request, false, arena, provenance)
		push_error(
			"Arena Studio : le runner refuse toute dependance au bundle produced gele."
		)
		_cleanup_temporary_request(request)
		get_tree().quit(6)
		return

	var run_path := str(request.get("run_path", ""))
	var run := ResourceLoader.load(
		run_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as RunData if not run_path.is_empty() and ResourceLoader.exists(run_path) \
	else RunData.new()
	var configuration := StringName(request.get("configuration", "movement"))
	var test_options := DirectTestConfiguration.resolve(configuration)
	get_tree().set_meta("arena_studio_test_configuration", configuration)
	get_tree().set_meta(DirectTestConfiguration.TREE_META, test_options)
	run.run_name = "Test Arena Studio [%s] — %s" % [
		configuration, arena.display_name,
	]
	run.rooms = [arena]
	if run.default_seed == 0:
		run.default_seed = 1337

	var heroes: Array = []
	if bool(request.get("exact_run_content", false)):
		var resolution := RunHeroResolver.resolve_runtime_hero_data(run, false)
		if not resolution.is_valid():
			_write_launch_result(request, false, arena, provenance)
			for error in resolution.errors:
				push_error("Arena Studio : resolution run-aware : %s" % error)
			_cleanup_temporary_request(request)
			get_tree().quit(7)
			return
		heroes.assign(resolution.heroes)
		provenance["hero_source"] = "RunHeroResolver"
	else:
		if int(request.get("contract_version", 0)) >= 2 \
				and not bool(request.get("fixture_fallback", false)):
			_write_launch_result(request, false, arena, provenance)
			push_error("Arena Studio : fallback de heros non explicitement etiquete.")
			_cleanup_temporary_request(request)
			get_tree().quit(8)
			return
		heroes = request.get("heroes", DEFAULT_HEROES)
		provenance["hero_source"] = "explicit_fixture"
	if not bool(test_options.get("spawn_heroes", false)):
		heroes = []
	if heroes.any(func(value):
		return value is String and not ResourceLoader.exists(str(value))
	):
		heroes = DEFAULT_HEROES

	print("ARENA_STUDIO_DIRECT_TEST configuration=%s applied=%s arena=%s" % [
		configuration, test_options.get("applied_mode", "unknown"), arena.arena_id,
	])
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager == null:
		push_error("Arena Studio : l'autoload GameManager est introuvable.")
		get_tree().quit(3)
		return
	var probe: ArenaDirectTestProbe = null
	if bool(request.get("probe_runtime", false)):
		probe = DirectTestProbe.new()
		probe.configure(request, provenance)
		get_tree().root.add_child(probe)
	var started: bool = game_manager.start_direct_encounter_test(
		run, heroes, test_options
	)
	_write_launch_result(request, started, arena, provenance)
	if not started:
		if probe != null:
			probe.queue_free()
		push_error("Arena Studio : le lancement direct a ete refuse par GameManager.")
		_cleanup_temporary_request(request)
		get_tree().quit(4)
		return
	if probe == null:
		_cleanup_temporary_request(request)


func _load_request() -> Dictionary:
	if not FileAccess.file_exists(REQUEST_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REQUEST_PATH))
	return parsed if parsed is Dictionary else {}


func _write_launch_result(
		request: Dictionary,
		started: bool,
		arena: ArenaDefinition,
		provenance: Dictionary = {}
	) -> void:
	var result_path := str(request.get("result_path", ""))
	if result_path.is_empty():
		return
	var absolute := ProjectSettings.globalize_path(result_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(result_path, FileAccess.WRITE)
	if file != null:
		var payload := provenance.duplicate(true)
		payload.merge({
			"ok": started,
			"arena_id": str(arena.arena_id),
			"configuration": str(request.get("configuration", "")),
			"applied_mode": str(get_tree().get_meta(
				DirectTestConfiguration.TREE_META, {}
			).get("applied_mode", "")),
			"working_copy": true,
			"runtime_scene_inspected": false,
		}, true)
		file.store_string(JSON.stringify(payload, "  "))
		file.close()


func _cleanup_temporary_request(request: Dictionary) -> void:
	if not bool(request.get("cleanup_on_load", false)):
		return
	if not str(request.get("context_root", "")).is_empty():
		ArenaDirectTestService.cleanup_context(request)
		return
	var arena_path := str(request.get("arena_path", ""))
	if arena_path.begins_with("user://dungeon_draft_studio/arena_studio/tests/"):
		var absolute := ProjectSettings.globalize_path(arena_path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
	var request_absolute := ProjectSettings.globalize_path(REQUEST_PATH)
	if FileAccess.file_exists(request_absolute):
		DirAccess.remove_absolute(request_absolute)


func _provenance(
		request: Dictionary,
		arena_path: String,
		arena: ArenaDefinition
	) -> Dictionary:
	var temporary_fingerprint := ArenaSnapshotService.arena_fingerprint(arena)
	var runtime_state := ArenaRuntimeProjectionService.build(arena)
	var runtime_fingerprint := (
		ArenaSnapshotService.arena_fingerprint(runtime_state.arena_projection)
		if runtime_state != null and runtime_state.arena_projection != null else ""
	)
	var working_fingerprint := str(request.get(
		"working_fingerprint", temporary_fingerprint
	))
	var requested_temporary := str(request.get(
		"temporary_fingerprint", temporary_fingerprint
	))
	var produced_loaded := _depends_on_produced_bundle(arena_path)
	return {
		"studio_product_version": str(request.get(
			"studio_product_version", StudioVersion.PRODUCT_VERSION
		)),
		"generated_by": str(request.get("generated_by", StudioVersion.GENERATED_BY)),
		"arena_path_loaded": arena_path,
		"working_fingerprint": working_fingerprint,
		"temporary_fingerprint": temporary_fingerprint,
		"requested_temporary_fingerprint": requested_temporary,
		"runtime_fingerprint": runtime_fingerprint,
		"fingerprints_identical": (
			working_fingerprint == temporary_fingerprint
			and temporary_fingerprint == requested_temporary
			and working_fingerprint == runtime_fingerprint
		),
		"produced_bundle_loaded": produced_loaded,
		"camera_mode": str(request.get("camera_mode", "")),
		"contract_version": int(request.get("contract_version", 0)),
		"generated_at": str(request.get("created_at", "")),
	}


func _depends_on_produced_bundle(arena_path: String) -> bool:
	const PRODUCED_PREFIX := "res://data/arenas/produced/"
	if arena_path.begins_with(PRODUCED_PREFIX):
		return true
	for dependency in ResourceLoader.get_dependencies(arena_path):
		if str(dependency).contains(PRODUCED_PREFIX):
			return true
	return false
