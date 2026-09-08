extends Node
## Production route rooms and Battle/EnemyTurnRunner, with explicitly positioned
## combat fixtures. This does not claim a played full-run victory or balance proof.

const SLUGS := ["sentinelle_airain", "rejeton_braise", "molosse_styx", "lamie_lethe"]
const SEED := 2401
const Cleanup := preload("res://test/support/isolated_battlefield_cleanup.gd")
var _resolution := Vector2i(1280, 720)
var _output := ""
var _errors: Array[String] = []
var _checks := 0
var _rooms: Array[Dictionary] = []
var _captures: Array[String] = []
var _observed: Dictionary = {}
var _active_views: Dictionary = {}
var _capture_pending := {}
var _capture_jobs := 0
var _finished := false
var _teardown_refs: Array[Dictionary] = []


func _ready() -> void:
	if "parse_only" in OS.get_cmdline_user_args():
		print("CATABASE_MONSTER_PROBE_PARSE=PASS")
		get_tree().quit(0)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("resolution="):
			var dimensions := argument.trim_prefix("resolution=").split("x")
			if dimensions.size() == 2:
				_resolution = Vector2i(int(dimensions[0]), int(dimensions[1]))
	_output = ProjectSettings.globalize_path("res://artifacts/catabase_monsters/%dx%d" % [_resolution.x, _resolution.y])
	DirAccess.make_dir_recursive_absolute(_output)
	get_window().size = _resolution
	get_tree().create_timer(180.0).timeout.connect(_watchdog)
	_run.call_deferred()


func _process(_delta: float) -> void:
	for slug: String in _active_views:
		if not is_instance_valid(_active_views[slug]): continue
		var sprite := _active_views[slug] as AnimatedSprite2D
		var key := "%s:%d" % [sprite.animation, sprite.frame]
		var samples: Array = _observed.get(slug, [])
		if not samples.has(key): samples.append(key)
		_observed[slug] = samples
		var action := str(sprite.animation).get_slice("_", 0)
		if action in ["walk", "attack", "cast", "death"] and sprite.frame >= 1:
			var label := slug + "_" + action
			if not _capture_pending.has(label) and not _captures.has(label):
				_capture_pending[label] = true
				_capture(label)


func _run() -> void:
	GameManager.expedition_save_path = _output.path_join("isolated_probe_save.json")
	GameManager.set_reduced_motion_enabled(false)
	var selections := _select_rooms()
	if "cleanup_only" in OS.get_cmdline_user_args():
		await _probe_room(SLUGS[0], selections[SLUGS[0]])
		for frame in 4: await get_tree().process_frame
		_verify_teardown()
		_finished = true
		get_tree().quit(0 if _errors.is_empty() else 1)
		return
	for slug: String in SLUGS:
		_check(selections.has(slug), slug + ": production route contains monster")
		if not selections.has(slug): continue
		await _probe_room(slug, selections[slug])
	await _finish()


func _select_rooms() -> Dictionary:
	var result := {}
	for node: Dictionary in ExpeditionRouteCatalog.create_nodes(SEED):
		if not ExpeditionRouteCatalog.is_combat(str(node.kind)): continue
		var room := ExpeditionRunFactory.make_room(node, SEED)
		for data: UnitData in room.enemies:
			var slug := str(data.unit_id).trim_prefix("catabase_")
			if slug in SLUGS and not result.has(slug):
				result[slug] = node.duplicate(true)
	return result


