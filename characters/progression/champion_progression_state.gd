class_name ChampionProgressionState
extends RefCounted

const SCHEMA_VERSION := 1
const STAT_SOURCE := "champion_progression"

var profile: ChampionProgressionProfile = null
var mastery_catalog: MasteryCatalogData = null
var unit: Unit = null
var current_xp: int = 0
var current_level: int = 1
var current_hp: int = 0
var unspent_attribute_points: int = 0
var unspent_mastery_points: int = 0
var vitality_points: int = 0
var power_points: int = 0
var resolve_points: int = 0
var wisdom_points: int = 0
var purchased_mastery_points: int = 0
var selected_node_ids: Array[StringName] = []
var selected_capstone_ids: Array[StringName] = []
var selected_specialist_summit_id: StringName = &""
var selected_mythic_junction_id: StringName = &""
var selected_apotheosis_id: StringName = &""
var encounter_start_wisdom: int = 0
var awarded_encounter_ids: Array[StringName] = []
var _original_max_hp_base: float = 0.0
var _original_prowess_base: float = 0.0
var _previous_shield_creation_multiplier: float = 1.0


func initialize(p_profile: ChampionProgressionProfile, p_unit: Unit, p_mastery_catalog: MasteryCatalogData = null) -> bool:
	if p_profile == null or p_unit == null or not p_profile.is_valid():
		return false
	profile = p_profile
	mastery_catalog = p_mastery_catalog
	unit = p_unit
	_original_max_hp_base = unit.max_hp.base_value
	_original_prowess_base = unit.attack_power.base_value
	_previous_shield_creation_multiplier = unit.shield_creation_multiplier
	current_xp = 0
	current_level = 1
	unspent_attribute_points = 0
	unspent_mastery_points = 0
	vitality_points = 0
	power_points = 0
	resolve_points = 0
	wisdom_points = 0
	purchased_mastery_points = 0
	selected_node_ids.clear()
	selected_capstone_ids.clear()
	selected_specialist_summit_id = &""
	selected_mythic_junction_id = &""
	selected_apotheosis_id = &""
	encounter_start_wisdom = 0
	awarded_encounter_ids.clear()
	_apply_effective_stats(false)
	current_hp = unit.current_hp
	return true


func dispose() -> void:
	if unit != null:
		unit.max_hp.remove_modifiers_from(STAT_SOURCE)
		unit.attack_power.remove_modifiers_from(STAT_SOURCE)
		unit.armure.remove_modifiers_from(STAT_SOURCE)
		unit.max_hp.base_value = _original_max_hp_base
		unit.attack_power.base_value = _original_prowess_base
		unit.shield_creation_multiplier = _previous_shield_creation_multiplier
		unit.current_hp = mini(unit.current_hp, unit.max_hp.get_int())
		unit.stats_changed.emit(unit)
		unit.hp_changed.emit(unit)
	profile = null
	mastery_catalog = null
	unit = null


func begin_encounter() -> void:
	encounter_start_wisdom = clampi(
		wisdom_points, 0, profile.wisdom_cap if profile != null else 0
	)
	if unit != null:
		current_hp = unit.current_hp


