extends RefCounted
const Effects := preload("res://core/expedition/consumable_card_effects.gd")
const Terrain := preload("res://core/expedition/consumable_card_terrain.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")


static func bind_hero(hero: Unit, cards) -> void:
	hero.set_meta("cc2_ruleset", Effects.ID)
	hero.set_meta("cc2_cards", weakref(cards))
	hero.basic_attack_enabled = false
	hero.crit_chance.base_value = 0
	hero.esquive.base_value = 0


static func rebuild(hero: Unit, cards, preserve_ratio := false) -> void:
	var before := hero.max_hp.get_int()
	var hp := hero.current_hp
	var stats := Math.stats(cards.level, cards.attributes, Math.equipment_mods(cards.equipped))
	hero.max_hp.base_value = stats.hp
	hero.attack_power.base_value = stats.power
	hero.max_ap.base_value = 4
	hero.max_mp.base_value = stats.mp
	hero.armure.base_value = stats.physical * 100.0
	hero.resist_magique.base_value = stats.magic * 100.0
	cards.hand_capacity = int(stats.hand)
	hero.current_hp = mini(
		int(stats.hp),
		(
			Math.rounded(float(hp) / maxi(1, before) * stats.hp)
			if preserve_ratio
			else hp + maxi(0, int(stats.hp) - before)
		),
	)
	hero.stats_changed.emit(hero)


static func begin_hero(hero: Unit, cards, terrain: TerrainEffects, reset_resources := true) -> void:
	var effects := Effects.states(hero)
	effects.erase("counter")
	effects.erase("edict")
	if reset_resources: hero.start_turn()
	# Guard expiration is owned by Unit.start_turn, before the deferred urn.
	cards.start_turn()
	cards.anchor_cell = hero.grid_pos
	if "bronze" in cards.active_relics and cards.absorbed_last_round > 0:
		Effects.guard(hero, .25, cards)
	if cards.round_index == 1:
		Effects.guard(hero, float(Math.equipment_mods(cards.equipped).get("openingShield", 0)), cards)
	var ice := Terrain.begin_activation(terrain, hero)
	apply_activation_statuses(hero, terrain._grid, ice)


static func apply_activation_statuses(unit: Unit, grid: GridData, ice := 0) -> bool:
	var effects := Effects.states(unit)
	for kind in ["bleed", "burn"]:
		if effects.has(kind) and unit.is_alive:
			var entry: Dictionary = effects[kind]
			var source: Unit = null
			for other in grid.get_units():
				if str(other.unit_id) == str(entry.source):
					source = other
			Effects.hit(unit, source, float(entry.amount), kind == "burn", "periodic", false, StringName("cc2_" + kind))
			entry.duration -= 1
			if entry.duration <= 0:
				effects.erase(kind)
	var slow := maxi(ice, int(effects.get("slow", { }).get("amount", 0)))
	unit.current_mp = maxi(0, unit.current_mp - slow)
	effects.erase("slow")
	var skipped := effects.has("stasis")
	effects.erase("stasis")
	# The skipped activation does not spend one of the next three immunity turns.
	if effects.has("stasis_ward") and not skipped:
		effects.stasis_ward.duration -= 1
		if effects.stasis_ward.duration <= 0:
			effects.erase("stasis_ward")
	return skipped or not unit.is_alive


static func end_hero(cards, grid: GridData) -> void:
	cards.end_turn()
	for unit in grid.get_units():
		var effects := Effects.states(unit)
		if (
			effects.has("mark") and effects.mark.has("expires_hero_end")
			and int(effects.mark.expires_hero_end) <= cards.round_index
		):
			effects.erase("mark")


static func end_enemy_phase(cards, grid: GridData, terrain: TerrainEffects) -> void:
	for unit in grid.get_units():
		var effects := Effects.states(unit)
		if effects.has("mark") and not effects.mark.has("expires_hero_end"):
			effects.mark.duration -= 1
			if effects.mark.duration <= 0:
				effects.erase("mark")
	terrain.tick_all_effects()
	Terrain.prune(terrain, cards)


static func after_hit(
	hero: Unit,
	attacker,
	result: DamageResolver.DamageResult,
	ctx: DamageResolver.HitContext,
) -> void:
	var cards = CatabaseCards.for_actor(hero)
	if cards == null:
		return
	if (
		attacker == null or not attacker is Unit
		or attacker.team == hero.team or ctx.attack_classification != &"cc2_attack"
	):
		return
	var absorbed := maxi(0, result.shield_damage_absorbed)
	cards.absorbed_since_turn += absorbed
	if not hero.is_alive:
		return
	if absorbed > 0 and cards.primary_class == "gardien" and cards.take_trigger("class"):
		Effects.hit(attacker, hero, .25 * hero.attack_power.get_value())
	if "mirror" in cards.active_relics and cards.take_trigger("mirror", true):
		Effects.hit(attacker, hero, .4 * hero.attack_power.get_value())
	var effects := Effects.states(hero)
	if effects.has("counter") and hero.grid_context != null and hero.grid_context.manhattan(
			hero.grid_pos,
			attacker.grid_pos,
		) == 1:
		Effects.hit(attacker, hero, float(effects.counter.amount), false, "indirect", false, &"cc2_counter")
		effects.erase("counter")
