extends GutTest

const ELF_DATA := preload("res://data/units/alliés/elfe.tres")
const STATUS_BUTTON_SCENE := preload(
	"res://ui/progression/components/skill_tree_status_button.tscn"
)
const TOOLTIP_SCENE := preload(
	"res://ui/progression/components/skill_tree_tooltip_panel.tscn"
)
const SCREEN_SCENE := preload(
	"res://ui/progression/screens/skill_tree_screen.tscn"
)
const LAB_SCENE := preload(
	"res://ui/progression/lab/skill_tree_graybox_lab.tscn"
)
const RUN_DATA := preload(
	"res://data/runs/fixed_trio_prototype_run.tres"
)


class FakeProgressionController:
	extends Node

	signal discipline_xp_gained(
		character_id,
		discipline_id,
		amount,
		snapshot
	)

	var states: Dictionary = {}

	func get_character_state(character_id: StringName) -> CharacterRunState:
		return states.get(character_id) as CharacterRunState


class FakeCombatContext:
	extends Node

	var active_unit: Unit = null

	func get_active_unit() -> Unit:
		return active_unit


var _states_to_dispose: Array[CharacterRunState] = []


func after_each() -> void:
	GameManager.cleanup_run_state()
	for state in _states_to_dispose:
		if state != null:
			state.dispose()
	_states_to_dispose.clear()


func test_visual_presentation_covers_all_five_player_states() -> void:
	var state := _make_elf_state()
	var discipline := _discipline(state, &"archer")
	var progress := state.get_discipline_progress(&"archer")

	var locked_xp := _presentation(
		discipline,
		_node(discipline, &"elf_archer_perfect_sight"),
		progress
	)
	assert_eq(
		locked_xp["state"],
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_XP
	)
	assert_string_contains(locked_xp["reason"], "12 XP requis")

	state.add_discipline_xp(&"archer", 18)
	assert_true(state.select_upgrade(
		&"archer",
		2,
		&"elf_archer_eagle_eye"
	))
	var selected := _presentation(
		discipline,
		_node(discipline, &"elf_archer_eagle_eye"),
		progress
	)
	var available := _presentation(
		discipline,
		_node(discipline, &"elf_archer_long_range"),
		progress
	)
	var locked_branch := _presentation(
		discipline,
		_node(discipline, &"elf_archer_hindering_arrow"),
		progress
	)
	var future := _presentation(
		discipline,
		_node(discipline, &"elf_archer_perfect_shot"),
		progress
	)
	assert_eq(
		selected["state"],
		SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED
	)
	assert_eq(
		available["state"],
		SkillTreeVisualPresentation.SkillTreeVisualState.AVAILABLE
	)
	assert_eq(
		locked_branch["state"],
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_BRANCH
	)
	assert_string_contains(locked_branch["reason"], "Œil d’aigle")
	assert_eq(
		future["state"],
		SkillTreeVisualPresentation.SkillTreeVisualState.FUTURE
	)
	assert_string_contains(future["reason"], "choix précédents")


func test_status_button_tracks_elf_archer_and_ignores_other_signals() -> void:
	var state := _make_elf_state()
	var controller := FakeProgressionController.new()
	controller.states[&"elf"] = state
	add_child_autofree(controller)
	var button := STATUS_BUTTON_SCENE.instantiate() as SkillTreeStatusButton
	button.progression_controller = controller
	add_child_autofree(button)
	await get_tree().process_frame

	assert_true(button.visible)
	assert_eq(button.get_rank_text(), "R1")
	assert_eq(button.get_xp_text(), "0 / 3")
	assert_false(button.has_pending_badge())

	state.add_discipline_xp(&"archer", 3)
	controller.discipline_xp_gained.emit(
		&"elf",
		&"archer",
		3,
		{}
	)
	assert_eq(button.get_rank_text(), "R2")
	assert_eq(button.get_xp_text(), "3 / 7")
	assert_true(button.has_pending_badge())

	state.add_discipline_xp(&"archer", 1)
	controller.discipline_xp_gained.emit(
		&"mage",
		&"archer",
		1,
		{}
	)
	assert_eq(button.get_xp_text(), "3 / 7")
	controller.discipline_xp_gained.emit(
		&"elf",
		&"archer",
		1,
		{}
	)
	assert_eq(button.get_xp_text(), "4 / 7")

	controller.states.clear()
	button.refresh_from_state()
	assert_false(button.visible)


