class_name SkillTreeResolver
extends RefCounted

enum RejectionReason {
	NONE,
	INVALID_DISCIPLINE,
	INVALID_NODE,
	WRONG_RANK,
	RANK_NOT_REACHED,
	RANK_NOT_PENDING,
	EARLIER_RANK_PENDING,
	RANK_ALREADY_SELECTED,
	MISSING_PREREQUISITE,
	EXCLUDED_BY_SELECTION,
	INVALID_TREE_DATA,
}


static func get_available_nodes(
		discipline: DisciplineData,
		choice_rank: int,
		reached_rank: int,
		pending_ranks: Array[int],
		selected_node_ids: Array[StringName]
	) -> Array[SkillUpgradeData]:
	var available: Array[SkillUpgradeData] = []
	var rank_data := _get_rank_data(discipline, choice_rank)
	if rank_data == null:
		return available
	for choice in rank_data.choices:
		if choice == null:
			continue
		var decision := evaluate_selection(
			discipline,
			choice_rank,
			choice.upgrade_id,
			reached_rank,
			pending_ranks,
			selected_node_ids
		)
		if decision.get("allowed", false):
			available.append(choice)
	return available


static func evaluate_selection(
		discipline: DisciplineData,
		choice_rank: int,
		node_id: StringName,
		reached_rank: int,
		pending_ranks: Array[int],
		selected_node_ids: Array[StringName]
	) -> Dictionary:
	var empty_ids: Array[StringName] = []
	if discipline == null or discipline.discipline_id == &"":
		return _decision(
			false,
			RejectionReason.INVALID_DISCIPLINE,
			null,
			empty_ids,
			empty_ids
		)
	if node_id == &"":
		return _decision(
			false,
			RejectionReason.INVALID_NODE,
			null,
			empty_ids,
			empty_ids
		)

	var diagnostics := validate_discipline(discipline)
	if not diagnostics.is_empty():
		return _decision(
			false,
			RejectionReason.INVALID_TREE_DATA,
			null,
			empty_ids,
			empty_ids
		)

	var node := _find_node(discipline, node_id)
	if node == null:
		return _decision(
			false,
			RejectionReason.INVALID_NODE,
			null,
			empty_ids,
			empty_ids
		)
	if node.rank != choice_rank:
		return _decision(
			false,
			RejectionReason.WRONG_RANK,
			node,
			empty_ids,
			empty_ids
		)
	if choice_rank > reached_rank:
		return _decision(
			false,
			RejectionReason.RANK_NOT_REACHED,
			node,
			empty_ids,
			empty_ids
		)
	if _has_selected_node_for_rank(
			discipline,
			choice_rank,
			selected_node_ids
		):
		return _decision(
			false,
			RejectionReason.RANK_ALREADY_SELECTED,
			node,
			empty_ids,
			empty_ids
		)
	if not pending_ranks.has(choice_rank):
		return _decision(
			false,
			RejectionReason.RANK_NOT_PENDING,
			node,
			empty_ids,
			empty_ids
		)
	for pending_rank in pending_ranks:
		if pending_rank < choice_rank:
			return _decision(
				false,
				RejectionReason.EARLIER_RANK_PENDING,
				node,
				empty_ids,
				empty_ids
			)

	var missing_prerequisites: Array[StringName] = []
	for prerequisite_id in _get_prerequisite_ids(node):
		if not selected_node_ids.has(prerequisite_id):
			missing_prerequisites.append(prerequisite_id)
	if not missing_prerequisites.is_empty():
		return _decision(
			false,
			RejectionReason.MISSING_PREREQUISITE,
			node,
			missing_prerequisites,
			empty_ids
		)

	var conflicting_node_ids: Array[StringName] = []
	var direct_exclusions := _get_excluded_ids(node)
	for selected_id in selected_node_ids:
		if direct_exclusions.has(selected_id) \
				and not conflicting_node_ids.has(selected_id):
			conflicting_node_ids.append(selected_id)
		var selected_node := _find_node(discipline, selected_id)
		if selected_node != null \
				and _get_excluded_ids(selected_node).has(node_id) \
				and not conflicting_node_ids.has(selected_id):
			conflicting_node_ids.append(selected_id)
	if not conflicting_node_ids.is_empty():
		return _decision(
			false,
			RejectionReason.EXCLUDED_BY_SELECTION,
			node,
			empty_ids,
			conflicting_node_ids
		)

	return _decision(
		true,
		RejectionReason.NONE,
		node,
		empty_ids,
		empty_ids
	)


