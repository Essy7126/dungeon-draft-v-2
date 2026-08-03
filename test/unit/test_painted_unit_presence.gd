extends GutTest

const UNIT_VIEW_SCENE := preload("res://battle/unit_view.tscn")
const ROOM_PATHS := [
	"res://data/rooms/first_run_room_01.tres",
	"res://data/rooms/room_05_volcano.tres",
	"res://data/rooms/room_06_space.tres",
]
const HERO_PATHS := {
	&"elf": "res://data/units/alliés/elfe.tres",
	&"mage": "res://data/units/alliés/mage.tres",
	&"warrior": "res://data/units/alliés/Guerrier.tres",
}


class FakePaintedVisual extends Node2D:
	var readability_call_count := 0

	func set_painted_readability(
			_enabled: bool,
			_outline_color: Color,
			_outline_width_px: float,
			_shadow_enabled: bool,
			_shadow_scale: float,
			_shadow_alpha: float
		) -> void:
		readability_call_count += 1

	func get_logical_foot_position() -> Vector2:
		return Vector2.ZERO

	func get_default_cast_effect_origin() -> Vector2:
		return Vector2(5.0, -11.0)


func test_chaque_map_peinte_possede_un_profil_de_presentation_valide() -> void:
	var expected_camera := [1.10, 1.12, 1.15]
	var expected_room_scale := [1.05, 1.08, 1.10]
	for index in ROOM_PATHS.size():
		var room := load(ROOM_PATHS[index]) as RoomData
		var profile := room.painted_map_visual_data.presentation_profile
		assert_not_null(profile, room.room_name)
		assert_eq(profile.validation_errors(), PackedStringArray())
		assert_almost_eq(profile.camera_zoom_multiplier, expected_camera[index], 0.0001)
		assert_almost_eq(
			profile.global_unit_scale_multiplier, expected_room_scale[index], 0.0001
		)
		assert_true(profile.contact_shadows_enabled)
		assert_true(profile.outlines_enabled)
		assert_false(profile.action_focus_enabled)
		assert_eq(profile.action_focus_zoom, 0.0)


func test_formule_finale_est_par_famille_fois_salle_avec_caps_explicites() -> void:
	var forest := _profile(0)
	var volcano := _profile(1)
	var space := _profile(2)
	assert_almost_eq(forest.final_visual_scale(&"elf"), 1.806, 0.0001)
	assert_almost_eq(forest.final_visual_scale(&"mage"), 1.848, 0.0001)
	assert_almost_eq(forest.final_visual_scale(&"warrior"), 1.974, 0.0001)
	assert_almost_eq(forest.final_visual_scale(&"skeleton_melee"), 1.68, 0.0001)
	assert_almost_eq(volcano.final_visual_scale(&"elf"), 1.8576, 0.0001)
	assert_almost_eq(volcano.final_visual_scale(&"skeleton_chief"), 1.62, 0.0001)
	assert_almost_eq(space.final_visual_scale(&"elf"), 1.892, 0.0001)
	assert_almost_eq(space.final_visual_scale(&"mage"), 1.936, 0.0001)
	assert_almost_eq(space.final_visual_scale(&"warrior"), 2.0, 0.0001)
	assert_almost_eq(space.final_visual_scale(&"skeleton_melee"), 1.76, 0.0001)
	assert_almost_eq(space.final_visual_scale(&"skeleton_chief"), 1.65, 0.0001)


func test_echelles_familles_appliquent_le_second_palier_de_lisibilite() -> void:
	var profile := _profile(2)
	for unit_id in [&"elf", &"mage", &"warrior"]:
		var family := profile.profile_for_unit(unit_id)
		assert_gte(family.final_visual_scale(profile.global_unit_scale_multiplier), 1.89)
		assert_lte(family.final_visual_scale(profile.global_unit_scale_multiplier), 2.0)
	for unit_id in [&"skeleton_melee", &"skeleton_ranged"]:
		var family := profile.profile_for_unit(unit_id)
		assert_gte(family.final_visual_scale(profile.global_unit_scale_multiplier), 1.70)
		assert_lte(family.final_visual_scale(profile.global_unit_scale_multiplier), 1.80)
	var elite := profile.profile_for_unit(&"skeleton_chief")
	assert_gte(elite.final_visual_scale(profile.global_unit_scale_multiplier), 1.60)
	assert_lte(elite.final_visual_scale(profile.global_unit_scale_multiplier), 1.70)


func test_application_est_absolue_et_ne_deplace_jamais_le_pied_logique() -> void:
	var fixture := _fake_view(&"elf")
	var view = fixture[0]
	var visual: FakePaintedVisual = fixture[1]
	view.scale = Vector2.ONE * 0.58
	view.position = Vector2(117.25, 63.5)
	var root_scale_before: Vector2 = view.scale
	var root_position_before: Vector2 = view.position
	var visual_base_scale: Vector2 = visual.scale
	view.apply_painted_presentation(_profile(0), true, true)
	var first_scale: Vector2 = visual.scale
	view.apply_painted_presentation(_profile(0), true, true)
	assert_eq(visual.scale, first_scale)
	assert_eq(visual.scale, visual_base_scale * 1.806)
	assert_eq(view.scale, root_scale_before)
	assert_eq(view.position, root_position_before)
	assert_eq(view.get_logical_foot_position(), Vector2.ZERO)
	assert_eq(visual.get_logical_foot_position(), Vector2.ZERO)
	assert_lte(visual.get_logical_foot_position().length(), 0.5)
	assert_eq(visual.readability_call_count, 2)


