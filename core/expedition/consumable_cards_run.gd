extends RefCounted
signal changed
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
const Profile := preload("res://core/expedition/consumable_cards_profile.gd")
const Cards := preload("res://core/expedition/consumable_cards_state.gd")
const Checkpoint := preload("res://core/expedition/consumable_cards_checkpoint.gd")
const Battle := preload("res://core/expedition/consumable_cards_battle.gd")
const Economy := preload("res://core/expedition/consumable_card_economy.gd")
const Math := preload("res://core/expedition/consumable_card_math.gd")
var checkpoint := Checkpoint.new()
var cards
var battle
var last_error := ""


func create(selection: Dictionary, seed_value: int, path := Profile.SAVE_PATH) -> bool:
	var candidate = Profile.create_cards(selection)
	if candidate == null: return false
	candidate.run_seed = seed_value & 0x7fffffff
	checkpoint.path = path
	var previous := ExpeditionSaveService.read_snapshot(path)
	var chronicle: Dictionary = previous.get("chronicle", {}) if Checkpoint.validation_errors(previous).is_empty() else {}
	var run_id := "cc2-" + Crypto.new().generate_random_bytes(16).hex_encode()
	if not checkpoint.initialize(run_id, candidate, candidate.run_seed, selection.get("visual_variant", {}), chronicle):
		last_error = checkpoint.last_error
		return false
	cards = candidate
	return true


func resume(path := Profile.SAVE_PATH) -> bool:
	var candidate := Checkpoint.new()
	candidate.path = path
	if not candidate.restore():
		last_error = candidate.last_error
		return false
	checkpoint = candidate
	return _publish()


func dispose() -> void:
	if battle != null:
		battle.dispose()
		battle = null


func act(request: Dictionary) -> Dictionary:
	if checkpoint.state.is_empty(): return {"success": false, "reason": "run_absent"}
	var sequence := int(checkpoint.state.action_seq)
	var id := "%s/%d" % [checkpoint.state.run_id, sequence + 1]
	# Detached units must not drive global presentation or legacy subscribers
	# before persistence. This synchronous scope never yields to another action.
	var was_blocked := EventBus.is_blocking_signals()
	EventBus.set_block_signals(true)
	var response := checkpoint.transact(id, sequence, func(candidate: Dictionary): return _resolve(candidate, request))
	EventBus.set_block_signals(was_blocked)
	if response.success:
		if not _publish(): return {"success": false, "reason": "committed_state_invalid"}
		changed.emit()
	else:
		last_error = checkpoint.last_error if checkpoint.blocked else str(response.get("reason", "action_refused"))
	return response


## The same detached resolver predicts HP, guard, movement and choices. Global
## presentation signals are muted only for this synchronous, unpublished preview.
func preview(request: Dictionary) -> Dictionary:
	if battle == null: return {"success": false}
	var state := Cards.new()
	if not state.restore(cards.snapshot()): return {"success": false}
	var runtime = Battle.restore(state, battle.snapshot())
	if runtime == null: return {"success": false}
	var was_blocked := EventBus.is_blocking_signals()
	EventBus.set_block_signals(true)
	var result: Dictionary = runtime.command(request)
	EventBus.set_block_signals(was_blocked)
	if result.success:
		result["units"] = []
		var actors: Array = [runtime.hero]
		actors.append_array(runtime.enemies)
		for unit in actors:
			var before: Unit = battle.unit_for(str(unit.unit_id))
			result.units.append({"id": str(unit.unit_id), "name": before.unit_name, "hp": unit.current_hp, "hp_delta": unit.current_hp - before.current_hp, "guard": unit.current_shield, "guard_delta": unit.current_shield - before.current_shield, "cell": [unit.grid_pos.x, unit.grid_pos.y]})
		result["ap"] = runtime.hero.current_ap
		result["mp"] = runtime.hero.current_mp
		result["choice"] = state.pending_choice.duplicate(true)
	runtime.dispose()
	return result


func _publish() -> bool:
	var next_cards := Cards.new()
	if not next_cards.restore(checkpoint.state.cards): return false
	var next_battle = null
	if not checkpoint.state.combat.is_empty():
		next_battle = Battle.restore(next_cards, checkpoint.state.combat)
		if next_battle == null: return false
	dispose()
	cards = next_cards
	battle = next_battle
	last_error = ""
	return true


