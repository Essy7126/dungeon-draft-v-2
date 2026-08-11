extends GutTest

const SHIELD_PATH := "res://vfx/profiles/test/shield_lifecycle.tres"
const LIGHTNING_PATH := "res://vfx/profiles/test/lightning_multi_target.tres"
const PATH_PATH := "res://vfx/profiles/test/player_path_preview.tres"
const PUBLICATION_PATH := "res://test/fixtures/vfx/published/codex_vfx_slice_test.tres"
const DRAFT_ID := &"codex.vfx.slice.draft_test"


func after_all() -> void:
	_remove_owned_file(PUBLICATION_PATH)
	_remove_owned_file(VFXDraftService.DRAFT_DIRECTORY.path_join("%s.json" % DRAFT_ID))


func test_profiles_load_with_schema_stable_ids_sequences_and_placeholder_art() -> void:
	var profiles := _profiles()
	assert_eq(profiles.size(), 3)
	for profile in profiles:
		assert_not_null(profile)
		assert_eq(profile.schema_version, 1)
		assert_false(str(profile.profile_id).is_empty())
		assert_gt(profile.sequences.size(), 0)
		assert_eq(profile.art_status, &"TECHNICAL_PLACEHOLDER")
		assert_true(VFXProfileValidator.validate(profile).ok)
	assert_eq(profiles[0].sequences.size(), 4)
	assert_not_null(profiles[0].get_sequence(&"apply"))
	assert_not_null(profiles[0].get_sequence(&"hit"))
	assert_not_null(profiles[0].get_sequence(&"break"))
	assert_not_null(profiles[0].get_sequence(&"expire"))


func test_registry_covers_slice_modules_and_rejects_unknown_module() -> void:
	for module_type in [
		&"ShieldSurfaceModule", &"ShieldRippleModule", &"LightningModule",
		&"PathRibbonModule", &"CellOverlayModule", &"ParticleBurstModule", &"FlashModule",
	]:
		assert_true(VFXModuleRegistry.knows(module_type), str(module_type))
	assert_false(VFXModuleRegistry.knows(&"UnknownGameplayModule"))
	var invalid := VFXProfileCopyService.new().duplicate_profile(_profile(SHIELD_PATH))
	invalid.sequences[0].modules[0].module_type = &"UnknownGameplayModule"
	var report := VFXProfileValidator.validate(invalid)
	assert_false(report.ok)
	assert_true(str(report.errors).contains("Module inconnu"))


func test_missing_context_fails_cleanly_without_residual_node() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var result := VFXProfileRunner.play(
		_profile(LIGHTNING_PATH), VFXExecutionContext.create({"seed": 5}), &"play", parent, false
	)
	assert_false(result.ok)
	assert_null(result.instance)
	assert_eq(parent.get_child_count(), 0)
	assert_true(str(result.errors).contains("origin_world"))


func test_determinism_is_stable_and_does_not_advance_gameplay_rng() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	seed(918273)
	var expected_gameplay_random := randf()
	seed(918273)
	var first := _manual_instance(_profile(LIGHTNING_PATH), _lightning_context(3, 424242), &"play", parent)
	var first_fingerprint := first.geometry_fingerprint()
	first.clear()
	first.free()
	var gameplay_random_after_vfx := randf()
	assert_almost_eq(gameplay_random_after_vfx, expected_gameplay_random, 0.0000001)
	var second := _manual_instance(_profile(LIGHTNING_PATH), _lightning_context(3, 424242), &"play", parent)
	assert_eq(second.geometry_fingerprint(), first_fingerprint)
	second.clear()
	second.free()
	var different := _manual_instance(_profile(LIGHTNING_PATH), _lightning_context(3, 424243), &"play", parent)
	assert_ne(different.geometry_fingerprint(), first_fingerprint)
	different.clear()
	different.free()


