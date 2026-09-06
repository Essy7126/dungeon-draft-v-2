extends GutTest

const UNIT_PATH := "res://data/units/enemies/catabase_shadow_paris.tres"


func test_opposite_directions_reuse_the_exact_native_atlas_regions() -> void:
	var fixture := _fixture()
	var view: ParisIsoUnitView = fixture.visual
	for bank: SpriteFrames in [view._spectral_frames, view._infernal_frames]:
		for stem: String in ["idle", "walk", "attack", "cast", "hit", "death"]:
			_assert_alias(bank, stem + "_S", stem + "_E")
			_assert_alias(bank, stem + "_W", stem + "_N")
	_assert_alias(view._transformation_frames, "transform_S", "transform_E")
	_assert_alias(view._transformation_frames, "transform_W", "transform_N")


func test_every_pose_family_preserves_controlled_mirror_and_centered_ground_anchor() -> void:
	var fixture := _fixture()
	var view: ParisIsoUnitView = fixture.visual
	for form: StringName in [&"spectral", &"infernal"]:
		if form == &"infernal":
			(fixture.unit as Unit).take_damage(97)
			view.advance_simulation(0.9)
		for direction: String in ["E", "N", "S", "W"]:
			view.set_facing_label(direction)
			for stem: String in ["idle", "walk", "attack", "cast", "hit", "death"]:
				for phase: float in [0.0, 0.45, 1.0]:
					view._sample_normalized(stem, phase)
					assert_eq(view.animated_sprite.flip_h, direction in ["S", "W"])
					assert_false(view.animated_sprite.flip_v)
					assert_eq(view.get_visual_runtime_state().authored_view, "E" if direction in ["E", "S"] else "N")
					_assert_anchor(view)
			view.play_idle()
			assert_eq(view.animated_sprite.flip_h, direction in ["S", "W"])


func test_queued_facing_waits_for_cast_and_transformation_before_changing_mirror() -> void:
	var fixture := _fixture()
	var view: ParisIsoUnitView = fixture.visual
	view.set_facing_label("E")
	assert_true(view.play_cast())
	view.set_facing_label("S")
	view.advance_simulation(0.4)
	assert_false(view.animated_sprite.flip_h)
	assert_eq(view.get_visual_runtime_state().facing, "E")
	view.advance_simulation(0.4)
	assert_true(view.animated_sprite.flip_h)
	assert_eq(view.animated_sprite.animation, &"idle_S")
	view.set_facing_label("N")
	(fixture.unit as Unit).take_damage(97)
	view.set_facing_label("W")
	view.advance_simulation(0.4)
	assert_false(view.animated_sprite.flip_h)
	assert_eq(view.animated_sprite.animation, &"transform_N")
	view.advance_simulation(0.5)
	assert_true(view.animated_sprite.flip_h)
	assert_eq(view.animated_sprite.animation, &"idle_W")
	(fixture.unit as Unit).take_damage(999)
	view.advance_simulation(0.3)
	assert_true(view.animated_sprite.flip_h)
	assert_eq(view.animated_sprite.animation, &"death_W")
	_assert_anchor(view)


func test_spectral_arrow_and_infernal_whip_origins_are_exactly_symmetric() -> void:
	var fixture := _fixture()
	var view: ParisIsoUnitView = fixture.visual
	for form: StringName in [&"spectral", &"infernal"]:
		if form == &"infernal":
			(fixture.unit as Unit).take_damage(97)
			view.advance_simulation(0.9)
		for pair: Array in [["E", "S"], ["N", "W"]]:
			view.set_facing_label(pair[0])
			var native := view.get_default_cast_effect_origin()
			view.set_facing_label(pair[1])
			var mirrored := view.get_default_cast_effect_origin()
			assert_eq(mirrored, Vector2(-native.x, native.y))
			_assert_anchor(view)


func _fixture() -> Dictionary:
	var unit := Unit.from_data(load(UNIT_PATH) as UnitData)
	var wrapper := (load("res://battle/unit_view.gd") as Script).new() as Node2D
	add_child_autofree(wrapper)
	wrapper.position = Vector2(187, 243)
	wrapper.setup(unit, false)
	var visual := wrapper.get_optional_visual() as ParisIsoUnitView
	visual.set_process(false)
	return {"unit": unit, "wrapper": wrapper, "visual": visual}


func _assert_alias(bank: SpriteFrames, alias_name: String, native_name: String) -> void:
	assert_eq(bank.get_frame_count(alias_name), bank.get_frame_count(native_name))
	for index in bank.get_frame_count(native_name):
		var alias := bank.get_frame_texture(alias_name, index) as AtlasTexture
		var native := bank.get_frame_texture(native_name, index) as AtlasTexture
		assert_not_null(alias)
		assert_not_null(native)
		if alias == null or native == null:
			continue
		assert_eq(alias.atlas, native.atlas)
		assert_eq(alias.region, native.region)
		assert_eq(bank.get_frame_duration(alias_name, index), bank.get_frame_duration(native_name, index))


func _assert_anchor(view: ParisIsoUnitView) -> void:
	var sprite := view.animated_sprite
	assert_almost_eq(sprite.to_global(sprite.offset + view.sprite_profile.foot_anchor),
		(view.get_parent() as Node2D).global_position, Vector2(0.001, 0.001))
