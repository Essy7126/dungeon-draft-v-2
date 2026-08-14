extends GutTest

const PROFILE_PATH := "res://vfx/profiles/test/synthetic_flipbook_profile.tres"
const ASSET_PATH := "res://vfx/profiles/test/synthetic_flipbook_asset.tres"
const MANIFEST_PATH := "res://vfx/manifests/test/synthetic_flipbook_foundation.json"
const LAB_SCENE := preload("res://tools/labs/vfx_flipbook_foundation/VFXFlipbookFoundationLab.tscn")
const DRAFT_ID := &"test.synthetic.flipbook.foundation.draft"
const HISTORICAL_FINGERPRINTS := {
	"res://vfx/profiles/test/shield_lifecycle.tres": "c5815dc78973a5a267e534aa0413a92955a83739c688b813621e611eab2365e6",
	"res://vfx/profiles/test/lightning_multi_target.tres": "4280f7bd681df740a208b0438bef057137c4d12a7f03286bbb46006d1c48f0dd",
	"res://vfx/profiles/test/player_path_preview.tres": "4645b13d03a9be611356c2a268b394848c59c06b3addecd6f8e071369d92c2bc",
}


func after_all() -> void:
	var draft_path := VFXDraftService.DRAFT_DIRECTORY.path_join("%s.json" % DRAFT_ID)
	if FileAccess.file_exists(draft_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(draft_path))
	var invalid_manifest := "user://vfx_flipbook_invalid_manifest.json"
	if FileAccess.file_exists(invalid_manifest):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_manifest))


func test_asset_structure_validation_matrix() -> void:
	assert_true(_asset().validate_structure().is_empty())
	var cases := [
		["asset_id", &"", "asset_id"],
		["columns", 0, "columns"],
		["rows", 0, "rows"],
		["frame_count", 0, "frame_count"],
		["frame_count", 33, "frame_count"],
		["frames_per_second", 0.0, "frames_per_second"],
		["frames_per_second", -2.0, "frames_per_second"],
		["blend_mode", &"SCREEN", "blend_mode"],
		["alpha_mode", &"MAGIC", "alpha_mode"],
		["pivot_normalized", Vector2(1.1, 0.5), "pivot_normalized"],
		["nominal_size_in_cells", Vector2(0.0, 1.0), "nominal_size_in_cells"],
		["license_status", &"", "license_status"],
	]
	for case in cases:
		var clone: VFXFlipbookAsset = _asset().duplicate(true) as VFXFlipbookAsset
		clone.set(case[0], case[1])
		assert_true(
			str(clone.validate_structure()).contains(str(case[2])),
			"Validation attendue pour %s" % case[0],
		)
	var no_variants: VFXFlipbookAsset = _asset().duplicate(true) as VFXFlipbookAsset
	no_variants.variants.clear()
	assert_true(str(no_variants.validate_structure()).contains("variante"))
	var duplicate_ids: VFXFlipbookAsset = _asset().duplicate(true) as VFXFlipbookAsset
	duplicate_ids.variants[1].variant_id = duplicate_ids.variants[0].variant_id
	assert_true(str(duplicate_ids.validate_structure()).contains("dupli"))
	var no_low: VFXFlipbookAsset = _asset().duplicate(true) as VFXFlipbookAsset
	no_low.variants[0].texture_low = null
	assert_true(str(no_low.validate_structure()).contains("LOW"))


func test_registry_accepts_typed_flipbook_and_rejects_generic_without_partial_node() -> void:
	assert_true(VFXModuleRegistry.knows(&"FlipbookModule"))
	var generic := VFXModuleData.new()
	generic.module_id = &"generic"
	generic.module_type = &"FlipbookModule"
	assert_null(VFXModuleRegistry.create_visual(generic, _context(), 4))
	var parent := Node2D.new()
	add_child_autofree(parent)
	var profile := _profile_with_module(generic)
	var result := VFXProfileRunner.play(profile, _context(), &"play", parent, false)
	assert_false(result.ok)
	assert_null(result.instance)
	assert_eq(parent.get_child_count(), 0)
	assert_true(str(result.errors).contains("VFXFlipbookModuleData"))
	var tampered := _module()
	tampered.module_type = &"FlashModule"
	var tampered_profile := _profile_with_module(tampered)
	var tampered_validation := VFXProfileValidator.validate(tampered_profile, _context(), &"play")
	assert_false(tampered_validation.ok)
	assert_true(str(tampered_validation.errors).contains("module_type FlipbookModule"))


