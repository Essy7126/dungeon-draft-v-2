class_name RelicTacticalIntentExecutor
extends RefCounted

## Resolves declarative relic intents through the shared battle physics.
## Transient state belongs to this combat; source ids keep cleanup precise.
var _grid: GridData
var _caster: SpellCaster
var _adapter = null
var _vengeance: Dictionary = {}
var _next_shot: Dictionary = {}
var _dual: Dictionary = {}
var _followup: Dictionary = {}
var _active_followup: Dictionary = {}
var _armor_sources: Array[Dictionary] = []
var _seen: Dictionary = {}
var _serial := 0
var _resolving := false

class MinimumRangeWaiver:
	extends SpellModifier
	func ignores_minimum_range(_caster, _spell) -> bool:
		return true

func configure(grid: GridData, caster: SpellCaster, adapter) -> void:
	_grid = grid
	_caster = caster
	_adapter = adapter

func handle_intent(intent: Dictionary) -> void:
	execute_intent(intent)

## Public for the shared mastery/relic choice arbiter to execute a selected intent.
func execute_intent(intent: Dictionary) -> void:
	if _resolving or _grid == null:
		return
	var actor := _unit(intent.get("actor_id", &""))
	if actor == null or not actor.is_alive:
		return
	var event_key := "%s:%s:%s:%s:%s:%s" % [intent.get("actor_id", ""),
		intent.get("instance_id", ""), intent.get("intent_id", ""),
		intent.get("effect_index", 0), intent.get("event_serial", 0), intent.get("action_id", "")]
	if _seen.has(event_key):
		return
	_seen[event_key] = true
	_resolving = true
	var params: Dictionary = intent.get("parameters", {})
	match StringName(intent.get("intent_id", &"")):
		&"vengeance_mark":
			var enemy := _unit(intent.get("damage_source_id", &""))
			if enemy != null and enemy.team != actor.team and not _vengeance.has(actor):
				_vengeance[actor] = {"enemy": enemy, "parameters": params.duplicate(true)}
		&"collision_armor_followup":
			_apply_collision_followup(actor, intent, params)
		&"dash_next_shot":
			var spell_id := StringName(params.get("next_ability_id", &""))
			if spell_id != &"":
				_clear_next_shot(actor)
				var source := StringName("relic_shot:%s" % intent.get("instance_id", ""))
				_next_shot[actor] = {"spell_id": spell_id, "parameters": params.duplicate(true), "source": source}
				if bool(params.get("ignore_minimum_range", false)):
					var waiver := MinimumRangeWaiver.new()
					waiver.target_spell_id = spell_id
					var modifiers: Array[SpellModifier] = [waiver]
					actor.set_equipment_spell_modifiers(source, modifiers)
		&"projectile_counter":
			var attacker := _unit(intent.get("damage_source_id", &""))
			var amount := int(round(int(intent.get("amount_absorbed", 0)) * float(params.get("reflect_ratio", 0.0))))
			_deal_damage(actor, attacker, amount, intent, &"PROJECTILE")
		&"dual_technique":
			_arm_dual(actor, intent, params)
		&"guard_dash_conversion":
			_convert_guard(actor, intent, params)
	_resolving = false

