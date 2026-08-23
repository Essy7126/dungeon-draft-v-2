extends GutTest

const ACHILLES_PROFILE_PATH := (
	"res://data/maps/painted/unit_profile_achilles.tres"
)
const ACHILLES_V3_VISUAL_PROFILE_PATH := (
	"res://data/visuals/achilles/achilles_meshy_profile_v3.tres"
)
const ACHILLES_DATA_PATH := "res://data/units/allies/achilles.tres"
const SKELETON_DATA_PATH := (
	"res://data/units/enemies/odyssey_skirmisher.tres"
)
const FOREST_VISUAL_PATH := (
	"res://data/maps/painted/odyssey/room_01_visual.tres"
)
const ACHILLES_SCENE := preload(
	"res://characters/achilles/AchillesIsoUnitView.tscn"
)
const UNIT_VIEW_SCENE := preload("res://battle/unit_view.tscn")
const PAINTED_BATTLE_SCENE := preload(
	"res://data/rooms/maps/painted_battle.tscn"
)
const ROOM_PROFILE_PATHS := {
	"forest": "res://data/maps/painted/room_01_forest_presentation.tres",
	"volcano": "res://data/maps/painted/room_05_volcano_presentation.tres",
	"space": "res://data/maps/painted/room_06_space_presentation.tres",
}
const EXPECTED_ROOM_SCALES := {
	"forest": 1.05,
	"volcano": 1.08,
	"space": 1.10,
}
const MESHY_CLIP_NAMES: Array[StringName] = [
	&"Alert",
	&"Archery_Shot_3",
	&"Basic_Jump",
	&"Charged_Spell_Cast",
	&"Charged_Upward_Slash",
	&"Chest_Pound_Taunt",
	&"Double_Combo_Attack",
	&"Draw_and_Shoot_from_Back_2",
	&"Electrocution_Reaction",
	&"Hit_Reaction_1",
	&"Idle_11",
	&"Left_Slash",
	&"mage_soell_cast_7",
	&"run_fast_3_inplace",
	&"Running",
	&"Simple_Kick",
	&"Sword_Judgment",
	&"Sword_Parry_Backward_2",
	&"Triple_Combo_Attack",
	&"Walking",
]
const ALPHA_THRESHOLD := 0.02
const READY_TIMEOUT_MSEC := 15000
const REPRESENTATIVE_CLIP_TIMES: Array[float] = [0.0, 0.5, 0.98]
const MINIMUM_CLIP_FRAME_MARGIN_PIXELS := 16
const BATTLE_UNIT_VIEW_SCALE := 0.58
# The accepted Odyssey framing measures one painted cell at about 74 pixels
# vertically. Normalizing the real UnitView hierarchy to that cell keeps this
# regression independent from desktop DPI and window stretch settings.
const REFERENCE_ODYSSEY_CELL_DEPTH_PIXELS := 74.0
const ACHILLES_MINIMUM_REFERENCE_HEIGHT_PIXELS := 59.0
const ACHILLES_MAXIMUM_REFERENCE_HEIGHT_PIXELS := 73.0


func test_achilles_has_a_valid_painted_presence_profile() -> void:
	var profile := load(ACHILLES_PROFILE_PATH) as UnitVisualProfile
	assert_not_null(profile)
	if profile == null:
		return
	assert_true(profile.matches(&"achilles"))
	assert_eq(profile.family_id, &"hero_achilles")
	assert_almost_eq(profile.base_visual_scale, 1.0, 0.0001)
	assert_almost_eq(profile.minimum_visual_scale, 1.0, 0.0001)
	assert_almost_eq(profile.maximum_visual_scale, 1.15, 0.0001)
	assert_true(profile.validation_errors().is_empty())


