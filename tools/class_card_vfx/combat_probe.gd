extends Node
## Captures real card casts and durable states inside the production battle scene.
const Cards := preload("res://core/expedition/class_card_catalog.gd")
const OUT := "res://artifacts/dev/class_card_vfx/persistence/"
var checks: Array[Dictionary] = []
var battle: Node
var session: ExpeditionSession
var hero: Unit
var target: Unit
var router: Node
var ground_layers: Array[Dictionary] = []


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks.append({ "ok": ok, "check": label })
	if not ok:
		push_error(label)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT + "frames")
	get_window().size = Vector2i(1440, 950)
	get_tree().root.content_scale_size = Vector2i(1440, 950)
	GameManager.cleanup_run_state()
	var run := ExpeditionRunFactory.create(2401, { })
	var resolution := GameManager.resolve_run_hero_data(run, false)
	if (
		not resolution.is_valid()
		or not GameManager._prepare_preconfigured_run(run, resolution.heroes)
	):
		_check(false, "Canonical run initializes")
		_finish()
		return
	session = ExpeditionSession.new()
	GameManager.expedition = session
	session.initialize(GameManager.get_character_state(&"achilles"), 2401)
	session.cards = preload("res://core/expedition/class_cards.gd").new()
	session.cards.bind(session)
	session.needs_preparation = true
	_check(
		session
		.prepare_start(Cards.preset("thaumaturge"), GameManager.run_inventory, GameManager.item_catalog)
		.success,
		"Cards departure initializes",
	)
	_check(session.enter("d01_0"), "Cards combat destination enters")
	var room := ExpeditionRunFactory.make_room(session.route.get_current_node(), 2401, true)
	GameManager.current_room_index = 0
	GameManager.current_wave_index = 0
	GameManager.rooms[0] = room
	get_tree().set_meta(
		&"arena_studio_test_options",
		{
			"active": true,
			"spawn_heroes": true,
			"spawn_enemies": true,
			"deployment_enabled": false,
			"combat_enabled": false,
			"hud_enabled": false,
		},
	)
	battle = room.battle_scene.instantiate()
	add_child(battle)
	get_tree().remove_meta(&"arena_studio_test_options")
	var deadline := Time.get_ticks_msec() + 25000
	while not battle.runtime_ready_state and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(battle.runtime_ready_state, "Production battle is ready")
	hero = session.character.unit
	for unit: Unit in battle.units:
		if unit.team != hero.team:
			target = unit
			break
	router = VFXManager._class_card_router
	_check(router.is_card_battle() and target != null, "Production view binds the Cards router")
	if target == null:
		_finish()
		return
	target.esquive.base_value = 0
	hero.crit_chance.base_value = 0
	var found := false
	for cell in _central_cells():
		if found:
			break
		var other: Vector2i = cell + Vector2i.RIGHT
		if (
			battle.grid.is_walkable(cell) and battle.grid.is_walkable(other)
			and not battle.grid.has_unit(cell) and not battle.grid.has_unit(other)
		):
			_move(hero, cell)
			_move(target, other)
			found = true
	_check(found, "Preview pair occupies valid neighboring production tiles")
	await get_tree().create_timer(.3).timeout
	await _capture("before")
	# Native camera close-up for inspecting narrow translucent currents.
	battle.camera.zoom *= 2.4
	battle.camera.global_position = (
		battle._unit_views[hero].global_position + battle._unit_views[target].global_position
	) * .5 + Vector2(0, -35)
	await get_tree().process_frame
	for id in ["g_guard", "a_open", "a_cut", "t_burn", "g_prison", "t_disrupt"]:
		_cast(id, hero.grid_pos if id == "g_guard" else target.grid_pos)
	await get_tree().create_timer(1.8).timeout
	_check(router.holds.size() >= 6, "Shield and all five actual card statuses have durable VFX")
	var frozen_state := _state()
	for frame in 60:
		for hold in router.holds.values():
			hold.fx.manual = true
			hold.fx.sample(3.0 + frame / 30.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + "frames/%03d.png" % frame)
	_check(
		_state() == frozen_state,
		"Two seconds of VFX playback do not change HP or state durations",
	)
	await _capture("durable_states")
	_cast("t_flamewall", target.grid_pos)
	await get_tree().create_timer(1.8).timeout
	_check(router.surface_holds.size() > 0, "Actual fire-field card maintains its ground overlay")
	_check(_ground_order_correct(), "Ethereal ground draws above the actual surface tiles")
	await _capture("fire_ground")
	var ice_cell: Vector2i = target.grid_pos + Vector2i(0, 2)
	_cast("t_glacier", ice_cell)
	await get_tree().create_timer(1.8).timeout
	await _capture("fire_and_ice_ground")
	_check(_ground_order_correct(), "Reactions preserve ground overlay ordering")
	for state in target.get_active_statuses().duplicate():
		target.remove_status(state.data.get_effective_status_id())
	hero.clear_shield()
	# Fire/ice may create a steam residue with a different authored duration.
	for turn in 8:
		if battle.terrain_effects.active_surface_cells().is_empty():
			break
		battle.terrain_effects.tick_all_effects()
	await get_tree().create_timer(.8).timeout
	_check(
		router.holds.is_empty() and router.surface_holds.is_empty(),
		"Removed states and expired fields leave no durable VFX",
	)
	await _capture("expired")
	_finish()


