@tool
class_name SkillTreeDesignAnalysisService
extends RefCounted


static func analyze(discipline: DisciplineData) -> Dictionary:
	var started := Time.get_ticks_usec()
	return {
		"enumeration": SkillTreePathService.enumeration_result(discipline),
		"reachability": SkillTreePathService.reachability_analysis(discipline),
		"dominance": analyze_dominance(discipline),
		"capstones": analyze_capstones(discipline),
		"duration_usec": Time.get_ticks_usec() - started,
		"complete": true,
	}


static func analyze_dominance(discipline: DisciplineData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if discipline == null:
		return result
	for rank_data in discipline.ranks:
		if rank_data == null:
			continue
		for dominated in rank_data.choices:
			if dominated == null:
				continue
			for dominant in rank_data.choices:
				if dominant == null or dominant == dominated:
					continue
				var proof := _dominance_proof(dominated, dominant)
				if proof.get("dominated", false):
					result.append({
						"dominated_node_id": dominated.upgrade_id,
						"dominant_node_id": dominant.upgrade_id,
						"rank": rank_data.rank,
						"confidence": proof.get("confidence", "high"),
						"scenarios": proof.get("scenarios", []),
						"values": proof.get("values", {}),
						"conditions": proof.get("conditions", {}),
						"qualitative_differences": proof.get("qualitative_differences", []),
					})
	return result


static func analyze_capstones(discipline: DisciplineData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if discipline == null:
		return result
	var maximum_rank := 0
	for rank_data in discipline.ranks:
		if rank_data != null:
			maximum_rank = maxi(maximum_rank, rank_data.rank)
	for rank_data in discipline.ranks:
		if rank_data == null or rank_data.rank != maximum_rank:
			continue
		for node in rank_data.choices:
			if node == null or _has_qualitative_axis(node):
				continue
			result.append({
				"node_id": node.upgrade_id,
				"rank": node.rank,
				"severity": "WARNING",
				"code": "CAPSTONE_NUMERIC_ONLY",
				"message": "Cette capstone ne modifie que des valeurs numériques.",
				"blocking": false,
			})
	return result


static func _dominance_proof(
		dominated: SkillUpgradeData,
		dominant: SkillUpgradeData
	) -> Dictionary:
	if dominated.rank != dominant.rank \
			or dominated.target_spell_id != dominant.target_spell_id:
		return {"dominated": false}
	if dominated is SkillTreeNodeData and dominant is SkillTreeNodeData:
		if dominated.prerequisite_node_ids != dominant.prerequisite_node_ids:
			return {"dominated": false}
	else:
		return {"dominated": false}
	if dominated.spell_modifiers.size() != dominant.spell_modifiers.size() \
			or dominated.spell_modifiers.is_empty():
		return {"dominated": false}
	var strict := false
	var scenarios: Array[Dictionary] = []
	var values := {}
	var conditions := {}
	for index in range(dominated.spell_modifiers.size()):
		var weaker := dominated.spell_modifiers[index] as SpellModSkillTreeEffect
		var stronger := dominant.spell_modifiers[index] as SpellModSkillTreeEffect
		if weaker == null or stronger == null:
			return {"dominated": false}
		if not _qualitatively_comparable(weaker, stronger):
			return {"dominated": false}
		if stronger.amount < weaker.amount \
				or stronger.secondary_amount < weaker.secondary_amount \
				or stronger.duration < weaker.duration \
				or stronger.charges < weaker.charges \
				or stronger.ratio < weaker.ratio:
			return {"dominated": false}
		var weaker_conditions := _condition_count(weaker)
		var stronger_conditions := _condition_count(stronger)
		if stronger_conditions > weaker_conditions:
			return {"dominated": false}
		if stronger.amount > weaker.amount \
				or stronger.secondary_amount > weaker.secondary_amount \
				or stronger.duration > weaker.duration \
				or stronger.charges > weaker.charges \
				or stronger.ratio > weaker.ratio \
				or stronger_conditions < weaker_conditions:
			strict = true
		scenarios.append({
			"effect_index": index,
			"effect_type": weaker.effect_type,
			"weaker_condition_count": weaker_conditions,
			"stronger_condition_count": stronger_conditions,
		})
		values[index] = {
			"dominated": [weaker.amount, weaker.secondary_amount, weaker.duration, weaker.charges, weaker.ratio],
			"dominant": [stronger.amount, stronger.secondary_amount, stronger.duration, stronger.charges, stronger.ratio],
		}
		conditions[index] = {
			"dominated": _conditions(weaker),
			"dominant": _conditions(stronger),
		}
	return {
		"dominated": strict,
		"confidence": "high" if strict else "none",
		"scenarios": scenarios,
		"values": values,
		"conditions": conditions,
		"qualitative_differences": [],
	}


static func _qualitatively_comparable(
		first: SpellModSkillTreeEffect,
		second: SpellModSkillTreeEffect
	) -> bool:
	return first.effect_type == second.effect_type \
		and first.target_scope == second.target_scope \
		and first.effect_group == second.effect_group \
		and first.status_group == second.status_group \
		and first.status_mode == second.status_mode \
		and first.status_damage_type == second.status_damage_type \
		and first.status_element == second.status_element \
		and first.status_timing == second.status_timing


static func _condition_count(effect: SpellModSkillTreeEffect) -> int:
	return int(effect.require_backstab) + int(effect.require_ally_target) \
		+ int(effect.threshold_ratio > 0.0)


static func _conditions(effect: SpellModSkillTreeEffect) -> Dictionary:
	return {
		"require_backstab": effect.require_backstab,
		"require_ally_target": effect.require_ally_target,
		"threshold_ratio": effect.threshold_ratio,
	}


static func _has_qualitative_axis(node: SkillUpgradeData) -> bool:
	for modifier in node.spell_modifiers:
		var effect := modifier as SpellModSkillTreeEffect
		if effect == null:
			# Un modificateur spécialisé possède par définition un comportement
			# qualitatif que ce lint prudent ne tente pas de réduire.
			return true
		if effect.effect_type in [
			SpellModSkillTreeEffect.EffectType.RANGE,
			SpellModSkillTreeEffect.EffectType.STATUS_DOT,
			SpellModSkillTreeEffect.EffectType.STATUS_SLOW,
			SpellModSkillTreeEffect.EffectType.STATUS_REGEN,
			SpellModSkillTreeEffect.EffectType.STATUS_VULNERABILITY,
			SpellModSkillTreeEffect.EffectType.STATUS_OUTGOING_DAMAGE,
			SpellModSkillTreeEffect.EffectType.AREA_CARDINAL,
			SpellModSkillTreeEffect.EffectType.PUSH_BONUS,
			SpellModSkillTreeEffect.EffectType.PUSH_EXACT,
			SpellModSkillTreeEffect.EffectType.COLLISION_BONUS,
			SpellModSkillTreeEffect.EffectType.COLLISION_EXACT,
			SpellModSkillTreeEffect.EffectType.TERRAIN_DURATION,
			SpellModSkillTreeEffect.EffectType.TERRAIN_DAMAGE,
			SpellModSkillTreeEffect.EffectType.CLEANSE,
			SpellModSkillTreeEffect.EffectType.NEXT_TURN_MP_TARGET,
			SpellModSkillTreeEffect.EffectType.NEXT_TURN_MP_CASTER,
			SpellModSkillTreeEffect.EffectType.MP_ALLIES_ON_AREA,
			SpellModSkillTreeEffect.EffectType.ATTACK_BUFF,
			SpellModSkillTreeEffect.EffectType.MOVE_CASTER_TO_TARGET,
			SpellModSkillTreeEffect.EffectType.ALLOW_FREE_CELL_TARGET,
		]:
			return true
		if _condition_count(effect) > 0:
			return true
	return false
