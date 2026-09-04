extends GutTest

const TEST_ROOT := "user://item_studio_v1"
const DEFINITIONS_ROOT := TEST_ROOT + "/definitions"
const DRAFTS_ROOT := TEST_ROOT + "/drafts"
const TRANSACTIONS_ROOT := TEST_ROOT + "/transactions"
const CATALOG_PATH := TEST_ROOT + "/catalog.tres"
const CHARACTERIZATION_PATH := "res://artifacts/item_studio/characterization.json"


func before_all() -> void:
	_remove_tree(TEST_ROOT)
	assert_eq(DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(DEFINITIONS_ROOT)
	), OK)
	assert_eq(DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(DRAFTS_ROOT)
	), OK)
	var fixture_catalog := ItemCatalog.new()
	fixture_catalog.auto_discovery_directories = PackedStringArray([DEFINITIONS_ROOT])
	assert_eq(ResourceSaver.save(fixture_catalog, CATALOG_PATH), OK)


func after_all() -> void:
	_remove_tree(TEST_ROOT)


func test_production_catalog_matches_characterization_without_hardcoded_count() -> void:
	var service := ItemStudioCatalogService.new()
	var report := _characterization()
	assert_true(service.rebuild().get("ok", false))
	assert_eq(service.production_definitions().size(), int(report.get("definition_count", -1)))
	assert_eq(
		ItemFingerprintService.catalog_fingerprint(service.production_definitions()),
		str(report.get("production_catalog_fingerprint", "")),
	)


func test_catalog_ids_are_unique_and_entries_expose_runtime_status() -> void:
	var service := ItemStudioCatalogService.new()
	assert_true(service.rebuild().get("ok", false))
	var ids := {}
	for entry in service.entries(false):
		var item_id := StringName(entry.get("item_id", &""))
		assert_false(ids.has(item_id), str(item_id))
		ids[item_id] = true
		assert_eq(entry.get("status"), ItemStudioCatalogService.PRODUCTION_STATUS)
		assert_not_null(entry.get("definition"))


func test_effect_registry_covers_all_reachable_production_effects() -> void:
	var service := ItemStudioCatalogService.new()
	assert_true(service.rebuild().get("ok", false))
	var report := ItemEffectRegistry.new().coverage_report(service.production_definitions())
	assert_true(report.get("valid", false), str(report.get("unsupported", [])))
	assert_eq(int(report.get("descriptor_count", 0)), 5)


func test_unknown_spell_effect_is_preserved_and_blocks_validation() -> void:
	var definition := _weapon(&"unknown_effect")
	var unsupported: Array[SpellModifier] = [SpellModifier.new()]
	definition.spell_modifiers = unsupported
	var summary := ItemEffectRegistry.new().summarize(definition.spell_modifiers[0])
	assert_false(summary.get("supported", true))
	assert_true(str(summary.get("player", "")).contains("Effet non pris en charge"))
	var report := ItemStudioValidationService.new().validate(definition, _fixture_catalog())
	assert_false(report.get("valid", true))
	assert_true(_has_message(report, &"EFFECT_UNSUPPORTED"))
	assert_same(definition.spell_modifiers[0], unsupported[0])


func test_deep_copy_duplicates_mutable_effect_resources() -> void:
	var source := _weapon(&"copy_source")
	var spell := ItemSpellModifierData.new()
	spell.damage_percent = 0.25
	var spells: Array[SpellModifier] = [spell]
	source.spell_modifiers = spells
	var copy := ItemDeepCopyService.new().duplicate_definition(source)
	assert_ne(copy, source)
	assert_ne(copy.stat_modifiers[0], source.stat_modifiers[0])
	assert_ne(copy.spell_modifiers[0], source.spell_modifiers[0])
	copy.stat_modifiers[0].value = 99.0
	assert_ne(copy.stat_modifiers[0].value, source.stat_modifiers[0].value)
	assert_true(ItemDeepCopyService.new().mutable_sharing_audit(source, copy).get("valid", false))


func test_deep_copy_shares_immutable_texture_assets() -> void:
	var service := ItemStudioCatalogService.new()
	assert_true(service.rebuild().get("ok", false))
	var source := service.production_definitions().filter(func(value): return value.icon != null)[0] as ItemDefinition
	var copy := ItemDeepCopyService.new().duplicate_definition(source)
	assert_same(copy.icon, source.icon)
	assert_same(copy.inventory_icon, source.inventory_icon)
	assert_same(copy.card_texture, source.card_texture)


func test_reward_card_texture_keeps_studio_fallback_strict() -> void:
	var definition := ItemDefinition.new()
	var inventory_texture := ImageTexture.create_from_image(
		Image.create(1, 1, false, Image.FORMAT_RGBA8)
	)
	var icon_texture := ImageTexture.create_from_image(
		Image.create(2, 2, false, Image.FORMAT_RGBA8)
	)
	var card_texture := ImageTexture.create_from_image(
		Image.create(3, 3, false, Image.FORMAT_RGBA8)
	)
	definition.inventory_icon = inventory_texture
	assert_null(definition.get_reward_card_texture())
	definition.icon = icon_texture
	assert_same(definition.get_reward_card_texture(), icon_texture)
	definition.card_texture = card_texture
	assert_same(definition.get_reward_card_texture(), card_texture)


func test_document_mutation_never_changes_canonical_resource() -> void:
	var source := _weapon(&"canonical")
	var before := ItemFingerprintService.semantic_fingerprint(source)
	var document := ItemStudioDocument.new()
	assert_true(document.open_definition(source))
	document.record_edit("Modifier", func(): document.working_copy.display_name = "Working")
	assert_eq(ItemFingerprintService.semantic_fingerprint(source), before)
	assert_ne(document.working_copy.display_name, source.display_name)


func test_history_undo_redo_and_jump_restore_semantic_snapshots() -> void:
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_weapon(&"history")))
	document.record_edit("Nom A", func(): document.working_copy.display_name = "A")
	document.record_edit("Nom B", func(): document.working_copy.display_name = "B")
	assert_true(document.history.undo())
	assert_eq(document.working_copy.display_name, "A")
	assert_true(document.history.redo())
	assert_eq(document.working_copy.display_name, "B")
	assert_true(document.history.jump_to(0))
	assert_eq(document.working_copy.display_name, "Fixture")


