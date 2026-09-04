extends GutTest

const ODYSSEY := "res://data/runs/odyssey.tres"
const ACHILLES := "res://data/units/allies/achilles.tres"
const PROGRESSION := "res://data/runs/progression/odyssey/achilles_progression_profile.tres"
const SPELL_PATHS := [
	"res://data/spells/achilles/spear_thrust.tres",
	"res://data/spells/achilles/advance.tres",
	"res://data/spells/achilles/sweep.tres",
	"res://data/spells/achilles/guard.tres",
]
const DISCIPLINE_PATHS := [
	"res://data/characters/achilles/disciplines/spear.tres",
	"res://data/characters/achilles/disciplines/advance.tres",
	"res://data/characters/achilles/disciplines/sweep.tres",
	"res://data/characters/achilles/disciplines/guard.tres",
]

var exporter := AchillesTheorycraftSnapshotExporter.new()
var catalog := AchillesTheorycraftCatalog.new()
var analyzer := AchillesActionEconomyAnalyzer.new()
var validator := AchillesTheorycraftValidator.new()
var comparison := AchillesTheorycraftComparisonService.new()
var store := AchillesTheorycraftStore.new()
var snapshot := {}
var baseline: AchillesTheorycraftBuild


func before_all() -> void:
	snapshot = exporter.build_snapshot()
	baseline = catalog.create_current_baseline(str(snapshot.get("snapshot_sha", "")))


func after_all() -> void:
	for draft_id in [
		"gut_isolated_character_state_draft",
		"gut_state_isolation_draft",
		"gut_user_path",
	]:
		_remove_file(AchillesTheorycraftStore.DRAFT_ROOT.path_join("%s.json" % draft_id))
	_remove_tree(AchillesTheorycraftStore.EXPORT_ROOT.path_join("gut"))
	_remove_tree(AchillesTheorycraftStore.EXPORT_ROOT.path_join("gut_determinism"))
	_remove_tree("user://theorycraft_rejected")


func test_snapshot_records_repository_sha() -> void:
	assert_false(snapshot.has("error"), str(snapshot))
	var commit := str(snapshot.repository.commit)
	assert_eq(commit.length(), 40)
	assert_eq(commit, _git(["rev-parse", "HEAD"]))
	assert_eq(str(snapshot.repository.commit_date), _git(["show", "-s", "--format=%cI", "HEAD"]))
	var expected_classification := (
		"PRE_COMMIT_SOURCE_HEAD"
		if not _git(["status", "--porcelain", "--untracked-files=normal"]).is_empty()
		else "COMMITTED_SOURCE_HEAD"
	)
	assert_eq(snapshot.repository.source_classification, expected_classification)
	assert_eq(snapshot.repository.worktree_dirty, expected_classification == "PRE_COMMIT_SOURCE_HEAD")


func test_snapshot_matches_achilles_unit_resource() -> void:
	var unit := load(ACHILLES) as UnitData
	assert_eq(snapshot.achilles.character_id, str(unit.unit_id))
	assert_eq(snapshot.achilles.max_hp, 110)
	assert_eq(snapshot.achilles.initiative, 14)
	assert_eq(snapshot.achilles.max_ap, 6)
	assert_eq(snapshot.achilles.max_mp, 3)
	assert_eq(snapshot.achilles.attack_power, 18)
	assert_false(snapshot.achilles.basic_attack_enabled)
	assert_eq(snapshot.achilles.active_spell_slots, 4)


func test_snapshot_matches_progression_profile() -> void:
	var run := load(ODYSSEY) as RunData
	var resolved := RunHeroResolver.resolve_runtime_hero_data(run, false)
	assert_true(resolved.is_valid(), str(resolved.errors))
	assert_eq(resolved.heroes.size(), 1)
	assert_eq(resolved.heroes[0].spells.size(), 4)
	assert_eq(snapshot.achilles.progression_profile, PROGRESSION)