func test_fit_duration_samples_exact_frames_and_frame_offset() -> void:
	var visual := _visual(_module(), _context(), 0)
	var samples := [
		[0.0, 0], [1.0 / 32.0, 1], [0.25, 8], [0.5, 16],
		[31.0 / 32.0, 31], [1.0, 31], [1.4, 31],
	]
	for sample in samples:
		visual.set_normalized_progress(sample[0])
		assert_eq(visual.get_current_frame(), sample[1], "progress=%s" % sample[0])
	visual.free()
	var offset_module := _module()
	offset_module.frame_offset = 3
	var offset_visual := _visual(offset_module, _context(), 0)
	offset_visual.set_normalized_progress(0.0)
	assert_eq(offset_visual.get_current_frame(), 3)
	offset_visual.set_normalized_progress(1.0)
	assert_eq(offset_visual.get_current_frame(), 31)
	offset_visual.free()


func test_source_fps_one_shot_and_loop_sampling() -> void:
	var one_shot := _module()
	one_shot.duration = 2.0
	one_shot.asset.playback_mode = &"SOURCE_FPS"
	one_shot.asset.frames_per_second = 10.0
	one_shot.asset.frame_count = 12
	var visual := _visual(one_shot, _context(), 0)
	for sample in [[0.0, 0], [0.25, 5], [0.5, 10], [1.0, 11], [1.5, 11]]:
		visual.set_normalized_progress(sample[0])
		assert_eq(visual.get_current_frame(), sample[1])
	visual.free()
	var looping := _module()
	looping.duration = 2.0
	looping.asset.playback_mode = &"SOURCE_FPS"
	looping.asset.frames_per_second = 10.0
	looping.asset.frame_count = 12
	looping.asset.loop = true
	looping.frame_offset = 2
	var loop_visual := _visual(looping, _context(), 0)
	loop_visual.set_normalized_progress(1.0)
	assert_eq(loop_visual.get_current_frame(), 10)
	loop_visual.set_normalized_progress(1.5)
	assert_eq(loop_visual.get_current_frame(), 8)
	loop_visual.free()


func test_runtime_speed_scale_quarter_half_and_one() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	for sample in [[0.25, 4], [0.5, 8], [1.0, 16]]:
		var module := _module()
		module.duration = 2.0
		var profile := _profile_with_module(module)
		var context := _context(2, int(sample[0] * 100), sample[0])
		var instance := _instance(profile, context, parent)
		instance.advance_simulation(1.0)
		var visual := instance._visuals[0] as VFXFlipbookVisual
		assert_eq(visual.get_current_frame(), sample[1], "speed=%s" % sample[0])
		instance.clear()
		instance.free()
	assert_eq(parent.get_child_count(), 0)


func test_variants_quality_fallbacks_and_global_rng_are_deterministic() -> void:
	seed(771122)
	var expected := randf()
	seed(771122)
	var first := _visual(_module(), _context(0, 100), 100)
	var second := _visual(_module(), _context(2, 100), 100)
	var other := _visual(_module(), _context(2, 100), 101)
	assert_eq(first.get_selected_variant_id(), second.get_selected_variant_id())
	assert_ne(first.get_selected_variant_id(), other.get_selected_variant_id())
	assert_true(first.get_selected_texture_path().ends_with("_low.png"))
	assert_true(second.get_selected_texture_path().ends_with("_high.png"))
	assert_eq(first.get_selected_quality_tier(), 0)
	assert_eq(second.get_selected_quality_tier(), 2)
	assert_almost_eq(randf(), expected, 0.0000001)
	first.free()
	second.free()
	other.free()
	var fallback_asset: VFXFlipbookAsset = _asset().duplicate(true) as VFXFlipbookAsset
	var variant := fallback_asset.variants[0]
	variant.texture_medium = null
	variant.texture_high = null
	assert_eq(fallback_asset.select_texture(variant, 0).quality_tier, 0)
	assert_eq(fallback_asset.select_texture(variant, 1).quality_tier, 0)
	assert_eq(fallback_asset.select_texture(variant, 2).quality_tier, 0)
	assert_same(fallback_asset.select_texture(variant, 2).texture, variant.texture_low)


