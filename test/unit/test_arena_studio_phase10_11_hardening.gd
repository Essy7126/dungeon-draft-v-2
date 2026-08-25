extends GutTest

class DictionaryResource:
	extends Resource
	@export var refs := {}

var _tx_events := PackedStringArray()


func before_each() -> void:
	_tx_events.clear()
	ArenaTerrainRenderPlanService.clear_cache()
	ArenaTacticalMetricsService.clear_cache()
	ArenaValidator.clear_cache()
	ArenaVisualAssembler.clear_inspection_cache()
	ArenaArtProjectionRenderer.clear_geometry_cache()


func after_all() -> void:
	ArenaProductionTransactionService._remove_tree(ArenaGuidedSandboxService.ROOT)


func test_tools_use_full_french_names_and_permanent_contract() -> void:
	assert_eq(StudioVersion.PRODUCT_VERSION, "2.0.0")
	assert_eq(StudioVersion.GENERATED_BY, "dungeon_draft_studio_2_0_0")
	assert_true('version="2.0.0"' in FileAccess.get_file_as_string(
		"res://addons/dungeon_draft_arena_studio/plugin.cfg"
	))
	# Vocabulaire de la refonte Terrain : « Sols » et « Points de départ »
	# remplacent « Terrains » et « Spawns » dans le parcours nominal.
	assert_eq(ArenaStudioMain.TOOL_LABELS, [
		"Sélection", "Déplacer la vue", "Ajouter des cases", "Retirer des cases",
		"Bordure", "Murs et obstacles", "Sols", "Points de départ", "Vérification",
		"Transformer la grille", "Ancres",
	])
	assert_eq(ArenaStudioMain.TOOL_HELP.size(), ArenaStudioMain.TOOL_LABELS.size())
	assert_eq(ArenaStudioMain.TOOL_SHORTCUT_KEYS.size(), ArenaStudioMain.TOOL_LABELS.size())
	for help in ArenaStudioMain.TOOL_HELP:
		assert_eq((help as Array).size(), 3)
	var source := FileAccess.get_file_as_string(
		"res://addons/dungeon_draft_arena_studio/ui/arena_studio_main.gd"
	)
	assert_true("OUTIL ACTIF" in source)
	assert_true("Clic gauche" in source)
	assert_true("Clic droit" in source)


func test_context_bar_is_human_first_and_technical_details_are_collapsed() -> void:
	var bar := StudioContextBar.new()
	add_child_autofree(bar)
	await get_tree().process_frame
	assert_eq(bar._scope_label(StudioProjectContext.SCOPE_RUN_SPECIFIC), "Spécifique à la partie")
	assert_not_null(bar.human_summary_label)
	assert_not_null(bar.details_button)
	assert_false(bar.details_button.visible)
	assert_false(bar.details_label.visible)
	assert_eq(bar.custom_minimum_size.y, 56.0)
	assert_string_contains(bar.human_summary_label.tooltip_text, "Contexte actif")


func test_production_summary_dashboard_and_guided_tour_cover_beginner_contract() -> void:
	var targets := PackedStringArray()
	for page in ArenaStudioGuidedTour.PAGES:
		targets.append(str((page as Dictionary).get("target", &"")))
	for required in [
		"working_copy", "visual_modes", "quick_exact", "bundle_conflict",
		"update_replace", "rollback", "reintegrate", "sandbox",
	]:
		assert_has(targets, required)
	var source := FileAccess.get_file_as_string(
		"res://addons/dungeon_draft_arena_studio/ui/arena_studio_main.gd"
	)
	assert_true("Vous allez" in source)
	assert_true("la rencontre, les vagues et les récompenses" in source)
	assert_true("Vérifier et intégrer dans %s — %s salle %d" in source)
	assert_true("Pourquoi l'intégration est-elle indisponible ?" in source)
	assert_true("PRODUCTIONS ET RÉCUPÉRATIONS" in source)


