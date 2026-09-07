extends GutTest

const SCREEN_SCENE := preload(
	"res://ui/progression/screens/skill_tree_screen.tscn"
)
const NODE_SCENE := preload(
	"res://ui/progression/components/skill_tree_node_view.tscn"
)
const DEFAULT_SKILL_TREE_SKIN := preload(
	"res://ui/progression/skin/dungeon_draft_skill_tree_skin.tres"
)
const HERO_PATHS := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]


func _state(hero_path: String) -> CharacterRunState:
	var data := load(hero_path) as UnitData
	var state := CharacterRunState.new()
	assert_true(state.initialize(Unit.from_data(data), data))
	return state


func _screen() -> SkillTreeScreen:
	var screen := SCREEN_SCENE.instantiate() as SkillTreeScreen
	add_child_autofree(screen)
	return screen


func _settle_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func test_achilles_node_art_is_visible_only_after_the_rank_is_revealed() -> void:
	var discipline := load(
		"res://data/characters/achilles/disciplines/spear.tres"
	) as DisciplineData
	assert_not_null(discipline)
	var node := discipline.ranks[1].choices[0] as SkillUpgradeData
	assert_not_null(node)
	assert_not_null(node.icon)
	var presentation := {
		"state": SkillTreeVisualPresentation.SkillTreeVisualState.AVAILABLE,
		"required_xp": 3,
	}

	var visible_view := NODE_SCENE.instantiate() as SkillTreeNodeView
	add_child_autofree(visible_view)
	await get_tree().process_frame
	visible_view.configure_node(
		discipline,
		node,
		presentation,
		DEFAULT_SKILL_TREE_SKIN,
		null,
		&"achilles",
		SkillTreeNodeView.RevealMode.FULL,
	)
	var visible_icon := visible_view.get_node("%IconOverride") as TextureRect
	assert_same(visible_icon.texture, node.icon)
	assert_true(visible_view.is_content_revealed())
	assert_false((visible_view.get_node("%LockOverlay") as Control).visible)

	var masked_skin := SkillTreeSkinData.new()
	masked_skin.icon_catalog = DEFAULT_SKILL_TREE_SKIN.icon_catalog
	masked_skin.refined_config = (
		DEFAULT_SKILL_TREE_SKIN.refined_config.duplicate(true)
		as SkillTreeRefinedConfig
	)
	masked_skin.refined_config.show_next_rank_icons = false
	var masked_view := NODE_SCENE.instantiate() as SkillTreeNodeView
	add_child_autofree(masked_view)
	await get_tree().process_frame
	masked_view.configure_node(
		discipline,
		node,
		presentation,
		masked_skin,
		null,
		&"achilles",
		SkillTreeNodeView.RevealMode.NEXT_RANK,
	)
	var masked_icon := masked_view.get_node("%IconOverride") as TextureRect
	assert_same(masked_icon.texture, masked_skin.icon_catalog.hidden_icon)
	assert_not_same(masked_icon.texture, node.icon)
	assert_false(masked_view.is_content_revealed())
	assert_true((masked_view.get_node("%LockOverlay") as Control).visible)


func test_every_hero_exposes_four_spell_backed_tabs_and_progressive_reveal() -> void:
	for hero_path in HERO_PATHS:
		var state := _state(hero_path)
		var screen := _screen()
		var disciplines := state.get_disciplines()
		assert_true(screen.open_for_state(state, disciplines[0].discipline_id))
		await _settle_layout()
		assert_eq(screen.get_tab_count(), 4, hero_path)
		for discipline in disciplines:
			screen._show_discipline(discipline.discipline_id)
			await _settle_layout()
			assert_eq(screen.current_discipline_id, discipline.discipline_id)
			assert_eq(screen.get_graph().get_node_view_count(), 5)
			var base := screen.get_graph().get_node_view(&"__base_rank_1")
			assert_not_null(base)
			var expected_spell := state.unit.spells.filter(
				func(spell): return spell.skill_tree == discipline
			)[0] as Spell
			assert_eq(base.get_display_name(), expected_spell.spell_name)
		screen.queue_free()
		await get_tree().process_frame


