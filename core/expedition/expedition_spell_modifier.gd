class_name ExpeditionSpellModifier
extends SpellModifier

## These effects are opt-in to experimental Spell resources. They do not alter
## historical Achilles spells, incoming damage facts or equipment heal semantics.
const HEAL_BUDGET_META := &"expedition_heal_remaining"
const ENTRY_HP_META := &"expedition_entry_max_hp"

@export var sacrifice_fraction: float = 0.0
@export var heal_fraction: float = 0.0
@export var lifesteal_fraction: float = 0.0
@export var lifesteal_cap_fraction: float = 0.05
@export var self_status: StatusData = null
@export var cleanse_movement: bool = false
@export var temporary_stats: Dictionary = {}
@export var next_activation_mp_penalty: int = 0


func get_target_cell_failure_reason(caster, _spell, _cell: Vector2i, _grid) -> StringName:
	if caster == null:
		return &"caster"
	if sacrifice_fraction > 0.0 and caster.current_hp <= _sacrifice(caster):
		return &"sacrifice_non_lethal"
	if heal_fraction > 0.0 and int(caster.get_meta(HEAL_BUDGET_META, 0)) <= 0:
		return &"healing_reserve_empty"
	return &""


func on_costs_resolved(ctx) -> void:
	if sacrifice_fraction <= 0.0:
		return
	# A cost, not an enemy hit: no damage, dodge, retaliation or lifesteal events.
	var paid := mini(_sacrifice(ctx.caster), maxi(0, ctx.caster.current_hp - 1))
	ctx.caster.current_hp -= paid
	ctx.caster.hp_changed.emit(ctx.caster)
	ctx.set_meta("expedition_sacrifice_paid", paid)


func get_heal_amount(caster, spell, base_amount: int) -> int:
	if heal_fraction <= 0.0:
		return base_amount
	if not caster is Unit:
		return 0
	var available: int = int(caster.get_meta(HEAL_BUDGET_META,
		int(floor(caster.max_hp.get_value() * 0.20))))
	return mini(maxi(0, _requested_heal(caster) + base_amount - spell.heal), maxi(0, available))


func on_damage_resolved(ctx) -> void:
	if heal_fraction > 0.0 and ctx.spell.is_healing():
		_spend_heal(ctx.caster, int(ctx.report.get("healing_total", 0)))
	elif heal_fraction > 0.0:
		_heal_and_report(ctx, _requested_heal(ctx.caster))
	if lifesteal_fraction > 0.0:
		var enemy_hp_removed := 0
		for target in ctx.damage_result_by_unit:
			if target.team == ctx.caster.team:
				continue
			var result: DamageResolver.DamageResult = ctx.damage_result_by_unit[target]
			enemy_hp_removed += maxi(0, result.hp_damage_applied)
		var cap := int(floor(float(ctx.caster.get_meta(ENTRY_HP_META, 0)) * lifesteal_cap_fraction))
		_heal_and_report(ctx, mini(cap, int(floor(enemy_hp_removed * lifesteal_fraction))))
	if self_status != null:
		ctx.caster.apply_status(self_status, ctx.caster)
	for stat_name in temporary_stats:
		var stat := ctx.caster.get(String(stat_name)) as Stat
		if stat != null:
			var source := "exp_temporary_" + String(stat_name)
			stat.remove_modifiers_from(source)
			stat.add_modifier(float(temporary_stats[stat_name]), Stat.ModType.FLAT, source, 1)
	if next_activation_mp_penalty > 0:
		ctx.caster.queue_next_turn_mp_modifier(-next_activation_mp_penalty)
	if cleanse_movement:
		# Explicit family: movement and AP penalties. No universal cleanse.
		for entry in ctx.caster.active_statuses.duplicate():
			var status: StatusData = entry.get("data")
			if status != null and (status.mp_reduction > 0 or status.ap_reduction > 0):
				ctx.caster.remove_status(status.get_effective_status_id(), entry.get("source"), true)


func _heal_and_report(ctx, requested: int) -> void:
	var before: int = ctx.caster.current_hp
	ctx.caster.heal(mini(requested, _remaining(ctx.caster)), ctx.caster,
		{"ability_id": ctx.spell.get_effective_spell_id(), "action_id": ctx.action_id})
	var actual: int = maxi(0, ctx.caster.current_hp - before)
	_spend_heal(ctx.caster, actual)
	ctx.report["healing_total"] = int(ctx.report.get("healing_total", 0)) + actual
	ctx.report["healing_by_unit"][ctx.caster] = int(ctx.report["healing_by_unit"].get(ctx.caster, 0)) + actual
	if actual > 0 and not ctx.report["healed_units"].has(ctx.caster):
		ctx.report["healed_units"].append(ctx.caster)


func _requested_heal(caster: Unit) -> int:
	return maxi(1, int(floor(float(caster.get_meta(ENTRY_HP_META, caster.max_hp.get_int())) * heal_fraction)))


func _sacrifice(caster: Unit) -> int:
	return maxi(1, int(ceil(caster.max_hp.get_value() * sacrifice_fraction)))


func _remaining(caster: Unit) -> int:
	return maxi(0, int(caster.get_meta(HEAL_BUDGET_META, 0)))


func _spend_heal(caster: Unit, amount: int) -> void:
	caster.set_meta(HEAL_BUDGET_META, maxi(0, _remaining(caster) - amount))
