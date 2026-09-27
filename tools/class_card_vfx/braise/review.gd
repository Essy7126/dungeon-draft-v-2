extends "res://tools/class_card_vfx/orage/review.gd"
## Reuses the verified current-run fixture and its actual Battle mounting.
const Braise := preload("res://vfx/class_cards/braise/player.gd")
const Effects := preload("res://core/expedition/consumable_card_effects.gd")
const Terrain := preload("res://core/expedition/consumable_card_terrain.gd")
var aim_cell := Vector2i.ZERO
var water_fixture := false


func _init() -> void:
	output_path = "res://artifacts/dev/class_card_vfx/braise/combat/"
	captured_frames = 0
	capture_mode = "--capture-braise" in OS.get_cmdline_user_args()


func _mount() -> bool:
	if not await super._mount():
		return false
	# Pick the room's naturally toughest enemy so the real two-tick burn can be seen.
	for unit: Unit in victims:
		if unit.max_hp.get_int() > target.max_hp.get_int():
			target = unit
	for cell: Vector2i in _central_cells():
		var other := cell + Vector2i(2, -1)
		if (
			battle.grid.is_walkable(cell) and battle.grid.is_walkable(other)
			and battle.pathfinder.has_line_of_sight(cell, other)
		):
			home = cell
			aim_cell = other
			return true
	_check(false, "Two clear, visible sites at range three")
	return false