static func validate_discipline(
		discipline: DisciplineData
	) -> PackedStringArray:
	var diagnostics: Array[String] = []
	if discipline == null:
		diagnostics.append("INVALID_DISCIPLINE: discipline is null")
		return PackedStringArray(diagnostics)
	if discipline.discipline_id == &"":
		diagnostics.append("INVALID_DISCIPLINE: discipline_id is empty")

	var sorted_ranks := _get_sorted_ranks(discipline)
	var rank_numbers := {}
	var previous_rank := -1
	var previous_threshold := -1
	var nodes_by_id := {}
	var node_ranks := {}
	if not sorted_ranks.is_empty() and sorted_ranks[0].rank > 1:
		# Les anciennes donnees peuvent ne declarer que le rang 2 : le rang 1
		# initial a 0 XP reste alors implicite. Un premier rang 3+ revele en
		# revanche un trou reel dans la progression.
		previous_rank = 1
		previous_threshold = 0

	for rank_data in sorted_ranks:
		if rank_numbers.has(rank_data.rank):
			_append_diagnostic(
				diagnostics,
				"DUPLICATE_RANK: %d" % rank_data.rank
			)
		else:
			if previous_rank >= 0 and rank_data.rank != previous_rank + 1:
				_append_diagnostic(
					diagnostics,
					"NON_CONTIGUOUS_RANKS: expected %d, found %d" % [
						previous_rank + 1,
						rank_data.rank,
					]
				)
			if previous_rank >= 0 \
					and rank_data.required_total_xp <= previous_threshold:
				_append_diagnostic(
					diagnostics,
					"NON_INCREASING_XP_THRESHOLD: rank %d has %d after %d" % [
						rank_data.rank,
						rank_data.required_total_xp,
						previous_threshold,
					]
				)
			rank_numbers[rank_data.rank] = true
			previous_rank = rank_data.rank
			previous_threshold = rank_data.required_total_xp

		for choice in rank_data.choices:
			if choice == null:
				_append_diagnostic(
					diagnostics,
					"NULL_CHOICE: rank %d" % rank_data.rank
				)
				continue
			if choice.upgrade_id == &"":
				_append_diagnostic(
					diagnostics,
					"EMPTY_UPGRADE_ID: rank %d" % rank_data.rank
				)
				continue
			if nodes_by_id.has(choice.upgrade_id):
				_append_diagnostic(
					diagnostics,
					"DUPLICATE_UPGRADE_ID: %s" % choice.upgrade_id
				)
			else:
				nodes_by_id[choice.upgrade_id] = choice
				node_ranks[choice.upgrade_id] = rank_data.rank
			if choice.discipline_id != discipline.discipline_id:
				_append_diagnostic(
					diagnostics,
					"DISCIPLINE_MISMATCH: %s declares %s instead of %s" % [
						choice.upgrade_id,
						choice.discipline_id,
						discipline.discipline_id,
					]
				)
			if choice.rank != rank_data.rank:
				_append_diagnostic(
					diagnostics,
					"RANK_MISMATCH: %s declares %d instead of %d" % [
						choice.upgrade_id,
						choice.rank,
						rank_data.rank,
					]
				)

	for node_id_value in nodes_by_id:
		var node_id := StringName(node_id_value)
		var node := nodes_by_id[node_id] as SkillUpgradeData
		var node_rank: int = node_ranks[node_id]
		for prerequisite_id in _get_prerequisite_ids(node):
			if prerequisite_id == node_id:
				_append_diagnostic(
					diagnostics,
					"SELF_PREREQUISITE: %s" % node_id
				)
				continue
			if not nodes_by_id.has(prerequisite_id):
				_append_diagnostic(
					diagnostics,
					"UNKNOWN_PREREQUISITE: %s -> %s" % [
						node_id,
						prerequisite_id,
					]
				)
				continue
			var prerequisite_rank: int = node_ranks[prerequisite_id]
			if prerequisite_rank >= node_rank:
				_append_diagnostic(
					diagnostics,
					"PREREQUISITE_NOT_IN_LOWER_RANK: %s -> %s" % [
						node_id,
						prerequisite_id,
					]
				)
		for excluded_id in _get_excluded_ids(node):
			if excluded_id == node_id:
				_append_diagnostic(
					diagnostics,
					"SELF_EXCLUSION: %s" % node_id
				)
				continue
			if not nodes_by_id.has(excluded_id):
				_append_diagnostic(
					diagnostics,
					"UNKNOWN_EXCLUSION: %s -> %s" % [
						node_id,
						excluded_id,
					]
				)

	var visit_states := {}
	for node_id_value in nodes_by_id:
		var node_id := StringName(node_id_value)
		if int(visit_states.get(node_id, 0)) == 0:
			_visit_prerequisites(
				node_id,
				nodes_by_id,
				visit_states,
				diagnostics,
				[]
			)
	return PackedStringArray(diagnostics)


