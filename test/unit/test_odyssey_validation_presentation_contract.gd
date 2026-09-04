extends GutTest

const RUNNER_PATH := "res://tools/odyssey_validation_runner.gd"
const BATTLE_SCRIPT := preload("res://battle/battle.gd")
const ACHILLES_BACKEND := preload(
	"res://characters/achilles/3d/AchillesViewport3DBackend.tscn"
)


func test_runner_keeps_battle_presentation_processing() -> void:
	var runner_script := load(RUNNER_PATH) as Script
	assert_not_null(runner_script)
	assert_true(runner_script.can_instantiate())
	var file := FileAccess.open(RUNNER_PATH, FileAccess.READ)
	assert_not_null(file)
	var source := file.get_as_text()
	file.close()

	assert_false(
		source.contains("battle.process_mode = Node.PROCESS_MODE_DISABLED"),
		"Le runner ne doit pas geler les AnimationPlayer/SubViewport de Battle.",
	)
	assert_true(source.contains("_neutralize_capture_battle_logic(battle)"))
	assert_true(source.contains('"unit_visual_states": visual_states'))
	assert_true(source.contains('"capture_logic_stable": capture_logic_stable'))
	assert_false(source.contains("run_selector.select(2)"))
	assert_true(source.contains("panel.find_run_index(RUN)"))


func test_runner_shutdown_guard_neutralizes_a_started_battle_without_freezing_visuals() -> void:
	var runner_script := load(RUNNER_PATH) as Script
	var runner = runner_script.new()
	var battle = BATTLE_SCRIPT.new()
	var grid_view := Node2D.new()
	grid_view.set_process_input(true)
	grid_view.set_process_unhandled_input(true)
	grid_view.set_process_unhandled_key_input(true)
	battle.add_child(grid_view)
	battle.grid_view = grid_view
	var enemy_turn := EnemyTurnRunner.new()
	battle.add_child(enemy_turn)
	enemy_turn.setup(battle)
	battle.set("_enemy_turn", enemy_turn)
	var turn_queue := TurnQueue.new()
	battle.turn_queue = turn_queue
	turn_queue.turn_started.connect(Callable(battle, "_on_turn_started"))
	turn_queue.round_started.connect(Callable(battle, "_on_round_started"))

	var state := runner.call("_neutralize_capture_battle_logic", battle) as Dictionary

	assert_true(state.get("neutralized", false))
	assert_true(state.get("battle_closing", false))
	assert_true(state.get("enemy_runner_closing", false))
	assert_true(state.get("turn_handler_disconnected", false))
	assert_true(state.get("round_handler_disconnected", false))
	assert_true(state.get("grid_input_disabled", false))
	assert_true(state.get("battle_process_mode_enabled", false))
	assert_ne(battle.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(grid_view.is_processing_unhandled_input())
	battle.free()
	runner.free()


func test_achilles_backend_has_subtle_fill_and_rim_lights() -> void:
	var backend := ACHILLES_BACKEND.instantiate()
	add_child_autofree(backend)
	var render_world := backend.get_node("AchillesSubViewport/RenderWorld")
	var key := render_world.get_node("DirectionalLight3D") as DirectionalLight3D
	var fill := render_world.get_node("FillLight") as OmniLight3D
	var rim := render_world.get_node("RimLight") as DirectionalLight3D

	assert_not_null(key)
	assert_not_null(fill)
	assert_not_null(rim)
	assert_gt(fill.light_energy, 0.0)
	assert_lt(fill.light_energy, 2.0)
	assert_gt(rim.light_energy, 0.0)
	assert_lt(rim.light_energy, key.light_energy)
	assert_false(fill.shadow_enabled)
	assert_false(rim.shadow_enabled)