func test_rapid_numeric_edits_merge_into_one_history_action() -> void:
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_weapon(&"merged_numeric_history")))
	for value in [2.0, 3.0, 4.0, 5.0]:
		document.record_edit(
			"Modifier la valeur d’effet",
			func(): document.working_copy.stat_modifiers[0].value = value,
			ItemStudioDocument.CHANGE_VALUE,
			"stat.value",
			"stat_value_0",
		)
	assert_eq(document.history.get_history_entries().size(), 1)
	assert_eq(document.working_copy.stat_modifiers[0].value, 5.0)
	assert_true(document.history.undo())
	assert_eq(document.working_copy.stat_modifiers[0].value, 1.0)
	assert_true(document.history.redo())
	assert_eq(document.working_copy.stat_modifiers[0].value, 5.0)


func test_document_refresh_classifies_value_and_structure_changes() -> void:
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_weapon(&"refresh_kinds")))
	var kinds: Array[StringName] = []
	document.refresh_requested.connect(func(kind: StringName, _path: String): kinds.append(kind))
	document.record_edit("Valeur", func(): document.working_copy.display_name = "Valeur")
	document.record_edit(
		"Structure", func(): document.working_copy.stat_modifiers.append(ItemStatModifierData.new()),
		ItemStudioDocument.CHANGE_STRUCTURE, "stat_modifiers",
	)
	assert_eq(kinds, [ItemStudioDocument.CHANGE_VALUE, ItemStudioDocument.CHANGE_STRUCTURE])


func test_item_effect_add_remove_undo_redo_is_one_logical_history_action() -> void:
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_weapon(&"effect_history")))
	var original_count := document.working_copy.stat_modifiers.size()
	var modifier := ItemStatModifierData.new()
	modifier.stat_id = &"initiative"
	modifier.value = 2.0
	document.record_edit("Ajouter un effet", func(): document.working_copy.stat_modifiers.append(modifier))
	assert_eq(document.working_copy.stat_modifiers.size(), original_count + 1)
	assert_true(document.history.undo())
	assert_eq(document.working_copy.stat_modifiers.size(), original_count)
	assert_true(document.history.redo())
	assert_eq(document.working_copy.stat_modifiers.size(), original_count + 1)


func test_preview_disable_removes_only_the_isolated_effect() -> void:
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_weapon(&"preview_toggle")))
	var canonical_fingerprint := document.current_fingerprint()
	document.set_preview_effect_enabled(&"stat", 0, false)
	var preview := document.preview_copy()
	assert_true(preview.stat_modifiers.is_empty())
	assert_eq(document.working_copy.stat_modifiers.size(), 1)
	assert_eq(document.current_fingerprint(), canonical_fingerprint)


func test_draft_directory_is_outside_production_auto_discovery() -> void:
	var service := ItemStudioCatalogService.new()
	assert_true(service.rebuild().get("ok", false))
	assert_true(ItemStudioCatalogService.DRAFT_DIRECTORY.begins_with("user://"))
	assert_false(ItemStudioCatalogService.DRAFT_DIRECTORY.begins_with("res://"))
	assert_eq(service.draft_directories()[0], ItemStudioCatalogService.DRAFT_DIRECTORY)
	assert_true(service.draft_directories().has(ItemStudioCatalogService.LEGACY_DRAFT_DIRECTORY))
	assert_false(service.is_path_auto_discovered(
		ItemStudioCatalogService.DRAFT_DIRECTORY.path_join("probe.tres")
	))
	assert_false(bool(_characterization().get("draft_is_auto_discovered", true)))


func test_draft_save_remains_absent_from_fixture_production_catalog() -> void:
	var service := _fixture_catalog()
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_weapon(&"draft_only")))
	var result := _draft_save_service().save_draft(document, service)
	assert_true(result.get("ok", false), str(result))
	assert_true(str(result.get("path", "")).begins_with(DRAFTS_ROOT))
	assert_null(service.production_catalog.get_definition(&"draft_only"))
	assert_true(result.get("not_in_production_catalog", false))


func test_new_draft_normalizes_dangerous_item_id_inside_draft_root() -> void:
	var service := _fixture_catalog()
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_weapon(&"../../sortie illisible")))
	var result := _draft_save_service().save_draft(document, service)
	assert_true(result.get("ok", false), str(result))
	var saved_path := str(result.get("path", ""))
	assert_eq(saved_path.get_base_dir(), DRAFTS_ROOT)
	assert_true(saved_path.begins_with(DRAFTS_ROOT.trim_suffix("/") + "/"))
	assert_false(saved_path.get_file().contains(".."))
	assert_true(FileAccess.file_exists(saved_path))


func test_publication_writes_once_into_configured_auto_discovery_directory() -> void:
	var service := _fixture_catalog()
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_weapon(&"published_once")))
	var result := _publication_save_service().publish(document, service)
	assert_true(result.get("ok", false), str(result))
	assert_eq(int(result.get("catalog_occurrences", 0)), 1)
	assert_true(str(result.get("path", "")).begins_with(DEFINITIONS_ROOT))
	assert_not_null(service.production_catalog.get_definition(&"published_once"))
	assert_eq(
		ItemFingerprintService.semantic_fingerprint(service.production_catalog.get_definition(&"published_once")),
		str(result.get("fingerprint", "")),
	)


