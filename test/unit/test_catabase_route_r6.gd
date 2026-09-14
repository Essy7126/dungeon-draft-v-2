extends GutTest
## Transaction/graph tests simulate victories; they are not combat balance evidence.
const R6 := preload("res://core/expedition/catabase_route_v6.gd")
var managers: Array = []


class Manager:
	extends "res://core/game_manager.gd"
	func start_next_battle() -> void:
		pass


	func _request_scene_change(
		_path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		pass


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


func _manager(mode: String = "normal") -> Manager:
	var manager := Manager.new()
	manager.expedition_save_path = "user://ct_r6_contract_%d.json" % Time.get_ticks_usec()
	add_child(manager)
	managers.append(manager)
	assert_true(manager.start_expedition(2401, { }, false, true, mode))
	return manager


func after_each() -> void:
	for manager in managers:
		manager.cleanup_run_state()
		ExpeditionSaveService.remove_snapshot(manager.expedition_save_path)
		manager.queue_free()
	managers.clear()
	await get_tree().process_frame


func test_every_ordinary_path_has_twelve_fights_three_elites_three_refuges_and_fixed_xp() -> void:
	for seed_value in [1, 2401, 8711]:
		var route := ExpeditionRouteState.new()
		route.initialize(seed_value)
		var by_id := { }
		for node in route.nodes:
			by_id[str(node.id)] = node
		var paths: Array = []
		_collect_paths(by_id, "d01_0", [], paths)
		assert_eq(paths.size(), 81)
		for path: Array in paths:
			var fights: Array[int] = []
			var elites: Array[int] = []
			var refuges: Array[int] = []
			var xp := 0
			for node: Dictionary in path:
				if ExpeditionRouteCatalog.is_combat(str(node.kind)):
					fights.append(int(node.depth))
					xp += ExpeditionRunFactory.xp_for(node)
					assert_true(ResourceLoader.exists(str(node.room_resource)))
				elif not bool(node.preparation_only) and node.kind == "hub":
					refuges.append(int(node.depth))
				if node.kind == "elite":
					elites.append(int(node.depth))
			assert_eq(path.size(), 20)
			assert_eq(fights, R6.COMBAT_DEPTHS)
			assert_eq(elites, R6.ELITE_DEPTHS)
			assert_eq(refuges, R6.REFUGE_DEPTHS)
			assert_eq(xp, 2785)


func _collect_paths(by_id: Dictionary, id: String, previous: Array, paths: Array) -> void:
	var node: Dictionary = by_id[id]
	if bool(node.hidden):
		return
	var path := previous.duplicate()
	path.append(node)
	if int(node.depth) == 20:
		paths.append(path)
		return
	for edge: String in node.edges:
		_collect_paths(by_id, edge, path, paths)


func test_lethe_keeps_five_escales_and_secrets_preserve_family() -> void:
	var route := ExpeditionRouteState.new()
	route.initialize(2401)
	var titles: Array[String] = []
	var by_id := { }
	for node in route.nodes:
		by_id[str(node.id)] = node
	for node in route.nodes:
		if node.route_family == "lethe" and int(node.depth) in [2, 3, 4, 5, 6]:
			titles.append(str(node.title))
		for edge in node.edges:
			var next: Dictionary = by_id[edge]
			if node.route_family != "common" and next.route_family != "common":
				assert_eq(node.route_family, next.route_family, "No secret changes the commitment")
	assert_eq(
		titles,
		[
			"Les traces du Léthé",
			"Les lances oubliées",
			"La stèle des noms",
			"Les roseaux du tireur",
			"Les duellistes du gué",
		],
	)
	assert_ne(route.reveal_next_hidden_node(), "")
	assert_eq(route.revealed_node_ids.size(), 3, "One discovered place, all three family entrances")


func test_revision_five_roundtrip_and_new_difficulty_are_isolated() -> void:
	for revision in [2, 3, 4, 5, 6]:
		var route := ExpeditionRouteState.new()
		route.initialize(2401, revision, "easy")
		var snapshot: Dictionary = JSON.parse_string(JSON.stringify(route.to_snapshot()))
		var restored := ExpeditionRouteState.new()
		assert_true(restored.restore_snapshot(snapshot), str(revision))
		assert_eq(JSON.parse_string(JSON.stringify(restored.to_snapshot())), snapshot)
		assert_eq(restored.difficulty_id, "easy" if revision == 6 else "normal")
		if revision < 6:
			assert_false(snapshot.has("difficulty_id"))
		if revision == 6:
			var invalid := snapshot.duplicate(true)
			invalid.difficulty_id = "nightmare"
			assert_false(restored.restore_snapshot(invalid))
			assert_eq(JSON.parse_string(JSON.stringify(restored.to_snapshot())), snapshot)


func test_difficulty_preparation_is_atomic_and_survives_full_save() -> void:
	var manager := _manager()
	var before: Dictionary = manager.get_expedition_snapshot()
	var invalid := CatabasePreparationCatalog.preset("marteau")
	invalid.difficulty_id = "invalid"
	assert_false(manager.confirm_catabase_preparation(invalid).get("success", false))
	assert_eq(manager.get_expedition_snapshot(), before)
	var selection := CatabasePreparationCatalog.preset("marteau")
	selection.difficulty_id = "easy"
	assert_true(manager.confirm_catabase_preparation(selection).get("success", false))
	assert_eq(manager.expedition.route.difficulty_id, "easy")
	assert_false(manager.expedition.build.starting_selection.has("difficulty_id"))
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(manager.get_expedition_snapshot()))
	assert_true(manager.restore_expedition_snapshot(snapshot))
	assert_eq(manager.expedition.route.difficulty_id, "easy")
	assert_eq(int(manager.expedition.character.unit.get_meta("ct_balance_revision", -1)), 1)