func test_snapshot_matches_four_spell_resources() -> void:
	assert_eq(snapshot.capabilities.size(), 4)
	var by_id := {}
	for spell in snapshot.capabilities:
		by_id[spell.id] = spell
	assert_eq(by_id.achilles_spear_thrust.ap_cost, 2)
	assert_eq([by_id.achilles_spear_thrust.minimum_range, by_id.achilles_spear_thrust.maximum_range], [1, 2])
	assert_eq(by_id.achilles_spear_thrust.damage, 9)
	assert_true(by_id.achilles_spear_thrust.once_per_activation)
	assert_eq(by_id.achilles_advance.ap_cost, 2)
	assert_eq(by_id.achilles_advance.maximum_range, 3)
	assert_eq(by_id.achilles_advance.damage, 5)
	assert_true(by_id.achilles_advance.movement.moves_caster_to_target)
	assert_true(by_id.achilles_advance.movement.requires_clear_path)
	assert_eq(by_id.achilles_sweep.ap_cost, 3)
	assert_eq(by_id.achilles_sweep.damage, 6)
	assert_eq(by_id.achilles_sweep.push, 1)
	assert_eq(by_id.achilles_guard.ap_cost, 2)
	assert_eq(by_id.achilles_guard.shield, 10)


func test_snapshot_matches_four_discipline_resources() -> void:
	assert_eq(snapshot.disciplines.size(), 4)
	var ids: Array = snapshot.disciplines.map(func(value): return value.id)
	ids.sort()
	assert_eq(ids, ["advance", "guard", "spear", "sweep"])
	for discipline in snapshot.disciplines:
		assert_eq(discipline.ranks.size(), 2)
		assert_eq(discipline.ranks[0].rank, 1)
		assert_eq(discipline.ranks[0].required_total_xp, 0)
		assert_true(discipline.ranks[0].choices.is_empty())
		assert_eq(discipline.ranks[1].rank, 2)
		assert_eq(discipline.ranks[1].required_total_xp, 3)
		assert_eq(discipline.ranks[1].choices.size(), 2)


func test_snapshot_matches_odyssey_rooms() -> void:
	assert_eq(snapshot.odyssey.seed, 2401)
	assert_eq(snapshot.odyssey.target_duration_minutes, 18)
	assert_eq(snapshot.odyssey.extended_duration_minutes, 25)
	assert_eq(snapshot.odyssey.rooms.size(), 3)
	assert_true(snapshot.odyssey.rooms.all(func(room): return room.flow_encounter_count == 1))
	assert_eq(snapshot.odyssey.starting_inventory, [
		{"item_id": "minor_healing_potion", "quantity": 2},
		{"item_id": "minor_action_scroll", "quantity": 1},
	])
	assert_true(snapshot.odyssey.equipment_rewards_enabled)
	assert_true(snapshot.odyssey.rewards.equipment_enabled)
	assert_eq(
		snapshot.odyssey.rewards.equipment_pool_tag,
		str(FirstRunEquipmentRewardService.POOL_TAG),
	)


func test_snapshot_matches_odyssey_enemies() -> void:
	var by_id := {}
	for enemy in snapshot.enemies:
		by_id[enemy.id] = enemy
	assert_eq(by_id.odyssey_skirmisher.max_hp, 45)
	assert_eq([by_id.odyssey_skirmisher.max_ap, by_id.odyssey_skirmisher.max_mp], [4, 4])
	assert_eq(by_id.odyssey_guard.max_hp, 70)
	assert_eq(by_id.odyssey_guard.armor, 20.0)
	assert_eq(by_id.odyssey_champion.max_hp, 115)
	assert_eq(by_id.odyssey_champion.attack_power, 16)
	assert_eq(by_id.odyssey_champion.armor, 30.0)


func test_theorycraft_code_is_not_referenced_by_odyssey() -> void:
	for path in [ODYSSEY, "res://data/runs/profiles/odyssey_content_profile.tres", PROGRESSION]:
		assert_false(_text(path).contains("tools/achilles_theorycraft"), path)


func test_theorycraft_code_is_not_referenced_by_achilles_unit() -> void:
	assert_false(_text(ACHILLES).contains("tools/achilles_theorycraft"))


func test_theorycraft_draft_does_not_modify_character_run_state() -> void:
	var before := _production_fingerprints()
	var draft := catalog.create_sword_shield_template(snapshot.snapshot_sha)
	draft.build_id = "gut_isolated_character_state_draft"
	var result := store.save_draft(draft)
	assert_true(result.ok, str(result))
	assert_eq(_production_fingerprints(), before)


