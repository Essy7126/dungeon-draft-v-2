extends GutTest

const START_HUB_SCENE: PackedScene = preload("res://hub/StartHub.tscn")
const ARCHIVIST_MODEL_PATH := (
	"res://imported_models/Lanternbound Archivist/Lanternbound Archivist.glb"
)
const HUB_TEST_INTERACTABLE_SCRIPT = preload(
	"res://test/support/hub_test_interactable.gd"
)


func test_navigation_continue_rejoint_les_zones_libres_et_approches() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var region := controller.navigation_region
	assert_gt(region.navigation_polygon.get_polygon_count(), 0)
	assert_true(region.get_navigation_map().is_valid())
	assert_true(NavigationServer2D.map_is_active(region.get_navigation_map()))
	assert_has(
		NavigationServer2D.map_get_regions(region.get_navigation_map()),
		region.get_rid(),
	)
	var spawn := controller.player.global_position
	var targets := PackedVector2Array([
		Vector2(1024.0, 768.0),
		Vector2(1344.0, 1120.0),
		Vector2(704.0, 1120.0),
		Vector2(420.0, 1390.0),
		Vector2(1640.0, 1390.0),
	])
	targets.append_array(controller.archivist.get_approach_world_positions())
	for target in targets:
		assert_true(region.is_world_position_navigable(target), "cible libre %s" % target)
		var path := region.get_world_path(spawn, target)
		assert_false(path.is_empty(), "chemin requis vers %s" % target)
		assert_almost_eq(path[0].distance_to(spawn), 0.0, 0.01)
		assert_almost_eq(path[path.size() - 1].distance_to(target), 0.0, 0.01)
		_assert_continuous_path_is_navigable(region, path)


func test_chemins_contournent_table_et_comptoir_sans_les_traverser() -> void:
	var hub := await _make_hub()
	var region: HubNavigationRegion2D = hub.get_node("WorldRoot/NavigationRegion2D")
	var routes := [
		[
			Vector2(300.0, 1260.0),
			Vector2(940.0, 820.0),
			region.table_obstacle,
		],
		[
			Vector2(1740.0, 1260.0),
			Vector2(1100.0, 820.0),
			region.counter_obstacle,
		],
	]
	for route in routes:
		var path := region.get_world_path(route[0], route[1])
		assert_gt(path.size(), 2, "l'obstacle doit ajouter un virage continu")
		_assert_continuous_path_is_navigable(region, path)
		_assert_path_avoids_polygon(path, route[2])


func test_clic_libre_reste_exact_et_clic_obstacle_est_projete() -> void:
	var hub := await _make_hub()
	var region: HubNavigationRegion2D = hub.get_node("WorldRoot/NavigationRegion2D")
	var exact_click := Vector2(1137.25, 1452.75)
	assert_true(region.is_world_position_navigable(exact_click))
	assert_eq(region.project_world_position(exact_click), exact_click)
	var table_click := Vector2(560.0, 950.0)
	var projected := region.project_world_position(table_click)
	assert_ne(projected, table_click)
	assert_lte(region._distance_to_boundaries(projected), region.projection_epsilon)
	assert_false(region.get_world_path(Vector2(1024.0, 1536.0), projected).is_empty())


func test_resolver_selectionne_approche_monde_accessible_la_plus_courte() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var archivist: HubArchivist = controller.archivist
	var intent := InteractionIntent.new(1, archivist)
	var resolution := controller.interaction_resolver.resolve(
		controller.player, archivist, controller.navigation_region, intent
	)
	assert_false(resolution.is_empty())
	assert_has(archivist.get_approach_world_positions(), resolution["position"])
	assert_true(controller.navigation_region.is_world_position_reserved(
		resolution["position"]
	))
	var shortest := INF
	for approach_position in archivist.get_approach_world_positions():
		var path := controller.navigation_region.get_world_path(
			controller.player.global_position, approach_position
		)
		if not path.is_empty():
			shortest = minf(shortest, controller.navigation_region.get_path_length(path))
	assert_almost_eq(resolution["distance"], shortest, 0.01)
	controller.navigation_region.release_world_position(resolution["position"], intent)


func test_resolver_refuse_proprement_si_aucune_approche() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var target := HUB_TEST_INTERACTABLE_SCRIPT.new()
	target.approaches = PackedVector2Array([
		Vector2(100.0, 500.0), Vector2(560.0, 950.0),
	])
	target.occupied_world_position = Vector2(560.0, 950.0)
	hub.add_child(target)
	target.global_position = target.occupied_world_position
	var intent := InteractionIntent.new(1, target)
	assert_true(controller.interaction_resolver.resolve(
		controller.player, target, controller.navigation_region, intent
	).is_empty())


