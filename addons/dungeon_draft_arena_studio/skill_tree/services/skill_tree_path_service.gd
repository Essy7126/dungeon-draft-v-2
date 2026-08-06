@tool
class_name SkillTreePathService
extends RefCounted


static func final_configurations(
		discipline: DisciplineData,
		limit := 100000
	) -> Array[Array]:
	return enumeration_result(discipline, limit).get("configurations", []) as Array[Array]


static func enumeration_result(
		discipline: DisciplineData,
		limit := 100000,
		include_configurations := true
	) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result: Array[Array] = []
	if discipline == null or not SkillTreeResolver.validate_discipline(discipline).is_empty():
		return {
			"count": 0,
			"limit": maxi(1, limit),
			"truncated": false,
			"complete": true,
			"configurations": result,
			"duration_usec": Time.get_ticks_usec() - started,
			"stop_reason": "INVALID_DISCIPLINE",
		}
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
		maxi(1, limit) + 1
	)
	if choice_ranks.is_empty():
		result.append([])
	var truncated := result.size() > maxi(1, limit)
	if truncated:
		result.resize(maxi(1, limit))
	return {
		"count": result.size(),
		"limit": maxi(1, limit),
		"truncated": truncated,
		"complete": not truncated,
		"configurations": result if include_configurations else [],
		"duration_usec": Time.get_ticks_usec() - started,
		"stop_reason": "LIMIT_REACHED" if truncated else "COMPLETE",
	}


static func count_final_configurations(
		discipline: DisciplineData,
		limit := 100000
	) -> int:
	return final_configurations(discipline, limit).size()


static func reachable_node_ids(discipline: DisciplineData) -> Array[StringName]:
	return reachability_analysis(discipline).get("reachable_node_ids", []) \
		as Array[StringName]


static func reachability_analysis(discipline: DisciplineData) -> Dictionary:
	var started := Time.get_ticks_usec()
	var reachable: Array[StringName] = []
	var blocked: Array[StringName] = []
	var impossible: Array[StringName] = []
	var dead_ranks: Array[int] = []
	if discipline == null or not SkillTreeResolver.validate_discipline(discipline).is_empty():
		return {
			"reachable_node_ids": reachable,
			"blocked_node_ids": blocked,
			"impossible_node_ids": impossible,
			"dead_ranks": dead_ranks,
			"duration_usec": Time.get_ticks_usec() - started,
			"complete": false,
		}
	for rank_data in _sorted_ranks(discipline):
		if rank_data.choices.is_empty():
			continue
		var rank_reachable := false
		for node in rank_data.choices:
			if node == null:
				continue
			var path := _first_path_to_node(discipline, node)
			if not path.is_empty():
				reachable.append(node.upgrade_id)
				rank_reachable = true
			elif node is SkillTreeNodeData \
					and not node.prerequisite_node_ids.is_empty():
				blocked.append(node.upgrade_id)
			else:
				impossible.append(node.upgrade_id)
		if not rank_reachable:
			dead_ranks.append(rank_data.rank)
	return {
		"reachable_node_ids": reachable,
		"blocked_node_ids": blocked,
		"impossible_node_ids": impossible,
		"dead_ranks": dead_ranks,
		"duration_usec": Time.get_ticks_usec() - started,
		"complete": true,
	}


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
		"enumeration": enumeration_result(discipline, 100000, false),
		"reachability": reachability_analysis(discipline),
		"thresholds": thresholds,
	}


static func _first_path_to_node(
		discipline: DisciplineData,
		target: SkillUpgradeData
	) -> Array[StringName]:
	var choice_ranks: Array[int] = []
	for rank_data in _sorted_ranks(discipline):
		if rank_data.rank <= target.rank and not rank_data.choices.is_empty():
			choice_ranks.append(rank_data.rank)
	var pending := choice_ranks.duplicate()
	var memo := {}
	return _search_prefix(
		discipline, target, choice_ranks, 0, pending, [], memo
	)


static func _search_prefix(
		discipline: DisciplineData,
		target: SkillUpgradeData,
		choice_ranks: Array[int],
		index: int,
		pending: Array[int],
		selected: Array[StringName],
		memo: Dictionary
	) -> Array[StringName]:
	if index >= choice_ranks.size():
		return selected.duplicate() if selected.has(target.upgrade_id) else []
	var memo_ids := selected.duplicate()
	memo_ids.sort()
	var memo_key := "%d|%s" % [index, ",".join(memo_ids)]
	if memo.has(memo_key):
		return []
	memo[memo_key] = true
	var rank_number := choice_ranks[index]
	var candidates := SkillTreeResolver.get_available_nodes(
		discipline, rank_number, target.rank, pending, selected
	)
	if rank_number == target.rank:
		candidates = candidates.filter(func(node: SkillUpgradeData) -> bool:
			return node == target
		)
	for candidate in candidates:
		var next_selected := selected.duplicate()
		next_selected.append(candidate.upgrade_id)
		var next_pending := pending.duplicate()
		next_pending.erase(rank_number)
		var found := _search_prefix(
			discipline, target, choice_ranks, index + 1,
			next_pending, next_selected, memo
		)
		if not found.is_empty():
			return found
	return []


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
