extends "res://tools/catabase_run_balance_validation/full_run_probe.gd"
## Audit-only heuristic policies. Never loaded by production scenes.
## Scores are intentionally explicit: they are not an optimal-play oracle.
var audit_mode := "adaptive"
var audit_economy: Array[Dictionary] = []
var audit_turns: Array[Dictionary] = []
var audit_decks: Array[Dictionary] = []
var audit_current_turn := -1
var audit_depth := 0
var audit_recomposes := 0
var audit_retains := 0


func _parse_arguments() -> void:
	super._parse_arguments()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("audit="): audit_mode = argument.trim_prefix("audit=")


func _simulate_run(seed_value: int, difficulty: String, weapon: String, policy: String) -> Dictionary:
	audit_economy = []
	audit_turns = []
	audit_decks = []
	audit_recomposes = 0
	audit_retains = 0
	var result := await super._simulate_run(seed_value, difficulty, weapon, policy)
	result["deck_policy"] = audit_mode
	result["audit"] = {"mode": audit_mode, "economy": audit_economy.duplicate(true), "turns": audit_turns.duplicate(true), "decks": audit_decks.duplicate(true), "recomposes": audit_recomposes, "retains": audit_retains}
	return result


func _run_preparation(weapon: String) -> Dictionary:
	var selection := super._run_preparation(weapon)
	if audit_mode == "mobility" and weapon == "xiphos":
		# Legal menu choice, one-factor start variant: heal -> movement.
		selection.techniques[1] = "exp_feinte"
	if audit_mode == "armor_mixte": selection.armor = "mixte"
	return selection


func _fight_continuous(node: Dictionary, manager: HarnessManager, seed_value: int, weapon: String, policy: String) -> Dictionary:
	audit_current_turn = -1
	audit_depth = int(node.depth)
	var cards: CatabaseCards = manager.expedition.cards
	if cards != null:
		var families := {}
		for id in cards.active:
			var family := str(cards.copy_for(id).family)
			families[family] = int(families.get(family, 0)) + 1
		audit_decks.append({"depth": audit_depth, "size": cards.active.size(), "owned": cards.copies.size(), "gold": manager.expedition.gold, "families": families, "opening": cards.opening.map(func(id): return cards.copy_for(id).family), "pool": cards.entry_pool.duplicate()})
	return await super._fight_continuous(node, manager, seed_value, weapon, policy)


func _family_score(cards: CatabaseCards, family: String) -> float:
	if family == CatabaseCards.GESTURE: return 100.0
	var spell := cards.family_spell(family)
	if spell == null: return -100.0
	var hero: Unit = cards.owner().character.unit
	var score := 12.0
	if spell.deals_damage(): score += float(spell.get_scaled_damage(hero)) / maxf(1.0, hero.get_spell_ap_cost(spell))
	if spell.spell_range >= 3: score += 10.0
	if spell.spell_range >= 5: score += 5.0
	if spell.get_scaled_shield(hero) > 0: score += 8.0
	if family == "exp_souffle": score += 8.0 if audit_mode == "curated" else 45.0
	if family == "exp_ct_repercussion": score += 10.0
	if family == "exp_ct_repercussion" and audit_mode == "curated": score += 20.0
	if family in ["exp_feinte", "exp_marche"]: score += 10.0
	return score