func test_mouvement_est_continu_a_vitesse_constante_et_arrive_exactement() -> void:
	var hub := await _make_hub()
	var region: HubNavigationRegion2D = hub.get_node("WorldRoot/NavigationRegion2D")
	var actor := Node2D.new()
	var movement := ExplorationMovement.new()
	add_child_autofree(actor)
	add_child_autofree(movement)
	movement.movement_speed = 100.0
	var start := Vector2(900.0, 1500.0)
	var destination := Vector2(1111.25, 1450.75)
	movement.setup(actor, region, start)
	assert_true(movement.request_move(destination))
	movement._process(0.1)
	assert_almost_eq(actor.global_position.distance_to(start), 10.0, 0.01)
	assert_ne(actor.global_position, destination)
	for _step in range(200):
		movement._process(0.05)
		if not movement.is_moving():
			break
	assert_false(movement.is_moving())
	assert_almost_eq(actor.global_position.distance_to(destination), 0.0, 0.01)


func test_nouveau_clic_remplace_destination_sans_teleportation() -> void:
	var hub := await _make_hub()
	var region: HubNavigationRegion2D = hub.get_node("WorldRoot/NavigationRegion2D")
	var actor := Node2D.new()
	var movement := ExplorationMovement.new()
	add_child_autofree(actor)
	add_child_autofree(movement)
	movement.movement_speed = 100.0
	movement.setup(actor, region, Vector2(1024.0, 1536.0))
	var cancelled: Array[Vector2] = []
	movement.movement_cancelled.connect(
		func(destination: Vector2): cancelled.append(destination)
	)
	var first_destination := Vector2(1450.0, 1450.0)
	var final_destination := Vector2(800.0, 1450.0)
	assert_true(movement.request_move(first_destination))
	movement._process(0.2)
	var position_before_replacement := actor.global_position
	assert_true(movement.request_move(final_destination))
	assert_eq(actor.global_position, position_before_replacement)
	assert_eq(cancelled, [first_destination])
	for _step in range(200):
		movement._process(0.05)
		if not movement.is_moving():
			break
	assert_almost_eq(actor.global_position.distance_to(final_destination), 0.0, 0.01)


func test_annulation_est_immediate_sans_recentrage_ni_teleportation() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	controller.movement.movement_speed = 100.0
	assert_true(controller.request_ground_move(Vector2(1450.0, 1450.0)))
	controller.movement._process(0.2)
	var position_before_cancel := controller.player.global_position
	controller.movement.cancel()
	assert_false(controller.movement.is_moving())
	assert_eq(controller.player.global_position, position_before_cancel)
	assert_eq(
		controller.player.get_character_visual().get_current_animation(),
		&"Elf_Idle",
	)


func test_elfe_marche_une_fois_puis_redevient_idle() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var visual: CharacterVisual3D = controller.player.get_character_visual()
	assert_eq(visual.get_current_animation(), &"Elf_Idle")
	var started: Array[StringName] = []
	visual.animation_started.connect(
		func(animation_name: StringName): started.append(animation_name)
	)
	controller.movement.movement_speed = 1200.0
	var destination := Vector2(1227.5, 1453.25)
	assert_true(controller.request_ground_move(destination))
	assert_eq(visual.get_current_animation(), &"Elf_Walk")
	await _wait_for_movement(controller, 100)
	assert_almost_eq(controller.player.global_position.distance_to(destination), 0.0, 0.01)
	assert_eq(visual.get_current_animation(), &"Elf_Idle")
	assert_eq(started.count(&"Elf_Walk"), 1)


func test_trois_clics_rapides_ne_conservent_que_derniere_intention() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var first := controller.request_interaction(controller.archivist)
	var second := controller.request_interaction(controller.archivist)
	var third := controller.request_interaction(controller.archivist)
	assert_not_null(first)
	assert_not_null(second)
	assert_not_null(third)
	assert_true(first.cancelled)
	assert_true(second.cancelled)
	assert_false(third.cancelled)
	assert_eq(controller.get_active_intent(), third)
	assert_eq(third.id, first.id + 2)


