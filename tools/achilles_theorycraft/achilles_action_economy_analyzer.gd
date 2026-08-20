class_name AchillesActionEconomyAnalyzer
extends RefCounted

const ABSTRACT_AP_SEQUENCE := "ABSTRACT_AP_SEQUENCE"
const CONTEXTUALLY_LEGAL_SEQUENCE := "CONTEXTUALLY_LEGAL_SEQUENCE"


func analyze(
		build: AchillesTheorycraftBuild,
		context: TheorycraftContext = null,
		ap_budget_override: Variant = null
	) -> Dictionary:
	if build == null:
		return {"error": "BUILD_REQUIRED"}
	var resolved_budget: Variant = (
		ap_budget_override if ap_budget_override != null else build.ap_budget
	)
	var budget_provenance: Dictionary = (
		AchillesTheorycraftProvenance.assumption(
			"Explicit AP budget override supplied to AchillesActionEconomyAnalyzer"
		)
		if ap_budget_override != null
		else build.provenance.get(
			"ap_budget",
			AchillesTheorycraftProvenance.not_measured(
				"Build carries no resolved Achilles AP budget."
			),
		)
	)
	if resolved_budget == null or int(resolved_budget) <= 0:
		return _unmeasured_analysis(
			build,
			null,
			AchillesTheorycraftProvenance.not_measured(
				"No positive AP budget was resolved from the build or supplied explicitly."
			),
			"AP_BUDGET_NOT_MEASURED",
			"Sequence enumeration requires a positive AP budget.",
		)
	var ap_budget := int(resolved_budget)
	var actions: Dictionary = _resolved_actions(build, ap_budget, context)
	if actions.has("error"):
		return _unmeasured_analysis(
			build, ap_budget, budget_provenance, str(actions.error), str(actions.error)
		)
	var action_list: Array = actions.items
	var raw_sequences: Array = []
	_enumerate(action_list, ap_budget, [], {}, 0, raw_sequences)
	raw_sequences.sort_custom(func(a, b):
		return str(a.key) < str(b.key)
	)
	var sequences: Array = []
	var contextual: Array = []
	var contextual_legality_complete := context != null
	var histogram := {}
	var breakpoints: Array[int] = []
	var repeated_count := 0
	for raw in raw_sequences:
		var legality: Dictionary = _contextual_legality(raw.ids, context)
		if legality.status == AchillesTheorycraftProvenance.NOT_MEASURED:
			contextual_legality_complete = false
		var sequence: Dictionary = {
			"type": ABSTRACT_AP_SEQUENCE,
			"action_ids": raw.ids,
			"ap_spent": raw.ap_spent,
			"unused_ap": ap_budget - raw.ap_spent,
			"contextual_legality": legality,
			"provenance": AchillesTheorycraftProvenance.derived(
				"Ordered sequence enumeration under AP and frequency constraints",
				build.real_resource_refs,
			),
		}
		sequences.append(sequence)
		var histogram_key: String = str(sequence.unused_ap)
		histogram[histogram_key] = int(histogram.get(histogram_key, 0)) + 1
		if not breakpoints.has(sequence.ap_spent):
			breakpoints.append(sequence.ap_spent)
		if raw.ids.size() != _unique(raw.ids).size():
			repeated_count += 1
		if legality.status == "LEGAL":
			var contextual_sequence: Dictionary = sequence.duplicate(true)
			contextual_sequence.type = CONTEXTUALLY_LEGAL_SEQUENCE
			contextual.append(contextual_sequence)
	breakpoints.sort()
	var inclusion_maximal: Array = []
	for sequence in sequences:
		if not _can_append(sequence, action_list, ap_budget):
			inclusion_maximal.append(sequence)
	var max_spent := 0
	for sequence in sequences:
		max_spent = maxi(max_spent, int(sequence.ap_spent))
	var max_ap_sequences: Array = sequences.filter(func(sequence):
		return int(sequence.ap_spent) == max_spent
	)
	var contextual_count: Variant = contextual.size() if contextual_legality_complete else null
	var contextual_sequences: Variant = contextual if contextual_legality_complete else null
	var not_measured: Array = []
	if not contextual_legality_complete:
		not_measured.append("CONTEXTUAL_LEGALITY_NOT_MEASURED")
	var contextual_provenance := (
		AchillesTheorycraftProvenance.derived(
			"Count of sequences whose complete contextual legality result is LEGAL"
		)
		if contextual_legality_complete
		else AchillesTheorycraftProvenance.not_measured(
			"At least one abstract sequence lacks exact target, range or live-state legality."
		)
	)
	return AchillesTheorycraftJson.canonicalize({
		"build_id": build.build_id,
		"source_snapshot_sha": build.source_snapshot_sha,
		"ap_budget": ap_budget,
		"sequence_count": sequences.size(),
		"sequences": sequences,
		"contextually_legal_sequences": contextual_sequences,
		"contextual_sequence_count": contextual_count,
		"unused_ap_histogram": histogram,
		"breakpoints": breakpoints,
		"inclusion_maximal_sequences": inclusion_maximal,
		"inclusion_maximal_count": inclusion_maximal.size(),
		"maximum_ap_spent": max_spent,
		"maximum_ap_sequences": max_ap_sequences,
		"actions_in_all_maximum_ap_sequences": _intersection(max_ap_sequences),
		"repetitive_sequence_count": repeated_count,
		"not_measured": not_measured,
		"provenance": {
			"build_id": AchillesTheorycraftProvenance.derived(
				"Copied from the selected isolated build descriptor"
			),
			"source_snapshot_sha": AchillesTheorycraftProvenance.derived(
				"Copied from the selected isolated build descriptor"
			),
			"ap_budget": budget_provenance,
			"sequence_count": AchillesTheorycraftProvenance.derived(
				"Number of enumerated non-empty abstract AP sequences"
			),
			"sequences": AchillesTheorycraftProvenance.derived(
				"Depth-first ordered enumeration; non-empty prefixes; AP <= budget; frequency limits applied",
				build.real_resource_refs,
			),
			"contextually_legal_sequences": contextual_provenance,
			"contextual_sequence_count": contextual_provenance,
			"unused_ap_histogram": AchillesTheorycraftProvenance.derived(
				"ap_budget - sum(action costs) for each enumerated sequence"
			),
			"breakpoints": AchillesTheorycraftProvenance.derived(
				"Sorted distinct AP totals reached by enumerated sequences"
			),
			"inclusion_maximal_sequences": AchillesTheorycraftProvenance.derived(
				"Sequences to which no action can be appended within AP and frequency limits"
			),
			"inclusion_maximal_count": AchillesTheorycraftProvenance.derived(
				"Size of inclusion_maximal_sequences"
			),
			"maximum_ap_spent": AchillesTheorycraftProvenance.derived(
				"Maximum ap_spent across enumerated sequences"
			),
			"maximum_ap_sequences": AchillesTheorycraftProvenance.derived(
				"Sequences whose ap_spent equals maximum_ap_spent"
			),
			"actions_in_all_maximum_ap_sequences": AchillesTheorycraftProvenance.derived(
				"Set intersection of action IDs in all maximum-AP sequences"
			),
			"repetitive_sequence_count": AchillesTheorycraftProvenance.derived(
				"Count of enumerated sequences containing a repeated action ID"
			),
			"not_measured": AchillesTheorycraftProvenance.derived(
				"Explicit list of analysis fields that remain unmeasured"
			),
		},
	})