func test_anchors_cell_scale_pivot_rotation_opacity_and_blend_modes() -> void:
	var anchors := {
		&"TARGET_WORLD": Vector2(100, 112),
		&"ORIGIN_WORLD": Vector2(20, 32),
		&"FIRST_IMPACT_WORLD": Vector2(180, 192),
	}
	for anchor in anchors:
		var module := _module()
		module.anchor = anchor
		module.rotation_degrees = 17.0
		module.opacity = 0.6
		var visual := _visual(module, _context(), 0)
		assert_true(visual.sprite.position.is_equal_approx(anchors[anchor]))
		assert_true(visual.sprite.scale.is_equal_approx(Vector2(1.5, 0.75)))
		assert_true(visual.sprite.offset.is_equal_approx(Vector2(0, -16)))
		assert_almost_eq(visual.sprite.rotation_degrees, 17.0, 0.001)
		assert_almost_eq(visual.sprite.modulate.a, 0.6, 0.001)
		visual.free()
	var blend_expectations := {
		&"MIX": CanvasItemMaterial.BLEND_MODE_MIX,
		&"ADD": CanvasItemMaterial.BLEND_MODE_ADD,
	}
	for blend in blend_expectations:
		var module := _module()
		module.asset.blend_mode = blend
		var visual := _visual(module, _context(), 0)
		assert_eq((visual.sprite.material as CanvasItemMaterial).blend_mode, blend_expectations[blend])
		visual.free()
	var straight_premult := _module()
	straight_premult.asset.blend_mode = &"PREMULTIPLIED"
	straight_premult.asset.alpha_mode = &"STRAIGHT"
	var straight_visual := _visual(straight_premult, _context(), 0)
	assert_true(straight_visual.sprite.material is ShaderMaterial)
	assert_true((straight_visual.sprite.material as ShaderMaterial).shader.code.contains("blend_premul_alpha"))
	straight_visual.free()
	var native_premult := _module()
	native_premult.asset.blend_mode = &"PREMULTIPLIED"
	native_premult.asset.alpha_mode = &"PREMULTIPLIED"
	var native_visual := _visual(native_premult, _context(), 0)
	assert_eq(
		(native_visual.sprite.material as CanvasItemMaterial).blend_mode,
		CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA,
	)
	native_visual.free()


func test_incomplete_anchor_context_is_refused_without_residue() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	for case in [
		[&"TARGET_WORLD", {"seed": 1}],
		[&"ORIGIN_WORLD", {"target_world": Vector2.ZERO, "seed": 1}],
		[&"FIRST_IMPACT_WORLD", {"target_world": Vector2.ZERO, "seed": 1}],
	]:
		var module := _module()
		module.anchor = case[0]
		module.context_requirements = []
		var result := VFXProfileRunner.play(
			_profile_with_module(module), VFXExecutionContext.create(case[1]), &"play", parent, false
		)
		assert_false(result.ok, str(case[0]))
		assert_null(result.instance)
		assert_eq(parent.get_child_count(), 0)


func test_complete_cancel_clear_timeout_and_parent_free_leave_no_visuals() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var delayed_module := _module()
	delayed_module.start_offset = 0.4
	var delayed := _instance(_profile_with_module(delayed_module), _context(), parent)
	var delayed_visual := delayed._visuals[0] as VFXFlipbookVisual
	assert_false(delayed_visual.visible)
	delayed.advance_simulation(0.2)
	assert_false(delayed_visual.visible)
	delayed.advance_simulation(0.2)
	assert_true(delayed_visual.visible)
	delayed.clear()
	delayed.free()
	var complete := _instance(_profile(), _context(), parent)
	complete.advance_simulation(2.0)
	assert_eq(complete.lifecycle_state, &"COMPLETED")
	assert_eq(complete.active_visual_count(), 0)
	complete.cancel()
	complete.clear()
	complete.clear()
	complete.free()
	var cancelled := _instance(_profile(), _context(), parent)
	cancelled.cancel()
	assert_eq(cancelled.lifecycle_state, &"CANCELLED")
	assert_eq(cancelled.active_visual_count(), 0)
	cancelled.clear()
	assert_eq(cancelled.lifecycle_state, &"CLEARED")
	cancelled.free()
	var timeout_profile := VFXProfileCopyService.new().duplicate_profile(_profile())
	timeout_profile.maximum_duration = 0.05
	var timed := _instance(timeout_profile, _context(), parent)
	timed.advance_simulation(0.1)
	assert_eq(timed.lifecycle_state, &"TIMEOUT")
	assert_eq(timed.active_visual_count(), 0)
	timed.free()
	var scene_root := Node2D.new()
	add_child(scene_root)
	var layer := Node2D.new()
	scene_root.add_child(layer)
	var parent_owned := _instance(_profile(), _context(), layer)
	scene_root.free()
	assert_false(is_instance_valid(parent_owned))
	assert_eq(parent.get_child_count(), 0)


