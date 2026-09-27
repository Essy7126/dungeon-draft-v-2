extends "res://tools/class_card_vfx/semantic_probe.gd"
const Current := preload("res://core/expedition/consumable_card_catalog.gd")
const Spells := preload("res://core/expedition/consumable_card_spells.gd")
const Orage := preload("res://vfx/class_cards/orage/player.gd")
const REVIEW_TARGETS := [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN + Vector2i.RIGHT]
var capture_mode := false
var original_snapshot: Dictionary = { }
var normal_zoom := Vector2.ONE
var home := Vector2i.ZERO
var victims: Array[Unit] = []
var driver: Node
var busy := false


class Driver:
	extends "res://core/game_manager.gd"
	func _request_scene_change(
		_path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		pass


	func start_next_battle() -> void:
		pass


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


func _init() -> void:
	output_path = "res://artifacts/dev/class_card_vfx/orage/combat/"
	captured_frames = 0
	capture_mode = "--capture-orage" in OS.get_cmdline_user_args()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output_path)
	get_window().size = Vector2i(1440, 950)
	get_tree().root.content_scale_size = Vector2i(1440, 950)
	if not OS.get_user_data_dir().replace("\\", "/").begins_with(
		ProjectSettings.globalize_path("res://artifacts/dev/").replace("\\", "/")
	):
		push_error("Orage review requires isolated APPDATA")
		get_tree().quit(2)
		return
	GameManager.cleanup_run_state()
	driver = Driver.new()
	add_child(driver)
	driver.select_run_variant("cards")
	driver.expedition_save_path = "user://orage_driver.json"
	_check(
		driver.start_expedition(33, { }, false, true, "normal", true),
		"Current Cards preparation starts",
	)
	if driver.expedition == null:
		await _finish()
		return
	# Reach the third authored encounter through the real route services.
	# Prior victories are explicit fixtures; this is not a balance simulation.
	for _prior in 2:
		var route_session: ExpeditionSession = driver.expedition
		_check(route_session.combat_won(), "Prior fixture victory")
		_check(route_session.acknowledge_combat_receipt().success, "Prior receipt acknowledged")
		while not route_session.advancement_step.is_empty():
			_check(route_session.advance_level_step().success, "Prior level progression")
		var rewards: Array = route_session.reward_options(driver.item_catalog)
		_check(not rewards.is_empty(), "Route reward available")
		if rewards.is_empty():
			await _finish()
			return
		_check(
			route_session.claim(str(rewards[0].id), driver.run_inventory, driver.item_catalog).success,
			"Route reward claimed",
		)
		var next: Array = route_session.route.get_available_nodes()
		_check(
			not next.is_empty() and driver.choose_expedition_node(str(next[0].id)),
			"Next authored encounter",
		)
	original_snapshot = driver.get_expedition_snapshot().duplicate(true)
	GameManager.expedition_save_path = "user://orage_review.json"
	if not await _mount():
		await _finish()
		return
	_overlay()
	heading.text = "Orage du passage"
	caption.text = "Charge comprimée · foudre simultanée · éclats ivoire et or"
	normal_zoom = battle.camera.zoom
	if capture_mode:
		await _record("detail", normal_zoom * 1.9)
		await _record("combat", normal_zoom)
		await _journey()
		await _finish()
	else:
		var button := Button.new()
		button.text = "Rejouer Orage du passage"
		button.position = Vector2(56, 170)
		heading.get_parent().add_child(button)
		button.pressed.connect(_replay)
		var zoom_button := Button.new()
		zoom_button.text = "Caméra normale / détail"
		zoom_button.position = Vector2(330, 170)
		heading.get_parent().add_child(zoom_button)
		zoom_button.pressed.connect(
			func():
				battle.camera.zoom = normal_zoom if battle.camera.zoom != normal_zoom else normal_zoom * 1.9,
		)
		battle.camera.zoom = normal_zoom * 1.9
		await _replay()


