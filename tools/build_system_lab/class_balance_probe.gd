extends "res://tools/catabase_run_balance_validation/full_run_probe.gd"
## Real shared-grid combats. Fixed greedy policy; these are not human win rates.
const Classes := preload("res://core/expedition/class_card_catalog.gd")


func _run() -> void:
	label = "class_before"
	var selected_seeds := [2401]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("label="):
			label = arg.trim_prefix("label=").validate_filename()
		if arg.begins_with("seeds="):
			selected_seeds = []
			for value in arg.trim_prefix("seeds=").split(","):
				selected_seeds.append(int(value))
	output = "res://artifacts/dev/" + label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	_connect_metric_signals()
	for seed_value in selected_seeds:
		for id in Classes.CLASSES:
			var result := await _class_run(id, seed_value)
			results.append(result)
			_store_class_report()
		for weapon in ["marteau", "arc"]:
			_cards_mode = true
			results.append(await _simulate_run(seed_value, "normal", weapon, "balanced"))
			_store_class_report()
	_disconnect_metric_signals()
	_store_class_report()
	get_tree().quit(0 if errors.is_empty() else 1)


func _store_class_report() -> void:
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"cases": results,
				"errors": errors,
				"policy": "shared greedy balanced; power, native mastery, first specialization; auto-equip loot; no deck adaptation",
				"human_win_rate_claim": false,
			},
			"\t",
		)
	)
	file.close()


func _class_run(id: String, seed_value: int) -> Dictionary:
	var manager := HarnessManager.new()
	add_child(manager)
	manager.expedition_save_path = ProjectSettings.globalize_path(
		output.path_join("resume_%s_%d.json" % [id, seed_value])
	)
	manager._cards_departure_selection = Classes.preset(id)
	var ok := manager.start_expedition(seed_value, { }, false, true, "normal", true)
	var session: ExpeditionSession = manager.expedition
	if (
		not ok
		or not session \
				.prepare_start(Classes.preset(id), manager.run_inventory, manager.item_catalog) \
				.success
		or not session.enter("d01_0")
	):
		errors.append("class start failed: " + id)
		manager.cleanup_run_state()
		manager.queue_free()
		return { "class": id, "outcome": "setup_error" }
	var result := { "class": id, "seed": seed_value, "combats": [], "outcome": "incomplete" }
	_active_policy = "balanced"
	for transition in 80:
		var node := session.route.get_current_node()
		if session.route.phase == "combat":
			var combat := await _fight_continuous(node, manager, seed_value, id, "balanced")
			result.combats.append(combat)
			print(
				"CLASS_BALANCE ",
				id,
				" seed=",
				seed_value,
				" depth=",
				node.depth,
				" won=",
				combat.won,
				" turns=",
				combat.turns,
				" hp_lost=",
				combat.hp_damage_received,
			)
			if not combat.won:
				result.outcome = combat.termination
				break
			if not session.combat_won():
				errors.append("class victory boundary: " + id)
				break
		if session.route.phase == "reward":
			var champion := session.character.champion_progression
			while champion.unspent_attribute_points > 0:
				session.character.spend_champion_attribute(&"power")
			if champion.current_level >= 4 and session.cards.specialization.is_empty():
				session.cards.specialize(Classes.SPECS[id][0][0])
			while session.cards.train(id):
				pass
			for copy in session.cards.active:
				session.cards.upgrade_copy(copy)
			for step in 8:
				if session.advancement_step.is_empty():
					break
				if session.advancement_step == "advancement":
					session.cards.resolve_progression("skip")
				else:
					session.advance_level_step()
			_equip_class_loot(manager)
			var halt := ExpeditionRouteCatalog.is_halt(str(node.kind))
			if halt and session.character.unit.get_hp_ratio() < 1.:
				session.use_hub_service("rest", manager.run_inventory, manager.item_catalog)
			var reward := "finish" if int(node.depth) == 20 else "leave_hub" if halt else "class_continue"
			if not session.claim(reward, manager.run_inventory, manager.item_catalog).success:
				errors.append("class reward boundary: " + id)
				break
		if session.route.phase == "complete":
			result.outcome = "completed"
			break
		var next := Contract.choose_route_node(
			session.route.get_available_nodes(),
			seed_value,
			session.route.completed_node_ids.size() + 1,
		)
		if next.is_empty() or not session.enter(str(next.id)):
			errors.append("class route boundary: " + id)
			break
	manager.cleanup_run_state()
	manager.queue_free()
	await get_tree().process_frame
	return result


func _equip_class_loot(manager: HarnessManager) -> void:
	var service := EquipmentService.new()
	service.initialize(manager.item_catalog)
	for item in manager.run_inventory.get_slots().duplicate():
		if item == null:
			continue
		var definition := manager.item_catalog.get_definition(item.definition_id)
		if not definition.is_equippable():
			continue
		var worn := manager.expedition.character.equipment_loadout.get_item(
			definition.equipment_slot
		)
		if worn != null:
			var old := str(worn.definition_id).split("_")
			var fresh := str(item.definition_id).split("_")
			if old.size() == 5 and fresh.size() == 5 and int(old[2]) > int(fresh[2]):
				continue
		service.equip(
			manager.run_inventory,
			manager.expedition.character,
			item.instance_id,
			definition.equipment_slot,
		)
