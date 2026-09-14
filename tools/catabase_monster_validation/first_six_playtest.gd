extends "res://tools/catabase_monster_validation/early_run_playtest.gd"
## Independent production rooms. This bounded policy is not a human balance oracle.


func _run() -> void:
	label = "first_six"
	output = "res://artifacts/dev/early_run_playtest/" + label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for node: Dictionary in ExpeditionRouteCatalog.create_nodes(2401):
		if not ExpeditionRouteCatalog.is_combat(str(node.kind)) or int(node.depth) > 6:
			continue
		for kit: String in CatabasePreparationCatalog.WEAPONS:
			var result := _fight(node, 2401, kit)
			results.append(result)
			print("FIRST_SIX ", JSON.stringify(result))
			await get_tree().process_frame
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"cases": results,
				"errors": errors,
				"scope": "Independent rooms I–VI, full HP, production formations/AI/SpellCaster, six equipped presets. Available mutations purchased at II and finite relics enabled. Greedy policy, no claim of human balance or continuous survival.",
			},
			"\t",
		)
	)
	get_tree().quit(0 if errors.is_empty() and results.size() >= 18 else 1)


func _prepare_hero(hero: Unit, data: UnitData, kit: String, depth: int) -> Dictionary:
	var independent_data := data.duplicate(false) as UnitData
	independent_data.progression_profile = null
	var state := CharacterRunState.new()
	if not state.initialize(hero, independent_data):
		errors.append("Character initialization failed")
	var session := ExpeditionSession.new()
	session.initialize(state, 2401)
	session.needs_preparation = true
	var items := ExpeditionEquipmentCatalog.merge_into(null)
	var inventory := RunInventory.new()
	inventory.initialize(items, 30)
	var preparation := session.prepare_start(
		CatabasePreparationCatalog.preset(kit),
		inventory,
		items,
	)
	if not preparation.success:
		errors.append(str(preparation))
	for prior_depth in range(1, depth):
		session.build.grant_depth_reward(prior_depth)
	if depth >= 3:
		var roots := {
			"marteau": "ct_masse",
			"xiphos": "ct_salve",
			"disque": "ct_retour",
			"hampe": "ct_braise",
			"lame": "ct_entaille",
			"arc": "ct_peage",
		}
		var purchase := session.build.purchase("ct." + roots[kit] + "_a")
		if not purchase.success:
			errors.append(str(purchase))
	var runtime := RelicRuntimeService.new()
	if not runtime.initialize(inventory, items, [hero]):
		errors.append("Relic initialization failed")
	runtime.begin_combat([hero])
	return { "state": state, "session": session, "inventory": inventory, "runtime": runtime }


func _release_hero(context: Dictionary) -> void:
	context.runtime.dispose()
	context.state.dispose()


func _hero_action(
	hero: Unit,
	units: Array,
	grid: GridData,
	pathfinder: Pathfinder,
	caster: SpellCaster,
) -> Dictionary:
	for spell: Spell in hero.spells:
		var id := String(spell.spell_id)
		if id.begins_with("exp_ct_retour") or id.begins_with("exp_ct_masse_b"):
			if caster.can_cast(hero, spell, hero.grid_pos):
				for cell in caster.get_aoe_cells(spell, hero.grid_pos, hero.grid_pos):
					var target := grid.get_unit(cell) as Unit
					if target != null and target.team != hero.team:
						return { "type": "cast", "spell": spell, "cell": hero.grid_pos }
		if id.begins_with("exp_ct_salve") and hero.current_ap >= 5 and hero.current_shield == 0:
			var threatened := units.any(
				func(enemy: Unit):
					return (
						enemy.is_alive and enemy.team != hero.team
						and grid.manhattan(hero.grid_pos, enemy.grid_pos)
						<= enemy.max_mp.get_int() + 4
					),
			)
			if threatened and caster.can_cast(hero, spell, hero.grid_pos):
				return { "type": "cast", "spell": spell, "cell": hero.grid_pos }
		if (
			id.begins_with("exp_ct_peage") and hero.current_ap >= 5
			and caster.can_cast(hero, spell, hero.grid_pos)
		):
			for attack: Spell in hero.spells:
				if String(attack.spell_id) != "exp_ct_trait":
					continue
				for enemy: Unit in units:
					if (
						enemy.team != hero.team and enemy.is_alive
						and caster.can_cast(hero, attack, enemy.grid_pos)
					):
						return { "type": "cast", "spell": spell, "cell": hero.grid_pos }
		if id == "exp_ct_flux":
			for cell: Vector2i in hero.get_meta("ct_braises", []):
				if not caster.can_cast(hero, spell, cell):
					continue
				var destination := CatabaseCombatModifier.flux_destination(hero, cell)
				var target := grid.get_unit(destination) as Unit
				if target != null and target.team != hero.team:
					return { "type": "cast", "spell": spell, "cell": cell }
	var action := super._hero_action(hero, units, grid, pathfinder, caster)
	if not action.is_empty() and (action.type == "move" or (action.spell as Spell).deals_damage()):
		return action
	# A missed return must still recover the weapon; do not strand this policy.
	for spell: Spell in hero.spells:
		if (
			String(spell.spell_id).begins_with("exp_ct_retour")
			and caster.can_cast(hero, spell, hero.grid_pos)
		):
			return { "type": "cast", "spell": spell, "cell": hero.grid_pos }
	# Use the actual movement techniques when a front line blocks normal access.
	var current := _position_score(hero.grid_pos, hero, units, grid, pathfinder)
	var best := { }
	for spell: Spell in hero.spells:
		if spell.caster_movement != Spell.CasterMovement.TARGET_CELL:
			continue
		for x in range(-spell.spell_range, spell.spell_range + 1):
			for y in range(-spell.spell_range, spell.spell_range + 1):
				var cell := hero.grid_pos + Vector2i(x, y)
				if not caster.can_cast(hero, spell, cell):
					continue
				var value := _position_score(cell, hero, units, grid, pathfinder)
				if value > current + 0.1:
					current = value
					best = { "type": "cast", "spell": spell, "cell": cell }
	return best if not best.is_empty() else action