func test_proxy_clic_archiviste_recalibre_hover_et_remplacement() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	var archivist := controller.archivist
	controller.movement.movement_speed = 1200.0
	var body_point := archivist.click_collision.to_global(Vector2(0.0, 80.0))
	var lantern_point := archivist.click_collision.to_global(Vector2(100.0, -100.0))
	var outside_point := archivist.click_collision.to_global(Vector2(140.0, 0.0))
	assert_true(archivist.is_click_proxy_world_point(body_point))
	assert_true(archivist.is_click_proxy_world_point(lantern_point))
	assert_false(archivist.is_click_proxy_world_point(outside_point))
	archivist.click_area.mouse_entered.emit()
	assert_true(archivist.is_hovered())
	assert_ne(archivist.render_sprite.self_modulate, Color.WHITE)
	archivist.click_area.mouse_exited.emit()
	assert_false(archivist.is_hovered())
	controller.request_primary_click_at_world(outside_point)
	assert_null(controller.get_active_intent())
	assert_true(controller.request_primary_click_at_world(body_point))
	var body_intent := controller.get_active_intent()
	assert_true(controller.request_primary_click_at_world(lantern_point))
	assert_true(body_intent.cancelled)
	await _wait_for_movement(controller, 100)
	assert_true(controller.archivist_panel.visible)
	assert_eq(controller.get_state(), StartHubController.HubState.UI_LOCKED)


func test_clic_sol_pendant_approche_annule_interface_et_change_destination() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	controller.movement.movement_speed = 1200.0
	assert_not_null(controller.request_interaction(controller.archivist))
	await get_tree().process_frame
	var destination := Vector2(1103.25, 1481.75)
	assert_true(controller.request_ground_move(destination))
	await _wait_for_movement(controller, 80)
	assert_almost_eq(controller.player.global_position.distance_to(destination), 0.0, 0.01)
	assert_null(controller.get_active_intent())
	assert_false(controller.archivist_panel.visible)


func test_cible_desactivee_pendant_approche_n_interagit_pas() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	controller.movement.movement_speed = 1200.0
	assert_not_null(controller.request_interaction(controller.archivist))
	controller.archivist.set_interaction_enabled(false)
	await _wait_for_movement(controller, 100)
	assert_false(controller.archivist_panel.visible)
	assert_eq(controller.get_state(), StartHubController.HubState.IDLE)


func test_interaction_verifie_distance_oriente_et_ouvre_seulement_a_arrivee() -> void:
	var hub := await _make_hub()
	var controller: StartHubController = hub.get_node("HubController")
	controller.movement.movement_speed = 1200.0
	var intent := controller.request_interaction(controller.archivist)
	assert_not_null(intent)
	assert_false(controller.archivist_panel.visible)
	assert_eq(controller.get_state(), StartHubController.HubState.APPROACHING_INTERACTION)
	await _wait_for_movement(controller, 100)
	assert_true(controller.archivist_panel.visible)
	assert_eq(controller.get_state(), StartHubController.HubState.UI_LOCKED)
	assert_lte(
		controller.player.global_position.distance_to(controller.archivist.global_position),
		controller.archivist.get_max_interaction_distance(),
	)


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
	assert_false(controller.request_ground_move(Vector2(1024.0, 1400.0)))
	controller.trade_panel.get_node("%CloseButton").pressed.emit()
	assert_false(controller.trade_panel.visible)
	assert_true(panel.visible)
	panel.get_node("%LeaveButton").pressed.emit()
	assert_eq(controller.get_state(), StartHubController.HubState.IDLE)
	assert_false(panel.visible)
	await get_tree().process_frame
	assert_false(panel.visible)
	assert_eq(cinematic_calls[0], 0)


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
	assert_eq(calls[0], 0)
	assert_true(controller.archivist_panel.get_node("%RoomSelectionView").visible)
	var run_selector: OptionButton = controller.archivist_panel.get_node("%RunSelector")
	assert_eq(run_selector.item_count, 2)
	assert_eq(run_selector.get_item_text(0), "Principal")
	assert_eq(run_selector.get_item_text(1), "Run de test")
	controller.archivist_panel.get_node("%RoomSelector").select(2)
	controller.archivist_panel.get_node("%ConfirmRunButton").pressed.emit()
	controller.archivist_panel.get_node("%ConfirmRunButton").pressed.emit()
	assert_eq(calls[0], 1)
	assert_eq(controller.get_state(), StartHubController.HubState.TRANSITIONING)
	assert_eq(captured_paths, ["res://cinematics/intro/intro_cinematic.tscn"])
	assert_false(GameManager.run_active)
	GameManager.clear_next_run_configuration()


func test_run_de_test_selectionnee_est_transmise_a_la_cinematique() -> void:
	var hub := await _make_hub()
	var controller := await _open_archivist_panel(hub)
	controller.transition_fade_duration = 0.0
	controller.cinematic_open_callable = func(_scene_path): return true
	GameManager.cleanup_run_state()
	controller.archivist_panel.get_node("%RunButton").pressed.emit()
	var run_selector: OptionButton = controller.archivist_panel.get_node("%RunSelector")
	run_selector.select(1)
	run_selector.item_selected.emit(1)
	assert_eq(
		controller.archivist_panel.get_node("%RoomSelector").item_count,
		4,
	)
	controller.archivist_panel.get_node("%ConfirmRunButton").pressed.emit()
	var selected_run := GameManager.take_next_run_data(null)
	assert_not_null(selected_run)
	assert_eq(selected_run.resource_path, "res://data/runs/fixed_trio_prototype_run.tres")
	assert_eq(selected_run.run_name, "Run de test")
	GameManager.clear_next_run_configuration()


