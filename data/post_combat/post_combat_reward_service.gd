class_name PostCombatRewardService
extends RefCounted

const TEAM_HEAL := preload(
	"res://data/post_combat/rewards/team_heal_percent.tres"
)
const HERO_MAX_HP := preload(
	"res://data/post_combat/rewards/hero_max_hp.tres"
)
const NEXT_SHIELD := preload(
	"res://data/post_combat/rewards/next_combat_shield.tres"
)

var _applied_report_ids: Dictionary = {}


func reset() -> void:
	_applied_report_ids.clear()


func build_options(report: CombatReport, character_states: Array) -> Array[Dictionary]:
	if report == null or not report.finalized or not report.victory:
		return []
	var eligible: Array[CharacterRunState] = []
	for value in character_states:
		var state := value as CharacterRunState
		if state != null and state.unit != null and state.unit.is_alive:
			eligible.append(state)
	if eligible.is_empty():
		return []
	var target_index: int = maxi(report.room_index, 0) % eligible.size()
	var target_state := eligible[target_index]
	return [
		_option(TEAM_HEAL, &"", "Toute l’équipe"),
		_option(
			HERO_MAX_HP,
			target_state.character_id,
			target_state.unit.unit_name,
		),
		_option(NEXT_SHIELD, &"", "Toute l’équipe"),
	]


func apply(
		report: CombatReport,
		reward: PostCombatRewardData,
		target_character_id: StringName,
		character_states: Array,
		pending_next_combat_shields: Dictionary
	) -> Dictionary:
	if report == null or not report.finalized or not report.victory:
		return _failure("COMBAT_REPORT_INVALID", "Rapport de victoire indisponible.")
	if _applied_report_ids.has(report.report_id):
		return _failure("REWARD_ALREADY_APPLIED", "Une récompense a déjà été appliquée.")
	if reward == null or not reward.is_valid():
		return _failure("REWARD_INVALID", "Récompense invalide.")
	var states := _state_map(character_states)
	var details: Dictionary
	match reward.reward_type:
		PostCombatRewardData.RewardType.TEAM_HEAL_PERCENT:
			details = _apply_team_heal(reward, states)
		PostCombatRewardData.RewardType.HERO_MAX_HP:
			details = _apply_hero_max_hp(
				report,
				reward,
				target_character_id,
				states,
			)
		PostCombatRewardData.RewardType.NEXT_COMBAT_SHIELD:
			details = _store_next_combat_shield(
				reward,
				states,
				pending_next_combat_shields,
			)
		_:
			return _failure("REWARD_TYPE_UNSUPPORTED", "Type de récompense non pris en charge.")
	if not details.get("success", false):
		return details
	_applied_report_ids[report.report_id] = true
	details["report_id"] = report.report_id
	details["reward_id"] = reward.reward_id
	details["target_character_id"] = target_character_id
	return details


func consume_next_combat_shields(
		character_states: Array,
		pending_next_combat_shields: Dictionary
	) -> Dictionary:
	var applied := {}
	var states := _state_map(character_states)
	for key in pending_next_combat_shields.keys().duplicate():
		var character_id := StringName(key)
		var state := states.get(character_id) as CharacterRunState
		var value := maxi(0, int(pending_next_combat_shields.get(key, 0)))
		pending_next_combat_shields.erase(key)
		if state == null or state.unit == null or not state.unit.is_alive or value <= 0:
			continue
		state.unit.clear_shield()
		state.unit.add_shield(value)
		applied[str(character_id)] = value
	return applied


func has_applied(report_id: StringName) -> bool:
	return _applied_report_ids.has(report_id)


func _option(
		reward: PostCombatRewardData,
		target_character_id: StringName,
		target_name: String
	) -> Dictionary:
	return {
		"reward": reward,
		"reward_id": reward.reward_id,
		"target_character_id": target_character_id,
		"target_name": target_name,
	}


func _state_map(character_states: Array) -> Dictionary:
	var result := {}
	for value in character_states:
		var state := value as CharacterRunState
		if state != null:
			result[state.character_id] = state
	return result


func _apply_team_heal(
		reward: PostCombatRewardData,
		states: Dictionary
	) -> Dictionary:
	var healed := {}
	for character_id in states:
		var state := states[character_id] as CharacterRunState
		if state == null or state.unit == null or not state.unit.is_alive:
			continue
		var unit := state.unit
		var before := unit.current_hp
		var amount := maxi(1, int(round(unit.max_hp.get_int() * reward.value)))
		unit.heal(amount)
		healed[str(character_id)] = unit.current_hp - before
	return {"success": true, "healed": healed}


func _apply_hero_max_hp(
		report: CombatReport,
		reward: PostCombatRewardData,
		target_character_id: StringName,
		states: Dictionary
	) -> Dictionary:
	var state := states.get(target_character_id) as CharacterRunState
	if state == null or state.unit == null or not state.unit.is_alive:
		return _failure("REWARD_TARGET_INVALID", "Le héros ciblé est indisponible.")
	var amount := maxi(1, int(round(reward.value)))
	var unit := state.unit
	var max_before := unit.max_hp.get_int()
	var hp_before := unit.current_hp
	unit.max_hp.add_modifier(
		amount,
		Stat.ModType.FLAT,
		"post_combat_%s_%s" % [report.report_id, reward.reward_id],
	)
	unit.current_hp = mini(unit.current_hp + amount, unit.max_hp.get_int())
	unit.hp_changed.emit(unit)
	unit.stats_changed.emit(unit)
	return {
		"success": true,
		"max_hp_before": max_before,
		"max_hp_after": unit.max_hp.get_int(),
		"hp_before": hp_before,
		"hp_after": unit.current_hp,
	}


func _store_next_combat_shield(
		reward: PostCombatRewardData,
		states: Dictionary,
		pending_next_combat_shields: Dictionary
	) -> Dictionary:
	var stored := {}
	var amount := maxi(1, int(round(reward.value)))
	for character_id in states:
		var state := states[character_id] as CharacterRunState
		if state == null or state.unit == null or not state.unit.is_alive:
			continue
		var previous := int(pending_next_combat_shields.get(character_id, 0))
		var kept := maxi(previous, amount)
		pending_next_combat_shields[character_id] = kept
		stored[str(character_id)] = kept
	return {"success": true, "stored_shields": stored}


func _failure(code: String, message: String) -> Dictionary:
	return {
		"success": false,
		"error_code": code,
		"error": message,
	}
