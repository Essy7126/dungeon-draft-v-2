extends "res://tools/class_card_vfx/orage/review.gd"
## Real current-run room, deterministic staging, no invented combat result.
const Convergence := preload("res://vfx/class_cards/convergence/player.gd")
const Effects := preload("res://core/expedition/consumable_card_effects.gd")
const PULL_ORIGINS := [Vector2i.UP * 2, Vector2i.LEFT * 2, Vector2i.RIGHT * 2]
const HERO_OFFSET := Vector2i(-2, 1)
var aim_cell := Vector2i.ZERO
var upgraded := false


func _init() -> void:
	output_path = "res://artifacts/dev/class_card_vfx/convergence/combat/"
	captured_frames = 0
	capture_mode = "--capture-convergence" in OS.get_cmdline_user_args()


func _mount() -> bool:
	if not await super._mount():
		return false
	victims.sort_custom(_victim_before)
	target = victims[0]
	for cell: Vector2i in _central_cells():
		var open := true
		for offset in [
			Vector2i.ZERO,
			HERO_OFFSET,
			Vector2i.UP,
			Vector2i.LEFT,
			Vector2i.RIGHT,
			Vector2i.DOWN,
		] + PULL_ORIGINS:
			open = open and battle.grid.is_walkable(cell + offset)
			open = open and battle.pathfinder.has_line_of_sight(cell + HERO_OFFSET, cell + offset)
		if open:
			aim_cell = cell
			home = cell + HERO_OFFSET
			return victims.size() >= 3
	_check(false, "Clear attraction radius and cross in actual arena")
	return false


func _victim_before(a: Unit, b: Unit) -> bool:
	if a.max_hp.get_int() == b.max_hp.get_int():
		return str(a.get_runtime_stable_id()) < str(b.get_runtime_stable_id())
	return a.max_hp.get_int() > b.max_hp.get_int()