func test_donnees_archiviste_preparent_le_trio_reel_dans_game_manager() -> void:
	var data: LanternboundArchivistData = load(
		"res://hub/data/lanternbound_archivist.tres"
	)
	GameManager.cleanup_run_state()
	var available_runs := data.get_available_runs()
	assert_eq(available_runs.size(), 2)
	assert_eq(available_runs[0].run_name, "Principal")
	assert_eq(available_runs[0].rooms.size(), 6)
	assert_true(
		available_runs[0].is_valid(), str(available_runs[0].validation_errors())
	)
	assert_eq(available_runs[1].run_name, "Run de test")
	assert_eq(available_runs[1].rooms.size(), 4)
	assert_true(
		available_runs[1].is_valid(), str(available_runs[1].validation_errors())
	)
	assert_true(GameManager._prepare_preconfigured_run(
		available_runs[0], data.hero_sources
	))
	assert_eq(GameManager.get_ordered_heroes().map(
		func(hero: Unit): return String(hero.unit_id)
	), ["elf", "mage", "warrior"])
	assert_eq(GameManager.rooms.size(), 6)
	GameManager.cleanup_run_state()


func test_echec_transition_restaure_un_etat_non_bloque() -> void:
	var hub := await _make_hub()
	var controller := await _open_archivist_panel(hub)
	controller.transition_fade_duration = 0.0
	controller.cinematic_open_callable = func(_scene_path): return false
	controller.archivist_panel.get_node("%RunButton").pressed.emit()
	controller.archivist_panel.get_node("%ConfirmRunButton").pressed.emit()
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
	for approach_position in archivist.get_approach_world_positions():
		controller.player.global_position = approach_position
		controller._orient_player_to_world_direction(
			archivist.global_position - approach_position
		)
		assert_almost_eq(archivist.get_facing_yaw_degrees(), yaw, 0.001)
	assert_eq(archivist.occupied_cell, Vector2i(5, 11))
	assert_eq(archivist.approach_cells, [
		Vector2i(4, 11), Vector2i(5, 10), Vector2i(6, 11), Vector2i(5, 12),
	])


func _make_hub() -> Node:
	# Laisse NavigationServer2D retirer la region autofree du test precedent.
	await get_tree().process_frame
	await get_tree().physics_frame
	var hub := START_HUB_SCENE.instantiate()
	add_child_autofree(hub)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	return hub


func _open_archivist_panel(hub: Node) -> StartHubController:
	var controller: StartHubController = hub.get_node("HubController")
	controller.movement.movement_speed = 1200.0
	assert_not_null(controller.request_interaction(controller.archivist))
	await _wait_for_movement(controller, 120)
	assert_true(controller.archivist_panel.visible)
	return controller


func _wait_for_movement(controller: StartHubController, max_frames: int) -> void:
	for _frame in range(max_frames):
		await get_tree().process_frame
		if not controller.movement.is_moving():
			return
	fail_test("le mouvement n'a pas termine en %d frames" % max_frames)


func _assert_continuous_path_is_navigable(
		region: HubNavigationRegion2D,
		path: PackedVector2Array
	) -> void:
	for index in range(path.size()):
		assert_true(
			region.is_world_position_navigable(path[index])
			or region._distance_to_boundaries(path[index]) <= region.projection_epsilon,
			"point du chemin navigable %s" % path[index],
		)
		if index == 0:
			continue
		var segment_length := path[index - 1].distance_to(path[index])
		var sample_count := maxi(1, ceili(segment_length / 8.0))
		for sample_index in range(sample_count + 1):
			var sample := path[index - 1].lerp(
				path[index], float(sample_index) / float(sample_count)
			)
			assert_true(
				region.is_world_position_navigable(sample)
				or region._distance_to_boundaries(sample) <= region.projection_epsilon,
				"segment continu navigable en %s" % sample,
			)


func _assert_path_avoids_polygon(
		path: PackedVector2Array,
		obstacle: PackedVector2Array
	) -> void:
	for index in range(1, path.size()):
		var segment_length := path[index - 1].distance_to(path[index])
		var sample_count := maxi(1, ceili(segment_length / 4.0))
		for sample_index in range(sample_count + 1):
			var sample := path[index - 1].lerp(
				path[index], float(sample_index) / float(sample_count)
			)
			assert_false(
				Geometry2D.is_point_in_polygon(sample, obstacle),
				"le chemin ne traverse pas l'obstacle en %s" % sample,
			)