func award_encounter_xp(
		encounter_id: StringName,
		base_xp: int,
		victory: bool,
		glory_accepted: bool = false,
		glory_succeeded: bool = false
	) -> Dictionary:
	if profile == null or unit == null or encounter_id == &"" or base_xp < 0:
		return _award_failure(&"INVALID_ENCOUNTER_XP")
	if not victory:
		return _award_failure(&"ENCOUNTER_NOT_WON")
	if glory_succeeded and not glory_accepted:
		return _award_failure(&"GLORY_NOT_ACCEPTED")
	if awarded_encounter_ids.has(encounter_id):
		return _award_failure(&"ENCOUNTER_ALREADY_AWARDED")
	var gained_xp := profile.encounter_xp(
		base_xp,
		encounter_start_wisdom,
		glory_accepted,
		glory_succeeded,
	)
	var xp_before := current_xp
	var level_before := current_level
	var hp_before := unit.current_hp
	var prowess_before := unit.attack_power.get_int()
	var wisdom_multiplier := (
		1.0 + profile.wisdom_bonus_per_point * float(encounter_start_wisdom)
	)
	var xp_after_wisdom := int(round(float(base_xp) * wisdom_multiplier))
	var glory_multiplier := (
		profile.glory_success_multiplier
		if glory_accepted and glory_succeeded else 1.0
	)
	current_xp += gained_xp
	current_level = profile.level_for_xp(current_xp)
	var attribute_rewards := (
		profile.attribute_points_through_level(current_level)
		- profile.attribute_points_through_level(level_before)
	)
	var mastery_rewards := (
		profile.mastery_points_through_level(current_level)
		- profile.mastery_points_through_level(level_before)
	)
	unspent_attribute_points += attribute_rewards
	unspent_mastery_points += mastery_rewards
	awarded_encounter_ids.append(encounter_id)
	_apply_effective_stats(true)
	current_hp = unit.current_hp
	return {
		"granted": true,
		"refusal_reason": &"",
		"encounter_id": encounter_id,
		"base_xp": base_xp,
		"victory": victory,
		"wisdom_at_start": encounter_start_wisdom,
		"wisdom_points_at_encounter_start": encounter_start_wisdom,
		"wisdom_multiplier": wisdom_multiplier,
		"wisdom_bonus_xp": xp_after_wisdom - base_xp,
		"glory_accepted": glory_accepted,
		"glory_succeeded": glory_succeeded,
		"glory_multiplier": glory_multiplier,
		"glory_bonus_xp": gained_xp - xp_after_wisdom,
		"gained_xp": gained_xp,
		"xp_before": xp_before,
		"xp_after": current_xp,
		"level_before": level_before,
		"level_after": current_level,
		"levels_gained": current_level - level_before,
		"multiple_levels": current_level - level_before > 1,
		"reached_levels": range(level_before + 1, current_level + 1),
		"attribute_points_gained": attribute_rewards,
		"mastery_points_gained": mastery_rewards,
		"hp_before": hp_before,
		"hp_after": unit.current_hp,
		"hp_delta": unit.current_hp - hp_before,
		"max_hp_after": unit.max_hp.get_int(),
		"prowess_before": prowess_before,
		"prowess_after": unit.attack_power.get_int(),
	}


func spend_attribute(attribute_id: StringName) -> bool:
	if profile == null or unit == null or unspent_attribute_points <= 0:
		return false
	match attribute_id:
		ChampionProgressionProfile.ATTRIBUTE_VITALITY:
			vitality_points += 1
		ChampionProgressionProfile.ATTRIBUTE_POWER:
			power_points += 1
		ChampionProgressionProfile.ATTRIBUTE_RESOLVE:
			resolve_points += 1
		ChampionProgressionProfile.ATTRIBUTE_WISDOM:
			if wisdom_points >= profile.wisdom_cap:
				return false
			wisdom_points += 1
		_:
			return false
	unspent_attribute_points -= 1
	_apply_effective_stats(true)
	current_hp = unit.current_hp
	return true


func grant_purchased_mastery(amount: int = 1) -> bool:
	if profile == null \
			or amount <= 0 \
			or purchased_mastery_points + amount > profile.purchased_mastery_cap:
		return false
	purchased_mastery_points += amount
	unspent_mastery_points += amount
	return true


func purchase_mastery_node(
		node: SkillTreeNodeData,
		doctrines: Array[DisciplineData],
		advanced_nodes: Array[SkillTreeNodeData] = []
	) -> Dictionary:
	if mastery_catalog != null:
		if mastery_catalog.node_catalog().get(node.upgrade_id if node != null else &"") != node:
			return {"allowed": false, "purchased": false, "reason_id": "INVALID_NODE"}
		doctrines = mastery_catalog.doctrines
		advanced_nodes = mastery_catalog.get_advanced_nodes()
	var decision := SkillTreeResolver.evaluate_mastery_purchase(
		node,
		doctrines,
		advanced_nodes,
		current_level,
		unspent_mastery_points,
		selected_node_ids,
		profile,
	)
	if not bool(decision.get("allowed", false)):
		return decision
	unspent_mastery_points -= node.mastery_cost
	selected_node_ids.append(node.upgrade_id)
	match node.node_type:
		SkillTreeNodeData.NodeType.CAPSTONE:
			selected_capstone_ids.append(node.upgrade_id)
		SkillTreeNodeData.NodeType.SPECIALIST_SUMMIT:
			selected_specialist_summit_id = node.upgrade_id
		SkillTreeNodeData.NodeType.MYTHIC_JUNCTION:
			selected_mythic_junction_id = node.upgrade_id
		SkillTreeNodeData.NodeType.APOTHEOSIS:
			selected_apotheosis_id = node.upgrade_id
	decision["purchased"] = true
	decision["unspent_mastery_points"] = unspent_mastery_points
	decision["selected_node_ids"] = selected_node_ids.duplicate()
	return decision