func test_theorycraft_draft_does_not_modify_save_data() -> void:
	var draft := catalog.create_bow_template(snapshot.snapshot_sha)
	draft.build_id = "gut_state_isolation_draft"
	var result := store.save_draft(draft)
	assert_true(result.ok, str(result))
	assert_true(str(result.path).begins_with("user://theorycraft/achilles/"))
	assert_false(str(result.path).contains("/saves/"))
	assert_false(str(result.path).contains("character_run_state"))


func test_theorycraft_export_does_not_modify_production_resources() -> void:
	var before := _production_fingerprints()
	var builds := catalog.initial_builds(snapshot.snapshot_sha)
	var report := comparison.compare(builds, [TheorycraftContext.abstract_context()])
	var result := store.export_review(report, builds, AchillesTheorycraftStore.EXPORT_ROOT.path_join("gut"))
	assert_true(result.ok, str(result))
	assert_eq(_production_fingerprints(), before)


func test_export_destinations_reject_arbitrary_and_canonical_paths() -> void:
	var builds := catalog.initial_builds(snapshot.snapshot_sha)
	var report := comparison.compare(builds)
	var rejected_root := ProjectSettings.globalize_path("user://theorycraft_rejected")
	var fake_mission_root := rejected_root.path_join(
		AchillesTheorycraftStore.MISSION_ARTIFACT_DIRECTORY
	)
	var fake_existed_before := DirAccess.dir_exists_absolute(fake_mission_root)
	for forbidden_root in [
		rejected_root.path_join("arbitrary"),
		fake_mission_root,
		rejected_root.path_join("canonical/review"),
		rejected_root.path_join("external_worktree/review"),
	]:
		assert_false(store.configure_artifact_root(forbidden_root), forbidden_root)
		assert_false(store.export_review(report, builds, forbidden_root).ok, forbidden_root)
		assert_false(exporter.configure_artifact_root(forbidden_root), forbidden_root)
		assert_false(exporter.export_snapshot(forbidden_root).ok, forbidden_root)
	assert_eq(
		DirAccess.dir_exists_absolute(fake_mission_root),
		fake_existed_before,
		"Rejected destination must not be created before validation",
	)
	var explicit_mission_root := ProjectSettings.globalize_path("res://")
	explicit_mission_root = explicit_mission_root.path_join("artifacts")
	explicit_mission_root = explicit_mission_root.path_join(
		AchillesTheorycraftStore.MISSION_ARTIFACT_DIRECTORY
	)
	assert_true(store.configure_artifact_root(explicit_mission_root))
	assert_true(exporter.configure_artifact_root(explicit_mission_root))
	assert_true(store.configure_artifact_root(AchillesTheorycraftStore.DURABLE_INTEGRATION_ROOT))
	assert_true(exporter.configure_artifact_root(
		AchillesTheorycraftSnapshotExporter.DURABLE_INTEGRATION_ROOT
	))


func test_artifact_generator_validates_root_before_creating_directories() -> void:
	var source := _text(
		"res://artifacts/ACHILLES_3D_CHARACTER_THEORYCRAFT_V1_20260820_181248/"
		+ "08_theorycraft_validation/generate_theorycraft_artifacts.gd"
	)
	var exporter_validation := source.find("if not exporter.configure_artifact_root")
	var store_validation := source.find("if not store.configure_artifact_root")
	var directory_creation := source.find("DirAccess.make_dir_recursive_absolute")
	assert_true(exporter_validation >= 0)
	assert_true(store_validation >= 0)
	assert_true(directory_creation >= 0)
	assert_true(exporter_validation < directory_creation)
	assert_true(store_validation < directory_creation)


func test_user_drafts_are_saved_outside_res() -> void:
	var draft := catalog.create_bow_template(snapshot.snapshot_sha)
	draft.build_id = "gut_user_path"
	var result := store.save_draft(draft)
	assert_true(result.ok, str(result))
	assert_true(str(result.path).begins_with(AchillesTheorycraftStore.DRAFT_ROOT))
	assert_false(str(result.path).begins_with("res://"))


func test_theorycraft_sources_contain_no_production_save_service() -> void:
	var files := _files_recursive("res://tools/achilles_theorycraft")
	for path in files:
		if path.ends_with(".gd"):
			assert_false(_text(path).contains("Resource" + "Saver"), path)