func _unmeasured_analysis(
		build: AchillesTheorycraftBuild,
		ap_budget: Variant,
		budget_provenance: Dictionary,
		code: String,
		reason: String
	) -> Dictionary:
	var unmeasured := AchillesTheorycraftProvenance.not_measured(reason)
	var provenance := {
		"build_id": AchillesTheorycraftProvenance.derived(
			"Copied from the selected isolated build descriptor"
		),
		"source_snapshot_sha": AchillesTheorycraftProvenance.derived(
			"Copied from the selected isolated build descriptor"
		),
		"ap_budget": budget_provenance,
		"not_measured": AchillesTheorycraftProvenance.derived(
			"Explicit list of analysis fields that remain unmeasured"
		),
	}
	for field in [
		"sequence_count", "sequences", "contextually_legal_sequences",
		"contextual_sequence_count", "unused_ap_histogram", "breakpoints",
		"inclusion_maximal_sequences", "inclusion_maximal_count",
		"maximum_ap_spent", "maximum_ap_sequences",
		"actions_in_all_maximum_ap_sequences", "repetitive_sequence_count",
	]:
		provenance[field] = unmeasured.duplicate(true)
	return AchillesTheorycraftJson.canonicalize({
		"build_id": build.build_id,
		"source_snapshot_sha": build.source_snapshot_sha,
		"ap_budget": ap_budget,
		"sequence_count": null,
		"sequences": [],
		"contextually_legal_sequences": [],
		"contextual_sequence_count": null,
		"unused_ap_histogram": {},
		"breakpoints": [],
		"inclusion_maximal_sequences": [],
		"inclusion_maximal_count": null,
		"maximum_ap_spent": null,
		"maximum_ap_sequences": [],
		"actions_in_all_maximum_ap_sequences": [],
		"repetitive_sequence_count": null,
		"not_measured": [code],
		"provenance": provenance,
	})