func test_validator_scopes_flipbook_context_to_selected_enabled_sequence() -> void:
	var active_module := VFXModuleData.new()
	active_module.module_id = &"active_flash"
	active_module.module_type = &"FlashModule"
	active_module.duration = 1.0
	var active_sequence := VFXSequenceData.new()
	active_sequence.sequence_id = &"active"
	active_sequence.modules = [active_module]
	var hidden_module := _module()
	hidden_module.anchor = &"ORIGIN_WORLD"
	hidden_module.context_requirements = [&"origin_world"]
	var hidden_sequence := VFXSequenceData.new()
	hidden_sequence.sequence_id = &"hidden"
	hidden_sequence.modules = [hidden_module]
	var profile := VFXProfile.new()
	profile.profile_id = &"test.validator.sequence_scope"
	profile.render_policy = &"HYBRID_CAPABLE"
	profile.sequences = [active_sequence, hidden_sequence]
	var target_only := VFXExecutionContext.create({"target_world": Vector2(2, 3), "seed": 7})
	assert_true(VFXProfileValidator.validate(profile, target_only, &"active").ok)
	assert_false(VFXProfileValidator.validate(profile, target_only, &"hidden").ok)
	hidden_module.enabled = false
	assert_true(VFXProfileValidator.validate(profile, target_only, &"hidden").ok)


func test_repeated_load_complete_and_ten_simultaneous_instances_leave_no_nodes() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	for index in 100:
		var instance := _instance(_profile(), _context(index % 3, 1000 + index), parent)
		instance.advance_simulation(0.13)
		instance.clear()
		instance.free()
	assert_eq(parent.get_child_count(), 0)
	for index in 20:
		var instance := _instance(_profile(), _context(2, 2000 + index), parent)
		instance.advance_simulation(2.0)
		assert_eq(instance.active_visual_count(), 0)
		instance.free()
	assert_eq(parent.get_child_count(), 0)
	var simultaneous: Array[VFXRuntimeInstance] = []
	for index in 10:
		simultaneous.append(_instance(_profile(), _context(index % 3, 3000 + index), parent))
	assert_eq(parent.get_child_count(), 10)
	for instance in simultaneous:
		instance.cancel()
		instance.free()
	assert_eq(parent.get_child_count(), 0)


func test_snapshot_copy_and_durable_path_round_trip_keep_concrete_type() -> void:
	var source := _profile()
	var fingerprint := VFXProfileSnapshotService.fingerprint(source)
	var snapshot := VFXProfileSnapshotService.to_dictionary(source)
	var restored := VFXProfileSnapshotService.from_dictionary(snapshot)
	var source_module := source.get_sequence(&"play").modules[0] as VFXFlipbookModuleData
	var restored_module := restored.get_sequence(&"play").modules[0] as VFXFlipbookModuleData
	assert_not_same(restored, source)
	assert_not_same(restored.sequences[0], source.sequences[0])
	assert_not_same(restored_module, source_module)
	assert_eq(restored_module.asset.resource_path, ASSET_PATH)
	assert_eq(
		restored_module.asset.variants[0].texture_low.resource_path,
		source_module.asset.variants[0].texture_low.resource_path,
	)
	assert_eq(VFXProfileSnapshotService.fingerprint(restored), fingerprint)
	restored_module.scale_multiplier = Vector2(2.0, 1.0)
	assert_ne(restored_module.scale_multiplier, source_module.scale_multiplier)
	assert_true(VFXProfileSnapshotService.validate_durable_snapshot(source).is_empty())
	var transient_module := (
		_profile().get_sequence(&"play").modules[0].duplicate(false) as VFXFlipbookModuleData
	)
	transient_module.asset = _asset().duplicate(false) as VFXFlipbookAsset
	var transient := _profile_with_module(transient_module)
	assert_true(str(VFXProfileSnapshotService.validate_durable_snapshot(transient)).contains("persistant"))
	var transient_source_module := transient.sequences[0].modules[0] as VFXFlipbookModuleData
	var transient_copy := VFXProfileCopyService.new().duplicate_profile(transient)
	var transient_copy_module := transient_copy.sequences[0].modules[0] as VFXFlipbookModuleData
	assert_same(transient_copy_module.asset, transient_source_module.asset)
	assert_not_same(transient_copy_module, transient_source_module)
	var transient_document := VFXStudioDocument.new()
	assert_true(transient_document.open_profile(transient))
	assert_true(transient_document.record_edit("transient duration", func():
		transient_document.working_copy.sequences[0].modules[0].duration = 1.7
	))
	assert_true(transient_document.history.undo())
	assert_same(
		(transient_document.working_copy.sequences[0].modules[0] as VFXFlipbookModuleData).asset,
		transient_source_module.asset,
	)
	transient_document.history.clear()
	transient_document.history.configure(Callable(), Callable())
	transient_document = null


