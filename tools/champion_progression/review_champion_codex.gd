extends SceneTree

var _state
var _codex
const OUTPUT := "res://artifacts/achilles_theorycraft_integration"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var resolver = load("res://core/run_content/run_hero_resolver.gd")
	var unit_script = load("res://units/unit.gd")
	var state_script = load("res://characters/progression/character_run_state.gd")
	var codex_script = load("res://ui/progression/champion/champion_codex.gd")
	var run = load("res://data/runs/odyssey.tres")
	var resolution = resolver.resolve_runtime_hero_data(run, false)
	if not resolution.is_valid():
		push_error(str(resolution.errors))
		quit(2)
		return
	var data = resolution.heroes[0]
	_state = state_script.new()
	if not _state.initialize(unit_script.from_data(data), data):
		push_error("REVIEW_CHAMPION_INIT_FAILED")
		quit(2)
		return
	_state.begin_encounter()
	_state.award_encounter_xp(&"visual_fixture_only", 1700, true)
	for attribute in [&"vitality", &"vitality", &"power", &"power", &"resolve", &"wisdom", &"wisdom"]:
		_state.spend_champion_attribute(attribute)
	_state.purchase_mastery_node(&"achilles_wrath_focused_fury")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	_codex = codex_script.new()
	_codex.configure(_state, false)
	root.add_child(_codex)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for dimensions in [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080)]:
		root.size = dimensions
		DisplayServer.window_set_size(dimensions)
		_codex.select_section(&"achilles_wrath_of_peleus")
		_codex.inspect_node(&"achilles_wrath_opening_slash")
		await _capture(dimensions, "maitrises")
		_codex.select_section(&"attributes")
		await _capture(dimensions, "caracteristiques")
		_codex._inspect_spell(data.spells[3])
		await _capture(dimensions, "technique")
	# A legal capstone fixture verifies the effective multi-target values too.
	for mastery_id in [&"achilles_wrath_opening_slash", &"achilles_wrath_execution", &"achilles_wrath_break_formation", &"achilles_wrath_scourge_of_troy"]:
		if not _state.purchase_mastery_node(mastery_id).purchased:
			push_error("REVIEW_MASTERY_PURCHASE_FAILED: %s" % mastery_id)
			quit(2)
			return
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	_codex.refresh()
	_codex._inspect_spell(data.spells[0])
	await _capture(root.size, "fleau")
	_codex.select_section(&"attributes")
	await _capture(root.size, "attributs_fleau")
	_codex.queue_free()
	await process_frame
	_state.dispose()
	_state = null
	_codex = null
	for _frame in 3:
		await process_frame
	print("CHAMPION_CODEX_REVIEW_OK")
	quit(0)

func _capture(dimensions: Vector2i, section: String) -> void:
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	var file_name := "champion_%dx%d_%s.png" % [dimensions.x, dimensions.y, section]
	var error := capture.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(file_name)))
	print("CHAMPION_CODEX_CAPTURE %s %s" % [file_name, error])