func on_before_hit(target: Unit, ctx: DamageResolver.HitContext) -> void:
	if target == null or ctx == null:
		return
	var actor := ctx.attacker as Unit
	# Secondary relic impacts cannot recursively consume or re-arm relic effects.
	if str(ctx.action_id).begins_with("relic:"):
		return
	var defensive: Dictionary = _vengeance.get(target, {})
	if not defensive.is_empty() and actor != null and defensive.get("enemy") == actor:
		ctx.guard_damage_multiplier /= maxf(0.01, 1.0 + float(defensive.parameters.get("guard_bonus", 0.0)))
	if actor == null:
		return
	var damage_multiplier := 1.0
	var marked: Dictionary = _vengeance.get(actor, {})
	if marked.get("enemy") == target:
		damage_multiplier *= 1.0 + float(marked.parameters.get("damage_bonus", 0.0))
	var shot: Dictionary = _next_shot.get(actor, {})
	if StringName(shot.get("spell_id", &"")) == ctx.ability_id and not shot.is_empty():
		damage_multiplier *= 1.0 + float(shot.parameters.get("damage_bonus", 0.0))
	var dual: Dictionary = _dual.get(actor, {})
	if not bool(dual.get("consumed", true)) and StringName(dual.get("spell_id", &"")) == ctx.ability_id:
		damage_multiplier *= 1.0 + float(dual.parameters.get("damage_bonus", 0.0))
		ctx.pen_flat += float(dual.parameters.get("armor_ignore", 0))
		dual["active_action"] = ctx.action_id
	ctx.raw_damage = maxi(0, int(round(float(ctx.raw_damage) * damage_multiplier)))
	var followup: Dictionary = _followup.get(actor, {})
	if not followup.is_empty() and StringName(followup.parameters.get("followup_ability_id", &"")) == ctx.ability_id:
		var direction := _cardinal(target.grid_pos - actor.grid_pos)
		_active_followup[actor] = {"intent": followup.intent, "parameters": followup.parameters,
			"action_id": ctx.action_id, "spell_id": ctx.ability_id,
			"cell": target.grid_pos + direction * int(followup.parameters.get("behind_cells", 1)),
			"raw_damage": ctx.raw_damage}
		_followup.erase(actor)

func on_hit(_fact: CombatEventFact) -> void:
	pass

func on_spell_completed(actor: Unit, spell: Spell, report: Dictionary) -> void:
	if actor == null or spell == null or bool(report.get("automatic", false)):
		return
	var spell_id := spell.get_effective_spell_id()
	var shot: Dictionary = _next_shot.get(actor, {})
	if StringName(shot.get("spell_id", &"")) == spell_id:
		_clear_next_shot(actor)
	var dual: Dictionary = _dual.get(actor, {})
	if StringName(dual.get("spell_id", &"")) == spell_id:
		dual["consumed"] = true
	var followup: Dictionary = _active_followup.get(actor, {})
	if not followup.is_empty() and StringName(followup.spell_id) == spell_id:
		_active_followup.erase(actor)
		var target := _grid.get_unit(followup.cell) as Unit
		var damage := int(round(float(followup.raw_damage) * float(followup.parameters.get("followup_ratio", 0.0))))
		_deal_damage(actor, target, damage, followup.intent, &"MELEE")

func on_movement(_actor: Unit, _movement: Dictionary) -> void:
	pass

func on_activation_started(unit: Unit) -> void:
	_clear_next_shot(unit)
	_dual.erase(unit)

func on_activation_ended(unit: Unit) -> void:
	_clear_next_shot(unit)
	_dual.erase(unit)

func dispose() -> void:
	for unit in _next_shot.keys():
		_clear_next_shot(unit)
	for entry in _armor_sources:
		var target := entry.target as Unit
		if is_instance_valid(target):
			target.armure.remove_modifiers_from(entry.source)
	_armor_sources.clear()
	_vengeance.clear()
	_dual.clear()
	_followup.clear()
	_active_followup.clear()
	_seen.clear()
	_grid = null
	_caster = null
	_adapter = null

func _apply_collision_followup(actor: Unit, intent: Dictionary, params: Dictionary) -> void:
	var victim := _unit(intent.get("event_target_id", &""))
	if victim == null or victim.team == actor.team:
		return
	var source := "relic_armor:%s:%s" % [intent.get("instance_id", ""), actor.get_runtime_stable_id()]
	victim.armure.remove_modifiers_from(source)
	victim.armure.add_modifier(-float(params.get("armor_loss", 0)), Stat.ModType.FLAT, source)
	var registered := false
	for entry in _armor_sources:
		if entry.target == victim and entry.source == source:
			registered = true
	if not registered:
		_armor_sources.append({"target": victim, "source": source})
	_followup[actor] = {"intent": intent.duplicate(true), "parameters": params.duplicate(true)}