func test_all_three_odyssey_presentations_register_calibrated_achilles() -> void:
	for room_id in ROOM_PROFILE_PATHS:
		var profile := load(
			ROOM_PROFILE_PATHS[room_id]
		) as BattlePresentationProfile
		assert_not_null(profile, room_id)
		if profile == null:
			continue
		assert_not_null(profile.profile_for_unit(&"achilles"), room_id)
		var final_scale := profile.final_visual_scale(&"achilles")
		assert_almost_eq(
			final_scale,
			float(EXPECTED_ROOM_SCALES[room_id]),
			0.0001,
			room_id,
		)
		assert_lte(final_scale, 1.15, "%s remains inside the V3 envelope" % room_id)
		assert_lt(
			final_scale,
			1.974,
			"%s cannot restore the obsolete double scale" % room_id,
		)
		assert_true(profile.validation_errors().is_empty(), room_id)


func test_v3_direct_profile_keeps_tactical_camera_and_exact_animation_pool() -> void:
	var profile := load(
		ACHILLES_V3_VISUAL_PROFILE_PATH
	) as AchillesVisualProfile
	assert_not_null(profile)
	if profile == null:
		return
	assert_eq(profile.profile_id, &"achilles_meshy_animation_pool_v3")
	assert_eq(
		profile.character_asset_path,
		"res://assets/characters/Achilles/3d/achilles_meshy_animation_pool_v3.glb",
	)
	assert_eq(profile.viewport_size, Vector2i(384, 384))
	assert_almost_eq(profile.orthographic_size, 2.6, 0.0001)
	assert_almost_eq(profile.render_display_size, 78.0, 0.0001)
	assert_eq(profile.character_framing_offset, Vector3(0.0, 0.35, 0.0))
	assert_almost_eq(profile.character_scale, 1.0, 0.0001)
	var actual_clips: Array[StringName] = profile.required_action_names.duplicate()
	var expected_clips: Array[StringName] = MESHY_CLIP_NAMES.duplicate()
	actual_clips.sort()
	expected_clips.sort()
	assert_eq(actual_clips, expected_clips)


func test_all_twenty_meshy_clips_keep_safe_viewport_margins() -> void:
	var achilles := ACHILLES_SCENE.instantiate() as AchillesIsoUnitView
	add_child_autofree(achilles)
	var deadline := Time.get_ticks_msec() + READY_TIMEOUT_MSEC
	while achilles.get_active_backend_name() != &"Viewport3DBackend" \
			and Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_eq(achilles.get_active_backend_name(), &"Viewport3DBackend")
	if achilles.get_active_backend_name() != &"Viewport3DBackend":
		return
	await wait_process_frames(4)

	var backend := achilles.viewport_backend
	var visual: Achilles3DVisual = backend.get_achilles_visual()
	assert_not_null(visual)
	if visual == null:
		return
	var player: AnimationPlayer = visual.get_animation_player()
	assert_not_null(player)
	if player == null:
		return
	var actual_clips := visual.get_source_action_names()
	var expected_clips: Array[StringName] = MESHY_CLIP_NAMES.duplicate()
	actual_clips.sort()
	expected_clips.sort()
	assert_eq(actual_clips.size(), 20)
	assert_eq(actual_clips, expected_clips)

	player.speed_scale = 0.0
	for clip_name in MESHY_CLIP_NAMES:
		visual.cancel_action()
		assert_true(
			visual.play_action(&"FRAME_MARGIN_PROBE", clip_name),
			String(clip_name),
		)
		var animation: Animation = player.get_animation(clip_name)
		assert_not_null(animation, String(clip_name))
		if animation == null:
			continue
		for normalized_time in REPRESENTATIVE_CLIP_TIMES:
			# 0.98 samples the authored final pose without wrapping imported
			# loop clips back to their first key.
			player.seek(animation.length * normalized_time, true)
			player.advance(0.0)
			visual._process(0.0)
			backend.character_viewport.render_target_update_mode = (
				SubViewport.UPDATE_ONCE
			)
			await wait_process_frames(1)
			await RenderingServer.frame_post_draw
			var image: Image = backend.character_viewport.get_texture().get_image()
			var bounds := _alpha_bounds(image)
			assert_true(
				bounds.has_area(),
				"%s @ %.2f has visible pixels" % [clip_name, normalized_time],
			)
			if not bounds.has_area():
				continue
			var viewport_size: Vector2i = backend.character_viewport.size
			var margins := [
				bounds.position.x,
				bounds.position.y,
				viewport_size.x - bounds.end.x,
				viewport_size.y - bounds.end.y,
			]
			var minimum_margin: int = margins.min()
			assert_gte(
				minimum_margin,
				MINIMUM_CLIP_FRAME_MARGIN_PIXELS,
				"%s @ %.2f keeps all four viewport margins" % [
					clip_name, normalized_time,
				],
			)
	visual.cancel_action()
	player.speed_scale = 1.0