func _probe_room(slug: String, route_node: Dictionary) -> void:
	var room := ExpeditionRunFactory.make_room(route_node, SEED)
	var run := ExpeditionRunFactory.create(SEED, {"achilles": "painted_g"})
	run.rooms = [room]
	var resolution = GameManager.resolve_run_hero_data(run, false)
	_check(resolution.is_valid(), slug + ": canonical hero resolution")
	if not resolution.is_valid(): return
	_check(GameManager._prepare_preconfigured_run(run, resolution.heroes), slug + ": runtime preparation")
	var build := ExpeditionBuildState.new()
	_check(build.initialize(GameManager.get_character_state(&"achilles")), slug + ": canonical spell kit")
	GameManager.current_room_index = 0
	var battle := room.battle_scene.instantiate()
	add_child(battle)
	var deadline := Time.get_ticks_msec() + 25000
	while not bool(battle.get("runtime_ready_state")) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(bool(battle.get("runtime_ready_state")), slug + ": Battle ready")
	if not bool(battle.get("runtime_ready_state")):
		await _close_battle(battle)
		return
	if "cleanup_only" in OS.get_cmdline_user_args():
		await _close_battle(battle)
		return
	var grid := battle.get("grid") as GridData
	var units: Array = battle.get("units")
	var hero: Unit = GameManager.heroes[0]
	var enemy: Unit = null
	var spawns: Array[Dictionary] = []
	var formation: Dictionary = battle.get("encounter_formation_snapshot")
	_check(bool(formation.get("valid", false)), slug + ": role-distance formation is valid")
	var occupied := {}
	for unit: Unit in units:
		if unit.team == 0: continue
		_check(grid.is_walkable(unit.grid_pos, unit), slug + ": enemy occupies legal floor")
		_check(not occupied.has(unit.grid_pos), slug + ": unique enemy cell")
		occupied[unit.grid_pos] = true
		var matches_plan := false
		for placement: Dictionary in formation.get("placements", []):
			var planned := placement.get("unit_data") as UnitData
			if planned != null and planned.unit_id == unit.unit_id and placement.cell == unit.grid_pos:
				matches_plan = true
		_check(matches_plan, slug + ": actual cell matches role-distance spawn plan")
		spawns.append({"id": str(unit.unit_id), "cell": _cell(unit.grid_pos), "hp": unit.current_hp,
			"ap": unit.current_ap, "mp": unit.current_mp, "initiative": unit.get_initiative(),
			"in_preferred_spawn_zone": room.enemy_spawn_zone.has(unit.grid_pos)})
		if str(unit.unit_id) == "catabase_" + slug: enemy = unit
	_check(enemy != null, slug + ": actual monster unit spawned")
	if enemy == null:
		await _close_battle(battle)
		return
	var view = battle.get("_unit_views").get(enemy)
	var visual: Node2D = view.get_optional_visual() if is_instance_valid(view) else null
	_check(visual != null, slug + ": actual UnitView has custom painted visual")
	if visual == null:
		await _close_battle(battle)
		return
	var sprites := visual.find_children("*", "AnimatedSprite2D", true, false)
	_check(sprites.size() == 1, slug + ": exactly one visible animated sprite")
	if sprites.size() != 1:
		await _close_battle(battle)
		return
	var sprite := sprites[0] as AnimatedSprite2D
	_active_views[slug] = sprite
	_check(not sprite.flip_h and not sprite.flip_v, slug + ": explicit direction, no reflection")
	_check(sprite.sprite_frames != null and sprite.sprite_frames.get_animation_names().size() >= 24,
		slug + ": imported action sheets bound")
	var deployment = battle.get("_deployment")
	_check(deployment != null and deployment.is_active(), slug + ": real deployment active")
	if deployment != null and deployment.is_active():
		deployment.on_cell_clicked(room.hero_spawn_zone[0])
	deadline = Time.get_ticks_msec() + 10000
	while not bool(battle.call("_can_accept_player_intent")) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(bool(battle.call("_can_accept_player_intent")), slug + ": controllable battle after deployment")
	await _wait_for_intro(battle, slug)
	await _capture(slug + "_authored_encounter")
	var runner := battle.get("_enemy_turn") as EnemyTurnRunner
	enemy.start_turn()
	var position_before := enemy.grid_pos
	var mp_before := enemy.current_mp
	var hp_before_ai := hero.current_hp
	await runner.run(enemy)
	var ai_report := {"from": _cell(position_before), "to": _cell(enemy.grid_pos),
		"mp_before": mp_before, "mp_after": enemy.current_mp,
		"hero_hp_before": hp_before_ai, "hero_hp_after": hero.current_hp,
		"actions": runner.last_action_count}
	_check(runner.last_action_count > 0, slug + ": real EnemyTurnRunner executes AI plan")
	var casts: Array[Dictionary] = []
	for spell: Spell in enemy.spells:
		casts.append(await _exercise_cast(battle, runner, enemy, hero, spell, slug))
	var observed: Array = _observed.get(slug, [])
	_check(observed.any(func(key): return str(key).begins_with("attack_")), slug + ": real attack animation observed")
	_check(observed.any(func(key): return str(key).begins_with("cast_")), slug + ": real cast animation observed")
	_check(observed.any(func(key): return str(key).begins_with("walk_")), slug + ": real walk animation observed")
	var anchor: Vector2 = visual.get_logical_foot_position()
	_check(anchor.is_zero_approx(), slug + ": visual foot remains at logical cell pivot")
	await _capture(slug + "_resolved_combat")
	var lethal_report := await _exercise_lethal_hit(battle, enemy, hero, slug)
	_check(observed.any(func(key): return str(key).begins_with("death_")), slug + ": real lethal-hit death animation")
	_rooms.append({"monster": slug, "route_node": route_node, "scene": room.battle_scene.resource_path,
		"room_name": room.room_name, "spawns": spawns, "ai": ai_report, "casts": casts,
		"animations": observed, "lethal_hit": lethal_report,
		"fixture": "Seeded authored encounter; hero deployment is real. Extra spell probes position the existing hero on a legal target cell and advance the existing enemy activation to exercise each ability through EnemyTurnRunner. The final death fixture lowers enemy HP to one before a legal real hero spear impact."})
	_active_views.erase(slug)
	await _close_battle(battle)


