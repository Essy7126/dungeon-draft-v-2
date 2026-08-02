extends GutTest

const START_HUB_SCENE: PackedScene = preload("res://hub/StartHub.tscn")
const ARCHIVIST_MODEL_PATH := (
	"res://imported_models/Lanternbound Archivist/Lanternbound Archivist.glb"
)
const HUB_TEST_INTERACTABLE_SCRIPT = preload("res://test/support/hub_test_interactable.gd")


func test_astar_rejoint_archiviste_et_marqueurs_sans_traverser_obstacle() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var grid := controller.navigation_grid
	var spawn := controller.movement.current_cell
	var targets: Array[Vector2i] = [
		Vector2i(6, 11),
		Vector2i(10, 5),
		Vector2i(5, 10),
		Vector2i(2, 2),
	]
	for target in targets:
		var path := grid.get_path(spawn, target)
		assert_false(path.is_empty(), "chemin requis vers %s" % target)
		_assert_octile_walkable_path(grid, path)


func test_astar_prend_la_diagonale_libre_et_refuse_la_coupe_d_angle() -> void:
	var grid := HubNavigationGrid.new()
	grid.rebuild()
	var origin := Vector2i(8, 12)
	var diagonal := origin + Vector2i(1, 1)
	var path := grid.get_path(origin, diagonal)
	assert_eq(path, [origin, diagonal])
	assert_almost_eq(grid.get_path_cost(path), HubNavigationGrid.DIAGONAL_COST, 0.00001)
	grid.blocked_cells = [origin + Vector2i.RIGHT]
	grid.rebuild()
	assert_false(grid.can_traverse(origin, diagonal))
	path = grid.get_path(origin, diagonal)
	assert_false(path.is_empty())
	assert_ne(path[1], diagonal, "AStar ne coupe pas le coin bloque")
	_assert_octile_walkable_path(grid, path)
	grid.blocked_cells = [origin + Vector2i.RIGHT, origin + Vector2i.DOWN]
	grid.rebuild()
	assert_false(
		grid.can_traverse(origin, diagonal),
		"aucun passage entre deux cellules bloquees en diagonale",
	)


func test_occupation_reservation_et_destination_archiviste_refusee() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var grid := controller.navigation_grid
	var archivist: HubArchivist = hub.get_node("WorldRoot/SortableWorld/Archivist")
	assert_true(grid.is_occupied(archivist.occupied_cell))
	assert_false(grid.is_walkable(archivist.occupied_cell))
	assert_true(grid.get_path(controller.movement.current_cell, archivist.occupied_cell).is_empty())
	var owner := RefCounted.new()
	var reservable := Vector2i(13, 14)
	assert_true(grid.reserve(reservable, owner))
	assert_false(grid.is_walkable(reservable))
	assert_true(grid.is_walkable(reservable, owner))
	grid.release(reservable, owner)
	assert_true(grid.is_walkable(reservable))


func test_resolver_selectionne_approche_accessible_la_plus_courte() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var archivist: HubArchivist = hub.get_node("WorldRoot/SortableWorld/Archivist")
	var intent := InteractionIntent.new(1, archivist)
	var resolution := controller.interaction_resolver.resolve(
		controller.player, archivist, controller.navigation_grid, intent
	)
	assert_false(resolution.is_empty())
	assert_has(archivist.approach_cells, resolution["cell"])
	assert_true(controller.navigation_grid.is_reserved(resolution["cell"]))
	var shortest := INF
	for cell in archivist.approach_cells:
		var path := controller.navigation_grid.get_path(
			controller.movement.current_cell, cell, intent
		)
		if not path.is_empty():
			shortest = minf(shortest, controller.navigation_grid.get_path_cost(path))
	assert_almost_eq(resolution["distance"], shortest, 0.00001)
	controller.navigation_grid.release(resolution["cell"], intent)


func test_resolver_refuse_proprement_si_aucune_approche() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var target := HUB_TEST_INTERACTABLE_SCRIPT.new()
	target.approaches = [Vector2i(0, 0), Vector2i(2, 8)]
	hub.add_child(target)
	target.position = controller.navigation_grid.cell_to_world(target.occupied_cell)
	var intent := InteractionIntent.new(1, target)
	assert_true(controller.interaction_resolver.resolve(
		controller.player, target, controller.navigation_grid, intent
	).is_empty())


