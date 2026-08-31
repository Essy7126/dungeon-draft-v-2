extends GutTest

const SHIELD_PATH := "res://vfx/profiles/test/shield_lifecycle.tres"
const LIGHTNING_PATH := "res://vfx/profiles/test/lightning_multi_target.tres"
const PATH_PATH := "res://vfx/profiles/test/player_path_preview.tres"
const PUBLICATION_PATH := "res://test/fixtures/vfx/published/codex_vfx_slice_test.tres"
const DRAFT_ID := &"codex.vfx.slice.draft_test"
const INVALID_DRAFT_ID := &"codex.vfx.slice.invalid_recovery"
const CONCURRENT_DRAFT_ID := &"codex.vfx.slice.concurrent_recovery"
const EXTERNAL_BASELINE_DRAFT_ID := &"codex.vfx.slice.external_baseline"


func after_all() -> void:
	_remove_owned_file(PUBLICATION_PATH)
	_remove_owned_file(VFXDraftService.DRAFT_DIRECTORY.path_join("%s.json" % DRAFT_ID))
	_remove_owned_file(VFXDraftService.DRAFT_DIRECTORY.path_join("%s.json" % INVALID_DRAFT_ID))
	_remove_owned_file(VFXDraftService.DRAFT_DIRECTORY.path_join("%s.json" % CONCURRENT_DRAFT_ID))
	_remove_owned_file(VFXDraftService.DRAFT_DIRECTORY.path_join(
		"%s.json" % EXTERNAL_BASELINE_DRAFT_ID
	))


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
	_remove_owned_file(VFXDraftService.DRAFT_DIRECTORY.path_join("%s.json" % DRAFT_ID))
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
	var draft_bytes := FileAccess.get_file_as_bytes(str(draft.path))
	assert_true(document.record_edit("Échec transactionnel", func():
		document.working_copy.sequences[0].modules[0].duration += 0.3
	))
	var failing_service := VFXDraftService.new()
	failing_service.force_failure_after_replace = true
	var failed := failing_service.save_draft(document)
	assert_false(failed.ok)
	assert_true(bool(failed.get("rolled_back", false)), str(failed))
	assert_eq(FileAccess.get_file_as_bytes(str(draft.path)), draft_bytes)
	assert_true(document.is_dirty())


func test_draft_service_rejects_path_traversal_profile_id() -> void:
	for unsafe_id in [&"../outside", &"CON", &"com1.profile", &"LPT9"]:
		var profile := VFXProfileCopyService.new().duplicate_profile(_profile(SHIELD_PATH))
		profile.profile_id = unsafe_id
		var document := VFXStudioDocument.new()
		assert_true(document.open_profile(profile))
		var result := VFXDraftService.new().save_draft(document)
		assert_false(result.ok, str(unsafe_id))
		assert_eq(result.get("code", ""), "unsafe_profile_id", str(unsafe_id))


func test_draft_rollback_preserves_third_party_json_and_durable_backup() -> void:
	_remove_owned_file(VFXDraftService.DRAFT_DIRECTORY.path_join(
		"%s.json" % CONCURRENT_DRAFT_ID
	))
	var profile := VFXProfileCopyService.new().duplicate_profile(_profile(SHIELD_PATH))
	profile.profile_id = CONCURRENT_DRAFT_ID
	var document := VFXStudioDocument.new()
	assert_true(document.open_profile(profile))
	var initial := VFXDraftService.new().save_draft(document)
	assert_true(initial.ok, str(initial))
	var original_bytes := FileAccess.get_file_as_bytes(str(initial.path))
	assert_true(document.record_edit("Écriture Studio", func():
		document.working_copy.sequences[0].modules[0].duration += 0.4
	))
	var external_duration := 7.25
	var hook_result := {"ok": false, "sha256": ""}
	var service := VFXDraftService.new()
	service.before_verification_hook = func(written_path: String):
		var external := VFXProfileCopyService.new().duplicate_profile(_profile(SHIELD_PATH))
		external.profile_id = CONCURRENT_DRAFT_ID
		external.sequences[0].modules[0].duration = external_duration
		var external_file := FileAccess.open(written_path, FileAccess.WRITE)
		if external_file != null:
			external_file.store_string(JSON.stringify(
				VFXProfileSnapshotService.to_dictionary(external), "  "
			))
			external_file.flush()
			external_file.close()
			hook_result["ok"] = true
			hook_result["sha256"] = FileAccess.get_sha256(written_path)
	var failed := service.save_draft(document)
	assert_true(hook_result.ok)
	assert_false(failed.ok, str(failed))
	assert_false(bool(failed.get("rolled_back", true)), str(failed))
	assert_true(bool((failed.rollback as Dictionary).get(
		"skipped_external_change", false
	)), str(failed))
	assert_eq(FileAccess.get_sha256(str(initial.path)), hook_result.sha256)
	var external_loaded := service.load_draft(CONCURRENT_DRAFT_ID)
	assert_true(external_loaded.ok, str(external_loaded))
	assert_eq(
		external_loaded.profile.sequences[0].modules[0].duration,
		external_duration,
	)
	var transaction := failed.transaction as Dictionary
	assert_true(FileAccess.file_exists(str(transaction.manifest_path)))
	assert_true(FileAccess.file_exists(str(transaction.backup_path)))
	assert_eq(
		FileAccess.get_file_as_bytes(str(transaction.backup_path)),
		original_bytes,
	)
	var manifest = JSON.parse_string(
		FileAccess.get_file_as_string(str(transaction.manifest_path))
	)
	assert_true(manifest is Dictionary)
	assert_eq(str((manifest as Dictionary).get("status", "")), "PREPARED")
	assert_false(str((manifest as Dictionary).get("staged_sha256", "")).is_empty())
	_remove_owned_file(str(transaction.get("local_backup_path", "")))
	service._cleanup_transaction(transaction)