func _exercise_cast(battle: Node, runner: EnemyTurnRunner, enemy: Unit, hero: Unit,
		spell: Spell, slug: String) -> Dictionary:
	var grid := battle.get("grid") as GridData
	var caster := battle.get("spell_caster") as SpellCaster
	for activation in range(4): enemy.start_turn()
	var origin := hero.grid_pos
	var target_cell := Vector2i(-1, -1)
	for y in grid.rows:
		for x in grid.cols:
			var candidate := Vector2i(x, y)
			if candidate == enemy.grid_pos or not grid.is_walkable(candidate, hero): continue
			if grid.has_unit(candidate) and grid.get_unit(candidate) != hero: continue
			var previous := hero.grid_pos
			if not grid.relocate_unit(hero, candidate): continue
			if caster.can_cast(enemy, spell, candidate):
				target_cell = candidate
				break
			grid.relocate_unit(hero, previous)
		if target_cell.x >= 0: break
	_check(target_cell.x >= 0, slug + ": legal target for " + str(spell.spell_id))
	if target_cell.x < 0: return {"spell": str(spell.spell_id), "error": "no_legal_target"}
	var hero_view = battle.get("_unit_views").get(hero)
	hero_view.position = battle.call("grid_cell_to_parent_local", hero.grid_pos, hero_view.get_parent())
	hero_view.synchronize_external_movement()
	var hp_before := hero.current_hp
	var ap_before := enemy.current_ap
	var uses_before := enemy.get_spell_uses(spell)
	var legal_before := caster.can_cast(enemy, spell, hero.grid_pos)
	await runner._execute_cast(enemy, spell, hero.grid_pos)
	var report := {"spell": str(spell.spell_id), "legal": legal_before, "fixture_hero_from": _cell(origin),
		"target": _cell(target_cell), "hp_before": hp_before, "hp_after_telegraph": hero.current_hp,
		"ap_before": ap_before, "ap_after": enemy.current_ap, "uses_before": uses_before,
		"uses_after": enemy.get_spell_uses(spell)}
	_check(enemy.current_ap == ap_before - spell.ap_cost, slug + ": spell AP cost paid")
	_check(enemy.get_spell_uses(spell) == uses_before + 1, slug + ": exactly one spell release")
	if spell.is_delayed():
		_check(hero.current_hp == hp_before, slug + ": telegraph gives warning before damage")
		enemy.start_turn()
		report["delayed_resolution"] = await battle.call("_resolve_pending_ability", enemy)
	_check(hero.current_hp < hp_before, slug + ": real spell damage")
	var status_ids: Array[String] = []
	for entry: Dictionary in hero.get_active_statuses():
		var status := entry.get("data") as StatusData
		if status != null: status_ids.append(str(status.get_effective_status_id()))
	if spell.applied_status != null:
		_check(status_ids.has(str(spell.applied_status.get_effective_status_id())), slug + ": actual target status")
	report["hp_after"] = hero.current_hp
	report["statuses"] = status_ids
	report["target_after"] = _cell(hero.grid_pos)
	await get_tree().create_timer(0.2).timeout
	return report


func _exercise_lethal_hit(battle: Node, enemy: Unit, hero: Unit, slug: String) -> Dictionary:
	var caster := battle.get("spell_caster") as SpellCaster
	var grid := battle.get("grid") as GridData
	var spear: Spell = null
	for spell: Spell in hero.spells:
		if spell.get_effective_spell_id() == &"achilles_peleid_strike": spear = spell
	_check(spear != null, slug + ": canonical spear for lethal fixture")
	if spear == null: return {"error": "canonical_spear_missing"}
	hero.start_turn()
	await _wait_for_intro(battle, slug + ": lethal fixture")
	var found := false
	for y in grid.rows:
		for x in grid.cols:
			var candidate := Vector2i(x, y)
			if not grid.is_walkable(candidate, hero): continue
			if grid.has_unit(candidate) and grid.get_unit(candidate) != hero: continue
			var previous := hero.grid_pos
			if not grid.relocate_unit(hero, candidate): continue
			if caster.can_cast(hero, spear, enemy.grid_pos):
				found = true
				break
			grid.relocate_unit(hero, previous)
		if found: break
	_check(found, slug + ": legal real hero attack")
	if not found: return {"error": "no_legal_spear_target"}
	var hero_view = battle.get("_unit_views").get(hero)
	hero_view.position = battle.call("grid_cell_to_parent_local", hero.grid_pos, hero_view.get_parent())
	hero_view.synchronize_external_movement()
	enemy.current_hp = 1 # Explicit lethal fixture; the spell causes actual death.
	var ap_before := hero.current_ap
	var report := caster.cast(hero, spear, enemy.grid_pos)
	_check(not enemy.is_alive, slug + ": real spell triggers monster death")
	_check(hero.current_ap == ap_before - spear.ap_cost, slug + ": lethal cast pays real cost")
	await get_tree().create_timer(0.8).timeout
	return {"spell": str(spear.spell_id), "hp_fixture": 1, "alive_after": enemy.is_alive,
		"ap_before": ap_before, "ap_after": hero.current_ap, "cast_failed": bool(report.get("failed", false))}


