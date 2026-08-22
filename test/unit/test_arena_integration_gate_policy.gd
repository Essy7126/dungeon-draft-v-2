extends GutTest

const DESTINATION := "user://dungeon_draft_studio/tests/integration_gate/bundle"


func before_each() -> void:
	ArenaValidator.clear_cache()
	ArenaVisualAssembler.clear_inspection_cache()
	ArenaTerrainRenderPlanService.clear_cache()
	ArenaAutomaticRuntimeSmokeService.clear_cache()


func test_warnings_and_information_never_disable_production_gate() -> void:
	var arena := _arena_fixture("warning_policy")
	var report := ArenaValidationReport.new()
	report.add_message(
		ArenaValidationMessage.Severity.WARNING, &"narrow_passages",
		"Corridor etroit volontaire."
	)
	report.add_message(
		ArenaValidationMessage.Severity.INFO, &"foreground_missing",
		"Aucun foreground n'est configure."
	)
	var inputs := _runtime_inputs(arena)
	var gate := ArenaIntegrationGatePolicy.evaluate(
		report, inputs.parity, inputs.visual, inputs.smoke,
		{"state": ArenaBundleInspectionService.EMPTY},
		ArenaIntegrationGatePolicy.Profile.PRODUCTION, {
			"arena_fingerprint": ArenaSnapshotService.arena_fingerprint(arena),
			"manual_test_performed": false,
			"art_alignment_confirmed": false,
		}
	)
	assert_true(gate.ready_to_integrate, str(gate))
	assert_true((gate.blocking_errors as Array).is_empty())
	assert_gte((gate.acknowledgement_warnings as Array).size(), 3)
	assert_true(gate.requires_warning_acknowledgement)
	assert_true((gate.information as Array).any(func(value):
		return (value as Dictionary).code == "foreground_missing"
	))


func test_technical_validation_error_blocks_with_visible_reason() -> void:
	var arena := _arena_fixture("blocking_policy")
	var report := ArenaValidationReport.new()
	report.add_message(
		ArenaValidationMessage.Severity.ERROR, &"spawn_blocked",
		"Heros 2 ne possede pas de position valide."
	)
	var inputs := _runtime_inputs(arena)
	var gate := ArenaIntegrationGatePolicy.evaluate(
		report, inputs.parity, inputs.visual, inputs.smoke,
		{"state": ArenaBundleInspectionService.EMPTY}
	)
	assert_false(gate.ready_to_integrate)
	assert_eq((gate.blocking_errors as Array).size(), 1)
	assert_eq((gate.blocking_errors as Array)[0].code, "spawn_blocked")
	assert_true((gate.blocking_errors as Array)[0].blocks_integration)


func test_removed_missing_or_duplicate_tiles_are_always_blocking() -> void:
	var arena := _arena_fixture("topology_policy")
	var inputs := _runtime_inputs(arena)
	var divergent := (inputs.parity as Dictionary).duplicate(true)
	divergent.valid = false
	divergent.removed_cells_rendered = ["2,2"]
	divergent.duplicate_cells = ["4,4"]
	var gate := ArenaIntegrationGatePolicy.evaluate(
		ArenaValidator.validate(arena, false), divergent,
		inputs.visual, inputs.smoke,
		{"state": ArenaBundleInspectionService.EMPTY}
	)
	assert_false(gate.ready_to_integrate)
	assert_true((gate.blocking_errors as Array).any(func(value):
		return (value as Dictionary).code == "REMOVED_CELL_RENDERED"
	))
	assert_true((gate.blocking_errors as Array).any(func(value):
		return (value as Dictionary).code == "MISSING_OR_DUPLICATE_TILES"
	))


