extends RefCounted
const Player := preload("player.gd")


static func handles(entry: Dictionary) -> bool:
	return entry.get("id", "") == "cc2_l01" and entry.get("feedback_phase", "") == ""


static func prepare(router: Node, caster: Unit, entry: Dictionary) -> Node:
	var old: Node = router.sentence_preparations.get(caster)
	if is_instance_valid(old):
		old.cancel()
	var payload := entry.duplicate(true)
	payload["orage_preparing"] = true
	payload["width"] = 1.0
	var fx: Node = router._spawn(
		payload,
		router.manager._grid_cell_global(caster.grid_pos),
		router.manager._find_unit_view(caster),
	)
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
	var points: Array[Vector2] = []
	for fact: Dictionary in evidence.get("targets", []):
		if fact.unit in report.get("damaged_enemies", []):
			var p: Vector2 = router.manager._grid_cell_global(fact.cell)
			if p not in points:
				points.append(p)
	var fx: Node = prepared
	if not is_instance_valid(fx):
		if points.is_empty():
			return
		var entry: Dictionary = router.Catalog.for_spell(spell)
		entry["width"] = 1.0
		fx = router._spawn(entry, router.manager._grid_cell_global(
				evidence.get("origin", caster.grid_pos)
			))
	if fx == null:
		return
	fx.set_impacts(points)
	fx.confirm()
	fx.sample(fx.elapsed)