func test_lifecycle_complete_cancel_clear_timeout_and_quality_tier() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var complete := _manual_instance(_profile(SHIELD_PATH), _shield_context(), &"apply", parent)
	var reasons: Array[StringName] = []
	complete.completed.connect(func(_instance, reason): reasons.append(reason))
	complete.advance_simulation(2.0)
	assert_eq(complete.lifecycle_state, &"COMPLETED")
	assert_eq(reasons, [&"COMPLETED"])
	assert_eq(complete.active_visual_count(), 0)
	complete.free()
	var cancelled := _manual_instance(_profile(SHIELD_PATH), _shield_context(), &"hit", parent)
	cancelled.cancel()
	assert_eq(cancelled.lifecycle_state, &"CANCELLED")
	assert_eq(cancelled.active_visual_count(), 0)
	cancelled.clear()
	assert_eq(cancelled.lifecycle_state, &"CLEARED")
	cancelled.free()
	var timeout_profile := VFXProfileCopyService.new().duplicate_profile(_profile(SHIELD_PATH))
	timeout_profile.maximum_duration = 0.05
	var timed := _manual_instance(timeout_profile, _shield_context(), &"apply", parent)
	timed.advance_simulation(0.1)
	assert_eq(timed.lifecycle_state, &"TIMEOUT")
	assert_eq(timed.active_visual_count(), 0)
	timed.free()
	var quality_profile := VFXProfileCopyService.new().duplicate_profile(_profile(SHIELD_PATH))
	quality_profile.get_sequence(&"apply").modules[0].minimum_quality = 2
	quality_profile.get_sequence(&"apply").modules[1].minimum_quality = 2
	var low_context := VFXExecutionContext.create({
		"target_world": Vector2.ZERO, "seed": 1, "quality_tier": 0,
	})
	var low := _manual_instance(quality_profile, low_context, &"apply", parent)
	assert_eq(low.active_visual_count(), 0)
	low.clear()
	low.free()


func test_deep_working_copy_has_no_shared_mutable_subresources() -> void:
	var source := _profile(SHIELD_PATH)
	var service := VFXProfileCopyService.new()
	var copy := service.duplicate_profile(source)
	assert_true(service.mutable_resources_are_distinct(source, copy))
	var original_color := source.sequences[0].modules[0].primary_color
	copy.sequences[0].modules[0].primary_color = Color.RED
	assert_eq(source.sequences[0].modules[0].primary_color, original_color)
	copy.sequences[0].modules[0].response_curve.set_point_value(1, 0.2)
	assert_ne(
		copy.sequences[0].modules[0].response_curve.get_point_position(1),
		source.sequences[0].modules[0].response_curve.get_point_position(1),
	)


func test_document_undo_redo_draft_save_and_reload() -> void:
	var profile := VFXProfileCopyService.new().duplicate_profile(_profile(SHIELD_PATH))
	profile.profile_id = DRAFT_ID
	var document := VFXStudioDocument.new()
	assert_true(document.open_profile(profile))
	var before := document.working_copy.sequences[0].modules[0].duration
	assert_true(document.record_edit("Durée test", func():
		document.working_copy.sequences[0].modules[0].duration = before + 0.2
	))
	assert_true(document.history.can_undo())
	assert_true(document.history.undo())
	assert_almost_eq(document.working_copy.sequences[0].modules[0].duration, before, 0.0001)
	assert_true(document.history.redo())
	assert_almost_eq(document.working_copy.sequences[0].modules[0].duration, before + 0.2, 0.0001)
	var draft := VFXDraftService.new().save_draft(document)
	assert_true(draft.ok, str(draft))
	assert_true(str(draft.path).begins_with("user://"))
	var loaded := VFXDraftService.new().load_draft(DRAFT_ID)
	assert_true(loaded.ok, str(loaded))
	assert_eq(
		VFXProfileSnapshotService.fingerprint(loaded.profile),
		VFXProfileSnapshotService.fingerprint(document.working_copy),
	)


