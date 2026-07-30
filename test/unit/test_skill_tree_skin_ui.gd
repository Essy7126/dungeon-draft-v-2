extends GutTest

const ELF_DATA := preload("res://data/units/alliés/elfe.tres")
const SKIN := preload(
	"res://ui/progression/skin/dungeon_draft_skill_tree_skin.tres"
)
const VISUAL_MAP := preload(
	"res://ui/progression/skin/elf_archer_visual_map.tres"
)
const SCREEN_SCENE := preload(
	"res://ui/progression/screens/skill_tree_screen.tscn"
)
const STATUS_BUTTON_SCENE := preload(
	"res://ui/progression/components/skill_tree_status_button.tscn"
)
const GLYPH_SCENE := preload(
	"res://ui/progression/components/skill_tree_effect_glyph.tscn"
)
const LAB_SCENE := preload(
	"res://ui/progression/lab/skill_tree_graybox_lab.tscn"
)

const ASSET_DIRECTORY := (
	"res://asset/ui/dungeon_draft/arbre_compétences/"
)
const REQUIRED_SOURCE_ASSETS := [
	"skill_tree_panel_main.png.png",
	"skill_details_panel.png.png",
	"skill_node_standard.png.png",
	"skill_node_frame_base.png",
	"skill_character_tab_base.png",
	"skill_discipline_tab_base.png.png",
	"skill_xp_bar_frame.png.png",
	"skill_state_lock.svg.png",
	"skill_state_purchased.svg.png",
	"skill_state_excluded.svg.png",
	"glyph_damage.png",
	"glyph_area..png",
]
const EXPECTED_NODE_IDS := [
	&"__base_rank_1",
	&"elf_archer_eagle_eye",
	&"elf_archer_repel_arrow",
	&"elf_archer_long_range",
	&"elf_archer_piercing_shot",
	&"elf_archer_hindering_arrow",
	&"elf_archer_impact_bolt",
	&"elf_archer_perfect_sight",
	&"elf_archer_stabilization",
	&"elf_archer_barbed_tip",
	&"elf_archer_open_breach",
	&"elf_archer_pin_arrow",
	&"elf_archer_tactical_retreat",
	&"elf_archer_siege_bolt",
	&"elf_archer_shatter",
	&"elf_archer_perfect_shot",
	&"elf_archer_transpiercing_bolt",
	&"elf_archer_siege_arrow",
	&"elf_archer_stopping_arrow",
]


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


var _states_to_dispose: Array[CharacterRunState] = []


func after_each() -> void:
	for state in _states_to_dispose:
		if state != null:
			state.dispose()
	_states_to_dispose.clear()


func test_skin_loads_every_runtime_source_and_import_sidecar() -> void:
	assert_true(
		SKIN.get_missing_essential_textures().is_empty(),
		str(SKIN.get_missing_essential_textures())
	)
	for asset_name in REQUIRED_SOURCE_ASSETS:
		var asset_path: String = ASSET_DIRECTORY + str(asset_name)
		assert_true(FileAccess.file_exists(asset_path), asset_path)
		assert_true(
			FileAccess.file_exists(asset_path + ".import"),
			asset_path + ".import"
		)
		assert_not_null(load(asset_path), asset_path)
	assert_not_null(SKIN.get_node_frame(1))
	assert_not_null(SKIN.get_node_frame(3))
	assert_not_null(SKIN.get_node_frame(5))
	assert_not_null(SKIN.get_state_texture(&"locked"))
	assert_not_null(SKIN.get_state_texture(&"selected"))
	assert_not_null(SKIN.get_state_texture(&"excluded"))


func test_visual_map_covers_the_base_and_all_eighteen_archer_nodes() -> void:
	assert_eq(VISUAL_MAP.get_entry_count(), 19)
	assert_true(
		VISUAL_MAP.get_validation_errors().is_empty(),
		str(VISUAL_MAP.get_validation_errors())
	)
	var actual_ids := VISUAL_MAP.get_node_ids()
	var expected_ids: Array[StringName] = []
	expected_ids.assign(EXPECTED_NODE_IDS)
	actual_ids.sort()
	expected_ids.sort()
	assert_eq(actual_ids, expected_ids)
	for node_id in expected_ids:
		var visual := VISUAL_MAP.get_visual(node_id)
		assert_not_null(visual, str(node_id))
		assert_true(visual.is_valid(), str(node_id))
		assert_eq(visual.discipline_icon_id, &"elf_archer", str(node_id))