func _central_cells() -> Array:
	var cells: Array = []
	for y in range(2, battle.grid.rows - 2):
		for x in range(2, battle.grid.cols - 2):
			cells.append(Vector2i(x, y))
	var center := Vector2(battle.grid.cols, battle.grid.rows) * .5
	cells.sort_custom(
		func(a, b):
			return Vector2(a).distance_squared_to(center) < Vector2(b).distance_squared_to(center),
	)
	return cells


func _move(unit: Unit, cell: Vector2i) -> void:
	_check(battle.grid.relocate_unit(unit, cell), "Actor relocation uses the battle grid")
	var view: Node2D = battle._unit_views[unit]
	view.position = battle.grid_cell_to_parent_local(cell, view.get_parent())


func _cast(id: String, cell: Vector2i) -> void:
	hero.current_ap = hero.max_ap.get_int()
	target.current_hp = target.max_hp.get_int()
	session.cards.hand.assign([session.cards.add_copy(id)])
	var report: Dictionary = battle.spell_caster.cast(hero, Cards.make_spell(id), cell)
	_check(
		not report.get("failed", false),
		"Real cast " + id + ": " + str(report.get("reason", "ok")),
	)


func _state() -> Array:
	var values: Array = [hero.current_hp, target.current_hp, hero.current_shield]
	for state in target.get_active_statuses():
		values.append([str(state.data.get_effective_status_id()), state.remaining])
	return values


func _ground_order_correct() -> bool:
	var valid: bool = not router.surface_holds.is_empty()
	for cell in router.surface_holds:
		var overlay: Node = router.surface_holds[cell]
		var base: Node = battle.terrain_surface_visual_adapter.node_for_cell(cell)
		var visual_id: StringName = battle.terrain_effects.get_visual_terrain_id(cell)
		var expects_base := bool(TerrainSurfaceVisualResolver.resolve(visual_id).get("ok", false))
		var above := (
			not expects_base
			if base == null
			else (
				overlay.get_parent() == base.get_parent() and overlay.get_index() > base.get_index()
			)
		)
		ground_layers.append(
			{
				"cell": str(cell),
				"visual_id": str(visual_id),
				"expects_base": expects_base,
				"base_index": base.get_index() if base != null else -1,
				"overlay_index": overlay.get_index(),
				"above": above,
			}
		)
		valid = valid and above
	return valid


func _capture(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(OUT + label + ".png") == OK, "Captured "
		+ label)


func _finish() -> void:
	if is_instance_valid(battle):
		battle._begin_battle_shutdown()
		battle.queue_free()
	GameManager.cleanup_run_state()
	var report := {
		"passed": checks.all(
			func(row):
				return row.ok,
		),
		"checks": checks,
		"renderer": RenderingServer.get_current_rendering_method(),
		"frames": 60,
		"ground_layers": ground_layers,
		"note": "Production arena and SpellCaster; AI paused by Studio direct-test configuration. Actors positioned, hand prepared, native camera enlarged 2.4x for the visual scenario.",
	}
	FileAccess.open(OUT + "report.json", FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if report.passed else 1)
