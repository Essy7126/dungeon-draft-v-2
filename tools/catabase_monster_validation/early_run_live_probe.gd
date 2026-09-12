extends "res://tools/catabase_monster_validation/early_run_playtest.gd"
## Real scene/intent traversal I–VII. No injected wins, HP or action resources.
var route_name := "barque"
var live_kit := "airain"
var live_output := ""
var records: Array[Dictionary] = []
var seen_rewards: Array[String] = []
var live_turns := 0
var active_key := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("route="):
			route_name = arg.trim_prefix("route=")
		if arg.begins_with("kit="):
			live_kit = arg.trim_prefix("kit=")
	live_output = "res://artifacts/dev/early_run_playtest/live_" + route_name + "_" + live_kit
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(live_output))
	GameManager.expedition_save_path = live_output.path_join("checkpoint.json")
	GameManager.set_reduced_motion_enabled(true)
	Engine.time_scale = 6.0
	get_tree().current_scene = null
	_live.call_deferred()


func _live() -> void:
	var replacement := GameManager.get_expedition_replacement_guard()
	if bool(replacement.get("exists", false)):
		GameManager.confirm_expedition_replacement(str(replacement.token))
	if not GameManager.start_expedition(2401):
		await _finish_live(false, "start_failed")
		return
	var deadline := Time.get_ticks_msec() + 420000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if not GameManager.run_active:
			await _finish_live(false, "defeat")
			return
		var session: ExpeditionSession = GameManager.expedition
		var node := session.route.get_current_node()
		if session.route.phase == "reward":
			if not seen_rewards.has(str(node.id)):
				seen_rewards.append(str(node.id))
				var report = GameManager.get_current_combat_report()
				records.append(
					{
						"node": node.id,
						"title": node.title,
						"depth": node.depth,
						"hp": session.character.unit.current_hp,
						"max_hp": session.character.unit.max_hp.get_int(),
						"turns_total": live_turns,
						"victory": report != null and report.victory,
						"loadout": session.character.loadout.get_spell_slot_ids(),
						"masteries": session.build.unlocked_node_ids.duplicate(),
					}
				)
				print("LIVE_ROOM ", JSON.stringify(records.back()))
			if int(node.depth) == 7:
				await _finish_live(true, "first_junction_reached")
				return
			_prepare_build(session)
			if ExpeditionRouteCatalog.is_halt(str(node.kind)):
				for service: Dictionary in session.hub_services(GameManager.item_catalog):
					if str(service.id) in ["rest", "lore"] and bool(service.available):
						GameManager.use_catabase_hub_service(str(service.id))
			var options := session.reward_options(GameManager.item_catalog)
			var choice := str(options.back().id)
			for option: Dictionary in options:
				if str(option.id) == "supplies":
					choice = "supplies"
			GameManager.claim_expedition_reward(choice)
			continue
		if session.route.phase == "map":
			var next := session.route.get_available_nodes()
			if next.is_empty():
				await _finish_live(false, "no_destination")
				return
			var chosen: Dictionary = next[0]
			if int(node.depth) == 1:
				var wanted: String = {
					"puits": "La sente des oliviers",
					"porte": "Le portique des oboles",
					"barque": "Les traces du Léthé",
				}[route_name]
				for candidate in next:
					if str(candidate.title) == wanted:
						chosen = candidate
			GameManager.choose_expedition_node(str(chosen.id))
			continue
		var battle := get_tree().current_scene
		if battle == null or not bool(battle.get("runtime_ready_state")):
			continue
		var deployment = battle.get("_deployment")
		if deployment != null and deployment.is_active():
			deployment.on_cell_clicked(GameManager.get_current_room().hero_spawn_zone[0])
			continue
		if not bool(battle.call("_can_accept_player_intent")):
			continue
		var hero: Unit = battle.call("get_active_unit")
		if hero == null or hero.team != 0:
			continue
		var key := str(node.id) + ":" + str(hero.activation_index)
		if key != active_key:
			active_key = key
			live_turns += 1
		var action := _hero_action(
			hero,
			battle.get("units"),
			battle.get("grid"),
			battle.get("pathfinder"),
			battle.get("spell_caster"),
		)
		if action.is_empty():
			battle.set("_skip_end_turn_confirmation", true)
			battle.call("_on_end_turn_pressed")
		elif str(action.type) == "cast":
			battle.call("_on_spell_pressed", action.spell)
			battle.call("_on_cell_clicked", action.cell)
		else:
			battle.call("_on_move_pressed")
			battle.call("_on_cell_clicked", action.path.back())
	await _finish_live(false, "timeout")


func _prepare_build(session: ExpeditionSession) -> void:
	while session.character.champion_progression.unspent_attribute_points > 0:
		GameManager.spend_champion_attribute(&"achilles", &"vitality")
	var root_id: String = {
		"briseur": "colere.root",
		"chasseur": "chiron.root",
		"airain": "eaque.root",
	}[live_kit]
	for id in [
		root_id,
		live_kit + ".learn_a",
		live_kit + ".liaison_a",
		live_kit + ".mutation",
		live_kit + ".learn_b",
		live_kit + ".signature",
		live_kit + ".liaison_b",
	]:
		if not id in session.build.unlocked_node_ids:
			GameManager.purchase_expedition_technique(id)
	if int(session.build.completed_depth) == 1:
		var technique: StringName = {
			"briseur": &"exp_crochet",
			"chasseur": &"exp_rupture",
			"airain": &"exp_heurt",
		}[live_kit]
		GameManager.equip_expedition_spell(technique, 1 if live_kit != "chasseur" else 0)
	if session.character.loadout.get_active_slot_count() >= 5:
		var spell: StringName = {
			"briseur": &"exp_fauchage",
			"chasseur": &"exp_marque",
			"airain": &"exp_posture",
		}[live_kit]
		GameManager.equip_expedition_spell(spell, 4)


func _finish_live(success: bool, reason: String) -> void:
	var file := FileAccess.open(live_output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"success": success,
				"reason": reason,
				"route": route_name,
				"kit": live_kit,
				"rooms": records,
				"turns": live_turns,
				"scope": "Real production scenes, deployment, player intents, AI, persistent HP and rewards; automated player, vitality attributes, mastery priorities, provisions, no equipment. Stops on defeat or after VII.",
			},
			"\t",
		)
	)
	print("EARLY_LIVE ", success, " ", reason, " ", live_output)
	var scene := get_tree().current_scene
	get_tree().current_scene = null
	if scene != null:
		scene.queue_free()
	for frame in 8:
		await get_tree().process_frame
	GameManager.cleanup_run_state()
	for frame in 8:
		await get_tree().process_frame
	get_tree().quit(0 if success else 1)