func _resolved_actions(
		build: AchillesTheorycraftBuild,
		ap_budget: int,
		context: TheorycraftContext
	) -> Dictionary:
	var items: Array = []
	for spec in build.action_slots:
		var resolved_cost: Variant = spec.resolved_ap_cost()
		if resolved_cost == null:
			return {"error": "AP cost is NOT_MEASURED for %s" % spec.semantic_id}
		var cost: int = int(resolved_cost)
		if cost <= 0:
			return {"error": "Non-positive AP cost is unsupported for %s" % spec.semantic_id}
		var frequency_data: Dictionary = spec.frequency if spec.frequency is Dictionary else {}
		var max_uses: int = int(ap_budget / cost)
		if bool(frequency_data.get("once_per_activation", false)) \
				or int(frequency_data.get("cooldown_activations", 0)) > 0:
			max_uses = 1
		var combat_limit := int(frequency_data.get("max_uses_per_combat", 0))
		if combat_limit > 0:
			max_uses = mini(max_uses, combat_limit)
		if int(frequency_data.get("initial_cooldown", 0)) > 0:
			max_uses = 0
		if context != null:
			var cooldowns: Dictionary = context.starting_state.get("cooldowns", {})
			if int(cooldowns.get(str(spec.semantic_id), 0)) > 0:
				max_uses = 0
		items.append({
			"id": str(spec.semantic_id),
			"cost": cost,
			"max_uses": max_uses,
		})
	items.sort_custom(func(a, b): return str(a.id) < str(b.id))
	return {"items": items}


func _enumerate(
		actions: Array,
		ap_budget: int,
		prefix: Array,
		counts: Dictionary,
		spent: int,
		output: Array
	) -> void:
	for action in actions:
		var used := int(counts.get(action.id, 0))
		if used >= int(action.max_uses) or spent + int(action.cost) > ap_budget:
			continue
		var next_prefix: Array = prefix.duplicate()
		next_prefix.append(str(action.id))
		var next_counts: Dictionary = counts.duplicate()
		next_counts[action.id] = used + 1
		var next_spent: int = spent + int(action.cost)
		output.append({
			"ids": next_prefix,
			"ap_spent": next_spent,
			"key": ">".join(PackedStringArray(next_prefix)),
		})
		_enumerate(actions, ap_budget, next_prefix, next_counts, next_spent, output)


func _can_append(sequence: Dictionary, actions: Array, ap_budget: int) -> bool:
	var counts := {}
	for action_id in sequence.action_ids:
		counts[action_id] = int(counts.get(action_id, 0)) + 1
	for action in actions:
		if int(counts.get(action.id, 0)) < int(action.max_uses) \
				and int(sequence.ap_spent) + int(action.cost) <= ap_budget:
			return true
	return false


func _contextual_legality(ids: Array, context: TheorycraftContext) -> Dictionary:
	if context == null or context.context_id == "abstract":
		return {
			"status": AchillesTheorycraftProvenance.NOT_MEASURED,
			"provenance": AchillesTheorycraftProvenance.not_measured(
				"Abstract AP legality does not prove target, range or state legality."
			),
		}
	var key: String = ">".join(PackedStringArray(ids))
	var explicit: Dictionary = context.starting_state.get("sequence_legality", {})
	if explicit.has(key):
		return {
			"status": "LEGAL" if bool(explicit[key]) else "ILLEGAL",
			"provenance": AchillesTheorycraftProvenance.observed(
				"TheorycraftContext.starting_state.sequence_legality[%s]" % key
			),
		}
	var legal_actions: Array = context.starting_state.get("legal_action_ids", [])
	if not legal_actions.is_empty():
		var legal: bool = true
		for action_id in ids:
			if not legal_actions.has(action_id) and not legal_actions.has(StringName(action_id)):
				legal = false
				break
		return {
			"status": "LEGAL" if legal else "ILLEGAL",
			"provenance": AchillesTheorycraftProvenance.assumption(
				"Manual context action whitelist; inter-action state transitions are not simulated."
			),
		}
	return {
		"status": AchillesTheorycraftProvenance.NOT_MEASURED,
		"provenance": AchillesTheorycraftProvenance.not_measured(
			"No exact target/range/state legality adapter supplied for this room context."
		),
	}


func _intersection(sequences: Array) -> Array:
	if sequences.is_empty():
		return []
	var common: Array = _unique(sequences[0].action_ids)
	for sequence in sequences.slice(1):
		common = common.filter(func(action_id): return sequence.action_ids.has(action_id))
	common.sort()
	return common


func _unique(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if not result.has(value):
			result.append(value)
	return result
