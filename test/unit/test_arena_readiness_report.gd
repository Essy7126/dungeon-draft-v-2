extends GutTest


func test_section_states_are_explicit_and_serializable() -> void:
	var section := ArenaReadinessSection.new()
	assert_eq(section.state, ArenaReadinessSection.State.NOT_RUN)
	assert_false(section.was_run())
	assert_false(section.passed())
	section.state = ArenaReadinessSection.State.PASS_WITH_WARNINGS
	section.warnings.append("design_warning")
	assert_true(section.was_run())
	assert_true(section.passed())
	assert_eq(section.state_name(), "PASS_WITH_WARNINGS")
	assert_eq(section.to_dict().warnings, ["design_warning"])
	section.state = ArenaReadinessSection.State.BLOCKED
	assert_true(section.blocks_readiness())
	assert_false(section.passed())


func test_data_warnings_remain_non_blocking() -> void:
	var validation := ArenaValidationReport.new()
	validation.add_message(
		ArenaValidationMessage.Severity.WARNING, &"narrow_passage",
		"Passage etroit volontaire."
	)
	var section := ArenaReadinessService.data_section(validation)
	assert_eq(section.state, ArenaReadinessSection.State.PASS_WITH_WARNINGS)
	assert_true(section.passed())
	assert_eq(section.errors.size(), 0)
	assert_eq(section.warnings.size(), 1)


func test_runtime_not_run_blocks_test_and_integration_but_not_production() -> void:
	var report := _otherwise_ready_report()
	report.runtime_scene_report = ArenaRuntimeSceneReport.new()
	report.recompute()
	assert_true(report.data_valid)
	assert_false(report.runtime_bootable)
	assert_false(report.ready_to_test)
	assert_true(report.ready_to_produce)
	assert_false(report.ready_to_integrate)


func test_visual_or_production_failure_blocks_production() -> void:
	var report := _otherwise_ready_report()
	report.visual_report = _section(ArenaReadinessSection.State.FAIL, &"VISUAL_INVALID")
	report.recompute()
	assert_false(report.ready_to_produce)
	assert_false(report.ready_to_integrate)
	report.visual_report = _section(ArenaReadinessSection.State.PASS, &"VISUAL_VALID")
	report.production_report = _section(
		ArenaReadinessSection.State.BLOCKED, &"PRODUCTION_BLOCKED"
	)
	report.recompute()
	assert_false(report.ready_to_produce)


func test_integration_requires_a_current_runtime_proof() -> void:
	var report := _otherwise_ready_report()
	report.recompute()
	assert_true(report.runtime_bootable)
	assert_true(report.ready_to_test)
	assert_true(report.ready_to_produce)
	assert_true(report.ready_to_integrate)
	report.integration_report = _section(
		ArenaReadinessSection.State.FAIL, &"INTEGRATION_NOT_READY"
	)
	report.recompute()
	assert_true(report.ready_to_produce)
	assert_false(report.ready_to_integrate)


func test_runtime_dictionary_requires_the_real_scene_contract() -> void:
	var payload := _runtime_payload()
	var runtime := ArenaReadinessService.runtime_scene_section(null, payload)
	assert_eq(runtime.state, ArenaReadinessSection.State.PASS)
	assert_true(runtime.runtime_contract_satisfied(), str(runtime.to_dict()))
	payload.pathfinder_ready = false
	runtime = ArenaReadinessService.runtime_scene_section(null, payload)
	assert_eq(runtime.state, ArenaReadinessSection.State.FAIL)
	assert_false(runtime.runtime_contract_satisfied())
	assert_has(runtime.errors, "pathfinder_not_ready")


func test_runtime_scene_path_mismatch_is_not_bootable() -> void:
	var payload := _runtime_payload()
	payload.expected_battle_scene_path = "res://data/rooms/maps/modular_battle.tscn"
	var runtime := ArenaReadinessService.runtime_scene_section(null, payload)
	assert_eq(runtime.state, ArenaReadinessSection.State.FAIL)
	assert_has(runtime.errors, "battle_scene_mismatch")


func test_build_keeps_all_six_domains_separate() -> void:
	var validation := ArenaValidationReport.new()
	var report := ArenaReadinessService.build(null, {
		"data_report": validation,
		"topology_report": _section(
			ArenaReadinessSection.State.PASS, &"TOPOLOGY_VALID"
		),
		"visual_report": _section(
			ArenaReadinessSection.State.PASS, &"VISUAL_VALID"
		),
		"runtime_scene_report": _runtime_report(),
		"production_report": _section(
			ArenaReadinessSection.State.PASS, &"PRODUCTION_READY"
		),
		"integration_report": _section(
			ArenaReadinessSection.State.PASS, &"INTEGRATION_READY"
		),
	})
	assert_true(report.data_valid)
	assert_true(report.runtime_bootable)
	assert_true(report.ready_to_test)
	assert_true(report.ready_to_produce)
	assert_true(report.ready_to_integrate)
	var serialized := report.to_dict()
	assert_true(serialized.has("data_report"))
	assert_true(serialized.has("topology_report"))
	assert_true(serialized.has("visual_report"))
	assert_true(serialized.has("runtime_scene_report"))
	assert_true(serialized.has("production_report"))
	assert_true(serialized.has("integration_report"))


func _otherwise_ready_report() -> ArenaReadinessReport:
	var report := ArenaReadinessReport.new()
	report.data_report = _section(ArenaReadinessSection.State.PASS, &"DATA_VALID")
	report.topology_report = _section(
		ArenaReadinessSection.State.PASS, &"TOPOLOGY_VALID"
	)
	report.visual_report = _section(
		ArenaReadinessSection.State.PASS, &"VISUAL_VALID"
	)
	report.runtime_scene_report = _runtime_report()
	report.production_report = _section(
		ArenaReadinessSection.State.PASS, &"PRODUCTION_READY"
	)
	report.integration_report = _section(
		ArenaReadinessSection.State.PASS, &"INTEGRATION_READY"
	)
	return report


func _section(state: int, code: StringName) -> ArenaReadinessSection:
	var section := ArenaReadinessSection.new()
	section.state = state
	section.code = code
	return section


func _runtime_report() -> ArenaRuntimeSceneReport:
	return ArenaReadinessService.runtime_scene_section(null, _runtime_payload())


func _runtime_payload() -> Dictionary:
	return {
		"ok": true,
		"runtime_scene_inspected": true,
		"expected_battle_scene_path": "res://data/rooms/maps/painted_battle.tscn",
		"battle_scene_path": "res://data/rooms/maps/painted_battle.tscn",
		"script_parse_ok": true,
		"scene_instantiated": true,
		"runtime_ready": true,
		"grid_ready": true,
		"pathfinder_ready": true,
		"render_ready": true,
		"spawn_ready": true,
		"cleanup_ok": true,
		"produced_bundle_loaded": false,
		"working_fingerprint": "same_fingerprint",
		"temporary_fingerprint": "same_fingerprint",
		"runtime_fingerprint": "same_fingerprint",
		"fingerprints_identical": true,
		"working_topology_hash": "same_topology",
		"temporary_topology_hash": "same_topology",
		"runtime_topology_hash": "same_topology",
		"topology_hashes_identical": true,
	}