func test_sequence_enumerator_respects_six_ap() -> void:
	var result := analyzer.analyze(baseline)
	assert_eq(result.sequence_count, 22)
	assert_eq(result.ap_budget, snapshot.achilles.max_ap)
	assert_eq(
		result.provenance.ap_budget.kind,
		AchillesTheorycraftProvenance.OBSERVED_RUNTIME_DATA,
	)
	for sequence in result.sequences:
		assert_true(sequence.ap_spent <= 6, str(sequence))


func test_sequence_enumerator_respects_explicit_non_six_ap_budget() -> void:
	var result := analyzer.analyze(baseline, null, 5)
	assert_eq(result.ap_budget, 5)
	assert_eq(
		result.provenance.ap_budget.kind,
		AchillesTheorycraftProvenance.MANUAL_ASSUMPTION,
	)
	assert_true(result.sequences.all(func(sequence): return sequence.ap_spent <= 5))


func test_sequence_enumerator_has_no_hidden_six_ap_fallback() -> void:
	var unresolved := AchillesTheorycraftBuild.from_dict(baseline.to_dict())
	unresolved.ap_budget = null
	unresolved.provenance.erase("ap_budget")
	var result := analyzer.analyze(unresolved)
	assert_null(result.ap_budget)
	assert_null(result.sequence_count)
	assert_true(result.not_measured.has("AP_BUDGET_NOT_MEASURED"))


func test_sequence_enumerator_respects_once_per_activation() -> void:
	var result := analyzer.analyze(baseline)
	for sequence in result.sequences:
		var unique := {}
		for action_id in sequence.action_ids:
			assert_false(unique.has(action_id), str(sequence))
			unique[action_id] = true


func test_sequence_enumerator_reports_unused_ap() -> void:
	var result := analyzer.analyze(baseline)
	assert_eq(result.unused_ap_histogram, {"0": 6, "1": 6, "2": 6, "3": 1, "4": 3})
	assert_eq(result.inclusion_maximal_count, 12)


func test_sequence_enumerator_distinguishes_abstract_and_contextual() -> void:
	var context := TheorycraftContext.new()
	context.context_id = "manual_legality_fixture"
	context.starting_state["legal_action_ids"] = baseline.action_slots.map(
		func(action): return str(action.semantic_id)
	)
	var result := analyzer.analyze(baseline, context)
	assert_eq(result.sequence_count, 22)
	assert_eq(result.contextual_sequence_count, 22)
	assert_true(result.contextually_legal_sequences.all(func(sequence):
		return sequence.type == AchillesActionEconomyAnalyzer.CONTEXTUALLY_LEGAL_SEQUENCE
	))


func test_contextual_sequence_count_remains_not_measured_without_legality_evidence() -> void:
	for context in catalog.odyssey_contexts():
		var result := analyzer.analyze(baseline, context)
		assert_null(result.contextual_sequence_count, context.context_id)
		assert_null(result.contextually_legal_sequences, context.context_id)
		assert_true(
			result.not_measured.has("CONTEXTUAL_LEGALITY_NOT_MEASURED"),
			context.context_id,
		)
		assert_eq(
			result.provenance.contextual_sequence_count.kind,
			AchillesTheorycraftProvenance.NOT_MEASURED,
			context.context_id,
		)


func test_all_context_fields_export_explicit_provenance() -> void:
	for context in catalog.odyssey_contexts():
		var data := context.to_dict()
		for field in [
			"context_id", "room_resource", "enemy_resources", "turn_horizon",
			"starting_state", "consumables", "assumptions",
		]:
			assert_true(data.provenance.has(field), "%s/%s" % [data.context_id, field])
			assert_true(
				AchillesTheorycraftProvenance.is_valid(data.provenance[field]),
				"%s/%s" % [data.context_id, field],
			)


func test_sequence_enumerator_is_deterministic() -> void:
	assert_eq(
		AchillesTheorycraftJson.stringify(analyzer.analyze(baseline)),
		AchillesTheorycraftJson.stringify(analyzer.analyze(baseline)),
	)


func test_observed_values_have_resource_source() -> void:
	for capability in snapshot.capabilities:
		assert_eq(capability._provenance.ap_cost.kind, AchillesTheorycraftProvenance.OBSERVED_RUNTIME_DATA)
		assert_true(str(capability._provenance.ap_cost.source).begins_with("res://"))