func test_structured_tooltip_lists_four_disciplines_and_named_path() -> void:
	var state := _make_elf_state()
	state.add_discipline_xp(&"archer", 12)
	assert_true(state.select_upgrade(
		&"archer", 2, &"elf_archer_eagle_eye"
	))
	assert_true(state.select_upgrade(
		&"archer", 3, &"elf_archer_long_range"
	))
	assert_true(state.select_upgrade(
		&"archer", 4, &"elf_archer_perfect_sight"
	))
	state.add_discipline_xp(&"assassin", 3)
	var tooltip := TOOLTIP_SCENE.instantiate() as SkillTreeTooltipPanel
	add_child_autofree(tooltip)
	await get_tree().process_frame
	tooltip.refresh_from_state(state)
	var text := tooltip.get_summary_text()

	for discipline_name in ["Archer", "Assassin", "Mage", "Soigneur"]:
		assert_string_contains(text, discipline_name)
	assert_string_contains(
		text,
		"Œil d’aigle → Longue portée → Vue parfaite"
	)
	assert_string_contains(text, "prochain seuil : 18")
	assert_string_contains(text, "choix en attente")
	assert_eq(tooltip.XP_REMINDER, (
		"Chaque lancement réussi d’un sort rapporte 1 XP à sa discipline."
	))


func test_consultative_screen_builds_real_graph_without_mutation() -> void:
	var state := _make_elf_state()
	state.add_discipline_xp(&"archer", 18)
	assert_true(state.select_upgrade(
		&"archer", 2, &"elf_archer_eagle_eye"
	))
	assert_true(state.select_upgrade(
		&"archer", 3, &"elf_archer_long_range"
	))
	var controller := FakeProgressionController.new()
	controller.states[&"elf"] = state
	add_child_autofree(controller)
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	var before := state.get_discipline_progress_snapshot(&"archer")

	assert_true(screen.open_for_character(&"elf", controller, &"archer"))
	assert_true(screen.visible)
	assert_true(screen.is_consultative())
	assert_eq(screen.get_tab_count(), 4)
	assert_eq(screen.get_graph().get_node_view_count(), 19)
	assert_eq(screen.get_graph().get_connection_count(), 16)
	assert_true(
		screen.get_graph().get_connection_states().has(&"selected")
	)
	assert_true(
		screen.get_graph().get_connection_states().has(&"incompatible")
	)

	assert_true(screen.get_graph().inspect_node_by_id(
		&"elf_archer_long_range"
	))
	assert_string_contains(
		screen.get_detail_panel().get_detail_text(),
		"LONGUE PORTÉE"
	)
	assert_string_contains(
		screen.get_detail_panel().get_detail_text(),
		"Œil d’aigle"
	)
	var node_view := screen.get_graph().get_node_view(
		&"elf_archer_long_range"
	)
	assert_false(node_view.has_signal("pressed"))
	assert_true(node_view.is_consultative())
	assert_eq(
		state.get_discipline_progress_snapshot(&"archer"),
		before
	)
	screen.close_screen()
	assert_false(screen.visible)
	assert_eq(
		state.get_discipline_progress_snapshot(&"archer"),
		before
	)


func test_ui_cancel_closes_screen_without_awarding_xp() -> void:
	var state := _make_elf_state()
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	var before := state.get_discipline_progress_snapshot(&"archer")
	assert_true(screen.open_for_state(state))
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	screen._unhandled_input(cancel)
	assert_false(screen.visible)
	assert_eq(
		state.get_discipline_progress_snapshot(&"archer"),
		before
	)


