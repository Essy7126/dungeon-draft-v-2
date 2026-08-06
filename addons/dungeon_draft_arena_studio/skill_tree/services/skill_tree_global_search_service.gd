@tool
class_name SkillTreeGlobalSearchService
extends RefCounted


static func search(heroes: Array[Dictionary], query: String, limit := 200) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var normalized := query.strip_edges().to_lower()
	if normalized.is_empty():
		return result
	for hero_entry in heroes:
		var unit := hero_entry.get("resource") as UnitData
		if unit == null:
			continue
		var hero_path := str(hero_entry.get("path", unit.resource_path))
		_append_if_match(result, normalized, {
			"kind": "character", "label": unit.unit_name,
			"search_text": "%s %s %s" % [unit.unit_name, unit.get_effective_unit_id(), unit.description],
			"character_path": hero_path, "discipline_id": &"", "node_id": &"",
		}, limit)
		for discipline in unit.disciplines:
			if discipline == null:
				continue
			_append_if_match(result, normalized, {
				"kind": "discipline", "label": discipline.display_name,
				"search_text": "%s %s %s" % [discipline.display_name, discipline.discipline_id, discipline.description],
				"character_path": hero_path, "discipline_id": discipline.discipline_id, "node_id": &"",
			}, limit)
			for rank_data in discipline.ranks:
				if rank_data == null:
					continue
				for node in rank_data.choices:
					if node == null:
						continue
					var summary := SkillTreeEffectSummaryService.summarize_node(node)
					_append_if_match(result, normalized, {
						"kind": "node", "label": node.display_name,
						"search_text": "%s %s %s %s" % [node.display_name, node.upgrade_id, node.description, summary],
						"character_path": hero_path, "discipline_id": discipline.discipline_id,
						"node_id": node.upgrade_id, "rank": node.rank, "summary": summary,
					}, limit)
					for modifier in node.spell_modifiers:
						if modifier == null:
							continue
						var modifier_summary := SkillTreeEffectSummaryService.summarize_modifier(modifier)
						_append_if_match(result, normalized, {
							"kind": "effect", "label": modifier.modifier_name,
							"search_text": "%s %s %s" % [modifier.modifier_name, modifier.target_spell_id, modifier_summary],
							"character_path": hero_path, "discipline_id": discipline.discipline_id,
							"node_id": node.upgrade_id, "rank": node.rank, "summary": modifier_summary,
						}, limit)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_key := "%s|%s|%s" % [a.get("kind", ""), a.get("label", ""), a.get("node_id", "")]
		var b_key := "%s|%s|%s" % [b.get("kind", ""), b.get("label", ""), b.get("node_id", "")]
		return a_key.naturalnocasecmp_to(b_key) < 0
	)
	return result


static func _append_if_match(
		result: Array[Dictionary], query: String, entry: Dictionary, limit: int
	) -> void:
	if result.size() >= limit or not str(entry.get("search_text", "")).to_lower().contains(query):
		return
	entry.erase("search_text")
	result.append(entry)
