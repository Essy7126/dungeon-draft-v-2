extends "res://tools/class_card_vfx/orage/review.gd"
## Reuses the verified current-run fixture and its actual Battle mounting.
const Permutation := preload("res://vfx/class_cards/permutation/player.gd")
var exchange_cell := Vector2i.ZERO


func _init() -> void:
	output_path = "res://artifacts/dev/class_card_vfx/permutation/combat/"
	captured_frames = 0
	capture_mode = "--capture-permutation" in OS.get_cmdline_user_args()


func _mount() -> bool:
	if not await super._mount():
		return false
	for cell: Vector2i in _central_cells():
		var other := cell + Vector2i(2, -2)
		if (
			battle.grid.is_walkable(cell) and battle.grid.is_walkable(other)
			and battle.pathfinder.has_line_of_sight(cell, other)
		):
			home = cell
			exchange_cell = other
			return true
	_check(false, "Two clear, visible sites at range four")
	return false


func _stage(_boost := false, _single := true) -> String:
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
				battle.grid.manhattan(c, home) > 5 and c != exchange_cell
				and battle.grid.is_walkable(c) and not battle.grid.has_unit(c)
			),
	)
	for i in victims.size():
		_move(victims[i], far_cells[i])
	_move(hero, home)
	_move(target, exchange_cell)
	battle.camera.global_position = (
		VFXManager._grid_cell_global(home) + VFXManager._grid_cell_global(exchange_cell)
	) * .5 + Vector2(0, -VFXManager._cell_visual_width() * .45)
	var uid: String = session.cards.acquire(
		"r08",
		"loot",
		"permutation_review:" + str(session.cards.serial),
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


func _labels() -> void:
	heading.text = "Permutation"
	caption.text = "Deux ancrages · échange instantané · jade, ivoire et bronze"
	for child in heading.get_parent().get_children():
		if child is Button and "Orage" in child.text:
			child.text = "Rejouer Permutation"


func _record(label: String, zoom_value: Vector2) -> void:
	_labels()
	_stage()
	battle.action_bar.hide()
	if is_instance_valid(battle.turn_order_timeline):
		battle.turn_order_timeline.hide()
	battle.camera.zoom = zoom_value
	DirAccess.make_dir_recursive_absolute(output_path + label)
	var hp := [hero.current_hp, target.current_hp]
	var spell := Spells.make_spell("r08")
	var fx: Node = router.prepare_sentence(hero, spell, exchange_cell)
	_check(fx != null and fx.get_script() == Permutation, "Dedicated paired clasps: " + label)
	if fx == null:
		return
	fx.manual = true
	var frozen := []
	for frame in 42:
		var t := frame / 30.0
		if frame == 8:
			var report: Dictionary = battle.spell_caster.cast(hero, spell, exchange_cell)
			_check(
				not report.get("failed", false),
				"Actual Permutation cast: " + str(report.get("reason", "ok")),
			)
			_check(fx.confirmed and fx.sites.size() == 2, "Two sites confirmed together")
			_check(
				[hero.grid_pos, target.grid_pos] == [exchange_cell, home],
				"Real positions exchanged",
			)
			_check(
				[hero.current_hp, target.current_hp] == hp
				and report.get("damaged_enemies", []).is_empty(),
				"Permutation causes no damage",
			)
			_check(
				not is_instance_valid(battle._spell_movement_feedback_tween),
				"No dash tween for exchange",
			)
			for unit: Unit in [hero, target]:
				_check(
					battle._unit_views[unit].global_position.distance_to(
						VFXManager._grid_cell_global(unit.grid_pos)
					) < 1,
					"Both visible actors already occupy their new cells",
				)
			frozen = _combat_values()
			casts.append(
				{
					"label": label,
					"sites": 2,
					"damage": report.get("hp_damage_total", 0),
					"origin": [home.x, home.y],
					"destination": [exchange_cell.x, exchange_cell.y],
				}
			)
		fx.sample(t)
		clock_label.text = "%.2f s · %s · 2 PA · aucun dégât" % [
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
		if frame >= 8:
			_check(
				_combat_values() == frozen,
				"Visual playback preserves resolved state: " + label + "/" + str(frame),
			)
	_check(
		router.echoes.is_empty() and router.arrivals.is_empty(),
		"No extra movement or projectile effects",
	)
	_check(router.surface_holds.is_empty(), "No persistent portal")
	fx.cancel()


func _combat_values() -> Array:
	var values: Array = super._combat_values()
	values.append(hero.grid_pos)
	return values


func _replay() -> void:
	if busy:
		return
	busy = true
	_labels()
	_stage()
	await battle._on_request_cast_spell(Spells.make_spell("r08"), exchange_cell)
	await get_tree().create_timer(.8).timeout
	busy = false


func _journey() -> void:
	battle._begin_battle_shutdown()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	if not await _mount():
		return
	var uid := _stage()
	var hp: Array = [hero.current_hp, target.current_hp]
	await battle._on_request_cast_spell(Spells.make_spell("r08"), exchange_cell)
	var deadline := Time.get_ticks_msec() + 8000
	while battle._spell_resolution_pending and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not battle._spell_resolution_pending, "Public command returns control")
	_check(hero.current_ap == 2, "Public command spends two AP")
	_check(
		[hero.grid_pos, target.grid_pos] == [exchange_cell, home],
		"Public command exchanges both units",
	)
	_check([hero.current_hp, target.current_hp] == hp, "Public command preserves both HP")
	_check(session.cards.consumed.has(uid), "Public command consumes one copy")
	_check(router.sentence_preparations.is_empty(), "Public command clears anticipation")
	await get_tree().create_timer(.8).timeout
	_check(not battle._cards_runtime.save_failed, "Canonical checkpoint saved")
	var snapshot := ExpeditionSaveService.read_snapshot(GameManager.expedition_save_path)
	_check(not snapshot.is_empty(), "Committed checkpoint readable")
	var saved_positions: Array = [hero.grid_pos, target.grid_pos]
	battle._begin_battle_shutdown()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	_check(router.effects.is_empty(), "Shutdown clears every clasp")
	original_snapshot = snapshot
	if not await _mount():
		return
	_check(session.cards.consumed.has(uid), "Resume keeps copy consumed")
	_check(
		hero.current_ap == 2 and [hero.grid_pos, target.grid_pos] == saved_positions,
		"Resume preserves AP and both exchanged positions",
	)
	_check([hero.current_hp, target.current_hp] == hp, "Resume preserves both HP")
	_check(router.effects.is_empty(), "Resume does not replay the exchange")
	clock_label.text = "Reprise réelle · positions échangées conservées"
	await _capture("combat_resumed")
	battle._begin_battle_shutdown()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	GameManager._combat_report_tracker.discard()
	_check(session.combat_won(), "Fixture victory reaches real receipt")
	var path := "user://permutation_receipt.json"
	_check(GameManager.save_expedition(path), "Receipt saves")
	var receipt: Node = load(GameManager.EXPEDITION_SCREEN_PATH).instantiate()
	add_child(receipt)
	await get_tree().create_timer(.4).timeout
	await _capture("receipt")
	receipt.queue_free()
	await get_tree().process_frame
	_check(
		GameManager.restore_expedition_snapshot(ExpeditionSaveService.read_snapshot(path)),
		"Saved receipt restores",
	)
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
		"note": "Actual current Cards third room; two earlier fixture victories. Repositioned actors, unmodified HP, AI held on player turn, HUD hidden only in visual sequences. Public command, disk checkpoint and receipt roundtrip; not a balance test.",
	}
	FileAccess.open(output_path + "report.json", FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	get_tree().quit(0 if report.passed else 1)