func test_reward_weapon_refuges_and_final_preparation_are_one_time_transactions() -> void:
	for mode in ["normal", "easy"]:
		var manager := _manager(mode)
		assert_true(manager.confirm_catabase_preparation(CatabasePreparationCatalog.preset(
				"marteau"
			)).get("success", false))
		var session := manager.expedition
		for depth in range(1, 21):
			if depth > 1:
				var candidates := session.route.get_available_nodes()
				assert_false(candidates.is_empty())
				var preferred := candidates.filter(
					func(node: Dictionary):
						return str(node.route_family) == ("styx" if depth >= 17 else "airain"),
				)
				assert_true(
					manager.choose_expedition_node(
						str((preferred[0] if not preferred.is_empty() else candidates[0]).id)
					)
				)
			if session.route.phase == "combat":
				assert_true(session.combat_won())
			if depth == 20:
				assert_eq(
					preload("res://core/expedition/expedition_flow.gd").required_step(session),
					"rewards",
					"No post-boss allocation blocks victory",
				)
			_resolve_advancement(manager)
			if depth == 12:
				assert_true(manager.choose_expedition_capacity("slot").get("success", false))
			var options := session.reward_options(manager.item_catalog, manager.run_inventory)
			if depth == 2:
				var gear: Dictionary = options.filter(
					func(option: Dictionary):
						return str(option.id).begins_with("item:"),
				)[0]
				assert_ne(str(gear.item_id), "catabase_ct_marteau")
				assert_true(
					str(gear.item_id).trim_prefix("catabase_ct_")
					in CatabasePreparationCatalog.WEAPONS
				)
				assert_eq(
					session.reward_options(manager.item_catalog, manager.run_inventory),
					options,
				)
			if depth in [7, 11, 16]:
				var hero := session.character.unit
				hero.current_hp = 1
				var before_gold := session.gold
				assert_true(
					session
					.use_hub_service("rest", manager.run_inventory, manager.item_catalog)
					.success
				)
				assert_eq(
					hero.current_hp,
					1 + roundi(hero.max_hp.get_int() * (0.40 if mode == "easy" else 0.30)),
				)
				assert_eq(session.gold, before_gold)
				assert_false(
					session
					.use_hub_service("rest", manager.run_inventory, manager.item_catalog)
					.success
				)
				var saved: Dictionary = JSON.parse_string(
					JSON.stringify(manager.get_expedition_snapshot())
				)
				assert_true(manager.restore_expedition_snapshot(saved), "Refuge receipt resumes")
				session = manager.expedition
				assert_false(
					session
					.use_hub_service("rest", manager.run_inventory, manager.item_catalog)
					.success
				)
			if depth == 19:
				assert_eq(session.build.points, 24)
				assert_eq(session.character.champion_progression.current_xp, 2440)
				assert_eq(session.character.champion_progression.current_level, 12)
				assert_true(session.hub_services(manager.item_catalog).is_empty())
				assert_false(
					session
					.use_hub_service("rest", manager.run_inventory, manager.item_catalog)
					.success
				)
				assert_eq(options.size(), 1)
			if (
				session.route.get_current_node().kind == "lore"
				and not session.route.has_future_hidden_node()
			):
				var services := session.hub_services(manager.item_catalog)
				assert_eq(services.size(), 2)
				var gold_before := session.gold
				var selected_index := 1 if depth == 18 else 0
				var other_index := 1 - selected_index
				if depth == 18:
					assert_false(
						session
						.use_hub_service(str(services[0].id), manager.run_inventory, manager.item_catalog)
						.success,
						"Already carried supply cannot duplicate or consume the choice",
					)
				assert_true(
					session
					.use_hub_service(str(services[selected_index].id), manager.run_inventory, manager.item_catalog)
					.success
				)
				assert_false(
					session
					.use_hub_service(str(services[other_index].id), manager.run_inventory, manager.item_catalog)
					.success,
					"One supply choice per memory",
				)
				assert_eq(session.gold, gold_before, "No obsolete currency on top")
				assert_eq(
					session.route.reveal_next_hidden_node(),
					"",
					"Cannot reveal a secret at an already engaged depth",
				)
				var memory_snapshot: Dictionary = JSON.parse_string(
					JSON.stringify(manager.get_expedition_snapshot())
				)
				assert_true(manager.restore_expedition_snapshot(memory_snapshot))
				session = manager.expedition
				assert_false(
					session
					.use_hub_service(str(services[other_index].id), manager.run_inventory, manager.item_catalog)
					.success,
					"Choice receipt survives resume",
				)
			var choice := (
				"finish"
				if depth == 20
				else (
					"leave_hub"
					if session.route.get_current_node().kind not in ["normal", "elite", "boss"]
					else "supplies"
				)
			)
			assert_true(manager.claim_expedition_reward(choice).get("success", false), str(depth))
		assert_eq(session.route.phase, "complete")
		assert_eq(session.character.champion_progression.current_xp, 2785)


