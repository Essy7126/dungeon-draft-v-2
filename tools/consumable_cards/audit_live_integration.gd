extends Node
## Audit probes on authored scenes. Fixtures are explicit; this is not a balance campaign.
const Catalog = preload("res://core/expedition/consumable_card_catalog.gd")
const Runtime = preload("res://battle/consumable_cards_runtime.gd")
const Spells = preload("res://core/expedition/consumable_card_spells.gd")
const Vfx = preload("res://vfx/class_cards/class_card_vfx_router.gd")
var battle: Node
var driver: Node
var result := {"completed": false, "failures": [], "findings": [], "encounters": [], "probes": {}}
var output := ""
var capture := false


class Manager:
	extends "res://core/game_manager.gd"
	func _request_scene_change(_path: String, _mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT) -> void:
		pass
	func start_next_battle() -> void:
		pass
	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> bool:
	if not ok:
		result.failures.append(label)
		push_error("Audit harness: " + label)
	return ok


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--capture": capture = true
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(ProjectSettings.globalize_path("res://artifacts/dev/").replace("\\", "/")):
		push_error("Requires isolated artifacts/dev APPDATA and --output")
		get_tree().quit(2)
		return
	var supported := []
	var missing := []
	var families: Array = Catalog.pool()
	families.append_array(["fallback_strike", "fallback_guard"])
	for family in families:
		if Vfx.handles(Spells.make_spell(str(family))): supported.append(family)
		else: missing.append(family)
	result.probes.vfx = {"supported": supported, "missing": missing}
	driver = Manager.new()
	add_child(driver)
	driver.select_run_variant("cards")
	driver.expedition_save_path = "user://audit_driver.json"
	if not check(driver.start_expedition(33, {}, false, true, "normal", true), "driver starts"): return finish()
	GameManager.expedition_save_path = "user://audit_live.json"
	for depth in range(1, 21):
		var session: ExpeditionSession = driver.expedition
		if session.route.phase == "combat":
			if not await mount(driver.get_expedition_snapshot()): return finish()
			var definition := Runtime.Integration.encounter(GameManager.expedition)
			var reference := []
			for model in Runtime.Enemies.build(definition):
				reference.append({"kind": model.get_meta("cc2_kind"), "hp": model.max_hp.get_int(), "attack": model.attack_power.get_value()})
			var roster := []
			for unit in battle.units:
				if unit.team != 0: roster.append({"id": str(unit.unit_id), "name": unit.unit_name, "role": str(unit.tactical_role_id), "kind": unit.get_meta("cc2_kind", ""), "variant": unit.get_meta("cc2_variant", ""), "hp": unit.max_hp.get_int(), "attack": unit.attack_power.get_value()})
			var room = battle._cards_runtime.room_rules
			result.encounters.append({"depth": depth, "index": definition.index, "planned_map": definition.map, "planned_roster": definition.roster, "reference_stats": reference, "variant": definition.encounterVariant, "actual_scene": GameManager.get_current_room().battle_scene.resource_path, "actual_room": "" if room == null else room.room_id, "roster": roster})
			if capture and room != null and not room.room_id.is_empty(): await capture_room(room, int(definition.index))
			if depth == 1: probe_pressure()
			if depth == 20: probe_boss()
			clear_battle()
			GameManager.cleanup_run_state()
			check(session.combat_won(), "advance combat %d" % depth)
			check(session.acknowledge_combat_receipt().success, "receipt %d" % depth)
		if session.cards.level >= 4 and session.cards.specialization.is_empty(): check(session.cards.specialize("execution"), "specialization")
		while not session.advancement_step.is_empty(): check(session.advance_level_step().success, "advancement")
		if depth == 20: break
		var options: Array = session.reward_options(driver.item_catalog)
		if not check(not options.is_empty(), "route options %d" % depth): return finish()
		check(session.claim(str(options[0].id), driver.run_inventory, driver.item_catalog).success, "claim %d" % depth)
		var next: Array = session.route.get_available_nodes()
		if not check(not next.is_empty(), "next node %d" % depth): return finish()
		check(driver.choose_expedition_node(str(next[0].id)), "choose %d" % depth)
	result.completed = result.failures.is_empty() and result.encounters.size() == 12
	finish()


func mount(snapshot: Dictionary) -> bool:
	clear_battle()
	GameManager.cleanup_run_state()
	if not check(GameManager.restore_expedition_snapshot(snapshot), "restore session"): return false
	battle = GameManager.get_current_room().battle_scene.instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if GameManager.expedition.combat_checkpoint.is_empty(): battle._deployment.on_cell_clicked(battle._deployment._deploy_zone[0])
	for _tick in 500:
		await get_tree().create_timer(.02).timeout
		if battle._can_accept_player_intent(): return true
	return check(false, "Battle did not accept input")


func probe_pressure() -> void:
	var hero: Unit = GameManager.expedition.character.unit
	Runtime.Effects.guard(hero, 1.0, GameManager.expedition.cards)
	var before := {"hp": hero.current_hp, "shield": hero.current_shield}
	var expected_loss := Runtime.Math.pressure(hero.max_hp.get_int(), 9)
	# Start of round 10 applies the pressure owed at the end of round 9.
	battle._cards_runtime.round_started(10)
	result.probes.pressure = {"before": before, "expected_hp_loss": expected_loss, "after": {"hp": hero.current_hp, "shield": hero.current_shield}}


