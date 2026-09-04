extends GutTest

const UNIT_VIEW_SCENE := preload("res://battle/unit_view.tscn")
const BATTLE_SCRIPT := preload("res://battle/battle.gd")
const GRID_VIEW_SCRIPT := preload("res://battle/grid_view.gd")
const PAINTED_BATTLE_SCENE := preload(
	"res://data/rooms/maps/painted_battle.tscn"
)


func test_transient_inspection_is_suppressed_only_on_painted_battles() -> void:
	var legacy_battle = BATTLE_SCRIPT.new()
	assert_true(
		legacy_battle.show_transient_inspection,
		"Les combats historiques conservent leur aperçu au survol.",
	)
	legacy_battle.free()

	var painted_battle = PAINTED_BATTLE_SCENE.instantiate()
	assert_false(
		painted_battle.show_transient_inspection,
		"Le plateau peint doit rester dégagé pendant la lecture des portées.",
	)
	painted_battle.free()


func test_initial_enemy_facing_is_opt_in_only_for_painted_battles() -> void:
	var legacy_battle = BATTLE_SCRIPT.new()
	assert_false(
		legacy_battle.orient_enemies_at_battle_start,
		"Une scène historique doit conserver son facing logique de spawn.",
	)
	legacy_battle.free()

	var painted_battle = PAINTED_BATTLE_SCENE.instantiate()
	assert_true(
		painted_battle.orient_enemies_at_battle_start,
		"Le plateau peint oriente explicitement les ennemis après le déploiement.",
	)
	painted_battle.free()


func test_initial_facing_contract_preserves_legacy_and_only_orients_enemies() -> void:
	var battle = BATTLE_SCRIPT.new()
	battle.grid = GridData.new(5, 1)
	var hero := Unit.new("Achille")
	var enemy := Unit.new("Ennemi")
	enemy.team = 1
	hero.facing_dir = Vector2i.DOWN
	enemy.facing_dir = Vector2i.DOWN
	assert_true(battle.grid.place_unit(hero, Vector2i.ZERO))
	assert_true(battle.grid.place_unit(enemy, Vector2i(3, 0)))
	battle.units = [hero, enemy]
	var hero_view := _FacingViewSpy.new()
	var enemy_view := _FacingViewSpy.new()
	battle.add_child(hero_view)
	battle.add_child(enemy_view)
	battle.set("_unit_views", {
		hero: hero_view,
		enemy: enemy_view,
	})

	battle.call("_orient_enemies_for_battle_start")
	assert_eq(hero.facing_dir, Vector2i.DOWN)
	assert_eq(enemy.facing_dir, Vector2i.DOWN)
	assert_true(hero_view.faced_directions.is_empty())
	assert_true(enemy_view.faced_directions.is_empty())

	battle.orient_enemies_at_battle_start = true
	battle.call("_orient_enemies_for_battle_start")
	assert_eq(
		enemy.facing_dir,
		Vector2i.LEFT,
		"L’ennemi peint fait face au héros dès le début du combat.",
	)
	assert_eq(enemy_view.faced_directions, [Vector2i(-3, 0)])
	assert_eq(
		hero.facing_dir,
		Vector2i.DOWN,
		"Ce contrat visuel ne doit pas réécrire le facing du héros.",
	)
	assert_true(hero_view.faced_directions.is_empty())
	battle.free()


func test_painted_unit_health_is_contextual_and_target_state_is_explicit() -> void:
	var unit := Unit.new("Cible", 1, 40)
	var view = UNIT_VIEW_SCENE.instantiate()
	add_child_autofree(view)
	view.setup(unit, false)
	var profile := BattlePresentationProfile.new()
	profile.outlines_enabled = true
	view.apply_painted_presentation(profile, false, true)

	var hp_bar := view.get("_hp_bar") as ProgressBar
	assert_false(hp_bar.visible, "Les PV pleins ne doivent pas parasiter la peinture.")
	view.set_tactical_emphasis(&"target_valid")
	assert_eq(view.get_tactical_emphasis(), &"target_valid")
	assert_true(hp_bar.visible, "La cible doit immédiatement révéler sa jauge.")
	assert_eq(hp_bar.position, Vector2(-28.0, -72.0))

	view.set_tactical_emphasis(&"")
	assert_false(hp_bar.visible)
	unit.current_hp = 18
	view.call("_update_hp_bar")
	assert_true(hp_bar.visible, "Une unité blessée conserve une information utile.")

	view.apply_painted_presentation(null, false, false)
	assert_eq(hp_bar.size, Vector2(48.0, 6.0))
	assert_eq(hp_bar.position, Vector2(-24.0, -45.0))
	var shield_bar := view.get("_shield_bar") as ProgressBar
	assert_eq(shield_bar.size, Vector2(48.0, 4.0))
	assert_eq(shield_bar.position, Vector2(-24.0, -51.0))
	var status_row := view.get("_status_row") as HBoxContainer
	assert_eq(status_row.position, Vector2(-24.0, -66.0))


