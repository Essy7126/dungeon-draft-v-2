@tool
class_name SkillTreeGlobalSearchService
extends RefCounted


static func search(heroes: Array[Dictionary], query: String, limit := 200) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var normalized := query.strip_edges().to_lower()
	if normalized.is_empty():
		return result
	for hero_entry in heroes:
		for variant in _editorial_variants(hero_entry):
			_search_unit(result, normalized, variant, limit)
			if result.size() >= limit:
				break
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_key := "%s|%s|%s|%s" % [
			a.get("kind", ""), a.get("label", ""), a.get("profile_path", ""),
			a.get("node_id", ""),
		]
		var b_key := "%s|%s|%s|%s" % [
			b.get("kind", ""), b.get("label", ""), b.get("profile_path", ""),
			b.get("node_id", ""),
		]
		return a_key.naturalnocasecmp_to(b_key) < 0
	)
	return result


static func _search_unit(
		result: Array[Dictionary],
		query: String,
		variant: Dictionary,
		limit: int
	) -> void:
	var unit := variant.get("resource") as UnitData
	if unit == null:
		return
	var hero_path := str(variant.get("path", unit.resource_path))
	_append_if_match(result, query, _with_authority({
		"kind": "character", "label": unit.unit_name,
		"search_text": "%s %s %s" % [
			unit.unit_name, unit.get_effective_unit_id(), unit.description,
		],
		"character_path": hero_path, "discipline_id": &"", "node_id": &"",
	}, variant), limit)
	for spell in unit.spells:
		if spell == null:
			continue
		_append_if_match(result, query, _with_authority({
			"kind": "spell", "label": spell.spell_name,
			"search_text": "%s %s %s" % [
				spell.spell_name, spell.get_effective_spell_id(), spell.description,
			],
			"character_path": hero_path,
			"discipline_id": spell.discipline_id,
			"node_id": &"",
		}, variant), limit)
	for discipline in unit.disciplines:
		if discipline == null:
			continue
		_append_if_match(result, query, _with_authority({
			"kind": "discipline", "label": discipline.display_name,
			"search_text": "%s %s %s" % [discipline.display_name, discipline.discipline_id, discipline.description],
			"character_path": hero_path, "discipline_id": discipline.discipline_id, "node_id": &"",
		}, variant), limit)
		for rank_data in discipline.ranks:
			if rank_data == null:
				continue
			for node in rank_data.choices:
				if node == null:
					continue
				var summary := SkillTreeEffectSummaryService.summarize_node(node)
				_append_if_match(result, query, _with_authority({
					"kind": "node", "label": node.display_name,
					"search_text": "%s %s %s %s" % [node.display_name, node.upgrade_id, node.description, summary],
					"character_path": hero_path, "discipline_id": discipline.discipline_id,
					"node_id": node.upgrade_id, "rank": node.rank, "summary": summary,
				}, variant), limit)
				for modifier in node.spell_modifiers:
					if modifier == null:
						continue
					var modifier_summary := SkillTreeEffectSummaryService.summarize_modifier(modifier)
					_append_if_match(result, query, _with_authority({
						"kind": "effect", "label": modifier.modifier_name,
						"search_text": "%s %s %s" % [modifier.modifier_name, modifier.target_spell_id, modifier_summary],
						"character_path": hero_path, "discipline_id": discipline.discipline_id,
						"node_id": node.upgrade_id, "rank": node.rank, "summary": modifier_summary,
					}, variant), limit)


static func _editorial_variants(hero_entry: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var unit := hero_entry.get("unit_resource", hero_entry.get("resource")) as UnitData
	var authorities: Array = hero_entry.get("profile_authorities", [])
	if unit == null or authorities.is_empty():
		result.append(hero_entry)
		return result
	for authority_value in authorities:
		var authority := authority_value as Dictionary
		var profile := authority.get("progression_profile") \
			as CharacterProgressionProfile
		var view := RunContentCatalogService.as_editable_unit_view(unit, profile)
		if view == null:
			continue
		var variant := hero_entry.duplicate()
		variant["resource"] = view
		for key in [
			"authority", "run", "run_path", "run_name", "hero_profile",
			"hero_path", "progression_profile", "profile_path",
		]:
			variant[key] = authority.get(key)
		result.append(variant)
	return result


static func _with_authority(entry: Dictionary, variant: Dictionary) -> Dictionary:
	for key in ["authority", "run_path", "run_name", "hero_path", "profile_path"]:
		entry[key] = variant.get(key, "")
	return entry


static func _append_if_match(
		result: Array[Dictionary], query: String, entry: Dictionary, limit: int
	) -> void:
	if result.size() >= limit or not str(entry.get("search_text", "")).to_lower().contains(query):
		return
	entry.erase("search_text")
	result.append(entry)
