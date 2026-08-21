class_name AchillesTheorycraftComparisonService
extends RefCounted

var analyzer: AchillesActionEconomyAnalyzer = AchillesActionEconomyAnalyzer.new()
var validator: AchillesTheorycraftValidator = AchillesTheorycraftValidator.new()


func compare(
		builds: Array[AchillesTheorycraftBuild],
		contexts: Array[TheorycraftContext] = []
	) -> TheorycraftComparisonReport:
	var report := TheorycraftComparisonReport.new()
	var selected: Array[AchillesTheorycraftBuild] = builds.slice(0, 3)
	for build in selected:
		var build_data := build.to_dict()
		report.builds.append({
			"build_id": build.build_id,
			"display_name": build.display_name,
			"status": build.status,
			"source_snapshot_sha": build.source_snapshot_sha,
			"ap_budget": build.ap_budget,
			"runtime_backed": build.is_runtime_backed(),
			"runtime_loadable": false,
			"active_in_game": false,
			"real_resource_refs": build.real_resource_refs.duplicate(),
			"provenance": {
				"build_id": build_data.provenance.build_id,
				"display_name": build_data.provenance.display_name,
				"status": build_data.provenance.status,
				"source_snapshot_sha": build_data.provenance.source_snapshot_sha,
				"ap_budget": build_data.provenance.ap_budget,
				"runtime_backed": build_data.provenance.runtime_backed,
				"runtime_loadable": build_data.provenance.runtime_loadable,
				"active_in_game": build_data.provenance.active_in_game,
				"real_resource_refs": build_data.provenance.real_resource_refs,
			},
		})
	var chosen_contexts: Array[TheorycraftContext] = []
	if contexts.is_empty():
		chosen_contexts.append(TheorycraftContext.abstract_context())
	else:
		for context in contexts:
			chosen_contexts.append(context)
	for context in chosen_contexts:
		report.contexts.append(context.to_dict())
	var analyses := {}
	for build in selected:
		var primary_context: TheorycraftContext = chosen_contexts[0] if chosen_contexts.size() == 1 else null
		var analysis: Dictionary = analyzer.analyze(build, primary_context)
		analyses[build.build_id] = analysis
		report.ap_sequences[build.build_id] = analysis
		report.unused_ap[build.build_id] = analysis.get("unused_ap_histogram", {})
		_apply_axis_metrics(report, build, analysis)
	report.warnings = validator.validate_builds(selected, analyses)
	report.deltas = _deltas(selected)
	for build in selected:
		for axis in ["recovery", "exposure", "reliability"]:
			var reason := "No exact positional battle state or validated context adapter supplied."
			report.not_measured.append({
				"build_id": build.build_id,
				"axis": axis,
				"reason": reason,
				"provenance": AchillesTheorycraftProvenance.not_measured(reason),
			})
	report.provenance = {
		"schema_version": AchillesTheorycraftProvenance.derived(
			"Achilles theorycraft comparison schema"
		),
		"builds": AchillesTheorycraftProvenance.derived(
			"Ordered projection of one to three selected isolated build descriptors"
		),
		"contexts": AchillesTheorycraftProvenance.derived(
			"Ordered serialization of selected TheorycraftContext values"
		),
		"ap_sequences": AchillesTheorycraftProvenance.derived(
			"Per-build AchillesActionEconomyAnalyzer results"
		),
		"unused_ap": AchillesTheorycraftProvenance.derived(
			"Per-build unused_ap_histogram projection; consult each analysis provenance"
		),
		"comparison": AchillesTheorycraftProvenance.derived(
			"Deterministic comparison of at most three isolated builds"
		),
		"warnings": AchillesTheorycraftProvenance.derived(
			"Bounded warning rules; not owner decisions"
		),
		"not_measured": AchillesTheorycraftProvenance.derived(
			"Explicit enumeration of comparison axes lacking validated live-state evidence"
		),
		"deltas": AchillesTheorycraftProvenance.derived(
			"Field-wise deterministic differences from the first selected build"
		),
	}
	for axis in [
		"damage", "mobility", "range", "area", "defense", "control",
		"recovery", "exposure", "reliability", "frequency",
	]:
		report.provenance[axis] = AchillesTheorycraftProvenance.derived(
			"Per-build %s axis values; each value carries its own provenance" % axis
		)
	return report


