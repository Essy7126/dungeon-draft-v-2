extends RefCounted
const Math := preload("res://core/expedition/consumable_card_math.gd")
const ID := "catabase_cards_consumable_v2"


static func states(unit: Unit) -> Dictionary:
	if not unit.has_meta("cc2_effects"):
		unit.set_meta("cc2_effects", { })
	return unit.get_meta("cc2_effects")


static func apply_state(
	unit: Unit,
	kind: String,
	amount: float,
	duration: int,
	source: Unit,
	extras: Dictionary = { },
) -> bool:
	var all := states(unit)
	var before: Dictionary = all.get(kind, { }).duplicate(true)
	var value := {
		"amount": amount,
		"duration": duration,
		"source": str(source.unit_id) if source != null else "",
	}
	if not before.is_empty():
		value.amount = maxf(float(before.amount), amount)
		value.duration = maxi(int(before.duration), duration)
		if float(before.amount) > amount:
			value.source = before.source
	value.merge(extras, true)
	if not before.is_empty() and float(before.amount) > amount:
		value = before.duplicate(true)
		value.duration = maxi(int(before.duration), duration)
	all[kind] = value
	unit.stats_changed.emit(unit)
	return before != value


static func guard(
	hero: Unit, coefficient: float, cards, extra_multiplier := 1.0, ability_id: StringName = &"",
	card: Dictionary = {}, component_key := "amount",
) -> int:
	var mods := Math.equipment_mods(cards.equipped)
	var bonus := float(mods.get("guard", 0)) + .05 * int(cards.attributes.get("resolve", 0))
	if cards.prototype_revision == 1:
		bonus = Math.component_bonus(card, component_key, cards, mods, "guard") + extra_multiplier - 1.0
		extra_multiplier = 1.0
	var amount := Math.guard(
		hero.attack_power.get_value(),
		coefficient * extra_multiplier,
		bonus,
		hero.current_shield,
	)
	if amount > 0:
		hero.add_sourced_shield(
			&"cc2_guard",
			hero.current_shield + amount,
			hero,
			{ "tags": [&"guard"], "expires_after_activations": 1, "ability_id": ability_id },
		)
	return amount


static func hit(
	target: Unit,
	source: Unit,
	raw: float,
	magic := false,
	kind := "indirect",
	pierce := false,
	status_id: StringName = &"",
) -> DamageResolver.DamageResult:
	return target.take_damage(
		Math.rounded(raw),
		source,
		Spell.DamageType.MAGICAL if magic else Spell.DamageType.PHYSICAL,
		Spell.Element.NONE,
		{
			"damage_ruleset": ID,
			"raw_payload": raw,
			"ignore_defense": pierce,
			"attack_classification": StringName("cc2_" + kind),
			"is_periodic": kind == "periodic",
			"status_id": status_id,
			"skip_vulnerability": kind == "pressure",
			"skip_outgoing": kind == "pressure",
			"skip_splash": kind == "pressure",
		},
	)


static func axis(from: Vector2i, to: Vector2i) -> Vector2i:
	var delta := to - from
	return (
		Vector2i(signi(delta.x), 0)
		if absi(delta.x) >= absi(delta.y)
		else Vector2i(0, signi(delta.y))
	)


static func displace(grid: GridData, unit: Unit, direction: Vector2i, count: int) -> Dictionary:
	var origin := unit.grid_pos
	var wall := false
	if direction == Vector2i.ZERO:
		return { "from": origin, "to": origin, "moved": 0, "wall": false }
	var limit := mini(count, 1) if unit.get_meta("cc2_boss", false) else count
	for _step in maxi(0, limit):
		var next := unit.grid_pos + direction
		if not grid.is_valid(next):
			break
		if not grid.is_walkable(next, unit):
			wall = (
				grid.get_unit(next) == null and not grid.is_terrain_interactable(next)
				and grid.get_type(next) != GridData.CellType.HOLE
			)
			break
		if not grid.relocate_unit(unit, next) or not unit.is_alive:
			break
	var destination := unit.grid_pos
	if destination != origin:
		EventBus.unit_pushed.emit(unit, origin, destination, wall)
	return {
		"from": origin,
		"to": destination,
		"moved": grid.manhattan(origin, destination),
		"wall": wall,
	}


static func mark_facts(hero: Unit, target: Unit, cards, options: Dictionary = { }) -> Dictionary:
	var isolated := true
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor: Unit = hero.grid_context.get_unit(target.grid_pos + direction)
		if neighbor != null and neighbor.is_alive and neighbor.team == target.team:
			isolated = false
	var mark: Dictionary = states(target).get("mark", { })
	return {
		"distance": hero.grid_context.manhattan(hero.grid_pos, target.grid_pos),
		"mark": float(mark.get("amount", 0)),
		"mark_origin": str(mark.get("origin", "direct")),
		"moved": cards.moved_cells,
		"guard": hero.current_shield,
		"absorbed": cards.absorbed_last_round,
		"execute": target.current_hp * 100 <= target.max_hp.get_int() * 35,
		"isolated": isolated,
		"sacrifice": int(options.get("sacrifice", 0)),
		"cell": target.grid_pos,
	}


static func trigger_map(cards) -> Dictionary:
	var result := { }
	for key in cards.trigger_counters:
		result[key] = int(cards.trigger_counters[key]) == cards.round_index
	return result


static func return_to_anchor(hero: Unit, cards, grid: GridData) -> bool:
	if (
		cards.primary_class != "arpenteur" or not cards.anchor_available
		or cards.anchor_used or hero.current_mp < 1 or not hero.is_alive
		or grid.manhattan(hero.grid_pos, cards.anchor_cell) > 3
		or not grid.is_walkable(cards.anchor_cell) or grid.get_unit(cards.anchor_cell) != null
	):
		return false
	var from := hero.grid_pos
	if not grid.relocate_unit(hero, cards.anchor_cell):
		return false
	hero.spend_mp(1)
	cards.anchor_used = true
	EventBus.unit_pushed.emit(hero, from, hero.grid_pos, false)
	return true


static func relay(hero: Unit, cards, target: Unit = null) -> bool:
	if cards.pending_choice.get("kind") != "relay":
		return false
	if target != null:
		var cell := Vector2i(cards.pending_choice.cell[0], cards.pending_choice.cell[1])
		if not target.is_alive or target.team == hero.team or hero.grid_context.manhattan(
				cell,
				target.grid_pos,
			) > 2:
			return false
		apply_state(
			target,
			"mark",
			float(cards.pending_choice.amount),
			2,
			hero,
			{ "origin": "relay", "expires_hero_end": cards.round_index + 1 },
		)
	cards.pending_choice.clear()
	return true
