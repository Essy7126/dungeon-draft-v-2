extends SceneTree

const Player := preload("res://hub/sanctuary_prototype/sanctuary_player.gd")
const Navigation := preload("res://hub/sanctuary_prototype/sanctuary_navigation.gd")

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var fixture := Node2D.new()
	root.add_child(fixture)
	var player := Player.new()
	player.display_scale = 0.42
	fixture.add_child(player)
	_check(player.is_visual_ready(), "Achille sprite initializes")
	_check(player.find_children("*", "Node3D", true, false).is_empty(), "No Node3D")
	_check(player.find_children("*", "SubViewport", true, false).is_empty(), "No SubViewport")
	_check(player.find_children("*", "AnimatedSprite2D", true, false).size() == 1, "One animated sprite")
	_check(is_equal_approx(player.sprite_profile.display_scale, 0.35), "Source profile remains unchanged")
	var sprite := player.get_node("AchillesSprite/AnimatedSprite2D") as AnimatedSprite2D
	_check(sprite.scale.is_equal_approx(Vector2.ONE * 0.42), "Local display scale applies")
	for pair: Array in [[Vector2(2, 1), "E"], [Vector2(-2, 1), "S"], [Vector2(-2, -1), "W"], [Vector2(2, -1), "N"]]:
		_check(player.face_for_direction(pair[0]) == pair[1], "Isometric facing %s" % pair[1])
	_check(player.play_walk(Vector2(2, 1)), "Walk starts")
	_check(player.get_visual_state().animation == "walk_E", "Walk faces correctly")
	_check(player.play_idle(), "Idle starts")
	_check(player.get_visual_state().animation == "idle_E", "Idle preserves facing")
	player.play_walk(Vector2(-2, 1))
	player.cancel_movement_feedback()
	_check(player.get_visual_state().animation == "idle_S", "Movement cancellation returns to idle")

	var navigation := Navigation.new()
	var debug_overlay := navigation.create_debug_overlay(fixture)
	debug_overlay.position = Vector2(531, -289)
	debug_overlay.rotation = 0.2
	debug_overlay.scale = Vector2(1.5, 1.5)
	var outer := PackedVector2Array([Vector2(0, 0), Vector2(400, 0), Vector2(400, 300), Vector2(0, 300)])
	var obstacle := PackedVector2Array([Vector2(160, 70), Vector2(240, 70), Vector2(240, 230), Vector2(160, 230)])
	var obstacles: Array[PackedVector2Array] = [obstacle]
	_check(not navigation.is_navigation_ready(), "Navigation initially unready")
	_check(navigation.get_path(Vector2(40, 150), Vector2(360, 150)).is_empty(), "No path before configuration")
	_start_configuration(navigation, outer, obstacles)
	_check(not navigation.is_navigation_ready(), "Configuration waits for map synchronization")
	_check(navigation.get_path(Vector2(40, 150), Vector2(360, 150)).is_empty(), "No path while configuration pending")
	var ready_ok: bool = await navigation.configuration_finished
	_check(ready_ok, "Navigation configuration succeeds")
	_check(navigation.is_walkable(Vector2(40, 150)), "Local coordinate ignores node transform")
	_check(not navigation.is_walkable(Vector2(200, 150)), "Explicit obstacle mask blocks center")
	_check(not navigation.is_walkable(Vector2(155, 150)), "Feet cannot approach hole closer than radius")
	_check(not navigation.is_walkable(Vector2(4, 150)), "Feet stay away from outer edge")
	_check(navigation.get_path(Vector2(40, 150), Vector2(200, 150)).is_empty(), "Obstacle destination refused")
	var path := navigation.get_path(Vector2(40, 150), Vector2(360, 150))
	_check(path.size() >= 4, "Path bends around the hole")
	if not path.is_empty():
		_check(path[0].distance_to(Vector2(40, 150)) < 0.5, "Path begins at local start")
		_check(path[-1].distance_to(Vector2(360, 150)) < 0.5, "Path ends at local destination")
		var path_safe := true
		var detour_length := 0.0
		for segment in range(1, path.size()):
			detour_length += path[segment - 1].distance_to(path[segment])
			for step in range(41):
				var point := path[segment - 1].lerp(path[segment], float(step) / 40.0)
				if not navigation.is_walkable(point):
					path_safe = false
		_check(path_safe, "Every sampled segment stays on cleared navigation surface")
		_check(detour_length > 360.0, "Path includes meaningful detour")
	var no_obstacles: Array[PackedVector2Array] = []
	_check(await navigation.configure(outer, no_obstacles), "Reconfiguration succeeds")
	_check(navigation.is_walkable(Vector2(200, 150)), "Removing obstacle clears old collision")
	_check(navigation.get_path(Vector2(40, 150), Vector2(360, 150)).size() == 2, "Reconfigured map permits direct path")
	var divider := PackedVector2Array([Vector2(180, -10), Vector2(220, -10), Vector2(220, 310), Vector2(180, 310)])
	var divided_obstacles: Array[PackedVector2Array] = [divider]
	_check(await navigation.configure(outer, divided_obstacles), "Disconnected islands configure")
	_check(navigation.is_walkable(Vector2(40, 150)) and navigation.is_walkable(Vector2(360, 150)), "Both disconnected endpoints are walkable")
	_check(navigation.get_path(Vector2(40, 150), Vector2(360, 150)).is_empty(), "Partial route to a disconnected island is refused")
	_check(not await navigation.configure(PackedVector2Array(), no_obstacles), "Invalid outline fails")
	_check(not navigation.is_navigation_ready(), "Invalid reconfiguration disables old paths")
	_check(navigation.get_path(Vector2(40, 150), Vector2(360, 150)).is_empty(), "No stale path after failed reconfiguration")
	navigation.close()
	fixture.queue_free()
	await process_frame
	await process_frame
	for failure: String in _failures:
		push_error("SANCTUARY_COMPONENTS: %s" % failure)
	print("SANCTUARY_COMPONENTS: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _start_configuration(navigation: RefCounted, outer: PackedVector2Array, obstacles: Array[PackedVector2Array]) -> void:
	await navigation.configure(outer, obstacles)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