func test_publication_promotes_draft_back_over_same_canonical_item() -> void:
	var item_id := &"draft_updates_canonical"
	var canonical_path := DEFINITIONS_ROOT + "/%s.tres" % item_id
	var canonical := _weapon(item_id)
	canonical.display_name = "Production précédente"
	assert_eq(ResourceSaver.save(canonical, canonical_path), OK)
	var draft_path := DRAFTS_ROOT + "/%s_recovery_fixture.tres" % item_id
	var draft := _weapon(item_id)
	draft.display_name = "Version récupérée"
	assert_eq(ResourceSaver.save(draft, draft_path), OK)
	var service := _fixture_catalog()
	var document := ItemStudioDocument.new()
	assert_true(document.open_definition(
		ResourceLoader.load(draft_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition,
		ItemStudioDocument.STATUS_DRAFT,
	))
	var result := _publication_save_service().publish(document, service)
	assert_true(result.get("ok", false), str(result))
	assert_eq(result.get("path"), canonical_path)
	assert_eq(int(result.get("catalog_occurrences", 0)), 1)
	assert_true(result.get("draft_removed", false))
	assert_false(FileAccess.file_exists(draft_path))
	var reloaded := ResourceLoader.load(
		canonical_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ItemDefinition
	assert_eq(reloaded.display_name, "Version récupérée")


func test_transactional_failure_restores_existing_file() -> void:
	var path := TEST_ROOT + "/rollback.tres"
	var source := _weapon(&"rollback")
	source.display_name = "Avant"
	assert_eq(ResourceSaver.save(source, path), OK)
	var canonical := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	var document := ItemStudioDocument.new()
	assert_true(document.open_definition(canonical))
	document.record_edit("Nom", func(): document.working_copy.display_name = "Après")
	var save := _transactional_save_service()
	save.force_failure_after_write = true
	var result := save.execute(save.build_plan(
		document, path, ItemStudioDocument.STATUS_SHARED, _fixture_catalog()
	), document)
	assert_false(result.get("ok", true), str(result))
	assert_true((result.get("rollback", {}) as Dictionary).get("ok", false), str(result))
	var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	assert_not_null(restored)
	assert_eq(restored.display_name, "Avant")
	var transaction := result.get("transaction", {}) as Dictionary
	assert_true(transaction.get("cleaned", false), str(transaction))
	assert_true(str(transaction.get("stage_path", "")).begins_with(
		TRANSACTIONS_ROOT + "/"
	))
	assert_true(str(transaction.get("backup_path", "")).begins_with(
		TRANSACTIONS_ROOT + "/"
	))
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(
		str(transaction.get("directory", ""))
	)))


func test_transaction_update_preserves_uid_and_leaves_no_production_auxiliary() -> void:
	var path := DEFINITIONS_ROOT + "/uid_preserved.tres"
	assert_eq(ResourceSaver.save(_weapon(&"uid_preserved"), path), OK)
	var canonical_uid := ResourceUID.create_id()
	assert_true(_write_serialized_resource_uid(path, canonical_uid))
	assert_eq(_serialized_resource_uid(path), canonical_uid)
	var document := ItemStudioDocument.new()
	assert_true(document.open_definition(
		ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	))
	document.record_edit(
		"Nom", func(): document.working_copy.display_name = "UID conservé"
	)
	var save := _transactional_save_service()
	var result := save.execute(save.build_plan(
		document, path, ItemStudioDocument.STATUS_SHARED, _fixture_catalog()
	), document)
	assert_true(result.get("ok", false), str(result))
	assert_eq(_serialized_resource_uid(path), canonical_uid)
	var transaction := result.get("transaction", {}) as Dictionary
	assert_true(transaction.get("cleaned", false), str(transaction))
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(
		str(transaction.get("directory", ""))
	)))
	var production_directory := DirAccess.open(DEFINITIONS_ROOT)
	assert_not_null(production_directory)
	for file_name in production_directory.get_files():
		assert_false(file_name.contains("studio_tmp"), file_name)
		assert_false(file_name.contains("studio_backup"), file_name)
		assert_false(file_name.contains("staged_candidate"), file_name)
		assert_false(file_name.contains("original_before"), file_name)


func test_publication_preserves_draft_changed_during_verified_publish() -> void:
	var item_id := &"concurrent_draft_preserved"
	var draft_path := DRAFTS_ROOT + "/%s.tres" % item_id
	var draft := _weapon(item_id)
	draft.display_name = "Version ouverte"
	assert_eq(ResourceSaver.save(draft, draft_path), OK)
	var document := ItemStudioDocument.new()
	assert_true(document.open_definition(
		ResourceLoader.load(draft_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition,
		ItemStudioDocument.STATUS_DRAFT,
	))
	document.record_edit(
		"Publier", func(): document.working_copy.display_name = "Version publiée"
	)
	var publication := _publication_save_service()
	publication.before_draft_cleanup_hook = func(source_path: String):
		var concurrent := _weapon(item_id)
		concurrent.display_name = "Version concurrente"
		assert_eq(ResourceSaver.save(concurrent, source_path), OK)
	var result := publication.publish(document, _fixture_catalog())
	assert_true(result.get("ok", false), str(result))
	assert_false(result.get("draft_removed", true), str(result))
	assert_true(result.get("draft_preserved_external_change", false), str(result))
	var preserved := ResourceLoader.load(
		draft_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ItemDefinition
	assert_not_null(preserved)
	assert_eq(preserved.display_name, "Version concurrente")


func test_publication_postcondition_failure_rolls_back_new_target() -> void:
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_weapon(&"postcondition_rollback")))
	var catalog := _fixture_catalog()
	var publication := _publication_save_service()
	publication.force_postcondition_failure = true
	var target := publication.target_path(document, catalog)
	assert_false(FileAccess.file_exists(target))
	var result := publication.publish(document, catalog)
	assert_false(result.get("ok", true), str(result))
	assert_true((result.get("rollback", {}) as Dictionary).get("ok", false), str(result))
	assert_false(FileAccess.file_exists(target))
	assert_eq(document.status, ItemStudioDocument.STATUS_NEW)
	assert_true(document.is_dirty())


func test_item_context_rollback_restores_document_history_and_target() -> void:
	var studio := _item_studio()
	studio.catalog.configure(CATALOG_PATH, DRAFTS_ROOT)
	assert_true(studio.catalog.rebuild().get("ok", false))
	assert_true(studio.document.create_new(_weapon(&"context_document_rollback")))
	studio.document.record_edit(
		"Nom A", func(): studio.document.working_copy.display_name = "Travail local"
	)
	var expected_fingerprint := studio.document.current_fingerprint()
	var expected_history_count := studio.document.history.get_history_entries().size()
	var snapshot := studio._context_snapshot()
	var target := studio.draft_service.target_path(studio.document, studio.catalog)
	var committed := studio._transition_draft()
	assert_true(committed.get("ok", false), str(committed))
	assert_true(FileAccess.file_exists(target))
	var committed_transaction := committed.get("transaction", {}) as Dictionary
	assert_eq(committed_transaction.get("last_status"), "COMMITTED")
	assert_true(FileAccess.file_exists(str(
		committed_transaction.get("manifest_path", "")
	)))
	var rollback := studio._context_rollback(
		StudioProjectContext.ACTION_DRAFT, {}, {"committed": committed}
	)
	assert_true(rollback.get("ok", false), str(rollback))
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(
		str(committed_transaction.get("directory", ""))
	)))
	assert_true(studio._context_restore(snapshot).get("ok", false))
	assert_false(FileAccess.file_exists(target))
	assert_eq(studio.document.status, ItemStudioDocument.STATUS_NEW)
	assert_eq(studio.document.current_fingerprint(), expected_fingerprint)
	assert_eq(
		studio.document.history.get_history_entries().size(), expected_history_count
	)
	assert_true(studio.document.is_dirty())
	studio._finalize_context_transaction()
	studio.free()