func _close_battle(battle: Node) -> void:
	var fixture_grid := battle.get("grid") as GridData
	var fixture_terrain := battle.get("terrain_effects") as TerrainEffects
	_teardown_refs.append({"kind": "grid", "id": fixture_grid.get_instance_id(), "ref": weakref(fixture_grid)})
	_teardown_refs.append({"kind": "terrain", "id": fixture_terrain.get_instance_id(), "ref": weakref(fixture_terrain)})
	_teardown_refs.append({"kind": "service", "id": fixture_terrain.runtime_service.get_instance_id(), "ref": weakref(fixture_terrain.runtime_service)})
	battle.queue_free()
	for frame in 6: await get_tree().process_frame
	if fixture_grid != null:
		Cleanup.dispose_grid(fixture_grid)
	# The scene can disconnect grid listeners before this fixture teardown.
	# Retain the facade explicitly so its relay cycle is always released.
	if fixture_terrain != null:
		var service := fixture_terrain.runtime_service
		if service != null:
			for declaration: Dictionary in service.get_signal_list():
				var relay := Signal(service, StringName(declaration.name))
				for connection: Dictionary in relay.get_connections():
					relay.disconnect(connection.callable)
			service.grid = null
		fixture_terrain.runtime_service = null
		fixture_terrain._grid = null
	GameManager.cleanup_run_state()
	for frame in 3: await get_tree().process_frame


func _wait_for_intro(battle: Node, label: String) -> void:
	var intro: CharacterTurnIntroBanner = battle.get("action_bar").get_turn_intro_banner()
	var deadline := Time.get_ticks_msec() + 4000
	while intro.visible and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not intro.visible, label + ": turn introduction completes before capture")


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	_capture_jobs += 1
	await RenderingServer.frame_post_draw
	var screenshot := get_viewport().get_texture().get_image()
	_check(screenshot != null and not screenshot.is_empty(), "GPU screenshot: " + label)
	if screenshot != null and not screenshot.is_empty():
		_check(screenshot.get_size() == _resolution, "Actual capture resolution: " + label)
		_check(screenshot.save_png(_output.path_join(label + ".png")) == OK, "PNG saved: " + label)
		_captures.append(label)
	_capture_jobs -= 1


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition: _errors.append(label)


func _cell(value: Vector2i) -> Array[int]:
	return [value.x, value.y]


func _watchdog() -> void:
	if _finished: return
	_errors.append("Probe exceeded 180 seconds")
	_write_report()
	get_tree().quit(1)


func _write_report() -> void:
	var report := {"passed": _errors.is_empty(), "checks": _checks, "errors": _errors,
		"resolution": _cell(_resolution), "engine": Engine.get_version_info(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"capture_enabled": DisplayServer.get_name() != "headless", "captures": _captures,
		"encounters": _rooms, "scope": "Four actual route encounter fixtures, real EnemyTurnRunner AI, legal spell casts and resource spending. No full-run balance claim."}
	var file := FileAccess.open(_output.path_join("report.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t"))
	print("CATABASE_MONSTER_RUNTIME=" + JSON.stringify(report))


func _finish() -> void:
	# Let the last completed coroutine release its local fixture references.
	for frame in 4: await get_tree().process_frame
	var deadline := Time.get_ticks_msec() + 3000
	while _capture_jobs > 0 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(_rooms.size() == 4, "All four real monster rooms exercised")
	_verify_teardown()
	if DisplayServer.get_name() != "headless":
		for slug: String in SLUGS:
			for suffix: String in ["authored_encounter", "attack", "cast", "death", "resolved_combat"]:
				_check(_captures.has(slug + "_" + suffix), slug + ": required capture " + suffix)
	_finished = true
	_write_report()
	get_tree().quit(0 if _errors.is_empty() else 1)


func _verify_teardown() -> void:
	for entry: Dictionary in _teardown_refs:
		var released: bool = entry.ref.get_ref() == null
		print("CATABASE_MONSTER_TEARDOWN=", entry.kind, ":", entry.id, ":released=", released)
		_check(released, "Fixture reference released: " + str(entry.kind))