func _resolve(candidate: Dictionary, request: Dictionary) -> Dictionary:
	var next_cards := Cards.new()
	if not next_cards.restore(candidate.cards): return _failure("invalid_cards")
	var kind := str(request.get("kind", ""))
	if candidate.phase == "complete": return _failure("run_complete")
	if kind == "abandon":
		if candidate.phase == "preparation":
			candidate.route = {"depth": 0, "encounter": 0, "hero_hp": 110, "hero_max_hp": 110}
		candidate.phase = "complete"
		candidate.route["outcome"] = "abandoned"
		candidate.combat.clear()
		next_cards.finish_combat()
		candidate.cards = next_cards.snapshot()
		return {"success": true, "kind": "abandon"}
	if candidate.phase == "combat":
		var runtime = Battle.restore(next_cards, candidate.combat)
		if runtime == null: return _failure("invalid_combat")
		var result: Dictionary = runtime.next_actor() if kind == "next_actor" else runtime.command(request)
		if result.get("success", false):
			candidate.cards = next_cards.snapshot()
			candidate.combat = runtime.snapshot()
			if not runtime.outcome.is_empty():
				candidate.route.erase("equipment_health_basis")
				candidate.route["hero_hp"] = runtime.hero.current_hp
				candidate.route["hero_max_hp"] = runtime.hero.max_hp.get_int()
				candidate.route["outcome"] = runtime.outcome
				candidate.route["last_combat"] = {"encounter": int(runtime.encounter.index), "turns": next_cards.round_index, "outcome": runtime.outcome}
				if runtime.outcome == "victory":
					var killed: Array[String] = []
					for unit in runtime.enemies:
						if not unit.is_alive and not unit.get_meta("cc2_sacrificed", false): killed.append(str(unit.unit_id))
					var reward := Economy.collect_victory(next_cards, runtime.encounter, killed)
					if not reward.success:
						runtime.dispose()
						return reward
					candidate.route["reward"] = reward.reward
					var stats := Math.stats(next_cards.level, next_cards.attributes, Math.equipment_mods(next_cards.equipped), next_cards)
					candidate.route.hero_hp = mini(int(stats.hp), int(candidate.route.hero_hp) + maxi(0, int(stats.hp) - int(candidate.route.hero_max_hp)))
					candidate.route.hero_max_hp = int(stats.hp)
					candidate.phase = "complete" if int(runtime.encounter.index) == 12 else "reward"
				else: candidate.phase = "complete"
				next_cards.finish_combat()
				candidate.cards = next_cards.snapshot()
				candidate.combat.clear()
			runtime.dispose()
			return result
		runtime.dispose()
		return result
	# Every noncombat decision is executed on the detached card controller.
	var response := {"success": true, "kind": kind}
	match kind:
		"depart", "continue":
			if next_cards.level >= 4 and next_cards.specialization.is_empty(): return _failure("choose_specialization")
			var depth := int(candidate.route.get("depth", 0)) + 1
			if depth > 20: return _failure("route_complete")
			if kind == "depart" and candidate.phase != "preparation": return _failure("already_departed")
			if candidate.phase == "preparation" and kind != "depart": return _failure("departure_required")
			candidate.route["depth"] = depth
			candidate.route["outcome"] = ""
			var encounter_index := 0
			for entry in Catalog.data().route:
				if int(entry.depth) == depth: encounter_index = int(entry.index)
			if encounter_index > 0:
				candidate.route.erase("equipment_health_basis")
				var runtime := Battle.new()
				if not runtime.initialize(next_cards, encounter_index, int(candidate.route.get("hero_hp", -1))):
					runtime.dispose()
					return _failure("encounter_unavailable")
				candidate.phase = "combat"
				candidate.combat = runtime.snapshot()
				candidate.route["encounter"] = encounter_index
				candidate.route["hero_hp"] = runtime.hero.current_hp
				candidate.route["hero_max_hp"] = runtime.hero.max_hp.get_int()
				runtime.dispose()
			else:
				candidate.phase = "halt"
				candidate.route["merchant"] = ""
				for entry in Catalog.data().route:
					if int(entry.depth) == depth - 1:
						if entry.shopAfter:
							candidate.route.merchant = "depth_%02d" % depth
							Economy.market(next_cards, candidate.route.merchant, int(entry.index))
						if entry.refugeAfter:
							_heal_route(candidate, next_cards, .5 if int(entry.index) == 11 else .35)
		"prepare":
			if not next_cards.move_card(str(request.get("uid", "")), str(request.get("replace", ""))): return _failure("preparation")
		"opening":
			if not next_cards.set_opening(str(request.get("uid", ""))): return _failure("opening")
		"specialization":
			if not next_cards.specialize(str(request.get("id", ""))): return _failure("specialization")
		"upgrade":
			if not next_cards.upgrade_copy(str(request.get("family", ""))): return _failure("upgrade")
		"attribute":
			var attribute := str(request.get("id", ""))
			if not next_cards.spend_attribute(attribute): return _failure("attribute")
			_rebuild_route(candidate, next_cards, next_cards.prototype_revision == 1)
		"equipment":
			var uid := str(request.get("uid", ""))
			var slot := str(request.get("slot", ""))
			if uid.is_empty(): next_cards.equipped.erase(slot)
			else:
				var definition := ""
				for item in next_cards.equipment_copies:
					if item.id == uid: definition = item.definition
				var valid := false
				for row in Catalog.data().equipment:
					if row.id == definition and row.slot == slot: valid = true
				if not valid: return _failure("equipment")
				next_cards.equipped[slot] = definition
			_rebuild_route(candidate, next_cards, true)
		"relic":
			var id := str(request.get("id", ""))
			if id in next_cards.active_relics: next_cards.active_relics.erase(id)
			elif id in next_cards.owned_relics and next_cards.active_relics.size() < 2: next_cards.active_relics.append(id)
			else: return _failure("relic")
		"follow":
			var id := str(request.get("family", ""))
			if id in next_cards.followed_families: next_cards.followed_families.erase(id)
			elif not Catalog.card(id).is_empty() and next_cards.followed_families.size() < 2: next_cards.followed_families.append(id)
			else: return _failure("follow")
		"purchase":
			var visit := str(candidate.route.get("merchant", ""))
			if candidate.phase != "halt" or visit.is_empty(): return _failure("merchant")
			var purchase: Variant = request.get("purchase")
			if not purchase is Dictionary: return _failure("purchase")
			response = Economy.transact(next_cards, visit, purchase)
			if not response.success: return response
			if not response.replayed: _heal_route(candidate, next_cards, float(response.receipt.get("heal_fraction", 0)))
		_: return _failure("unknown_command")
	candidate.cards = next_cards.snapshot()
	return response


