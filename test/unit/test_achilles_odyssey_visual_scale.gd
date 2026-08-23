extends GutTest

const ACHILLES_PROFILE_PATH := (
	"res://data/maps/painted/unit_profile_achilles.tres"
)
const ACHILLES_V2_VISUAL_PROFILE_PATH := (
	"res://data/visuals/achilles/achilles_character_only_profile_v2.tres"
)
const ACHILLES_SCENE := preload(
	"res://characters/achilles/AchillesIsoUnitView.tscn"
)
const ELF_SCENE := preload(
	"res://characters/elf/ElfIsoUnitView.tscn"
)
const MAGE_SCENE := preload(
	"res://characters/mage/MageIsoUnitView.tscn"
)
const WARRIOR_SCENE := preload(
	"res://characters/warrior/WarriorIsoUnitView.tscn"
)
const ROOM_PROFILE_PATHS := {
	"forest": "res://data/maps/painted/room_01_forest_presentation.tres",
	"volcano": "res://data/maps/painted/room_05_volcano_presentation.tres",
	"space": "res://data/maps/painted/room_06_space_presentation.tres",
}
const ALPHA_THRESHOLD := 0.02
const READY_TIMEOUT_MSEC := 15000
const MESHY_CLIP_PREFIX := "achilles_v2__"
const REPRESENTATIVE_CLIP_TIMES: Array[float] = [0.0, 0.5, 0.98]
const MINIMUM_CLIP_FRAME_MARGIN_PIXELS := 16


func test_achilles_has_a_valid_painted_presence_profile() -> void:
	var profile := load(ACHILLES_PROFILE_PATH) as UnitVisualProfile
	assert_not_null(profile)
	assert_true(profile.matches(&"achilles"))
	assert_eq(profile.family_id, &"hero_achilles")
	assert_almost_eq(profile.base_visual_scale, 1.88, 0.0001)
	assert_almost_eq(profile.minimum_visual_scale, 1.25, 0.0001)
	assert_almost_eq(profile.maximum_visual_scale, 2.0, 0.0001)
	assert_true(profile.validation_errors().is_empty())


func test_all_three_odyssey_presentations_register_achilles() -> void:
	var expected_scales := {
		"forest": 1.974,
		"volcano": 2.0,
		"space": 2.0,
	}
	for room_id in ROOM_PROFILE_PATHS:
		var profile := load(ROOM_PROFILE_PATHS[room_id]) as BattlePresentationProfile
		assert_not_null(profile, room_id)
		assert_not_null(profile.profile_for_unit(&"achilles"), room_id)
		assert_almost_eq(
			profile.final_visual_scale(&"achilles"),
			float(expected_scales[room_id]),
			0.0001,
			room_id,
		)
		assert_true(profile.validation_errors().is_empty(), room_id)


func test_v2_camera_is_tactical_trio_calibration() -> void:
	var profile := load(ACHILLES_V2_VISUAL_PROFILE_PATH) as AchillesVisualProfile
	assert_not_null(profile)
	assert_eq(profile.viewport_size, Vector2i(384, 384))
	assert_almost_eq(profile.orthographic_size, 2.6, 0.0001)
	assert_almost_eq(profile.render_display_size, 125.0, 0.0001)
	assert_eq(profile.character_framing_offset, Vector3(0.0, 0.35, 0.0))
	assert_almost_eq(profile.character_scale, 1.0, 0.0001)


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
	var meshy_clips: Array[StringName] = []
	for clip_name in visual.get_all_source_action_names():
		if String(clip_name).begins_with(MESHY_CLIP_PREFIX):
			meshy_clips.append(clip_name)
	meshy_clips.sort()
	assert_eq(meshy_clips.size(), 20)

	player.speed_scale = 0.0
	for clip_name in meshy_clips:
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


func test_rendered_height_matches_trio_and_foot_stays_anchored() -> void:
	var views := {
		"achilles": ACHILLES_SCENE.instantiate(),
		"elf": ELF_SCENE.instantiate(),
		"mage": MAGE_SCENE.instantiate(),
		"warrior": WARRIOR_SCENE.instantiate(),
	}
	for view in views.values():
		add_child_autofree(view)

	var achilles = views.achilles as AchillesIsoUnitView
	var deadline := Time.get_ticks_msec() + READY_TIMEOUT_MSEC
	while achilles.get_active_backend_name() != &"Viewport3DBackend" \
			and Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_eq(achilles.get_active_backend_name(), &"Viewport3DBackend")
	if achilles.get_active_backend_name() != &"Viewport3DBackend":
		return
	await wait_process_frames(8)
	await RenderingServer.frame_post_draw

	var measures := {}
	for subject_id in views:
		measures[subject_id] = _render_measure(subject_id, views[subject_id])
	var achilles_measure: Dictionary = measures.achilles
	assert_between(
		float(achilles_measure.native_height_ratio),
		0.38,
		0.46,
		"Achilles keeps a detailed silhouette with safe animation margins.",
	)
	assert_lte(
		(achilles_measure.foot_anchor_error as Vector2).length(),
		0.01,
		"The projected feet remain exactly on the UnitView origin.",
	)

	for room_id in ROOM_PROFILE_PATHS:
		var room_profile := load(
			ROOM_PROFILE_PATHS[room_id]
		) as BattlePresentationProfile
		var achilles_height := float(achilles_measure.display_height) \
			* room_profile.final_visual_scale(&"achilles")
		var trio_heights: Array[float] = []
		for subject_id in ["elf", "mage", "warrior"]:
			trio_heights.append(
				float(measures[subject_id].display_height)
				* room_profile.final_visual_scale(StringName(subject_id))
			)
		trio_heights.sort()
		assert_gte(
			achilles_height,
			trio_heights.front() * 0.96,
			"%s: Achilles is not smaller than the accepted trio envelope." % room_id,
		)
		assert_lte(
			achilles_height,
			trio_heights.back() * 1.04,
			"%s: Achilles is not larger than the accepted trio envelope." % room_id,
		)


func _render_measure(subject_id: String, view: Node) -> Dictionary:
	var viewport: SubViewport
	var sprite: Sprite2D
	var foot_pixel := Vector2.ZERO
	if subject_id == "achilles":
		var backend = view.viewport_backend
		viewport = backend.character_viewport
		sprite = backend.rendered_sprite
		foot_pixel = backend.get_projected_foot_pixel()
	else:
		viewport = view.character_viewport
		sprite = view.render_sprite
		foot_pixel = view.get_projected_foot_pixel()
	var image := viewport.get_texture().get_image()
	var bounds := _alpha_bounds(image)
	return {
		"native_height_ratio": (
			float(bounds.size.y) / float(maxi(image.get_height(), 1))
		),
		"display_height": float(bounds.size.y) * sprite.scale.y,
		"foot_anchor_error": sprite.position + foot_pixel * sprite.scale,
	}


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
