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
	"skill_node_root_v2.png.png",
	"skill_rank_badge_base_v2.png.png",
	"skill_character_tab_base.png",
	"skill_discipline_tab_base.png.png",
	"skill_xp_bar_frame.png.png",
	"skill_state_lock.svg.png",
	"skill_state_purchased.svg.png",
	"skill_state_excluded.svg.png",
	"skill_state_pending.svg.png",
	"icon_discipline_elf_archer.png.png",
	"icon_discipline_elf_assassin.png.png",
	"icon_discipline_elf_mage.png.png",
	"icon_discipline_elf_healer.png.png",
	"glyph_damage.png",
	"glyph_area..png",
	"glyph_range.svg.png",
	"glyph_push.svg.png",
	"glyph_movement.svg.png",
	"glyph_bleed.svg.png",
	"glyph_vulnerability.svg.png",
	"glyph_collision.svg.png",
	"glyph_duration.svg.png",
]
const INVALID_NEW_SOURCE_ASSETS := [
	"skill_node_capstone_v2.png.png",
]
const DISCIPLINE_ICON_IDS := [
	&"elf_archer",
	&"elf_assassin",
	&"elf_mage",
	&"elf_healer",
]
const REAL_EFFECT_GLYPH_IDS := [
	&"damage",
	&"area_or_pierce",
	&"range",
	&"push",
	&"movement",
	&"bleed",
	&"vulnerability",
	&"collision",
	&"duration",
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
	for asset_name in INVALID_NEW_SOURCE_ASSETS:
		var asset_path: String = ASSET_DIRECTORY + str(asset_name)
		assert_true(FileAccess.file_exists(asset_path), asset_path)
		assert_true(
			FileAccess.file_exists(asset_path + ".import"),
			asset_path + ".import"
		)
	assert_not_null(SKIN.get_node_frame(1))
	assert_not_null(SKIN.get_node_frame(3))
	assert_not_null(SKIN.get_node_frame(5))
	assert_ne(SKIN.get_node_frame(1), SKIN.get_node_frame(5))
	assert_not_null(SKIN.rank_badge_texture)
	assert_not_null(SKIN.get_state_texture(&"locked"))
	assert_not_null(SKIN.get_state_texture(&"selected"))
	assert_not_null(SKIN.get_state_texture(&"excluded"))
	assert_not_null(SKIN.get_state_texture(&"pending"))


func test_new_skin_textures_use_the_audited_sources_and_regions() -> void:
	assert_eq(SKIN.node_root_texture.get_size(), Vector2(896, 896))
	assert_eq(SKIN.rank_badge_texture.get_size(), Vector2(1981, 973))
	assert_eq(
		SKIN.get_state_texture(&"pending").get_size(),
		Vector2(448, 448)
	)
	assert_eq(
		_texture_source_path(SKIN.node_root_texture),
		ASSET_DIRECTORY + "skill_node_root_v2.png.png"
	)
	assert_eq(
		_texture_source_path(SKIN.node_capstone_texture),
		ASSET_DIRECTORY + "skill_node_frame_base.png"
	)
	assert_eq(
		_texture_source_path(SKIN.rank_badge_texture),
		ASSET_DIRECTORY + "skill_rank_badge_base_v2.png.png"
	)
	assert_eq(
		_texture_source_path(SKIN.get_state_texture(&"pending")),
		ASSET_DIRECTORY + "skill_state_pending.svg.png"
	)

	var discipline_textures: Array[Texture2D] = []
	for icon_id in DISCIPLINE_ICON_IDS:
		var texture := SKIN.get_discipline_icon(icon_id)
		assert_not_null(texture, str(icon_id))
		assert_false(discipline_textures.has(texture), str(icon_id))
		discipline_textures.append(texture)
		assert_eq(SKIN.get_effect_glyph(icon_id), texture, str(icon_id))
	for glyph_id in REAL_EFFECT_GLYPH_IDS:
		assert_not_null(SKIN.get_effect_glyph(glyph_id), str(glyph_id))


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
	for glyph_id in REAL_EFFECT_GLYPH_IDS:
		var glyph := GLYPH_SCENE.instantiate() as SkillTreeEffectGlyph
		add_child_autofree(glyph)
		glyph.configure_effect(glyph_id, SKIN)
		assert_true(glyph.has_texture(), str(glyph_id))
		assert_false(glyph.is_using_fallback(), str(glyph_id))

	for icon_id in DISCIPLINE_ICON_IDS:
		var icon := GLYPH_SCENE.instantiate() as SkillTreeEffectGlyph
		add_child_autofree(icon)
		icon.configure_discipline(icon_id, SKIN)
		assert_true(icon.has_texture(), str(icon_id))
		assert_false(icon.is_using_fallback(), str(icon_id))

	var unknown := GLYPH_SCENE.instantiate() as SkillTreeEffectGlyph
	add_child_autofree(unknown)
	unknown.configure_effect(&"future", SKIN)
	assert_false(unknown.has_texture())
	assert_true(unknown.is_using_fallback())

	var empty_skin := SkillTreeSkinData.new()
	var absent := GLYPH_SCENE.instantiate() as SkillTreeEffectGlyph
	add_child_autofree(absent)
	absent.configure_effect(&"range", empty_skin)
	assert_false(absent.has_texture())
	assert_true(absent.is_using_fallback())


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
	for standard_node_id in [
		&"elf_archer_eagle_eye",
		&"elf_archer_long_range",
		&"elf_archer_perfect_sight",
	]:
		assert_eq(
			graph.get_node_view(standard_node_id).get_frame_texture(),
			SKIN.node_standard_texture,
			str(standard_node_id)
		)
	assert_eq(
		graph.get_node_view(
			&"elf_archer_perfect_shot"
		).get_frame_texture(),
		SKIN.node_capstone_texture
	)
	assert_eq(
		graph.get_node_view(&"__base_rank_1").get_rank_badge_text(),
		"R1"
	)
	assert_eq(
		graph.get_node_view(
			&"elf_archer_eagle_eye"
		).get_rank_badge_text(),
		"R2"
	)
	assert_eq(
		graph.get_node_view(
			&"elf_archer_perfect_shot"
		).get_rank_badge_text(),
		"R5"
	)
	for node_id in [
		&"__base_rank_1",
		&"elf_archer_eagle_eye",
		&"elf_archer_perfect_shot",
	]:
		var node_view := graph.get_node_view(node_id)
		assert_true(
			(node_view.get_node("%RankBadgeTexture") as TextureRect).visible,
			str(node_id)
		)
		assert_true(
			(node_view.get_node("%RankLabel") as Label).visible,
			str(node_id)
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


func test_new_icons_and_glyphs_propagate_through_the_skin_consumers() -> void:
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

	var tabs := screen.get_tab_buttons()
	assert_eq(tabs.size(), DISCIPLINE_ICON_IDS.size())
	for index in range(tabs.size()):
		var tab_icon := tabs[index].get_node(
			"%DisciplineIcon"
		) as SkillTreeEffectGlyph
		var expected_id: StringName = DISCIPLINE_ICON_IDS[index]
		assert_eq(tab_icon.glyph_id, expected_id)
		assert_eq(
			tab_icon.get("_texture"),
			SKIN.get_discipline_icon(expected_id)
		)
		_assert_texture_fits_control(tab_icon, "onglet %s" % expected_id)

	var eagle_eye := screen.get_graph().get_node_view(
		&"elf_archer_eagle_eye"
	)
	var root_node := screen.get_graph().get_node_view(&"__base_rank_1")
	var root_primary := root_node.get_node(
		"%EffectGlyphPrimary"
	) as SkillTreeEffectGlyph
	assert_eq(
		root_primary.get("_texture"),
		SKIN.get_discipline_icon(&"elf_archer")
	)
	_assert_texture_fits_control(root_primary, "racine Archer")
	var node_discipline := eagle_eye.get_node(
		"%DisciplineIcon"
	) as SkillTreeEffectGlyph
	var node_primary := eagle_eye.get_node(
		"%EffectGlyphPrimary"
	) as SkillTreeEffectGlyph
	var node_secondary := eagle_eye.get_node(
		"%EffectGlyphSecondary"
	) as SkillTreeEffectGlyph
	assert_eq(
		node_discipline.get("_texture"),
		SKIN.get_discipline_icon(&"elf_archer")
	)
	assert_eq(
		node_primary.get("_texture"),
		SKIN.get_effect_glyph(&"damage")
	)
	assert_eq(
		node_secondary.get("_texture"),
		SKIN.get_effect_glyph(&"range")
	)
	_assert_texture_fits_control(node_primary, "glyphe principal")
	_assert_texture_fits_control(node_secondary, "glyphe secondaire")

	assert_true(screen.get_graph().inspect_node_by_id(
		&"elf_archer_eagle_eye"
	))
	var detail := screen.get_detail_panel()
	var detail_discipline := detail.get_node(
		"%DisciplineIcon"
	) as SkillTreeEffectGlyph
	var detail_primary := detail.get_node(
		"%PrimaryGlyph"
	) as SkillTreeEffectGlyph
	assert_eq(
		detail_discipline.get("_texture"),
		SKIN.get_discipline_icon(&"elf_archer")
	)
	assert_eq(
		detail_primary.get("_texture"),
		SKIN.get_effect_glyph(&"damage")
	)
	_assert_texture_fits_control(detail_primary, "panneau de détail")

	var controller := FakeProgressionController.new()
	controller.states[&"elf"] = state
	add_child_autofree(controller)
	var hud_button := STATUS_BUTTON_SCENE.instantiate() as SkillTreeStatusButton
	hud_button.progression_controller = controller
	add_child_autofree(hud_button)
	await get_tree().process_frame
	var hud_icon := hud_button.get_node(
		"%DisciplineIcon"
	) as SkillTreeEffectGlyph
	assert_eq(
		hud_icon.get("_texture"),
		SKIN.get_discipline_icon(&"elf_archer")
	)
	_assert_texture_fits_control(hud_icon, "bouton HUD")

	var tooltip := hud_button.get_tooltip_panel()
	tooltip.refresh_from_state(state)
	var tooltip_ids: Array[StringName] = []
	for row in (
		tooltip.get_node("%DisciplineRows") as VBoxContainer
	).get_children():
		var tooltip_icon := row.get_child(0) as SkillTreeEffectGlyph
		tooltip_ids.append(tooltip_icon.glyph_id)
		assert_eq(
			tooltip_icon.get("_texture"),
			SKIN.get_discipline_icon(tooltip_icon.glyph_id)
		)
		_assert_texture_fits_control(
			tooltip_icon,
			"tooltip %s" % tooltip_icon.glyph_id
		)
	assert_eq(tooltip_ids, DISCIPLINE_ICON_IDS)


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
		[Vector2(1920, 1080), 410.0, true],
		[Vector2(1600, 900), 360.0, true],
		[Vector2(1280, 720), 330.0, false],
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
		_assert_rect_inside(
			snapshot["footer_global"],
			screen_bounds,
			"footer %s" % layout_case[0]
		)
		assert_true(snapshot["footer_visible"])
		assert_string_contains(snapshot["footer_text"], "Archer")


func test_node_and_tab_metrics_follow_the_three_layout_profiles() -> void:
	var state := _make_elf_state()
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child_autofree(host)
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	host.add_child(screen)
	await get_tree().process_frame
	assert_true(screen.open_for_state(state, &"archer"))
	var cases := [
		[Vector2(1920, 1080), &"large", 120.0, 132.0, 148.0, Vector2(260, 72)],
		[Vector2(1600, 900), &"medium", 108.0, 120.0, 134.0, Vector2(232, 66)],
		[Vector2(1280, 720), &"compact", 98.0, 106.0, 120.0, Vector2(210, 60)],
	]
	for layout_case in cases:
		host.size = layout_case[0]
		for _frame in range(3):
			await get_tree().process_frame
		var graph := screen.get_graph()
		assert_eq(
			graph.get_layout_snapshot()["profile"],
			layout_case[1],
			str(layout_case[0])
		)
		assert_eq(
			graph.get_node_view(
				&"elf_archer_long_range"
			).get_visual_frame_size().x,
			layout_case[2],
			"standard %s" % layout_case[0]
		)
		assert_eq(
			graph.get_node_view(
				&"__base_rank_1"
			).get_visual_frame_size().x,
			layout_case[3],
			"root %s" % layout_case[0]
		)
		assert_eq(
			graph.get_node_view(
				&"elf_archer_perfect_shot"
			).get_visual_frame_size().x,
			layout_case[4],
			"capstone %s" % layout_case[0]
		)
		var tab_snapshot := screen.get_tab_buttons()[0].get_layout_snapshot()
		assert_eq(
			tab_snapshot["minimum_size"],
			layout_case[5],
			"tab %s" % layout_case[0]
		)
		assert_gt(tab_snapshot["icon_size"].x, 0.0)


func test_large_archer_layout_uses_width_and_keeps_nodes_separate() -> void:
	var state := _make_elf_state()
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child_autofree(host)
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	host.add_child(screen)
	await get_tree().process_frame
	assert_true(screen.open_for_state(state, &"archer"))
	for _frame in range(3):
		await get_tree().process_frame
	var graph := screen.get_graph()
	var layout := graph.get_layout_snapshot()
	assert_gte(layout["used_width_ratio"], 0.75)
	assert_gt(graph.get_rank_center(5), graph.size.x * 0.75)
	for rank_number in range(1, 5):
		assert_lt(
			graph.get_rank_center(rank_number),
			graph.get_rank_center(rank_number + 1),
			"rank order %d/%d" % [rank_number, rank_number + 1]
		)
	var branch_rects := graph.get_branch_rects()
	assert_eq(branch_rects.size(), 2)
	assert_lt(branch_rects[0].end.y, branch_rects[1].position.y)
	var root_bounds := graph.get_node_bounds(&"__base_rank_1")
	var branch_midpoint := (
		branch_rects[0].get_center().y
		+ branch_rects[1].get_center().y
	) * 0.5
	assert_almost_eq(root_bounds.get_center().y, branch_midpoint, 1.0)
	var graph_bounds := Rect2(Vector2.ZERO, graph.size)
	var ordered_nodes := graph.get_node_views_in_focus_order()
	for view in ordered_nodes:
		_assert_rect_inside(
			Rect2(view.position, view.size),
			graph_bounds,
			str(view.presentation_id)
		)
	for first_index in range(ordered_nodes.size()):
		for second_index in range(first_index + 1, ordered_nodes.size()):
			var first := ordered_nodes[first_index]
			var second := ordered_nodes[second_index]
			assert_false(
				Rect2(first.position, first.size).intersects(
					Rect2(second.position, second.size)
				),
				"%s / %s" % [
					first.presentation_id,
					second.presentation_id,
				]
			)


func test_important_node_names_are_two_lines_or_less_without_truncation() -> void:
	var state := _make_elf_state()
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child_autofree(host)
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	host.add_child(screen)
	await get_tree().process_frame
	assert_true(screen.open_for_state(state, &"archer"))
	for _frame in range(3):
		await get_tree().process_frame
	for node_id in [
		&"elf_archer_barbed_tip",
		&"elf_archer_piercing_shot",
		&"elf_archer_transpiercing_bolt",
		&"elf_archer_hindering_arrow",
		&"elf_archer_tactical_retreat",
		&"elf_archer_siege_arrow",
	]:
		var view := screen.get_graph().get_node_view(node_id)
		var name_layout := view.get_name_layout_snapshot()
		assert_false(name_layout["truncated"], str(node_id))
		assert_lte(name_layout["line_count"], 2, str(node_id))
		assert_gte(name_layout["font_size"], 15, str(node_id))


func test_connections_have_expected_count_widths_and_clear_routes() -> void:
	var state := _make_elf_state()
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child_autofree(host)
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	host.add_child(screen)
	await get_tree().process_frame
	assert_true(screen.open_for_state(state, &"archer"))
	for _frame in range(3):
		await get_tree().process_frame
	var graph := screen.get_graph()
	assert_eq(graph.get_connection_count(), 16)
	assert_almost_eq(graph.get_connection_width(&"compatible"), 2.8, 0.01)
	assert_almost_eq(graph.get_connection_width(&"available"), 3.8, 0.01)
	assert_almost_eq(graph.get_connection_width(&"selected"), 4.5, 0.01)
	assert_almost_eq(graph.get_connection_width(&"incompatible"), 2.8, 0.01)
	for connection in graph.get_connection_records():
		var points: PackedVector2Array = connection["points"]
		assert_gte(points.size(), 4)
		assert_false(
			connection["crosses_intermediate"],
			"%s -> %s" % [
				connection["source_id"],
				connection["target_id"],
			]
		)
		var source := graph.get_node_view(connection["source_id"])
		var target := graph.get_node_view(connection["target_id"])
		assert_lte(
			points[0].distance_to(
				source.position + source.get_connection_anchor(&"right")
			),
			0.1
		)
		assert_lte(
			points[points.size() - 1].distance_to(
				target.position + target.get_connection_anchor(&"left")
			),
			0.1
		)


func test_detail_hierarchy_and_consultation_do_not_mutate_progression() -> void:
	var state := _make_elf_state()
	var progress := state.get_discipline_progress(&"archer")
	var initial_xp := progress.xp
	var initial_selections := progress.get_selected_upgrade_ids()
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	add_child_autofree(host)
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	host.add_child(screen)
	await get_tree().process_frame
	assert_true(screen.open_for_state(state, &"archer"))
	assert_true(screen.get_graph().inspect_node_by_id(
		&"elf_archer_perfect_shot"
	))
	var detail := screen.get_detail_panel()
	assert_eq(detail.get_section_labels(), [
		"DESCRIPTION",
		"SORT AFFECTÉ",
		"PRÉREQUIS",
		"ÉTAT",
		"RAISON",
	])
	var typography := detail.get_typography_snapshot()
	assert_gte(typography["title"], 22)
	assert_gte(typography["description"], 15)
	assert_gte(typography["section"], 12)
	assert_gte(typography["value"], 14)
	assert_false(detail.get_detail_text().contains("elf_archer_"))
	var cancel_event := InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	screen._unhandled_input(cancel_event)
	assert_false(screen.visible)
	assert_eq(progress.xp, initial_xp)
	assert_eq(progress.get_selected_upgrade_ids(), initial_selections)


func test_lab_exposes_eight_scenarios_in_a_reserved_bottom_band() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child_autofree(host)
	var lab := LAB_SCENE.instantiate() as SkillTreeGrayboxLab
	host.add_child(lab)
	await get_tree().process_frame
	assert_eq(lab.get_scenario_count(), 8)
	lab.show_rank_one_preview()
	await get_tree().process_frame
	var preview_progress := lab.preview_state.get_discipline_progress(
		&"archer"
	)
	assert_eq(preview_progress.xp, 0)
	assert_true(preview_progress.get_selected_upgrade_ids().is_empty())
	assert_false(lab.is_layout_debug_enabled())
	lab.layout_debug_toggle.button_pressed = true
	await get_tree().process_frame
	assert_true(lab.is_layout_debug_enabled())
	var screen_bounds := lab.skill_tree_screen.get_global_rect()
	var scenario_bounds := (
		lab.get_node("ScenarioBar") as Control
	).get_global_rect()
	assert_lte(screen_bounds.end.y, scenario_bounds.position.y)


func _texture_source_path(texture: Texture2D) -> String:
	var atlas := texture as AtlasTexture
	if atlas != null and atlas.atlas != null:
		return atlas.atlas.resource_path
	return texture.resource_path if texture != null else ""


func _assert_texture_fits_control(
		glyph: SkillTreeEffectGlyph,
		context: String
	) -> void:
	var texture := glyph.get("_texture") as Texture2D
	assert_not_null(texture, context)
	assert_gt(glyph.size.x, 0.0, context)
	assert_gt(glyph.size.y, 0.0, context)
	if texture == null or glyph.size.x <= 0.0 or glyph.size.y <= 0.0:
		return
	var texture_size := texture.get_size()
	var scale_factor := minf(
		glyph.size.x / texture_size.x,
		glyph.size.y / texture_size.y
	)
	var draw_size := texture_size * scale_factor
	assert_lte(draw_size.x, glyph.size.x + 0.01, context)
	assert_lte(draw_size.y, glyph.size.y + 0.01, context)
	assert_almost_eq(
		draw_size.x / draw_size.y,
		texture_size.x / texture_size.y,
		0.001,
		context
	)


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