static func _rebuild_route(candidate: Dictionary, state, proportional: bool) -> void:
	var stats := Math.stats(state.level, state.attributes, Math.equipment_mods(state.equipped), state)
	var before := int(candidate.route.get("hero_max_hp", stats.hp))
	var hp := int(candidate.route.get("hero_hp", before))
	candidate.route["hero_max_hp"] = int(stats.hp)
	if proportional:
		# Preserve the unrounded ratio across all equipment changes, including
		# reloads. Repeated swaps cannot accumulate integer rounding as healing.
		if not candidate.route.has("equipment_health_basis"):
			candidate.route.equipment_health_basis = {"hp": hp, "maximum": maxi(1, before)}
		var basis: Dictionary = candidate.route.equipment_health_basis
		candidate.route["hero_hp"] = mini(int(stats.hp), Math.rounded(float(basis.hp) / float(basis.maximum) * stats.hp))
	else:
		candidate.route.erase("equipment_health_basis")
		candidate.route["hero_hp"] = mini(int(stats.hp), hp + maxi(0, int(stats.hp) - before))


static func _heal_route(candidate: Dictionary, state, fraction: float) -> void:
	if fraction <= 0: return
	candidate.route.erase("equipment_health_basis")
	var maximum := int(candidate.route.get("hero_max_hp", 110))
	var multiplier := 1.0 + float(Math.equipment_mods(state.equipped).get("healing", 0))
	candidate.route["hero_hp"] = mini(maximum, int(candidate.route.get("hero_hp", maximum)) + Math.rounded(maximum * fraction * multiplier))


static func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}
