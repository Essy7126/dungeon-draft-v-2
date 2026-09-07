extends GutTest
## Integration checks for the interactive mastery atlas, using isolated heroes.

const PROFILE: CharacterProgressionProfile = preload("res://data/runs/progression/odyssey/achilles_progression_profile.tres")
const CODEX = preload("res://ui/progression/champion/champion_codex.gd")
const FIRST := &"achilles_wrath_focused_fury"
const SECOND := &"achilles_wrath_opening_slash"
var _state: CharacterRunState
var _codex
var _manager_before: Dictionary
var _profile_before: String


func before_each() -> void:
	_manager_before = GameManager.get_inventory_equipment_snapshot().duplicate(true)
	_profile_before = RunProgressionCloneService.semantic_fingerprint(PROFILE)
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
	if is_instance_valid(_codex):
		_codex.queue_free()
	await get_tree().process_frame
	_state.dispose()
	assert_eq(GameManager.get_inventory_equipment_snapshot(), _manager_before, "An isolated codex must leave the active run untouched")
	assert_eq(RunProgressionCloneService.semantic_fingerprint(PROFILE), _profile_before, "Exploration must not modify the authored profile")
	await get_tree().process_frame


func _open(read_only: bool = true) -> void:
	_codex = CODEX.new()
	_codex.configure(_state, read_only)
	add_child(_codex)
	await get_tree().process_frame
	await get_tree().process_frame


func test_graph_toolbar_changes_view_without_spending_and_search_remains_inspectable() -> void:
	await _open()
	var graph = _codex.get_graph()
	assert_not_null(graph)
	var before := _state.get_progression_snapshot().duplicate(true)
	for button_name in ["ZoomIn", "ZoomOut", "FitGraph", "NextAvailable"]:
		assert_not_null(_codex.find_child(button_name, true, false), "Toolbar has " + button_name)
	var zoom_in := _codex.find_child("ZoomIn", true, false) as Button
	var zoom_before: float = graph.get_navigation_snapshot().zoom
	zoom_in.pressed.emit()
	assert_gt(float(graph.get_navigation_snapshot().zoom), zoom_before)
	_codex.find_child("ZoomOut", true, false).pressed.emit()
	_codex.find_child("FitGraph", true, false).pressed.emit()
	_codex.set_search_query("Fureur lucide")
	assert_eq(_codex.get_node_buttons().size(), 1)
	assert_true(_codex.get_node_buttons().has(FIRST))
	_codex.get_node_buttons()[FIRST].pressed.emit()
	assert_eq(StringName(graph.get_navigation_snapshot().selected_node_id), FIRST)
	assert_true(_codex.get_action_button().disabled)
	_codex.set_search_query("impossible_query_zz")
	assert_true(_codex.get_node_buttons().is_empty())
	_codex.set_search_query("")
	assert_eq(_codex.get_node_buttons().size(), 9)
	assert_eq(_state.get_progression_snapshot(), before)


func test_purchase_updates_existing_graph_and_blocks_double_spending() -> void:
	assert_true(_state.champion_progression.grant_purchased_mastery(1))
	await _open(false)
	var graph = _codex.get_graph()
	graph.zoom_by(1.15)
	var view_before: Dictionary = graph.get_navigation_snapshot()
	_codex.inspect_node(FIRST)
	assert_false(_codex.get_action_button().disabled)
	watch_signals(_codex)
	_codex.get_action_button().pressed.emit()
	assert_eq(_state.champion_progression.selected_node_ids, [FIRST])
	assert_eq(_state.champion_progression.unspent_mastery_points, 0)
	assert_signal_emitted(_codex, "build_changed")
	assert_same(_codex.get_graph(), graph, "Purchase refreshes the existing graph")
	assert_eq(float(graph.get_navigation_snapshot().zoom), float(view_before.zoom))
	assert_true(_codex.get_action_button().disabled)
	var purchased := _state.get_progression_snapshot().duplicate(true)
	_codex.get_action_button().pressed.emit()
	assert_eq(_state.get_progression_snapshot(), purchased, "Replayed activation cannot spend again")
	_codex.inspect_node(SECOND)
	assert_true(_codex.get_action_button().disabled, "The next node requires points")


