extends GutTest
## Integration proof: the authored draft reaches the real runtime through its
## scaled viewport, with real click-to-move and no source or active-run writes.

const MAP := "res://data/halts/emerald_sanctuary_v1.json"
var viewport: SubViewport
var studio: PaintedHaltStudio


func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 1000)
	add_child_autofree(viewport)
	studio = PaintedHaltStudio.new()
	studio.auto_load = false
	viewport.add_child(studio)
	assert_true(studio.open_manifest(MAP))
	var catalog_paths: Array = []
	for index in studio.catalog.item_count:
		catalog_paths.append(studio.catalog.get_item_metadata(index))
	assert_has(catalog_paths, MAP)
	assert_has(catalog_paths, "res://data/halts/bronze_forge_v1.json")
	assert_does_not_have(catalog_paths, "res://data/halts/route_bindings.json")
	await wait_process_frames(3)


func after_each() -> void:
	studio.close_preview()
	studio.document.history.set_saved_fingerprint(studio.document.fingerprint())
	studio._remove_recovery()


func test_unsaved_draft_preview_routes_clicks_through_scaled_viewport() -> void:
	var source_hash := FileAccess.get_sha256(MAP)
	studio.document.set_property(["title"], "Aperçu non enregistré")
	studio.document.set_property(["water", "caustic_strength"], 0.16)
	studio.document.set_property(["water", "distortion_strength"], 0.68)
	studio.document.set_property(["water", "far_fade"], [0.18, 0.46])
	studio.document.set_property(["foliage_motion"], { "strength": 2.25, "speed": 0.72 })
	studio.document.set_property(["torches", 0, "flame_strength"], 0.75)
	studio.document.set_property(["torches", 0, "light_strength"], 1.3)
	studio.document.set_property(["torches", 0, "steady_light"], 0.37)
	studio.document.set_property(["torches", 0, "enclosed"], true)
	studio._refresh_material_preview()
	var authored_material := studio.canvas._painting.material as ShaderMaterial
	var height_field := studio.find_child("PlayerHeightPercent", true, false) as SpinBox
	assert_not_null(height_field)
	height_field.value = 24
	assert_almost_eq(float(studio.document.manifest.world.player_height_ratio), 0.24, 0.0001)
	var play: Button = _button("▶ Explorer")
	assert_not_null(play)
	await _click(play.get_global_rect().get_center())
	for frame in 180:
		if studio.preview_runtime != null and bool(studio.preview_runtime.get("_ready_for_play")):
			break
		await wait_process_frames(1)
	var runtime = studio.preview_runtime
	assert_not_null(runtime)
	if runtime == null:
		return
	assert_true(runtime._ready_for_play, "Actual runtime baked navigation and loaded Achille")
	var scale_ref := preload("res://hub/painted_halt/halt_scale_reference.gd")
	assert_almost_eq(
		runtime.player.display_scale * scale_ref.reference_height() / runtime.world_size.y,
		0.24,
		0.0001,
		"The real player matches the authored reference",
	)
	assert_eq(str(runtime.definition.title), "Aperçu non enregistré")
	for parameter in [
		"water_caustic_strength",
		"water_distortion_strength",
		"water_far_fade",
		"foliage_strength",
		"foliage_speed",
		"torch_strength",
	]:
		assert_eq(
			runtime.effect_material.get_shader_parameter(parameter),
			authored_material.get_shader_parameter(parameter),
			"Exploring the unsaved draft preserves the editor's material settings: " + parameter,
		)
	assert_almost_eq(float(runtime.effect_material.get_shader_parameter("foliage_strength")), 2.25, 0.0001)
	assert_almost_eq(float(runtime.effect_material.get_shader_parameter("foliage_speed")), 0.72, 0.0001)
	var torch_settings: PackedVector4Array = runtime.effect_material.get_shader_parameter(
		"torch_strength"
	)
	assert_eq(
		torch_settings[0],
		Vector4(0.75, 1.3, 0.37, 1.0),
		"All four channels reach the enclosed lantern",
	)
	assert_eq(torch_settings[1].w, 0.0, "Unflagged flames keep their existing animation")
	assert_true(
		runtime.interactions.bridge.preview,
		"Preview keeps transactions in its isolated session",
	)
	assert_eq(
		runtime.get_viewport().size,
		Vector2i(1280, 720),
		"Runtime HUD uses a fixed reviewable resolution",
	)
	var start: Vector2 = runtime.player.position
	var target: Vector2 = runtime.point([0.21, 0.81])
	assert_true(runtime.nav.is_walkable(target), "The click target is on the actual floor")
	var container := runtime.get_viewport().get_parent() as SubViewportContainer
	var click_point: Vector2 = container.get_global_transform() * runtime.world.to_global(target)
	await _click(click_point)
	for frame in 180:
		if runtime.player.position.distance_to(target) <= 2.0:
			break
		await wait_process_frames(1)
		if frame == 0 and runtime.is_player_moving():
			assert_almost_eq(
				runtime.ambience._distance,
				fposmod(float(runtime.player.get_visual_state().ground_stride), 38.0),
				0.01,
				"Sound and animation use the same calibrated step distance",
			)
	assert_gt(runtime.player.position.distance_to(start), 10.0, "A real canvas click moves Achille")
	assert_lt(
		runtime.player.position.distance_to(target),
		2.0,
		"Scaled input reaches the intended world point",
	)
	assert_true(runtime.nav.is_walkable(runtime.player.position))
	assert_eq(FileAccess.get_sha256(MAP), source_hash, "Preview never commits the source manifest")
	assert_true(studio.document.is_dirty())
	await _click(_button("Retour à la calibration").get_global_rect().get_center())
	assert_null(studio.preview_runtime)
	assert_true(studio.document.is_dirty(), "Closing the preview preserves the working copy")