func test_real_glyphs_and_programmatic_fallbacks_share_one_api() -> void:
	var damage := GLYPH_SCENE.instantiate() as SkillTreeEffectGlyph
	add_child_autofree(damage)
	damage.configure_effect(&"damage", SKIN)
	assert_true(damage.has_texture())
	assert_false(damage.is_using_fallback())

	var area := GLYPH_SCENE.instantiate() as SkillTreeEffectGlyph
	add_child_autofree(area)
	area.configure_effect(&"area_or_pierce", SKIN)
	assert_true(area.has_texture())
	assert_false(area.is_using_fallback())

	for glyph_id in [
		&"range",
		&"push",
		&"movement",
		&"bleed",
		&"vulnerability",
		&"collision",
		&"duration",
		&"elf_archer",
	]:
		var fallback := GLYPH_SCENE.instantiate() as SkillTreeEffectGlyph
		add_child_autofree(fallback)
		if str(glyph_id).begins_with("elf_"):
			fallback.configure_discipline(glyph_id, SKIN)
		else:
			fallback.configure_effect(glyph_id, SKIN)
		assert_true(fallback.is_using_fallback(), str(glyph_id))


func test_nodes_expose_distinct_visual_states_and_effect_mapping() -> void:
	var state := _make_elf_state()
	state.add_discipline_xp(&"archer", 18)
	assert_true(state.select_upgrade(
		&"archer",
		2,
		&"elf_archer_eagle_eye"
	))
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_true(screen.open_for_state(state, &"archer"))
	var graph := screen.get_graph()

	assert_eq(
		graph.get_node_view(&"elf_archer_eagle_eye").get_state_icon_id(),
		&"selected"
	)
	assert_eq(
		graph.get_node_view(&"elf_archer_long_range").get_state_icon_id(),
		&"pending"
	)
	assert_eq(
		graph.get_node_view(&"elf_archer_repel_arrow").get_state_icon_id(),
		&"excluded"
	)
	assert_eq(
		graph.get_node_view(&"elf_archer_perfect_shot").get_state_icon_id(),
		&"future"
	)
	assert_eq(
		graph.get_node_view(&"elf_archer_eagle_eye").get_primary_glyph_id(),
		&"damage"
	)
	assert_eq(
		graph.get_node_view(&"elf_archer_eagle_eye").get_secondary_glyph_id(),
		&"range"
	)
	assert_eq(
		graph.get_node_view(
			&"elf_archer_transpiercing_bolt"
		).get_primary_glyph_id(),
		&"area_or_pierce"
	)
	assert_eq(
		graph.get_node_view(&"__base_rank_1").get_frame_texture(),
		SKIN.node_root_texture
	)
	assert_eq(
		graph.get_node_view(
			&"elf_archer_perfect_shot"
		).get_frame_texture(),
		SKIN.node_capstone_texture
	)

	var locked_state := _make_elf_state()
	var locked_screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	add_child_autofree(locked_screen)
	await get_tree().process_frame
	assert_true(locked_screen.open_for_state(locked_state, &"archer"))
	assert_eq(
		locked_screen.get_graph().get_node_view(
			&"elf_archer_eagle_eye"
		).get_state_icon_id(),
		&"locked"
	)


func test_detail_panel_uses_player_names_without_fallback_ids() -> void:
	var state := _make_elf_state()
	state.add_discipline_xp(&"archer", 7)
	assert_true(state.select_upgrade(
		&"archer",
		2,
		&"elf_archer_eagle_eye"
	))
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_true(screen.open_for_state(state, &"archer"))
	assert_true(screen.get_graph().inspect_node_by_id(
		&"elf_archer_long_range"
	))
	var detail := screen.get_detail_panel()
	var detail_text := detail.get_detail_text()
	assert_not_null(detail.get_frame_texture())
	assert_string_contains(detail_text, "LONGUE PORTÉE")
	assert_string_contains(detail_text, "Œil d’aigle")
	assert_string_contains(detail_text, "Tir précis")
	assert_false(detail_text.contains("elf_archer_"))


func test_hud_uses_skin_tracks_xp_and_keeps_tooltip_inside_viewport() -> void:
	var state := _make_elf_state()
	state.add_discipline_xp(&"archer", 4)
	var controller := FakeProgressionController.new()
	controller.states[&"elf"] = state
	add_child_autofree(controller)
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child_autofree(host)
	var button := STATUS_BUTTON_SCENE.instantiate() as SkillTreeStatusButton
	button.progression_controller = controller
	button.position = Vector2(1066, 18)
	button.size = Vector2(196, 76)
	host.add_child(button)
	await get_tree().process_frame

	assert_eq(button.get_frame_texture(), SKIN.character_tab_texture)
	assert_eq(button.get_xp_frame_texture(), SKIN.xp_bar_frame_texture)
	assert_eq(button.get_rank_text(), "R2")
	assert_eq(button.get_xp_text(), "4 / 7")
	assert_true(button.has_pending_badge())
	var progress_snapshot := button.get_xp_progress_snapshot()
	assert_eq(progress_snapshot["minimum"], 0.0)
	assert_eq(progress_snapshot["maximum"], 7.0)
	assert_eq(progress_snapshot["value"], 4.0)

	var tooltip := button.get_tooltip_panel()
	tooltip.refresh_from_state(state)
	tooltip.show()
	await get_tree().process_frame
	var viewport_bounds := Rect2(host.global_position, host.size)
	tooltip.place_near(button.get_global_rect(), viewport_bounds)
	var tooltip_bounds := tooltip.get_global_bounds()
	_assert_rect_inside(tooltip_bounds, viewport_bounds, "tooltip")
	assert_eq(
		tooltip.XP_REMINDER,
		"Chaque lancement réussi d’un sort rapporte 1 XP à sa discipline."
	)