func test_departure_mode_control_is_local_until_confirmation_and_warns_inactive_combo() -> void:
	var manager := _manager()
	var view := preload("res://ui/expedition/catabase_departure_view.gd").new()
	add_child_autofree(view)
	var payloads: Array = []
	view.configure(
		manager.expedition,
		func(payload: Dictionary):
			payloads.append(payload)
			return { "success": true },
	)
	view.selection.relic = "fil"
	view.step = 6
	view.call("_render")
	assert_string_contains(view.status.text, "Fil du retour")
	var selector := view.find_child("CatabaseDifficulty", true, false) as OptionButton
	assert_not_null(selector)
	selector.select(1)
	selector.item_selected.emit(1)
	assert_eq(
		manager.expedition.route.difficulty_id,
		"normal",
		"No mutation while comparing choices",
	)
	view.call("_confirm")
	assert_eq(payloads.size(), 1)
	assert_eq(payloads[0].difficulty_id, "easy")


func test_known_r6_preview_matches_exact_room_and_distant_details_remain_hidden() -> void:
	var route := ExpeditionRouteState.new()
	route.initialize(2401, 6, "easy")
	assert_true(route.choose_node("d01_0"))
	assert_true(route.mark_combat_won())
	assert_true(route.complete_current_node())
	for node in route.get_available_nodes():
		var before := node.duplicate(true)
		var preview := ExpeditionEncounterPreview.describe(node, route.seed)
		var room := ExpeditionRunFactory.make_room(node, route.seed)
		assert_false(preview.is_empty())
		assert_eq(int(preview.get("count", 0)), room.enemies.size())
		for enemy in room.enemies:
			assert_string_contains(str(preview.details), "%d PV" % enemy.max_hp)
		assert_eq(node, before)
	for node in route.get_visible_nodes():
		if int(node.depth) == 17:
			assert_true(ExpeditionEncounterPreview.describe(node, route.seed).is_empty())
			assert_false(node.has("room_resource"))


func test_revealed_r6_secret_entrances_fit_the_small_parchment_without_overlap() -> void:
	var route := ExpeditionRouteState.new()
	route.initialize(2401)
	assert_ne(route.reveal_next_hidden_node(), "")
	assert_ne(route.reveal_next_hidden_node(), "")
	var canvas := ExpeditionMapCanvas.new()
	add_child_autofree(canvas)
	canvas.size.x = 580
	canvas.set_route(route)
	for frame in 3:
		await get_tree().process_frame
	assert_eq(canvas._rects.size(), 54)
	for id in canvas._rects:
		var rect: Rect2 = canvas._rects[id]
		assert_gte(rect.position.x, 0.0)
		assert_lte(rect.end.x, canvas.size.x)
		for other in canvas._rects:
			if str(other) > str(id):
				assert_false(rect.intersects(canvas._rects[other]), "%s / %s" % [id, other])
	assert_eq(canvas.call("_kind_label", { "preparation_only": true }), "PRÉPARATION")


func _resolve_advancement(manager: Manager) -> void:
	var session := manager.expedition
	while not session.advancement_step.is_empty():
		if session.advancement_step == "progression":
			while session.character.champion_progression.unspent_attribute_points > 0:
				assert_true(manager.spend_champion_attribute(&"achilles", &"vitality"))
		assert_true(manager.advance_expedition_level_step().get("success", false))
