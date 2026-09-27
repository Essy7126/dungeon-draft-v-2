extends RefCounted


static func handles(entry: Dictionary) -> bool:
	return entry.get("id", "") == "cc2_r08" and entry.get("feedback_phase", "") == ""


static func prepare(router: Node, caster: Unit, cell: Vector2i, entry: Dictionary) -> Node:
	var target: Unit
	for unit: Unit in router._units():
		if unit.grid_pos == cell and unit.is_alive and unit.team != caster.team:
			target = unit
			break
	if target == null or target.get_meta("cc2_boss", false):
		return null
	var old: Node = router.sentence_preparations.get(caster)
	if is_instance_valid(old):
		old.cancel()
	var payload := entry.duplicate(true)
	payload["width"] = 1.0
	payload["permutation_preparing"] = true
	payload["permutation_sites"] = [
		{ "point": router.manager._grid_cell_global(caster.grid_pos), "view": router
			.manager
			._find_unit_view(caster) },
		{ "point": router.manager._grid_cell_global(cell), "view": router.manager._find_unit_view(
				target
			) },
	]
	var fx: Node = router._spawn(payload, payload.permutation_sites[0].point)
	if fx == null:
		return null
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
	var targets: Array = evidence.get("targets", [])
	var target: Unit = targets[0].unit if targets.size() == 1 else null
	var swapped: bool = (
		target != null and is_instance_valid(target) and evidence.has("origin")
		and evidence.origin != targets[0].cell and caster.grid_pos == targets[0].cell
		and target.grid_pos == evidence.origin
	)
	if not swapped:
		if is_instance_valid(prepared):
			prepared.cancel()
		return
	var occupants: Array[Node2D] = [
		router.manager._find_unit_view(target),
		router.manager._find_unit_view(caster),
	]
	if is_instance_valid(prepared):
		prepared.confirm(occupants)
		return
	var entry: Dictionary = router.Catalog.for_spell(spell)
	entry["width"] = 1.0
	entry["permutation_sites"] = [
		{ "point": router.manager._grid_cell_global(evidence.origin), "view": occupants[0] },
		{ "point": router.manager._grid_cell_global(targets[0].cell), "view": occupants[1] },
	]
	router._spawn(entry, entry.permutation_sites[0].point)