func test_persistent_run_ui_uses_refined_dock_and_restores_combat_controls() -> void:
	assert_true(GameManager._prepare_preconfigured_run(RUN_DATA, [
		"res://data/units/alliés/elfe.tres",
		"res://data/units/alliés/mage.tres",
		"res://data/units/alliés/Gardien.tres",
	]))
	var run_ui := GameManager.get_persistent_run_ui()
	var context := FakeCombatContext.new()
	context.active_unit = GameManager.get_character_state(&"elf").unit
	add_child_autofree(context)
	var hud = run_ui.bind_combat_context(context)
	hud.set_player_controls_enabled(true)
	var state := GameManager.get_character_state(&"elf")
	var before := state.get_discipline_progress_snapshot(&"archer")

	var button := run_ui.get_skill_tree_status_button()
	assert_false(button.visible)
	var dock_button := hud.get_node("%SkillsButton") as Button
	assert_false(dock_button.disabled)
	dock_button.pressed.emit()
	assert_true(run_ui.get_skill_tree_screen().visible)
	assert_false(bool(hud.get("_player_controls_enabled")))
	assert_eq(run_ui.get_skill_tree_screen().get_active_theme().character_id, &"elf")
	assert_false(run_ui.open_pause_menu())
	assert_false(run_ui.is_pause_menu_open())
	run_ui.get_skill_tree_screen().close_screen()
	assert_false(run_ui.get_skill_tree_screen().visible)
	assert_true(bool(hud.get("_player_controls_enabled")))
	assert_true(run_ui.open_pause_menu())
	assert_true(run_ui.is_pause_menu_open())
	assert_true(get_tree().paused)
	assert_true(run_ui.close_pause_menu())
	assert_false(get_tree().paused)
	assert_true(bool(hud.get("_player_controls_enabled")))
	assert_eq(
		state.get_discipline_progress_snapshot(&"archer"),
		before
	)


func test_lab_scene_exposes_requested_graybox_states() -> void:
	var lab := LAB_SCENE.instantiate() as SkillTreeGrayboxLab
	add_child_autofree(lab)
	await get_tree().process_frame
	lab.show_scenario(SkillTreeGrayboxLab.Scenario.PREREQUISITE_LOCKED)
	await get_tree().process_frame
	var graph := lab.skill_tree_screen.get_graph()
	assert_eq(graph.get_node_view_count(), 19)
	assert_eq(
		_state_of(graph, &"__base_rank_1"),
		SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED
	)
	assert_eq(
		_state_of(graph, &"elf_archer_eagle_eye"),
		SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED
	)
	assert_eq(
		_state_of(graph, &"elf_archer_long_range"),
		SkillTreeVisualPresentation.SkillTreeVisualState.AVAILABLE
	)
	assert_eq(
		_state_of(graph, &"elf_archer_repel_arrow"),
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_BRANCH
	)
	assert_eq(
		_state_of(graph, &"elf_archer_perfect_shot"),
		SkillTreeVisualPresentation.SkillTreeVisualState.FUTURE
	)
	lab.show_rank_one_preview()
	await get_tree().process_frame
	var rank_one_progress := (
		lab.preview_state.get_discipline_progress(&"archer")
	)
	assert_eq(rank_one_progress.xp, 0)
	assert_eq(rank_one_progress.rank, 1)
	assert_eq(
		_state_of(lab.skill_tree_screen.get_graph(), &"elf_archer_eagle_eye"),
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_XP
	)


func _make_elf_state() -> CharacterRunState:
	var state := CharacterRunState.new()
	assert_true(state.initialize(Unit.from_data(ELF_DATA), ELF_DATA))
	_states_to_dispose.append(state)
	return state


func _discipline(
		state: CharacterRunState,
		discipline_id: StringName
	) -> DisciplineData:
	for discipline in state.get_disciplines():
		if discipline != null and discipline.discipline_id == discipline_id:
			return discipline
	return null


func _node(
		discipline: DisciplineData,
		node_id: StringName
	) -> SkillUpgradeData:
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		for candidate in rank_data.choices:
			if candidate != null and candidate.upgrade_id == node_id:
				return candidate
	return null


func _presentation(
		discipline: DisciplineData,
		node: SkillUpgradeData,
		progress: DisciplineProgressState
	) -> Dictionary:
	return SkillTreeVisualPresentation.describe_node(
		discipline,
		node,
		progress,
		progress.get_selected_upgrade_ids(),
		progress.get_pending_rank_choices()
	)


func _state_of(
		graph: SkillTreeGraphView,
		node_id: StringName
	) -> int:
	var view := graph.get_node_view(node_id)
	return int(view.visual_presentation.get("state", -1))