func _stage(_boost := false, single := false) -> String:
	router.clear()
	router.bind_terrain(battle.terrain_effects)
	for cell in battle.terrain_effects.active_surface_cells():
		battle.terrain_effects.clear_effect(cell)
	hero.current_ap = 4
	hero._ability_states.clear()
	hero.clear_combat_effect_history()
	hero.crit_chance.base_value = 0
	session.cards.used_families.clear()
	session.cards.pending_choice.clear()
	session.cards._activation_open = true
	if upgraded and not "t08" in session.cards.upgraded_ids:
		session.cards.upgraded_ids.append("t08")
	elif not upgraded:
		session.cards.upgraded_ids.erase("t08")
	var far_cells := _central_cells().filter(
		func(c):
			return (
				battle.grid.manhattan(c, aim_cell) > 4 and battle.grid.is_walkable(c)
				and not battle.grid.has_unit(c)
			),
	)
	for i in victims.size():
		Effects.states(victims[i]).clear()
		victims[i].current_hp = victims[i].max_hp.get_int()
		victims[i].esquive.base_value = 0
		_move(victims[i], far_cells[i])
	_move(hero, home)
	for i in (1 if single else 3):
		_move(victims[i], aim_cell + PULL_ORIGINS[i])
	battle.camera.global_position = VFXManager._grid_cell_global(aim_cell) + Vector2(
		0,
		-VFXManager._cell_visual_width() * .30,
	)
	var uid: String = session.cards.acquire(
		"t08",
		"loot",
		"convergence_review:" + str(session.cards.serial),
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
	heading.text = "Convergence"
	caption.text = "Quatre pétales · attraction d’un pas · frappe en croix"
	for child in heading.get_parent().get_children():
		if child is Button and "Orage" in child.text:
			child.text = "Rejouer Convergence"


func _record(label: String, zoom_value: Vector2) -> void:
	# A real lethal hit removes its view; start each clip from a fresh checkpoint.
	if label == "combat":
		if not await _remount(original_snapshot):
			return
	_labels()
	upgraded = label == "combat"
	_stage()
	battle.action_bar.hide()
	if is_instance_valid(battle.turn_order_timeline):
		battle.turn_order_timeline.hide()
	battle.camera.zoom = zoom_value
	DirAccess.make_dir_recursive_absolute(output_path + label)
	var spell := Spells.make_spell("t08", upgraded)
	var fx: Node = router.prepare_sentence(hero, spell, aim_cell)
	_check(fx != null and fx.get_script() == Convergence, "Dedicated Convergence anticipation")
	if fx == null:
		return
	fx.manual = true
	var frozen: Array = []
	for frame in 45:
		var t := frame / 30.0
		if frame == 8:
			var report: Dictionary = battle.spell_caster.cast(hero, spell, aim_cell)
			_check(
				not report.get("failed", false),
				"Actual cast: " + str(report.get("reason", "ok")),
			)
			_check(fx.confirmed, "Resolution confirms the petals")
			_check(fx.pull_paths.size() == 3, "Three actual one-cell pulls")
			_check(fx.hit_points.size() == 3, "Three actual local contacts")
			_check(fx.arm_points.size() == 4, "Four arms in the real grid axes")
			_check(hero.current_ap == 1, "Three AP spent")
			casts.append(
				{
					"label": label,
					"upgraded": upgraded,
					"damage": report.get("hp_damage_total", 0),
					"pulls": fx.pull_paths.size(),
					"contacts": fx.hit_points.size(),
				}
			)
			frozen = _combat_values()
		fx.sample(t)
		clock_label.text = "%.2f s · %s · %s" % [
			t,
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
		if frame >= 8:
			_check(
				_combat_values() == frozen,
				"Sampling preserves resolved combat " + label + "/" + str(frame),
			)
	_check(router.echoes.is_empty() and router.flights.is_empty(), "No duplicate generic flight")
	_check(
		router.holds.is_empty() and router.surface_holds.is_empty(),
		"No lingering state or surface",
	)
	fx.cancel()


func _replay() -> void:
	if busy:
		return
	busy = true
	if victims.any(
		func(unit):
			return not unit.is_alive,
	):
		if not await _remount(original_snapshot):
			busy = false
			return
	_labels()
	upgraded = false
	_stage()
	await battle._on_request_cast_spell(Spells.make_spell("t08"), aim_cell)
	await get_tree().create_timer(.8).timeout
	busy = false


func _remount(snapshot: Dictionary) -> bool:
	battle._begin_battle_shutdown()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	_check(router.effects.is_empty(), "Shutdown removes all Convergence sheets")
	original_snapshot = snapshot
	return await _mount()


func _journey() -> void:
	if not await _remount(original_snapshot):
		return
	upgraded = false
	var uid := _stage(false, true)
	var hp := target.current_hp
	await battle._on_request_cast_spell(Spells.make_spell("t08"), aim_cell)
	var deadline := Time.get_ticks_msec() + 8000
	while battle._spell_resolution_pending and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not battle._spell_resolution_pending, "Public command returns control")
	_check(hero.current_ap == 1 and target.current_hp < hp, "Public command spends and hits")
	_check(session.cards.consumed.has(uid), "Public command consumes the copy")
	_check(target.grid_pos == aim_cell + Vector2i.UP, "Public command pulls before hit")
	_check(router.sentence_preparations.is_empty(), "Preparation consumed")
	await get_tree().create_timer(.8).timeout
	_check(not battle._cards_runtime.save_failed, "Production checkpoint committed")
	var snapshot := ExpeditionSaveService.read_snapshot(GameManager.expedition_save_path)
	_check(not snapshot.is_empty(), "Checkpoint readable from disk")
	var saved := _combat_values()
	if not await _remount(snapshot):
		return
	_check(
		_combat_values() == saved,
		"Resume keeps AP, HP, consumed copy and every pulled position",
	)
	_check(session.cards.consumed.has(uid), "Consumed family persists")
	_check(router.effects.is_empty(), "Resume does not replay Convergence")
	await _capture("combat_resumed")
	battle._begin_battle_shutdown()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	GameManager._combat_report_tracker.discard()
	_check(session.combat_won(), "Fixture victory opens actual Cards receipt")
	var path := "user://convergence_receipt.json"
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
		"passed": checks.all(
			func(row):
				return row.ok,
		),
		"frames": captured_frames,
		"checks": checks,
		"casts": casts,
		"note": "Actual current Cards room; AI paused, units repositioned, HP restored to natural maximum for staged clips. Public cast, save/resume, then fixture victory/receipt. Not a played victory or balance test.",
	}
	FileAccess.open(output_path + "report.json", FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	get_tree().quit(0 if report.passed else 1)