func test_spatial_cursor_skips_non_interactable_cells_and_confirms_target() -> void:
	var battle = BATTLE_SCRIPT.new()
	var grid := GridData.new(4, 2)
	grid.set_type(Vector2i(2, 0), GridData.CellType.WALL)
	var grid_view := Node2D.new()
	grid_view.set_script(GRID_VIEW_SCRIPT)
	grid_view.setup(grid)
	battle.grid = grid
	battle.grid_view = grid_view
	battle.add_child(grid_view)
	battle.turn_state = TurnState.new()
	battle.turn_state.current = TurnState.State.TARGET_MELEE
	battle.set("_grid_cursor_cell", Vector2i(1, 0))
	grid_view.set_cursor_cell(Vector2i(1, 0))

	var move_right := InputEventAction.new()
	move_right.action = &"ui_right"
	move_right.pressed = true
	assert_true(battle.call("_handle_grid_navigation_input", move_right))
	assert_eq(
		grid_view.get_cursor_cell(),
		Vector2i(3, 0),
		"Le D-pad saute les trous du plateau sans perdre le focus.",
	)

	var requested: Array[Vector2i] = []
	battle.turn_state.request_attack.connect(
		func(cell: Vector2i) -> void: requested.append(cell)
	)
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	assert_true(battle.call("_handle_grid_navigation_input", accept))
	assert_eq(requested, [Vector2i(3, 0)])
	assert_eq(grid_view.get_selected_cell(), Vector2i(-1, -1))
	battle.free()


func test_pointer_takeover_clears_battle_cursor_without_hover_change() -> void:
	var battle = BATTLE_SCRIPT.new()
	var grid := GridData.new(2, 1)
	var grid_view := Node2D.new()
	grid_view.set_script(GRID_VIEW_SCRIPT)
	grid_view.setup(grid)
	battle.grid = grid
	battle.grid_view = grid_view
	battle.add_child(grid_view)
	grid_view.connect(
		&"spatial_cursor_released",
		Callable(battle, "_on_grid_spatial_cursor_released"),
	)

	var cell := Vector2i.ZERO
	grid_view.update_hover(grid_view.grid_to_world(cell))
	var hovered_before: Vector2i = grid_view.get_hovered_cell()
	battle.set("_grid_cursor_cell", cell)
	grid_view.set_cursor_cell(cell)

	grid_view.call("_release_spatial_cursor_to_pointer")

	assert_eq(grid_view.get_hovered_cell(), hovered_before)
	assert_eq(grid_view.get_cursor_cell(), Vector2i(-1, -1))
	assert_eq(
		battle.get("_grid_cursor_cell"),
		Vector2i(-1, -1),
		"La reprise souris doit aussi effacer le curseur logique de Battle.",
	)
	battle.free()


