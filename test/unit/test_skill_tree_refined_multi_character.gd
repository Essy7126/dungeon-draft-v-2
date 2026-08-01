extends GutTest

const SCREEN_SCENE := preload(
	"res://ui/progression/screens/skill_tree_screen.tscn"
)

const CASES := [
	{
		"unit": "res://data/units/alliés/elfe.tres",
		"theme": "res://data/ui/elf_hud_theme_refined.tres",
		"branches": {
			&"archer": 5,
			&"assassin": 3,
			&"mage": 3,
			&"healer": 3,
		},
	},
	{
		"unit": "res://data/units/alliés/mage.tres",
		"theme": "res://data/ui/mage_hud_theme_refined.tres",
		"branches": {
			&"mage_fire": 1,
			&"mage_ice": 1,
			&"mage_lightning": 1,
			&"mage_earth": 1,
		},
	},
	{
		"unit": "res://data/units/alliés/Gardien.tres",
		"theme": "res://data/ui/guardian_hud_theme_refined.tres",
		"branches": {},
	},
	{
		"unit": "res://data/units/alliés/Guerrier.tres",
		"theme": "res://data/ui/warrior_hud_theme_refined.tres",
		"branches": {},
	},
	{
		"unit": "res://data/units/alliés/healer.tres",
		"theme": "res://data/ui/druid_hud_theme_refined.tres",
		"branches": {},
	},
	{
		"unit": "res://data/units/alliés/Assassin.tres",
		"theme": "res://data/ui/assassin_hud_theme_refined.tres",
		"branches": {},
	},
	{
		"unit": "res://data/units/alliés/Necromant.tres",
		"theme": "res://data/ui/necromancer_hud_theme_refined.tres",
		"branches": {},
	},
	{
		"unit": "res://data/units/alliés/Hoplite.tres",
		"theme": "res://data/ui/hoplite_hud_theme_refined.tres",
		"branches": {},
	},
]

var _states: Array[CharacterRunState] = []


func after_each() -> void:
	for state in _states:
		if state != null:
			state.dispose()
	_states.clear()


func test_eight_characters_use_hud_identity_and_only_real_branches() -> void:
	for case_data in CASES:
		var state := _state(case_data["unit"])
		var host := Control.new()
		host.size = Vector2(1920, 1080)
		add_child_autofree(host)
		var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
		host.add_child(screen)
		await get_tree().process_frame
		assert_true(screen.open_for_state(state, &""), case_data["unit"])
		for _frame in range(3):
			await get_tree().process_frame
		var theme := load(case_data["theme"]) as CharacterHUDThemeData
		assert_same(screen.get_active_theme(), theme, case_data["unit"])
		assert_same(screen.get_node("%IdentityBadge").texture, theme.discipline_emblem_texture)
		assert_string_contains(
			screen.get_node("%TitleLabel").text,
			state.unit.unit_name.to_upper()
		)
		var branches: Dictionary = case_data["branches"]
		assert_eq(screen.get_tab_count(), branches.size(), case_data["unit"])
		if branches.is_empty():
			assert_false(screen.is_progression_defined())
			assert_true(screen.get_layout_snapshot()["empty_state_visible"])
			assert_eq(screen.get_graph().get_node_view_count(), 0)
			assert_string_contains(
				screen.get_detail_panel().get_detail_text(),
				"PROGRESSION NON DÉFINIE"
			)
			assert_false(
				screen.get_detail_panel().get_detail_text().contains("Tir précis")
			)
		else:
			assert_true(screen.is_progression_defined())
			assert_false(screen.get_layout_snapshot()["empty_state_visible"])
			for tab in screen.get_tab_buttons():
				tab.pressed.emit()
				await get_tree().process_frame
				assert_eq(
					screen.get_graph().get_node_view_count(),
					branches[tab.discipline_id],
					"%s / %s" % [case_data["unit"], tab.discipline_id]
				)
		host.queue_free()
		await get_tree().process_frame


func test_branch_navigation_exposes_rank_xp_next_threshold_and_path() -> void:
	var state := _state(CASES[0]["unit"])
	state.add_discipline_xp(&"archer", 7)
	assert_true(state.select_upgrade(&"archer", 2, &"elf_archer_eagle_eye"))
	var screen := await _open_screen(state, &"archer", Vector2(1920, 1080))
	var archer_tab := screen.get_tab_buttons()[0]
	var snapshot := archer_tab.get_layout_snapshot()
	assert_eq(snapshot["xp_text"], "7 / 12 XP")
	assert_eq(snapshot["next_rank_text"], "Prochain rang : 4")
	assert_string_contains(snapshot["path_text"], "Œil d’aigle")
	assert_true(snapshot["progress_visible"])
	var mage_state := _state(CASES[1]["unit"])
	var mage_screen := await _open_screen(
		mage_state, &"mage_fire", Vector2(1920, 1080)
	)
	var mage_snapshot := mage_screen.get_tab_buttons()[0].get_layout_snapshot()
	assert_eq(mage_snapshot["xp_text"], "0 XP")
	assert_eq(mage_snapshot["next_rank_text"], "Progression non définie")
	assert_false(mage_snapshot["progress_visible"])