func test_real_battle_unit_views_match_reference_cell_and_skeleton() -> void:
	var map_visual := load(FOREST_VISUAL_PATH) as PaintedMapVisualData
	assert_not_null(map_visual)
	if map_visual == null or map_visual.presentation_profile == null:
		return

	# Read the scale from the production Battle scene instead of reproducing a
	# hypothetical adapter-only scale chain in the test.
	var battle_fixture := PAINTED_BATTLE_SCENE.instantiate()
	var battle_unit_scale := float(battle_fixture.get("iso_unit_view_scale"))
	battle_fixture.free()
	assert_almost_eq(
		battle_unit_scale,
		BATTLE_UNIT_VIEW_SCALE,
		0.0001,
		"The regression follows the production Battle root scale.",
	)

	var achilles_view := _create_unit_view(
		ACHILLES_DATA_PATH,
		map_visual.presentation_profile,
		battle_unit_scale,
	)
	var skeleton_view := _create_unit_view(
		SKELETON_DATA_PATH,
		map_visual.presentation_profile,
		battle_unit_scale,
	)
	if achilles_view == null or skeleton_view == null:
		return
	var achilles := (
		achilles_view.call("get_optional_visual") as AchillesIsoUnitView
	)
	var skeleton := (
		skeleton_view.call("get_optional_visual") as CharacterIsoUnitView
	)
	assert_not_null(achilles)
	assert_not_null(skeleton)
	if achilles == null or skeleton == null:
		return

	var deadline := Time.get_ticks_msec() + READY_TIMEOUT_MSEC
	while achilles.get_active_backend_name() != &"Viewport3DBackend" \
			and Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_eq(achilles.get_active_backend_name(), &"Viewport3DBackend")
	if achilles.get_active_backend_name() != &"Viewport3DBackend":
		return
	await wait_process_frames(8)
	achilles.viewport_backend.character_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ONCE
	)
	skeleton.character_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await wait_process_frames(1)
	await RenderingServer.frame_post_draw

	assert_almost_eq(
		float(achilles_view.call("get_painted_visual_scale")),
		1.05,
		0.0001,
	)
	assert_almost_eq(
		float(skeleton_view.call("get_painted_visual_scale")),
		1.0,
		0.0001,
	)
	var achilles_measure := _unit_view_measure(achilles_view, achilles)
	var skeleton_measure := _unit_view_measure(skeleton_view, skeleton)
	if not achilles_measure.visible or not skeleton_measure.visible:
		return

	var cell_depth := _vertical_span(
		map_visual.cell_polygon_display(Vector2i.ZERO)
	)
	assert_gt(cell_depth, 0.0)
	if cell_depth <= 0.0:
		return
	var reference_pixel_scale := (
		REFERENCE_ODYSSEY_CELL_DEPTH_PIXELS / cell_depth
	)
	var achilles_height_pixels := (
		float(achilles_measure.world_height) * reference_pixel_scale
	)
	var skeleton_height_pixels := (
		float(skeleton_measure.world_height) * reference_pixel_scale
	)
	var achilles_to_cell := float(achilles_measure.world_height) / cell_depth
	var skeleton_to_cell := float(skeleton_measure.world_height) / cell_depth
	var achilles_to_skeleton := (
		float(achilles_measure.world_height)
		/ maxf(float(skeleton_measure.world_height), 0.001)
	)

	assert_between(
		achilles_height_pixels,
		ACHILLES_MINIMUM_REFERENCE_HEIGHT_PIXELS,
		ACHILLES_MAXIMUM_REFERENCE_HEIGHT_PIXELS,
		"Achilles occupies 59-73 px at the accepted Odyssey cell framing.",
	)
	assert_between(
		achilles_to_cell,
		0.79,
		0.99,
		"Achilles stays below one painted cell-depth at rest.",
	)
	assert_between(
		skeleton_to_cell,
		0.65,
		1.05,
		"The real skeleton remains a stable cell-relative reference.",
	)
	assert_between(
		achilles_to_skeleton,
		0.85,
		1.35,
		"Achilles and the production skeleton share a readable combat scale.",
	)
	assert_lte(
		float(achilles_measure.foot_anchor_error),
		0.05,
		"Achilles' projected feet remain on the UnitView origin.",
	)
	assert_lte(
		float(skeleton_measure.foot_anchor_error),
		0.05,
		"The skeleton reference remains on the UnitView origin.",
	)
	# This explicit counterfactual reconstructs the rejected screenshot setup:
	# the old 125 px billboard and the former painted x1.974 were both active.
	var obsolete_height_pixels := (
		achilles_height_pixels * (125.0 / 78.0) * (1.974 / 1.05)
	)
	assert_gt(obsolete_height_pixels, ACHILLES_MAXIMUM_REFERENCE_HEIGHT_PIXELS)


