extends "res://tools/class_card_vfx/orage/review.gd"
## Real card command, current-run enemy AI attack and disk checkpoint restoration.
const Contre := preload("res://vfx/class_cards/contre/player.gd")
const Counter := preload("res://vfx/class_cards/contre/controller.gd")
const Effects := preload("res://core/expedition/consumable_card_effects.gd")
const Turns := preload("res://core/expedition/consumable_card_turns.gd")
var upgraded := false
var cast_done := false
var enemy_done := false


func _init() -> void:
	output_path = "res://artifacts/dev/class_card_vfx/contre/combat/"
	captured_frames = 0
	capture_mode = "--capture-contre" in OS.get_cmdline_user_args()


func _mount() -> bool:
	if not await super._mount():
		return false
	victims.sort_custom(_victim_before)
	target = victims[0]
	return true


func _victim_before(a: Unit, b: Unit) -> bool:
	if a.max_hp.get_int() == b.max_hp.get_int():
		return str(a.get_runtime_stable_id()) < str(b.get_runtime_stable_id())
	return a.max_hp.get_int() > b.max_hp.get_int()


func _stage(_boost := false, _single := false) -> String:
	router.clear()
	router.bind_terrain(battle.terrain_effects)
	for cell in battle.terrain_effects.active_surface_cells():
		battle.terrain_effects.clear_effect(cell)
	hero.current_ap = 4
	hero.current_hp = hero.max_hp.get_int()
	hero._ability_states.clear()
	hero.clear_combat_effect_history()
	hero.clear_shield_source(&"cc2_guard")
	Effects.states(hero).clear()
	hero.crit_chance.base_value = 0
	hero.esquive.base_value = 0
	session.cards.used_families.clear()
	session.cards.pending_choice.clear()
	session.cards._activation_open = true
	if upgraded and not "g05" in session.cards.upgraded_ids:
		session.cards.upgraded_ids.append("g05")
	elif not upgraded:
		session.cards.upgraded_ids.erase("g05")
	var far_cells := _central_cells().filter(_far_cell)
	for i in victims.size():
		Effects.states(victims[i]).clear()
		victims[i].current_hp = victims[i].max_hp.get_int()
		victims[i].esquive.base_value = 0
		_move(victims[i], far_cells[i])
	_move(hero, home)
	_move(target, home + Vector2i.RIGHT)
	battle.camera.global_position = VFXManager._grid_cell_global(home) + Vector2(
		20,
		-VFXManager._cell_visual_width() * .30,
	)
	var uid: String = session.cards.acquire(
		"g05",
		"loot",
		"contre_review:" + str(session.cards.serial),
	)
	if session.cards.active.size() >= 15:
		session.cards.active.pop_back()
	session.cards.active.append(uid)
	session.cards.draw_pile.assign(session.cards.active)
	session.cards.draw_pile.erase(uid)
	session.cards.discard.clear()
	session.cards.hand.assign([uid])
	session.cards.retained = ""
	session.cards._repair_opening()
	session.cards.selected = uid
	return uid


func _labels() -> void:
	heading.text = "Contre préparé"
	caption.text = "Bronze assemblé · riposte en réserve · revers ivoire"
	for child in heading.get_parent().get_children():
		if child is Button and "Orage" in child.text:
			child.text = "Rejouer Contre préparé"


func _far_cell(cell: Vector2i) -> bool:
	if battle.grid.has_unit(cell):
		return false
	return battle.grid.manhattan(cell, home) > 4 and battle.grid.is_walkable(cell)


func _public_cast() -> void:
	cast_done = false
	await battle._on_request_cast_spell(Spells.make_spell("g05", upgraded), hero.grid_pos)
	cast_done = true


func _enemy_attack() -> void:
	enemy_done = false
	target.start_turn()
	await battle._cards_runtime.run_enemy(target)
	enemy_done = true