func test_draft_save_refuses_a_change_made_since_the_last_verified_save() -> void:
	var path := VFXDraftService.DRAFT_DIRECTORY.path_join(
		"%s.json" % EXTERNAL_BASELINE_DRAFT_ID
	)
	_remove_owned_file(path)
	var profile := VFXProfileCopyService.new().duplicate_profile(_profile(SHIELD_PATH))
	profile.profile_id = EXTERNAL_BASELINE_DRAFT_ID
	var document := VFXStudioDocument.new()
	assert_true(document.open_profile(profile))
	var service := VFXDraftService.new()
	var initial := service.save_draft(document)
	assert_true(initial.ok, str(initial))
	var external := VFXProfileCopyService.new().duplicate_profile(profile)
	external.sequences[0].modules[0].duration = 8.75
	var external_file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(external_file)
	external_file.store_string(JSON.stringify(
		VFXProfileSnapshotService.to_dictionary(external), "  "
	))
	external_file.flush()
	external_file.close()
	var external_sha := FileAccess.get_sha256(path)
	assert_true(document.record_edit("Écriture locale après concurrence", func():
		document.working_copy.sequences[0].modules[0].duration += 0.2
	))
	var refused := service.save_draft(document)
	assert_false(refused.ok, str(refused))
	assert_eq(str(refused.get("code", "")), "external_change")
	assert_eq(FileAccess.get_sha256(path), external_sha)
	assert_true(document.is_dirty())
	var recovery := service.save_recovery(document)
	assert_true(recovery.ok, str(recovery))
	assert_true(str(recovery.path).begins_with(VFXDraftService.RECOVERY_DIRECTORY + "/"))
	assert_true(FileAccess.file_exists(str(recovery.path)))
	_remove_owned_file(str(recovery.path))


func test_draft_save_rechecks_baseline_immediately_before_transaction() -> void:
	var path := VFXDraftService.DRAFT_DIRECTORY.path_join(
		"%s.json" % EXTERNAL_BASELINE_DRAFT_ID
	)
	_remove_owned_file(path)
	var profile := VFXProfileCopyService.new().duplicate_profile(_profile(SHIELD_PATH))
	profile.profile_id = EXTERNAL_BASELINE_DRAFT_ID
	var document := VFXStudioDocument.new()
	assert_true(document.open_profile(profile))
	var initial_service := VFXDraftService.new()
	assert_true(initial_service.save_draft(document).ok)
	assert_true(document.record_edit("Écriture locale concurrente", func():
		document.working_copy.sequences[0].modules[0].duration += 0.3
	))
	var external_sha := {"value": ""}
	var service := VFXDraftService.new()
	service.before_transaction_hook = func(target_path: String):
		var external := VFXProfileCopyService.new().duplicate_profile(profile)
		external.sequences[0].modules[0].duration = 6.5
		var file := FileAccess.open(target_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(
				VFXProfileSnapshotService.to_dictionary(external), "  "
			))
			file.flush()
			file.close()
			external_sha["value"] = FileAccess.get_sha256(target_path)
	var refused := service.save_draft(document)
	assert_false(refused.ok, str(refused))
	assert_eq(str(refused.get("code", "")), "external_change")
	assert_false(str(external_sha.value).is_empty())
	assert_eq(FileAccess.get_sha256(path), str(external_sha.value))


