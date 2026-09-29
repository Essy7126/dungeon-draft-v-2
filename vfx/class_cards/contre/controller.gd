extends RefCounted
## Only current Cards' confirmed counter state and its own damage fact.
const ID := "cc2_counter"


static func handles(entry: Dictionary) -> bool:
	return entry.get("id", "") == "cc2_g05" and entry.get("feedback_phase", "") == ""


static func active(unit: Unit) -> bool:
	return (
		is_instance_valid(unit) and unit.is_alive
		and int(unit.get_meta("cc2_effects", { }).get("counter", { }).get("duration", 0)) > 0
	)


static func restore(router: Node) -> void:
	for unit: Unit in router._units():
		if active(unit) and router._card_unit(unit):
			router._ensure_hold(
				unit,
				ID,
				{ "id": "cc2_g05", "contre_mode": "token", "status_id": ID, "width": 1.0 },
			)


static func resolve(router: Node, caster: Unit) -> void:
	if not active(caster):
		return
	var entry := { "id": "cc2_g05", "contre_mode": "arm", "width": 1.0 }
	entry["contre_origin"] = router.manager._caster_effect_origin(caster)
	router._at_unit(entry, caster)
	restore(router)
	var held: Dictionary = router.holds.get("%s:%s" % [caster.get_instance_id(), ID], { })
	if is_instance_valid(held.get("fx")):
		held.fx.appear_after = held.fx.elapsed + 14.0 / 30.0


static func hit(router: Node, fact: CombatEventFact) -> void:
	if (
		fact.status_id != &"cc2_counter" or not router._in_scope(fact)
		or not is_instance_valid(fact.source) or fact.source not in router._units()
		or not router._card_unit(fact.source) or fact.amount_applied + fact.amount_absorbed <= 0
	):
		return
	var key := "counter:%s" % fact.event_id
	if key in router.resolved:
		return
	router.resolved.append(key)
	if router.resolved.size() > 256:
		router.resolved.pop_front()
	# hit_resolved precedes unit death/removal. Freeze endpoints before that cleanup.
	var source: Vector2 = router.manager._grid_cell_global(fact.source.grid_pos)
	var target: Vector2 = router.manager._grid_cell_global(fact.target.grid_pos)
	router._remove_hold("%s:%s" % [fact.source.get_instance_id(), ID], false)
	router._spawn(
		{
			"id": "cc2_g05",
			"contre_mode": "riposte",
			"width": 1.0,
			"contre_origin": source,
			"contre_target": target,
		},
		source,
	)
