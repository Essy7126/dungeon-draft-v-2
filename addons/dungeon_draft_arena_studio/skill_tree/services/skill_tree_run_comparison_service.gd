@tool
class_name SkillTreeRunComparisonService
extends RefCounted


static func compare(
		left_run: RunData,
		right_run: RunData,
		character_id: StringName
	) -> Dictionary:
	var left := RunContentCatalogService.progression_profile_for(left_run, character_id)
	var right := RunContentCatalogService.progression_profile_for(right_run, character_id)
	if left == null or right == null:
		return {"ok": false, "error": "Profil absent dans l'une des parties."}
	var left_snapshot := _profile_snapshot(left)
	var right_snapshot := _profile_snapshot(right)
	var differences: Array[Dictionary] = []
	_compare_map("sort", left_snapshot.spells, right_snapshot.spells, differences)
	_compare_map("discipline", left_snapshot.disciplines, right_snapshot.disciplines, differences)
	_compare_discipline_details(
		left_snapshot.disciplines, right_snapshot.disciplines, differences
	)
	return {
		"ok": true,
		"character_id": character_id,
		"left_run": left_run.run_name,
		"right_run": right_run.run_name,
		"left_profile_path": left.resource_path,
		"right_profile_path": right.resource_path,
		"same_profile": left.resource_path == right.resource_path,
		"differences": differences,
		"left": left_snapshot,
		"right": right_snapshot,
	}


static func format_report(report: Dictionary) -> String:
	if not report.get("ok", false):
		return str(report.get("error", "Comparaison impossible."))
	var lines := PackedStringArray([
		"COMPARAISON DE PROGRESSION",
		"%s  ↔  %s" % [report.get("left_run", ""), report.get("right_run", "")],
		"Héros : %s" % report.get("character_id", ""),
		"Profil gauche : %s" % report.get("left_profile_path", ""),
		"Profil droit : %s" % report.get("right_profile_path", ""),
		"Ressource partagée : %s" % ("oui" if report.get("same_profile", false) else "non"),
		"",
	])
	var differences := report.get("differences", []) as Array
	if differences.is_empty():
		lines.append("Aucune divergence de sorts, rangs, noeuds ou effets.")
	else:
		for difference in differences:
			lines.append("• %s %s : %s" % [
				difference.get("kind", "element"), difference.get("id", ""),
				difference.get("change", "modifie"),
			])
	return "\n".join(lines)


## Une discipline dont l'empreinte diffère produisait une seule ligne
## « discipline X : modifie », sans dire quel rang ni quel nœud avait changé.
## On descend donc d'un cran pour nommer le rang, le nœud et son nombre
## d'effets, comme le promet la documentation d'authoring run-aware.
static func _compare_discipline_details(
		left: Dictionary,
		right: Dictionary,
		differences: Array[Dictionary]
	) -> void:
	for discipline_id in left:
		if not right.has(discipline_id):
			continue
		var left_ranks := _ranks_by_number((left[discipline_id] as Dictionary).get("ranks", []))
		var right_ranks := _ranks_by_number((right[discipline_id] as Dictionary).get("ranks", []))
		var rank_numbers := {}
		for number in left_ranks:
			rank_numbers[number] = true
		for number in right_ranks:
			rank_numbers[number] = true
		for number in rank_numbers:
			if not left_ranks.has(number):
				differences.append({
					"kind": "rang", "id": "%s R%d" % [discipline_id, number],
					"change": "ajoute a droite",
				})
				continue
			if not right_ranks.has(number):
				differences.append({
					"kind": "rang", "id": "%s R%d" % [discipline_id, number],
					"change": "absent a droite",
				})
				continue
			var left_rank := left_ranks[number] as Dictionary
			var right_rank := right_ranks[number] as Dictionary
			if int(left_rank.get("xp", 0)) != int(right_rank.get("xp", 0)):
				differences.append({
					"kind": "seuil d'XP", "id": "%s R%d" % [discipline_id, number],
					"change": "%d a gauche, %d a droite" % [
						int(left_rank.get("xp", 0)), int(right_rank.get("xp", 0)),
					],
				})
			_compare_nodes(
				str(discipline_id), int(number),
				_nodes_by_id(left_rank.get("nodes", [])),
				_nodes_by_id(right_rank.get("nodes", [])),
				differences
			)