func test_input_echoes_skip_accept_and_cancel_but_keep_direction_repeat() -> void:
	var battle = BATTLE_SCRIPT.new()
	var grid := GridData.new(3, 1)
	var grid_view := Node2D.new()
	grid_view.set_script(GRID_VIEW_SCRIPT)
	grid_view.setup(grid)
	battle.grid = grid
	battle.grid_view = grid_view
	battle.add_child(grid_view)
	battle.turn_state = TurnState.new()
	battle.turn_state.current = TurnState.State.TARGET_MELEE
	battle.set("_grid_cursor_cell", Vector2i.ZERO)
	grid_view.set_cursor_cell(Vector2i.ZERO)

	var requested: Array[Vector2i] = []
	battle.turn_state.request_attack.connect(
		func(cell: Vector2i) -> void: requested.append(cell)
	)
	var accept_echo := _pressed_echo_key(KEY_ENTER)
	assert_true(accept_echo.is_action_pressed(&"ui_accept", true))
	assert_true(battle.call("_handle_grid_navigation_input", accept_echo))
	assert_true(requested.is_empty(), "Un écho Entrée ne doit jamais confirmer.")

	var right_echo := _pressed_echo_key(KEY_RIGHT)
	assert_true(right_echo.is_action_pressed(&"ui_right", true))
	assert_true(battle.call("_handle_grid_navigation_input", right_echo))
	assert_eq(
		grid_view.get_cursor_cell(),
		Vector2i(1, 0),
		"La répétition reste active pour parcourir le plateau au D-pad.",
	)

	var deployment_probe := _DeploymentUndoProbe.new()
	battle.add_child(deployment_probe)
	battle.set("_deployment", deployment_probe)
	var cancel_echo := _pressed_echo_key(KEY_ESCAPE)
	assert_true(cancel_echo.is_action_pressed(&"ui_cancel", true))
	battle.call("_unhandled_input", cancel_echo)
	assert_eq(
		deployment_probe.undo_calls,
		0,
		"Un écho Échap ne doit pas annuler plusieurs placements.",
	)
	battle.free()


func test_deployment_exposes_only_free_interactable_cursor_cells() -> void:
	var battle = _DeploymentBattleStub.new()
	add_child_autofree(battle)
	var occupied := Unit.new("Occupant", 1, 10)
	assert_true(battle.grid.place_unit(occupied, Vector2i.ZERO))
	var controller := DeploymentController.new()
	battle.add_child(controller)
	controller.setup(battle)
	controller.set("_deploying", true)
	controller.set("_deploy_zone", [
		Vector2i.ZERO,
		Vector2i(1, 0),
		Vector2i(2, 0),
	])
	battle.grid.set_type(Vector2i(2, 0), GridData.CellType.WALL)

	assert_eq(controller.get_available_cells(), [Vector2i(1, 0)])
	assert_eq(controller.get_preferred_cursor_cell(), Vector2i(1, 0))


func test_deployment_undo_returns_gui_and_spatial_focus() -> void:
	var battle = BATTLE_SCRIPT.new()
	var grid := GridData.new(2, 1)
	var grid_view := Node2D.new()
	grid_view.set_script(GRID_VIEW_SCRIPT)
	grid_view.setup(grid)
	battle.grid = grid
	battle.grid_view = grid_view
	battle.add_child(grid_view)

	var hero := Unit.new("Achille", 0, 20)
	assert_true(grid.place_unit(hero, Vector2i.ZERO))
	battle.units.append(hero)
	var controller := DeploymentController.new()
	add_child_autofree(controller)
	controller.setup(battle)
	controller.set("_deploying", true)
	controller.set("_deploy_zone", [Vector2i.ZERO, Vector2i(1, 0)])
	controller.set("_deployed", [{"unit": hero, "cell": Vector2i.ZERO}])
	controller.set("_heroes_to_place", [])
	controller.spatial_focus_requested.connect(
		Callable(battle, "_on_deployment_spatial_focus_requested")
	)

	var undo_button := Button.new()
	add_child_autofree(undo_button)
	undo_button.focus_mode = Control.FOCUS_ALL
	undo_button.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), undo_button)

	controller.call("_undo_last_deploy")

	assert_null(
		get_viewport().gui_get_focus_owner(),
		"Annuler doit rendre les flèches au focus spatial.",
	)
	assert_eq(battle.get("_grid_cursor_cell"), Vector2i.ZERO)
	assert_eq(grid_view.get_cursor_cell(), Vector2i.ZERO)
	assert_eq(controller.get_preferred_cursor_cell(), Vector2i.ZERO)
	battle.free()


func _pressed_echo_key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.echo = true
	return event


class _DeploymentBattleStub:
	extends Node

	const SPELL_COLOR := Color(0.3, 0.55, 1.0, 0.4)

	var grid := GridData.new(3, 1)
	var room_data := RoomData.new()
	var units: Array = []
	var _unit_views := {}


class _DeploymentUndoProbe:
	extends DeploymentController

	var undo_calls := 0

	func is_active() -> bool:
		return true

	func undo_last_deploy() -> bool:
		undo_calls += 1
		return true


class _FacingViewSpy:
	extends Node2D

	var faced_directions: Array[Vector2i] = []

	func face_grid_direction(direction: Vector2i) -> void:
		faced_directions.append(direction)