func _arm_dual(actor: Unit, intent: Dictionary, params: Dictionary) -> void:
	if _dual.has(actor):
		return
	var used := StringName(intent.get("spell_id", &""))
	var first := StringName(params.get("first_ability_id", &""))
	var second := StringName(params.get("second_ability_id", &""))
	if used not in [first, second] or first == &"" or second == &"":
		return
	_dual[actor] = {"spell_id": second if used == first else first,
		"parameters": params.duplicate(true), "consumed": false}

func _convert_guard(actor: Unit, intent: Dictionary, params: Dictionary) -> void:
	var snapshot := actor.get_shield_instances_snapshot()
	var consumed := 0
	for entry in snapshot:
		var tags: Array = entry.get("tags", [])
		if not tags.has("guard") and not tags.has(&"guard"):
			continue
		var current := int(entry.get("value", 0))
		var amount := clampi(int(round(current * float(params.get("guard_consume_ratio", 0.0)))), 0, current)
		entry["value"] = current - amount
		consumed += amount
	if consumed <= 0:
		return
	snapshot = snapshot.filter(func(entry: Dictionary) -> bool: return int(entry.get("value", 0)) > 0)
	actor.restore_shield_instances_snapshot(snapshot)
	var targets: Array[Unit] = []
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var target := _grid.get_unit(actor.grid_pos + direction) as Unit
		if target != null and target.is_alive and target.team != actor.team:
			targets.append(target)
	for target in targets:
		if bool(params.get("damage_equals_consumed", false)):
			_deal_damage(actor, target, consumed, intent, &"MELEE")
		if target.is_alive and _caster != null:
			var movement: Array = []
			_caster._push_unit(actor, target, maxi(0, int(params.get("push_distance", 0))), 0, movement)
			for entry in movement:
				if _adapter == null:
					continue
				_adapter.dispatch(actor, &"collision" if entry.get("collision", false) else &"unit_moved", {
					"target": entry.get("unit"), "forced_move": true, "collision": entry.get("collision", false),
					"spell_id": intent.get("spell_id", &""), "action_id": intent.get("action_id", &""),
				})

func _deal_damage(actor: Unit, target: Unit, amount: int, intent: Dictionary, classification: StringName) -> void:
	if actor == null or target == null or not target.is_alive or target.team == actor.team or amount <= 0:
		return
	_serial += 1
	var hit := DamageResolver.HitContext.new()
	hit.attacker = actor
	hit.raw_damage = amount
	hit.action_id = StringName("relic:%s:%d" % [intent.get("instance_id", ""), _serial])
	hit.cast_id = hit.action_id
	hit.impact_id = StringName("%s:%s" % [hit.action_id, target.get_runtime_stable_id()])
	hit.ability_id = StringName(intent.get("spell_id", &""))
	if hit.ability_id == &"":
		var params: Dictionary = intent.get("parameters", {})
		hit.ability_id = StringName(params.get("followup_ability_id", intent.get("item_id", &"")))
	hit.attack_classification = classification
	var was_resolving := _resolving
	_resolving = true
	target.take_hit(hit)
	_resolving = was_resolving

func _clear_next_shot(actor: Unit) -> void:
	var state: Dictionary = _next_shot.get(actor, {})
	if not state.is_empty() and is_instance_valid(actor):
		actor.clear_equipment_spell_modifiers(StringName(state.source))
	_next_shot.erase(actor)

func _unit(stable_id: Variant) -> Unit:
	if _grid == null or str(stable_id).is_empty():
		return null
	for value in _grid.get_units():
		var unit := value as Unit
		if unit != null and str(unit.get_runtime_stable_id()) == str(stable_id):
			return unit
	return null

func _cardinal(delta: Vector2i) -> Vector2i:
	return Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
