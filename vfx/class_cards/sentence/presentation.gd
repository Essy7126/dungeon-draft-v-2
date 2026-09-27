extends RefCounted
## Cards-only anticipation before begin_cast revalidation; includes approved cel spells.


static func prepare(battle: Node, caster: Unit, spell: Spell, cell: Vector2i) -> Dictionary:
	var router: Node = VFXManager._class_card_router
	if not is_instance_valid(router) or not router.accepts(caster, spell):
		return { }
	var fx: Node = router.prepare_sentence(caster, spell, cell)
	if fx == null:
		return { }
	await battle.get_tree().create_timer(fx.CONTACT, false).timeout
	return {
		"fx": fx if is_instance_valid(fx) else null,
		"cancelled": not is_instance_valid(fx) or fx.closed,
	}
