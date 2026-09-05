extends GutTest

const SCREEN_SCENE := preload("res://ui/progression/screens/skill_tree_screen.tscn")
const MAIN_CONTENT: RunContentProfile = preload("res://data/runs/profiles/main_content_profile.tres")
const CHAMPION_CONTENT: RunContentProfile = preload("res://data/runs/profiles/odyssey_content_profile.tres")

var _screen: SkillTreeScreen
var _state: CharacterRunState


func before_each() -> void:
	_screen = SCREEN_SCENE.instantiate() as SkillTreeScreen
	add_child_autofree(_screen)


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.close_for_run_cleanup()
	if _state != null:
		_state.dispose()
		_state = null
	# Refresh removes old controls with queue_free; flush them before GUT counts orphans.
	await wait_process_frames(2)


func test_legacy_search_matches_spell_and_discipline_names_without_mutating_progression() -> void:
	await _open_hero(MAIN_CONTENT, &"warrior")
	var snapshot := _state.get_progression_snapshot()
	var spell := _state.unit.spells[1] as Spell
	_screen.set_search_query(spell.spell_name.to_upper())
	assert_eq(_visible_discipline_ids(), [spell.skill_tree.discipline_id])
	_screen.set_search_query(spell.skill_tree.display_name.to_lower())
	assert_eq(_visible_discipline_ids(), [spell.skill_tree.discipline_id])
	_screen.set_search_query("aucun sort ne porte ce nom")
	assert_true(_screen.get_visible_tab_buttons().is_empty())
	_screen.set_search_query("")
	assert_eq(_screen.get_visible_tab_buttons().size(), 4)
	assert_eq(_state.get_progression_snapshot(), snapshot)


func test_legacy_pending_filter_lists_only_real_unresolved_spell_ranks() -> void:
	await _open_hero(MAIN_CONTENT, &"warrior")
	var spell := _state.unit.spells[2] as Spell
	_state.add_spell_xp(spell.get_effective_spell_id(), spell.skill_tree.ranks[1].required_total_xp)
	_screen.refresh_from_state()
	var snapshot := _state.get_progression_snapshot()
	_screen.set_spell_filter(&"pending")
	assert_eq(_visible_discipline_ids(), [spell.skill_tree.discipline_id])
	_screen.set_spell_filter(&"all")
	assert_eq(_screen.get_visible_tab_buttons().size(), 4)
	assert_eq(_state.get_progression_snapshot(), snapshot)


func test_legacy_search_and_pending_filter_intersect_and_clear_cleanly() -> void:
	await _open_hero(MAIN_CONTENT, &"warrior")
	var first := _state.unit.spells[0] as Spell
	var second := _state.unit.spells[1] as Spell
	_state.add_spell_xp(first.get_effective_spell_id(), first.skill_tree.ranks[1].required_total_xp)
	_state.add_spell_xp(second.get_effective_spell_id(), second.skill_tree.ranks[1].required_total_xp)
	_screen.refresh_from_state()
	var snapshot := _state.get_progression_snapshot()
	_screen.set_spell_filter(&"pending")
	assert_eq(_screen.get_visible_tab_buttons().size(), 2)
	_screen.set_search_query(second.spell_name)
	assert_eq(_visible_discipline_ids(), [second.skill_tree.discipline_id])
	_screen.set_search_query(_state.unit.spells[2].spell_name)
	assert_true(_screen.get_visible_tab_buttons().is_empty())
	_screen.set_search_query("")
	assert_eq(_screen.get_visible_tab_buttons().size(), 2)
	assert_eq(_state.get_progression_snapshot(), snapshot)


func test_legacy_search_never_matches_or_reveals_hidden_upgrade_names() -> void:
	await _open_hero(MAIN_CONTENT, &"warrior")
	var discipline := _state.get_disciplines()[0] as DisciplineData
	var hidden_choice := discipline.ranks[1].choices[0] as SkillUpgradeData
	var snapshot := _state.get_progression_snapshot()
	_screen.set_search_query(hidden_choice.display_name)
	assert_true(_screen.get_visible_tab_buttons().is_empty())
	_screen.set_search_query("")
	_screen._show_discipline(discipline.discipline_id)
	var hidden_view := _screen.get_graph().get_node_view(hidden_choice.upgrade_id)
	assert_not_null(hidden_view)
	if hidden_view == null:
		return
	assert_false(hidden_view.is_content_revealed())
	assert_true(_screen.get_graph().inspect_node_by_id(hidden_choice.upgrade_id))
	var detail := _screen.get_detail_panel().get_detail_text()
	assert_false(detail.contains(hidden_choice.display_name))
	assert_false(detail.contains(hidden_choice.description))
	assert_eq(_state.get_progression_snapshot(), snapshot)


func _visible_discipline_ids() -> Array:
	return _screen.get_visible_tab_buttons().map(func(tab):
		return tab.discipline_id
	)