func test_production_dialog_keeps_actions_visible_at_1200_by_896() -> void:
	var previous_size := get_window().size
	get_window().size = Vector2i(1200, 896)
	var studio := ArenaStudioMain.new()
	add_child_autofree(studio)
	await get_tree().process_frame
	studio._set_arena(_arena_fixture(Vector2i(10, 8)), false, "responsive_contract")
	await get_tree().process_frame
	studio.show_production_wizard()
	await get_tree().process_frame
	await get_tree().process_frame
	var dialog := studio.production_dialog
	var primary := dialog.get_ok_button()
	var cancel := dialog.get_cancel_button()
	assert_true(dialog.visible)
	assert_lte(dialog.size.y, 896)
	assert_true(primary.visible)
	assert_true(cancel.visible)
	# Le validateur continu peut légitimement bloquer l'intégration de cette
	# fixture ; le contrat responsive porte sur l'accès visible aux actions.
	assert_ne(primary.focus_mode, Control.FOCUS_NONE)
	assert_lte(primary.get_global_rect().end.y, float(dialog.size.y))
	assert_lte(cancel.get_global_rect().end.y, float(dialog.size.y))
	dialog.hide()
	get_window().size = previous_size


func test_frozen_produced_bundle_is_read_only_referenced_and_conflictual_in_dashboard() -> void:
	var report := ArenaProductionDashboardService.scan()
	assert_true(report.ok)
	assert_true(report.read_only)
	assert_false(report.automatic_deletion)
	var expected := ArenaProductionService.DEFAULT_ROOT.path_join("room_01_forest")
	var record := {}
	for value in report.records:
		if str((value as Dictionary).get("path", "")) == expected:
			record = value
			break
	assert_false(record.is_empty())
	assert_eq(
		record.get("category", &""),
		ArenaBundleInspectionService.OWNED_DIRTY
	)
	assert_true(record.get("referenced", false))
	assert_false((record.get("actions", PackedStringArray()) as PackedStringArray).has("Archiver"))


func test_guided_sandbox_creates_only_user_fixture_and_incomplete_bundle() -> void:
	var created := ArenaGuidedSandboxService.create_fixture()
	assert_true(created.ok, str(created))
	assert_true(str(created.root).begins_with(ArenaGuidedSandboxService.ROOT + "/"))
	assert_true(str(created.working_arena_path).begins_with("user://"))
	assert_true(str(created.run_path).begins_with("user://"))
	assert_eq((created.recipe as Array).size(), 10)
	var incomplete := ArenaGuidedSandboxService.simulate_incomplete_bundle(created)
	assert_true(incomplete.ok, str(incomplete))
	assert_eq(
		incomplete.inspection.state,
		ArenaBundleInspectionService.OWNED_INCOMPLETE
	)


func test_context_transaction_prepares_stages_commits_in_sorted_order_and_rolls_back() -> void:
	var context := StudioProjectContext.new()
	assert_true(context.initialize().ok)
	context.register_transition_handler(
		&"zeta", _tx_commit.bind("zeta", true),
		_tx_commit.bind("zeta", false), _tx_commit.bind("zeta", false),
		_tx_prepare.bind("zeta"), _tx_stage.bind("zeta"), _tx_rollback.bind("zeta")
	)
	context.register_transition_handler(
		&"alpha", _tx_commit.bind("alpha", false),
		_tx_commit.bind("alpha", false), _tx_commit.bind("alpha", false),
		_tx_prepare.bind("alpha"), _tx_stage.bind("alpha"), _tx_rollback.bind("alpha")
	)
	context.set_dirty(&"zeta", true)
	context.set_dirty(&"alpha", true)
	var requested := context.request_scope(StudioProjectContext.SCOPE_DRAFT)
	assert_eq(requested.status, &"REQUIRES_DECISION")
	var resolved := context.resolve_pending_transition(StudioProjectContext.ACTION_SAVE)
	assert_false(resolved.ok)
	assert_eq(resolved.phase, &"COMMIT")
	assert_eq(resolved.domain, &"zeta")
	assert_true(resolved.rolled_back)
	assert_true(context.is_dirty(&"alpha"))
	assert_true(context.is_dirty(&"zeta"))
	assert_true(context.has_pending_transition())
	assert_eq(_tx_events, PackedStringArray([
		"prepare:alpha", "prepare:zeta", "stage:alpha", "stage:zeta",
		"commit:alpha", "commit:zeta", "rollback:zeta", "rollback:alpha",
	]))