static func _compare_nodes(
		discipline_id: String,
		rank_number: int,
		left: Dictionary,
		right: Dictionary,
		differences: Array[Dictionary]
	) -> void:
	var node_ids := {}
	for node_id in left:
		node_ids[node_id] = true
	for node_id in right:
		node_ids[node_id] = true
	for node_id in node_ids:
		var label := "%s R%d %s" % [discipline_id, rank_number, node_id]
		if not left.has(node_id):
			differences.append({"kind": "noeud", "id": label, "change": "ajoute a droite"})
		elif not right.has(node_id):
			differences.append({"kind": "noeud", "id": label, "change": "absent a droite"})
		else:
			var left_node := left[node_id] as Dictionary
			var right_node := right[node_id] as Dictionary
			var left_effects := int(left_node.get("effects", 0))
			var right_effects := int(right_node.get("effects", 0))
			if left_effects != right_effects:
				differences.append({
					"kind": "effets", "id": label,
					"change": "%d a gauche, %d a droite" % [left_effects, right_effects],
				})
			elif str(left_node.get("fingerprint", "")) != str(right_node.get("fingerprint", "")):
				differences.append({
					"kind": "noeud", "id": label,
					"change": "reglages differents a effectif d'effets egal",
				})


static func _ranks_by_number(ranks: Array) -> Dictionary:
	var result := {}
	for rank_value in ranks:
		var rank_data := rank_value as Dictionary
		result[int(rank_data.get("rank", 0))] = rank_data
	return result


static func _nodes_by_id(nodes: Array) -> Dictionary:
	var result := {}
	for node_value in nodes:
		var node_data := node_value as Dictionary
		result[str(node_data.get("id", ""))] = node_data
	return result


static func _profile_snapshot(profile: CharacterProgressionProfile) -> Dictionary:
	var spells := {}
	for spell in profile.spells:
		if spell != null:
			spells[str(spell.get_effective_spell_id())] = SkillTreeSnapshotService.storage_fingerprint(spell)
	var disciplines := {}
	var seen_trees := {}
	for spell in profile.spells:
		var discipline := spell.skill_tree if spell != null else null
		if discipline == null:
			continue
		if seen_trees.has(discipline.discipline_id):
			continue
		seen_trees[discipline.discipline_id] = true
		var ranks := []
		for rank_data in discipline.ranks:
			if rank_data == null:
				continue
			var nodes := []
			for node in rank_data.choices:
				if node != null:
					nodes.append({
						"id": str(node.upgrade_id),
						"effects": node.spell_modifiers.size(),
						"fingerprint": SkillTreeSnapshotService.storage_fingerprint(node),
					})
			ranks.append({"rank": rank_data.rank, "xp": rank_data.required_total_xp, "nodes": nodes})
		disciplines[str(discipline.discipline_id)] = {
			"fingerprint": SkillTreeSnapshotService.storage_fingerprint(discipline),
			"ranks": ranks,
		}
	return {
		"path": profile.resource_path,
		"active_spell_slots": profile.active_spell_slots,
		"spells": spells,
		"disciplines": disciplines,
	}


static func _compare_map(
		kind: String,
		left: Dictionary,
		right: Dictionary,
		differences: Array[Dictionary]
	) -> void:
	var ids := {}
	for id in left:
		ids[id] = true
	for id in right:
		ids[id] = true
	for id in ids:
		if not left.has(id):
			differences.append({"kind": kind, "id": id, "change": "ajoute a droite"})
		elif not right.has(id):
			differences.append({"kind": kind, "id": id, "change": "absent a droite"})
		elif JSON.stringify(left[id]) != JSON.stringify(right[id]):
			differences.append({"kind": kind, "id": id, "change": "contenu different"})
