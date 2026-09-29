extends RefCounted


static func handles(entry: Dictionary) -> bool:
	return entry.get("id", "") == "cc2_t08" and entry.get("feedback_phase", "") == ""


static func payload(router: Node, entry: Dictionary, cell: Vector2i) -> Dictionary:
	var result := entry.duplicate(true)
	var point: Vector2 = router.manager._grid_cell_global(cell)
	result["width"] = 1.0
	result["convergence_basis"] = [
		router.manager._grid_cell_global(cell + Vector2i.RIGHT) - point,
		router.manager._grid_cell_global(cell + Vector2i.DOWN) - point,
	]
	return result


static func prepare(router: Node, caster: Unit, cell: Vector2i, entry: Dictionary) -> Node:
	var previous: Node = router.sentence_preparations.get(caster)
	if is_instance_valid(previous):
		previous.cancel()
	var recipe := payload(router, entry, cell)
	recipe["convergence_preparing"] = true
	var fx: Node = router._spawn(recipe, router.manager._grid_cell_global(cell))
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
	if evidence.is_empty():
		if is_instance_valid(prepared):
			prepared.cancel()
		return
	var cell: Vector2i = report.cell
	var point: Vector2 = router.manager._grid_cell_global(cell)
	var arms: Array[Vector2] = []
	for hit_cell: Vector2i in evidence.get("arm_cells", []):
		var delta := hit_cell - cell
		if absi(delta.x) + absi(delta.y) == 1:
			arms.append(router.manager._grid_cell_global(hit_cell))
	var contacts: Array[Vector2] = []
	for fact: Dictionary in evidence.get("contacts", []):
		if fact.unit in router._units():
			contacts.append(router.manager._grid_cell_global(fact.cell))
	var trails: Array[Dictionary] = []
	for movement: Dictionary in evidence.get("movement", []):
		if movement.unit in router._units() and movement.from != movement.to:
			trails.append(
				{
					"from": router.manager._grid_cell_global(movement.from),
					"to": router.manager._grid_cell_global(movement.to),
				}
			)
	var fx := prepared
	if is_instance_valid(fx) and fx.point.distance_to(point) > 1.0:
		fx.cancel()
		fx = null
	if not is_instance_valid(fx):
		var entry := payload(router, router.Catalog.for_spell(spell), cell)
		fx = router._spawn(entry, point)
	if is_instance_valid(fx):
		fx.confirm(arms, contacts, trails)