func test_failed_verification_preserves_third_party_write_and_recovery_backup() -> void:
	var path := TEST_ROOT + "/rollback_external_write.tres"
	var source := _weapon(&"rollback_external_write")
	source.display_name = "Avant"
	assert_eq(ResourceSaver.save(source, path), OK)
	var document := ItemStudioDocument.new()
	assert_true(document.open_definition(
		ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	))
	document.record_edit(
		"Nom Studio", func(): document.working_copy.display_name = "Studio"
	)
	var hook_result := {"error": ERR_UNCONFIGURED}
	var save := _transactional_save_service()
	save.before_verification_hook = func(written_path: String):
		var third_party := _weapon(&"rollback_external_write")
		third_party.display_name = "Écriture tierce"
		hook_result["error"] = ResourceSaver.save(third_party, written_path)
	var result := save.execute(save.build_plan(
		document, path, ItemStudioDocument.STATUS_SHARED, _fixture_catalog()
	), document)
	assert_eq(hook_result.get("error"), OK)
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), &"POST_WRITE_VERIFICATION_FAILED")
	var rollback := result.get("rollback", {}) as Dictionary
	assert_true(rollback.get("skipped_external_change", false), str(result))
	var disk := ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ItemDefinition
	assert_not_null(disk)
	assert_eq(disk.display_name, "Écriture tierce")
	var transaction := result.get("transaction", {}) as Dictionary
	var manifest_path := str(transaction.get("manifest_path", ""))
	var backup_path := str(transaction.get("backup_path", ""))
	assert_true(FileAccess.file_exists(manifest_path))
	assert_true(FileAccess.file_exists(backup_path))
	assert_eq(
		FileAccess.get_sha256(backup_path),
		str(transaction.get("original_sha256", "")),
	)
	var backup := ResourceLoader.load(
		backup_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ItemDefinition
	assert_not_null(backup)
	assert_eq(backup.display_name, "Avant")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	assert_true(manifest is Dictionary)
	assert_eq(str((manifest as Dictionary).get("status", "")), "PREPARED")
	assert_eq(
		str(transaction.get("last_status", "")),
		"ROLLBACK_SKIPPED_EXTERNAL_CHANGE",
	)
	assert_true(_remove_tree(str(transaction.get("directory", ""))))


func test_transaction_blocks_external_modification_before_replacing_target() -> void:
	var path := TEST_ROOT + "/external_modified.tres"
	var source := _weapon(&"external_modified")
	source.display_name = "Ouvert"
	assert_eq(ResourceSaver.save(source, path), OK)
	var document := ItemStudioDocument.new()
	assert_true(document.open_definition(
		ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	))
	document.record_edit("Nom Studio", func(): document.working_copy.display_name = "Studio")
	var save := _transactional_save_service()
	var plan := save.build_plan(
		document, path, ItemStudioDocument.STATUS_SHARED, _fixture_catalog()
	)
	var external := _weapon(&"external_modified")
	external.display_name = "Externe"
	assert_eq(ResourceSaver.save(external, path), OK)
	var result := save.execute(plan, document)
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), &"EXTERNAL_TARGET_MODIFIED")
	var disk := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	assert_eq(disk.display_name, "Externe")


func test_transaction_blocks_external_deletion_before_replacing_target() -> void:
	var path := TEST_ROOT + "/external_deleted.tres"
	assert_eq(ResourceSaver.save(_weapon(&"external_deleted"), path), OK)
	var document := ItemStudioDocument.new()
	assert_true(document.open_definition(
		ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	))
	document.record_edit("Nom Studio", func(): document.working_copy.display_name = "Studio")
	var save := _transactional_save_service()
	var plan := save.build_plan(
		document, path, ItemStudioDocument.STATUS_SHARED, _fixture_catalog()
	)
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK)
	var result := save.execute(plan, document)
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), &"EXTERNAL_TARGET_DELETED")
	assert_false(FileAccess.file_exists(path))


func test_transaction_blocks_target_created_after_plan_review() -> void:
	var path := TEST_ROOT + "/external_created.tres"
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_weapon(&"external_created")))
	var save := _transactional_save_service()
	var plan := save.build_plan(
		document, path, ItemStudioDocument.STATUS_SHARED, _fixture_catalog()
	)
	var external := _weapon(&"external_created")
	external.display_name = "Externe"
	assert_eq(ResourceSaver.save(external, path), OK)
	var result := save.execute(plan, document)
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), &"EXTERNAL_TARGET_CREATED")
	var disk := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	assert_eq(disk.display_name, "Externe")


func test_save_plan_blocks_duplicate_item_id_and_path_collision() -> void:
	var service := _fixture_catalog()
	var existing_path := DEFINITIONS_ROOT + "/collision.tres"
	assert_eq(ResourceSaver.save(_weapon(&"collision"), existing_path), OK)
	assert_true(service.rebuild().get("ok", false))
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_weapon(&"collision")))
	var plan := _transactional_save_service().build_plan(
		document, existing_path, ItemStudioDocument.STATUS_SHARED, service
	)
	assert_false(plan.is_valid())
	assert_true(plan.conflicts.any(func(conflict): return conflict.code in [&"ITEM_ID_DUPLICATE", &"PATH_COLLISION"]))


func test_published_item_id_is_immutable() -> void:
	var document := ItemStudioDocument.new()
	var source := _weapon(&"stable_id")
	assert_true(document.open_definition(source, ItemStudioDocument.STATUS_SHARED))
	document.working_copy.item_id = &"renamed"
	var report := ItemStudioValidationService.new().validate(
		document.working_copy, _fixture_catalog(), "", "", document.original_item_id
	)
	assert_true(_has_message(report, &"PUBLISHED_ID_IMMUTABLE"))