func test_champion_navigation_exposes_three_doctrines_four_techniques_and_advanced_masteries() -> void:
	await _open_hero(CHAMPION_CONTENT, &"achilles")
	var codex := _screen.get_champion_codex() as ChampionCodex
	assert_not_null(codex)
	assert_true(codex.is_visible_in_tree())
	assert_true(_screen.is_progression_defined())
	assert_eq(_screen.get_tab_count(), 3)
	assert_true(_state.get_spell_progressions().is_empty())
	var snapshot := _state.get_progression_snapshot()
	var strip := codex.get("_spells") as HBoxContainer
	assert_eq(strip.get_child_count(), 4)
	for index in range(4):
		var button := strip.get_child(index) as Button
		assert_true(_label_text(button).contains(_state.unit.spells[index].spell_name))
		var icon := button.find_children("*", "TextureRect", true, false)[0] as TextureRect
		assert_not_null(icon.texture)
	for doctrine in _state.progression_profile.mastery_catalog.doctrines:
		codex.select_section(doctrine.discipline_id)
		assert_eq(codex.get_node_buttons().size(), 9, doctrine.display_name)
	codex.select_section(&"advanced")
	assert_eq(codex.get_node_buttons().size(), 9)
	codex.select_section(&"attributes")
	assert_true(codex.get_node_buttons().is_empty())
	assert_false((codex.get("_search") as LineEdit).visible)
	assert_eq(_state.get_progression_snapshot(), snapshot)


func test_champion_search_filters_named_masteries_and_resets_when_changing_doctrine() -> void:
	await _open_hero(CHAMPION_CONTENT, &"achilles")
	var codex := _screen.get_champion_codex() as ChampionCodex
	var catalog := _state.progression_profile.mastery_catalog
	var node := catalog.node_catalog()[&"achilles_chiron_pelion_reach"] as SkillTreeNodeData
	var snapshot := _state.get_progression_snapshot()
	codex.select_section(node.doctrine_id)
	codex.set_search_query(node.display_name.to_upper())
	assert_eq(codex.get_node_buttons().keys(), [node.upgrade_id])
	codex.set_search_query("aucune maîtrise de ce nom")
	assert_true(codex.get_node_buttons().is_empty())
	codex.set_search_query("")
	assert_eq(codex.get_node_buttons().size(), 9)
	codex.set_search_query(node.display_name)
	codex.select_section(catalog.doctrines[0].discipline_id)
	assert_eq((codex.get("_search") as LineEdit).text, "")
	assert_eq(codex.get_node_buttons().size(), 9)
	assert_eq(_state.get_progression_snapshot(), snapshot)


func test_champion_preview_cannot_purchase_even_when_a_mastery_is_affordable() -> void:
	await _open_hero(CHAMPION_CONTENT, &"achilles")
	_state.begin_encounter()
	assert_true(_state.award_encounter_xp(&"codex_preview_victory", 100, true).granted)
	var codex := _screen.get_champion_codex() as ChampionCodex
	var root := SkillTreeResolver.champion_doctrine_nodes(
		_state.progression_profile.mastery_catalog.doctrines[0]
	)[0] as SkillTreeNodeData
	assert_true(_state.evaluate_mastery_node(root.upgrade_id).allowed)
	var snapshot := _state.get_progression_snapshot()
	codex.inspect_node(root.upgrade_id)
	assert_true(codex.read_only)
	assert_true(codex.get_action_button().disabled)
	codex.get_action_button().pressed.emit()
	assert_eq(_state.get_progression_snapshot(), snapshot)
	assert_true(_state.add_spell_xp(_state.unit.spells[0].get_effective_spell_id(), 100).is_empty())
	assert_eq(_state.get_progression_snapshot(), snapshot)
	codex.get_close_button().pressed.emit()
	assert_false(_screen.visible)


func _open_hero(content: RunContentProfile, hero_id: StringName) -> void:
	# Resolve the production profile without loading scenes from the three rooms.
	var fixture := RunData.new()
	fixture.content_profile = content
	var resolution := RunHeroResolver.resolve_runtime_hero_data(fixture, false)
	assert_true(resolution.is_valid(), str(resolution.errors))
	var hero_data: UnitData = null
	for candidate in resolution.heroes:
		if candidate.get_effective_unit_id() == hero_id:
			hero_data = candidate
	assert_not_null(hero_data)
	_state = CharacterRunState.new()
	assert_true(_state.initialize(Unit.from_data(hero_data), hero_data))
	assert_true(_screen.open_for_state(_state))
	await wait_process_frames(3)


func _label_text(node: Node) -> String:
	var parts := PackedStringArray()
	if node is Label:
		parts.append((node as Label).text)
	for child in node.get_children():
		parts.append(_label_text(child))
	return "\n".join(parts)