func test_next_available_selects_a_legal_choice_and_never_purchases_it() -> void:
	assert_true(_state.champion_progression.grant_purchased_mastery(1))
	await _open(false)
	var before := _state.get_progression_snapshot().duplicate(true)
	var next_button := _codex.find_child("NextAvailable", true, false) as Button
	assert_not_null(next_button)
	assert_false(next_button.disabled)
	next_button.pressed.emit()
	var selected := StringName(_codex.get_graph().get_navigation_snapshot().selected_node_id)
	assert_ne(selected, &"")
	assert_true(bool(_state.evaluate_mastery_node(selected).get("allowed", false)))
	assert_false(_codex.get_action_button().disabled)
	assert_eq(_state.get_progression_snapshot(), before)


func test_section_spell_and_attribute_navigation_remains_read_only_at_high_level() -> void:
	assert_true(bool(_state.award_encounter_xp(&"dynamic_codex_fixture", 1700, true).get("granted", false)))
	await _open(true)
	var before := _state.get_progression_snapshot().duplicate(true)
	for doctrine in PROFILE.mastery_catalog.doctrines:
		_codex.select_section(doctrine.discipline_id)
		assert_eq(_codex.get_node_buttons().size(), 9)
		for node_id in _codex.get_node_buttons():
			_codex.inspect_node(node_id)
			assert_true(_codex.get_action_button().disabled)
	_codex.select_section(&"advanced")
	assert_eq(_codex.get_node_buttons().size(), 9)
	_codex.select_section(&"attributes")
	assert_false(_codex.get_graph().is_visible_in_tree())
	for button in _codex.get("_content").find_children("*", "Button", true, false):
		assert_true(button.disabled, "Attribute investments are unavailable in consultation")
	for spell in PROFILE.spells:
		_codex._inspect_spell(spell)
		assert_true(_codex.get_action_button().disabled)
	_codex.select_section(PROFILE.mastery_catalog.doctrines[0].discipline_id)
	assert_true(_codex.get_graph().is_visible_in_tree())
	assert_eq(_state.get_progression_snapshot(), before)


func test_read_only_programmatic_purchase_is_rejected_even_with_points() -> void:
	assert_true(_state.champion_progression.grant_purchased_mastery(1))
	await _open(true)
	_codex.inspect_node(FIRST)
	var before := _state.get_progression_snapshot().duplicate(true)
	watch_signals(_codex)
	_codex.get_action_button().pressed.emit()
	assert_eq(_state.get_progression_snapshot(), before)
	assert_signal_not_emitted(_codex, "build_changed")


func test_doctrine_labels_fit_their_buttons_at_720p() -> void:
	await _open(true)
	_codex.size = Vector2(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	var navigation: Dictionary = _codex.get("_nav_buttons")
	for doctrine in PROFILE.mastery_catalog.doctrines:
		var button := navigation[doctrine.discipline_id] as Button
		var bounds := button.get_global_rect().grow(1.0)
		for label in button.find_children("*", "Label", true, false):
			assert_true(bounds.encloses(label.get_global_rect()), "%s: doctrine label remains inside its card: %s" % [doctrine.display_name, label.text])


func test_returning_to_a_doctrine_restores_its_inspected_node_in_view() -> void:
	await _open(true)
	_codex.size = Vector2(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	var before := _state.get_progression_snapshot().duplicate(true)
	var final_node := &"achilles_wrath_scourge_of_troy"
	_codex.inspect_node(final_node)
	_codex.select_section(PROFILE.mastery_catalog.doctrines[2].discipline_id)
	_codex.inspect_node(&"achilles_aeacus_active_guard")
	_codex.select_section(PROFILE.mastery_catalog.doctrines[0].discipline_id)
	var graph = _codex.get_graph()
	var navigation: Dictionary = graph.get_navigation_snapshot()
	assert_eq(StringName(navigation.selected_node_id), final_node)
	var node := graph.get_node_buttons()[final_node] as Button
	var target_rect := Rect2(node.position * float(navigation.zoom) + Vector2(navigation.pan_offset), node.size * float(navigation.zoom))
	assert_true(Rect2(Vector2.ZERO, graph.size).grow(1.0).encloses(target_rect), "Returning to a doctrine brings its remembered mastery into view")
	assert_true(_codex.get_action_button().disabled)
	assert_eq(_state.get_progression_snapshot(), before)