func test_document_undo_redo_and_draft_reload_preserve_flipbook() -> void:
	var editable := VFXProfileCopyService.new().duplicate_profile(_profile())
	editable.profile_id = DRAFT_ID
	var document := VFXStudioDocument.new()
	assert_true(document.open_profile(editable))
	var actions := [
		["placement", func(): (document.working_copy.sequences[0].modules[0] as VFXFlipbookModuleData).rotation_degrees = 23.0],
		["duration", func(): document.working_copy.sequences[0].modules[0].duration = 1.4],
		["opacity", func(): (document.working_copy.sequences[0].modules[0] as VFXFlipbookModuleData).opacity = 0.42],
		["scale", func(): (document.working_copy.sequences[0].modules[0] as VFXFlipbookModuleData).scale_multiplier = Vector2(1.3, 0.8)],
	]
	for action in actions:
		assert_true(document.record_edit(action[0], action[1]))
	var edited_fingerprint := document.current_fingerprint()
	for _index in actions.size():
		assert_true(document.history.undo())
	for _index in actions.size():
		assert_true(document.history.redo())
	assert_eq(document.current_fingerprint(), edited_fingerprint)
	var saved := VFXDraftService.new().save_draft(document)
	assert_true(saved.ok, str(saved))
	var loaded := VFXDraftService.new().load_draft(DRAFT_ID)
	assert_true(loaded.ok, str(loaded))
	var loaded_profile: VFXProfile = loaded.profile as VFXProfile
	var loaded_module: VFXModuleData = loaded_profile.sequences[0].modules[0]
	assert_true(loaded_module is VFXFlipbookModuleData)
	assert_eq((loaded_module as VFXFlipbookModuleData).asset.resource_path, ASSET_PATH)
	assert_eq(VFXProfileSnapshotService.fingerprint(loaded_profile), edited_fingerprint)
	var first_visual := _visual(loaded_module, _context(2, 91), 91)
	var first_variant := first_visual.get_selected_variant_id()
	first_visual.free()
	var replay_visual := _visual(loaded_module, _context(2, 91), 91)
	assert_eq(replay_visual.get_selected_variant_id(), first_variant)
	replay_visual.free()


