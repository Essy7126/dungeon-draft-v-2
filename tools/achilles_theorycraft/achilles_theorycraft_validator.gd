class_name AchillesTheorycraftValidator
extends RefCounted

const POTENTIAL_STRICT_DOMINANCE := "POTENTIAL_STRICT_DOMINANCE"
const NUMERIC_ONLY_CHOICE := "NUMERIC_ONLY_CHOICE"
const DEAD_AP_RISK := "DEAD_AP_RISK"
const AUTOMATIC_GUARD_LOOP_RISK := "AUTOMATIC_GUARD_LOOP_RISK"
const BOW_KITE_RISK := "BOW_KITE_RISK"
const NO_RECOVERY_PATH_RISK := "NO_RECOVERY_PATH_RISK"
const LOW_BUILD_DISTINCTION := "LOW_BUILD_DISTINCTION"
const REPETITIVE_SEQUENCE_RISK := "REPETITIVE_SEQUENCE_RISK"

const NUMERIC_FIELDS := ["damage", "hp", "max_hp", "shield", "armor", "armure"]
const STRUCTURAL_FIELDS := [
	"geometry", "area", "target", "targeting", "timing", "mobility",
	"reaction", "risk", "frequency", "range", "conditions",
]


func validate_builds(builds: Array, analyses: Dictionary) -> Array:
	var warnings: Array = []
	for build in builds:
		var analysis: Dictionary = analyses.get(build.build_id, {})
		var maximal: Array = analysis.get("inclusion_maximal_sequences", [])
		if not maximal.is_empty():
			var dead_count := maximal.filter(func(sequence):
				return int(sequence.get("unused_ap", 0)) > 1
			).size()
			if float(dead_count) / float(maximal.size()) >= 0.5:
				warnings.append(_warning(
					DEAD_AP_RISK,
					"At least half of inclusion-maximal abstract sequences leave more than one AP.",
					{"build_id": build.build_id, "count": dead_count, "total": maximal.size()},
				))
		var repetitive_count: Variant = analysis.get("repetitive_sequence_count")
		if repetitive_count != null and int(repetitive_count) > 0:
			warnings.append(_warning(
				REPETITIVE_SEQUENCE_RISK,
				"The abstract enumerator contains repeated-action sequences.",
				{"build_id": build.build_id, "count": repetitive_count},
			))
		var changed_fields: Array[String] = []
		for effect in build.draft_effects:
			if effect is Dictionary:
				changed_fields.append(str(effect.get("field", "")))
		var numeric: Dictionary = numeric_only_warning(changed_fields, build.build_id)
		if not numeric.is_empty():
			warnings.append(numeric)
		var assumptions := _assumption_map(build)
		if assumptions.has("defensive_action_ratio") \
				and assumptions.has("has_risk_window") \
				and assumptions.has("has_opportunity_cost"):
			var guard := guard_loop_warning(
				build.build_id,
				assumptions.defensive_action_ratio,
				assumptions.has_risk_window,
				assumptions.has_opportunity_cost,
			)
			if not guard.is_empty():
				warnings.append(guard)
		if assumptions.has("maximum_range") and assumptions.has("mobility") \
				and assumptions.has("enemy_mobility") and assumptions.has("zone_pressure"):
			var kite := kite_warning(
				build.build_id,
				assumptions.maximum_range,
				assumptions.mobility,
				assumptions.enemy_mobility,
				assumptions.zone_pressure,
			)
			if not kite.is_empty():
				warnings.append(kite)
		if assumptions.has("recovery_options"):
			var recovery := recovery_warning(build.build_id, assumptions.recovery_options)
			if not recovery.is_empty():
				warnings.append(recovery)
	for left_index in range(builds.size()):
		for right_index in range(left_index + 1, builds.size()):
			var similar: Dictionary = similar_build_warning(
				builds[left_index], builds[right_index],
				analyses.get(builds[left_index].build_id, {}),
				analyses.get(builds[right_index].build_id, {}),
			)
			if not similar.is_empty():
				warnings.append(similar)
			var left_assumptions := _assumption_map(builds[left_index])
			var right_assumptions := _assumption_map(builds[right_index])
			if left_assumptions.get("normalized_axes") is Dictionary \
					and right_assumptions.get("normalized_axes") is Dictionary:
				var dominance := strict_dominance_warning(
					builds[left_index].build_id,
					builds[right_index].build_id,
					left_assumptions.normalized_axes,
					right_assumptions.normalized_axes,
					bool(left_assumptions.get("has_extra_condition", false)),
					bool(left_assumptions.get("has_extra_cost", false)),
				)
				if not dominance.is_empty():
					warnings.append(dominance)
	return _sort_warnings(warnings)


