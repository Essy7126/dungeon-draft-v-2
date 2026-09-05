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
	WRONG_PROGRESSION_MODE,
	LEVEL_GATE,
	INSUFFICIENT_MASTERY,
	ALREADY_SELECTED,
	MISSING_ANY_PREREQUISITE,
	EXCLUSIVE_GROUP,
	TREE_NOT_COMPLETE,
	TREE_POINTS_GATE,
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
			if choice.discipline_id != &"" \
					and choice.discipline_id != discipline.discipline_id:
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
			if choice is SkillTreeNodeData:
				var typed := choice as SkillTreeNodeData
				for message in typed.validation_errors():
					_append_diagnostic(diagnostics, message)

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
		if node is SkillTreeNodeData:
			var typed := node as SkillTreeNodeData
			for any_id in typed.requires_any_node_ids:
				if not nodes_by_id.has(any_id):
					_append_diagnostic(
						diagnostics,
						"UNKNOWN_ANY_PREREQUISITE: %s -> %s" % [node_id, any_id]
					)
				elif int(node_ranks[any_id]) >= node_rank:
					_append_diagnostic(
						diagnostics,
						"ANY_PREREQUISITE_NOT_IN_LOWER_RANK: %s -> %s" % [
							node_id, any_id,
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


## Point d'entree explicite pour les nouveaux consommateurs. Les APIs legacy
## ci-dessus ne changent ni signature ni semantique.
static func evaluate_purchase(
		discipline: DisciplineData,
		node_id: StringName,
		context: Dictionary,
		doctrines: Array[DisciplineData] = [],
		advanced_nodes: Array[SkillTreeNodeData] = []
	) -> Dictionary:
	if discipline == null:
		return _mastery_decision(false, RejectionReason.INVALID_DISCIPLINE, null)
	if discipline.progression_mode == DisciplineData.ProgressionMode.LEGACY_RANK_XP:
		var pending: Array[int] = []
		pending.assign(context.get("pending_ranks", []))
		var selected: Array[StringName] = []
		selected.assign(context.get("selected_node_ids", []))
		return evaluate_selection(
			discipline,
			int(context.get("choice_rank", 0)),
			node_id,
			int(context.get("reached_rank", 0)),
			pending,
			selected,
		)
	var node := _find_node(discipline, node_id) as SkillTreeNodeData
	var mastery_selected: Array[StringName] = []
	mastery_selected.assign(context.get("selected_node_ids", []))
	return evaluate_mastery_purchase(
		node,
		doctrines,
		advanced_nodes,
		int(context.get("champion_level", 1)),
		int(context.get("unspent_mastery_points", 0)),
		mastery_selected,
	)


static func evaluate_mastery_purchase(
		node: SkillTreeNodeData,
		doctrines: Array[DisciplineData],
		advanced_nodes: Array[SkillTreeNodeData],
		champion_level: int,
		unspent_mastery_points: int,
		selected_node_ids: Array[StringName],
		champion_profile: ChampionProgressionProfile = null
	) -> Dictionary:
	if node == null or not node.is_champion_mastery():
		return _mastery_decision(false, RejectionReason.INVALID_NODE, node)
	if selected_node_ids.has(node.upgrade_id):
		return _mastery_decision(false, RejectionReason.ALREADY_SELECTED, node)
	var catalog := champion_node_catalog(doctrines, advanced_nodes)
	if not catalog.is_empty() and catalog.get(node.upgrade_id) != node:
		return _mastery_decision(false, RejectionReason.INVALID_NODE, node)
	var required_level := node.required_champion_level
	if node.node_type == SkillTreeNodeData.NodeType.CAPSTONE:
		var has_capstone := false
		for selected_id in selected_node_ids:
			var selected_node := catalog.get(selected_id) as SkillTreeNodeData
			if selected_node != null and selected_node.node_type == SkillTreeNodeData.NodeType.CAPSTONE:
				has_capstone = true
		var capstone_level := (champion_profile.second_capstone_level if has_capstone else champion_profile.first_capstone_level) if champion_profile != null else (13 if has_capstone else 10)
		required_level = maxi(required_level, capstone_level)
	if champion_level < required_level:
		return _mastery_decision(false, RejectionReason.LEVEL_GATE, node)
	if unspent_mastery_points < node.mastery_cost:
		return _mastery_decision(false, RejectionReason.INSUFFICIENT_MASTERY, node)
	for required_id in node.prerequisite_node_ids:
		if not selected_node_ids.has(required_id):
			return _mastery_decision(
				false, RejectionReason.MISSING_PREREQUISITE, node,
				[required_id],
			)
	if not node.requires_any_node_ids.is_empty():
		var has_any := false
		for required_id in node.requires_any_node_ids:
			if selected_node_ids.has(required_id):
				has_any = true
				break
		if not has_any:
			return _mastery_decision(
				false,
				RejectionReason.MISSING_ANY_PREREQUISITE,
				node,
				node.requires_any_node_ids,
			)
	for excluded_id in node.excluded_node_ids:
		if selected_node_ids.has(excluded_id):
			return _mastery_decision(
				false, RejectionReason.EXCLUDED_BY_SELECTION, node, [], [excluded_id]
			)
	if node.exclusive_group != &"":
		for selected_id in selected_node_ids:
			var selected_node := catalog.get(selected_id) as SkillTreeNodeData
			if selected_node != null \
					and selected_node.exclusive_group == node.exclusive_group:
				return _mastery_decision(
					false,
					RejectionReason.EXCLUSIVE_GROUP,
					node,
					[],
					[selected_id],
				)
	for tree_id in node.requires_completed_tree_ids:
		var required_tree := champion_doctrine_by_id(doctrines, tree_id)
		if required_tree == null \
				or not champion_doctrine_is_complete(required_tree, selected_node_ids):
			return _mastery_decision(
				false, RejectionReason.TREE_NOT_COMPLETE, node
			)
	for requirement in node.doctrine_point_requirements:
		if requirement == null:
			return _mastery_decision(false, RejectionReason.INVALID_TREE_DATA, node)
		var required_tree := champion_doctrine_by_id(doctrines, requirement.tree_id)
		if required_tree == null or champion_doctrine_selected_cost(
			required_tree, selected_node_ids
		) < requirement.minimum_points:
			return _mastery_decision(
				false, RejectionReason.TREE_POINTS_GATE, node
			)
	return _mastery_decision(true, RejectionReason.NONE, node)


## Alias de compatibilite avec les prototypes Champion deja presents dans
## certaines branches locales. Il partage strictement le meme resolver.
static func evaluate_champion_purchase(
		node: SkillTreeNodeData,
		doctrines: Array[DisciplineData],
		advanced_nodes: Array[SkillTreeNodeData],
		champion_level: int,
		unspent_mastery_points: int,
		selected_node_ids: Array[StringName]
	) -> Dictionary:
	return evaluate_mastery_purchase(
		node,
		doctrines,
		advanced_nodes,
		champion_level,
		unspent_mastery_points,
		selected_node_ids,
	)


static func validate_champion_tree(
		doctrines: Array[DisciplineData],
		advanced_nodes: Array[SkillTreeNodeData] = []
	) -> PackedStringArray:
	var errors := PackedStringArray()
	if doctrines.size() != 3:
		errors.append("CHAMPION_DOCTRINE_COUNT: expected 3, found %d" % doctrines.size())
	var doctrine_ids := {}
	var node_ids := {}
	var effect_sources := {}
	for doctrine in doctrines:
		if doctrine == null or doctrine.discipline_id == &"":
			errors.append("CHAMPION_DOCTRINE_INVALID")
			continue
		if discipline_ids_has(doctrine_ids, doctrine.discipline_id):
			errors.append("CHAMPION_DOCTRINE_DUPLICATE: %s" % doctrine.discipline_id)
		doctrine_ids[doctrine.discipline_id] = true
		if doctrine.progression_mode != DisciplineData.ProgressionMode.MASTERY_POINTS:
			errors.append("CHAMPION_DOCTRINE_MODE: %s" % doctrine.discipline_id)
		errors.append_array(validate_discipline(doctrine))
		var nodes := champion_doctrine_nodes(doctrine)
		if nodes.size() != 9:
			errors.append("CHAMPION_NODE_COUNT: %s" % doctrine.discipline_id)
		var tier_counts := {}
		var capstone_count := 0
		var affected := {}
		for node in nodes:
			_validate_mastery_node_identity(
				node, doctrine.discipline_id, node_ids, effect_sources, errors
			)
			tier_counts[node.tier] = int(tier_counts.get(node.tier, 0)) + 1
			if node.node_type == SkillTreeNodeData.NodeType.CAPSTONE:
				capstone_count += 1
			for spell_id in node.affected_spell_ids:
				affected[spell_id] = true
		if tier_counts.get(1, 0) != 1 \
				or tier_counts.get(2, 0) != 2 \
				or tier_counts.get(3, 0) != 2 \
				or tier_counts.get(4, 0) != 2 \
				or tier_counts.get(5, 0) != 2:
			errors.append("CHAMPION_TIER_TOPOLOGY: %s" % doctrine.discipline_id)
		if capstone_count != 2:
			errors.append("CHAMPION_CAPSTONE_COUNT: %s" % doctrine.discipline_id)
		if affected.size() < 3:
			errors.append("CHAMPION_AFFECTED_SPELLS: %s" % doctrine.discipline_id)
		if minimal_champion_capstone_cost(doctrine) != 6:
			errors.append("CHAMPION_MINIMAL_PATH_COST: %s" % doctrine.discipline_id)
		if full_champion_doctrine_cost(doctrine) != 9:
			errors.append("CHAMPION_FULL_COST: %s" % doctrine.discipline_id)
	for node in advanced_nodes:
		if node == null or not node.is_champion_mastery():
			errors.append("CHAMPION_ADVANCED_NODE_INVALID")
			continue
		_validate_mastery_node_identity(
			node, node.doctrine_id, node_ids, effect_sources, errors
		)
		match node.node_type:
			SkillTreeNodeData.NodeType.SPECIALIST_SUMMIT:
				if node.required_champion_level != 13:
					errors.append("CHAMPION_SUMMIT_GATE: %s" % node.upgrade_id)
			SkillTreeNodeData.NodeType.MYTHIC_JUNCTION, SkillTreeNodeData.NodeType.APOTHEOSIS:
				if node.required_champion_level != 14:
					errors.append("CHAMPION_ADVANCED_GATE: %s" % node.upgrade_id)
			_:
				errors.append("CHAMPION_ADVANCED_TYPE: %s" % node.upgrade_id)
	return errors


static func champion_node_catalog(
		doctrines: Array[DisciplineData],
		advanced_nodes: Array[SkillTreeNodeData] = []
	) -> Dictionary:
	var result := {}
	for doctrine in doctrines:
		for node in champion_doctrine_nodes(doctrine):
			result[node.upgrade_id] = node
	for node in advanced_nodes:
		if node != null:
			result[node.upgrade_id] = node
	return result


static func champion_doctrine_nodes(
		doctrine: DisciplineData
	) -> Array[SkillTreeNodeData]:
	var result: Array[SkillTreeNodeData] = []
	if doctrine == null:
		return result
	for rank_data in doctrine.ranks:
		if rank_data == null:
			continue
		for choice in rank_data.choices:
			var node := choice as SkillTreeNodeData
			if node != null and node.is_champion_mastery():
				result.append(node)
	return result


static func champion_doctrine_by_id(
		doctrines: Array[DisciplineData],
		doctrine_id: StringName
	) -> DisciplineData:
	for doctrine in doctrines:
		if doctrine != null and doctrine.discipline_id == doctrine_id:
			return doctrine
	return null


static func champion_doctrine_selected_cost(
		doctrine: DisciplineData,
		selected_node_ids: Array[StringName]
	) -> int:
	var total := 0
	for node in champion_doctrine_nodes(doctrine):
		if selected_node_ids.has(node.upgrade_id):
			total += node.mastery_cost
	return total


static func minimal_champion_capstone_cost(doctrine: DisciplineData) -> int:
	var paths := champion_capstone_paths(doctrine, 99)
	var minimum := 2147483647
	for path_value in paths:
		var path := path_value as Array
		minimum = mini(minimum, _path_cost(doctrine, path))
	return -1 if minimum == 2147483647 else minimum


static func full_champion_doctrine_cost(doctrine: DisciplineData) -> int:
	var non_capstone_cost := 0
	var maximum_capstone_cost := 0
	for node in champion_doctrine_nodes(doctrine):
		if node.node_type == SkillTreeNodeData.NodeType.CAPSTONE:
			maximum_capstone_cost = maxi(maximum_capstone_cost, node.mastery_cost)
		else:
			non_capstone_cost += node.mastery_cost
	return non_capstone_cost + maximum_capstone_cost


static func champion_doctrine_is_complete(
		doctrine: DisciplineData,
		selected_node_ids: Array[StringName]
	) -> bool:
	var selected_capstone := false
	var catalog := champion_node_catalog([doctrine])
	for node in champion_doctrine_nodes(doctrine):
		if node.node_type == SkillTreeNodeData.NodeType.CAPSTONE \
				and selected_node_ids.has(node.upgrade_id):
			selected_capstone = true
	if not selected_capstone:
		return false
	if champion_doctrine_selected_cost(doctrine, selected_node_ids) \
			>= full_champion_doctrine_cost(doctrine):
		return true
	# Une paire explicitement exclusive compte comme un palier complet lorsque
	# l'une de ses branches est achetee ; aucune gate n'est contournee.
	for node in champion_doctrine_nodes(doctrine):
		if node.node_type == SkillTreeNodeData.NodeType.CAPSTONE \
				or selected_node_ids.has(node.upgrade_id):
			continue
		var covered_by_exclusion := false
		for excluded_id in node.excluded_node_ids:
			if selected_node_ids.has(excluded_id) and catalog.has(excluded_id):
				covered_by_exclusion = true
				break
		if not covered_by_exclusion:
			return false
	return true


static func champion_capstone_paths(
		doctrine: DisciplineData,
		champion_level: int
	) -> Array:
	var paths: Array = []
	if doctrine == null:
		return paths
	var tier_nodes := {}
	for node in champion_doctrine_nodes(doctrine):
		if not tier_nodes.has(node.tier):
			tier_nodes[node.tier] = []
		(tier_nodes[node.tier] as Array).append(node)
	if not tier_nodes.has(1):
		return paths
	var seeds: Array = []
	for root_value in tier_nodes[1]:
		var root := root_value as SkillTreeNodeData
		seeds.append([root.upgrade_id])
	for tier in [2, 3, 4]:
		var expanded: Array = []
		for seed_value in seeds:
			var seed := seed_value as Array
			for subset in _non_empty_subsets(tier_nodes.get(tier, [])):
				var candidate := seed.duplicate()
				for node_value in subset:
					candidate.append((node_value as SkillTreeNodeData).upgrade_id)
				if _path_dependencies_pass(doctrine, candidate):
					expanded.append(candidate)
		seeds = expanded
	for capstone_value in tier_nodes.get(5, []):
		var capstone := capstone_value as SkillTreeNodeData
		if capstone.required_champion_level > champion_level:
			continue
		for seed_value in seeds:
			var candidate := (seed_value as Array).duplicate()
			candidate.append(capstone.upgrade_id)
			if _path_dependencies_pass(doctrine, candidate):
				paths.append(candidate)
	return paths


static func _mastery_decision(
		allowed: bool,
		reason: RejectionReason,
		node: SkillTreeNodeData,
		missing_prerequisites: Array = [],
		conflicting_node_ids: Array = []
	) -> Dictionary:
	return {
		"allowed": allowed,
		"reason": reason,
		"reason_id": RejectionReason.keys()[reason],
		"node": node,
		"mastery_cost": node.mastery_cost if node != null else 0,
		"missing_prerequisites": missing_prerequisites.duplicate(),
		"conflicting_node_ids": conflicting_node_ids.duplicate(),
	}


static func _validate_mastery_node_identity(
		node: SkillTreeNodeData,
		expected_doctrine_id: StringName,
		node_ids: Dictionary,
		effect_sources: Dictionary,
		errors: PackedStringArray
	) -> void:
	if node_ids.has(node.upgrade_id):
		errors.append("CHAMPION_NODE_DUPLICATE: %s" % node.upgrade_id)
	else:
		node_ids[node.upgrade_id] = true
	if node.doctrine_id != expected_doctrine_id:
		errors.append("CHAMPION_NODE_AUTHORITY: %s" % node.upgrade_id)
	for effect in node.reactive_effects:
		if effect == null:
			continue
		if effect_sources.has(effect.source_id):
			errors.append("CHAMPION_REACTIVE_SOURCE_DUPLICATE: %s" % effect.source_id)
		effect_sources[effect.source_id] = true


static func discipline_ids_has(values: Dictionary, key: StringName) -> bool:
	return values.has(key)


static func _non_empty_subsets(values: Array) -> Array:
	var result: Array = []
	var count := values.size()
	for mask in range(1, 1 << count):
		var subset: Array = []
		for index in range(count):
			if mask & (1 << index):
				subset.append(values[index])
		result.append(subset)
	return result


static func _path_dependencies_pass(
		doctrine: DisciplineData,
		path: Array
	) -> bool:
	for node_id_value in path:
		var node := _find_node(doctrine, StringName(node_id_value)) as SkillTreeNodeData
		if node == null:
			return false
		for required_id in node.prerequisite_node_ids:
			if not path.has(required_id):
				return false
		if not node.requires_any_node_ids.is_empty():
			var any_found := false
			for required_id in node.requires_any_node_ids:
				if path.has(required_id):
					any_found = true
					break
			if not any_found:
				return false
		for excluded_id in node.excluded_node_ids:
			if path.has(excluded_id):
				return false
	return true


static func _path_cost(discipline: DisciplineData, path: Array) -> int:
	var result := 0
	for node_id_value in path:
		var node := _find_node(discipline, StringName(node_id_value)) as SkillTreeNodeData
		if node != null:
			result += node.mastery_cost
	return result


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
