extends GutTest
const HALL := preload("res://hub/painted_halt/LivingHalt.tscn")
const BRIDGE := preload("res://hub/painted_halt/halt_session_bridge.gd")
const CATALOG := preload("res://core/expedition/painted_halt_catalog.gd")


class ManagerSpy extends Node:
	var calls := 0
	var pending := false


	func get_sanctuary_context() -> Dictionary:
		return { "mode": "halt", "services": [], "balance": 100 }


	func get_expedition_save_status() -> Dictionary:
		return { "pending": pending, "message": "Enregistrement en attente" }


	func use_catabase_hub_service(_id: String) -> Dictionary:
		calls += 1
		pending = true
		return { "success": true, "saved": false }


	func retry_expedition_save() -> bool:
		pending = false
		return true


func test_studio_preview_never_calls_game_manager_or_repeats_receipt() -> void:
	var manager := ManagerSpy.new()
	add_child_autofree(manager)
	var bridge := BRIDGE.new()
	bridge.configure(true, manager)
	assert_eq(bridge.context().balance, 180)
	assert_true(bridge.use_service("preview:bronze").success)
	assert_eq(bridge.context().balance, 120)
	assert_false(bridge.use_service("preview:bronze").success)
	assert_eq(bridge.context().balance, 120)
	assert_eq(manager.calls, 0)
	assert_true(bridge.leave().success)
	assert_false(bridge.use_service("preview:lore").success)


func test_applied_transaction_with_failed_checkpoint_only_retries_save() -> void:
	var manager := ManagerSpy.new()
	add_child_autofree(manager)
	var bridge := BRIDGE.new()
	bridge.configure(false, manager)
	assert_true(bridge.use_service("real-service").success)
	assert_false(bridge.use_service("real-service").success)
	assert_eq(manager.calls, 1)
	assert_true(bridge.retry_save().success)
	assert_eq(manager.calls, 1)


func test_bindings_are_presentation_only_and_preserve_all_seeded_route_ids() -> void:
	for seed_value in [1, 17, 2401]:
		var nodes := ExpeditionRouteCatalog.create_nodes(seed_value)
		var before := nodes.duplicate(true)
		var bound := 0
		for node: Dictionary in nodes:
			var path := CATALOG.manifest_for(node)
			if not path.is_empty():
				bound += 1
				assert_eq(int(node.depth), 8)
				assert_true(str(node.kind) in ["merchant", "sanctuary"])
		assert_eq(bound, 2)
		assert_eq(nodes, before)


func test_approach_redirect_and_modal_transaction_state() -> void:
	var hall = HALL.instantiate()
	hall.audio_enabled = false
	add_child_autofree(hall)
	for attempt in 180:
		if hall.is_ready_for_play():
			break
		await get_tree().physics_frame
	assert_true(hall.is_ready_for_play())
	if not hall.is_ready_for_play():
		return
	hall.set_process(false)
	assert_true(hall.interactions.request(0))
	assert_false(hall.interactions.active)
	hall.advance_world(0.1)
	assert_true(hall.request_move(hall.point(hall.definition.world.spawn)))
	assert_eq(hall.interactions.pending, -1)
	hall.stop_movement()
	assert_true(hall.interactions.request(0))
	for step in 3600:
		hall.advance_world(1.0 / 60.0)
		if hall.interactions.active:
			break
	assert_true(hall.interactions.active)
	assert_false(hall.request_move(hall.point(hall.definition.world.spawn)))
	var before: Vector2 = hall.player.position
	hall.advance_world(1)
	assert_eq(hall.player.position, before)
	assert_true(hall.interactions.activate("preview:blessing").success)
	assert_true(hall.interactions.awakened.has("altar"))
	assert_false(hall.interactions.activate("preview:blessing").success)
	hall.interactions.close()
	assert_false(hall.interactions.active)
	assert_true(hall.request_move(hall.point(hall.definition.world.spawn)))


func test_production_scene_requires_an_active_bound_halt() -> void:
	# This assertion does not initialize or mutate the live singleton's session.
	var scene := load("res://hub/painted_halt/ExpeditionHalt.tscn") as PackedScene
	assert_not_null(scene)
	var state := scene.get_state()
	var explicit_production := false
	for index in state.get_node_property_count(0):
		if state.get_node_property_name(0, index) == &"preview_mode":
			explicit_production = state.get_node_property_value(0, index) == false
	assert_true(explicit_production)


func test_actor_calibration_is_independent_of_world_width_and_source_resolution() -> void:
	var scale_ref := preload("res://hub/painted_halt/halt_scale_reference.gd")
	var manifest := {
		"source": { "size": [1600, 900] },
		"world": { "width": 2200, "player_height_ratio": 0.24 },
	}
	var height_720 := 720.0 * scale_ref.reference_height() * scale_ref.display_scale(manifest) / scale_ref.world_height(
		manifest
	)
	assert_almost_eq(height_720, 172.8, 0.001)
	manifest.world.width = 4400
	manifest.source.size = [3200, 1800]
	var resized_height := 720.0 * scale_ref.reference_height() * scale_ref.display_scale(manifest) / scale_ref.world_height(
		manifest
	)
	assert_almost_eq(
		resized_height,
		height_720,
		0.001,
		"Larger maps cannot silently shrink the actor",
	)
	manifest.world.erase("player_height_ratio")
	manifest.world.player_scale = 0.52
	assert_almost_eq(
		scale_ref.display_scale(manifest),
		0.52,
		0.0001,
		"Legacy maps keep their authored appearance",
	)


func test_calibrated_actor_stride_follows_ground_distance() -> void:
	var player := preload("res://hub/painted_halt/halt_player.gd").new()
	player.display_scale = 1.04
	add_child_autofree(player)
	assert_true(player.is_visual_ready())
	assert_true(player.play_walk(Vector2.RIGHT))
	player.advance_ground_stride(76)
	assert_almost_eq(
		float(player.get_visual_state().ground_stride),
		38.0,
		0.001,
		"A doubled body takes a doubled step",
	)