func _apply_axis_metrics(
		report: TheorycraftComparisonReport,
		build: AchillesTheorycraftBuild,
		analysis: Dictionary
	) -> void:
	var measured: bool = not build.action_slots.is_empty() \
		and build.action_slots.all(func(action): return action.is_runtime_backed())
	if not measured:
		for axis in [
			"damage", "range", "area", "mobility", "defense", "control",
			"recovery", "exposure", "reliability", "frequency",
		]:
			report.get(axis)[build.build_id] = AchillesTheorycraftProvenance.not_measured_value(
				"Concept template intentionally has no final measured values."
			)
		return
	var damage := 0
	var maximum_range := 0
	var area_actions := 0
	var movement_actions := 0
	var defense := 0
	var control := 0
	for action in build.action_slots:
		var spell := load(action.real_spell_resource) as Spell
		if spell == null:
			continue
		damage += spell.damage
		maximum_range = maxi(maximum_range, spell.spell_range)
		if spell.aoe_shape != Spell.AoeShape.SINGLE or spell.aoe_size > 1:
			area_actions += 1
		var movement: Dictionary = action.mobility if action.mobility is Dictionary else {}
		if bool(movement.get("moves_caster_to_target", false)):
			movement_actions += 1
		defense += spell.shield_grant + spell.heal
		control += spell.push_distance + spell.pull_distance + spell.ap_drain
	var sources: Array = build.real_resource_refs.duplicate()
	report.damage[build.build_id] = _derived_value(damage, "Sum of direct spell damage fields", sources)
	report.range[build.build_id] = _derived_value(maximum_range, "Maximum observed spell_range", sources)
	report.area[build.build_id] = _derived_value(area_actions, "Count of non-single area actions", sources)
	report.mobility[build.build_id] = _derived_value(movement_actions, "Count of observed caster-movement actions", sources)
	report.defense[build.build_id] = _derived_value(defense, "Sum of listed shield and heal availability; not per-turn output", sources)
	report.control[build.build_id] = _derived_value(control, "Sum of listed push, pull and AP-drain fields", sources)
	report.frequency[build.build_id] = _derived_value(
		analysis.get("sequence_count"), "Count of abstract ordered AP sequences", sources
	)
	for axis in ["recovery", "exposure", "reliability"]:
		report.get(axis)[build.build_id] = AchillesTheorycraftProvenance.not_measured_value(
			"Requires exact target, map and turn state."
		)


func _derived_value(value: Variant, calculation: String, sources: Array) -> Dictionary:
	return {
		"value": value,
		"provenance": AchillesTheorycraftProvenance.derived(calculation, sources),
	}


func _deltas(builds: Array[AchillesTheorycraftBuild]) -> Array:
	if builds.size() < 2:
		return []
	var baseline: Dictionary = builds[0].to_dict()
	var result: Array = []
	for index in range(1, builds.size()):
		var candidate: Dictionary = builds[index].to_dict()
		for field in [
			"status", "weapon_family", "action_slots", "weapon_mastery",
			"universal_tactic", "divine_influence", "relic_or_card",
			"draft_effects", "assumptions", "design_tags", "author_notes",
		]:
			if AchillesTheorycraftJson.fingerprint(baseline.get(field)) \
					== AchillesTheorycraftJson.fingerprint(candidate.get(field)):
				continue
			result.append({
				"build_id": builds[index].build_id,
				"field": field,
				"before": baseline.get(field),
				"after": candidate.get(field),
				"provenance": candidate.get("provenance", {}).get(
					field, AchillesTheorycraftProvenance.draft()
				),
				"runtime_status": "DRAFT" if builds[index].status != "BASELINE" else "RUNTIME_BASELINE",
				"axis_consequences": AchillesTheorycraftProvenance.not_measured_value(
					"No validated causal model maps this isolated field delta to battle axes."
				),
			})
	result.sort_custom(func(a, b):
		return "%s:%s" % [a.build_id, a.field] < "%s:%s" % [b.build_id, b.field]
	)
	return result
