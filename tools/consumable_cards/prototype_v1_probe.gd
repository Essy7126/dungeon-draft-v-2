extends "res://tools/consumable_cards/audit_live_integration.gd"
## Bounded deterministic policy on actual public Battle scenes. Not a human win-rate.
const Progression := preload("res://core/expedition/consumable_progression_v1.gd")
var trials: Array = []
var active_trial := { }
var only_class := ""
var numerical: Array = []


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		if arg.begins_with("--class="):
			only_class = arg.trim_prefix("--class=")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(
			ProjectSettings.globalize_path("res://artifacts/dev/").replace("\\", "/")
		):
		get_tree().quit(2)
		return
	EventBus.spell_cast.connect(_record_cast)
	_numeric_contract()
	Engine.time_scale = 3.0
	for class_id in Catalog.CLASSES:
		if not only_class.is_empty() and class_id != only_class:
			continue
		for allocation in ["native", "split", "off_element"]:
			await _trial(class_id, allocation, 1)
			if not result.failures.is_empty():
				return finish()
			await _trial(class_id, allocation, 6)
			if not result.failures.is_empty():
				return finish()
	finish()


func _trial(class_id: String, allocation: String, depth: int) -> void:
	clear_battle()
	GameManager.cleanup_run_state()
	driver = Manager.new()
	add_child(driver)
	driver.select_run_variant("cards")
	driver.expedition_save_path = "user://probe_driver_%s_%s_%d.json" % [
		class_id,
		allocation,
		depth,
	]
	var selection: Dictionary = Catalog.preset(class_id)
	var primary_elements := {
		"assassin": "night",
		"gardien": "earth",
		"arpenteur": "wind",
		"thaumaturge": "water",
	}
	var primary: String = primary_elements[class_id]
	selection.masteries = Progression.empty_elements()
	selection.masteries[primary] = 2 if allocation == "split" else 0 if allocation == "off_element" else 4
	selection.masteries.sun += 2 if allocation == "split" else 4 if allocation == "off_element" else 0
	check(driver.configure_next_run(load("res://data/runs/odyssey.tres"), 0), "configure run")
	check(driver.configure_cards_departure(selection), "configure actual departure")
	if not check(
		driver.start_expedition(33, { "achilles": "passe_rive" }, false, true, "normal", true),
		"start",
	):
		return
	if depth > 1:
		# Only transport to an independent later encounter. No continuous-run claim.
		for previous_depth in range(1, depth):
			var session: ExpeditionSession = driver.expedition
			if session.route.phase == "combat":
				check(session.combat_won(), "fixture transit victory")
				check(session.acknowledge_combat_receipt().success, "fixture receipt")
			if session.cards.level >= 4 and session.cards.specialization.is_empty():
				var class_row: Dictionary = Catalog.class_row(class_id)
				session.cards.specialize(class_row.specs[0])
			while not session.advancement_step.is_empty():
				session.advance_level_step()
			var options: Array = session.reward_options(driver.item_catalog)
			check(
				session.claim(str(options[0].id), driver.run_inventory, driver.item_catalog).success,
				"fixture route reward",
			)
			check(
				driver.choose_expedition_node(str(session.route.get_available_nodes()[0].id)),
				"fixture next room",
			)
		var cards = driver.expedition.cards
		var budget: int = Progression.element_budget(cards.level)
		cards.masteries = Progression.empty_elements()
		cards.masteries[primary] = budget / 2 if allocation == "split" else 0 if allocation == "off_element" else budget
		cards.masteries.sun = budget / 2 if allocation == "split" else budget if allocation == "off_element" else 0
		cards.aptitudes.protection = Progression.aptitude_budget(cards.level)
		Runtime.Integration.rebuild(driver.expedition)
		driver.expedition.character.unit.current_hp = driver \
				.expedition \
				.character \
				.unit \
				.max_hp \
				.get_int()
	GameManager.expedition_save_path = "user://probe_live_%s_%s_%d.json" % [
		class_id,
		allocation,
		depth,
	]
	active_trial = {
		"class": class_id,
		"allocation": allocation,
		"depth": depth,
		"seed": 33,
		"casts": [],
		"actions": [],
		"enemy_casts": [],
		"rounds": [],
	}
	if not await mount(driver.get_expedition_snapshot()):
		return
	var hero: Unit = GameManager.expedition.character.unit
	var cards = GameManager.expedition.cards
	var visual: Node = battle._unit_views[hero].get_optional_visual()
	if not check(visual is PasseRiveAutoSpriteView, "actual Passe-rive visual"):
		return
	active_trial["appearance"] = visual.sprite_backend.get_script().resource_path
	check(
		active_trial.appearance == "res://characters/achilles/2d/passe_rive_s19_backend.gd",
		"actual Passe-rive backend",
	)
	active_trial["start"] = _facts(hero, cards)
	active_trial["specialization"] = cards.specialization
	active_trial["prepared_families"] = cards.active.map(
		func(uid):
			return str(cards.copy_for(uid).get("family", "")),
	)
	active_trial["roster"] = battle.units.filter(
		func(u):
			return u.team != 0,
	).map(
		func(u):
			return {
				"id": str(u.content_unit_id),
				"hp": u.current_hp,
				"physical": u.armure.get_value(),
				"magic": u.resist_magique.get_value(),
			},
	)
	if allocation == "native":
		await _picture("%s_d%02d_start" % [class_id, depth])
	var action_count := 0
	var last_round := 0
	var deadline := Time.get_ticks_msec() + 150000
	while (
		not battle._battle_over and hero.is_alive
		and cards.round_index <= (6 if depth == 6 else 12) and Time.get_ticks_msec() < deadline
	):
		if not await _idle():
			break
		if cards.round_index != last_round:
			last_round = cards.round_index
			active_trial.rounds.append(_facts(hero, cards))
		var action := _choose(hero, cards)
		if action.get("kind") == "cast":
			cards.selected = action.uid
			var before := _facts(hero, cards)
			await battle._on_request_cast_spell(action.spell, action.cell)
			await _idle()
			active_trial.actions.append(
				{
					"round": cards.round_index,
					"family": action.family,
					"before": before,
					"after": _facts(hero, cards),
				}
			)
		elif action.get("kind") == "move":
			await battle._on_request_move_to(action.cell)
		else:
			battle._commit_player_end_turn()
			await _idle()
		action_count += 1
		if action_count > 160:
			break
	active_trial["end"] = _facts(hero, cards)
	# Victory immediately grants a level and its HP delta. Report pre-reward HP too.
	active_trial["combat_end_hp"] = hero.current_hp - maxi(
		0,
		hero.max_hp.get_int() - int(active_trial.start.maximum),
	)
	active_trial["outcome"] = "victory" if _enemies().is_empty() else "defeat" if not hero.is_alive else "turn_limit"
	if Time.get_ticks_msec() >= deadline:
		active_trial.outcome = "timeout"
		check(false, "policy timeout")
	if allocation == "native":
		await _picture("%s_d%02d_end" % [class_id, depth])
	trials.append(active_trial.duplicate(true))
	print(
		"PROTOTYPE_V1_TRIAL "
		+ JSON.stringify(
			{
				"class": class_id,
				"allocation": allocation,
				"depth": depth,
				"outcome": active_trial.outcome,
				"round": cards.round_index,
				"hp": hero.current_hp,
				"casts": active_trial.casts.size(),
			}
		)
	)
	_write()
	active_trial = { }
	# Let the combat log's one-frame scroll updates settle before fixture teardown.
	await get_tree().process_frame
	await get_tree().process_frame
	clear_battle()
	GameManager.cleanup_run_state()
	driver.cleanup_run_state()
	driver.free()
	driver = null
	await get_tree().process_frame