func _mount() -> bool:
	var restored := GameManager.restore_expedition_snapshot(original_snapshot)
	_check(restored, "Prepared current run restores")
	if not restored:
		return false
	session = GameManager.expedition
	battle = GameManager.get_current_room().battle_scene.instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if session.combat_checkpoint.is_empty():
		battle._deployment.on_cell_clicked(battle._deployment._deploy_zone[0])
	var deadline := Time.get_ticks_msec() + 25000
	while not battle._can_accept_player_intent() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(battle._can_accept_player_intent(), "Actual current Cards Battle ready")
	if not battle._can_accept_player_intent():
		return false
	var banner: Control = battle.action_bar.get_turn_intro_banner()
	while (
		is_instance_valid(banner) and banner.is_visible_in_tree()
		and Time.get_ticks_msec() < deadline
	):
		await get_tree().process_frame
	_check(
		not is_instance_valid(banner) or not banner.is_visible_in_tree(),
		"Turn introduction completes before review",
	)
	hero = session.character.unit
	router = VFXManager._class_card_router
	victims.clear()
	for unit: Unit in battle.units:
		if unit.team != hero.team:
			victims.append(unit)
	target = victims[0] if not victims.is_empty() else null
	_check(
		target != null and battle._cards_runtime != null,
		"Current Cards runtime and enemies bound",
	)
	var found := false
	for cell in _central_cells():
		var open := true
		for offset in [Vector2i.ZERO] + REVIEW_TARGETS:
			open = open and battle.grid.is_walkable(cell + offset)
		if open:
			home = cell
			found = true
			break
	_check(found, "Clear real arena tiles found")
	return found and target != null and battle._cards_runtime != null


func _stage(boost := true, single := false) -> String:
	router.clear()
	router.bind_terrain(battle.terrain_effects)
	for cell in battle.terrain_effects.active_surface_cells():
		battle.terrain_effects.clear_effect(cell)
	hero.current_ap = 4
	hero._ability_states.clear()
	hero.clear_combat_effect_history()
	session.cards.used_families.clear()
	session.cards.pending_choice.clear()
	session.cards._activation_open = true
	var far_cells := _central_cells().filter(
		func(c):
			return (
				battle.grid.manhattan(c, home) > 4 and battle.grid.is_walkable(c)
				and not battle.grid.has_unit(c)
			),
	)
	for i in victims.size():
		_move(victims[i], far_cells[i])
		if boost:
			victims[i].max_hp.base_value = 1000
			victims[i].current_hp = 1000
		victims[i].esquive.base_value = 0
	_move(hero, home)
	var positions := REVIEW_TARGETS
	for i in mini(1 if single else 3, victims.size()):
		_move(victims[i], home + positions[i])
	hero.crit_chance.base_value = 0
	battle.camera.global_position = VFXManager._grid_cell_global(home) + Vector2(
		0,
		-VFXManager._cell_visual_width() * .45,
	)
	var uid: String = session.cards.acquire(
		"l01",
		"loot",
		"orage_review:" + str(session.cards.serial),
	)
	if session.cards.active.size() >= 15:
		session.cards.active.pop_back()
	session.cards.active.append(uid)
	session.cards.draw_pile.assign(
		session.cards.active.filter(
			func(id):
				return id != uid,
		)
	)
	session.cards.discard.clear()
	session.cards.hand.assign([uid])
	session.cards.retained = ""
	session.cards._repair_opening()
	session.cards.selected = uid
	return uid


func _record(label: String, zoom_value: Vector2) -> void:
	_stage()
	battle.action_bar.hide()
	if is_instance_valid(battle.turn_order_timeline):
		battle.turn_order_timeline.hide()
	battle.camera.zoom = zoom_value
	DirAccess.make_dir_recursive_absolute(output_path + label)
	var spell := Spells.make_spell("l01")
	var fx: Node = router.prepare_sentence(hero, spell, hero.grid_pos)
	_check(fx != null and fx.get_script() == Orage, "Dedicated anticipation: " + label)
	if fx == null:
		return
	fx.manual = true
	var report := { }
	var frozen := []
	for frame in 42:
		var t := frame / 30.0
		if frame == 9:
			report = battle.spell_caster.cast(hero, spell, hero.grid_pos)
			_check(
				not report.get("failed", false),
				"Actual Orage cast: " + label + " / " + str(report.get("reason", "ok")),
			)
			_check(fx.confirmed, "Charge confirmed by cast event")
			_check(
				fx.hit_points.size() == report.get("damaged_enemies", []).size(),
				"One bolt per damaged enemy",
			)
			frozen = _combat_values()
			casts.append(
				{
					"label": label,
					"enemies": report.get("damaged_enemies", []).size(),
					"damage": report.get("hp_damage_total", 0),
				}
			)
		fx.sample(t)
		clock_label.text = "%.2f s · %s · 3 PA · IA suspendue" % [
			t,
			"caméra de combat" if label == "combat" else "vue de détail",
		]
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_check(
			get_viewport().get_texture().get_image().save_png(
				output_path + label + "/%03d.png" % frame
			) == OK,
			label + " frame " + str(frame),
		)
		captured_frames += 1
		if frame >= 9:
			_check(
				_combat_values() == frozen,
				"Playback preserves resolved combat: " + label + "/" + str(frame),
			)
	_check(router.echoes.is_empty(), "No duplicate generic projectile")
	_check(router.surface_holds.is_empty(), "No lingering electrified terrain")
	fx.cancel()