func test_focus_survives_discipline_switch_and_returns_to_last_node() -> void:
	var state := _make_elf_state()
	state.add_discipline_xp(&"archer", 7)
	assert_true(state.select_upgrade(
		&"archer",
		2,
		&"elf_archer_eagle_eye"
	))
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_true(screen.open_for_state(state, &"archer"))
	await get_tree().process_frame
	assert_true(screen.get_graph().focus_node_by_id(
		&"elf_archer_long_range"
	))
	await get_tree().process_frame
	assert_eq(
		screen.get_last_inspected_id(&"archer"),
		&"elf_archer_long_range"
	)

	var tabs := screen.get_tab_buttons()
	tabs[1].pressed.emit()
	await get_tree().process_frame
	assert_eq(screen.current_discipline_id, &"assassin")
	tabs[0].pressed.emit()
	await get_tree().process_frame
	assert_eq(screen.current_discipline_id, &"archer")
	assert_eq(
		screen.get_last_inspected_id(&"archer"),
		&"elf_archer_long_range"
	)
	assert_eq(
		get_viewport().gui_get_focus_owner(),
		screen.get_graph().get_node_view(&"elf_archer_long_range")
	)


func test_screen_reflows_without_panel_overlap_at_three_resolutions() -> void:
	var state := _make_elf_state()
	state.add_discipline_xp(&"archer", 18)
	assert_true(state.select_upgrade(
		&"archer",
		2,
		&"elf_archer_eagle_eye"
	))
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child_autofree(host)
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	host.add_child(screen)
	await get_tree().process_frame
	assert_true(screen.open_for_state(state, &"archer"))

	var cases := [
		[Vector2(1920, 1080), 400.0, true],
		[Vector2(1600, 900), 352.0, true],
		[Vector2(1280, 720), 318.0, false],
	]
	for layout_case in cases:
		host.size = layout_case[0]
		await get_tree().process_frame
		await get_tree().process_frame
		var snapshot := screen.get_layout_snapshot()
		var screen_bounds: Rect2 = snapshot["screen_global"]
		var graph_bounds: Rect2 = snapshot["graph_scroll_global"]
		var detail_bounds: Rect2 = snapshot["detail_global"]
		_assert_rect_inside(
			snapshot["outer_global"],
			screen_bounds,
			"cadre externe %s" % layout_case[0]
		)
		_assert_rect_inside(
			snapshot["close_global"],
			screen_bounds,
			"bouton fermer %s" % layout_case[0]
		)
		_assert_rect_inside(
			graph_bounds,
			screen_bounds,
			"graphe %s" % layout_case[0]
		)
		_assert_rect_inside(
			detail_bounds,
			screen_bounds,
			"détail %s" % layout_case[0]
		)
		assert_lte(
			graph_bounds.end.x,
			detail_bounds.position.x + 2.0,
			"séparation graphe/détail %s" % layout_case[0]
		)
		assert_eq(
			snapshot["detail_minimum_width"],
			layout_case[1],
			"largeur détail %s" % layout_case[0]
		)
		assert_eq(
			snapshot["consultative_visible"],
			layout_case[2],
			"sous-titre %s" % layout_case[0]
		)


func test_lab_exposes_eight_scenarios_in_a_reserved_bottom_band() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child_autofree(host)
	var lab := LAB_SCENE.instantiate() as SkillTreeGrayboxLab
	host.add_child(lab)
	await get_tree().process_frame
	assert_eq(lab.get_scenario_count(), 8)
	var screen_bounds := lab.skill_tree_screen.get_global_rect()
	var scenario_bounds := (
		lab.get_node("ScenarioBar") as Control
	).get_global_rect()
	assert_lte(screen_bounds.end.y, scenario_bounds.position.y)


func _make_elf_state() -> CharacterRunState:
	var state := CharacterRunState.new()
	assert_true(state.initialize(Unit.from_data(ELF_DATA), ELF_DATA))
	_states_to_dispose.append(state)
	return state


func _assert_rect_inside(
		inner: Rect2,
		outer: Rect2,
		context: String
	) -> void:
	assert_gte(
		inner.position.x,
		outer.position.x - 1.0,
		"%s gauche" % context
	)
	assert_gte(
		inner.position.y,
		outer.position.y - 1.0,
		"%s haut" % context
	)
	assert_lte(
		inner.end.x,
		outer.end.x + 1.0,
		"%s droite" % context
	)
	assert_lte(
		inner.end.y,
		outer.end.y + 1.0,
		"%s bas" % context
	)