func test_mouvement_met_a_jour_cellule_uniquement_au_centre() -> void:
	var grid := HubNavigationGrid.new()
	grid.rebuild()
	var actor := Node2D.new()
	var movement := ExplorationMovement.new()
	add_child_autofree(actor)
	add_child_autofree(movement)
	movement.movement_speed = 40.0
	movement.setup(actor, grid, Vector2i(8, 8))
	assert_true(movement.request_move(Vector2i(9, 8)))
	movement._process(0.1)
	assert_eq(movement.current_cell, Vector2i(8, 8))
	assert_ne(actor.position, grid.cell_to_world(Vector2i(9, 8)))
	for _step in range(40):
		movement._process(0.1)
		if not movement.is_moving():
			break
	assert_eq(movement.current_cell, Vector2i(9, 8))
	assert_eq(actor.position, grid.cell_to_world(Vector2i(9, 8)))


func test_elfe_est_idle_marche_en_diagonale_une_fois_puis_redevient_idle() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var visual: CharacterVisual3D = controller.player.get_character_visual()
	await get_tree().process_frame
	assert_eq(visual.get_current_animation(), &"Elf_Idle")
	var started: Array[StringName] = []
	visual.animation_started.connect(
		func(animation_name: StringName): started.append(animation_name)
	)
	controller.movement.movement_speed = 1200.0
	var destination := controller.movement.current_cell + Vector2i(-3, -3)
	assert_true(controller.request_ground_move(destination))
	assert_eq(visual.get_current_animation(), &"Elf_Walk")
	await _wait_for_movement(controller, 100)
	assert_eq(controller.movement.current_cell, destination)
	assert_eq(visual.get_current_animation(), &"Elf_Idle")
	assert_eq(started.count(&"Elf_Walk"), 1, "la marche ne redemarre pas a chaque cellule")


func test_elfe_revient_idle_apres_annulation_echec_et_ouverture_ui() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var visual: CharacterVisual3D = controller.player.get_character_visual()
	controller.movement.movement_speed = 1200.0
	assert_true(controller.request_ground_move(Vector2i(12, 12)))
	controller.movement.cancel()
	await _wait_for_movement(controller, 40)
	assert_eq(visual.get_current_animation(), &"Elf_Idle")
	hub.queue_free()
	await get_tree().process_frame
	hub = await _make_hub()
	controller = hub.get_node("HubController")
	visual = controller.player.get_character_visual()
	assert_false(controller.movement.request_move(Vector2i(0, 0)))
	assert_eq(visual.get_current_animation(), &"Elf_Idle")
	hub.queue_free()
	await get_tree().process_frame
	hub = await _make_hub()
	controller = await _open_archivist_panel(hub)
	assert_eq(controller.player.get_character_visual().get_current_animation(), &"Elf_Idle")


func test_nouveau_clic_interrompt_segment_diagonal_sans_teleportation() -> void:
	var grid := HubNavigationGrid.new()
	grid.rebuild()
	var actor := Node2D.new()
	var movement := ExplorationMovement.new()
	add_child_autofree(actor)
	add_child_autofree(movement)
	movement.movement_speed = 100.0
	movement.setup(actor, grid, Vector2i(8, 8))
	var entered: Array[Vector2i] = []
	movement.cell_entered.connect(func(cell: Vector2i): entered.append(cell))
	assert_true(movement.request_move(Vector2i(10, 10)))
	movement._process(0.2)
	var position_before_replacement := actor.position
	assert_true(movement.request_move(Vector2i(8, 10)))
	assert_eq(movement.current_cell, Vector2i(8, 8))
	assert_eq(actor.position, position_before_replacement)
	for _step in range(100):
		movement._process(0.1)
		if not movement.is_moving():
			break
	assert_gt(entered.size(), 1)
	assert_eq(entered[0], Vector2i(9, 9), "le segment diagonal engage atteint son centre")
	assert_eq(movement.current_cell, Vector2i(8, 10))
	assert_eq(actor.position, grid.cell_to_world(Vector2i(8, 10)))


func test_trois_clics_rapides_ne_conservent_que_derniere_intention() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var archivist: HubArchivist = hub.get_node("WorldRoot/SortableWorld/Archivist")
	var first := controller.request_interaction(archivist)
	var second := controller.request_interaction(archivist)
	var third := controller.request_interaction(archivist)
	assert_not_null(first)
	assert_not_null(second)
	assert_not_null(third)
	assert_true(first.cancelled)
	assert_true(second.cancelled)
	assert_false(third.cancelled)
	assert_eq(controller.get_active_intent(), third)
	assert_eq(third.id, first.id + 2)