func _combat_values() -> Array:
	var values := [hero.current_hp, hero.current_ap, session.cards.consumed.size()]
	for unit in victims:
		values.append([unit.current_hp, unit.current_shield, unit.grid_pos])
	return values


func _replay() -> void:
	if busy:
		return
	busy = true
	_stage()
	var spell := Spells.make_spell("l01")
	router.prepare_sentence(hero, spell, hero.grid_pos)
	await get_tree().create_timer(Orage.CONTACT).timeout
	battle.spell_caster.cast(hero, spell, hero.grid_pos)
	await get_tree().create_timer(1.0).timeout
	busy = false


func _journey() -> void:
	battle._begin_battle_shutdown()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	if not await _mount():
		return
	var uid := _stage(false, true)
	var before := hero.current_ap
	var hp := target.current_hp
	await battle._on_request_cast_spell(Spells.make_spell("l01"), hero.grid_pos)
	var deadline := Time.get_ticks_msec() + 8000
	while battle._spell_resolution_pending and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not battle._spell_resolution_pending, "Public command returns control")
	_check(hero.current_ap == before - 3, "Public command spends exactly three AP")
	_check(target.current_hp < hp, "Public command damages actual enemy")
	_check(session.cards.consumed.has(uid), "Public command consumes one actual copy")
	_check(router.sentence_preparations.is_empty(), "Public command consumes anticipation")
	await get_tree().create_timer(1.0).timeout
	_check(not battle._cards_runtime.save_failed, "Canonical combat checkpoint saves")
	_check(not session.combat_checkpoint.is_empty(), "Combat continuation exists")
	# The public getter intentionally refuses a live combat report. Resume the
	# checkpoint that the real runtime has committed to disk instead.
	var snapshot := ExpeditionSaveService.read_snapshot(GameManager.expedition_save_path)
	_check(not snapshot.is_empty(), "Committed combat snapshot readable")
	var saved_ap: int = hero.current_ap
	var saved_cell: Vector2i = hero.grid_pos
	var saved_enemy_hp: int = target.current_hp
	battle._begin_battle_shutdown()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	_check(router.effects.is_empty(), "Shutdown clears every Orage sheet")
	original_snapshot = snapshot
	if not await _mount():
		return
	_check(true, "Combat checkpoint remounts the real Battle")
	_check(session.cards.consumed.has(uid), "Resume keeps Orage copy consumed")
	_check(
		hero.current_ap == saved_ap and hero.grid_pos == saved_cell,
		"Resume retains exact AP and position",
	)
	_check(target.current_hp == saved_enemy_hp, "Resume retains resolved enemy HP")
	_check(router.effects.is_empty(), "Resume does not replay lightning")
	await _capture("combat_resumed")
	battle._begin_battle_shutdown()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	GameManager._combat_report_tracker.discard()
	_check(session.combat_won(), "Fixture victory reaches the actual Cards receipt")
	var path := "user://orage_receipt.json"
	_check(GameManager.save_expedition(path), "Receipt saves with production service")
	var receipt: Node = load(GameManager.EXPEDITION_SCREEN_PATH).instantiate()
	add_child(receipt)
	await get_tree().create_timer(.4).timeout
	await _capture("receipt")
	receipt.queue_free()
	await get_tree().process_frame
	var saved: Dictionary = ExpeditionSaveService.read_snapshot(path)
	_check(not saved.is_empty(), "Receipt snapshot readable")
	_check(GameManager.restore_expedition_snapshot(saved), "Saved receipt restores")
	ExpeditionSaveService.remove_snapshot(path)


func _finish() -> void:
	if is_instance_valid(battle):
		battle._begin_battle_shutdown()
		battle.queue_free()
	if is_instance_valid(driver):
		driver.cleanup_run_state()
		driver.queue_free()
	GameManager.cleanup_run_state()
	await get_tree().process_frame
	await get_tree().process_frame
	var report := {
		"passed": checks.all(
			func(row):
				return row.ok,
		),
		"frames": captured_frames,
		"checks": checks,
		"casts": casts,
		"note": "Actual current Cards room; AI paused, enemies repositioned and HP raised only for the two visual sequences. Fresh unboosted public cast and receipt fixture; not a balance test.",
	}
	FileAccess.open(output_path + "report.json", FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	get_tree().quit(0 if report.passed else 1)