func test_automatic_smoke_round_trips_user_copy_and_exact_floor_sets() -> void:
	var arena := _arena_fixture("automatic_smoke")
	var smoke := ArenaAutomaticRuntimeSmokeService.run(arena)
	assert_true(smoke.ok, str(smoke))
	assert_true(str(smoke.temporary_path).begins_with(
		ArenaAutomaticRuntimeSmokeService.ROOT + "/"
	))
	assert_true(smoke.fingerprints_identical)
	assert_true(smoke.topology_hashes_identical)
	assert_eq(smoke.expected_floor_cells, smoke.rendered_floor_cells)
	assert_eq(smoke.expected_floor_hash, smoke.rendered_floor_hash)
	assert_true((smoke.missing_cells as Array).is_empty())
	assert_true((smoke.unexpected_cells as Array).is_empty())
	assert_true((smoke.removed_cells_rendered as Array).is_empty())
	assert_true((smoke.duplicate_cells as Array).is_empty())


func test_warning_acceptance_is_justified_fingerprinted_and_invalidated() -> void:
	var arena := _arena_fixture("warning_acceptance")
	var session := ArenaEditSession.new()
	assert_true(session.open(arena, "", true, "warning_acceptance"))
	var issue := {
		"code": "narrow_passages",
		"cell": [2, 2],
		"subject_id": "",
	}
	assert_true(session.accept_design_warning(issue, "Passage de verrouillage du Guerrier.").is_empty() == false)
	var accepted := session.accepted_design_warnings()
	assert_eq(accepted.size(), 1)
	assert_eq(accepted[0].justification, "Passage de verrouillage du Guerrier.")
	assert_eq(accepted[0].arena_fingerprint, session.current_fingerprint())
	var report := ArenaValidationReport.new()
	report.add_message(
		ArenaValidationMessage.Severity.WARNING, &"narrow_passages",
		"Corridor accepte.", Vector2i(2, 2)
	)
	var inputs := _runtime_inputs(session.working_arena)
	var gate := ArenaIntegrationGatePolicy.evaluate(
		report, inputs.parity, inputs.visual, inputs.smoke,
		{"state": ArenaBundleInspectionService.EMPTY},
		ArenaIntegrationGatePolicy.Profile.PRODUCTION, {
			"arena_fingerprint": session.current_fingerprint(),
			"accepted_warnings": accepted,
		}
	)
	var accepted_issue := (gate.acknowledgement_warnings as Array).filter(
		func(value): return (value as Dictionary).code == "narrow_passages"
	)
	assert_eq(accepted_issue.size(), 1)
	assert_true(accepted_issue[0].acknowledged)
	var before := session.working_arena.to_snapshot()
	session.working_arena.erase_cell(Vector2i(5, 5))
	var after := session.working_arena.to_snapshot()
	assert_true(session.commit("Changer la topologie", before, after))
	assert_true(session.accepted_design_warnings().is_empty())


func test_strict_release_only_promotes_explicit_warning_codes() -> void:
	var arena := _arena_fixture("strict_profile")
	var report := ArenaValidationReport.new()
	report.add_message(
		ArenaValidationMessage.Severity.WARNING, &"narrow_passages",
		"Corridor etroit."
	)
	var inputs := _runtime_inputs(arena)
	var production := ArenaIntegrationGatePolicy.evaluate(
		report, inputs.parity, inputs.visual, inputs.smoke,
		{"state": ArenaBundleInspectionService.EMPTY}
	)
	assert_true(production.ready_to_integrate)
	var strict := ArenaIntegrationGatePolicy.evaluate(
		report, inputs.parity, inputs.visual, inputs.smoke,
		{"state": ArenaBundleInspectionService.EMPTY},
		ArenaIntegrationGatePolicy.Profile.STRICT_RELEASE, {
			"strict_blocking_warning_codes": ["narrow_passages"],
		}
	)
	assert_false(strict.ready_to_integrate)
	assert_true((strict.blocking_errors as Array).any(func(value):
		return (value as Dictionary).code == "narrow_passages"
	))