func _enemies() -> Array:
	return battle.units.filter(
		func(u):
			return u.team != 0 and u.is_alive,
	)


func _facts(hero: Unit, cards) -> Dictionary:
	return {
		"round": cards.round_index,
		"level": cards.level,
		"hp": hero.current_hp,
		"maximum": hero.max_hp.get_int(),
		"guard": hero.current_shield,
		"power": hero.attack_power.get_value(),
		"ap": hero.current_ap,
		"mp": hero.current_mp,
		"masteries": cards.masteries.duplicate(),
		"aptitudes": cards.aptitudes.duplicate(),
		"copies": cards.copies.size(),
		"consumed": cards.consumed.size(),
		"enemy_hp": _enemies().reduce(
			func(n, u):
				return n + u.current_hp,
			0,
		),
		"enemy_count": _enemies().size(),
		"position": [hero.grid_pos.x, hero.grid_pos.y],
	}


func _choose(hero: Unit, cards) -> Dictionary:
	var best := { }
	var best_score := 0.0
	var available: Array = []
	for id in ["fallback_strike", "fallback_guard"]:
		available.append({ "family": id, "uid": "" })
	for uid in cards.hand:
		available.append({ "family": str(cards.copy_for(uid).family), "uid": str(uid) })
	for entry in available:
		cards.selected = entry.uid
		var spell: Spell = cards.family_spell(entry.family)
		var definition: Dictionary = Spells.definition(
			entry.family,
			entry.family in cards.upgraded_ids,
			cards.primary_class,
		)
		var cells: Array = battle.spell_caster.get_targetable_cells(hero, spell)
		for cell in cells:
			if not battle.spell_caster.can_cast(hero, spell, cell):
				continue
			var score := 0.0
			for target in _enemies():
				if target.grid_pos not in battle.spell_caster.get_aoe_cells(
					spell,
					cell,
					hero.grid_pos,
				):
					continue
				var facts := Runtime.Effects.mark_facts(hero, target, cards)
				var impact := Runtime.Math.impact(
					definition,
					hero.attack_power.get_value(),
					facts,
					{ },
					cards.primary_class,
					cards.specialization,
					Runtime.Effects.trigger_map(cards),
					cards,
				)
				var damage := Runtime.Math.damage(
					impact.raw,
					(
						target.resist_magique.get_value() / 100.0
						if definition.type == "magic"
						else target.armure.get_value() / 100.0
					),
				)
				score += minf(target.current_hp, damage) + (4 if damage >= target.current_hp else 0)
				if definition.op == "mark" and not Runtime.Effects.states(target).has("mark"):
					score += hero.attack_power.get_value() * float(definition.amount) * .6
				if definition.op in ["burn", "bleed"] and not Runtime.Effects.states(target).has(
						definition.op
					):
					score += hero.attack_power.get_value() * float(definition.amount)
				if definition.op == "slow":
					score += 1.0
			if definition.op == "guard" and hero.current_shield == 0:
				score = hero.attack_power.get_value() * float(definition.amount) * .35
			score /= maxf(1.0, float(definition.ap))
			if score > best_score:
				best_score = score
				best = {
					"kind": "cast",
					"family": entry.family,
					"uid": entry.uid,
					"spell": spell,
					"cell": cell,
				}
	if not best.is_empty():
		return best
	# Move closer only when no scored card is currently usable. Fixed policy, no hidden lookahead.
	var reach: Array = battle.pathfinder.get_reachable(hero.grid_pos, hero.current_mp, hero)
	var desired := 3 if cards.primary_class in ["arpenteur", "thaumaturge"] else 1
	var current := 999
	for enemy in _enemies():
		current = mini(current, absi(battle.grid.manhattan(hero.grid_pos, enemy.grid_pos) - desired))
	for cell in reach:
		if cell == hero.grid_pos:
			continue
		var distance := 999
		for enemy in _enemies():
			distance = mini(distance, absi(battle.grid.manhattan(cell, enemy.grid_pos) - desired))
		if distance < current:
			current = distance
			best = { "kind": "move", "cell": cell }
	return best