func test_shader_preview_uses_authored_materials_and_original_toggle() -> void:
	studio._refresh_material_preview()
	var painting := studio.canvas._painting
	assert_not_null(painting.material)
	assert_true(painting.material is ShaderMaterial)
	assert_eq(painting.material.get_shader_parameter("water_caustic_strength"), 1.0)
	assert_eq(painting.material.get_shader_parameter("water_distortion_strength"), 1.0)
	assert_eq(painting.material.get_shader_parameter("water_far_fade"), Vector2.ZERO)
	assert_eq(painting.material.get_shader_parameter("foliage_strength"), 1.0)
	assert_eq(painting.material.get_shader_parameter("foliage_speed"), 1.0)
	var torch_settings: PackedVector4Array = painting.material.get_shader_parameter(
		"torch_strength"
	)
	assert_eq(torch_settings[0].w, 0.0, "Legacy lights are open flames by default")
	studio.document.set_property(["water", "tint"], "#2288cc")
	studio.document.set_property(["water", "caustic_strength"], 0.16)
	studio.document.set_property(["water", "distortion_strength"], 0.68)
	studio.document.set_property(["water", "far_fade"], [0.18, 0.46])
	studio._refresh_material_preview()
	var tint: Color = painting.material.get_shader_parameter("water_color")
	assert_eq(tint, Color("2288cc"))
	assert_almost_eq(float(painting.material.get_shader_parameter("water_caustic_strength")), 0.16, 0.0001)
	assert_almost_eq(float(painting.material.get_shader_parameter("water_distortion_strength")), 0.68, 0.0001)
	assert_eq(painting.material.get_shader_parameter("water_far_fade"), Vector2(0.18, 0.46))
	studio.canvas.set_effects_enabled(false)
	assert_null(painting.material)
	studio.canvas.set_effects_enabled(true)
	assert_not_null(painting.material)


func _button(label: String) -> Button:
	for button: Button in studio.find_children("*", "Button", true, false):
		if button.text == label:
			return button
	return null


func _click(point: Vector2, alt_pressed := false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	viewport.push_input(motion, true)
	await wait_process_frames(2)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.alt_pressed = alt_pressed
		event.pressed = pressed
		viewport.push_input(event, true)
		await wait_process_frames(2)


func test_newly_attached_source_can_play_before_godot_import() -> void:
	var path := "res://artifacts/dev/halt_preview_raw_%d.png" % Time.get_ticks_usec()
	var source := Image.create(64, 36, false, Image.FORMAT_RGBA8)
	source.fill(Color("355a4b"))
	assert_eq(source.save_png(path), OK)
	assert_false(FileAccess.file_exists(path + ".import"))
	studio.document.manifest.source.image = path
	studio.document.manifest.source.size = [64, 36]
	studio.document.manifest.source.sha256 = FileAccess.get_sha256(path)
	studio._image = source
	studio.canvas.set_document(studio.document, source)
	await _click(_button("▶ Explorer").get_global_rect().get_center())
	for frame in 180:
		if studio.preview_runtime != null and bool(studio.preview_runtime.get("_ready_for_play")):
			break
		await wait_process_frames(1)
	var runtime = studio.preview_runtime
	assert_not_null(runtime)
	if runtime != null:
		assert_true(runtime._ready_for_play)
		assert_eq(runtime.effect_material.get_shader_parameter("foliage_strength"), 1.0)
		assert_eq(runtime.effect_material.get_shader_parameter("foliage_speed"), 1.0)
		var torch_settings: PackedVector4Array = runtime.effect_material.get_shader_parameter(
			"torch_strength"
		)
		assert_eq(torch_settings[0].w, 0.0)
		var painting := runtime.world.get_child(0) as TextureRect
		assert_not_null(painting.texture)
		if painting.texture != null:
			assert_eq(
				painting.texture.get_width(),
				64,
				"Preview reads the freshly attached original without import metadata",
			)
	studio.close_preview()
	await wait_process_frames(2)
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK)


func test_scale_reference_can_be_placed_without_editing_navigation() -> void:
	var before := studio.document.fingerprint()
	var target := studio.canvas.to_canvas([0.4, 0.7])
	await _click(studio.canvas.get_global_transform() * target, true)
	assert_almost_eq(studio.canvas.scale_reference_position.x, 0.4, 0.001)
	assert_almost_eq(studio.canvas.scale_reference_position.y, 0.7, 0.001)
	assert_eq(
		studio.document.fingerprint(),
		before,
		"Reference placement never changes the spawn, geometry or history",
	)


func test_legacy_height_outside_new_range_is_shown_without_silent_clamping() -> void:
	studio.document.manifest.world.erase("player_height_ratio")
	studio.document.manifest.world.width = 6000
	studio.document.manifest.world.player_scale = 0.2
	studio.document.changed.emit()
	await wait_process_frames(2)
	var field := studio.find_child("PlayerHeightPercent", true, false) as SpinBox
	var actual: float = studio.canvas.ScaleReference.height_ratio(studio.document.manifest) * 100
	assert_almost_eq(field.value, actual, 0.01)
	assert_false(field.editable)
	assert_false(studio.document.manifest.world.has("player_height_ratio"))
	await _click(_button("Recalibrer l’échelle").get_global_rect().get_center())
	assert_almost_eq(float(studio.document.manifest.world.player_height_ratio), 0.22, 0.0001)