func _manage_cards(session: ExpeditionSession, shop_allowed: bool) -> void:
	var cards: CatabaseCards = session.cards
	if cards == null or session.route.phase == "combat": return
	cards.sync_learned()
	var event := {"depth": int(session.route.get_current_node().depth), "gold_before": session.gold, "owned_before": cards.copies.size(), "added": [], "sold": [], "bought": [], "drops": cards.last_drops.map(func(id): return cards.copy_for(id).duplicate())}
	if audit_mode in ["adaptive", "speed", "swarm", "curated"]:
		var candidates := cards.copies.duplicate()
		candidates.sort_custom(func(a, b):
			var sa := _family_score(cards, str(a.family))
			var sb := _family_score(cards, str(b.family))
			return sa > sb if not is_equal_approx(sa, sb) else str(a.id) < str(b.id))
		for card in candidates:
			if card.id in cards.active: continue
			var same := cards.active.filter(func(id): return cards.copy_for(id).family == card.family).size()
			if audit_mode == "curated" and card.family == "exp_souffle" and same >= 1: continue
			if same >= (6 if card.family == CatabaseCards.GESTURE else 3): continue
			if audit_mode == "swarm":
				if cards.move_card(str(card.id)): event.added.append(card.family)
				continue
			var weakest := ""
			var low := INF
			for id in cards.active:
				var old_family := str(cards.copy_for(id).family)
				if old_family == CatabaseCards.GESTURE: continue
				var score := _family_score(cards, old_family)
				if score < low: low = score; weakest = id
			if not weakest.is_empty() and _family_score(cards, str(card.family)) > low + 2.0:
				if cards.move_card(str(card.id), weakest): event.added.append(card.family)
		var techniques := cards.active.filter(func(id): return cards.copy_for(id).family != CatabaseCards.GESTURE)
		techniques.sort_custom(func(a, b): return _family_score(cards, str(cards.copy_for(a).family)) > _family_score(cards, str(cards.copy_for(b).family)))
		if techniques.size() >= 2:
			if audit_mode == "curated":
				var chosen: Array[String] = []
				var families: Array[String] = []
				for id in techniques:
					var family := str(cards.copy_for(id).family)
					if family in families or family in ["exp_souffle", "exp_ct_repercussion"]: continue
					chosen.append(id)
					families.append(family)
					if chosen.size() == 2: break
				for i in chosen.size(): cards.set_opening(chosen[i], i + 2)
			else:
				cards.set_opening(techniques[0], 2)
				cards.set_opening(techniques[1], 3)
	if audit_mode in ["adaptive", "speed", "liquidate", "curated"]:
		for card in cards.copies.duplicate():
			if card.id not in cards.active and cards.sell(str(card.id)): event.sold.append(card.family)
	if shop_allowed and audit_mode in ["adaptive", "speed", "curated"]:
		var offers := cards.shop()
		for index in offers.size():
			var family := str(offers[index].family)
			if family == CatabaseCards.GESTURE: continue
			var count := cards.active.filter(func(id): return cards.copy_for(id).family == family).size()
			if audit_mode == "curated" and family == "exp_souffle" and count >= 1: continue
			if count >= 3: continue
			var low := INF
			var weakest := ""
			for id in cards.active:
				var old := str(cards.copy_for(id).family)
				if old == CatabaseCards.GESTURE: continue
				var score := _family_score(cards, old)
				if score < low: low = score; weakest = id
			if _family_score(cards, family) > low + 2.0 and session.gold >= int(CatabaseCards.BUY[cards.rarity(family)]) + 30:
				if cards.buy(index):
					event.bought.append(family)
					var id := str(cards.copies[-1].id)
					if cards.move_card(id, weakest): event.added.append(family)
	event["gold_after"] = session.gold
	event["active_size"] = cards.active.size()
	event["owned_after"] = cards.copies.size()
	audit_economy.append(event)


func _claim_combat_reward(session: ExpeditionSession, manager: HarnessManager, policy: String) -> Dictionary:
	_manage_cards(session, false)
	return super._claim_combat_reward(session, manager, policy)


func _resolve_halt(session: ExpeditionSession, manager: HarnessManager, policy: String, weapon: String) -> Dictionary:
	_manage_cards(session, true)
	return super._resolve_halt(session, manager, policy, weapon)


