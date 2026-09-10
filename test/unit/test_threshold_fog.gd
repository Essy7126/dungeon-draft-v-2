extends GutTest
## Component contracts only: no scene render, shader pixel threshold or production writes.

const Fog := preload("res://hub/catabase_threshold/threshold_fog.gd")
var fog: Fog
var mask_path := ""


func before_each() -> void:
	fog = Fog.new()
	add_child_autofree(fog)
	mask_path = ""


func after_each() -> void:
	if not mask_path.is_empty() and FileAccess.file_exists(mask_path):
		assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(mask_path)), OK)


func _surface() -> ColorRect:
	return fog.get_node("ThresholdGroundFog") as ColorRect


func _material() -> ShaderMaterial:
	return _surface().material as ShaderMaterial


func test_unmasked_fallback_is_visible_and_cannot_capture_floor_input() -> void:
	assert_true(fog.configure(Vector2(1600, 900), { }))
	assert_true(fog.configured)
	assert_eq(fog.configuration_error, "")
	var surface := _surface()
	assert_true(surface.visible)
	assert_eq(surface.position, Vector2.ZERO)
	assert_eq(surface.size, Vector2(1600, 900))
	assert_eq(surface.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(surface.focus_mode, Control.FOCUS_NONE)
	assert_false(fog.is_processing(), "The owner, not a frame callback, advances this effect")
	assert_false(bool(_material().get_shader_parameter("has_density_mask")))


func test_explicit_missing_mask_hides_previous_fog_until_configuration_recovers() -> void:
	assert_true(fog.configure(Vector2(1600, 900), { }))
	var previous_surface := _surface()
	var missing := "res://artifacts/dev/threshold-fog-fixtures/missing-%d.png" % Time.get_ticks_usec()
	assert_false(
		fog.configure(Vector2(1600, 900), { "threshold_fog": { "density_mask": missing } })
	)
	assert_false(fog.configured)
	assert_false(fog.configuration_error.is_empty())
	assert_false(previous_surface.visible, "A failed authored mask must not cover a cleared route")
	fog.set_state(12.0, true, false)
	assert_false(
		previous_surface.visible,
		"The owner's next enabled tick cannot revive invalid fog",
	)
	assert_true(fog.configure(Vector2(800, 450), { }))
	assert_eq(fog.configuration_error, "")
	assert_eq(_surface(), previous_surface)
	assert_eq(fog.get_child_count(), 1, "Reconfiguration must not stack transparent overlays")
	assert_true(previous_surface.visible)
	assert_eq(previous_surface.size, Vector2(800, 450))


func test_reconfigure_clears_previous_mask_and_settings_without_changing_source() -> void:
	var folder := "res://artifacts/dev/threshold-fog-fixtures"
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)), OK)
	mask_path = folder.path_join("density-%d-%d.png" % [Time.get_ticks_usec(), randi()])
	var source := Image.create(2, 1, false, Image.FORMAT_RGB8)
	source.fill(Color.BLACK)
	source.set_pixel(1, 0, Color.WHITE)
	assert_eq(source.save_png(ProjectSettings.globalize_path(mask_path)), OK)
	var original_hash := FileAccess.get_sha256(mask_path)
	var definition := {
		"threshold_fog": { "density_mask": mask_path, "opacity": 0.45, "seed": 82.0 }
	}
	var original_definition := definition.duplicate(true)
	assert_true(fog.configure(Vector2(1600, 900), definition))
	assert_eq(definition, original_definition)
	assert_true(bool(_material().get_shader_parameter("has_density_mask")))
	var texture := _material().get_shader_parameter("density_mask") as Texture2D
	assert_not_null(texture)
	if texture != null:
		assert_eq(texture.get_image().get_pixel(0, 0).r, 0.0)
		assert_eq(texture.get_image().get_pixel(1, 0).r, 1.0)
	assert_eq(FileAccess.get_sha256(mask_path), original_hash)
	fog.set_state(8.0, false, false)
	assert_true(fog.configure(Vector2(1200, 700), { }))
	assert_false(_surface().visible, "Switching masks must preserve the owner's disabled state")
	assert_eq(fog.get_child_count(), 1)
	assert_false(bool(_material().get_shader_parameter("has_density_mask")))
	assert_null(_material().get_shader_parameter("density_mask"))
	assert_almost_eq(float(_material().get_shader_parameter("opacity")), 0.20, 0.0001)
	fog.set_state(8.0, true, false)
	assert_true(_surface().visible)


func test_supplied_clock_can_pause_and_scrub_without_accumulating_time() -> void:
	assert_true(fog.configure(Vector2(1600, 900), { }))
	fog.set_state(17.25, true, false)
	var material := _material()
	for repetition in 4:
		fog.set_state(17.25, true, false)
	assert_almost_eq(float(material.get_shader_parameter("effect_time")), 17.25, 0.0001)
	fog.set_state(2.5, true, false)
	assert_almost_eq(
		float(material.get_shader_parameter("effect_time")),
		2.5,
		0.0001,
		"Seeking an owner's clock backwards must reproduce the earlier phase",
	)
	fog.set_state(NAN, false, false)
	assert_almost_eq(float(material.get_shader_parameter("effect_time")), 2.5, 0.0001)
	assert_true(_surface().visible, "An invalid time cannot corrupt the last valid visual state")


func test_reduced_mode_freezes_phase_across_ticks_and_visibility_changes() -> void:
	assert_true(fog.configure(Vector2(1600, 900), { "threshold_fog": { "reduced_strength": 0.4 } }))
	fog.set_state(20.0, true, false)
	fog.set_state(21.0, true, true)
	var material := _material()
	assert_almost_eq(float(material.get_shader_parameter("effect_time")), 21.0, 0.0001)
	assert_almost_eq(float(material.get_shader_parameter("effect_strength")), 0.4, 0.0001)
	fog.set_state(45.0, true, true)
	fog.set_state(60.0, false, true)
	assert_false(_surface().visible)
	fog.set_state(90.0, true, true)
	assert_true(_surface().visible)
	assert_almost_eq(
		float(material.get_shader_parameter("effect_time")),
		21.0,
		0.0001,
		"Reduced fog must stay still while the surrounding scene keeps advancing",
	)
	fog.set_state(91.0, true, false)
	assert_almost_eq(float(material.get_shader_parameter("effect_time")), 91.0, 0.0001)
	assert_almost_eq(float(material.get_shader_parameter("effect_strength")), 1.0, 0.0001)


func test_disabled_or_zero_opacity_stays_hidden_and_bad_extent_can_recover() -> void:
	fog.set_state(4.0, false, false)
	assert_true(fog.configure(Vector2(1600, 900), { }))
	assert_false(_surface().visible, "State can be provided before scene configuration")
	fog.set_state(4.0, true, false)
	assert_true(_surface().visible)
	assert_true(fog.configure(Vector2(1600, 900), { "threshold_fog": { "opacity": 0.0 } }))
	fog.set_state(5.0, true, false)
	assert_false(_surface().visible)
	assert_false(fog.configure(Vector2.ZERO, { }))
	assert_false(fog.configured)
	assert_false(_surface().visible)
	assert_true(fog.configure(Vector2(1600, 900), { }))
	assert_true(fog.configured)
	assert_true(_surface().visible)
	assert_eq(fog.get_child_count(), 1)