func test_document_snapshot_restores_transient_flipbook_and_full_history() -> void:
	var profile := VFXProfileCopyService.new().duplicate_profile(_profile(SHIELD_PATH))
	var module := VFXFlipbookModuleData.new()
	module.module_id = &"transient_flipbook"
	module.module_type = &"FlipbookModule"
	module.asset = VFXFlipbookAsset.new()
	module.asset.asset_id = &"transient_asset"
	profile.sequences[0].modules[0] = module
	var document := VFXStudioDocument.new()
	assert_true(document.open_profile(profile))
	assert_true(document.record_edit("Opacité intermédiaire", func():
		(document.working_copy.sequences[0].modules[0] as VFXFlipbookModuleData).opacity = 0.6
	))
	var snapshot := document.snapshot_state()
	var snapshot_asset := (
		document.working_copy.sequences[0].modules[0] as VFXFlipbookModuleData
	).asset
	snapshot_asset.display_name = "Mutation après snapshot"
	snapshot_asset.columns = 9
	assert_true(document.record_edit("Opacité finale", func():
		(document.working_copy.sequences[0].modules[0] as VFXFlipbookModuleData).opacity = 0.2
	))
	(document.working_copy.sequences[0].modules[0] as VFXFlipbookModuleData).asset = null
	assert_true(document.restore_state(snapshot))
	var restored := document.working_copy.sequences[0].modules[0] as VFXFlipbookModuleData
	assert_not_null(restored.asset)
	assert_eq(restored.asset.asset_id, &"transient_asset")
	assert_ne(restored.asset.display_name, "Mutation après snapshot")
	assert_eq(restored.asset.columns, 1)
	assert_almost_eq(restored.opacity, 0.6, 0.0001)
	assert_true(document.is_dirty())
	assert_true(document.history.can_undo())
	assert_true(document.history.undo())
	assert_almost_eq(
		(document.working_copy.sequences[0].modules[0] as VFXFlipbookModuleData).opacity,
		1.0, 0.0001
	)
	assert_false(document.is_dirty())
	assert_true(document.history.redo())
	assert_almost_eq(
		(document.working_copy.sequences[0].modules[0] as VFXFlipbookModuleData).opacity,
		0.6, 0.0001
	)
	assert_true(document.is_dirty())
	var recovery := VFXDraftService.new().save_recovery(document)
	assert_true(recovery.ok, str(recovery))
	assert_eq(str(recovery.format), "tres")
	var recovered := ResourceLoader.load(
		str(recovery.path), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as VFXProfile
	assert_not_null(recovered)
	assert_not_null(
		(recovered.sequences[0].modules[0] as VFXFlipbookModuleData).asset
	)
	assert_eq(
		(recovered.sequences[0].modules[0] as VFXFlipbookModuleData).asset.columns,
		1
	)
	_remove_owned_file(str(recovery.path))


func test_semantically_invalid_vfx_remains_recoverable_as_local_draft() -> void:
	_remove_owned_file(VFXDraftService.DRAFT_DIRECTORY.path_join(
		"%s.json" % INVALID_DRAFT_ID
	))
	var profile := VFXProfileCopyService.new().duplicate_profile(_profile(SHIELD_PATH))
	profile.profile_id = INVALID_DRAFT_ID
	profile.schema_version = 999
	var document := VFXStudioDocument.new()
	assert_true(document.open_profile(profile))
	var result := VFXDraftService.new().save_draft(document)
	assert_true(result.ok, str(result))
	assert_false(bool(result.get("valid", true)))
	var loaded := VFXDraftService.new().load_draft(INVALID_DRAFT_ID)
	assert_true(loaded.ok, str(loaded))
	assert_false(bool(loaded.get("valid", true)))
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


func test_dirty_profile_change_requires_explicit_context_decision() -> void:
	var context := StudioProjectContext.new()
	var composer := VFXComposer.new()
	composer.setup(context)
	add_child_autofree(composer)
	await get_tree().process_frame
	assert_true(context.transition_handler_contract(&"vfx").valid)
	var opening_source := composer.document.source
	var opening_duration := composer.document.working_copy.sequences[0].modules[0].duration
	assert_true(composer.document.record_edit("Durée sale", func():
		composer.document.working_copy.sequences[0].modules[0].duration = opening_duration + 0.2
	))
	assert_true(context.is_dirty(&"vfx"))
	composer.catalogue.select(1)
	assert_false(composer._on_profile_selected(1))
	assert_same(composer.document.source, opening_source)
	assert_eq(composer._active_profile_index, 0)
	assert_true(context.has_pending_transition())
	assert_true(context.resolve_pending_transition(StudioProjectContext.ACTION_CANCEL).ok)
	assert_same(composer.document.source, opening_source)
	assert_true(composer.document.is_dirty())
	composer.catalogue.select(1)
	assert_false(composer._on_profile_selected(1))
	assert_true(context.resolve_pending_transition(StudioProjectContext.ACTION_DISCARD).ok)
	assert_eq(composer._active_profile_index, 1)
	assert_eq(composer.document.source_path, LIGHTNING_PATH)
	assert_false(composer.document.is_dirty())
	assert_false(context.is_dirty(&"vfx"))


func test_prepare_for_close_saves_dirty_vfx_draft() -> void:
	_remove_owned_file(VFXDraftService.DRAFT_DIRECTORY.path_join("%s.json" % DRAFT_ID))
	var composer := VFXComposer.new()
	add_child_autofree(composer)
	await get_tree().process_frame
	var owned := VFXProfileCopyService.new().duplicate_profile(_profile(SHIELD_PATH))
	owned.profile_id = DRAFT_ID
	assert_true(composer.document.open_profile(owned))
	var before := composer.document.working_copy.sequences[0].modules[0].duration
	assert_true(composer.document.record_edit("Préparer fermeture", func():
		composer.document.working_copy.sequences[0].modules[0].duration = before + 0.1
	))
	var result := composer.prepare_for_close()
	assert_true(result.ok, str(result))
	assert_false(composer.document.is_dirty())
	assert_true(FileAccess.file_exists(
		VFXDraftService.DRAFT_DIRECTORY.path_join("%s.json" % DRAFT_ID)
	))
	_remove_owned_file(VFXDraftService.DRAFT_DIRECTORY.path_join("%s.json" % DRAFT_ID))


func test_discard_after_a_draft_save_restores_the_saved_draft_not_the_source() -> void:
	var document := VFXStudioDocument.new()
	assert_true(document.open_profile(_profile(SHIELD_PATH)))
	var original := document.working_copy.sequences[0].modules[0].duration
	assert_true(document.record_edit("Version brouillon", func():
		document.working_copy.sequences[0].modules[0].duration = original + 0.4
	))
	document.mark_draft_saved("user://test-vfx-draft.json", "test-sha")
	var saved_draft_duration := document.working_copy.sequences[0].modules[0].duration
	assert_true(document.record_edit("Après brouillon", func():
		document.working_copy.sequences[0].modules[0].duration += 0.7
	))
	assert_true(document.discard_changes())
	assert_eq(
		document.working_copy.sequences[0].modules[0].duration,
		saved_draft_duration,
	)
	assert_ne(saved_draft_duration, original)
	assert_false(document.is_dirty())
	assert_true(document.saved_as_draft)


func test_dungeon_draft_studio_registers_vfx_as_fourth_shared_domain() -> void:
	_remove_owned_file(VFXDraftService.DRAFT_DIRECTORY.path_join("%s.json" % DRAFT_ID))
	var context := StudioProjectContext.new()
	var studio := DungeonDraftStudioMain.new()
	studio.setup(null, null, context)
	add_child_autofree(studio)
	studio.set_deferred("size", Vector2(1500, 850))
	await get_tree().process_frame
	assert_eq(studio.tabs.get_tab_count(), 4)
	assert_eq(studio.tabs.get_child(3).name, StringName("VFX"))
	assert_eq(studio.tabs.get_tab_title(3), "LAB VFX")
	assert_eq(studio.domain_buttons[3].text, "LAB VFX")
	assert_not_null(studio.vfx_composer)
	assert_true(context.transition_handler_contract(&"vfx").valid)
	var item_source := studio.item_studio.document.source
	assert_not_null(item_source)
	assert_true(studio.item_studio.document.open_definition(
		item_source, ItemStudioDocument.STATUS_SHARED
	))
	studio.tabs.current_tab = 2
	studio._on_tab_changed(2)
	assert_eq(studio.document_state_label.text, "Production chargée")
	assert_true(studio.item_studio.document.open_definition(
		item_source, ItemStudioDocument.STATUS_DRAFT
	))
	studio._refresh_history_controls()
	assert_eq(studio.document_state_label.text, "Brouillon enregistré")
	studio.tabs.current_tab = 3
	studio._on_tab_changed(3)
	assert_same(studio._active_history_provider(), studio.vfx_composer)
	assert_false(studio.guided_toggle.visible)
	assert_eq(studio.document_state_label.text, "Profil source chargé")
	var owned := VFXProfileCopyService.new().duplicate_profile(_profile(SHIELD_PATH))
	owned.profile_id = DRAFT_ID
	assert_true(studio.vfx_composer.document.open_profile(owned))
	var before := studio.vfx_composer.document.working_copy.sequences[0].modules[0].duration
	assert_true(studio.vfx_composer.document.record_edit("Raccourci sauvegarde", func():
		studio.vfx_composer.document.working_copy.sequences[0].modules[0].duration = before + 0.1
	))
	studio._refresh_history_controls()
	assert_eq(studio.document_state_label.text, "Profil source modifié")
	var save_event := InputEventKey.new()
	save_event.pressed = true
	save_event.ctrl_pressed = true
	save_event.keycode = KEY_S
	studio._unhandled_key_input(save_event)
	assert_false(studio.vfx_composer.document.is_dirty())
	assert_eq(studio.document_state_label.text, "Brouillon enregistré")
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