func test_rank_five_displays_all_nineteen_nodes_and_excluded_state() -> void:
	var state := _state(HERO_PATHS[1])
	var discipline := state.get_disciplines()[0]
	var progress := state.get_discipline_progress(discipline.discipline_id)
	progress.add_xp(30)
	var r2a := discipline.ranks[1].choices[0] as SkillTreeNodeData
	var r3a := discipline.ranks[2].choices[0] as SkillTreeNodeData
	var r4a := discipline.ranks[3].choices[0] as SkillTreeNodeData
	var r5a := discipline.ranks[4].choices[0] as SkillTreeNodeData
	assert_not_null(progress.select_upgrade(r2a.upgrade_id, 2))
	assert_not_null(progress.select_upgrade(r3a.upgrade_id, 3))
	assert_not_null(progress.select_upgrade(r4a.upgrade_id, 4))
	assert_not_null(progress.select_upgrade(r5a.upgrade_id, 5))
	var screen := _screen()
	assert_true(screen.open_for_state(state, discipline.discipline_id))
	await _settle_layout()
	assert_eq(screen.get_graph().get_node_view_count(), 19)
	assert_eq(
		screen.get_graph().get_node_view(r2a.upgrade_id).get_state_text(),
		"ACQUIS"
	)
	var r2b := discipline.ranks[1].choices[1] as SkillTreeNodeData
	assert_eq(
		screen.get_graph().get_node_view(r2b.upgrade_id).get_state_text(),
		"EXCLU"
	)
	assert_eq(SkillTreeVisualPresentation.state_label(
		SkillTreeVisualPresentation.SkillTreeVisualState.SELECTED
	), "ACQUIS")
	assert_eq(SkillTreeVisualPresentation.state_label(
		SkillTreeVisualPresentation.SkillTreeVisualState.AVAILABLE
	), "DISPONIBLE")
	assert_eq(SkillTreeVisualPresentation.state_label(
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_XP
	), "XP REQUISE")
	assert_eq(SkillTreeVisualPresentation.state_label(
		SkillTreeVisualPresentation.SkillTreeVisualState.FUTURE
	), "VERROUILLÉ")
	assert_eq(SkillTreeVisualPresentation.state_label(
		SkillTreeVisualPresentation.SkillTreeVisualState.LOCKED_BY_BRANCH
	), "EXCLU")


func test_responsive_layout_stays_inside_720p_1080p_and_1440p() -> void:
	var state := _state(HERO_PATHS[2])
	state.get_discipline_progress(state.get_disciplines()[0].discipline_id).add_xp(30)
	var screen := _screen()
	await get_tree().process_frame
	assert_same(screen.theme, PremiumUI.get_theme())
	assert_true(screen.open_for_state(
		state,
		state.get_disciplines()[0].discipline_id
	))
	var cases := [
		{"size": Vector2(1280, 720), "profile": &"compact"},
		{"size": Vector2(1920, 1080), "profile": &"large"},
		{"size": Vector2(2560, 1440), "profile": &"large"},
	]
	for case in cases:
		screen.apply_viewport_size_for_test(case["size"])
		await _settle_layout()
		var snapshot := screen.get_layout_snapshot()
		assert_eq(snapshot["layout_profile"], case["profile"], str(case["size"]))
		assert_true(snapshot["screen_global"].encloses(snapshot["outer_global"]))
		assert_true(snapshot["outer_global"].encloses(snapshot["header_global"]))
		assert_true(snapshot["outer_global"].encloses(snapshot["branch_global"]))
		assert_true(snapshot["outer_global"].encloses(snapshot["canvas_global"]))
		assert_true(snapshot["outer_global"].encloses(snapshot["detail_global"]))
		assert_false(snapshot["branch_global"].intersects(snapshot["canvas_global"]))
		assert_false(snapshot["canvas_global"].intersects(snapshot["detail_global"]))
		if case["size"] == Vector2(2560, 1440):
			assert_gte((snapshot["outer_global"] as Rect2).size.x, 2000.0)
			assert_gte((snapshot["outer_global"] as Rect2).size.y, 1100.0)
		assert_true(screen.get_graph().get_node_views_in_focus_order().all(
			func(view): return view.focus_mode == Control.FOCUS_ALL
		))
