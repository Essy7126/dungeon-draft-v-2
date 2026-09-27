extends RefCounted
## Profile policy around the shared reaction table and permanent/dynamic layers.
const Effects := preload("res://core/expedition/consumable_card_effects.gd")


static func effect(surface: String, duration: int) -> TerrainEffectData:
	var result := TerrainEffectData.new()
	result.surface_id = StringName(surface)
	result.visual_terrain_id = StringName(surface)
	result.effect_name = {
		"water": "Eau du Léthé",
		"ice": "Glace",
		"fire": "Bûcher",
		"steam": "Vapeur",
	}.get(surface, surface)
	result.trigger = TerrainEffectData.Trigger.TURN_START
	result.duration = duration
	result.blocks_vision = surface == "steam"
	result.same_surface_policy = TerrainEffectData.SameSurfacePolicy.REPLACE
	result.color = {
		"water": Color("3979a6"),
		"ice": Color("97dce8"),
		"fire": Color("e88a49"),
		"steam": Color("a9afb5"),
	}.get(surface, Color.WHITE)
	return result


static func resolve_cast(ctx, cards, card: Dictionary) -> void:
	if ctx.terrain == null:
		return
	var incoming := ""
	if card.get("waterField", false):
		incoming = "water"
	elif card.op == "firefield":
		incoming = "fire"
	elif card.op == "icefield":
		incoming = "ice"
	var reaction_only: bool = card.has("waterReaction")
	if reaction_only:
		incoming = "ice" if card.waterReaction == "freeze" else "fire"
	if incoming.is_empty():
		return
	prune(ctx.terrain, cards)
	var new_group := ""
	var transformed := false
	for cell in ctx.affected_cells:
		var current: CellSurfaceState = ctx.terrain.runtime_service.get_state(cell)
		var dynamic: bool = current != null and current.is_dynamic()
		var previous := str(current.surface_id) if dynamic else "none"
		if reaction_only and previous != "water":
			continue
		var eligibility: Dictionary = ctx.terrain.runtime_service.eligibility_report(
			cell,
			effect(incoming, 2),
		)
		if not eligibility.eligible:
			continue
		var resolved := TerrainInteractionResolver.resolve_ids(
			StringName(previous),
			StringName(incoming),
		)
		var surface := str(resolved.result_surface_id)
		var changed_type: bool = dynamic and surface != previous
		var duration := int(card.get("duration", 2))
		if reaction_only:
			duration = int(card.get("waterReactionDuration", 2 if surface == "ice" else 1))
		elif surface == "steam":
			duration = 1
		var group := str(current.gameplay_flags.get("cc2_group", "")) if dynamic else ""
		if not changed_type or group.is_empty():
			if new_group.is_empty():
				cards.surface_serial += 1
				new_group = "surface_%06d" % cards.surface_serial
				cards.surface_groups.append({ "id": new_group, "serial": cards.surface_serial })
			group = new_group
		# Resolve through the shared table first, then install the final profile
		# payload. This prevents the legacy reaction's default ice stun/entry tick.
		if dynamic:
			ctx.terrain.clear_effect(cell)
		var applied: Dictionary = ctx.terrain.place_effect(
			cell,
			effect(surface, duration),
			ctx.caster,
			ctx.spell,
			duration,
		)
		if not applied.get("changed", false):
			continue
		var state: CellSurfaceState = ctx.terrain.runtime_service.get_state(cell)
		state.gameplay_flags["cc2_group"] = group
		state.gameplay_flags["cc2_owner"] = str(ctx.caster.unit_id)
		state.gameplay_flags["cc2_payload"] = 0.0
		if card.id == "t02" and surface == "steam":
			state.gameplay_flags["cc2_vfx"] = "braise_steam"
		if surface == "fire":
			var coefficient := float(card.amount) + (.1 if "embers" in cards.active_relics else 0.0)
			state.gameplay_flags["cc2_payload"] = coefficient * ctx.caster.attack_power.get_value()
		if cell not in ctx.report.terrain_changed:
			ctx.report.terrain_changed.append(cell)
		transformed = transformed or changed_type
	prune(ctx.terrain, cards)
	while cards.surface_groups.size() > 2:
		var oldest: Dictionary = cards.surface_groups.pop_front()
		for cell in ctx.terrain.runtime_service.active_surface_cells():
			if str(ctx.terrain.runtime_service.get_state(cell).gameplay_flags.get("cc2_group", "")) == oldest.id:
				ctx.terrain.clear_effect(cell)
	if transformed and cards.primary_class == "thaumaturge" and cards.take_trigger("class"):
		Effects.guard(ctx.caster, .2, cards)


static func prune(terrain: TerrainEffects, cards) -> void:
	var alive := { }
	for cell in terrain.runtime_service.active_surface_cells():
		var group := str(terrain.runtime_service.get_state(cell).gameplay_flags.get("cc2_group", ""))
		if not group.is_empty():
			alive[group] = true
	for group in cards.surface_groups.duplicate():
		if not alive.has(group.id):
			cards.surface_groups.erase(group)


static func begin_activation(terrain: TerrainEffects, unit: Unit) -> int:
	var state := terrain.runtime_service.get_state(unit.grid_pos)
	if state == null or not state.is_dynamic() or not state.gameplay_flags.has("cc2_group"):
		return 0
	if state.surface_id == &"fire":
		Effects.hit(unit, state.source_unit, float(state.gameplay_flags.get("cc2_payload", 0)), true, "periodic")
	if (
		state.surface_id == &"ice" and state.source_unit != null
		and unit.team != state.source_unit.team
	):
		return 1
	return 0


static func snapshot(terrain: TerrainEffects) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell in terrain.runtime_service.active_surface_cells():
		var state := terrain.runtime_service.get_state(cell)
		result.append(
			{
				"cell": [cell.x, cell.y],
				"surface": str(state.surface_id),
				"duration": state.remaining_duration,
				"flags": state.gameplay_flags.duplicate(true),
				"source": str(state.source_unit.unit_id) if state.source_unit != null else "",
			}
		)
	return result
