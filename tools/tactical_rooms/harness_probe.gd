extends "res://tools/catabase_run_balance_validation/full_run_probe.gd"
## Integration probe, not balance: independent starter heroes with explicit extra HP.
const Rooms = preload("res://core/expedition/card_tactical_room_catalog.gd")
const Cards = preload("res://core/expedition/class_card_catalog.gd")


func _run() -> void:
	output = "res://artifacts/dev/tactical-harness"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("output="):
			output = argument.trim_prefix("output=")
	DirAccess.make_dir_recursive_absolute(output)
	_connect_metric_signals()
	var visited := { }
	for node in ExpeditionRouteCatalog.create_nodes(42):
		var id := Rooms.id_for(node)
		if id.is_empty() or visited.has(id):
			continue
		visited[id] = true
		var manager := HarnessManager.new()
		add_child(manager)
		manager.expedition_save_path = output.path_join(id + "-save.json")
		manager._cards_departure_selection = Cards.preset("gardien")
		if not manager.start_expedition(42, { }, false, true, "normal", true):
			errors.append(id + ": start failed")
			continue
		var preparation: Dictionary = manager.expedition.prepare_start(
			Cards.preset("gardien"),
			manager.run_inventory,
			manager.item_catalog,
		)
		if not preparation.success:
			errors.append(id + ": preparation failed")
			continue
		manager.expedition.route.current_node_id = node.id
		manager.expedition.route.phase = "combat"
		var hero: Unit = manager.expedition.character.unit
		hero.max_hp.add_modifier(1000, Stat.ModType.FLAT, "integration_probe")
		hero.heal(1000)
		var result := await _fight_continuous(node, manager, 42, "gardien", "balanced")
		if not result.has("tactical_room") or result.tactical_room.id != id or result.turns < 1:
			errors.append(id + ": room rules not observed")
		results.append(result)
		manager.cleanup_run_state()
		manager.queue_free()
		await get_tree().process_frame
	_disconnect_metric_signals()
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{ "cases": results, "errors": errors, "balance_claim": false, "extra_hp": 1000 },
			"\t",
		)
	)
	file.close()
	print("TACTICAL_HARNESS cases=", results.size(), " errors=", errors.size())
	get_tree().quit(0 if results.size() == 5 and errors.is_empty() else 1)
