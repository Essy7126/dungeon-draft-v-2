extends Node
## Isolated real battle scene with the production card hand. Does not load personal saves.
const Rooms = preload("res://core/expedition/card_tactical_room_catalog.gd")
const Cards = preload("res://core/expedition/class_cards.gd")
const Catalog = preload("res://core/expedition/class_card_catalog.gd")


func _ready() -> void:
	var room_id := "forge"
	var output := ""
	var exercise := false
	var open_convoy := false
	var verify_victory := false
	var delay_hourglass := false
	for argument in OS.get_cmdline_user_args():
		if argument == "--delay-hourglass":
			delay_hourglass = true
			exercise = true
		if argument == "--verify-victory":
			verify_victory = true
			exercise = true
		if argument == "--open-convoy":
			open_convoy = true
			exercise = true
		if argument == "--exercise":
			exercise = true
		if argument.begins_with("--room="):
			room_id = argument.trim_prefix("--room=")
		if argument.begins_with("--capture="):
			output = argument.trim_prefix("--capture=")
	assert(room_id in Rooms.IDS)
	GameManager.expedition_save_path = "res://artifacts/dev/tactical-room-preview-%d.json" % [
		Time.get_ticks_usec()
	]
	var node := { }
	for candidate in ExpeditionRouteCatalog.create_nodes(42):
		if Rooms.id_for(candidate) == room_id:
			node = candidate
	var run := ExpeditionRunFactory.create(42)
	var room := ExpeditionRunFactory.make_room(node, 42, true)
	run.rooms = [room]
	var resolution := GameManager.resolve_run_hero_data(run, false)
	assert(GameManager._prepare_preconfigured_run(run, resolution.heroes))
	GameManager.current_room_index = 0
	GameManager.expedition = ExpeditionSession.new()
	var session: ExpeditionSession = GameManager.expedition
	session.initialize(GameManager.get_character_state(&"achilles"), 42)
	session.route.current_node_id = node.id
	session.route.phase = "combat"
	session.build.class_mode = true
	session.cards = Cards.new()
	session.cards.bind(session)
	session.cards.primary_class = "gardien"
	session.cards.initialize_deck(Catalog.preset("gardien"))
	var options := ArenaDirectTestConfiguration.resolve(&"real_encounter")
	options.deployment_enabled = false
	options.camera_mode = "PRODUCTION"
	get_tree().set_meta(ArenaDirectTestConfiguration.TREE_META, options)
	var battle = room.battle_scene.instantiate()
	add_child(battle)
	await battle.runtime_ready
	battle._start_battle()
	for frame in 15:
		await get_tree().process_frame
	assert(battle.room_rules != null)
	assert(session.cards.hand.size() == 4)
	await get_tree().create_timer(2.0).timeout
	if exercise:
		var hero: Unit = session.character.unit
		var annotation_layer := CanvasLayer.new()
		annotation_layer.layer = 30
		add_child(annotation_layer)
		var annotation := Label.new()
		annotation.position = Vector2(12, 16)
		annotation.text = "ESSAI MÉCANIQUES · +1 000 PV temporaires"
		annotation.add_theme_font_size_override("font_size", 12)
		annotation_layer.add_child(annotation)
		# This checks turn/UI integration, not balance: a level-one preview must survive a late pack.
		hero.max_hp.add_modifier(1000, Stat.ModType.FLAT, "runtime_probe")
		hero.heal(1000)
		assert(battle.grid.relocate_unit(hero, Vector2i(1, 3)))
		battle._sync_room_positions()
		if room_id == "reservoir":
			assert(battle.grid.relocate_unit(hero, Vector2i(3, 1)))
			battle._sync_room_positions()
			await _complete_round(battle)
			assert(battle.room_rules.charges[0] > 0)
			print("TACTICAL_RESERVOIR_STORAGE_PASS charges=", battle.room_rules.charges[0])
		var cost := 2 if room_id in ["convoy", "hourglass"] else 1
		var before := hero.current_ap
		var action := (
			"gate"
			if room_id == "convoy"
			else ("left" if room_id in ["forge", "reservoir"] else "right")
		)
		if delay_hourglass:
			assert(room_id == "hourglass")
			action = "left"
			cost = 1
		assert(battle._room_input_allowed())
		var stunned_carrier: Unit
		var stunned_position := Vector2i.ZERO
		if open_convoy:
			assert(room_id == "convoy")
			stunned_carrier = battle.room_rules.carriers[0]
			stunned_position = stunned_carrier.grid_pos
			var stun := StatusData.new()
			stun.status_id = &"room_probe_stun"
			stun.status_name = "Étourdi — contrôle runtime"
			stun.skips_turn = true
			stun.duration = 1
			stunned_carrier.apply_status(stun)
		else:
			battle.room_buttons[action].pressed.emit()
			assert(hero.current_ap == before - cost)
			assert(battle.room_rules.mechanism_used)
		await _complete_round(battle)
		assert(not battle.room_rules.mechanism_used)
		assert(session.cards.hand.size() == 4)
		if delay_hourglass:
			assert(battle.room_rules.postponed)
			assert(battle.room_rules.blast_damage == 48)
			assert(not battle.room_rules.use_terminal("left"))
			print("TACTICAL_HOURGLASS_DELAY_PASS")
		if open_convoy:
			assert(stunned_carrier.is_alive)
			assert(stunned_carrier.grid_pos == stunned_position)
			assert(not battle.room_rules.altar_sealed)
			print("TACTICAL_CONVOY_STUN_PASS deliveries=", battle.room_rules.deliveries)
		print("TACTICAL_ROOM_ROUND_PASS ", room_id, " hp=", hero.current_hp)
	if not output.is_empty():
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(output)
		assert(error == OK)
		print(
			"TACTICAL_ROOM_CAPTURE ",
			room_id,
			" actors=",
			battle.units.size(),
			" cards=",
			session.cards.hand.size(),
		)
		if verify_victory:
			_probe_room_victory(battle)
		battle.queue_free()
		await get_tree().process_frame
		GameManager.cleanup_run_state()
		get_tree().quit()


func _complete_round(battle) -> void:
	assert(battle._finish_active_turn(&"manual"))
	var deadline := Time.get_ticks_msec() + 20000
	while (
		not battle._room_input_allowed() and not battle._battle_over
		and Time.get_ticks_msec() < deadline
	):
		await get_tree().create_timer(.05).timeout
	assert(not battle._battle_over)
	assert(battle._room_input_allowed())


func _probe_room_victory(battle) -> void:
	# Deliberate terminal-state fixture, after the unmodified round scenario and capture.
	# The lethal hit itself must come from the public room command / end-turn path.
	var rules = battle.room_rules
	assert(rules.room_id in ["hourglass", "reservoir"])
	for carrier: Unit in rules.carriers:
		if carrier.is_alive:
			carrier.clear_shield()
			carrier.take_damage(99999)
		assert(not carrier.is_alive)
	rules.boss.clear_shield()
	rules.boss.current_hp = 1
	assert(not battle._battle_over)
	if rules.room_id == "reservoir":
		assert(rules.charges[0] > 0)
		battle.room_buttons.left.pressed.emit()
	else:
		assert(battle.grid.relocate_unit(rules.hero, Vector2i(1, 3)))
		battle.room_buttons.right.pressed.emit()
		assert(rules.mechanism_used)
		assert(battle._finish_active_turn(&"manual"))
	assert(not rules.boss.is_alive)
	assert(battle._battle_over)
	assert(not battle._room_input_allowed())
	print("TACTICAL_ROOM_VICTORY_PASS ", rules.room_id)
