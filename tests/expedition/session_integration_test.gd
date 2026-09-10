extends Node
## Integration outcomes are simulated. BattleFlowProbe separately plays real combat.
const CANONICAL_RUN = preload("res://data/runs/odyssey.tres")
const COMBAT_HUD = preload("res://ui/recraft_hud_v1/combat/combat_hud_recraft_v1.tscn")

class HarnessManager:
	extends "res://core/game_manager.gd"
	var requested_battles := 0
	var test_save_path: String = OS.get_environment("TEMP").path_join("catabase-integration-%d.json" % Time.get_ticks_usec())
	func start_next_battle() -> void:
		_room_outcome_resolved = false
		requested_battles += 1
	func save_expedition(path: String = ExpeditionSaveService.SAVE_PATH) -> bool:
		return super.save_expedition(test_save_path if path == ExpeditionSaveService.SAVE_PATH else path)

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_fixed_canonical_start()
	_test_complete_route()
	_test_halt_economy_and_restore()
	_test_specialized_itinerary_services()
	_test_atomic_rejections()
	_test_defeat()
	print("Catabase integration: %d checks, %d failures (simulated victories)" % [_checks, _failures.size()])
	for failure in _failures: printerr(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _manager(seed_value := 2401) -> HarnessManager:
	var manager := HarnessManager.new()
	manager.expedition_save_path = manager.test_save_path
	manager._ready()
	var run := CANONICAL_RUN.duplicate(false) as RunData
	run.randomize_seed_each_run = false
	run.default_seed = seed_value
	manager.start_run(run)
	_check(manager.run_active and manager.expedition != null, "Canonical launch did not create route")
	return manager


func _dispose(manager) -> void:
	manager.cleanup_run_state()
	manager._exit_tree()
	if FileAccess.file_exists(manager.test_save_path):
		DirAccess.remove_absolute(manager.test_save_path)
	manager.free()


func _test_fixed_canonical_start() -> void:
	var profile := CANONICAL_RUN.content_profile.hero_profiles[0].progression_profile.champion_progression_profile
	var hp_curve := profile.base_hp_by_level.duplicate()
	var m := _manager()
	var state: CharacterRunState = m.get_character_state(&"achilles")
	var starter: Array[StringName] = [&"achilles_peleid_strike", &"achilles_fulminant_dash", &"achilles_pelion_shot", &"achilles_bronze_guard"]
	_check(m.expedition.route.phase == "combat", "Launch should enter first combat directly")
	_check(m.expedition.route.current_node_id == "d01_0", "Opening changed with path")
	_check(m.requested_battles == 1, "Launch did not request a battle")
	_check(m._active_run_name == "Catabase", "Separate experimental name survived")
	_check(CANONICAL_RUN.rooms.size() == 15 and m.rooms.size() == 20, "Room pool and itinerary confused")
	_check(state.loadout.get_spell_slot_ids() == starter, "Opening spells/order changed")
	_check(state.unit.max_hp.get_int() == 110 and state.unit.attack_power.get_int() == 18, "Opening stats changed")
	_check(m.expedition.build.points == 0, "Pre-run currency permits prebuild")
	_check(not m.purchase_expedition_technique("colere.root").get("success", false), "Purchased before first victory")
	_check(not m.equip_expedition_spell(&"", 3), "Removed starter during opening")
	_check(m.get_current_room().grid_layout == CANONICAL_RUN.rooms[0].grid_layout, "Opening layout changed")
	_check(m.get_current_encounter_definition().roster_units[0].max_hp == CANONICAL_RUN.rooms[0].encounter_definition.roster_units[0].max_hp, "Opening enemy changed")
	_check(profile.base_hp_by_level == hp_curve, "Runtime mutated authored progression")
	var entry := _json(m.get_expedition_snapshot())
	_check(not entry.is_empty(), "Opening entry not saved")
	var restored := _manager(100)
	_check(restored.resume_expedition(m.test_save_path), "Opening cannot resume")
	_check(_json(restored.get_expedition_snapshot()) == entry, "Opening resume changed state")
	_dispose(restored)
	# A different adventure must retain its own authority.
	var trio := load("res://data/runs/first_run.tres") as RunData
	m.start_run(trio)
	_check(m.expedition == null, "Catabase route leaked into trio")
	_check(m.get_ordered_character_states().size() == 3, "Trio hero resolution changed")
	_dispose(m)


func _win(manager) -> void:
	manager.begin_combat_report()
	manager.on_battle_won()


func _claim(manager) -> void:
	if int(manager.expedition.route.get_current_node().depth) == ExpeditionBuildState.CAPACITY_DEPTH:
		_check(manager.choose_expedition_capacity("slot").get("success", false), "Sixth slot refused at XII")
	var offers: Array = manager.expedition.reward_options(manager.item_catalog)
	_check(not offers.is_empty(), "No action at reward boundary")
	if offers.is_empty(): return
	var choice: Dictionary = offers.back()
	_check(manager.claim_expedition_reward(str(choice.id)).get("success", false), "Cannot claim/leave")
	_check(not manager.claim_expedition_reward(str(choice.id)).get("success", false), "Duplicated destination claim")


func _test_complete_route() -> void:
	var m := _manager(317)
	var fights := 0
	var halts := 0
	var xp := 0
	var seen := {}
	for depth in range(1, 21):
		if depth > 1:
			var options: Array = m.expedition.route.get_available_nodes()
			_check(not options.is_empty(), "Route dead-end")
			if options.is_empty(): break
			_check(m.choose_expedition_node(str(options[depth % options.size()].id)), "Route choice refused")
		var node: Dictionary = m.expedition.route.get_current_node()
		if m.expedition.route.phase == "combat":
			fights += 1
			var id: StringName = m.get_current_encounter_definition().encounter_id
			_check(not seen.has(id), "Repeated encounter XP ID")
			seen[id] = true
			xp += ExpeditionRunFactory.xp_for(node)
			_win(m)
		else:
			halts += 1
		var character: CharacterRunState = m.expedition.character
		_check(character.champion_progression.current_xp == xp, "XP missing, duplicated, or earned from empty hub")
		_check(character.champion_progression.unspent_mastery_points == 0, "Two mastery budgets active")
		_check(m.expedition.route.phase == "reward", "Missing reward boundary")
		var before := _json(m.get_expedition_snapshot())
		m.on_battle_won()
		m.expedition.award_destination()
		_check(_json(m.get_expedition_snapshot()) == before, "Repeated outcome changed state")
		if depth == 1:
			_check(m.purchase_expedition_technique("colere.root").get("success", false), "First doctrine root refused")
			_check(m.purchase_expedition_technique("briseur.learn_a").get("success", false), "First new technique refused")
			_check(m.equip_expedition_spell(&"exp_crochet", 3), "Cannot replace defense after victory")
		if character.champion_progression.current_level >= 5:
			_check(character.loadout.get_active_slot_count() >= 5, "Level five lacks fifth slot")
		_claim(m)
		if depth < 20:
			_check(m.run_active and m.expedition.route.phase == "map", "Premature end")
	_check(fights >= 14 and fights <= 16 and halts == 20 - fights, "15/5 route envelope violated")
	_check(m.requested_battles == fights, "Fight nodes did not launch production battles")
	_check(not m.run_active and m.expedition.route.phase == "complete", "Final boss did not finish run")
	_check(not FileAccess.file_exists(m.test_save_path), "Completed run remains resumable")
	_check(m.get_last_run_result().get("victory", false), "Final result lost victory")
	_dispose(m)


func _advance_to_halt(manager) -> void:
	_win(manager)
	_claim(manager)
	for depth in range(2, 5):
		var choices: Array = manager.expedition.route.get_available_nodes()
		var selected: Dictionary = choices[0]
		# Prefer an actual camp at the first convergence, if reachable.
		for node in choices:
			if node.kind == "hub": selected = node
		manager.choose_expedition_node(str(selected.id))
		if manager.expedition.route.phase == "combat": _win(manager)
		if depth < 4: _claim(manager)


func _test_halt_economy_and_restore() -> void:
	var m := _manager(2401)
	# Existing saves keep universal halts and their purchase receipts.
	m.expedition.route.initialize(2401, 3)
	m.expedition.route.choose_node("d01_0")
	_advance_to_halt(m)
	_check(ExpeditionRouteCatalog.is_halt(str(m.expedition.route.get_current_node().kind)), "First halt absent")
	var hp_before: int = m.expedition.character.unit.current_hp
	m.expedition.character.unit.current_hp -= 20
	var services: Array = m.expedition.hub_services(m.item_catalog)
	_check(services.size() >= 4 and services.size() <= 5, "Halt missing distinct interactions")
	var gold_before: int = m.expedition.gold
	_check(m.use_catabase_hub_service("lore").get("success", false), "Lore service failed")
	_check(m.expedition.gold == gold_before + 20, "Lore reward incorrect")
	var after_lore := _json(m.get_expedition_snapshot())
	_check(not m.use_catabase_hub_service("lore").get("success", false), "Farmed lore reward twice")
	_check(_json(m.get_expedition_snapshot()) == after_lore, "Failed lore transaction mutated state")
	_check(m.use_catabase_hub_service("rest").get("success", false), "Rest purchase failed")
	_check(m.expedition.character.unit.current_hp > hp_before - 20, "Paid rest did not heal")
	var stock: Dictionary = services[0]
	var buy: Dictionary = m.use_catabase_hub_service(str(stock.id))
	_check(buy.get("success", false), "Could not buy first merchant equipment with earned gold")
	var instance: ItemInstance = null
	for item in m.run_inventory.get_slots():
		if item != null and str(item.definition_id) == str(stock.item_id): instance = item
	_check(instance != null, "Purchased item missing from inventory")
	if instance != null:
		var definition: ItemDefinition = m.item_catalog.get_definition(instance.definition_id)
		_check(m.equip_inventory_item(instance.instance_id, &"achilles", definition.equipment_slot).get("success", false), "Cannot equip purchased gear")
	_check(m.expedition.route.phase == "reward", "One service prematurely left the hub")
	for service in m.expedition.hub_services(m.item_catalog):
		if service.id == "branch:elements":
			_check(m.use_catabase_hub_service("branch:elements").get("success", false), "Paid branch discovery failed")
			_check(m.expedition.build.is_axis_discovered("elements"), "Discovery did not unlock new tree branch")
	var saved := _json(m.get_expedition_snapshot())
	var restored := _manager(17)
	var truncated := saved.duplicate(true)
	truncated.session.hub_stock_ids = [saved.session.hub_stock_ids[0]]
	_check(not restored.restore_expedition_snapshot(truncated), "Accepted merchant stock that would cause invalid index")
	_check(restored.restore_expedition_snapshot(saved), "Halt save restore failed")
	_check(_json(restored.get_expedition_snapshot()) == saved, "Halt receipts/stock/gear changed on restore")
	_check(not restored.use_catabase_hub_service(str(stock.id)).get("success", false), "Restoration refreshed stock")
	_check(restored.claim_expedition_reward("leave_hub").get("success", false), "Cannot leave after multiple services")
	_dispose(restored)
	_dispose(m)


func _test_specialized_itinerary_services() -> void:
	for kind in ["hub", "merchant", "lore", "sanctuary"]:
		var m := _manager(2401)
		var target_depth := 8 if kind == "sanctuary" else 4
		var can_reach := {}
		for node in m.expedition.route.nodes:
			if int(node.depth) == target_depth and str(node.kind) == kind and not node.hidden:
				can_reach[str(node.id)] = true
		for depth in range(target_depth - 1, 0, -1):
			for node in m.expedition.route.nodes:
				if int(node.depth) != depth:
					continue
				for edge in node.edges:
					if can_reach.has(str(edge)):
						can_reach[str(node.id)] = true
		for depth in range(1, target_depth + 1):
			if depth > 1:
				for option in m.expedition.route.get_available_nodes():
					if can_reach.has(str(option.id)):
						_check(m.choose_expedition_node(str(option.id)), "Specialized halt path inaccessible")
						break
			if m.expedition.route.phase == "combat":
				_win(m)
			if depth < target_depth:
				_claim(m)
		_check(str(m.expedition.route.get_current_node().kind) == kind, "Did not reach advertised halt")
		var services: Array = m.expedition.hub_services(m.item_catalog)
		_check(services.size() == (3 if kind == "merchant" else 1), "Halt offers unrelated services")
		for service in services:
			_check(str(service.kind) == kind, "Service does not match map promise")
		var invalid_service := "rest" if kind != "hub" else "lore"
		var before := _json(m.get_expedition_snapshot())
		_check(not m.use_catabase_hub_service(invalid_service).get("success", false), "Can use a service from discarded halt")
		_check(_json(m.get_expedition_snapshot()) == before, "Unavailable service mutated session")
		m.expedition.character.unit.current_hp -= 30
		var hp_before: int = m.expedition.character.unit.current_hp
		var gold_before: int = m.expedition.gold
		var service: Dictionary = services[0]
		_check(m.use_catabase_hub_service(str(service.id)).get("success", false), "Advertised halt service failed")
		match kind:
			"hub":
				_check(m.expedition.character.unit.current_hp > hp_before, "Refuge did not heal")
				_check(m.expedition.gold == gold_before, "Free refuge charged gold")
			"merchant":
				_check(m.expedition.gold == gold_before - int(service.cost), "Merchant cost incorrect")
				_check(m.expedition.character.unit.current_hp == hp_before, "Merchant healed for free")
			"lore":
				_check(m.expedition.gold == gold_before + 20, "Memory oboles missing")
				_check("d08_secret" in m.expedition.route.revealed_node_ids, "Memory failed to reveal secret")
			"sanctuary":
				_check(m.expedition.build.is_axis_discovered(str(service.branch_id)), "Sanctuary failed to unlock branch")
				_check(m.expedition.gold == gold_before - int(service.cost), "Branch cost incorrect")
		var saved := _json(m.get_expedition_snapshot())
		var restored := _manager(17)
		_check(restored.restore_expedition_snapshot(saved), "Specialized halt receipt failed to restore")
		_check(_json(restored.get_expedition_snapshot()) == saved, "Specialized save changed on restore")
		_check(not restored.use_catabase_hub_service(str(service.id)).get("success", false), "Reload repeated service")
		_dispose(restored)
		_dispose(m)


func _test_atomic_rejections() -> void:
	var m := _manager(91)
	_win(m)
	var valid := _json(m.get_expedition_snapshot())
	var bad := valid.duplicate(true)
	bad.version = 1
	_check(not m.restore_expedition_snapshot(bad), "Accepted obsolete expedition snapshot")
	_check(_json(m.get_expedition_snapshot()) == valid, "Bad snapshot modified current state")
	bad = valid.duplicate(true)
	bad.session.build.current_level = 12
	_check(not m.restore_expedition_snapshot(bad), "Accepted level inconsistent with progression")
	bad = valid.duplicate(true)
	bad.session.hub_stock_ids = ["invented"]
	_check(not m.restore_expedition_snapshot(bad), "Accepted invented stock")
	_check(_json(m.get_expedition_snapshot()) == valid, "Rejected stock changed state")
	var inventory := _json(m.get_inventory_equipment_snapshot())
	_claim(m)
	m.choose_expedition_node(str(m.expedition.route.get_available_nodes()[0].id))
	var locked := _json(m.get_expedition_snapshot())
	_check(not m.restore_inventory_equipment_snapshot(inventory), "Legacy restore bypassed combat lock")
	_check(_json(m.get_expedition_snapshot()) == locked, "Legacy restore changed engaged kit")
	_dispose(m)


func _test_defeat() -> void:
	var m := _manager(55)
	_check(FileAccess.file_exists(m.test_save_path), "Opening entry save missing")
	m.begin_combat_report()
	m.on_battle_lost()
	_check(not m.run_active, "Defeat did not end run")
	_check(not FileAccess.file_exists(m.test_save_path), "Defeat can be resumed")
	_dispose(m)


func _json(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value)) as Dictionary


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)