func test_reward_eligibility_is_explicit_and_equipment_only() -> void:
	var publication := _publication_save_service()
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_weapon(&"rewardable")))
	assert_true(publication.set_reward_eligibility(document, true))
	assert_true(document.working_copy.tags.has(FirstRunEquipmentRewardService.POOL_TAG))
	assert_true(publication.set_reward_eligibility(document, false))
	assert_false(document.working_copy.tags.has(FirstRunEquipmentRewardService.POOL_TAG))
	var potion_document := ItemStudioDocument.new()
	assert_true(potion_document.create_new(_consumable(&"not_rewardable")))
	assert_false(publication.set_reward_eligibility(potion_document, true))


func test_equipment_preview_uses_runtime_services_and_restores_state() -> void:
	var catalog := ItemStudioCatalogService.new()
	assert_true(catalog.rebuild().get("ok", false))
	var sword := catalog.production_catalog.get_definition(&"warrior_training_sword")
	var warrior := load("res://data/units/alliés/Guerrier.tres") as UnitData
	var report := ItemRuntimePreviewService.new().preview_equipment(warrior, sword)
	assert_true(report.get("ok", false), str(report))
	assert_true(report.get("restoration_exact", false))
	assert_true(report.get("canonical_unchanged", false))
	assert_eq(report.get("runtime_service"), "EquipmentService + EquipmentStatService")


func test_consumable_preview_uses_item_use_service_without_canonical_mutation() -> void:
	var catalog := ItemStudioCatalogService.new()
	assert_true(catalog.rebuild().get("ok", false))
	var potion := catalog.production_catalog.get_definition(&"minor_healing_potion")
	var elf := load("res://data/units/alliés/elfe.tres") as UnitData
	var report := ItemRuntimePreviewService.new().preview_consumable(elf, potion)
	assert_true(report.get("ok", false), str(report))
	assert_true(report.get("canonical_unchanged", false))
	assert_eq(int(report.get("quantity_before", 0)) - int(report.get("quantity_after", 0)), 1)
	assert_eq(report.get("runtime_service"), "ItemUseService")


func test_balance_breakpoints_flag_action_economy_range_and_global_multiplier() -> void:
	var definition := _weapon(&"breakpoints")
	definition.stat_modifiers[0].stat_id = &"max_ap"
	var spell := ItemSpellModifierData.new()
	spell.range_bonus = 1
	spell.damage_percent = 0.2
	var spells: Array[SpellModifier] = [spell]
	definition.spell_modifiers = spells
	var report := ItemBalanceAnalysisService.new().breakpoints(definition)
	var codes := report.map(func(value): return value.get("code", ""))
	assert_has(codes, "AP_BREAKPOINT")
	assert_has(codes, "RANGE_BREAKPOINT")
	assert_has(codes, "GLOBAL_MULTIPLIER")
	definition.stat_modifiers[0].stat_id = &"max_mp"
	var mp_codes := ItemBalanceAnalysisService.new().breakpoints(definition).map(func(value): return value.get("code", ""))
	assert_has(mp_codes, "MP_BREAKPOINT")


func test_spell_analysis_uses_real_hero_loadout_and_target_profile() -> void:
	var catalog := ItemStudioCatalogService.new()
	assert_true(catalog.rebuild().get("ok", false))
	var definition := catalog.production_catalog.get_definition(&"hache_executeur")
	assert_not_null(definition)
	var service := ItemBalanceAnalysisService.new()
	var choices := service.spell_choices(definition)
	assert_eq(choices.size(), 1)
	assert_eq((choices[0] as Dictionary).get("character_id"), &"warrior")
	var selected_projection := {}
	var critical_projection := {}
	for spell_value in (choices[0] as Dictionary).get("spells", []) as Array:
		var spell := spell_value as Dictionary
		var projection := service.project_selected_spell(
			definition, str((choices[0] as Dictionary).get("path", "")),
			int(spell.get("index", -1)), 1.0,
		)
		if projection.get("damage_type_label") == "Physique" \
				and int(projection.get("damage_before", 0)) > 0:
			selected_projection = projection
			critical_projection = service.project_selected_spell(
				definition, str((choices[0] as Dictionary).get("path", "")),
				int(spell.get("index", -1)), 0.35,
			)
			break
	assert_false(selected_projection.is_empty())
	assert_true(selected_projection.get("ok", false))
	assert_eq(selected_projection.get("runtime_service"), "ItemRuntimePreviewService.project_spell")
	assert_gt(
		int(selected_projection.get("damage_after", 0)),
		int(selected_projection.get("damage_before", 0)),
	)
	assert_gt(
		int(critical_projection.get("damage_after", 0)),
		int(selected_projection.get("damage_after", 0)),
	)


func test_hero_catalog_discovers_achilles_and_validation_accepts_it() -> void:
	var hero_catalog := ItemHeroCatalogService.new()
	var rebuilt := hero_catalog.rebuild()
	assert_true(rebuilt.get("ok", false), str(rebuilt))
	assert_has(hero_catalog.known_ids(), &"achilles")
	var achilles_entry := hero_catalog.entry_for_id(&"achilles")
	assert_eq(achilles_entry.get("display_name"), "Achille")
	assert_eq(achilles_entry.get("path"), "res://data/units/allies/achilles.tres")
	var definition := _weapon(&"achilles_item")
	definition.compatible_character_ids = [&"achilles"]
	var validation := ItemStudioValidationService.new()
	validation.hero_catalog = hero_catalog
	var validation_report := validation.validate_interactive(definition, _fixture_catalog())
	assert_true(validation_report.get("valid", false), str(validation_report))
	assert_false(_has_message(validation_report, &"CHARACTER_UNKNOWN"))
	var balance := ItemBalanceAnalysisService.new()
	balance.hero_catalog = hero_catalog
	var spell_choices := balance.spell_choices(definition)
	assert_eq(spell_choices.size(), 1)
	assert_eq((spell_choices[0] as Dictionary).get("character_id"), &"achilles")
	assert_false(((spell_choices[0] as Dictionary).get("spells", []) as Array).is_empty())
	var analysis := balance.analyze(definition)
	assert_true(analysis.get("ok", false), str(analysis))
	assert_true((analysis.get("heroes", []) as Array).any(func(hero):
		return StringName((hero as Dictionary).get("character_id", &"")) == &"achilles"
	))


func test_drawback_noop_is_reported_for_compatible_heroes() -> void:
	var definition := _weapon(&"noop_drawback")
	definition.stat_modifiers[0].stat_id = &"armure"
	definition.stat_modifiers[0].value = -20.0
	var report := ItemBalanceAnalysisService.new().analyze(definition)
	var codes := (report.get("breakpoints", []) as Array).map(func(value): return value.get("code", ""))
	assert_has(codes, "NOOP_EFFECT")