func capture_room(room, index: int) -> void:
	var hero: Unit = GameManager.expedition.character.unit
	var banner: Control = battle.action_bar.get_turn_intro_banner()
	for _tick in 200:
		if not is_instance_valid(banner) or not banner.is_visible_in_tree(): break
		await get_tree().create_timer(.02).timeout
	check(not is_instance_valid(banner) or not banner.is_visible_in_tree(), "turn banner completed")
	var target: Vector2i = room.layout.reservoirs[0] if room.room_id == "reservoir" else room.layout.lever
	for cell in [target, target + Vector2i.LEFT, target + Vector2i.RIGHT, target + Vector2i.UP, target + Vector2i.DOWN]:
		if battle.grid.is_walkable(cell, hero) and battle.grid.relocate_unit(hero, cell): break
	var view: Node2D = battle._unit_views.get(hero)
	if is_instance_valid(view): view.position = battle.grid_cell_to_parent_local(hero.grid_pos, view.get_parent())
	if room.room_id == "reservoir":
		room.end_hero()
		hero.current_ap = 4
		battle._hud_port.update_info(hero)
	await get_tree().create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	check_room_hud()
	var filename := "%02d_%s.png" % [index, room.room_id]
	check(get_viewport().get_texture().get_image().save_png(output.get_base_dir().path_join(filename)) == OK, "capture " + filename)
	if index == 4:
		# Presentation fixture for the late-combat forecast, not simulated turns.
		var saved_round: int = GameManager.expedition.cards.round_index
		var saved_activation := hero.activation_index
		GameManager.expedition.cards.round_index = 9
		hero.activation_index = 9
		await get_tree().create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		check_room_hud()
		check(get_viewport().get_texture().get_image().save_png(output.get_base_dir().path_join("04_forge_pressure.png")) == OK, "pressure capture")
		GameManager.expedition.cards.round_index = saved_round
		hero.activation_index = saved_activation


func check_room_hud() -> void:
	var viewport := get_viewport().get_visible_rect().grow(1)
	for name in ["CardRoomIntention", "CardRoomCommands", "CardPressureForecast", "FixedWeaponActions", "CatabaseCardHand"]:
		var control: Control = battle.action_bar.find_child(name, true, false)
		if control != null and control.is_visible_in_tree():
			check(viewport.encloses(control.get_global_rect()), name + " fits viewport")
	for label in battle.action_bar.find_children("*", "Label", true, false):
		var button := label.find_parent("FixedWeapon_*") as Button
		if button != null and label.is_visible_in_tree():
			check(button.get_global_rect().grow(1).encloses(label.get_global_rect()), "weapon text fits button")


func probe_boss() -> void:
	var boss: Unit = null
	for unit in battle.units:
		if unit.get_meta("cc2_boss", false): boss = unit
	if not check(boss != null, "boss found"): return
	boss.current_hp = floori(boss.max_hp.get_int() * .51)
	boss.clear_shield()
	boss.activation_index = 1
	Runtime.Effects.apply_state(boss, "burn", ceilf(boss.max_hp.get_int() * .04), 1, GameManager.expedition.character.unit)
	var skipped: bool = battle._cards_runtime.begin_activation(boss)
	var prepared := Runtime.Enemies.prepare_activation(boss, GameManager.expedition.character.unit, battle.units, battle.grid, battle.terrain_effects, 100.0, false, false)
	result.probes.boss_periodic = {"hp": boss.current_hp, "maximum": boss.max_hp.get_int(), "phase": boss.get_meta("cc2_phase"), "skipped": skipped, "next_behavior": prepared.kind}


func clear_battle() -> void:
	if is_instance_valid(battle):
		remove_child(battle)
		battle.free()
	battle = null


func finish() -> void:
	if result.completed:
		var expected_rooms := []
		for encounter in result.encounters:
			if encounter.planned_map in ["forge", "garden", "convoy", "hourglass", "reservoir"] and encounter.actual_room == "": expected_rooms.append(encounter.index)
			var expected: String = {"support_line_of_sight": "support", "break_guard_formation": "formation", "finite_parry": "parry", "telegraphed_execution": "execution"}.get(encounter.variant, "")
			if expected != "" and not encounter.roster.any(func(unit): return unit.variant == expected):
				result.findings.append({"id": "missing_encounter_variant", "combat": encounter.index, "expected": expected})
		if not expected_rooms.is_empty(): result.findings.append({"id": "missing_room_mechanics", "combats": expected_rooms})
		if not result.probes.vfx.missing.is_empty(): result.findings.append({"id": "vfx_unrecognized", "count": result.probes.vfx.missing.size()})
		if result.probes.has("boss_periodic") and result.probes.boss_periodic.hp * 2 <= result.probes.boss_periodic.maximum and result.probes.boss_periodic.phase != 2:
			result.findings.append({"id": "boss_phase_after_periodic_damage"})
		if result.probes.has("pressure") and result.probes.pressure.before.hp - result.probes.pressure.after.hp != result.probes.pressure.expected_hp_loss:
			result.findings.append({"id": "pressure_absorbed_by_guard"})
		result["integration_complete"] = result.findings.is_empty()
	clear_battle()
	GameManager.cleanup_run_state()
	if is_instance_valid(driver):
		driver.cleanup_run_state()
		driver.free()
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result, "\t"))
	print("CARDS_LIVE_AUDIT " + JSON.stringify(result))
	get_tree().quit(0 if result.completed else 1)