func test_proxy_clic_archiviste_couvre_corps_lanterne_hover_et_remplacement() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var archivist := controller.archivist
	controller.movement.movement_speed = 1200.0
	var body_point := archivist.click_collision.to_global(Vector2(0.0, 45.0))
	var lantern_point := archivist.click_collision.to_global(Vector2(62.0, -48.0))
	var outside_point := archivist.click_collision.to_global(Vector2(90.0, 0.0))
	assert_true(archivist.is_click_proxy_world_point(body_point))
	assert_true(archivist.is_click_proxy_world_point(lantern_point))
	assert_false(archivist.is_click_proxy_world_point(outside_point))
	archivist.click_area.mouse_entered.emit()
	assert_true(archivist.is_hovered())
	assert_ne(archivist.render_sprite.self_modulate, Color.WHITE)
	assert_false(controller.archivist_panel.visible)
	archivist.click_area.mouse_exited.emit()
	assert_false(archivist.is_hovered())
	controller.request_primary_click_at_world(outside_point)
	assert_null(controller.get_active_intent(), "hors proxy = clic sol, pas interaction")
	assert_false(controller.archivist_panel.visible)
	assert_true(controller.request_primary_click_at_world(body_point))
	var body_intent := controller.get_active_intent()
	assert_not_null(body_intent)
	assert_true(controller.request_primary_click_at_world(lantern_point))
	assert_true(body_intent.cancelled)
	assert_ne(controller.get_active_intent(), body_intent)
	await _wait_for_movement(controller, 100)
	assert_true(controller.archivist_panel.visible)
	assert_eq(controller.get_state(), StartHubController.HubState.UI_LOCKED)
	assert_false(
		controller.request_primary_click_at_world(body_point),
		"le panneau ouvert consomme le flux et ne recree pas d'intention",
	)
	assert_null(controller.get_active_intent())


func test_clic_sol_pendant_approche_annule_interface_et_change_destination() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var archivist: HubArchivist = hub.get_node("WorldRoot/SortableWorld/Archivist")
	controller.movement.movement_speed = 1200.0
	assert_not_null(controller.request_interaction(archivist))
	await get_tree().process_frame
	assert_true(controller.request_ground_move(Vector2i(14, 13)))
	await _wait_for_movement(controller, 80)
	assert_eq(controller.movement.current_cell, Vector2i(14, 13))
	assert_null(controller.get_active_intent())
	assert_false(controller.archivist_panel.visible)


func test_cible_desactivee_pendant_approche_n_interagit_pas() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var archivist: HubArchivist = hub.get_node("WorldRoot/SortableWorld/Archivist")
	controller.movement.movement_speed = 1200.0
	assert_not_null(controller.request_interaction(archivist))
	archivist.set_interaction_enabled(false)
	await _wait_for_movement(controller, 100)
	assert_false(controller.archivist_panel.visible)
	assert_eq(controller.get_state(), StartHubController.HubState.IDLE)


func test_interaction_s_ouvre_seulement_apres_arrivee_adjacente() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var archivist: HubArchivist = hub.get_node("WorldRoot/SortableWorld/Archivist")
	controller.movement.movement_speed = 1200.0
	assert_not_null(controller.request_interaction(archivist))
	assert_false(controller.archivist_panel.visible)
	assert_eq(controller.get_state(), StartHubController.HubState.APPROACHING_INTERACTION)
	await _wait_for_movement(controller, 100)
	assert_true(controller.archivist_panel.visible)
	assert_eq(controller.get_state(), StartHubController.HubState.UI_LOCKED)
	assert_eq(_manhattan(controller.movement.current_cell, archivist.occupied_cell), 1)


func test_parler_echanger_et_partir_verrouillent_puis_rendent_controle() -> void:
	var hub := await _make_hub()
	var controller := await _open_archivist_panel(hub)
	var cinematic_calls := [0]
	controller.cinematic_open_callable = func(_scene_path):
		cinematic_calls[0] += 1
		return true
	var panel := controller.archivist_panel
	panel.get_node("%TalkButton").pressed.emit()
	assert_true(panel.is_dialogue_open())
	assert_true(controller.is_ui_locked())
	panel.get_node("%DialogueBackButton").pressed.emit()
	panel.get_node("%TradeButton").pressed.emit()
	assert_false(panel.visible)
	assert_true(controller.trade_panel.visible)
	assert_false(controller.request_ground_move(Vector2i(10, 10)))
	controller.trade_panel.get_node("%CloseButton").pressed.emit()
	assert_false(controller.trade_panel.visible)
	assert_true(panel.visible)
	panel.get_node("%LeaveButton").pressed.emit()
	assert_eq(controller.get_state(), StartHubController.HubState.IDLE)
	assert_false(panel.visible)
	await get_tree().process_frame
	assert_false(panel.visible, "aucune ancienne intention ne rouvre l'interface")
	assert_eq(cinematic_calls[0], 0, "parler, echanger et partir n'ouvrent pas l'intro")