func test_certificate_does_not_require_manual_previews_or_manual_test() -> void:
	var certificate := ArenaProductionReadinessCertificate.new()
	certificate.automatic_runtime_smoke_valid = true
	certificate.runtime_test_valid = true
	certificate.expected_tiles = 8
	certificate.rendered_tiles = 8
	certificate.expected_walls = 2
	certificate.rendered_walls = 2
	certificate.pathfinding_valid = true
	certificate.spawn_contract_valid = true
	certificate.coverage_gate_valid = true
	certificate.destination_conflict_state = ArenaBundleInspectionService.EMPTY
	certificate.canonical_topology_hash = "same"
	certificate.temporary_topology_hash = "same"
	certificate.runtime_topology_hash = "same"
	certificate.expected_floor_hash = "floor"
	certificate.rendered_floor_hash = "floor"
	certificate.topology_gate_valid = true
	certificate.preview_logic_valid = false
	certificate.preview_art_valid = false
	certificate.preview_game_valid = false
	certificate.art_alignment_confirmed = false
	certificate.manual_test_performed = false
	certificate.readiness_report = ArenaReadinessService.build(null, {
		"data_report": _passing_readiness_section(&"DATA_VALID"),
		"visual_report": _passing_readiness_section(&"VISUAL_VALID"),
		"runtime_scene_report": _passing_runtime_result(),
		"production_plan": {"ok": true, "can_produce": true},
		"integration_plan": {"ok": true, "can_integrate": true},
	})
	assert_true(certificate.recompute_ready(), str(certificate.to_dict()))
	assert_true(certificate.blocking_errors.is_empty())
	assert_true(certificate.acknowledgement_warnings.any(func(value):
		return (value as Dictionary).code == "MANUAL_TEST_NOT_PERFORMED"
	))
	certificate.unexpected_cells = ["7,7"]
	assert_false(certificate.recompute_ready())


func test_projection_smoke_cannot_replace_real_runtime_scene_gate() -> void:
	var arena := _arena_fixture("runtime_scene_gate")
	var inputs := _runtime_inputs(arena)
	var missing := ArenaIntegrationGatePolicy.evaluate(
		ArenaValidator.validate(arena, false), inputs.parity, inputs.visual,
		inputs.smoke, {"state": ArenaBundleInspectionService.EMPTY},
		ArenaIntegrationGatePolicy.Profile.PRODUCTION, {
			"requires_runtime_scene": true,
			"runtime_scene_result": {},
		}
	)
	assert_false(missing.runtime_bootable)
	assert_true(missing.ready_to_produce)
	assert_false(missing.ready_to_integrate)
	assert_true((missing.blocking_errors as Array).any(func(value):
		return (value as Dictionary).code == "RUNTIME_SCENE_NOT_RUN"
	))
	var verified := ArenaIntegrationGatePolicy.evaluate(
		ArenaValidator.validate(arena, false), inputs.parity, inputs.visual,
		inputs.smoke, {"state": ArenaBundleInspectionService.EMPTY},
		ArenaIntegrationGatePolicy.Profile.PRODUCTION, {
			"requires_runtime_scene": true,
			"runtime_scene_result": _passing_runtime_result(),
		}
	)
	assert_true(verified.runtime_bootable, str(verified))
	assert_true(verified.ready_to_integrate, str(verified))


func test_integration_plan_exposes_gate_and_ignores_unrelated_dirty_domains() -> void:
	var arena := _arena_fixture("integration_plan")
	var plan := ArenaIntegrationService.plan(
		arena, null, ArenaProductionAttachmentService.NONE, -1,
		DESTINATION, null, {
			"unrelated_dirty_domains": ["vfx", "skill_tree"],
			"manual_test_performed": false,
		}
	)
	assert_true(plan.ok, str(plan))
	assert_true(plan.can_integrate, str(plan.gate_report))
	assert_true((plan.gate_report.blocking_errors as Array).is_empty())
	assert_true((plan.gate_report.information as Array).any(func(value):
		return (value as Dictionary).code == "UNRELATED_DOCUMENTS_DIRTY"
	))


