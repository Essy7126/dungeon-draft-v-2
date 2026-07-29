class_name SkillTreeVisualPresentation
extends RefCounted

enum SkillTreeVisualState {
	SELECTED,
	AVAILABLE,
	LOCKED_BY_XP,
	LOCKED_BY_BRANCH,
	FUTURE,
}


static func describe_node(
		discipline: DisciplineData,
		node: SkillUpgradeData,
		progress: DisciplineProgressState,
		selected_node_ids: Array[StringName],
		pending_ranks: Array[int]
	) -> Dictionary:
	var required_xp := _required_xp(discipline, node.rank if node != null else 1)
	var current_xp := progress.xp if progress != null else 0
	var result := {
		"state": SkillTreeVisualState.FUTURE,
		"reason": "Évolution future compatible.",
		"xp": current_xp,
		"required_xp": required_xp,
		"is_selected": false,
		"is_pending": false,
	}
	if discipline == null or node == null or progress == null:
		result["state"] = SkillTreeVisualState.LOCKED_BY_XP
		result["reason"] = "Progression indisponible."
		return result

	var is_selected := selected_node_ids.has(node.upgrade_id)
	var is_pending := pending_ranks.has(node.rank)
	result["is_selected"] = is_selected
	result["is_pending"] = is_pending
	if is_selected:
		result["state"] = SkillTreeVisualState.SELECTED
		result["reason"] = "Évolution déjà sélectionnée."
		return result
	if current_xp < required_xp:
		result["state"] = SkillTreeVisualState.LOCKED_BY_XP
		result["reason"] = "%d XP requis — progression actuelle : %d XP." % [
			required_xp,
			current_xp,
		]
		return result

	if is_pending and _resolver_approves(
			discipline,
			node,
			progress,
			selected_node_ids,
			pending_ranks
		):
		result["state"] = SkillTreeVisualState.AVAILABLE
		result["reason"] = "Choix disponible après le combat."
		return result

	var incompatibility := _branch_incompatibility(
		discipline,
		node,
		selected_node_ids,
		{}
	)
	if not incompatibility.is_empty():
		result["state"] = SkillTreeVisualState.LOCKED_BY_BRANCH
		result["reason"] = incompatibility
		return result

	var selected_same_rank := _selected_node_for_rank(
		discipline,
		node.rank,
		selected_node_ids
	)
	if selected_same_rank != null:
		result["state"] = SkillTreeVisualState.LOCKED_BY_BRANCH
		result["reason"] = "%s a été choisi au rang %d." % [
			selected_same_rank.display_name,
			node.rank,
		]
		return result

	result["state"] = SkillTreeVisualState.FUTURE
	result["reason"] = (
		"Disponible après résolution des choix précédents."
		if current_xp >= required_xp
		else "Évolution future compatible."
	)
	return result


static func describe_base_rank(
		progress: DisciplineProgressState,
		required_xp: int = 0
	) -> Dictionary:
	return {
		"state": SkillTreeVisualState.SELECTED,
		"reason": "Compétence de base de la discipline.",
		"xp": progress.xp if progress != null else 0,
		"required_xp": required_xp,
		"is_selected": true,
		"is_pending": false,
	}


static func state_label(state: SkillTreeVisualState) -> String:
	match state:
		SkillTreeVisualState.SELECTED:
			return "Sélectionné"
		SkillTreeVisualState.AVAILABLE:
			return "Disponible après le combat"
		SkillTreeVisualState.LOCKED_BY_XP:
			return "Bloqué par l’XP"
		SkillTreeVisualState.LOCKED_BY_BRANCH:
			return "Branche inaccessible"
		SkillTreeVisualState.FUTURE:
			return "Futur compatible"
	return "État inconnu"


static func symbol_for_state(state: SkillTreeVisualState) -> String:
	match state:
		SkillTreeVisualState.SELECTED:
			return "✓"
		SkillTreeVisualState.AVAILABLE:
			return "!"
		SkillTreeVisualState.LOCKED_BY_XP:
			return "🔒"
		SkillTreeVisualState.LOCKED_BY_BRANCH:
			return "⛔"
		SkillTreeVisualState.FUTURE:
			return "◇"
	return "?"


static func _resolver_approves(
		discipline: DisciplineData,
		node: SkillUpgradeData,
		progress: DisciplineProgressState,
		selected_node_ids: Array[StringName],
		pending_ranks: Array[int]
	) -> bool:
	var available := SkillTreeResolver.get_available_nodes(
		discipline,
		node.rank,
		progress.rank,
		pending_ranks,
		selected_node_ids
	)
	return available.any(
		func(candidate: SkillUpgradeData) -> bool:
			return candidate != null and candidate.upgrade_id == node.upgrade_id
	)


static func _branch_incompatibility(
		discipline: DisciplineData,
		node: SkillUpgradeData,
		selected_node_ids: Array[StringName],
		visited: Dictionary
	) -> String:
	if node == null or visited.has(node.upgrade_id):
		return ""
	visited[node.upgrade_id] = true
	if node is SkillTreeNodeData:
		var tree_node := node as SkillTreeNodeData
		for excluded_id in tree_node.excluded_node_ids:
			if selected_node_ids.has(excluded_id):
				var excluded := _find_node(discipline, excluded_id)
				return (
					"%s rend cette évolution incompatible."
					% excluded.display_name
					if excluded != null
					else "Cette évolution appartient à une autre branche."
				)
		for prerequisite_id in tree_node.prerequisite_node_ids:
			if selected_node_ids.has(prerequisite_id):
				continue
			var prerequisite := _find_node(discipline, prerequisite_id)
			if prerequisite == null:
				return "Prérequis de branche indisponible."
			var selected_same_rank := _selected_node_for_rank(
				discipline,
				prerequisite.rank,
				selected_node_ids
			)
			if selected_same_rank != null:
				return "%s a été choisi au rang %d." % [
					selected_same_rank.display_name,
					prerequisite.rank,
				]
			var inherited := _branch_incompatibility(
				discipline,
				prerequisite,
				selected_node_ids,
				visited
			)
			if not inherited.is_empty():
				return inherited
	return ""


static func _selected_node_for_rank(
		discipline: DisciplineData,
		wanted_rank: int,
		selected_node_ids: Array[StringName]
	) -> SkillUpgradeData:
	if discipline == null:
		return null
	for rank_data in discipline.ranks:
		if rank_data == null or rank_data.rank != wanted_rank:
			continue
		for candidate in rank_data.choices:
			if candidate != null and selected_node_ids.has(candidate.upgrade_id):
				return candidate
	return null


static func _find_node(
		discipline: DisciplineData,
		node_id: StringName
	) -> SkillUpgradeData:
	if discipline == null:
		return null
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		for candidate in rank_data.choices:
			if candidate != null and candidate.upgrade_id == node_id:
				return candidate
	return null


static func _required_xp(
		discipline: DisciplineData,
		wanted_rank: int
	) -> int:
	if discipline == null:
		return 0
	for rank_data in discipline.ranks:
		if rank_data != null and rank_data.rank == wanted_rank:
			return rank_data.required_total_xp
	return 0
