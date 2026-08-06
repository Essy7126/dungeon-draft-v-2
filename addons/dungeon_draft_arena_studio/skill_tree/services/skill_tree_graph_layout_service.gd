@tool
class_name SkillTreeGraphLayoutService
extends RefCounted


static func layered_positions(
		discipline: DisciplineData,
		card_sizes: Dictionary = {},
		pinned_positions: Dictionary = {},
		only_node_ids: Array[StringName] = []
	) -> Dictionary:
	var result := {}
	if discipline == null:
		return result
	var ordered_by_rank := {}
	var ranks: Array[DisciplineRankData] = []
	for rank_data in discipline.ranks:
		if rank_data != null:
			ranks.append(rank_data)
	ranks.sort_custom(func(a: DisciplineRankData, b: DisciplineRankData):
		return a.rank < b.rank
	)
	for rank_data in ranks:
		var nodes: Array[SkillUpgradeData] = []
		for node in rank_data.choices:
			if node != null:
				nodes.append(node)
		nodes.sort_custom(func(a: SkillUpgradeData, b: SkillUpgradeData) -> bool:
			var a_score := _parent_barycenter(a, result)
			var b_score := _parent_barycenter(b, result)
			if not is_equal_approx(a_score, b_score):
				return a_score < b_score
			return str(a.upgrade_id) < str(b.upgrade_id)
		)
		ordered_by_rank[rank_data.rank] = nodes
		var y := 32.0
		for node in nodes:
			var id_text := str(node.upgrade_id)
			if pinned_positions.has(id_text):
				result[id_text] = pinned_positions[id_text]
				y = maxf(y, (pinned_positions[id_text] as Vector2).y + _card_size(node, card_sizes).y + 28.0)
				continue
			if not only_node_ids.is_empty() and not only_node_ids.has(node.upgrade_id):
				continue
			var size := _card_size(node, card_sizes)
			result[id_text] = Vector2(32.0 + float(node.rank - 1) * 320.0, y)
			y += size.y + 28.0
	return result


static func _parent_barycenter(node: SkillUpgradeData, positions: Dictionary) -> float:
	if not node is SkillTreeNodeData or node.prerequisite_node_ids.is_empty():
		return 0.0
	var total := 0.0
	var count := 0
	for prerequisite_id in node.prerequisite_node_ids:
		if positions.has(str(prerequisite_id)):
			total += (positions[str(prerequisite_id)] as Vector2).y
			count += 1
	return total / float(count) if count > 0 else 0.0


static func _card_size(node: SkillUpgradeData, sizes: Dictionary) -> Vector2:
	var value: Variant = sizes.get(str(node.upgrade_id))
	return value as Vector2 if value is Vector2 else Vector2(252.0, 138.0)