func test_origine_de_cast_suit_le_rendu_sans_changer_la_cellule() -> void:
	var fixture := _fake_view(&"mage")
	var view = fixture[0]
	var visual: FakePaintedVisual = fixture[1]
	view.position = Vector2(80.0, 120.0)
	var position_before: Vector2 = view.position
	view.apply_painted_presentation(_profile(2), true, true)
	var expected: Vector2 = visual.to_global(visual.get_default_cast_effect_origin())
	assert_almost_eq(view.get_cast_effect_origin_global().x, expected.x, 0.01)
	assert_almost_eq(view.get_cast_effect_origin_global().y, expected.y, 0.01)
	assert_eq(view.position, position_before)


func test_zoom_modere_conserve_la_projection_et_le_format_de_reference() -> void:
	var expected_ranges := [Vector2(1.05, 1.10), Vector2(1.08, 1.12), Vector2(1.10, 1.15)]
	var expected_origins := [Vector2(688, 164.97778), Vector2(695, 172.5), Vector2(693.5, 137)]
	var expected_axes := [
		Vector2(34.4, 17.066667),
		Vector2(34.65, 17.5),
		Vector2(34.825, 17.5),
	]
	for index in ROOM_PATHS.size():
		var room := load(ROOM_PATHS[index]) as RoomData
		var visual := room.painted_map_visual_data
		var multiplier := visual.presentation_profile.camera_zoom_multiplier
		assert_gte(multiplier, expected_ranges[index].x - 0.0001)
		assert_lte(multiplier, expected_ranges[index].y + 0.0001)
		assert_eq(visual.source_image_size, Vector2i(1376, 768))
		assert_eq(visual.logical_grid_size, Vector2i(14, 14))
		assert_eq(visual.grid_origin, expected_origins[index])
		assert_eq(visual.axis_x, expected_axes[index])
		assert_eq(visual.axis_y, Vector2(-expected_axes[index].x, expected_axes[index].y))
		assert_lt(visual.calibration_rms(), 0.001)
		var cover := maxf(1920.0 / 1376.0, 1080.0 / 768.0)
		var width_percent := (
			100.0 * _platform_bounds(visual, room.grid_layout).size.x * cover
			* visual.camera_zoom * multiplier / 1920.0
		)
		assert_gte(width_percent, 65.0)
		assert_lte(width_percent, 72.0)


func test_chaque_tour_possede_un_occluder_y_sorte_depuis_le_background() -> void:
	for room_path in ROOM_PATHS:
		var room := load(room_path) as RoomData
		var visual := room.painted_map_visual_data
		assert_gte(visual.foreground_occluder_polygon.size(), 12, room.room_name)
		assert_gt(visual.foreground_occluder_sort_y, 400.0, room.room_name)
		var texture := visual.load_background_texture()
		var occluder := visual.create_foreground_occluder(texture)
		assert_not_null(occluder)
		assert_eq(occluder.position.y, visual.foreground_occluder_sort_y)
		assert_true(occluder.is_in_group("painted_foreground_occluders"))
		assert_eq(occluder.texture, texture)
		assert_eq(occluder.uv, visual.foreground_occluder_polygon)
		assert_true(visual.foreground_full_hide_rect.has_area())
		assert_true(visual.is_position_fully_occluded(
			visual.foreground_full_hide_rect.get_center()
		))
		assert_false(visual.is_position_fully_occluded(
			visual.foreground_full_hide_rect.end + Vector2.ONE
		))
		occluder.free()


func test_adaptateur_ne_touche_a_aucun_systeme_logique() -> void:
	var source := FileAccess.get_file_as_string("res://battle/painted/painted_battle.gd")
	for forbidden in [
		"GridData.new", "Pathfinder.new", "TerrainEffects.new",
		"hero_spawn_zone =", "enemy_spawn_zone =", "grid_pos =",
	]:
		assert_false(forbidden in source, forbidden)
	assert_true("apply_painted_presentation" in source)
	assert_true("presentation_profile" in source)


func test_exports_de_validation_sont_presents_aux_trois_resolutions() -> void:
	for room_path in ROOM_PATHS:
		var room := load(room_path) as RoomData
		var directory := "res://artifacts/maps/unit_presence_audit/%s" % (
			room.painted_map_visual_data.map_id
		)
		for filename in [
			"baseline_720p.png", "baseline.png", "baseline_1440p.png",
			"final_720p.png", "final.png", "final_1440p.png",
			"four_way_comparison.png", "resolution_comparison.png",
			"action_states_comparison.png",
		]:
			assert_true(FileAccess.file_exists("%s/%s" % [directory, filename]))
	assert_true(FileAccess.file_exists(
		"res://artifacts/maps/unit_presence_audit/unit_family_scale_ladder.png"
	))
	assert_true(FileAccess.file_exists(
		"res://artifacts/maps/unit_presence_audit/validation_summary.json"
	))


func _profile(index: int) -> BattlePresentationProfile:
	var room := load(ROOM_PATHS[index]) as RoomData
	return room.painted_map_visual_data.presentation_profile


func _fake_view(unit_id: StringName) -> Array:
	var view = UNIT_VIEW_SCENE.instantiate()
	add_child_autofree(view)
	view.unit = Unit.from_data(load(HERO_PATHS[unit_id]) as UnitData)
	var visual := FakePaintedVisual.new()
	view.add_child(visual)
	view.set("_optional_visual", visual)
	view.set("_painted_optional_base_scale", visual.scale)
	return [view, visual]


func _platform_bounds(
		visual: PaintedMapVisualData,
		layout: RoomGridLayout
	) -> Rect2:
	var points := PackedVector2Array()
	var void_lookup := {}
	for cell in layout.void_cells():
		void_lookup[cell] = true
	for y in range(layout.logical_size.y):
		for x in range(layout.logical_size.x):
			var cell := Vector2i(x, y)
			if void_lookup.has(cell):
				continue
			points.append_array(visual.cell_polygon(cell))
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)