func _record(label: String, zoom_value: Vector2) -> void:
	if label == "combat":
		if not await _remount(original_snapshot):
			return
	_labels()
	upgraded = label == "combat"
	var uid := _stage()
	battle.action_bar.hide()
	if is_instance_valid(battle.turn_order_timeline):
		battle.turn_order_timeline.hide()
	battle.camera.zoom = zoom_value
	DirAccess.make_dir_recursive_absolute(output_path + label)
	var observed := { "arm": [], "token": [], "riposte": [] }
	var hp_before := target.current_hp
	for frame in 90:
		if frame == 3:
			_public_cast()
		if frame == 40:
			_check(cast_done and hero.current_ap == 2, "Public card command finishes; two AP spent")
			_check(Counter.active(hero), "Counter armed before enemy attack")
			_check(session.cards.consumed.has(uid), "Exactly the selected copy consumed")
		if frame == 42:
			_enemy_attack()
		for fx in router.effects:
			if is_instance_valid(fx) and fx is Contre and not fx.closed:
				if not fx.get_instance_id() in observed[fx.mode]:
					observed[fx.mode].append(fx.get_instance_id())
		clock_label.text = "%.2f s · %s · %s" % [
			frame / 30.0,
			"caméra normale" if label == "combat" else "détail",
			"améliorée" if upgraded else "normale",
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
	_check(enemy_done, "Actual current-run enemy AI completes its attack")
	_check(target.current_hp < hp_before, "Riposte damages the actual attacker")
	_check(not Counter.active(hero), "One counter charge consumed")
	_check(
		observed.arm.size() == 1 and observed.riposte.size() == 1,
		"One assembly and one return stroke",
	)
	_check(observed.token.size() == 1, "One quiet token, no state stacking")
	_check(router.echoes.is_empty() and router.flights.is_empty(), "No generic duplicate flight")
	_check(
		_count("riposte") == 0 and _count("arm") == 0 and _count("token") == 0,
		"No retained counter effect after hit",
	)
	casts.append(
		{
			"label": label,
			"upgraded": upgraded,
			"counter_damage_and_passive": hp_before - target.current_hp,
			"guard_remaining": hero.current_shield,
			"observed": observed,
		}
	)


func _count(mode: String) -> int:
	var count := 0
	for fx in router.effects:
		if is_instance_valid(fx) and not fx.closed and fx is Contre and fx.mode == mode:
			count += 1
	return count


func _replay() -> void:
	if busy:
		return
	busy = true
	if not await _remount(original_snapshot):
		busy = false
		return
	_labels()
	upgraded = false
	_stage()
	await _public_cast()
	await get_tree().create_timer(.8).timeout
	await _enemy_attack()
	busy = false


func _remount(snapshot: Dictionary) -> bool:
	battle._begin_battle_shutdown()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	_check(router.effects.is_empty(), "Shutdown removes all sheets and holds")
	original_snapshot = snapshot
	return await _mount()


func _journey() -> void:
	if not await _remount(original_snapshot):
		return
	upgraded = false
	var uid := _stage()
	await _public_cast()
	await get_tree().create_timer(.8).timeout
	_check(Counter.active(hero), "Public cast arms saved state")
	_check(not battle._cards_runtime.save_failed, "Production checkpoint committed")
	var snapshot := ExpeditionSaveService.read_snapshot(GameManager.expedition_save_path)
	_check(not snapshot.is_empty(), "Armed checkpoint read from disk")
	var saved := _combat_values()
	var guard := hero.current_shield
	if not await _remount(snapshot):
		return
	_check(_combat_values() == saved, "Resume keeps AP, HP, positions and consumed copy")
	_check(session.cards.consumed.has(uid) and Counter.active(hero), "Armed counter survives resume")
	_check(
		_count("arm") == 0 and _count("riposte") == 0 and _count("token") == 1,
		"Resume restores only the quiet token",
	)
	await _capture("combat_resumed_armed")
	await _enemy_attack()
	await get_tree().create_timer(.6).timeout
	_check(
		not Counter.active(hero) and hero.current_shield < guard,
		"Resumed counter actually fires",
	)
	_check(battle._cards_runtime.checkpoint(), "Spent counter checkpoint committed")
	var spent := ExpeditionSaveService.read_snapshot(GameManager.expedition_save_path)
	if not await _remount(spent):
		return
	_check(
		not Counter.active(hero) and _count("token") == 0 and _count("riposte") == 0,
		"Spent counter does not return on resume",
	)
	await _capture("combat_resumed_spent")
	# Independent expiry path starts from the same armed disk checkpoint.
	if not await _remount(snapshot):
		return
	Turns.begin_hero(hero, session.cards, battle.terrain_effects, false)
	await get_tree().create_timer(.7).timeout
	_check(
		not Counter.active(hero) and _count("token") == 0 and _count("riposte") == 0,
		"Next activation expires without an invented strike",
	)
	await _capture("expired")
	battle._begin_battle_shutdown()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	GameManager._combat_report_tracker.discard()
	_check(session.combat_won(), "Fixture victory opens actual Cards receipt")
	var path := "user://contre_receipt.json"
	_check(GameManager.save_expedition(path), "Receipt saved by production service")
	var receipt: Node = load(GameManager.EXPEDITION_SCREEN_PATH).instantiate()
	add_child(receipt)
	await get_tree().create_timer(.4).timeout
	await _capture("receipt")
	receipt.queue_free()
	await get_tree().process_frame
	var receipt_snapshot := ExpeditionSaveService.read_snapshot(path)
	_check(not receipt_snapshot.is_empty(), "Receipt snapshot readable")
	_check(GameManager.restore_expedition_snapshot(receipt_snapshot), "Saved receipt restores")
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
		"passed": checks.all(_row_passed),
		"frames": captured_frames,
		"checks": checks,
		"casts": casts,
		"note": "Actual current Cards room, staged positions and natural maximum HP. Public card command and production enemy AI attack, armed/spent disk save/resume, expiry; fixture victory/receipt. Not a played victory or balance test.",
	}
	FileAccess.open(output_path + "report.json", FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	get_tree().quit(0 if report.passed else 1)


func _row_passed(row: Dictionary) -> bool:
	return row.ok