func test_commencer_run_ouvre_intro_sans_demarrer_run_et_une_seule_fois() -> void:
	var hub := await _make_hub()
	var controller := await _open_archivist_panel(hub)
	var calls := [0]
	var captured_paths: Array[String] = []
	GameManager.cleanup_run_state()
	controller.transition_fade_duration = 0.0
	controller.cinematic_open_callable = func(scene_path):
		calls[0] += 1
		captured_paths.append(scene_path)
		return true
	controller.archivist_panel.get_node("%RunButton").pressed.emit()
	controller.archivist_panel.get_node("%RunButton").pressed.emit()
	assert_eq(calls[0], 1)
	assert_eq(controller.get_state(), StartHubController.HubState.TRANSITIONING)
	assert_false(controller.archivist_panel.visible)
	assert_false(controller.trade_panel.visible)
	assert_eq(captured_paths, ["res://cinematics/intro/intro_cinematic.tscn"])
	assert_false(GameManager.run_active, "le hub ne demarre pas la run avant l'intro")


func test_donnees_archiviste_preparent_le_trio_reel_dans_game_manager() -> void:
	var data: LanternboundArchivistData = load(
		"res://hub/data/lanternbound_archivist.tres"
	)
	GameManager.cleanup_run_state()
	assert_true(GameManager._prepare_preconfigured_run(data.run_data, data.hero_sources))
	assert_eq(GameManager.get_ordered_heroes().map(
		func(hero: Unit): return String(hero.unit_id)
	), ["elf", "mage", "warrior"])
	assert_eq(GameManager.rooms.size(), 4, "first_run nettoyee contient quatre salles reelles")
	GameManager.cleanup_run_state()


func test_echec_transition_restaure_un_etat_non_bloque() -> void:
	var hub := await _make_hub()
	var controller := await _open_archivist_panel(hub)
	controller.transition_fade_duration = 0.0
	controller.cinematic_open_callable = func(_scene_path): return false
	controller.archivist_panel.get_node("%RunButton").pressed.emit()
	assert_push_error("impossible d'ouvrir la cinematique d'introduction")
	assert_eq(controller.get_state(), StartHubController.HubState.IDLE)
	assert_false(controller.transition_fade.visible)
	assert_true(controller.archivist.interaction_enabled)


func test_modele_glb_sans_animation_est_charge_et_pose_importee_conservee() -> void:
	assert_true(ResourceLoader.exists(ARCHIVIST_MODEL_PATH))
	var packed := load(ARCHIVIST_MODEL_PATH) as PackedScene
	assert_not_null(packed)
	var model := packed.instantiate() as Node3D
	add_child_autofree(model)
	assert_eq(model.scale, Vector3.ONE)
	assert_null(model.find_child("AnimationPlayer", true, false))


func test_orientation_archiviste_reste_fixe_pour_toutes_les_approches() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var archivist: HubArchivist = controller.archivist
	var yaw := archivist.get_facing_yaw_degrees()
	for cell in archivist.approach_cells:
		controller.movement.setup(controller.player, controller.navigation_grid, cell)
		controller.player.position = controller.navigation_grid.cell_to_world(cell)
		assert_almost_eq(archivist.get_facing_yaw_degrees(), yaw, 0.001)
	assert_eq(archivist.occupied_cell, Vector2i(5, 11))
	assert_eq(archivist.approach_cells, [
		Vector2i(4, 11), Vector2i(5, 10), Vector2i(6, 11), Vector2i(5, 12),
	])


func _make_hub() -> Node:
	var hub := START_HUB_SCENE.instantiate()
	add_child_autofree(hub)
	await get_tree().process_frame
	return hub


func _open_archivist_panel(hub: Node) -> StartHubController:
	var controller: StartHubController = hub.get_node("HubController")
	controller.movement.movement_speed = 1200.0
	assert_not_null(controller.request_interaction(controller.archivist))
	await _wait_for_movement(controller, 100)
	assert_true(controller.archivist_panel.visible)
	return controller


func _wait_for_movement(controller: StartHubController, max_frames: int) -> void:
	for _frame in range(max_frames):
		await get_tree().process_frame
		if not controller.movement.is_moving():
			return
	fail_test("le mouvement n'a pas termine en %d frames" % max_frames)


func _assert_octile_walkable_path(
		grid: HubNavigationGrid,
		path: Array[Vector2i]
	) -> void:
	for index in range(path.size()):
		assert_true(
			grid.is_walkable(path[index]) or index == 0,
			"cellule praticable %s" % path[index],
		)
		if index > 0:
			var delta := path[index] - path[index - 1]
			assert_lte(absi(delta.x), 1)
			assert_lte(absi(delta.y), 1)
			assert_ne(delta, Vector2i.ZERO)
			assert_true(
				grid.can_traverse(path[index - 1], path[index]),
				"le chemin ne coupe aucun angle",
			)


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