func test_manifest_validation_failures_and_release_eligibility() -> void:
	var service := VFXFlipbookManifestService.new()
	var valid := service.load_and_validate(MANIFEST_PATH, _asset())
	assert_true(valid.ok, str(valid.errors))
	assert_false(service.is_release_eligible(valid.manifest, _asset()))
	var invalid_path := "user://vfx_flipbook_invalid_manifest.json"
	var file := FileAccess.open(invalid_path, FileAccess.WRITE)
	file.store_string("{ definitely invalid")
	file.close()
	assert_false(service.load_and_validate(invalid_path).ok)
	var bad_checksum := _manifest()
	bad_checksum.texture_checksums[bad_checksum.variants[0].texture_low] = "0".repeat(64)
	assert_true(str(service.validate(bad_checksum).errors).contains("Checksum texture"))
	var bad_layout := _manifest()
	bad_layout.frame_count = 999
	assert_true(str(service.validate(bad_layout).errors).contains("Layout"))
	var bad_texture := _manifest()
	bad_texture.variants[0].texture_low = bad_texture.variants[0].texture_medium
	assert_true(str(service.validate(bad_texture).errors).contains("Dimensions texture"))
	var duplicate := _manifest()
	duplicate.variants[1].variant_id = duplicate.variants[0].variant_id
	assert_true(str(service.validate(duplicate).errors).contains("dupli"))
	var empty_variants := _manifest()
	empty_variants.variants = []
	empty_variants.license_status = "COMMERCIAL_CLEARED"
	assert_false(service.is_release_eligible(empty_variants))
	var malformed_variants := _manifest()
	malformed_variants.variants[0] = 42
	var malformed_report := service.validate(malformed_variants, _asset())
	assert_false(malformed_report.ok)
	assert_true(str(malformed_report.errors).contains("Variante manifeste invalide"))
	var fallback_manifest := _manifest()
	for value in fallback_manifest.variants:
		var fallback_variant := value as Dictionary
		fallback_variant.erase("texture_medium")
		fallback_variant.erase("frame_size_medium")
		fallback_variant.erase("texture_high")
		fallback_variant.erase("frame_size_high")
	var fallback_asset := _asset().duplicate(false) as VFXFlipbookAsset
	var fallback_variants: Array[VFXFlipbookVariant] = []
	for source_variant in _asset().variants:
		var fallback_variant := VFXFlipbookVariant.new()
		fallback_variant.variant_id = source_variant.variant_id
		fallback_variant.texture_low = source_variant.texture_low
		fallback_variants.append(fallback_variant)
	fallback_asset.variants = fallback_variants
	var fallback_report := service.validate(fallback_manifest, fallback_asset)
	assert_true(fallback_report.ok, str(fallback_report.errors))
	assert_eq(fallback_asset.select_texture(fallback_asset.variants[0], 2).quality_tier, 0)
	var wrong_type := _manifest()
	wrong_type.columns = "8"
	assert_true(str(service.validate(wrong_type).errors).contains("Type manifeste"))
	var wrong_nested_type := _manifest()
	wrong_nested_type.variants[0].frame_size_low = "16"
	assert_true(str(service.validate(wrong_nested_type).errors).contains("frame_size_low"))
	var non_hex_generator := _manifest()
	non_hex_generator.generator_checksum = "z".repeat(64)
	assert_true(str(service.validate(non_hex_generator).errors).contains("Checksum generateur"))
	var resource_mismatch: VFXFlipbookAsset = _asset().duplicate(true) as VFXFlipbookAsset
	resource_mismatch.rows = 3
	assert_true(str(service.validate(_manifest(), resource_mismatch).errors).contains("Divergence rows"))
	var schema_mismatch := _asset().duplicate(false) as VFXFlipbookAsset
	schema_mismatch.schema_version = 2
	var schema_report := service.validate(_manifest(), schema_mismatch)
	assert_false(schema_report.ok)
	assert_true(str(schema_report.errors).contains("schema_version"))
	var path_mismatch := _asset().duplicate(false) as VFXFlipbookAsset
	path_mismatch.manifest_path = "res://vfx/manifests/test/not_the_fixture.json"
	assert_true(
		str(service.load_and_validate(MANIFEST_PATH, path_mismatch).errors).contains("manifest_path")
	)
	var evaluation := _manifest()
	evaluation.license_status = "EVALUATION_ONLY"
	assert_false(service.is_release_eligible(evaluation))
	var commercial := _manifest()
	commercial.license_status = "COMMERCIAL_CLEARED"
	assert_true(service.is_release_eligible(commercial))


