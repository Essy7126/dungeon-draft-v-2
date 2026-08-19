extends GutTest

const TEST_ROOT := "user://item_studio_v1"
const DEFINITIONS_ROOT := TEST_ROOT + "/definitions"
const DRAFTS_ROOT := TEST_ROOT + "/drafts"
const CATALOG_PATH := TEST_ROOT + "/catalog.tres"
const CHARACTERIZATION_PATH := "res://artifacts/item_studio/characterization.json"


func before_all() -> void:
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
	assert_false(service.is_path_auto_discovered(
		ItemStudioCatalogService.DRAFT_DIRECTORY.path_join("probe.tres")
	))
	assert_false(bool(_characterization().get("draft_is_auto_discovered", true)))


func test_draft_save_remains_absent_from_fixture_production_catalog() -> void:
	var service := _fixture_catalog()
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_weapon(&"draft_only")))
	var result := ItemDraftService.new().save_draft(document, service)
	assert_true(result.get("ok", false), str(result))
	assert_true(str(result.get("path", "")).begins_with(DRAFTS_ROOT))
	assert_null(service.production_catalog.get_definition(&"draft_only"))
	assert_true(result.get("not_in_production_catalog", false))


func test_publication_writes_once_into_configured_auto_discovery_directory() -> void:
	var service := _fixture_catalog()
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_weapon(&"published_once")))
	var result := ItemPublicationService.new().publish(document, service)
	assert_true(result.get("ok", false), str(result))
	assert_eq(int(result.get("catalog_occurrences", 0)), 1)
	assert_true(str(result.get("path", "")).begins_with(DEFINITIONS_ROOT))
	assert_not_null(service.production_catalog.get_definition(&"published_once"))
	assert_eq(
		ItemFingerprintService.semantic_fingerprint(service.production_catalog.get_definition(&"published_once")),
		str(result.get("fingerprint", "")),
	)


func test_transactional_failure_restores_existing_file() -> void:
	var path := TEST_ROOT + "/rollback.tres"
	var source := _weapon(&"rollback")
	source.display_name = "Avant"
	assert_eq(ResourceSaver.save(source, path), OK)
	var canonical := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	var document := ItemStudioDocument.new()
	assert_true(document.open_definition(canonical))
	document.record_edit("Nom", func(): document.working_copy.display_name = "Après")
	var save := ItemTransactionalSaveService.new()
	save.force_failure_after_write = true
	var result := save.execute(save.build_plan(
		document, path, ItemStudioDocument.STATUS_SHARED, _fixture_catalog()
	), document)
	assert_false(result.get("ok", true))
	var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	assert_not_null(restored)
	assert_eq(restored.display_name, "Avant")


func test_save_plan_blocks_duplicate_item_id_and_path_collision() -> void:
	var service := _fixture_catalog()
	var existing_path := DEFINITIONS_ROOT + "/collision.tres"
	assert_eq(ResourceSaver.save(_weapon(&"collision"), existing_path), OK)
	assert_true(service.rebuild().get("ok", false))
	var document := ItemStudioDocument.new()
	assert_true(document.create_new(_weapon(&"collision")))
	var plan := ItemTransactionalSaveService.new().build_plan(
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
	var publication := ItemPublicationService.new()
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
	var plan := ItemTransactionalSaveService.new().build_plan(
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


func _fixture_catalog() -> ItemStudioCatalogService:
	var service := ItemStudioCatalogService.new()
	service.configure(CATALOG_PATH, DRAFTS_ROOT)
	assert_true(service.rebuild().get("ok", false))
	return service


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