func _stage(_boost := false, _single := true) -> String:
	router.clear()
	for victim: Unit in victims:
		Effects.states(victim).clear()
		victim.current_hp = victim.max_hp.get_int()
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
				battle.grid.manhattan(c, home) > 5 and c != aim_cell
				and battle.grid.is_walkable(c) and not battle.grid.has_unit(c)
			),
	)
	for i in victims.size():
		_move(victims[i], far_cells[i])
	_move(hero, home)
	_move(target, aim_cell)
	if water_fixture:
		battle.terrain_effects.place_effect(aim_cell, Terrain.effect("water", 2), hero, null, 2)
	battle.camera.global_position = (
		VFXManager._grid_cell_global(home) + VFXManager._grid_cell_global(aim_cell)
	) * .5 + Vector2(0, -VFXManager._cell_visual_width() * .45)
	var uid: String = session.cards.acquire(
		"t02",
		"loot",
		"braise_review:" + str(session.cards.serial),
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
	heading.text = "Braise tenace"
	caption.text = "Charbon fissuré · impact vermillon · deux pulsations de brûlure"
	for child in heading.get_parent().get_children():
		if child is Button and "Orage" in child.text:
			child.text = "Rejouer Braise"


func _record(label: String, zoom_value: Vector2) -> void:
	_labels()
	water_fixture = label == "combat"
	_stage()
	battle.action_bar.hide()
	if is_instance_valid(battle.turn_order_timeline):
		battle.turn_order_timeline.hide()
	battle.camera.zoom = zoom_value
	DirAccess.make_dir_recursive_absolute(output_path + label)
	var hp := target.current_hp
	var spell := Spells.make_spell("t02")
	var fx: Node = router.prepare_sentence(hero, spell, aim_cell)
	_check(fx != null and fx.get_script() == Braise, "Dedicated charcoal: " + label)
	if fx == null:
		return
	fx.manual = true
	var frozen: Array = []
	var pulse_time := -100.0
	for frame in 90:
		var t := frame / 30.0
		if frame == 9:
			var report: Dictionary = battle.spell_caster.cast(hero, spell, aim_cell)
			_check(
				not report.get("failed", false),
				"Actual Braise cast: " + str(report.get("reason", "ok")),
			)
			_check(fx.confirmed and fx.impact_confirmed, "Confirmed impact")
			if not Effects.states(target).has("burn"):
				_check(false, "Review target must survive the initial hit")
				return
			_check(
				target.current_hp < hp and Effects.states(target).burn.duration == 2,
				"Direct hit and two burn activations",
			)
			_check(router.holds.has(_burn_key()), "One burn sign")
			_check(router.surface_holds.has(aim_cell) == water_fixture, "Steam only on actual dynamic water")
			casts.append(
				{ "label": label, "direct_damage": hp - target.current_hp, "water": water_fixture }
			)
			frozen = _combat_values()
		if frame in [42, 66]:
			var before := target.current_hp
			battle._cards_runtime.begin_activation(target)
			_check(target.current_hp < before, "Actual activation burn tick " + str(frame))
			_check(Effects.states(target).has("burn") == (frame == 42), "Exactly two ticks")
			pulse_time = t
			frozen = _combat_values()
		if frame == 54 and water_fixture:
			battle.terrain_effects.tick_all_effects()
			_check(not router.surface_holds.has(aim_cell), "Steam expires at enemy phase boundary")
			_check(Effects.states(target).has("burn"), "Steam expiration keeps remaining burn")
		fx.sample(t)
		if router.holds.has(_burn_key()):
			var held: Node = router.holds[_burn_key()].fx
			held.manual = true
			held.pulse_age = t - pulse_time
			held.sample(t)
		clock_label.text = "%.2f s · %s · %s" % [
			t,
			"eau → vapeur" if water_fixture else "sol sec",
			"impact" if frame < 30 else "activations rapprochées pour la revue",
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
				"Visual sampling leaves combat unchanged: " + label + "/" + str(frame),
			)
	_check(not router.holds.has(_burn_key()), "Expired burn leaves no persistent sign")
	_check(router.echoes.is_empty() and router.flights.is_empty(), "No duplicate projectile")
	fx.cancel()


func _burn_key() -> String:
	return "%s:cc2_burn" % target.get_instance_id()


func _combat_values() -> Array:
	var values: Array = super._combat_values()
	values.append(Effects.states(target).duplicate(true))
	return values


func _replay() -> void:
	if busy:
		return
	busy = true
	_labels()
	water_fixture = false
	_stage()
	await battle._on_request_cast_spell(Spells.make_spell("t02"), aim_cell)
	await get_tree().create_timer(.8).timeout
	busy = false


func _remount(snapshot: Dictionary) -> bool:
	battle._begin_battle_shutdown()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	_check(router.effects.is_empty(), "Shutdown removes all local effects")
	original_snapshot = snapshot
	return await _mount()


func _journey() -> void:
	if not await _remount(original_snapshot):
		return
	water_fixture = true
	var uid := _stage()
	var hp := target.current_hp
	await battle._on_request_cast_spell(Spells.make_spell("t02"), aim_cell)
	var deadline := Time.get_ticks_msec() + 8000
	while battle._spell_resolution_pending and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not battle._spell_resolution_pending, "Public command returns control")
	_check(hero.current_ap == 2 and target.current_hp < hp, "Public command spends two AP and hits")
	_check(session.cards.consumed.has(uid), "Public command consumes one copy")
	if not Effects.states(target).has("burn"):
		_check(false, "Public review target survives the initial hit")
		return
	_check(Effects.states(target).burn.duration == 2, "Public command applies two activation burn")
	await get_tree().create_timer(.8).timeout
	_check(not battle._cards_runtime.save_failed, "Canonical checkpoint committed")
	var snapshot := ExpeditionSaveService.read_snapshot(GameManager.expedition_save_path)
	_check(not snapshot.is_empty(), "Disk checkpoint readable")
	var saved_hp := target.current_hp
	var saved_cell := target.grid_pos
	if not await _remount(snapshot):
		return
	_check(
		session.cards.consumed.has(uid) and hero.current_ap == 2,
		"Resume preserves consumption and AP",
	)
	_check(
		target.current_hp == saved_hp and target.grid_pos == saved_cell,
		"Resume preserves HP and position",
	)
	_check(Effects.states(target).burn.duration == 2, "Resume preserves burn duration")
	router._restore_unit_holds()
	_check(
		router.holds.has(_burn_key()) and router.holds[_burn_key()].fx.pulse_age > 1.0,
		"Resume restores quiet burn sign",
	)
	_check(
		router.surface_holds.has(saved_cell) and router.surface_holds[saved_cell].motif
		== "braise_steam",
		"Resume restores exact steam presentation",
	)
	_check(
		router
		.effects
		.filter(
			func(node):
				return is_instance_valid(node) and node is Braise and not node.badge_mode,
		)
		.is_empty(),
		"Resume never replays projectile or impact",
	)
	clock_label.text = "Reprise disque · brûlure et vapeur conservées"
	await _capture("combat_resumed")
	battle._cards_runtime.begin_activation(target)
	battle.terrain_effects.tick_all_effects()
	await get_tree().create_timer(.4).timeout
	_check(Effects.states(target).burn.duration == 1, "First activation leaves one burn tick")
	_check(not router.surface_holds.has(saved_cell), "Steam lifetime is independent")
	battle._cards_runtime.checkpoint()
	snapshot = ExpeditionSaveService.read_snapshot(GameManager.expedition_save_path)
	saved_hp = target.current_hp
	if not await _remount(snapshot):
		return
	_check(
		target.current_hp == saved_hp and Effects.states(target).burn.duration == 1,
		"Mid-burn disk resume preserves exact remaining tick",
	)
	battle._cards_runtime.begin_activation(target)
	await get_tree().create_timer(.5).timeout
	_check(
		not Effects.states(target).has("burn") and not router.holds.has(_burn_key()),
		"Second activation extinguishes burn and sign",
	)
	var last_hp := target.current_hp
	battle._cards_runtime.begin_activation(target)
	_check(target.current_hp == last_hp, "No third damage or burn pulse")
	battle._begin_battle_shutdown()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	GameManager._combat_report_tracker.discard()
	_check(session.combat_won(), "Fixture victory reaches real receipt")
	var path := "user://braise_receipt.json"
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
		"note": "Actual current Cards third room; two earlier fixture victories. Actors repositioned, HP restored to normal maximum between examples; visual sequences hide HUD. Two enemy activations are deliberately brought together for review via actual Cards runtime; AI movement is held. Public cast, disk checkpoint, mid-burn resume and receipt roundtrip; not a balance or full enemy-turn simulation.",
	}
	FileAccess.open(output_path + "report.json", FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	get_tree().quit(0 if report.passed else 1)
