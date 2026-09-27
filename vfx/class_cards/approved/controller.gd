extends RefCounted
const Player := preload("player.gd")
const IDS := ["g_hook", "t_glacier", "a_reap", "r_scatter"]


static func handles(entry: Dictionary) -> bool:
	return entry.get("id", "") in IDS and entry.get("feedback_phase", "") == ""


static func prepare(
	router: Node,
	caster: Unit,
	spell: Spell,
	cell: Vector2i,
	entry: Dictionary,
) -> Node:
	if entry.id == "t_glacier":
		return null # The real terrain creation owns germination.
	var old: Node = router.sentence_preparations.get(caster)
	if is_instance_valid(old):
		old.cancel()
	var payload := entry.duplicate(true)
	payload["approved_preparing"] = true
	payload["width"] = 1.0
	var fx: Node = router._spawn(payload, router.manager._grid_cell_global(cell))
	if fx == null:
		return null
	fx.origin = router.manager._grid_cell_global(caster.grid_pos)
	fx.source_anchor = router.manager._find_unit_view(caster)
	var host: Node = router.manager._battle_view.get_parent()
	if host.get("spell_caster") != null:
		var cells: Array = host.spell_caster.get_aoe_cells(spell, cell, caster.grid_pos)
		fx.set_destinations(_points(router, cells))
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
	var entry: Dictionary = router.Catalog.for_spell(spell)
	if entry.id == "t_glacier":
		for cell: Vector2i in report.get("terrain_changed", []):
			router._sync_surface(cell)
		return
	var evidence: Dictionary = report.get("card_vfx", { })
	var damaged: Array = report.get("damaged_enemies", [])
	var fx: Node = prepared
	if not is_instance_valid(fx):
		entry["width"] = 1.0
		fx = router._spawn(entry, router.manager._grid_cell_global(
				report.get("cell", caster.grid_pos)
			))
	if fx == null:
		return
	fx.origin = router.manager._grid_cell_global(evidence.get("origin", caster.grid_pos))
	fx.source_anchor = router.manager._find_unit_view(caster)
	fx.set_destinations(
		_points(router, evidence.get("cells", [report.get("cell", caster.grid_pos)]))
	)
	for target_fact: Dictionary in evidence.get("targets", []):
		var target: Unit = target_fact.unit
		if target in damaged:
			fx.hit = true
			fx.hit_points.append(router.manager._grid_cell_global(target_fact.cell))
			if entry.id == "a_reap":
				fx.empowered = bool(target_fact.execute)
		if entry.id == "g_hook":
			fx.anchor = router.manager._find_unit_view(target)
	if entry.id == "g_hook":
		for movement: Dictionary in evidence.get("movement", []):
			if movement.unit == caster:
				continue
			fx.follow_displacement(
				movement.unit,
				router.manager._find_unit_view(movement.unit),
				router.manager._grid_cell_global(movement.from),
				router.manager._grid_cell_global(movement.to),
			)
	fx.confirm()
	fx.sample(fx.elapsed)


static func _points(router: Node, cells: Array) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for cell: Vector2i in cells:
		points.append(router.manager._grid_cell_global(cell))
	return points
