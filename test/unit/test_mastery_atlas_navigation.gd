extends GutTest

const GRAPH := preload("res://ui/progression/champion/champion_mastery_graph.gd")
const PROFILE: CharacterProgressionProfile = preload("res://data/runs/progression/odyssey/achilles_progression_profile.tres")
var _state: CharacterRunState


func before_each() -> void:
	var data := UnitData.new()
	data.unit_id = PROFILE.character_id
	data.unit_name = "Achille"
	data.max_hp = 110
	data.attack_power = 18
	data.spells = PROFILE.spells
	data.progression_profile = PROFILE
	_state = CharacterRunState.new()
	assert_true(_state.initialize(Unit.from_data(data), data))


func after_each() -> void:
	await get_tree().process_frame
	_state.dispose()
	await get_tree().process_frame


func _graph(section: StringName = &"achilles_wrath_of_peleus", expand_map: bool = true) -> ChampionMasteryGraph:
	var graph := GRAPH.new() as ChampionMasteryGraph
	graph.size = Vector2(460, 350)
	graph.configure(_state, section)
	add_child_autofree(graph)
	graph.set_reduced_motion(true)
	if expand_map:
		graph.get_minimap().set_collapsed(false)
	return graph


func _mouse(point: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event


func test_minimap_projects_real_nodes_and_current_viewport_at_small_resolution() -> void:
	var graph := _graph()
	await get_tree().process_frame
	var map := graph.get_minimap()
	var snapshot := graph.get_minimap_snapshot()
	assert_eq((snapshot.nodes as Array).size(), 9)
	assert_true(Rect2(Vector2.ZERO, graph.size).encloses(Rect2(map.position, map.size)))
	assert_true((snapshot.map_rect as Rect2).encloses(snapshot.viewport_on_map))
	for node: Dictionary in snapshot.nodes:
		var button := graph.get_all_node_buttons()[node.id] as Button
		assert_eq(node.rect, Rect2(button.position, button.size))
		assert_eq(node.state, button.get_meta("mastery_state"))
		var point: Vector2 = node.rect.get_center()
		assert_true(map.map_to_world(map.world_to_map(point)).is_equal_approx(point))
	var camera := graph.get_navigation_snapshot()
	assert_true((snapshot.viewport as Rect2).position.is_equal_approx(-camera.pan_offset / float(camera.zoom)))
	assert_true((snapshot.viewport as Rect2).size.is_equal_approx(graph.size / float(camera.zoom)))


func test_minimap_click_and_drag_move_camera_without_inspecting_or_spending() -> void:
	var graph := _graph()
	await get_tree().process_frame
	var before := _state.get_progression_snapshot()
	var initial := graph.get_navigation_snapshot()
	var map := graph.get_minimap()
	var local_start := map.world_to_map(Vector2(200, 300))
	map._gui_input(_mouse(local_start, true))
	assert_true(bool(map.get_map_snapshot().dragging))
	var motion := InputEventMouseMotion.new()
	motion.position = map.world_to_map(Vector2(300, 440))
	motion.relative = motion.position - local_start
	map._gui_input(motion)
	map._gui_input(_mouse(motion.position, false))
	assert_false(bool(map.get_map_snapshot().dragging))
	assert_ne(graph.get_pan_offset(), initial.pan_offset)
	assert_eq(graph.get_zoom(), float(initial.zoom))
	assert_eq(graph.get_navigation_snapshot().selected_node_id, initial.selected_node_id)
	assert_true((map.get_map_snapshot().viewport as Rect2).get_center().is_equal_approx(Vector2(300, 440)))
	assert_eq(_state.get_progression_snapshot(), before)


func test_minimap_collapse_and_keyboard_navigation_are_camera_only() -> void:
	var graph := _graph()
	await get_tree().process_frame
	var map := graph.get_minimap()
	var camera := graph.get_navigation_snapshot()
	var before := _state.get_progression_snapshot()
	(map.get_node("ToggleMap") as Button).pressed.emit()
	assert_true(bool(map.get_map_snapshot().collapsed))
	assert_eq(map.size, ChampionMasteryMinimap.COLLAPSED_SIZE)
	assert_eq(graph.get_pan_offset(), camera.pan_offset)
	(map.get_node("ToggleMap") as Button).pressed.emit()
	assert_false(bool(map.get_map_snapshot().collapsed))
	var key := InputEventKey.new()
	key.keycode = KEY_DOWN
	key.pressed = true
	map._gui_input(key)
	assert_ne(graph.get_pan_offset(), camera.pan_offset)
	assert_eq(graph.get_zoom(), float(camera.zoom))
	assert_eq(_state.get_progression_snapshot(), before)


func test_minimap_retains_dimmed_search_context_and_updates_acquired_state() -> void:
	var graph := _graph()
	await get_tree().process_frame
	_state.champion_progression.grant_purchased_mastery(1)
	assert_true(bool(_state.purchase_mastery_node(&"achilles_wrath_focused_fury").get("purchased", false)))
	graph.configure(_state, &"achilles_wrath_of_peleus")
	graph.set_search_query("Entaille")
	var nodes: Array = graph.get_minimap_snapshot().nodes
	var matches := 0
	var acquired := 0
	for node: Dictionary in nodes:
		matches += int(bool(node.matched))
		acquired += int(str(node.state) == "acquired")
	assert_eq(nodes.size(), 9)
	assert_eq(matches, 1)
	assert_eq(acquired, 1)
	assert_eq(graph.get_node_buttons().size(), 1)


func test_major_masteries_have_type_specific_native_frames() -> void:
	var graph := _graph()
	await get_tree().process_frame
	var counts := {"capstone": 0, "summit": 0, "junction": 0, "apotheosis": 0}
	for button: Button in graph.get_all_node_buttons().values():
		assert_true(button.has_node("PrestigeFrame"))
		if str(button.get_meta("prestige")) == "capstone":
			counts.capstone += 1
	graph.configure(_state, &"advanced")
	for button: Button in graph.get_all_node_buttons().values():
		var kind := str(button.get_meta("prestige"))
		counts[kind] += 1
		assert_eq((button.get_node("PrestigeFrame") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_false(bool(graph.get_node_effect_snapshot(StringName(button.name)).running))
	assert_eq(counts, {"capstone": 2, "summit": 3, "junction": 3, "apotheosis": 3})


func test_reveal_uses_actual_purchase_and_stops_immediately_with_reduced_motion() -> void:
	var graph := _graph()
	await get_tree().process_frame
	graph.set_reduced_motion(false)
	_state.champion_progression.grant_purchased_mastery(1)
	graph.configure(_state, &"achilles_wrath_of_peleus")
	graph.inspect_node(&"achilles_wrath_focused_fury")
	assert_false(bool(graph.get_node_effect_snapshot(&"achilles_wrath_focused_fury").running), "Inspecting an available mastery never implies acquisition")
	assert_true(bool(_state.purchase_mastery_node(&"achilles_wrath_focused_fury").get("purchased", false)))
	graph.configure(_state, &"achilles_wrath_of_peleus")
	graph._process(0.42)
	var effect := graph.get_node_effect_snapshot(&"achilles_wrath_focused_fury")
	assert_true(bool(effect.running))
	assert_gt(float(effect.progress), 0.0)
	assert_lt(float(effect.progress), 1.0)
	var shader := (graph.get_all_node_buttons()[&"achilles_wrath_focused_fury"].get_node("AcquisitionReveal") as ColorRect).material as ShaderMaterial
	assert_eq(float(shader.get_shader_parameter("activation")), 1.0)
	graph.set_reduced_motion(true)
	assert_false(bool(graph.get_node_effect_snapshot(&"achilles_wrath_focused_fury").running))
	assert_eq(float(shader.get_shader_parameter("activation")), 0.0)
	graph.configure(_state, &"achilles_wrath_of_peleus")
	assert_false(bool(graph.get_node_effect_snapshot(&"achilles_wrath_focused_fury").running), "Refreshing an already acquired node never replays acquisition")



func test_narrow_advanced_map_starts_collapsed_without_covering_cards_and_preserves_manual_choice() -> void:
	var graph := _graph(&"advanced", false)
	await get_tree().process_frame
	var map := graph.get_minimap()
	assert_true(bool(map.get_map_snapshot().collapsed))
	var minimap_rect := Rect2(map.position, map.size)
	for button: Button in graph.get_all_node_buttons().values():
		var card_rect := Rect2(button.position * graph.get_zoom() + graph.get_pan_offset(), button.size * graph.get_zoom())
		assert_false(minimap_rect.intersects(card_rect), "The collapsed map never obscures a mastery in the initial readable framing")
	map.set_collapsed(false)
	graph.zoom_by(1.05)
	graph.center_on_node(&"achilles_apotheosis_invincible_hero")
	assert_false(bool(map.get_map_snapshot().collapsed), "An explicit map choice survives camera movement")
	map.set_collapsed(true)
	graph.center_on_node(&"achilles_summit_wrath")
	assert_true(bool(map.get_map_snapshot().collapsed))