func test_historical_profiles_registry_geometry_manager_gameplay_and_legacy_are_stable() -> void:
	for module_type in [
		&"ShieldSurfaceModule", &"ShieldRippleModule", &"LightningModule",
		&"PathRibbonModule", &"CellOverlayModule", &"ParticleBurstModule", &"FlashModule",
	]:
		assert_true(VFXModuleRegistry.knows(module_type))
		var module := VFXModuleData.new()
		module.module_id = module_type
		module.module_type = module_type
		var visual := VFXModuleRegistry.create_visual(module, _context(), 123)
		assert_not_null(visual)
		visual.free()
	for path in HISTORICAL_FINGERPRINTS:
		var profile := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as VFXProfile
		assert_not_null(profile)
		assert_eq(VFXProfileSnapshotService.fingerprint(profile), HISTORICAL_FINGERPRINTS[path])
	var lightning := ResourceLoader.load(
		"res://vfx/profiles/test/lightning_multi_target.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as VFXProfile
	var parent := Node2D.new()
	add_child_autofree(parent)
	var lightning_context := VFXExecutionContext.create({
		"origin_world": Vector2(20, 30), "target_world": Vector2(100, 100),
		"impact_world_points": PackedVector2Array([Vector2(100, 100)]), "seed": 744,
	})
	var geometry_a := _instance(lightning, lightning_context, parent).geometry_fingerprint()
	parent.get_child(0).free()
	var geometry_b := _instance(lightning, lightning_context, parent).geometry_fingerprint()
	assert_eq(geometry_a, geometry_b)
	parent.get_child(0).free()
	var gameplay := {"hp": 91, "damage": 13, "cells": [Vector2i(1, 2), Vector2i(2, 2)]}
	var gameplay_bytes := var_to_bytes(gameplay)
	seed(34567)
	var expected_random := randf()
	seed(34567)
	var managed := VFXManager.play_profile(_profile(), _context(), &"play", parent)
	assert_not_null(managed)
	managed.advance_simulation(0.25)
	assert_eq(var_to_bytes(gameplay), gameplay_bytes)
	assert_almost_eq(randf(), expected_random, 0.0000001)
	managed.clear()
	managed.free()
	assert_true(FileAccess.get_file_as_string("res://data/spell.gd").contains("vfx_scene"))
	assert_eq(parent.get_child_count(), 0)


func test_autonomous_lab_exposes_controls_and_fourteen_contract_scenarios() -> void:
	var lab: Node = LAB_SCENE.instantiate()
	add_child_autofree(lab)
	await get_tree().process_frame
	assert_not_null(lab.vfx_layer)
	assert_eq(lab.vfx_layer.name, "VFXLayer")
	assert_not_null(lab.stage)
	assert_not_null(lab.light_silhouette)
	assert_not_null(lab.dark_silhouette)
	assert_eq(lab.get_contract_scenarios().size(), 14)
	var captions: Array[String] = []
	for button in lab.find_children("*", "Button", true, false):
		captions.append((button as Button).text)
	for caption in [
		"Play", "Pause", "Resume", "Replay", "Clear", "0.25x", "0.5x", "1.0x",
		"LOW", "MEDIUM", "HIGH", "MIX", "ADD", "PREMULTIPLIED", "Light/Dark",
		"1 instance", "4 instances", "10 instances",
	]:
		assert_true(caption in captions, caption)
	for index in lab.get_contract_scenarios().size():
		var scenario_name: String = lab.get_contract_scenarios()[index]
		var result: Dictionary = lab.run_contract_scenario(index)
		assert_true(bool(result.get("ok", false)), scenario_name)
		match scenario_name:
			"four_instances":
				assert_eq(result.visuals.size(), 4)
			"ten_instances":
				assert_eq(result.visuals.size(), 10)
			"cancel_at_half", "loop_explicitly_stopped":
				assert_true(result.visuals.is_empty())
				assert_true(result.lifecycle_states.all(func(state): return state == "CANCELLED"))
			"parent_freed", "incomplete_context_refused":
				assert_eq(int(result.residual), 0)
			_:
				assert_eq(result.visuals.size(), 1)
		lab.clear()
		assert_eq(lab.vfx_layer.get_child_count(), 0)
	var source := FileAccess.get_file_as_string(
		"res://tools/labs/vfx_flipbook_foundation/vfx_flipbook_foundation_lab.gd"
	)
	for forbidden in [
		"ArenaDefinition", "ArenaEditSession", "ArenaRuntimePreview", "DynamicSurfaceService",
		"PaintedGridView", "RoomData", "RunData",
	]:
		assert_false(source.contains(forbidden), forbidden)


func test_lab_play_pause_resume_and_scrub_are_real_and_absolute() -> void:
	var lab: VFXFlipbookFoundationLab = LAB_SCENE.instantiate() as VFXFlipbookFoundationLab
	add_child_autofree(lab)
	await get_tree().process_frame
	lab.clear()
	lab.play()
	assert_eq(lab.current_instances.size(), 1)
	var playing := lab.current_instances[0] as VFXRuntimeInstance
	assert_true(playing.is_processing())
	lab.pause()
	assert_false(playing.is_processing())
	lab.resume()
	assert_true(playing.is_processing())
	lab.scrub_to(0.25)
	var quarter := lab.inspection_snapshot()
	assert_eq(int(quarter.visuals[0].frame), 8)
	assert_false((lab.current_instances[0] as VFXRuntimeInstance).is_processing())
	lab.scrub_to(0.10)
	var tenth := lab.inspection_snapshot()
	assert_eq(int(tenth.visuals[0].frame), 3)
	assert_lt((lab.current_instances[0] as VFXRuntimeInstance).elapsed, 0.11)
	lab.clear()
	assert_eq(lab.vfx_layer.get_child_count(), 0)


func test_versioned_launchers_are_portable_and_target_the_autonomous_lab() -> void:
	var paths := [
		"res://LANCER_LAB_VFX_FLIPBOOK.cmd",
		"res://OUVRIR_LAB_VFX_FLIPBOOK_DANS_GODOT.cmd",
		"res://tools/launchers/launch_vfx_flipbook_lab.ps1",
		"res://tools/labs/vfx_flipbook_foundation/smoke_vfx_flipbook_lab.gd",
		"res://docs/tools/vfx/vfx_flipbook_foundation_user_guide.md",
	]
	for path in paths:
		assert_true(FileAccess.file_exists(path), path)
	var launcher := FileAccess.get_file_as_string(paths[2])
	for token in ["GODOT4_BIN", "GODOT_BIN", "godot_path.txt", "Run", "Edit", "Smoke", "--version"]:
		assert_true(launcher.contains(token), token)
	assert_false(launcher.contains("C:\\Users\\"))
	assert_true(launcher.contains("VFXFlipbookFoundationLab.tscn"))
	assert_true(launcher.contains("smoke_vfx_flipbook_lab.gd"))
	assert_true(launcher.contains('$Mode -eq "Smoke"'))
	var smoke := FileAccess.get_file_as_string(paths[3])
	assert_true(smoke.contains("WATCHDOG_SECONDS"))


func _profile() -> VFXProfile:
	return ResourceLoader.load(PROFILE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as VFXProfile


func _asset() -> VFXFlipbookAsset:
	return ResourceLoader.load(ASSET_PATH) as VFXFlipbookAsset


func _module() -> VFXFlipbookModuleData:
	var source := _profile().get_sequence(&"play").modules[0] as VFXFlipbookModuleData
	var module := VFXFlipbookModuleData.new()
	module.module_id = source.module_id
	module.duration = source.duration
	module.anchor = source.anchor
	module.seed_offset = source.seed_offset
	module.context_requirements = source.context_requirements.duplicate()
	module.asset = source.asset.duplicate(true) as VFXFlipbookAsset
	module.scale_multiplier = source.scale_multiplier
	module.rotation_degrees = source.rotation_degrees
	module.opacity = source.opacity
	module.color_modulate = source.color_modulate
	module.frame_offset = source.frame_offset
	return module


func _profile_with_module(module: VFXModuleData) -> VFXProfile:
	var sequence := VFXSequenceData.new()
	sequence.sequence_id = &"play"
	sequence.modules = [module]
	var profile := VFXProfile.new()
	profile.profile_id = &"test.synthetic.transient"
	profile.render_policy = &"HYBRID_CAPABLE"
	profile.sequences = [sequence]
	profile.maximum_duration = 3.0
	return profile


func _context(quality := 2, context_seed := 44, speed_scale := 1.0) -> VFXExecutionContext:
	return VFXExecutionContext.create({
		"target_world": Vector2(100, 120),
		"origin_world": Vector2(20, 40),
		"impact_world_points": PackedVector2Array([Vector2(180, 200)]),
		"cell_visual_size": Vector2(96, 48),
		"quality_tier": quality,
		"seed": context_seed,
		"speed_scale": speed_scale,
	})


func _visual(
		module: VFXModuleData, context: VFXExecutionContext, local_seed: int
	) -> VFXFlipbookVisual:
	var visual := VFXModuleRegistry.create_visual(module, context, local_seed) as VFXFlipbookVisual
	assert_not_null(visual)
	return visual


func _instance(
		profile: VFXProfile, context: VFXExecutionContext, parent: Node
	) -> VFXRuntimeInstance:
	var result := VFXProfileRunner.play(profile, context, &"play", parent, false)
	assert_true(result.ok, str(result.get("errors", [])))
	return result.instance as VFXRuntimeInstance


func _manifest() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH)) as Dictionary
