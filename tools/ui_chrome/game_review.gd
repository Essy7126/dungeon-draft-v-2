extends "res://tools/ui_chrome/menus_review.gd"
## Real UI/service boundaries. Encounter victories are explicit disposable fixtures.


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("output_dir="):
			_output = argument.trim_prefix("output_dir=")
	if _output.is_empty():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_output)
	GameManager.expedition_save_path = _output.path_join("fixture_save.json")
	GameManager.set_reduced_motion_enabled(true)
	var run := ExpeditionRunFactory.create(2401)
	var resolved := RunHeroResolver.resolve_runtime_hero_data(run, false)
	_check(resolved.is_valid(), "Canonical run resolves")
	_check(GameManager._prepare_preconfigured_run(run, resolved.heroes), "Canonical state prepares")
	GameManager.expedition = ExpeditionSession.new()
	GameManager.expedition.initialize(GameManager.get_character_state(&"achilles"), 2401)
	_check(GameManager.expedition.enter("d01_0"), "First encounter enters")
	_check(
		GameManager.expedition.combat_won(),
		"Simulated first victory creates the real post-combat choices",
	)
	var screen: Control = load("res://ui/expedition/ExpeditionScreen.tscn").instantiate()
	add_child(screen)
	await _settle()
	_check(screen.get("_page") == "progression", "Attribute page opens first")
	await _capture("run_progression", [screen.get("_hero_banner"), screen.get("_body")])
	var points := GameManager.expedition.character.champion_progression.unspent_attribute_points
	for point in range(points):
		await _click(screen.find_child("Attribute_vitality", true, false))
	await _click(screen.find_child("ContinueExpeditionFlow", true, false))
	_check(screen.get("_page") == "rewards", "Continue reaches reward choice")
	await _click(screen.find_child("RewardOption_0", true, false))
	await _capture(
		"run_rewards",
		[screen.get("_hero_banner"), screen.find_child("ConfirmExpeditionReward", true, false)],
	)
	await _click(screen.find_child("ConfirmExpeditionReward", true, false))
	_check(screen.get("_page") == "preparation", "Confirmed reward reaches preparation")
	await _capture("run_preparation", [screen.get("_hero_banner"), screen.get("_body")])
	await _click(screen.find_child("CatabaseTab_build", true, false))
	_check(screen.get("_page") == "build", "Skills navigation opens the real build")
	await _capture("run_skills", [screen.get("_hero_banner"), screen.get("_body")])
	await _click(screen.find_child("CloseExpeditionScreen", true, false))
	await _click(screen.find_child("OpenRouteMap", true, false))
	_check(screen.get("_page") == "map", "Preparation opens the route")
	await _capture(
		"run_map",
		[screen.get("_hero_banner"), screen.find_child("CommitDestination", true, false)],
	)
	screen.hide()
	var pause: DarkPauseMenu = load("res://ui/menus/dark_pause_menu.tscn").instantiate()
	add_child(pause)
	pause.set_reduced_motion(true)
	pause.open_menu()
	await _settle()
	await _capture("pause", [pause.get_node("%MenuPanel"), pause.get_action_button(&"resume")])
	var resumed := [false]
	pause.resume_requested.connect(
		func():
			resumed[0] = true,
	)
	await _click(pause.get_action_button(&"resume"))
	_check(resumed[0], "Resume receives an actual click")
	pause.close_menu()
	pause.queue_free()
	await _settle()
	screen.show()
	var unit := GameManager.get_character_state(&"achilles").unit
	var tooltip := KeywordTooltipLayer.new()
	add_child(tooltip)
	tooltip.show_spell(unit, unit.spells[0], "", Vector2(400, 200))
	await _settle()
	await _capture("spell_tooltip", [tooltip.get("_panel")])
	tooltip.queue_free()
	await _settle()
	var inspection = load("res://ui/inspect_panel.gd").new()
	add_child(inspection)
	inspection.show_unit(unit, true)
	await _settle()
	await _capture("unit_inspection", [inspection.get("_panel")])
	var inspect_content: Control = inspection.get("_content")
	_check(
		inspect_content.size.x <= inspect_content.get_parent().size.x,
		"Inspection text fits without horizontal scrolling",
	)
	inspection.queue_free()
	screen.queue_free()
	await _settle()
	var result: Control = load("res://ui/RunResultScreen.tscn").instantiate()
	add_child(result)
	for victory in [true, false]:
		result.call(
			"_apply_result",
			{
				"victory": victory,
				"is_catabase": victory,
				"run_name": "Catabase" if victory else "L’Odyssée du trio",
				"rooms_cleared": 20 if victory else 2,
				"room_total": 20 if victory else 6,
				"reached_room_number": 20 if victory else 3,
				"epitaph": "Fixture de revue visuelle — aucune fin de campagne n’a été jouée.",
			},
		)
		await _settle()
		await _capture(
			"victory" if victory else "defeat",
			[result.get_node("%Panel"), result.get("return_button")],
		)
	result.queue_free()
	await _settle()
	await _reach_halt(4)
	var bridge := SanctuarySession.new()
	bridge.bind_runtime(GameManager)
	var panels := SanctuaryPanels.new()
	panels.setup(bridge)
	add_child(panels)
	panels.open_shop()
	await _settle()
	_check(panels.is_open(), "Sanctuary shop opens")
	await _capture("sanctuary_shop", [panels.find_child("SanctuaryPanel", true, false)])
	await _click(panels.find_child("ClosePanel", true, false))
	_check(not panels.is_open(), "Shop close releases its modal")
	panels.open_oracle()
	await _settle()
	await _capture("sanctuary_oracle", [panels.find_child("SanctuaryPanel", true, false)])
	panels.close_panel()
	panels.queue_free()
	await _settle()
	GameManager.cleanup_run_state()
	await _settle()
	for manifest in ["emerald_sanctuary_v1", "bronze_forge_v1"]:
		var halt: Node = load("res://hub/painted_halt/LivingHalt.tscn").instantiate()
		halt.set("manifest_path", "res://data/halts/%s.json" % manifest)
		halt.set("audio_enabled", false)
		add_child(halt)
		await _settle()
		_check(str(halt.get("_error")).is_empty(), "Halt loads: " + manifest)
		await _capture(manifest, [halt.get("_interface")])
		halt.queue_free()
		await _settle()
	await _finish()


func _reach_halt(depth: int) -> void:
	var session := GameManager.expedition
	while int(session.route.get_current_node().depth) < depth:
		if session.route.phase != "map":
			while session.character.champion_progression.unspent_attribute_points > 0:
				_check(
					session.character.spend_champion_attribute(&"vitality"),
					"Fixture spends earned attribute",
				)
			var offers := session.reward_options(GameManager.item_catalog)
			_check(not offers.is_empty(), "Fixture has reward offers")
			if offers.is_empty():
				return
			_check(
				bool(
					session.claim(str(offers.back().id), GameManager.run_inventory, GameManager.item_catalog).success
				),
				"Fixture claims reward",
			)
		var available := session.route.get_available_nodes()
		_check(not available.is_empty(), "Fixture has a route destination")
		if available.is_empty():
			return
		_check(session.enter(str(available[0].id)), "Fixture enters next depth")
		if session.route.phase == "combat":
			_check(session.combat_won(), "Fixture simulates encounter outcome")
