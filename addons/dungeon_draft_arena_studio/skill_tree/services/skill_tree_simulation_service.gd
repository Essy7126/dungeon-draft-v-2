@tool
class_name SkillTreeSimulationService
extends RefCounted


static func simulate(
		discipline: DisciplineData,
		xp: int,
		selected_ids: Array[StringName] = []
	) -> Dictionary:
	var progress := DisciplineProgressState.new()
	if discipline == null or not progress.initialize(discipline):
		return {"ok": false, "error": "Discipline invalide."}
	progress.add_xp(maxi(0, xp))
	for rank_data in _sorted_ranks(discipline):
		if rank_data.rank <= 1:
			continue
		for node in rank_data.choices:
			if node != null and selected_ids.has(node.upgrade_id):
				progress.select_upgrade(node.upgrade_id, rank_data.rank)
				break
	var states := {}
	for rank_data in _sorted_ranks(discipline):
		for node in rank_data.choices:
			if node == null:
				continue
			states[str(node.upgrade_id)] = _node_state(
				discipline, node, progress
			)
	return {
		"ok": true,
		"xp": progress.xp,
		"rank": progress.rank,
		"pending_ranks": progress.get_pending_rank_choices(),
		"selected_ids": progress.get_selected_upgrade_ids(),
		"active_modifiers": _active_modifiers(progress),
		"states": states,
		"snapshot": progress.get_snapshot(),
	}


static func try_select(
		discipline: DisciplineData,
		xp: int,
		selected_ids: Array[StringName],
		node_id: StringName
	) -> Dictionary:
	var before := simulate(discipline, xp, selected_ids)
	if not before.get("ok", false):
		return before
	var node := _find_node(discipline, node_id)
	if node == null:
		return {"ok": false, "error": "Amélioration introuvable."}
	var decision := SkillTreeResolver.evaluate_selection(
		discipline,
		node.rank,
		node_id,
		int(before.get("rank", 1)),
		_typed_int_array(before.get("pending_ranks", [])),
		_typed_id_array(before.get("selected_ids", []))
	)
	if not decision.get("allowed", false):
		return {
			"ok": false,
			"error": _reason_text(int(decision.get(
				"reason", SkillTreeResolver.RejectionReason.INVALID_NODE
			))),
		}
	var next := selected_ids.duplicate()
	next.append(node_id)
	return simulate(discipline, xp, next)


static func _node_state(
		discipline: DisciplineData,
		node: SkillUpgradeData,
		progress: DisciplineProgressState
	) -> Dictionary:
	if progress.get_selected_upgrade_ids().has(node.upgrade_id):
		return {"state": "ACQUIS", "reason": "Amélioration sélectionnée."}
	var decision := SkillTreeResolver.evaluate_selection(
		discipline,
		node.rank,
		node.upgrade_id,
		progress.rank,
		progress.get_pending_rank_choices(),
		progress.get_selected_upgrade_ids()
	)
	if decision.get("allowed", false):
		return {"state": "DISPONIBLE", "reason": "Toutes les conditions sont remplies."}
	var reason := int(decision.get("reason", SkillTreeResolver.RejectionReason.INVALID_NODE))
	var state := "VERROUILLÉ"
	if reason == SkillTreeResolver.RejectionReason.RANK_NOT_REACHED:
		state = "XP REQUISE"
	elif reason == SkillTreeResolver.RejectionReason.EXCLUDED_BY_SELECTION:
		state = "EXCLU"
	return {"state": state, "reason": _reason_text(reason)}


static func _reason_text(reason: int) -> String:
	match reason:
		SkillTreeResolver.RejectionReason.WRONG_RANK:
			return "Cette amélioration est rangée au mauvais niveau."
		SkillTreeResolver.RejectionReason.RANK_NOT_REACHED:
			return "Le seuil d’XP de ce rang n’est pas encore atteint."
		SkillTreeResolver.RejectionReason.RANK_NOT_PENDING:
			return "Ce rang ne demande actuellement aucun choix."
		SkillTreeResolver.RejectionReason.EARLIER_RANK_PENDING:
			return "Un choix d’un rang précédent doit être effectué d’abord."
		SkillTreeResolver.RejectionReason.RANK_ALREADY_SELECTED:
			return "Une autre amélioration a déjà été choisie pour ce rang."
		SkillTreeResolver.RejectionReason.MISSING_PREREQUISITE:
			return "Tous les prérequis obligatoires n’ont pas été acquis."
		SkillTreeResolver.RejectionReason.EXCLUDED_BY_SELECTION:
			return "Une amélioration déjà acquise exclut ce choix."
		SkillTreeResolver.RejectionReason.INVALID_TREE_DATA:
			return "L’arbre contient une erreur structurelle."
		_:
			return "Cette amélioration n’est pas disponible."


static func _active_modifiers(
		progress: DisciplineProgressState
	) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in progress.get_selected_upgrades():
		for modifier in node.get_spell_modifiers():
			if modifier != null:
				result.append({
					"node_id": node.upgrade_id,
					"node_name": node.display_name,
					"modifier": modifier,
					"summary": SkillTreeEffectSummaryService.summarize_modifier(modifier),
				})
	return result


static func _find_node(
		discipline: DisciplineData,
		node_id: StringName
	) -> SkillUpgradeData:
	if discipline == null:
		return null
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		for node in rank_data.choices:
			if node != null and node.upgrade_id == node_id:
				return node
	return null


static func _sorted_ranks(discipline: DisciplineData) -> Array[DisciplineRankData]:
	var result: Array[DisciplineRankData] = []
	if discipline != null:
		for rank_data in discipline.ranks:
			if rank_data != null:
				result.append(rank_data)
	result.sort_custom(func(a: DisciplineRankData, b: DisciplineRankData) -> bool:
		return a.rank < b.rank
	)
	return result


static func _typed_int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value in values:
		result.append(int(value))
	return result


static func _typed_id_array(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		result.append(StringName(value))
	return result