func test_ehp_projection_uses_damage_resolver_law() -> void:
	var definition := _weapon(&"ehp")
	definition.stat_modifiers[0].stat_id = &"armure"
	definition.stat_modifiers[0].value = 20.0
	var report := ItemBalanceAnalysisService.new().analyze(definition)
	assert_true(report.get("ok", false), str(report))
	var hero := (report.get("heroes", []) as Array)[0] as Dictionary
	var physical := ((hero.get("ehp", {}) as Dictionary).get("physical", {}) as Dictionary)
	assert_gt(float(physical.get("after", 0.0)), float(physical.get("base", 0.0)))


func test_comparison_requires_same_slot_category_and_audience() -> void:
	var first := _weapon(&"first")
	var second := _weapon(&"second")
	first.stat_modifiers[0].value = 5.0
	second.stat_modifiers[0].value = 2.0
	var comparable := ItemComparisonService.new().compare(first, second)
	assert_eq(comparable.get("status"), &"STRICT_DOMINANCE")
	second.compatible_character_ids = [&"mage"]
	var rejected := ItemComparisonService.new().compare(first, second)
	assert_eq(rejected.get("status"), &"INCOMPARABLE")


func test_comparison_stays_conservative_for_conditional_effects() -> void:
	var first := _weapon(&"conditional")
	var second := _weapon(&"plain")
	var spell := ItemSpellModifierData.new()
	spell.damage_percent = 1.0
	spell.target_spell_id = &"one_spell"
	var spells: Array[SpellModifier] = [spell]
	first.spell_modifiers = spells
	var report := ItemComparisonService.new().compare(first, second)
	assert_eq(report.get("status"), &"PARTIAL")
	assert_true(report.get("conditional", false))


func test_ui_state_round_trip_preserves_filters_selection_and_scope() -> void:
	var state := ItemStudioUiStateService.new()
	state.set_value("selected_path", "res://fixture.tres")
	state.set_value("scope", "DRAFT")
	state.set_value("comparison_hero", "warrior")
	state.set_value("comparison_spell", "warrior_heavy_strike")
	state.set_value("comparison_target_hp", 0.35)
	state.state["filters"] = {"search": "lame", "category": 1}
	var restored := ItemStudioUiStateService.new()
	restored.restore(state.snapshot())
	assert_eq(restored.get_value("selected_path"), "res://fixture.tres")
	assert_eq(restored.get_value("scope"), "DRAFT")
	assert_eq(restored.get_value("comparison_hero"), "warrior")
	assert_eq(restored.get_value("comparison_spell"), "warrior_heavy_strike")
	assert_eq(restored.get_value("comparison_target_hp"), 0.35)
	assert_eq((restored.get_value("filters") as Dictionary).get("search"), "lame")


func test_run_specific_scope_is_explicitly_blocked_by_save_plan() -> void:
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_weapon(&"run_specific")))
	var plan := _transactional_save_service().build_plan(
		document, DEFINITIONS_ROOT + "/run_specific.tres",
		StudioProjectContext.SCOPE_RUN_SPECIFIC, _fixture_catalog()
	)
	assert_false(plan.is_valid())
	assert_true(plan.conflicts.any(func(conflict): return conflict.code == &"RUN_SPECIFIC_UNSUPPORTED"))


func test_dirty_item_domain_blocks_context_change_until_explicit_decision() -> void:
	var context := StudioProjectContext.new()
	assert_true(context.initialize("res://data/runs/first_run.tres", &"elf").get("ok", false))
	context.register_transition_handler(
		&"items", func(): return {"ok": true},
		func(): return {"ok": true, "path": "user://item_draft.tres"},
		func(): return {"ok": true}
	)
	context.set_dirty(&"items", true, {"item_id": "fixture"})
	var blocked := context.request_scope(StudioProjectContext.SCOPE_SHARED, &"items")
	assert_false(blocked.get("ok", true))
	assert_eq(blocked.get("status"), &"REQUIRES_DECISION")
	assert_true(context.resolve_pending_transition(StudioProjectContext.ACTION_CANCEL).get("ok", false))
	assert_true(context.is_dirty(&"items"))


func test_prepare_for_close_writes_dirty_document_to_configured_draft_directory() -> void:
	var studio := _item_studio()
	studio.catalog.configure(CATALOG_PATH, DRAFTS_ROOT)
	assert_true(studio.catalog.rebuild().get("ok", false))
	assert_true(studio.document.create_new(_weapon(&"close_recovery")))
	assert_true(studio.document.is_dirty())
	var result := studio.prepare_for_close()
	assert_true(result.get("ok", false), str(result))
	assert_true(str(result.get("path", "")).begins_with(DRAFTS_ROOT))
	assert_true(FileAccess.file_exists(str(result.get("path", ""))))
	assert_false(studio.document.is_dirty())
	assert_eq(studio.document.status, ItemStudioDocument.STATUS_DRAFT)
	studio.free()