func test_derived_values_have_calculation_source() -> void:
	var analysis := analyzer.analyze(baseline)
	assert_eq(analysis.provenance.sequences.kind, AchillesTheorycraftProvenance.DERIVED_EXACT)
	assert_false(str(analysis.provenance.sequences.calculation).is_empty())


func test_action_build_and_static_template_fields_have_complete_provenance() -> void:
	for build in catalog.initial_builds(snapshot.snapshot_sha):
		var build_data := build.to_dict()
		for field in build_data.keys():
			if field == "provenance":
				continue
			assert_true(build_data.provenance.has(field), "%s/%s" % [build.build_id, field])
			assert_true(
				AchillesTheorycraftProvenance.is_valid(build_data.provenance[field]),
				"%s/%s" % [build.build_id, field],
			)
		for action in build_data.action_slots:
			for field in action.keys():
				if field == "provenance":
					continue
				assert_true(action.provenance.has(field), "%s/%s" % [action.semantic_id, field])
				assert_true(
					AchillesTheorycraftProvenance.is_valid(action.provenance[field]),
					"%s/%s" % [action.semantic_id, field],
				)
			if build.status == AchillesTheorycraftBuild.STATUS_BASELINE:
				assert_eq(
					action.provenance.real_spell_resource.kind,
					AchillesTheorycraftProvenance.OBSERVED_RUNTIME_DATA,
				)
				assert_eq(
					action.provenance.draft_status.kind,
					AchillesTheorycraftProvenance.DERIVED_EXACT,
				)
			else:
				assert_eq(
					action.provenance.real_spell_resource.kind,
					AchillesTheorycraftProvenance.NOT_MEASURED,
				)
				assert_eq(
					action.provenance.draft_status.kind,
					AchillesTheorycraftProvenance.DRAFT_DESIGN_INPUT,
				)
		assert_true(build_data.provenance.has("real_resource_refs"), build.build_id)
	for path in [
		"res://tools/achilles_theorycraft/templates/sword_shield_concept_template.json",
		"res://tools/achilles_theorycraft/templates/bow_concept_template.json",
	]:
		var parsed: Variant = JSON.parse_string(_text(path))
		assert_true(parsed is Dictionary, path)
		if not parsed is Dictionary:
			continue
		for field in parsed.keys():
			if field == "provenance":
				continue
			assert_true(parsed.provenance.has(field), "%s/%s" % [path, field])
			assert_true(
				AchillesTheorycraftProvenance.is_valid(parsed.provenance[field]),
				"%s/%s" % [path, field],
			)


func test_snapshot_root_containers_have_explicit_provenance() -> void:
	for field in [
		"repository", "achilles", "capabilities", "disciplines", "odyssey",
		"enemies", "maps",
	]:
		assert_true(snapshot._provenance.has(field), field)
		assert_true(AchillesTheorycraftProvenance.is_valid(snapshot._provenance[field]), field)


func test_comparison_report_fields_and_gaps_have_complete_provenance() -> void:
	var data := comparison.compare(catalog.initial_builds(snapshot.snapshot_sha)).to_dict()
	for field in data.keys():
		if field == "provenance":
			continue
		assert_true(data.provenance.has(field), field)
		assert_true(AchillesTheorycraftProvenance.is_valid(data.provenance[field]), field)
	for build_data in data.builds:
		for field in build_data.keys():
			if field == "provenance":
				continue
			assert_true(build_data.provenance.has(field), "%s/%s" % [build_data.build_id, field])
			assert_true(
				AchillesTheorycraftProvenance.is_valid(build_data.provenance[field]),
				"%s/%s" % [build_data.build_id, field],
			)
	for entry in data.not_measured:
		assert_true(AchillesTheorycraftProvenance.is_valid(entry.provenance), str(entry))
		assert_eq(entry.provenance.kind, AchillesTheorycraftProvenance.NOT_MEASURED)
	for analysis in data.ap_sequences.values():
		for field in analysis.keys():
			if field == "provenance":
				continue
			assert_true(analysis.provenance.has(field), field)
			assert_true(AchillesTheorycraftProvenance.is_valid(analysis.provenance[field]), field)


func test_draft_values_are_marked_draft() -> void:
	var draft := catalog.create_sword_shield_template(snapshot.snapshot_sha)
	assert_eq(draft.status, "DRAFT")
	assert_eq(draft.provenance.author_notes.kind, AchillesTheorycraftProvenance.DRAFT_DESIGN_INPUT)
	assert_true(draft.action_slots.all(func(action):
		return action.provenance.conditions.kind == AchillesTheorycraftProvenance.DRAFT_DESIGN_INPUT
	))