func numeric_only_warning(changed_fields: Array[String], build_id := "") -> Dictionary:
	var fields: Array = changed_fields.filter(func(field): return not field.is_empty())
	if fields.is_empty():
		return {}
	var has_numeric: bool = fields.any(func(field): return field in NUMERIC_FIELDS)
	var has_structural: bool = fields.any(func(field): return field in STRUCTURAL_FIELDS)
	if has_numeric and not has_structural and fields.all(func(field): return field in NUMERIC_FIELDS):
		return _warning(
			NUMERIC_ONLY_CHOICE,
			"Draft changes only numeric durability or output fields and no structural axis.",
			{"build_id": build_id, "changed_fields": fields},
		)
	return {}


func strict_dominance_warning(
		candidate_id: String,
		reference_id: String,
		candidate_axes: Dictionary,
		reference_axes: Dictionary,
		has_extra_condition := false,
		has_extra_cost := false
	) -> Dictionary:
	if has_extra_condition or has_extra_cost:
		return {}
	var measured := 0
	var strictly_better := false
	for axis in reference_axes.keys():
		if not candidate_axes.has(axis):
			continue
		var candidate: Variant = _numeric_value(candidate_axes[axis])
		var reference: Variant = _numeric_value(reference_axes[axis])
		if candidate == null or reference == null:
			continue
		measured += 1
		if float(candidate) < float(reference):
			return {}
		if float(candidate) > float(reference):
			strictly_better = true
	if measured > 0 and strictly_better:
		return _warning(
			POTENTIAL_STRICT_DOMINANCE,
			"Candidate is at least equal on every measured axis and better on one, without recorded extra condition or cost.",
			{
				"candidate": candidate_id,
				"reference": reference_id,
				"measured_axes": measured,
				"input_provenance": AchillesTheorycraftProvenance.assumption(
					"Normalized comparison axes supplied to the bounded validator."
				),
			},
		)
	return {}


func guard_loop_warning(
		build_id: String,
		defensive_action_ratio: Variant,
		has_risk_window: Variant,
		has_opportunity_cost: Variant
	) -> Dictionary:
	if defensive_action_ratio == null or has_risk_window == null \
			or has_opportunity_cost == null:
		return {}
	if float(defensive_action_ratio) >= 0.8 \
			and not bool(has_risk_window) and not bool(has_opportunity_cost):
		return _warning(
			AUTOMATIC_GUARD_LOOP_RISK,
			"A defensive option appears in at least 80% of plausible activations without measured risk window or opportunity cost.",
			{
				"build_id": build_id,
				"ratio": defensive_action_ratio,
				"input_provenance": AchillesTheorycraftProvenance.assumption(
					"Guard frequency, risk window and opportunity cost are manual theorycraft inputs."
				),
			},
		)
	return {}