func _idle() -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while (
		is_instance_valid(battle) and not battle._battle_over
		and not battle._can_accept_player_intent() and Time.get_ticks_msec() < deadline
	):
		await get_tree().process_frame
	return (
		is_instance_valid(battle) and not battle._battle_over
		and check(Time.get_ticks_msec() < deadline, "Battle input timeout")
	)


func _record_cast(actor: Unit, spell: Spell, report: Dictionary) -> void:
	if active_trial.is_empty():
		return
	active_trial["casts" if actor.team == 0 else "enemy_casts"].append(
		{
			"actor": str(actor.content_unit_id),
			"spell": str(spell.spell_id),
			"failed": report.get("failed", false),
			"damage": report.get("hp_damage_total", 0),
			"healing": report.get("healing_total", 0),
		}
	)


func _picture(label: String) -> void:
	await get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.get_base_dir().path_join(
				label + ".png"
			)) == OK, "capture")


func _write() -> void:
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"completed": result.failures.is_empty(),
				"failures": result.failures,
				"trials": trials,
				"numerical": numerical,
				"policy": "Greedy score, real Battle/AI/stats/consumption, seed 33. Trials independent. Depth 6 reached by declared transit victories, full HP, Protection, no equipment; original starter prepared deck, transit loot owned but unprepared. Native, primary/Sun split and full Sun allocations. Six-round elite cutoff is not defeat. Not continuous survival or human win-rate.",
			},
			"\t",
		)
	)


func _numeric_contract() -> void:
	var cards = preload("res://core/expedition/consumable_cards_state.gd").new()
	cards.prototype_revision = 1
	for level in [1, 6, 12]:
		cards.level = level
		for element in Progression.ELEMENTS:
			cards.masteries = Progression.empty_elements()
			cards.masteries[element] = Progression.element_budget(level)
			for row in Catalog.data().cards:
				for upgraded in [false, true]:
					var card: Dictionary = Catalog.card(row.id, upgraded)
					var impact: Dictionary = Runtime.Math.impact(
						card,
						Progression.POWER[level - 1],
						{ "distance": 2 },
						{ },
						"",
						"",
						{ },
						cards,
					)
					var raw: float = impact.raw
					numerical.append(
						{
							"id": row.id,
							"level": level,
							"element": element,
							"upgraded": upgraded,
							"raw": raw,
							"damage_r20": Runtime.Math.damage(raw, .2),
						}
					)
	check(numerical.size() == 1728, "all card forms, levels and elements measured")


func finish() -> void:
	_write()
	clear_battle()
	GameManager.cleanup_run_state()
	if is_instance_valid(driver):
		driver.cleanup_run_state()
		driver.free()
	Engine.time_scale = 1.0
	get_tree().quit(0 if result.failures.is_empty() else 1)