func test_edited_draft_action_value_becomes_draft_provenance() -> void:
	var draft := catalog.create_bow_template(snapshot.snapshot_sha)
	draft.action_slots[0].ap_cost = 2
	draft.mark_owner_editable_fields_as_draft()
	assert_eq(
		draft.action_slots[0].provenance.ap_cost.kind,
		AchillesTheorycraftProvenance.DRAFT_DESIGN_INPUT,
	)


func test_real_spell_reference_refreshes_values_from_resource() -> void:
	var data := baseline.to_dict()
	data.action_slots[0].ap_cost = 99
	data.action_slots[0].provenance.ap_cost = AchillesTheorycraftProvenance.draft()
	var restored := AchillesTheorycraftBuild.from_dict(data)
	assert_eq(restored.action_slots[0].resolved_ap_cost(), 2)
	assert_eq(
		restored.action_slots[0].provenance.ap_cost.kind,
		AchillesTheorycraftProvenance.OBSERVED_RUNTIME_DATA,
	)


func test_manual_assumptions_are_visible() -> void:
	var context := TheorycraftContext.new()
	context.context_id = "manual_fixture"
	context.starting_state.legal_action_ids = baseline.action_slots.map(
		func(action): return str(action.semantic_id)
	)
	var result := analyzer.analyze(baseline, context)
	assert_eq(
		result.sequences[0].contextual_legality.provenance.kind,
		AchillesTheorycraftProvenance.MANUAL_ASSUMPTION,
	)


func test_not_measured_is_not_reported_as_zero() -> void:
	var draft := catalog.create_bow_template(snapshot.snapshot_sha)
	var result := analyzer.analyze(draft)
	assert_null(result.sequence_count)
	assert_ne(result.sequence_count, 0)
	assert_true(result.not_measured.size() > 0)
	for room in snapshot.maps:
		assert_null(room.path_distance)
		assert_eq(room._provenance.path_distance.kind, AchillesTheorycraftProvenance.NOT_MEASURED)


func test_build_comparison_is_deterministic() -> void:
	var builds := catalog.initial_builds(snapshot.snapshot_sha)
	var first := comparison.compare(builds).to_dict()
	var second := comparison.compare(builds).to_dict()
	assert_eq(AchillesTheorycraftJson.stringify(first), AchillesTheorycraftJson.stringify(second))


func test_build_comparison_caps_selection_at_three() -> void:
	var builds := catalog.initial_builds(snapshot.snapshot_sha)
	var fourth := AchillesTheorycraftBuild.from_dict(builds[1].to_dict())
	fourth.build_id = "FOURTH_DRAFT_SHOULD_NOT_ENTER_REPORT"
	builds.append(fourth)
	var report := comparison.compare(builds)
	assert_eq(report.builds.size(), 3)
	assert_false(report.builds.any(func(entry): return entry.build_id == fourth.build_id))


func test_comparison_deltas_expose_honest_axis_consequences() -> void:
	var report := comparison.compare(catalog.initial_builds(snapshot.snapshot_sha))
	assert_false(report.deltas.is_empty())
	for delta in report.deltas:
		assert_true(delta.has("axis_consequences"), str(delta))
		assert_null(delta.axis_consequences.value)
		assert_eq(
			delta.axis_consequences.provenance.kind,
			AchillesTheorycraftProvenance.NOT_MEASURED,
		)


func test_numeric_only_build_warning() -> void:
	var warning := validator.numeric_only_warning(["damage", "shield"], "numeric")
	assert_eq(warning.code, AchillesTheorycraftValidator.NUMERIC_ONLY_CHOICE)


func test_potential_dominance_warning() -> void:
	var warning := validator.strict_dominance_warning(
		"candidate", "reference", {"damage": 5, "range": 3}, {"damage": 4, "range": 3}
	)
	assert_eq(warning.code, AchillesTheorycraftValidator.POTENTIAL_STRICT_DOMINANCE)
	assert_true(validator.strict_dominance_warning(
		"candidate", "reference", {"damage": 5}, {"damage": 4}, true, false
	).is_empty())