func get_shield_creation_multiplier() -> float:
	if profile == null:
		return 1.0
	return 1.0 + profile.resolve_shield_percent_per_point * float(resolve_points)


func to_snapshot() -> Dictionary:
	if unit != null:
		current_hp = unit.current_hp
	return {
		"schema_version": SCHEMA_VERSION,
		"current_xp": current_xp,
		"current_level": current_level,
		"current_hp": current_hp,
		"unspent_attribute_points": unspent_attribute_points,
		"unspent_mastery_points": unspent_mastery_points,
		"vitality_points": vitality_points,
		"power_points": power_points,
		"resolve_points": resolve_points,
		"wisdom_points": wisdom_points,
		"purchased_mastery_points": purchased_mastery_points,
		"selected_node_ids": _ids_to_strings(selected_node_ids),
		"selected_capstone_ids": _ids_to_strings(selected_capstone_ids),
		"selected_specialist_summit_id": str(selected_specialist_summit_id),
		"selected_mythic_junction_id": str(selected_mythic_junction_id),
		"selected_apotheosis_id": str(selected_apotheosis_id),
		"encounter_start_wisdom": encounter_start_wisdom,
		"awarded_encounter_ids": _ids_to_strings(awarded_encounter_ids),
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	if profile == null or unit == null:
		return false
	var parsed := _parse_snapshot(snapshot)
	if not bool(parsed.get("ok", false)):
		return false
	var original := to_snapshot()
	var original_is_alive := unit.is_alive
	_assign_snapshot(parsed)
	_apply_effective_stats(false)
	var restored_hp := int(parsed.get("current_hp", -1))
	if restored_hp < 0 or restored_hp > unit.max_hp.get_int():
		_assign_snapshot(original)
		_apply_effective_stats(false)
		unit.current_hp = int(original.get("current_hp", unit.current_hp))
		unit.is_alive = original_is_alive
		current_hp = unit.current_hp
		return false
	unit.current_hp = restored_hp
	unit.is_alive = restored_hp > 0
	current_hp = restored_hp
	unit.hp_changed.emit(unit)
	return true


func _apply_effective_stats(add_max_hp_delta: bool) -> void:
	if profile == null or unit == null:
		return
	var previous_max_hp := unit.max_hp.get_int()
	var previous_hp := unit.current_hp
	unit.max_hp.remove_modifiers_from(STAT_SOURCE)
	unit.attack_power.remove_modifiers_from(STAT_SOURCE)
	unit.armure.remove_modifiers_from(STAT_SOURCE)
	unit.max_hp.base_value = profile.base_hp_for_level(current_level)
	unit.attack_power.base_value = profile.base_prowess_for_level(current_level)
	if vitality_points > 0:
		unit.max_hp.add_modifier(
			profile.base_hp_for_level(current_level) * profile.vitality_hp_percent_per_point * float(vitality_points),
			Stat.ModType.FLAT,
			STAT_SOURCE,
		)
	if power_points > 0:
		unit.attack_power.add_modifier(
			profile.power_prowess_percent_per_point * float(power_points),
			Stat.ModType.PERCENT,
			STAT_SOURCE,
		)
	if resolve_points > 0:
		unit.armure.add_modifier(
			float(profile.resolve_armor_per_point * resolve_points),
			Stat.ModType.FLAT,
			STAT_SOURCE,
		)
	unit.shield_creation_multiplier = get_shield_creation_multiplier()
	var new_max_hp := unit.max_hp.get_int()
	if add_max_hp_delta and new_max_hp > previous_max_hp:
		unit.current_hp = mini(
			new_max_hp, previous_hp + new_max_hp - previous_max_hp
		)
	else:
		unit.current_hp = mini(previous_hp, new_max_hp)
	unit.stats_changed.emit(unit)
	unit.hp_changed.emit(unit)


func _parse_snapshot(snapshot: Dictionary) -> Dictionary:
	if int(snapshot.get("schema_version", -1)) != SCHEMA_VERSION:
		return {"ok": false}
	var parsed := snapshot.duplicate(true)
	var restored_xp := int(parsed.get("current_xp", -1))
	var restored_level := int(parsed.get("current_level", 0))
	var restored_hp := int(parsed.get("current_hp", -1))
	if restored_xp < 0 \
			or restored_hp < 0 \
			or restored_level != profile.level_for_xp(restored_xp):
		return {"ok": false}
	for key in [
		"unspent_attribute_points",
		"unspent_mastery_points",
		"vitality_points",
		"power_points",
		"resolve_points",
		"wisdom_points",
		"purchased_mastery_points",
	]:
		if int(parsed.get(key, -1)) < 0:
			return {"ok": false}
	if int(parsed.get("purchased_mastery_points", -1)) \
			> profile.purchased_mastery_cap:
		return {"ok": false}
	if int(parsed.get("wisdom_points", -1)) > profile.wisdom_cap:
		return {"ok": false}
	var spent_attributes := (
		int(parsed.get("vitality_points", 0))
		+ int(parsed.get("power_points", 0))
		+ int(parsed.get("resolve_points", 0))
		+ int(parsed.get("wisdom_points", 0))
	)
	if spent_attributes + int(parsed.get("unspent_attribute_points", 0)) \
			!= profile.attribute_points_through_level(restored_level):
		return {"ok": false}
	var available_mastery := (
		profile.mastery_points_through_level(restored_level)
		+ int(parsed.get("purchased_mastery_points", 0))
	)
	if int(parsed.get("unspent_mastery_points", 0)) > available_mastery:
		return {"ok": false}
	var selected_result := _parse_unique_ids(parsed.get("selected_node_ids", []))
	var capstones_result := _parse_unique_ids(
		parsed.get("selected_capstone_ids", [])
	)
	var awarded_result := _parse_unique_ids(
		parsed.get("awarded_encounter_ids", [])
	)
	if not bool(selected_result.get("ok", false)) \
			or not bool(capstones_result.get("ok", false)) \
			or not bool(awarded_result.get("ok", false)):
		return {"ok": false}
	var selected: Array[StringName] = selected_result.get("values", [])
	var capstones: Array[StringName] = capstones_result.get("values", [])
	var awarded: Array[StringName] = awarded_result.get("values", [])
	for capstone_id in capstones:
		if not selected.has(capstone_id):
			return {"ok": false}
	for key in [
		"selected_specialist_summit_id",
		"selected_mythic_junction_id",
		"selected_apotheosis_id",
	]:
		var node_id := StringName(parsed.get(key, &""))
		if node_id != &"" and not selected.has(node_id):
			return {"ok": false}
	var wisdom_snapshot := int(parsed.get("encounter_start_wisdom", -1))
	if wisdom_snapshot < 0 or wisdom_snapshot > profile.wisdom_cap:
		return {"ok": false}
	parsed["selected_node_ids"] = selected
	parsed["selected_capstone_ids"] = capstones
	parsed["awarded_encounter_ids"] = awarded
	if mastery_catalog != null and not _validate_mastery_snapshot(parsed):
		return {"ok": false}
	parsed["ok"] = true
	return parsed


func _assign_snapshot(snapshot: Dictionary) -> void:
	current_xp = int(snapshot.get("current_xp", 0))
	current_level = int(snapshot.get("current_level", 1))
	current_hp = int(snapshot.get("current_hp", 0))
	unspent_attribute_points = int(snapshot.get("unspent_attribute_points", 0))
	unspent_mastery_points = int(snapshot.get("unspent_mastery_points", 0))
	vitality_points = int(snapshot.get("vitality_points", 0))
	power_points = int(snapshot.get("power_points", 0))
	resolve_points = int(snapshot.get("resolve_points", 0))
	wisdom_points = int(snapshot.get("wisdom_points", 0))
	purchased_mastery_points = int(snapshot.get("purchased_mastery_points", 0))
	selected_node_ids = _variant_to_unique_ids(snapshot.get("selected_node_ids", []))
	selected_capstone_ids = _variant_to_unique_ids(snapshot.get("selected_capstone_ids", []))
	selected_specialist_summit_id = StringName(snapshot.get(
		"selected_specialist_summit_id", &""
	))
	selected_mythic_junction_id = StringName(snapshot.get(
		"selected_mythic_junction_id", &""
	))
	selected_apotheosis_id = StringName(snapshot.get(
		"selected_apotheosis_id", &""
	))
	encounter_start_wisdom = int(snapshot.get("encounter_start_wisdom", 0))
	awarded_encounter_ids = _variant_to_unique_ids(snapshot.get(
		"awarded_encounter_ids", []
	))


func _award_failure(reason: StringName) -> Dictionary:
	return {
		"granted": false,
		"refusal_reason": reason,
		"gained_xp": 0,
		"xp_after": current_xp,
		"level_before": current_level,
		"level_after": current_level,
	}


func _ids_to_strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


func _variant_to_unique_ids(values: Variant) -> Array[StringName]:
	var parsed := _parse_unique_ids(values)
	return parsed.get("values", []) if bool(parsed.get("ok", false)) else []


func _parse_unique_ids(values: Variant) -> Dictionary:
	var result: Array[StringName] = []
	if not values is Array:
		return {"ok": false, "values": result}
	for value in values:
		if not value is String and not value is StringName:
			return {"ok": false, "values": []}
		var converted := StringName(value)
		if converted == &"" or result.has(converted):
			return {"ok": false, "values": []}
		result.append(converted)
	return {"ok": true, "values": result}


## Valide le budget et rejoue les preconditions sans toucher a l'unite.
## Les identifiants sauvegardes ne deviennent jamais des autorites de gameplay.
func _validate_mastery_snapshot(snapshot: Dictionary) -> bool:
	var catalog := mastery_catalog.node_catalog()
	var selected: Array[StringName] = snapshot.get("selected_node_ids", [])
	var remaining: Array[StringName] = selected.duplicate()
	var restored_level := int(snapshot.get("current_level", 1))
	var available := profile.mastery_points_through_level(restored_level) + int(snapshot.get("purchased_mastery_points", 0))
	var spent := 0
	var expected_capstones: Array[StringName] = []
	var expected_advanced := {"selected_specialist_summit_id": &"", "selected_mythic_junction_id": &"", "selected_apotheosis_id": &""}
	for node_id in selected:
		var node := catalog.get(node_id) as SkillTreeNodeData
		if node == null:
			return false
		spent += node.mastery_cost
		match node.node_type:
			SkillTreeNodeData.NodeType.CAPSTONE:
				expected_capstones.append(node_id)
			SkillTreeNodeData.NodeType.SPECIALIST_SUMMIT:
				if expected_advanced.selected_specialist_summit_id != &"":
					return false
				expected_advanced.selected_specialist_summit_id = node_id
			SkillTreeNodeData.NodeType.MYTHIC_JUNCTION:
				if expected_advanced.selected_mythic_junction_id != &"":
					return false
				expected_advanced.selected_mythic_junction_id = node_id
			SkillTreeNodeData.NodeType.APOTHEOSIS:
				if expected_advanced.selected_apotheosis_id != &"":
					return false
				expected_advanced.selected_apotheosis_id = node_id
	if spent + int(snapshot.get("unspent_mastery_points", -1)) != available:
		return false
	var saved_capstones: Array[StringName] = snapshot.get("selected_capstone_ids", [])
	if expected_capstones.size() != saved_capstones.size():
		return false
	for node_id in expected_capstones:
		if not saved_capstones.has(node_id):
			return false
	for key in expected_advanced:
		if StringName(snapshot.get(key, &"")) != expected_advanced[key]:
			return false
	var accepted: Array[StringName] = []
	while not remaining.is_empty():
		var found := false
		for node_id in remaining.duplicate():
			var node := catalog.get(node_id) as SkillTreeNodeData
			var decision := SkillTreeResolver.evaluate_mastery_purchase(node, mastery_catalog.doctrines, mastery_catalog.get_advanced_nodes(), restored_level, available, accepted, profile)
			if not bool(decision.get("allowed", false)):
				continue
			accepted.append(node_id)
			available -= node.mastery_cost
			remaining.erase(node_id)
			found = true
		if not found:
			return false
	return true