func test_test_publication_is_validated_transactional_and_conflict_aware() -> void:
	_remove_owned_file(PUBLICATION_PATH)
	var service := VFXTestPublicationService.new()
	var refused := service.publish(_profile(SHIELD_PATH), "res://data/vfx/forbidden.tres")
	assert_false(refused.ok)
	var invalid := VFXProfileCopyService.new().duplicate_profile(_profile(SHIELD_PATH))
	invalid.schema_version = 999
	assert_false(service.publish(invalid, PUBLICATION_PATH).ok)
	var published := service.publish(_profile(SHIELD_PATH), PUBLICATION_PATH)
	assert_true(published.ok, str(published))
	assert_true(FileAccess.file_exists(PUBLICATION_PATH))
	var conflict := service.publish(_profile(SHIELD_PATH), PUBLICATION_PATH)
	assert_false(conflict.ok)
	assert_true(conflict.conflict)


func test_shield_all_four_sequences_and_lightning_one_or_many_targets() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var shield := _profile(SHIELD_PATH)
	for sequence_id in [&"apply", &"hit", &"break", &"expire"]:
		var instance := _manual_instance(shield, _shield_context(), sequence_id, parent)
		assert_gt(instance.active_visual_count(), 0, str(sequence_id))
		instance.advance_simulation(0.2)
		instance.clear()
		assert_eq(instance.active_visual_count(), 0)
		instance.free()
	var single := _manual_instance(_profile(LIGHTNING_PATH), _lightning_context(1, 12), &"play", parent)
	assert_gt(single.active_visual_count(), 0)
	single.clear()
	single.free()
	var many := _manual_instance(_profile(LIGHTNING_PATH), _lightning_context(6, 12), &"play", parent)
	assert_gt(many.active_visual_count(), 0)
	many.clear()
	many.free()


func test_player_path_uses_exact_ordered_cells_for_multiple_lengths_and_validity() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	for count in [2, 5, 9]:
		for valid in [true, false]:
			var context := _path_context(count, valid)
			assert_eq((context.get_value(&"ordered_path_cells") as Array).size(), count)
			assert_eq((context.get_value(&"path_world_points") as PackedVector2Array).size(), count)
			assert_eq(context.get_value(&"path_valid"), valid)
			var instance := _manual_instance(_profile(PATH_PATH), context, &"play", parent)
			assert_gt(instance.active_visual_count(), 0)
			instance.clear()
			instance.free()
	var source := FileAccess.get_file_as_string(PATH_PATH).to_lower()
	for forbidden in ["pathfind", "enemy", "telegraph", "ability_telegraphed"]:
		assert_false(source.contains(forbidden), "Le profil path reste joueur-only et sans calcul %s" % forbidden)


func test_twenty_play_clear_cycles_and_ten_simultaneous_instances_leave_no_nodes() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	for profile in _profiles():
		var sequence_id := profile.sequences[0].sequence_id
		for iteration in 20:
			var context := _context_for_profile(profile, iteration + 100)
			var instance := _manual_instance(profile, context, sequence_id, parent)
			instance.advance_simulation(0.06)
			instance.clear()
			instance.free()
	assert_eq(parent.get_child_count(), 0)
	var simultaneous: Array[VFXRuntimeInstance] = []
	for index in 10:
		simultaneous.append(_manual_instance(
			_profile(LIGHTNING_PATH), _lightning_context(4, 900 + index), &"play", parent
		))
	assert_eq(parent.get_child_count(), 10)
	for instance in simultaneous:
		instance.cancel()
		instance.free()
	assert_eq(parent.get_child_count(), 0)


func test_vfx_manager_additive_entry_preserves_legacy_and_gameplay_snapshot() -> void:
	var no_vfx_spell := Spell.new()
	assert_null(VFXManager.play_spell_vfx(null, no_vfx_spell, Vector2i.ZERO))
	var layer := Node2D.new()
	add_child_autofree(layer)
	var gameplay_result := {
		"hp": 73, "shield": 8, "affected_cells": [Vector2i(1, 1), Vector2i(2, 1)],
		"damage": 27, "cooldown": 2,
	}
	var without_vfx := gameplay_result.duplicate(true)
	var context := _shield_context()
	var instance := VFXManager.play_profile(_profile(SHIELD_PATH), context, &"apply", layer)
	assert_not_null(instance)
	instance.advance_simulation(0.2)
	assert_eq(gameplay_result, without_vfx, "Le runner VFX n’écrit aucun résultat gameplay.")
	instance.clear()
	instance.free()
	assert_eq(layer.get_child_count(), 0)