static func _decision(
		allowed: bool,
		reason: RejectionReason,
		node: SkillUpgradeData,
		missing_prerequisites: Array[StringName],
		conflicting_node_ids: Array[StringName]
	) -> Dictionary:
	return {
		"allowed": allowed,
		"reason": reason,
		"node": node,
		"missing_prerequisites": missing_prerequisites.duplicate(),
		"conflicting_node_ids": conflicting_node_ids.duplicate(),
	}


static func _get_sorted_ranks(
		discipline: DisciplineData
	) -> Array[DisciplineRankData]:
	var sorted: Array[DisciplineRankData] = []
	if discipline == null:
		return sorted
	for rank_data in discipline.ranks:
		if rank_data != null:
			sorted.append(rank_data)
	sorted.sort_custom(
		func(a: DisciplineRankData, b: DisciplineRankData):
			return a.rank < b.rank
	)
	return sorted


static func _get_rank_data(
		discipline: DisciplineData,
		wanted_rank: int
	) -> DisciplineRankData:
	if discipline == null:
		return null
	for rank_data in discipline.ranks:
		if rank_data != null and rank_data.rank == wanted_rank:
			return rank_data
	return null


static func _find_node(
		discipline: DisciplineData,
		node_id: StringName
	) -> SkillUpgradeData:
	if discipline == null or node_id == &"":
		return null
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		for choice in rank_data.choices:
			if choice != null and choice.upgrade_id == node_id:
				return choice
	return null


static func _has_selected_node_for_rank(
		discipline: DisciplineData,
		wanted_rank: int,
		selected_node_ids: Array[StringName]
	) -> bool:
	for selected_id in selected_node_ids:
		var selected_node := _find_node(discipline, selected_id)
		if selected_node != null and selected_node.rank == wanted_rank:
			return true
	return false


static func _get_prerequisite_ids(
		node: SkillUpgradeData
	) -> Array[StringName]:
	if node is SkillTreeNodeData:
		return (node as SkillTreeNodeData).prerequisite_node_ids.duplicate()
	var empty: Array[StringName] = []
	return empty


static func _get_excluded_ids(
		node: SkillUpgradeData
	) -> Array[StringName]:
	if node is SkillTreeNodeData:
		return (node as SkillTreeNodeData).excluded_node_ids.duplicate()
	var empty: Array[StringName] = []
	return empty


static func _visit_prerequisites(
		node_id: StringName,
		nodes_by_id: Dictionary,
		visit_states: Dictionary,
		diagnostics: Array[String],
		stack: Array[StringName]
	) -> void:
	visit_states[node_id] = 1
	stack.append(node_id)
	var node := nodes_by_id[node_id] as SkillUpgradeData
	for prerequisite_id in _get_prerequisite_ids(node):
		if not nodes_by_id.has(prerequisite_id):
			continue
		var prerequisite_state := int(visit_states.get(prerequisite_id, 0))
		if prerequisite_state == 1:
			_append_diagnostic(
				diagnostics,
				"PREREQUISITE_CYCLE: %s -> %s" % [
					" -> ".join(stack),
					prerequisite_id,
				]
			)
		elif prerequisite_state == 0:
			_visit_prerequisites(
				prerequisite_id,
				nodes_by_id,
				visit_states,
				diagnostics,
				stack
			)
	stack.pop_back()
	visit_states[node_id] = 2


static func _append_diagnostic(
		diagnostics: Array[String],
		diagnostic: String
	) -> void:
	if not diagnostics.has(diagnostic):
		diagnostics.append(diagnostic)