func _create_unit_view(
		data_path: String,
		presentation: BattlePresentationProfile,
		battle_unit_scale: float
	) -> Node2D:
	var data := load(data_path) as UnitData
	assert_not_null(data, data_path)
	if data == null:
		return null
	var view := UNIT_VIEW_SCENE.instantiate() as Node2D
	add_child_autofree(view)
	view.call("setup", Unit.from_data(data))
	view.scale = Vector2.ONE * battle_unit_scale
	view.call("apply_painted_presentation", presentation)
	return view


func _unit_view_measure(unit_view: Node2D, optional_visual: Node2D) -> Dictionary:
	var viewport: SubViewport
	var sprite: Sprite2D
	var foot_pixel := Vector2.ZERO
	if optional_visual is AchillesIsoUnitView:
		var achilles := optional_visual as AchillesIsoUnitView
		viewport = achilles.viewport_backend.character_viewport
		sprite = achilles.viewport_backend.rendered_sprite
		foot_pixel = achilles.viewport_backend.get_projected_foot_pixel()
	else:
		var character := optional_visual as CharacterIsoUnitView
		viewport = character.character_viewport
		sprite = character.render_sprite
		foot_pixel = character.get_projected_foot_pixel()
	var image: Image = viewport.get_texture().get_image()
	var bounds := _alpha_bounds(image)
	assert_true(bounds.has_area(), "%s has visible pixels" % optional_visual.name)
	if not bounds.has_area():
		return {"visible": false}
	var top_global := sprite.to_global(Vector2(0.0, float(bounds.position.y)))
	var bottom_global := sprite.to_global(Vector2(0.0, float(bounds.end.y)))
	return {
		"visible": true,
		"world_height": top_global.distance_to(bottom_global),
		"foot_anchor_error": sprite.to_global(foot_pixel).distance_to(
			unit_view.global_position
		),
	}


func _vertical_span(points: PackedVector2Array) -> float:
	if points.is_empty():
		return 0.0
	var minimum_y := points[0].y
	var maximum_y := points[0].y
	for point in points:
		minimum_y = minf(minimum_y, point.y)
		maximum_y = maxf(maximum_y, point.y)
	return maximum_y - minimum_y


func _alpha_bounds(image: Image) -> Rect2i:
	if image == null or image.is_empty():
		return Rect2i()
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= ALPHA_THRESHOLD:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)
