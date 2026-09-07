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


func _graph(section: StringName = &"achilles_wrath_of_peleus") -> ChampionMasteryGraph:
	var graph := GRAPH.new() as ChampionMasteryGraph
	graph.size = Vector2(800, 600)
	graph.configure(_state, section)
	add_child_autofree(graph)
	graph.set_reduced_motion(true)
	return graph


func test_drawn_connections_are_exact_runtime_prerequisites_for_every_doctrine() -> void:
	var graph := _graph()
	await get_tree().process_frame
	for doctrine in PROFILE.mastery_catalog.doctrines:
		graph.configure(_state, doctrine.discipline_id)
		assert_eq(graph.get_all_node_buttons().size(), 9)
		for button: Button in graph.get_all_node_buttons().values():
			var title := button.get_node("MasteryName") as Label
			assert_lte(title.size.x, 143.0, "Wrapped names must remain inside their authored text column")
			assert_lte(title.size.y, 48.0, "Names may occupy at most two rows above the mastery status")
		var edges: Array = graph.get_navigation_snapshot().edges
		var expected := 0
		for node in SkillTreeResolver.champion_doctrine_nodes(doctrine):
			expected += node.prerequisite_node_ids.size() + node.requires_any_node_ids.size()
			for edge in edges:
				if edge.to != node.upgrade_id:
					continue
				assert_true(node.requires_any_node_ids.has(edge.from) if edge.kind == "any" else node.prerequisite_node_ids.has(edge.from))
		assert_eq(edges.size(), expected)
	graph.configure(_state, &"advanced")
	assert_eq(graph.get_all_node_buttons().size(), 9)
	var advanced_edges: Array = graph.get_navigation_snapshot().edges
	assert_eq(advanced_edges.size(), 3, "Only the three authored summit-to-apotheosis prerequisites connect advanced nodes")
	for edge in advanced_edges:
		var node := PROFILE.mastery_catalog.node_catalog().get(edge.to) as SkillTreeNodeData
		assert_true(node.prerequisite_node_ids.has(edge.from))
		assert_eq(edge.kind, "all")


func test_zoom_keeps_anchor_fixed_and_is_bounded_and_read_only() -> void:
	var graph := _graph()
	await get_tree().process_frame
	var before := _state.get_progression_snapshot()
	var anchor := Vector2(385, 240)
	var point_before := (anchor - graph.get_pan_offset()) / graph.get_zoom()
	graph.zoom_by(1.25, anchor)
	var point_after := (anchor - graph.get_pan_offset()) / graph.get_zoom()
	assert_almost_eq(point_after.x, point_before.x, 0.01)
	assert_almost_eq(point_after.y, point_before.y, 0.01)
	graph.zoom_by(1000)
	assert_eq(graph.get_zoom(), ChampionMasteryGraph.MAX_ZOOM)
	graph.zoom_by(0.0001)
	assert_eq(graph.get_zoom(), ChampionMasteryGraph.MIN_ZOOM)
	graph.zoom_by(-1)
	assert_eq(graph.get_zoom(), ChampionMasteryGraph.MIN_ZOOM)
	assert_eq(_state.get_progression_snapshot(), before)


func test_refresh_preserves_view_and_selected_node_and_reports_real_acquisition() -> void:
	var graph := _graph()
	await get_tree().process_frame
	graph.zoom_by(1.35)
	graph.center_on_node(&"achilles_wrath_execution")
	graph.inspect_node(&"achilles_wrath_focused_fury")
	var camera := graph.get_navigation_snapshot()
	_state.champion_progression.grant_purchased_mastery(2)
	graph.configure(_state, &"achilles_wrath_of_peleus")
	assert_eq(graph.get_node_buttons()[&"achilles_wrath_focused_fury"].get_meta("mastery_state"), "available")
	assert_true(bool(_state.purchase_mastery_node(&"achilles_wrath_focused_fury").get("purchased", false)))
	graph.configure(_state, &"achilles_wrath_of_peleus")
	assert_eq(graph.get_zoom(), float(camera.zoom))
	assert_eq(graph.get_pan_offset(), camera.pan_offset)
	assert_eq(graph.get_navigation_snapshot().selected_node_id, &"achilles_wrath_focused_fury")
	assert_eq(graph.get_node_buttons()[&"achilles_wrath_focused_fury"].get_meta("mastery_state"), "acquired")
	assert_eq(graph.get_node_buttons()[&"achilles_wrath_opening_slash"].get_meta("mastery_state"), "available")


func test_search_matches_descriptions_and_keeps_context_without_mutation() -> void:
	var graph := _graph()
	await get_tree().process_frame
	var before := _state.get_progression_snapshot()
	graph.set_search_query("Fureur lucide")
	assert_eq(graph.get_node_buttons().size(), 1)
	assert_eq(graph.get_all_node_buttons().size(), 9)
	graph.set_search_query("bouclier")
	assert_true(graph.get_node_buttons().has(&"achilles_wrath_irrepressible_wrath"))
	graph.set_search_query("aucun_resultat_987")
	assert_true(graph.get_node_buttons().is_empty())
	for button: Button in graph.get_all_node_buttons().values():
		assert_eq(button.focus_mode, Control.FOCUS_NONE)
	graph.set_search_query("")
	assert_eq(graph.get_node_buttons().size(), 9)
	assert_eq(_state.get_progression_snapshot(), before)