func test_composer_loads_catalogue_working_copy_preview_and_clear() -> void:
	var composer := VFXComposer.new()
	add_child_autofree(composer)
	composer.set_deferred("size", Vector2(1280, 760))
	await get_tree().process_frame
	assert_eq(composer.catalogue.item_count, 3)
	assert_not_null(composer.document.working_copy)
	assert_ne(composer.document.source, composer.document.working_copy)
	assert_true(composer.document.copy_service.mutable_resources_are_distinct(
		composer.document.source, composer.document.working_copy
	))
	composer.play_preview()
	assert_not_null(composer.current_instance)
	composer.clear_preview()
	assert_null(composer.current_instance)
	assert_eq(composer.stage.get_children().filter(func(child): return child is VFXRuntimeInstance).size(), 0)


func test_dungeon_draft_studio_registers_vfx_as_fourth_shared_domain() -> void:
	var studio := DungeonDraftStudioMain.new()
	add_child_autofree(studio)
	studio.set_deferred("size", Vector2(1500, 850))
	await get_tree().process_frame
	assert_eq(studio.tabs.get_tab_count(), 4)
	assert_eq(studio.tabs.get_tab_title(3), "VFX")
	assert_not_null(studio.vfx_composer)
	studio.tabs.current_tab = 3
	assert_same(studio._active_history_provider(), studio.vfx_composer)
	studio.prepare_for_close()


func _profiles() -> Array[VFXProfile]:
	return [_profile(SHIELD_PATH), _profile(LIGHTNING_PATH), _profile(PATH_PATH)]


func _profile(path: String) -> VFXProfile:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as VFXProfile


func _manual_instance(
		profile: VFXProfile,
		context: VFXExecutionContext,
		sequence_id: StringName,
		parent: Node
	) -> VFXRuntimeInstance:
	var result := VFXProfileRunner.play(profile, context, sequence_id, parent, false)
	assert_true(result.ok, str(result.get("errors", [])))
	return result.instance as VFXRuntimeInstance


func _shield_context() -> VFXExecutionContext:
	return VFXExecutionContext.create({
		"target_world": Vector2(320, 220),
		"impact_world_points": PackedVector2Array([Vector2(342, 208)]),
		"seed": 424242, "quality_tier": 2, "magnitude": 0.8,
	})


func _lightning_context(count: int, context_seed: int) -> VFXExecutionContext:
	var points := PackedVector2Array()
	for index in count:
		points.append(Vector2(340 + index * 42, 120 + (index % 3) * 92))
	return VFXExecutionContext.create({
		"origin_world": Vector2(90, 240), "target_world": points[-1],
		"impact_world_points": points, "impact_timings": [],
		"seed": context_seed, "quality_tier": 2,
	})


func _path_context(count: int, valid: bool) -> VFXExecutionContext:
	var cells: Array[Vector2i] = []
	var points := PackedVector2Array()
	for index in count:
		cells.append(Vector2i(index, index % 2))
		points.append(Vector2(80 + index * 55, 180 + (index % 2) * 26))
	return VFXExecutionContext.create({
		"origin_cell": cells[0], "target_cell": cells[-1],
		"ordered_path_cells": cells, "path_world_points": points,
		"origin_world": points[0], "target_world": points[-1],
		"impact_world_points": PackedVector2Array([points[-1]]),
		"path_valid": valid, "seed": 31337, "quality_tier": 2,
		"consumer_kind": &"PLAYER_CONTROLLED",
	})


func _context_for_profile(profile: VFXProfile, context_seed: int) -> VFXExecutionContext:
	if profile.profile_id == &"test.shield.lifecycle":
		return _shield_context()
	if profile.profile_id == &"test.lightning.multi_target":
		return _lightning_context(4, context_seed)
	return _path_context(7, true)


func _remove_owned_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
