class_name EncounterRuntimeState
extends RefCounted

var definition: EncounterDefinition = null
var normal_summons_committed := 0
var chief_summons_committed := 0
var _pending_by_caster: Dictionary = {}


func initialize(source: EncounterDefinition) -> bool:
	definition = source
	normal_summons_committed = 0
	chief_summons_committed = 0
	_pending_by_caster.clear()
	return definition != null and definition.is_valid()


func can_prepare_summon(
		caster: Unit,
		spell: Spell,
		living_enemy_count: int
	) -> StringName:
	if definition == null or caster == null or spell == null or not spell.is_summon():
		return &"encounter_state"
	var ability_id := spell.get_effective_spell_id()
	if not definition.is_ability_enabled(ability_id):
		return &"ability_disabled"
	var caster_id := caster.get_runtime_stable_id()
	if _pending_by_caster.has(caster_id):
		return &"pending_summon"
	if living_enemy_count >= definition.living_enemy_cap:
		return &"team_limit"
	match spell.summon_type:
		&"normal":
			if normal_summons_committed >= definition.shared_normal_summon_budget:
				return &"normal_summon_budget"
		&"chief":
			if chief_summons_committed >= definition.shared_chief_summon_budget:
				return &"chief_summon_budget"
		_:
			return &"summon_type"
	return &""


func commit_prepared_summon(caster: Unit, spell: Spell) -> bool:
	if caster == null or spell == null:
		return false
	var caster_id := caster.get_runtime_stable_id()
	if _pending_by_caster.has(caster_id):
		return false
	_pending_by_caster[caster_id] = spell.summon_type
	match spell.summon_type:
		&"normal": normal_summons_committed += 1
		&"chief": chief_summons_committed += 1
		_: return false
	return true


func clear_pending(caster: Unit) -> void:
	if caster != null:
		_pending_by_caster.erase(caster.get_runtime_stable_id())


func has_pending(caster: Unit) -> bool:
	return caster != null and _pending_by_caster.has(caster.get_runtime_stable_id())


func get_remaining_budget(summon_type: StringName) -> int:
	if definition == null:
		return 0
	match summon_type:
		&"normal":
			return maxi(0, definition.shared_normal_summon_budget - normal_summons_committed)
		&"chief":
			return maxi(0, definition.shared_chief_summon_budget - chief_summons_committed)
	return 0


func snapshot() -> Dictionary:
	return {
		"room_index": definition.room_index if definition != null else -1,
		"living_enemy_cap": definition.living_enemy_cap if definition != null else 0,
		"normal_summons_committed": normal_summons_committed,
		"chief_summons_committed": chief_summons_committed,
		"normal_summons_remaining": get_remaining_budget(&"normal"),
		"chief_summons_remaining": get_remaining_budget(&"chief"),
		"pending_count": _pending_by_caster.size(),
	}