func test_nodes_and_detail_distinguish_acquired_available_excluded_and_future() -> void:
	var state := _state(CASES[0]["unit"])
	state.add_discipline_xp(&"archer", 18)
	assert_true(state.select_upgrade(&"archer", 2, &"elf_archer_eagle_eye"))
	var screen := await _open_screen(state, &"archer", Vector2(1920, 1080))
	var graph := screen.get_graph()
	var contracts := {
		&"elf_archer_eagle_eye": [
			SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED,
			"ACQUIS",
			"ACQUIS",
		],
		&"elf_archer_long_range": [
			SkillTreeVisualPresentation.SkillTreeVisualState.AVAILABLE,
			"DISPONIBLE",
			"CHOISIR APRÈS LE COMBAT",
		],
		&"elf_archer_repel_arrow": [
			SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_BRANCH,
			"EXCLU",
			"CHOIX EXCLU",
		],
		&"elf_archer_perfect_shot": [
			SkillTreeVisualPresentation.SkillTreeVisualState.FUTURE,
			"VERROUILLÉ",
			"VERROUILLÉ",
		],
	}
	for node_id in contracts:
		var view := graph.get_node_view(node_id)
		assert_eq(int(view.visual_presentation["state"]), contracts[node_id][0], str(node_id))
		assert_eq(view.get_node("%StateText").text, contracts[node_id][1], str(node_id))
		assert_true(graph.inspect_node_by_id(node_id))
		assert_true(view.is_inspection_selected())
		assert_eq(
			screen.get_detail_panel().get_action_button().text,
			contracts[node_id][2],
			str(node_id)
		)


func test_existing_selection_flow_updates_immediately_without_screen_mutation() -> void:
	var state := _state(CASES[0]["unit"])
	state.add_discipline_xp(&"archer", 7)
	assert_true(state.select_upgrade(&"archer", 2, &"elf_archer_eagle_eye"))
	var screen := await _open_screen(state, &"archer", Vector2(1920, 1080))
	var progress := state.get_discipline_progress(&"archer")
	var before := progress.get_selected_upgrade_ids()
	assert_true(screen.get_graph().inspect_node_by_id(&"elf_archer_long_range"))
	assert_eq(progress.get_selected_upgrade_ids(), before)
	assert_true(state.select_upgrade(&"archer", 3, &"elf_archer_long_range"))
	screen.refresh_from_state()
	await get_tree().process_frame
	var refreshed := screen.get_graph().get_node_view(&"elf_archer_long_range")
	assert_eq(
		int(refreshed.visual_presentation["state"]),
		SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED
	)
	assert_eq(refreshed.get_node("%StateText").text, "ACQUIS")


func test_four_stable_zones_fit_three_resolutions_for_all_characters() -> void:
	for resolution in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]:
		for case_data in CASES:
			var state := _state(case_data["unit"])
			var screen := await _open_screen(state, &"", resolution)
			var layout := screen.get_layout_snapshot()
			var outer: Rect2 = layout["outer_global"]
			_assert_inside(outer, layout["screen_global"], "outer %s" % resolution)
			for zone_name in ["header_global", "branch_global", "canvas_global", "detail_global"]:
				_assert_inside(layout[zone_name], outer, "%s %s" % [zone_name, resolution])
			var branch: Rect2 = layout["branch_global"]
			var canvas: Rect2 = layout["canvas_global"]
			var detail: Rect2 = layout["detail_global"]
			assert_lte(branch.end.x, canvas.position.x + 1.0)
			assert_lte(canvas.end.x, detail.position.x + 1.0)
			screen.get_parent().queue_free()
			await get_tree().process_frame


func test_keyboard_shortcut_closes_and_focus_navigation_is_available() -> void:
	var state := _state(CASES[0]["unit"])
	var screen := await _open_screen(state, &"archer", Vector2(1920, 1080))
	assert_false(screen.get_tab_buttons()[0].focus_neighbor_right.is_empty())
	var event := InputEventKey.new()
	event.physical_keycode = KEY_K
	event.pressed = true
	screen._unhandled_input(event)
	assert_false(screen.visible)


func _state(path: String) -> CharacterRunState:
	var data := load(path) as UnitData
	var state := CharacterRunState.new()
	assert_true(state.initialize(Unit.from_data(data), data), path)
	_states.append(state)
	return state


func _open_screen(
		state: CharacterRunState,
		discipline_id: StringName,
		resolution: Vector2
	) -> SkillTreeScreen:
	var host := Control.new()
	host.size = resolution
	add_child_autofree(host)
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	host.add_child(screen)
	await get_tree().process_frame
	assert_true(screen.open_for_state(state, discipline_id))
	for _frame in range(3):
		await get_tree().process_frame
	return screen


func _assert_inside(inner: Rect2, outer: Rect2, context: String) -> void:
	assert_gte(inner.position.x, outer.position.x - 1.0, context)
	assert_gte(inner.position.y, outer.position.y - 1.0, context)
	assert_lte(inner.end.x, outer.end.x + 1.0, context)
	assert_lte(inner.end.y, outer.end.y + 1.0, context)
