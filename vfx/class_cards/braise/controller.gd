extends RefCounted


static func handles(entry: Dictionary) -> bool:
	return entry.get("id", "") == "cc2_t02" and entry.get("feedback_phase", "") == ""


static func prepare(router: Node, caster: Unit, cell: Vector2i, entry: Dictionary) -> Node:
	var old: Node = router.sentence_preparations.get(caster)
	if is_instance_valid(old):
		old.cancel()
	var payload := entry.duplicate(true)
	payload["width"] = 1.0
	payload["braise_preparing"] = true
	payload["braise_origin"] = router.manager._caster_effect_origin(caster)
	var fx: Node = router._spawn(payload, router.manager._grid_cell_global(cell))
	if fx != null:
		router.sentence_preparations[caster] = fx
		fx.cancelled.connect(
			func():
				if router.sentence_preparations.get(caster) == fx:
					router.sentence_preparations.erase(caster),
		)
	return fx


static func resolve(
	router: Node,
	caster: Unit,
	spell: Spell,
	report: Dictionary,
	prepared: Node,
) -> void:
	var evidence: Dictionary = report.get("card_vfx", { })
	var points: Array[Vector2] = []
	for fact: Dictionary in evidence.get("targets", []):
		if fact.unit in report.get("damaged_enemies", []):
			points.append(router.manager._grid_cell_global(fact.cell))
	if is_instance_valid(prepared):
		prepared.confirm(not points.is_empty())
	elif not points.is_empty():
		var entry: Dictionary = router.Catalog.for_spell(spell)
		entry["width"] = 1.0
		router._spawn(entry, points[0])
	for cell in report.get("terrain_changed", []):
		router._sync_surface(cell)
	restore(router)


static func restore(router: Node) -> void:
	for unit: Unit in router._units():
		if not active(unit):
			continue
		var entry: Dictionary = router.Catalog.feedback("fire")
		entry["braise_badge"] = true
		entry["status_id"] = "cc2_burn"
		entry["width"] = 1.0
		router._ensure_hold(unit, "cc2_burn", entry)


static func active(unit: Unit) -> bool:
	return (
		is_instance_valid(unit) and unit.is_alive
		and int(unit.get_meta("cc2_effects", { }).get("burn", { }).get("duration", 0)) > 0
	)


static func tick(router: Node, fact: CombatEventFact) -> void:
	if not active(fact.target):
		return
	restore(router)
	var held: Dictionary = router.holds.get("%s:cc2_burn" % fact.target.get_instance_id(), { })
	if is_instance_valid(held.get("fx")):
		held.fx.pulse()


static func steam(state: CellSurfaceState) -> bool:
	return (
		state.surface_id == &"steam"
		and (
			state.gameplay_flags.get("cc2_vfx", "") == "braise_steam"
			or (state.source_spell != null and state.source_spell.spell_id == &"cc2_t02")
		)
	)
