extends GutTest

const PROFILE: CharacterProgressionProfile = preload("res://data/runs/progression/odyssey/achilles_progression_profile.tres")
const CODEX = preload("res://ui/progression/champion/champion_codex.gd")
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

func _codex(read_only: bool = false) -> ChampionCodex:
	var codex := CODEX.new() as ChampionCodex
	codex.configure(_state, read_only)
	add_child_autofree(codex)
	return codex

func test_all_three_doctrines_are_browsable_without_spending_or_cast_xp() -> void:
	var codex := _codex(true)
	await get_tree().process_frame
	var before := _state.get_progression_snapshot()
	for doctrine in PROFILE.mastery_catalog.doctrines:
		codex.select_section(doctrine.discipline_id)
		assert_eq(codex.get_node_buttons().size(), 9)
		for node_id in codex.get_node_buttons():
			codex.inspect_node(node_id)
			assert_true(codex.get_action_button().disabled)
	codex.select_section(&"advanced")
	assert_eq(codex.get_node_buttons().size(), 9)
	assert_eq(_state.get_progression_snapshot(), before)

func test_node_preview_then_purchase_uses_same_state_and_refreshes_points() -> void:
	_state.champion_progression.grant_purchased_mastery(1)
	var codex := _codex()
	await get_tree().process_frame
	codex.inspect_node(&"achilles_wrath_focused_fury")
	assert_false(codex.get_action_button().disabled)
	assert_true(_state.champion_progression.selected_node_ids.is_empty())
	watch_signals(codex)
	codex.get_action_button().pressed.emit()
	assert_true(_state.champion_progression.selected_node_ids.has(&"achilles_wrath_focused_fury"))
	assert_eq(_state.champion_progression.unspent_mastery_points, 0)
	assert_signal_emitted(codex, "build_changed")
	assert_true(codex.get_action_button().disabled)

func test_search_filters_navigation_without_mutation_and_close_is_signal_only() -> void:
	var codex := _codex(true)
	await get_tree().process_frame
	var before := _state.get_progression_snapshot()
	codex.set_search_query("Fureur lucide")
	assert_eq(codex.get_node_buttons().size(), 1)
	codex.set_search_query("no_such_mastery")
	assert_true(codex.get_node_buttons().is_empty())
	watch_signals(codex)
	codex.get_close_button().pressed.emit()
	assert_signal_emitted(codex, "close_requested")
	assert_eq(_state.get_progression_snapshot(), before)


func test_grimoire_host_opens_the_requested_doctrine_and_defaults_to_the_first() -> void:
	var host = load("res://ui/progression/screens/skill_tree_screen.tscn").instantiate()
	add_child_autofree(host)
	await get_tree().process_frame
	assert_true(host.open_for_state(_state, &"achilles_aegis_of_aeacus"))
	await get_tree().process_frame
	var codex := host.get_champion_codex() as ChampionCodex
	assert_not_null(codex)
	assert_true(codex.get_node_buttons().has(&"achilles_aeacus_active_guard"))
	assert_true(codex.read_only)
	codex.select_section(&"archer")
	assert_true(codex.get_node_buttons().has(&"achilles_wrath_focused_fury"))
	watch_signals(host)
	codex.get_close_button().pressed.emit()
	assert_signal_emitted(host, "screen_closed")
	assert_false(host.visible)