func test_justified_terrain_overrides_are_aggregated_as_one_information() -> void:
	var arena := _arena_fixture("override_aggregation")
	for cell in [Vector2i(2, 2), Vector2i(3, 2)]:
		var definition := arena.get_cell_definition(cell)
		definition.terrain_id = &"lava"
		definition.cell_type = GridData.CellType.NORMAL
		definition.playable = true
		definition.production_note = "Choix de design valide."
	var report := ArenaValidator.validate(arena, false)
	var aggregated := report.messages.filter(func(value):
		return value.code == &"terrain_overrides_verified"
	)
	assert_eq(aggregated.size(), 1)
	assert_eq(aggregated[0].severity, ArenaValidationMessage.Severity.INFO)
	var verified_details: Array = JSON.parse_string(aggregated[0].technical_details)
	assert_eq(verified_details.size(), 2)
	assert_false(report.messages.any(func(value):
		return value.code == &"terrain_manual_override"
	))


func _runtime_inputs(arena: ArenaDefinition) -> Dictionary:
	var smoke := ArenaAutomaticRuntimeSmokeService.run(arena)
	var visual := ArenaVisualAssembler.inspect(arena)
	return {
		"smoke": smoke,
		"visual": visual,
		"parity": {
			"valid": bool(smoke.get("ok", false)),
			"canonical_topology_hash": smoke.get("working_topology_hash", ""),
			"temporary_topology_hash": smoke.get("temporary_topology_hash", ""),
			"runtime_topology_hash": smoke.get("runtime_topology_hash", ""),
			"expected_floor_hash": smoke.get("expected_floor_hash", ""),
			"rendered_floor_hash": smoke.get("rendered_floor_hash", ""),
			"missing_cells": smoke.get("missing_cells", []),
			"unexpected_cells": smoke.get("unexpected_cells", []),
			"removed_cells_rendered": smoke.get("removed_cells_rendered", []),
			"duplicate_cells": smoke.get("duplicate_cells", []),
		},
	}


func _passing_readiness_section(code: StringName) -> ArenaReadinessSection:
	var section := ArenaReadinessSection.new()
	section.state = ArenaReadinessSection.State.PASS
	section.code = code
	return section


func _passing_runtime_result() -> Dictionary:
	return {
		"ok": true,
		"runtime_scene_inspected": true,
		"battle_scene_path": "res://battle/painted/painted_battle.tscn",
		"script_parse_ok": true,
		"scene_instantiated": true,
		"runtime_ready": true,
		"grid_ready": true,
		"pathfinder_ready": true,
		"render_ready": true,
		"spawn_ready": true,
		"produced_bundle_loaded": false,
		"working_fingerprint": "same",
		"temporary_fingerprint": "same",
		"runtime_fingerprint": "same",
		"fingerprints_identical": true,
		"working_topology_hash": "same",
		"temporary_topology_hash": "same",
		"runtime_topology_hash": "same",
		"topology_hashes_identical": true,
	}


func _arena_fixture(identifier: String) -> ArenaDefinition:
	var arena := ArenaDefinition.new()
	arena.set_identity("Gate %s" % identifier, "gate_%s" % identifier)
	arena.visual_mode = ArenaDefinition.VisualMode.MODULAR
	arena.theme_id = &"dynamic_default"
	arena.modular_visual_profile = ArenaModularVisualProfile.new()
	arena.modular_visual_profile.theme_id = arena.theme_id
	arena.grid_size = Vector2i(12, 9)
	arena.grid_origin = Vector2.ZERO
	arena.axis_x = Vector2(32.0, 16.0)
	arena.axis_y = Vector2(-32.0, 16.0)
	for y in range(arena.grid_size.y):
		for x in range(arena.grid_size.x):
			ArenaTerrainRegistry.configure_cell(
				arena.ensure_cell(Vector2i(x, y)), &"stone"
			)
	ArenaEditingService.prepare_automatically(arena)
	var objective := ArenaObjectiveDefinition.new()
	objective.objective_id = &"gate_goal"
	objective.cell = Vector2i(6, 4)
	arena.objectives.append(objective)
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	return arena