func test_guard_loop_warning() -> void:
	var warning := validator.guard_loop_warning("guard", 0.9, false, false)
	assert_eq(warning.code, AchillesTheorycraftValidator.AUTOMATIC_GUARD_LOOP_RISK)


func test_build_assumptions_feed_bounded_validators() -> void:
	var draft := catalog.create_sword_shield_template(snapshot.snapshot_sha)
	draft.assumptions = [{
		"defensive_action_ratio": 0.9,
		"has_risk_window": false,
		"has_opportunity_cost": false,
		"recovery_options": 0,
	}]
	var analysis := analyzer.analyze(draft)
	var warnings: Array = validator.validate_builds([draft], {draft.build_id: analysis})
	var codes: Array = warnings.map(func(warning): return warning.code)
	assert_true(codes.has(AchillesTheorycraftValidator.AUTOMATIC_GUARD_LOOP_RISK))
	assert_true(codes.has(AchillesTheorycraftValidator.NO_RECOVERY_PATH_RISK))
	draft.mark_owner_editable_fields_as_draft()
	assert_eq(
		draft.provenance.assumptions.kind,
		AchillesTheorycraftProvenance.MANUAL_ASSUMPTION,
	)
	for warning in warnings:
		if warning.code in [
			AchillesTheorycraftValidator.AUTOMATIC_GUARD_LOOP_RISK,
			AchillesTheorycraftValidator.NO_RECOVERY_PATH_RISK,
		]:
			assert_eq(
				warning.evidence.input_provenance.kind,
				AchillesTheorycraftProvenance.MANUAL_ASSUMPTION,
			)


func test_kite_risk_warning() -> void:
	var warning := validator.kite_warning("bow", 7, 5, 4, 0)
	assert_eq(warning.code, AchillesTheorycraftValidator.BOW_KITE_RISK)


func test_missing_recovery_warning() -> void:
	var warning := validator.recovery_warning("fragile", 0)
	assert_eq(warning.code, AchillesTheorycraftValidator.NO_RECOVERY_PATH_RISK)


func test_similar_build_warning() -> void:
	var duplicate := AchillesTheorycraftBuild.from_dict(baseline.to_dict())
	duplicate.build_id = "baseline_numeric_variant"
	duplicate.status = AchillesTheorycraftBuild.STATUS_DRAFT
	duplicate.draft_effects = [{"field": "damage", "before": 9, "after": 10}]
	var left := analyzer.analyze(baseline)
	var right := analyzer.analyze(duplicate)
	var warning := validator.similar_build_warning(baseline, duplicate, left, right)
	assert_eq(warning.code, AchillesTheorycraftValidator.LOW_BUILD_DISTINCTION)


func test_current_baseline_uses_real_resources() -> void:
	assert_not_null(baseline)
	assert_eq(baseline.real_resource_refs, SPELL_PATHS)
	assert_true(baseline.action_slots.all(func(action): return action.is_runtime_backed()))
	assert_true(baseline.validation_errors().is_empty(), str(baseline.validation_errors()))
	assert_eq(baseline.ap_budget, snapshot.achilles.max_ap)
	assert_true(baseline.is_runtime_backed())
	assert_false(baseline.is_runtime_loadable())
	assert_false(baseline.to_dict().active_in_game)


func test_sword_shield_template_is_not_runtime_loadable() -> void:
	var build := catalog.create_sword_shield_template(snapshot.snapshot_sha)
	assert_eq(build.status, "DRAFT")
	assert_true(build.design_tags.has("DESIGN_CONCEPT_ONLY"))
	assert_true(build.design_tags.has("NOT_RUNTIME_LOADABLE"))
	assert_false(build.is_runtime_loadable())


func test_bow_template_is_not_runtime_loadable() -> void:
	var build := catalog.create_bow_template(snapshot.snapshot_sha)
	assert_eq(build.status, "DRAFT")
	assert_true(build.design_tags.has("DESIGN_CONCEPT_ONLY"))
	assert_true(build.design_tags.has("NOT_RUNTIME_LOADABLE"))
	assert_false(build.is_runtime_loadable())


