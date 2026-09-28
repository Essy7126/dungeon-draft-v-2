extends "res://tools/consumable_cards/audit_live_integration.gd"
## Actual enemy turns; route victories between samples are explicit fixtures.
var native_casts: Array = []


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(
			ProjectSettings.globalize_path("res://artifacts/dev/").replace("\\", "/")
		):
		get_tree().quit(2)
		return
	EventBus.spell_cast.connect(_record_spell)
	driver = Manager.new()
	add_child(driver)
	driver.expedition_save_path = "user://bestiary_driver.json"
	if not check(driver.start_expedition(33, { }, false, true, "normal", true), "start"):
		return finish()
	GameManager.expedition_save_path = "user://bestiary_live.json"
	for depth in range(1, 21):
		var session: ExpeditionSession = driver.expedition
		if depth in [2, 6, 8, 17]:
			if not await mount(driver.get_expedition_snapshot()):
				return finish()
			var row := {
				"depth": depth,
				"scene": GameManager.get_current_room().battle_scene.resource_path,
				"roster": [],
			}
			for unit in battle.units:
				if unit.team == 1:
					row.roster.append(
						{
							"id": str(unit.content_unit_id),
							"hp": unit.max_hp.get_int(),
							"ap": unit.max_ap.get_int(),
							"mp": unit.max_mp.get_int(),
							"spells": unit.spells.map(
								func(spell):
									return str(spell.spell_id),
							),
						}
					)
			result.encounters.append(row)
			await _image("%02d_deployment" % depth)
			for round_index in [2, 3]:
				battle._commit_player_end_turn()
				var resumed := false
				for _tick in 6000:
					await get_tree().create_timer(.02).timeout
					if battle._battle_over:
						break
					if (
						GameManager.expedition.cards.round_index == round_index
						and battle._can_accept_player_intent()
					):
						resumed = true
						break
				if not check(resumed, "native round %d depth %d" % [round_index, depth]):
					return finish()
			await _image("%02d_after_two_enemy_turns" % depth)
			check(battle._cards_runtime.checkpoint(), "checkpoint depth %d" % depth)
			clear_battle()
			GameManager.cleanup_run_state()
		if session.route.phase == "combat":
			check(session.combat_won(), "route fixture victory")
			check(session.acknowledge_combat_receipt().success, "receipt")
		if session.cards.level >= 4 and session.cards.specialization.is_empty():
			session.cards.specialize("execution")
		while not session.advancement_step.is_empty():
			session.advance_level_step()
		if depth == 20:
			break
		var options: Array = session.reward_options(driver.item_catalog)
		check(session.claim(str(options[0].id), driver.run_inventory, driver.item_catalog).success, "claim")
		check(
			driver.choose_expedition_node(str(session.route.get_available_nodes()[0].id)),
			"choose",
		)
	result["native_casts"] = native_casts
	result["fixtures"] = "Intervening victories are declared to reach the samples. In sampled fights the unmodified hero passes twice; real AI, movement, effects, animations and checkpoints execute. No win-rate claim."
	result.completed = result.failures.is_empty() and result.encounters.size() == 4
	finish()


func _record_spell(actor: Unit, spell: Spell, report: Dictionary) -> void:
	if actor.team == 1 and not report.get("failed", false):
		native_casts.append(
			{
				"actor": str(actor.content_unit_id),
				"spell": str(spell.spell_id),
				"round": GameManager.expedition.cards.round_index,
			}
		)


func _image(label: String) -> void:
	var banner: Control = battle.action_bar.get_turn_intro_banner()
	for _tick in 200:
		if not is_instance_valid(banner) or not banner.is_visible_in_tree():
			break
		await get_tree().create_timer(.02).timeout
	check(not is_instance_valid(banner) or not banner.is_visible_in_tree(), "turn banner completed")
	await get_tree().create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.get_base_dir().path_join(
				label + ".png"
			)) == OK, label)


func finish() -> void:
	clear_battle()
	GameManager.cleanup_run_state()
	if is_instance_valid(driver):
		driver.cleanup_run_state()
		driver.free()
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t"))
	print("BESTIARY_CAPTURE " + JSON.stringify(result))
	get_tree().quit(0 if result.completed else 1)
