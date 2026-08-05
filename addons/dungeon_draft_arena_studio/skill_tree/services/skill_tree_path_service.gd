@tool
class_name SkillTreePathService
extends RefCounted


static func final_configurations(
		discipline: DisciplineData,
		limit := 100000
	) -> Array[Array]:
	var result: Array[Array] = []
	if discipline == null or not SkillTreeResolver.validate_discipline(discipline).is_empty():
		return result
	var choice_ranks: Array[int] = []
	var maximum_rank := 1
	for rank_data in _sorted_ranks(discipline):
		maximum_rank = maxi(maximum_rank, rank_data.rank)
		if not rank_data.choices.is_empty():
			choice_ranks.append(rank_data.rank)
	_enumerate(
		discipline,
		choice_ranks,
		0,
		maximum_rank,
		choice_ranks.duplicate(),
		[],
		result,
		maxi(1, limit)
	)
	if choice_ranks.is_empty():
		result.append([])
	return result


static func count_final_configurations(
		discipline: DisciplineData,
		limit := 100000
	) -> int:
	return final_configurations(discipline, limit).size()


static func reachable_node_ids(discipline: DisciplineData) -> Array[StringName]:
	var result: Array[StringName] = []
	for configuration in final_configurations(discipline):
		for node_id_value in configuration:
			var node_id := StringName(node_id_value)
			if not result.has(node_id):
				result.append(node_id)
	return result


static func statistics(discipline: DisciplineData) -> Dictionary:
	var node_count := 0
	var prerequisite_count := 0
	var exclusion_count := 0
	var thresholds := PackedInt32Array()
	for rank_data in _sorted_ranks(discipline):
		thresholds.append(rank_data.required_total_xp)
		for node in rank_data.choices:
			if node == null:
				continue
			node_count += 1
			if node is SkillTreeNodeData:
				prerequisite_count += node.prerequisite_node_ids.size()
				exclusion_count += node.excluded_node_ids.size()
	return {
		"rank_count": discipline.ranks.size() if discipline != null else 0,
		"node_count": node_count,
		"prerequisite_count": prerequisite_count,
		"exclusion_count": exclusion_count,
		"final_configuration_count": count_final_configurations(discipline),
		"thresholds": thresholds,
	}


static func _enumerate(
		discipline: DisciplineData,
		choice_ranks: Array[int],
		index: int,
		reached_rank: int,
		pending_ranks: Array[int],
		selected: Array[StringName],
		result: Array[Array],
		limit: int
	) -> void:
	if result.size() >= limit:
		return
	if index >= choice_ranks.size():
		result.append(selected.duplicate())
		return
	var choice_rank := choice_ranks[index]
	var available := SkillTreeResolver.get_available_nodes(
		discipline,
		choice_rank,
		reached_rank,
		pending_ranks,
		selected
	)
	for node in available:
		var next_selected := selected.duplicate()
		next_selected.append(node.upgrade_id)
		var next_pending := pending_ranks.duplicate()
		next_pending.erase(choice_rank)
		_enumerate(
			discipline,
			choice_ranks,
			index + 1,
			reached_rank,
			next_pending,
			next_selected,
			result,
			limit
		)


static func _sorted_ranks(discipline: DisciplineData) -> Array[DisciplineRankData]:
	var result: Array[DisciplineRankData] = []
	if discipline == null:
		return result
	for rank_data in discipline.ranks:
		if rank_data != null:
			result.append(rank_data)
	result.sort_custom(func(a: DisciplineRankData, b: DisciplineRankData) -> bool:
		return a.rank < b.rank
	)
	return result