func test_templates_contain_no_final_balance_values() -> void:
	for build in [
		catalog.create_sword_shield_template(snapshot.snapshot_sha),
		catalog.create_bow_template(snapshot.snapshot_sha),
	]:
		assert_true(build.real_resource_refs.is_empty())
		for action in build.action_slots:
			for field in ["ap_cost", "range", "area", "mobility", "defense", "control", "recovery", "frequency"]:
				var value: Dictionary = action.get(field)
				assert_null(value.value, "%s/%s" % [action.semantic_id, field])


func test_templates_contain_no_weapon_asset_reference() -> void:
	for path in [
		"res://tools/achilles_theorycraft/templates/sword_shield_concept_template.json",
		"res://tools/achilles_theorycraft/templates/bow_concept_template.json",
	]:
		var content := _text(path).to_lower()
		for extension in [".glb", ".blend", ".fbx", ".png", ".webp"]:
			assert_false(content.contains(extension), path)
		assert_false(content.contains("res://assets/"), path)


func test_gate_a_artifacts_not_loaded_by_runtime() -> void:
	for path in [ODYSSEY, ACHILLES, PROGRESSION, "res://characters/achilles/AchillesIsoUnitView.tscn"]:
		assert_false(_text(path).contains("ACHILLES_3D_SWORD_ODYSSEY_V1"), path)


func test_gate_a_weapon_candidates_not_referenced() -> void:
	for path in [ODYSSEY, ACHILLES, PROGRESSION]:
		var content := _text(path)
		for candidate in ["COMPACT", "REFERENCE", "HEROIC"]:
			assert_false(content.contains(candidate), "%s: %s" % [path, candidate])


func test_lab_scene_is_autonomous_and_has_three_build_slots() -> void:
	var scene := load("res://tools/achilles_theorycraft/AchillesTheorycraftLab.tscn") as PackedScene
	assert_not_null(scene)
	var instance := scene.instantiate()
	add_child_autofree(instance)
	await wait_process_frames(2)
	assert_not_null(instance.get_node("%BuildA"))
	assert_not_null(instance.get_node("%BuildB"))
	assert_not_null(instance.get_node("%BuildC"))
	assert_eq((instance.get_node("%BuildB") as OptionButton).get_item_text(0), "EMPTY")
	assert_eq((instance.get_node("%BuildC") as OptionButton).get_item_text(0), "EMPTY")
	assert_eq((instance.get_node("%ContextSelector") as OptionButton).item_count, 4)


func test_deterministic_exports_repeat_byte_for_byte() -> void:
	var builds := catalog.initial_builds(snapshot.snapshot_sha)
	var report := comparison.compare(builds)
	var root := AchillesTheorycraftStore.EXPORT_ROOT.path_join("gut_determinism")
	var first := store.export_review(report, builds, root)
	assert_true(first.ok, str(first))
	var file_names := ["comparison.json", "comparison.md", "build_a.json", "build_b.json", "build_c.json"]
	var content_before := {}
	for file_name in file_names:
		content_before[file_name] = _text(root.path_join(file_name))
	var second := store.export_review(report, builds, root)
	assert_true(second.ok, str(second))
	assert_eq(first.comparison_sha, second.comparison_sha)
	assert_eq(first.paths.keys().size(), 5)
	for file_name in file_names:
		assert_eq(_text(root.path_join(file_name)), content_before[file_name], file_name)
		assert_true(first.paths.has(file_name), file_name)


func _production_fingerprints() -> Dictionary:
	var paths := [ODYSSEY, ACHILLES, PROGRESSION]
	paths.append_array(SPELL_PATHS)
	paths.append_array(DISCIPLINE_PATHS)
	var result := {}
	for path in paths:
		result[path] = _text(path).sha256_text()
	return result


func _text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var result := file.get_as_text()
	file.close()
	return result


func _files_recursive(root: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root)
	if directory == null:
		return result
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var path := root.path_join(name)
			if directory.current_is_dir():
				result.append_array(_files_recursive(path))
			else:
				result.append(path)
		name = directory.get_next()
	directory.list_dir_end()
	return result


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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


func _git(arguments: Array[String]) -> String:
	return _git_at(ProjectSettings.globalize_path("res://"), arguments)


func _git_at(path: String, arguments: Array[String]) -> String:
	var output: Array = []
	var args := PackedStringArray(["-C", path])
	args.append_array(PackedStringArray(arguments))
	var code := OS.execute("git", args, output, true)
	return str(output[0]).strip_edges() if code == 0 and not output.is_empty() else ""