func kite_warning(
		build_id: String,
		maximum_range: Variant,
		mobility: Variant,
		enemy_mobility: Variant,
		zone_pressure: Variant
	) -> Dictionary:
	if [maximum_range, mobility, enemy_mobility, zone_pressure].any(func(value):
		return value == null
	):
		return {}
	if float(maximum_range) > float(enemy_mobility) \
			and float(mobility) >= float(enemy_mobility) \
			and float(zone_pressure) <= 0.0:
		return _warning(
			BOW_KITE_RISK,
			"Measured range and mobility may deny slower enemies turns when zone pressure is absent.",
			{
				"build_id": build_id,
				"input_provenance": AchillesTheorycraftProvenance.assumption(
					"Range, mobility and zone-pressure fixture inputs are not live battle measurements."
				),
			},
		)
	return {}


func recovery_warning(build_id: String, recovery_options: Variant) -> Dictionary:
	if recovery_options == null:
		return {}
	if int(recovery_options) <= 0:
		return _warning(
			NO_RECOVERY_PATH_RISK,
			"No credible measured return option follows a positioning error.",
			{
				"build_id": build_id,
				"input_provenance": AchillesTheorycraftProvenance.assumption(
					"Recovery-option count is a manual bounded-validator input."
				),
			},
		)
	return {}


func similar_build_warning(
		build_a: AchillesTheorycraftBuild,
		build_b: AchillesTheorycraftBuild,
		analysis_a: Dictionary,
		analysis_b: Dictionary
	) -> Dictionary:
	var ids_a: Array = build_a.action_slots.map(func(action): return str(action.semantic_id))
	var ids_b: Array = build_b.action_slots.map(func(action): return str(action.semantic_id))
	ids_a.sort()
	ids_b.sort()
	if ids_a != ids_b:
		return {}
	var sequences_a: Array[String] = _sequence_keys(analysis_a)
	var sequences_b: Array[String] = _sequence_keys(analysis_b)
	if sequences_a != sequences_b:
		return {}
	var changes: Array[String] = []
	for effect in build_b.draft_effects:
		if effect is Dictionary:
			changes.append(str(effect.get("field", "")))
	if not changes.is_empty() and not changes.all(func(field): return field in NUMERIC_FIELDS):
		return {}
	return _warning(
		LOW_BUILD_DISTINCTION,
		"Builds use the same actions and abstract sequences; no structural distinction is recorded.",
		{"build_a": build_a.build_id, "build_b": build_b.build_id},
	)


func _sequence_keys(analysis: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for sequence in analysis.get("sequences", []):
		keys.append(">".join(PackedStringArray(sequence.get("action_ids", []))))
	keys.sort()
	return keys


func _assumption_map(build: AchillesTheorycraftBuild) -> Dictionary:
	var result := {}
	for entry in build.assumptions:
		if entry is Dictionary:
			for key in entry.keys():
				if str(key).begins_with("_") or str(key) == "provenance":
					continue
				result[key] = entry[key]
	if not result.is_empty():
		result["_provenance"] = AchillesTheorycraftProvenance.assumption(
			"Owner-editable build assumptions"
		)
	return result


func _numeric_value(value: Variant) -> Variant:
	if value is int or value is float:
		return value
	if value is Dictionary:
		var resolved: Variant = value.get("value")
		return resolved if resolved is int or resolved is float else null
	return null


func _warning(code: String, message: String, evidence: Dictionary) -> Dictionary:
	return {
		"code": code,
		"level": "WARNING",
		"message": message,
		"evidence": evidence,
		"scope": "CONTEXT_BOUNDED_REVIEW_SIGNAL",
		"provenance": AchillesTheorycraftProvenance.derived(
			"Bounded theorycraft validator rule; warning, not design verdict"
		),
	}


func _sort_warnings(warnings: Array) -> Array:
	warnings.sort_custom(func(a, b):
		var left: String = "%s:%s" % [a.get("code", ""), AchillesTheorycraftJson.stringify(a.get("evidence", {}))]
		var right: String = "%s:%s" % [b.get("code", ""), AchillesTheorycraftJson.stringify(b.get("evidence", {}))]
		return left < right
	)
	return warnings