func test_click_only_inspects_and_keyboard_selects_a_spatial_neighbor() -> void:
	var graph := _graph()
	await get_tree().process_frame
	var before := _state.get_progression_snapshot()
	watch_signals(graph)
	var root_button := graph.get_node_buttons()[&"achilles_wrath_focused_fury"] as Button
	root_button.pressed.emit()
	assert_signal_emitted_with_parameters(graph, "node_inspected", [&"achilles_wrath_focused_fury"])
	assert_true(root_button.focus_previous.is_empty(), "Shift-Tab can leave the graph")
	var all_buttons := graph.get_node_buttons().values()
	assert_true((all_buttons[-1] as Button).focus_next.is_empty(), "Tab can leave the graph")
	root_button.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_DOWN
	key.pressed = true
	root_button.gui_input.emit(key)
	assert_ne(graph.get_navigation_snapshot().selected_node_id, &"achilles_wrath_focused_fury")
	assert_eq(_state.get_progression_snapshot(), before)


func test_fit_stays_finite_at_supported_viewports_and_reduced_motion_is_immediate() -> void:
	var graph := _graph()
	await get_tree().process_frame
	for viewport_size in [Vector2(460, 350), Vector2(720, 500), Vector2(1100, 750)]:
		graph.size = viewport_size
		graph.fit_graph()
		var view := graph.get_navigation_snapshot()
		assert_true(is_finite(float(view.zoom)))
		assert_gte(float(view.zoom), ChampionMasteryGraph.READABLE_ZOOM, "Default framing keeps mastery names readable")
		assert_true((view.pan_offset as Vector2).is_finite())
		assert_eq(float(view.zoom), float(view.displayed_zoom))
		assert_true(graph.clip_contents)
		graph.zoom_by(1.1)
		assert_eq(float(graph.get_navigation_snapshot().zoom), float(graph.get_navigation_snapshot().displayed_zoom))


func test_first_purchase_pulses_once_and_reduced_motion_removes_animation() -> void:
	var graph := _graph()
	await get_tree().process_frame
	graph.set_reduced_motion(false)
	_state.champion_progression.grant_purchased_mastery(1)
	assert_true(bool(_state.purchase_mastery_node(&"achilles_wrath_focused_fury").get("purchased", false)))
	graph.configure(_state, &"achilles_wrath_of_peleus")
	assert_true((graph.get("_pulse_ids") as Dictionary).has(&"achilles_wrath_focused_fury"))
	graph.set_reduced_motion(true)
	assert_true((graph.get("_pulse_ids") as Dictionary).is_empty())
	graph.configure(_state, &"achilles_wrath_of_peleus")
	assert_true((graph.get("_pulse_ids") as Dictionary).is_empty())


func test_excluded_capstone_stays_explicit_when_no_mastery_points_remain() -> void:
	var champion := _state.champion_progression
	champion.award_encounter_xp(&"graph_fixture_victory", champion.profile.xp_for_level(14), true)
	var doctrine := PROFILE.mastery_catalog.doctrines[0]
	var path: Array = SkillTreeResolver.champion_capstone_paths(doctrine, 14)[0]
	for id in path:
		assert_true(bool(_state.purchase_mastery_node(StringName(id)).get("purchased", false)))
	champion.unspent_mastery_points = 0
	var graph := _graph()
	await get_tree().process_frame
	var excluded_count := 0
	for node in SkillTreeResolver.champion_doctrine_nodes(doctrine):
		if node.node_type != SkillTreeNodeData.NodeType.CAPSTONE or champion.selected_node_ids.has(node.upgrade_id):
			continue
		excluded_count += 1
		var button := graph.get_node_buttons()[node.upgrade_id] as Button
		assert_eq(button.get_meta("mastery_state"), "excluded")
		assert_string_contains((button.get_node("MasteryStatus") as Label).text, "CHOIX EXCLU")
	assert_eq(excluded_count, 1)



func test_long_mastery_name_wraps_into_two_visible_lines() -> void:
	var graph := _graph()
	await get_tree().process_frame
	await get_tree().process_frame
	var button := graph.get_node_buttons()[&"achilles_wrath_opening_slash"] as Button
	var title := button.get_node("MasteryName") as Label
	assert_eq(title.text, "Entaille d’ouverture")
	assert_gte(title.get_line_count(), 2, "The real label must wrap, not merely clip within a narrow rectangle")
	assert_eq(title.get_visible_line_count(), 2, "Both name rows must remain visible above the status (line height %d, box %s)" % [title.get_line_height(), title.size])
	assert_eq(title.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING)
	assert_lte(title.size.x, 143.0)
	assert_lte(title.position.y + title.size.y, (button.get_node("MasteryStatus") as Label).position.y)