func _hero_action(hero: Unit, units: Array, grid: GridData, pathfinder: Pathfinder, caster: SpellCaster) -> Dictionary:
	var cards: CatabaseCards = CatabaseCards.for_actor(hero)
	var turn := int(_active_metrics.get("turns", 0))
	if cards != null and turn != audit_current_turn:
		audit_current_turn = turn
		var families := cards.hand.map(func(id): return cards.copy_for(id).family)
		var legal_damage := 0
		for spell: Spell in hero.spells:
			if not spell.deals_damage(): continue
			if units.any(func(unit): return unit.is_alive and unit.team != hero.team and caster.can_cast(hero, spell, unit.grid_pos)): legal_damage += 1
		audit_turns.append({"depth": audit_depth, "turn": turn, "hand": families, "unique": _unique_count(families), "legal_damage_now": legal_damage, "ap_start": hero.current_ap, "mp_start": hero.current_mp, "hp": hero.current_hp, "max_hp": hero.max_hp.get_int()})
	var action := super._hero_action(hero, units, grid, pathfinder, caster)
	if audit_mode in ["informed", "curated", "mobility", "armor_control", "armor_mixte"]:
		# The old greedy evaluator sees Repercussion's 0.01P marker, not the
		# real 1.5 * consumed bronze payload. Correct that blind spot in controls.
		var best := 0.0
		if str(action.get("type", "")) == "cast":
			var chosen: Spell = action.spell
			if chosen.deals_damage(): best = float(chosen.get_scaled_damage(hero)) / maxf(1.0, hero.get_spell_ap_cost(chosen))
		for spell: Spell in hero.spells:
			if not str(spell.spell_id).begins_with("exp_ct_repercussion"): continue
			var damage := roundi(1.5 * mini(int(hero.get_meta("ct_bronze", 0)), CatabaseCombatModifier.bronze_spend_cap(hero)))
			for enemy: Unit in units:
				if not enemy.is_alive or enemy.team == hero.team or not caster.can_cast(hero, spell, enemy.grid_pos): continue
				var score := float(mini(damage, enemy.current_hp)) / maxf(1.0, hero.get_spell_ap_cost(spell)) + (15.0 if damage >= enemy.current_hp else 0.0)
				if score > best:
					best = score
					action = {"type": "cast", "spell": spell, "cell": enemy.grid_pos}
	if audit_mode == "speed" and not hero.spells.any(func(spell): return str(spell.spell_id).begins_with("exp_ct_peage")):
		# Throughput trial: prefer a legal damaging cast to automatic guard.
		# Arc keeps its toll+shot preparation; this is not an exhaustive planner.
		var best := -1.0
		for spell: Spell in hero.spells:
			if not spell.deals_damage(): continue
			for enemy: Unit in units:
				if not enemy.is_alive or enemy.team == hero.team or not caster.can_cast(hero, spell, enemy.grid_pos): continue
				var damage := spell.get_scaled_damage(hero)
				var score := float(mini(damage, enemy.current_hp)) / maxf(1.0, hero.get_spell_ap_cost(spell)) + (20.0 if damage >= enemy.current_hp else 0.0)
				if score > best:
					best = score
					action = {"type": "cast", "spell": spell, "cell": enemy.grid_pos}
	if cards != null and audit_mode in ["pilot", "adaptive", "speed", "swarm", "liquidate", "mobility", "curated", "informed", "armor_control", "armor_mixte"]:
		# Base policy ignores direct heals. Apply the same remedy to all audit
		# controls so adaptive-vs-pilot isolates deck/economy, not healer competence.
		if hero.get_hp_ratio() <= 0.65:
			for spell in hero.spells:
				if spell.is_healing() and caster.can_cast(hero, spell, hero.grid_pos):
					action = {"type": "cast", "spell": spell, "cell": hero.grid_pos}
					break
		if action.is_empty() and not cards.recomposed and hero.current_ap >= 2:
			var worst := ""
			var low := INF
			for id in cards.hand:
				var score := _family_score(cards, str(cards.copy_for(id).family))
				if score < low: low = score; worst = id
			if not worst.is_empty() and cards.recompose(worst):
				audit_recomposes += 1
				var spells: Array[Spell] = []
				for id in cards.hand:
					for spell in cards.spells_for(id):
						if spell not in spells: spells.append(spell)
				hero.spells = spells
				action = super._hero_action(hero, units, grid, pathfinder, caster)
		if action.is_empty() and not cards.hand.is_empty():
			var keep := cards.hand[0]
			for id in cards.hand:
				if _family_score(cards, str(cards.copy_for(id).family)) > _family_score(cards, str(cards.copy_for(keep).family)): keep = id
			cards.retained = keep
			audit_retains += 1
	if not audit_turns.is_empty() and action.is_empty(): audit_turns[-1]["ap_unspent"] = hero.current_ap
	return action


func _unique_count(values: Array) -> int:
	var distinct := {}
	for value in values: distinct[value] = true
	return distinct.size()