func test_prepare_for_close_preserves_existing_same_id_draft_and_writes_recovery() -> void:
	var item_id := &"close_existing_draft"
	var draft_path := DRAFTS_ROOT + "/%s.tres" % item_id
	var previous_draft := _weapon(item_id)
	previous_draft.display_name = "Ancien brouillon"
	assert_eq(ResourceSaver.save(previous_draft, draft_path), OK)
	var source_path := TEST_ROOT + "/close_existing_source.tres"
	var source := _weapon(item_id)
	source.display_name = "Production"
	assert_eq(ResourceSaver.save(source, source_path), OK)
	var studio := _item_studio()
	studio.catalog.configure(CATALOG_PATH, DRAFTS_ROOT)
	assert_true(studio.catalog.rebuild().get("ok", false))
	assert_true(studio.document.open_definition(
		ResourceLoader.load(source_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	))
	studio.document.record_edit(
		"Nom récupéré", func(): studio.document.working_copy.display_name = "Récupéré"
	)
	var result := studio.prepare_for_close()
	assert_true(result.get("ok", false), str(result))
	assert_true(result.get("recovery", false))
	assert_ne(result.get("path"), draft_path)
	assert_true(FileAccess.file_exists(str(result.get("path", ""))))
	var preserved := ResourceLoader.load(
		draft_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ItemDefinition
	assert_eq(preserved.display_name, "Ancien brouillon")
	var recovered := ResourceLoader.load(
		str(result.get("path", "")), "", ResourceLoader.CACHE_MODE_IGNORE
	) as ItemDefinition
	assert_eq(recovered.item_id, item_id)
	assert_eq(recovered.display_name, "Récupéré")
	studio.free()


func test_explicit_draft_save_updates_existing_same_id_target_with_fingerprint() -> void:
	var item_id := &"explicit_existing_draft"
	var draft_path := DRAFTS_ROOT + "/%s.tres" % item_id
	var previous_draft := _weapon(item_id)
	previous_draft.display_name = "Ancien brouillon"
	assert_eq(ResourceSaver.save(previous_draft, draft_path), OK)
	var source_path := TEST_ROOT + "/explicit_existing_source.tres"
	var source := _weapon(item_id)
	source.display_name = "Production"
	assert_eq(ResourceSaver.save(source, source_path), OK)
	var studio := _item_studio()
	studio.catalog.configure(CATALOG_PATH, DRAFTS_ROOT)
	assert_true(studio.catalog.rebuild().get("ok", false))
	assert_true(studio.document.open_definition(
		ResourceLoader.load(source_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	))
	studio.document.record_edit(
		"Nom récupéré", func(): studio.document.working_copy.display_name = "Récupéré"
	)
	var plan := studio.draft_service.plan(studio.document, studio.catalog)
	assert_true(plan.is_valid(), str(plan.conflicts))
	assert_eq(plan.entries.size(), 1)
	var plan_entry := plan.entries[0] as ItemSavePlanEntry
	assert_eq(plan_entry.operation, &"UPDATE")
	assert_false(plan_entry.old_fingerprint.is_empty())
	var result := studio.draft_service.save_draft(
		studio.document, studio.catalog, plan
	)
	assert_true(result.get("ok", false), str(result))
	assert_eq(result.get("path"), draft_path)
	var reloaded := ResourceLoader.load(
		draft_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ItemDefinition
	assert_eq(reloaded.display_name, "Récupéré")
	studio.free()


func test_draft_save_preserves_semantically_invalid_work_in_progress() -> void:
	var studio := _item_studio()
	studio.catalog.configure(CATALOG_PATH, DRAFTS_ROOT)
	assert_true(studio.catalog.rebuild().get("ok", false))
	var invalid := _weapon(&"invalid_work_in_progress")
	invalid.display_name = ""
	assert_true(studio.document.create_new(invalid))
	var result := studio.draft_service.save_draft(studio.document, studio.catalog)
	assert_true(result.get("ok", false), str(result))
	var reloaded := ResourceLoader.load(
		str(result.get("path", "")), "", ResourceLoader.CACHE_MODE_IGNORE
	) as ItemDefinition
	assert_not_null(reloaded)
	assert_false(reloaded.is_valid())
	studio.free()


func test_prepare_for_close_falls_back_to_unique_recovery_on_foreign_collision() -> void:
	var expected_path := DRAFTS_ROOT + "/close_foreign_collision.tres"
	var foreign := _weapon(&"another_item")
	foreign.display_name = "À préserver"
	assert_eq(ResourceSaver.save(foreign, expected_path), OK)
	var studio := _item_studio()
	studio.catalog.configure(CATALOG_PATH, DRAFTS_ROOT)
	assert_true(studio.catalog.rebuild().get("ok", false))
	assert_true(studio.document.create_new(_weapon(&"close_foreign_collision")))
	var result := studio.prepare_for_close()
	assert_true(result.get("ok", false), str(result))
	assert_true(result.get("recovery", false))
	assert_ne(result.get("path"), expected_path)
	assert_true(FileAccess.file_exists(str(result.get("path", ""))))
	var preserved := ResourceLoader.load(
		expected_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ItemDefinition
	assert_eq(preserved.item_id, &"another_item")
	assert_eq(preserved.display_name, "À préserver")
	studio.free()


func test_test_document_caches_and_summarizes_observable_result() -> void:
	var studio := _item_studio()
	assert_true(studio.document.create_new(_weapon(&"observable_test")))
	var report := studio.test_document()
	assert_true(report.get("ok", false), str(report))
	assert_eq(studio.last_test_report(), report)
	assert_eq(studio._cached_fingerprint, studio.document.current_fingerprint())
	assert_true(studio._status_message.begins_with("Test réussi"))
	studio.free()


func test_mutable_sharing_audit_passes_on_production_catalog() -> void:
	var catalog := ItemStudioCatalogService.new()
	assert_true(catalog.rebuild().get("ok", false))
	var report := ItemDeepCopyService.new().audit_catalog(catalog.production_definitions())
	assert_true(report.get("valid", false), str(report.get("shared_mutable", [])))


func test_item_id_normalization_and_collision_suffix_are_deterministic() -> void:
	var service := _fixture_catalog()
	var path_service := ItemIdPathService.new()
	assert_eq(path_service.normalize_item_id(" Épée — Test "), "epee_test")
	assert_eq(path_service.suggest_item_id("Collision", service), &"collision_2")


# Le choix « tout seul » / « le joueur » de l'éditeur d'effets se résume à une
# écriture de trigger_id. On couvre ici ce que ce bouton produit réellement :
# aller-retour dans le document avec historique, puis acceptation par la
# validation du Studio et par l'aperçu runtime.
func test_manual_activation_choice_round_trips_through_the_document() -> void:
	var relic := _manual_relic(&"studio_manual_choice")
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(relic))
	assert_true(document.working_copy.reactive_effects[0].is_manual_trigger())
	assert_true(document.record_edit("Modifier qui déclenche l’effet", func():
		document.working_copy.reactive_effects[0].trigger_id = \
			ItemReactiveEffectData.TRIGGER_TURN_START
	, ItemStudioDocument.CHANGE_STRUCTURE, "reactive.descriptor"))
	assert_false(document.working_copy.reactive_effects[0].is_manual_trigger())
	assert_false(document.working_copy.has_manual_activation())
	assert_true(document.history.undo())
	assert_true(
		document.working_copy.reactive_effects[0].is_manual_trigger(),
		"Annuler doit ramener le déclenchement au clic du joueur",
	)
	assert_true(document.working_copy.has_manual_activation())


func test_manual_relic_passes_studio_validation_and_runtime_preview() -> void:
	var relic := _manual_relic(&"studio_manual_valid")
	var report := ItemStudioValidationService.new().validate_interactive(
		relic, _fixture_catalog()
	)
	assert_true(report.get("valid", false), str(report))
	assert_false(_has_message(report, &"REACTIVE_DESCRIPTOR_UNKNOWN"))
	var preview := ItemRuntimePreviewService.new().preview_relic(relic)
	assert_true(preview.get("ok", false), str(preview))
	# Sans scénario dédié, un objet manuel s'afficherait « rien ne se passe » :
	# l'aperçu doit l'exercer par son vrai chemin d'activation.
	var manual_scenarios := (preview.get("scenarios", []) as Array).filter(func(value):
		return (value as Dictionary).get("trigger_id") == ItemReactiveEffectData.TRIGGER_MANUAL_ACTIVATION
	)
	assert_false(
		manual_scenarios.is_empty(),
		"L’aperçu doit montrer ce que produit le clic du joueur",
	)
	assert_true(manual_scenarios.any(func(value):
		return (value as Dictionary).get("triggered", false)
	))


func _manual_relic(item_id: StringName) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.item_id = item_id
	definition.display_name = "Relique manuelle fixture"
	definition.description = "Fixture de test"
	definition.category = ItemDefinition.Category.RELIC
	definition.equipment_slot = ItemDefinition.EquipmentSlot.NONE
	definition.stack_limit = 1
	var effect := ItemReactiveEffectData.new()
	effect.trigger_id = ItemReactiveEffectData.TRIGGER_MANUAL_ACTIVATION
	effect.target_id = ItemReactiveEffectData.TARGET_TRIGGER_HERO
	effect.result_id = ItemReactiveEffectData.RESULT_CURRENT_AP
	effect.value = 1.0
	effect.frequency_id = ItemReactiveEffectData.FREQUENCY_TURN
	var effects: Array[ItemReactiveEffectData] = [effect]
	definition.reactive_effects = effects
	return definition


func _fixture_catalog() -> ItemStudioCatalogService:
	var service := ItemStudioCatalogService.new()
	service.configure(CATALOG_PATH, DRAFTS_ROOT)
	assert_true(service.rebuild().get("ok", false))
	return service


func _transactional_save_service() -> ItemTransactionalSaveService:
	var service := ItemTransactionalSaveService.new()
	service.transaction_root = TRANSACTIONS_ROOT
	return service


func _draft_save_service() -> ItemDraftService:
	var service := ItemDraftService.new()
	service.save_service.transaction_root = TRANSACTIONS_ROOT
	return service


func _publication_save_service() -> ItemPublicationService:
	var service := ItemPublicationService.new()
	service.save_service.transaction_root = TRANSACTIONS_ROOT
	return service


func _item_studio() -> ItemStudioMain:
	var studio := ItemStudioMain.new()
	studio.draft_service.save_service.transaction_root = TRANSACTIONS_ROOT
	studio.publication_service.save_service.transaction_root = TRANSACTIONS_ROOT
	return studio


func _weapon(item_id: StringName) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.item_id = item_id
	definition.display_name = "Fixture"
	definition.description = "Fixture de test"
	definition.category = ItemDefinition.Category.WEAPON
	definition.equipment_slot = ItemDefinition.EquipmentSlot.WEAPON
	definition.stack_limit = 1
	var modifier := ItemStatModifierData.new()
	modifier.stat_id = &"attack_power"
	modifier.value = 1.0
	var modifiers: Array[ItemStatModifierData] = [modifier]
	definition.stat_modifiers = modifiers
	return definition


func _consumable(item_id: StringName) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.item_id = item_id
	definition.display_name = "Potion fixture"
	definition.description = "Fixture de test"
	definition.category = ItemDefinition.Category.CONSUMABLE
	definition.equipment_slot = ItemDefinition.EquipmentSlot.NONE
	definition.stack_limit = 5
	definition.use_effect = ItemDefinition.UseEffect.HEAL_FLAT
	definition.use_value = 10.0
	return definition


func _characterization() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CHARACTERIZATION_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}


func _serialized_resource_uid(path: String) -> int:
	if not FileAccess.file_exists(path):
		return ResourceUID.INVALID_ID
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ResourceUID.INVALID_ID
	var header := file.get_line()
	file.close()
	var marker := "uid=\""
	var marker_index := header.find(marker)
	if marker_index < 0:
		return ResourceUID.INVALID_ID
	var value_start := marker_index + marker.length()
	var value_end := header.find("\"", value_start)
	if value_end < 0:
		return ResourceUID.INVALID_ID
	return ResourceUID.text_to_id(header.substr(
		value_start, value_end - value_start
	))


func _write_serialized_resource_uid(path: String, uid: int) -> bool:
	if uid == ResourceUID.INVALID_ID or not FileAccess.file_exists(path):
		return false
	var content := FileAccess.get_file_as_string(path)
	var line_end := content.find("\n")
	var header := content.substr(0, line_end) if line_end >= 0 else content
	if not header.begins_with("[gd_resource"):
		return false
	var uid_text := ResourceUID.id_to_text(uid)
	var marker := "uid=\""
	var marker_index := header.find(marker)
	if marker_index >= 0:
		var value_start := marker_index + marker.length()
		var value_end := header.find("\"", value_start)
		if value_end < 0:
			return false
		header = header.substr(0, value_start) + uid_text + header.substr(value_end)
	else:
		var closing_bracket := header.rfind("]")
		if closing_bracket < 0:
			return false
		header = header.substr(0, closing_bracket) \
			+ " uid=\"%s\"" % uid_text \
			+ header.substr(closing_bracket)
	var rewritten := header + content.substr(line_end) \
		if line_end >= 0 else header
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(rewritten)
	file.flush()
	file.close()
	return _serialized_resource_uid(path) == uid


func _has_message(report: Dictionary, code: StringName) -> bool:
	return (report.get("messages", []) as Array).any(func(message):
		return StringName((message as Dictionary).get("code", &"")) == code
	)


func _remove_tree(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(absolute)
	if directory == null:
		return true
	for file_name in directory.get_files():
		DirAccess.remove_absolute(absolute.path_join(file_name))
	for child in directory.get_directories():
		_remove_tree(path.path_join(child))
	return DirAccess.remove_absolute(absolute) == OK