func test_reference_graph_uses_weak_refs_walks_dictionaries_and_reports_measurements() -> void:
	var graph := StudioReferenceGraphService.new()
	var parent := DictionaryResource.new()
	var child := Resource.new()
	parent.refs = {"nested": {"child": child}}
	var nodes := {}
	var outgoing := {}
	var incoming := {}
	graph._walk_resource(parent, &"ROOT", nodes, outgoing, incoming, {})
	var parent_key := graph.resource_key(parent)
	var child_key := graph.resource_key(child)
	assert_true(nodes.has(child_key))
	assert_true((nodes[child_key] as Dictionary).resource is WeakRef)
	assert_eq((outgoing[parent_key] as Array).size(), 1)
	assert_eq((outgoing[parent_key] as Array)[0].metadata.dictionary_key, "child")
	var report := graph.report()
	assert_has(report, "duration_ms")
	assert_has(report, "memory_delta_bytes")
	assert_has(report, "object_delta")
	for key in report.stable_path_nodes:
		assert_false(str(key).begins_with("memory://"))


func test_fingerprint_caches_hit_and_invalidate_after_semantic_change() -> void:
	var arena := _arena_fixture(Vector2i(5, 4))
	var first_plan := ArenaTerrainRenderPlanService.build(arena)
	var second_plan := ArenaTerrainRenderPlanService.build(arena)
	assert_false(first_plan.cache_hit)
	assert_true(second_plan.cache_hit)
	var first_metrics := ArenaTacticalMetricsService.analyze(arena)
	var second_metrics := ArenaTacticalMetricsService.analyze(arena)
	assert_false(first_metrics.cache_hit)
	assert_true(second_metrics.cache_hit)
	var first_validation := ArenaValidator.validate(arena, false)
	var second_validation := ArenaValidator.validate(arena, false)
	assert_false(first_validation.get_meta("cache_hit"))
	assert_true(second_validation.get_meta("cache_hit"))
	ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(2, 2)), &"water")
	var changed_plan := ArenaTerrainRenderPlanService.build(arena)
	var changed_metrics := ArenaTacticalMetricsService.analyze(arena)
	var changed_validation := ArenaValidator.validate(arena, false)
	assert_false(changed_plan.cache_hit)
	assert_false(changed_metrics.cache_hit)
	assert_false(changed_validation.get_meta("cache_hit"))
	assert_true(changed_validation.metrics.terrains.has("water"))


func test_performance_service_emits_threshold_and_cycle_report() -> void:
	var report := ArenaStudioPerformanceService.benchmark_fixture(Vector2i(4, 4), 2)
	assert_true(report.ok, str(report))
	assert_true(report.measurement_valid, str(report))
	assert_true(report.measurement_only)
	assert_null(report.slo_pass)
	assert_eq(report.verdict, "MEASUREMENT_ONLY")
	assert_eq(report.cycle_count, 2)
	assert_has(report, "memory_delta_bytes")
	assert_has(report, "object_delta")
	assert_has(report, "thresholds_pass")
	assert_true((report.thresholds_pass as Dictionary).is_empty())
	assert_has(report, "breakdown")
	assert_eq(report.camera_probe.position, Vector2(125, -62.5))


func _tx_prepare(_action: StringName, domain: String) -> Dictionary:
	_tx_events.append("prepare:%s" % domain)
	return {"ok": true}


func _tx_stage(_action: StringName, domain: String) -> Dictionary:
	_tx_events.append("stage:%s" % domain)
	return {"ok": true}


func _tx_commit(domain: String, fail: bool) -> Dictionary:
	_tx_events.append("commit:%s" % domain)
	return {"ok": not fail, "error": "injected" if fail else ""}


func _tx_rollback(_action: StringName, domain: String) -> Dictionary:
	_tx_events.append("rollback:%s" % domain)
	return {"ok": true}


func _arena_fixture(size: Vector2i) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Phase 10–11", "phase_10_11")
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = arena.theme_id
	arena.source_image_size = Vector2i(640, 360)
	arena.grid_size = size
	arena.grid_origin = Vector2(320, 64)
	arena.axis_x = Vector2(32, 16)
	arena.axis_y = Vector2(-32, 16)
	for y in range(size.y):
		for x in range(size.x):
			ArenaTerrainRegistry.configure_cell(arena.ensure_cell(Vector2i(x, y)), &"stone")
	ArenaEditingService.prepare_automatically(arena)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena
