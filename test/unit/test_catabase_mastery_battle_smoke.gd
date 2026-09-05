extends GutTest

## Real Map0, deployment controller, HUD intent routes, cast animations, terrain,
## and turn queue. Fixture placement/stat padding only keeps the smoke deterministic.
var battle
var hero: Unit

func after_each() -> void:
	if is_instance_valid(battle):
		battle.free()
	battle = null
	GameManager.cleanup_run_state()

func test_real_map0_guard_dash_strike_and_next_activation_complete_without_input_lock() -> void:
	GameManager.cleanup_run_state()
	GameManager.set_reduced_motion_enabled(true)
	var run := RunData.new()
	run.run_name = "Catabase Map0 smoke"
	run.content_profile = load("res://data/runs/profiles/odyssey_content_profile.tres")
	run.economy_profile = load("res://data/runs/economy/odyssey_economy_profile.tres")
	var room := load("res://data/rooms/odyssey/room_01.tres") as RoomData
	run.rooms = [room]
	var resolution := GameManager.resolve_run_hero_data(run)
	assert_true(GameManager._prepare_preconfigured_run(run, resolution.heroes))
	GameManager.current_room_index = 0
	hero = GameManager.get_ordered_character_states()[0].unit
	hero.initiative.base_value = 100
	hero.max_hp.base_value = 1000
	hero.current_hp = 1000
	hero.crit_chance.base_value = 0
	hero.esquive.base_value = 0
	var catalog := load("res://data/characters/achilles/doctrines/achilles_mastery_catalog.tres") as MasteryCatalogData
	var nodes: Array[SkillTreeNodeData] = []
	for id in [&"achilles_aeacus_directional_guard", &"achilles_aeacus_mobile_bastion"]:
		nodes.append(catalog.node_catalog()[id].duplicate(true) as SkillTreeNodeData)
	hero.mastery_nodes.assign(nodes)
	hero.set_progression_spell_modifiers_by_spell(MasteryStaticModifierResolver.modifiers_by_spell(nodes))
	assert_true(hero.mastery_runtime.configure_from_nodes(nodes).is_empty())
	battle = room.battle_scene.instantiate()
	battle.room_data = room
	add_child(battle)
	assert_true(await _until(func(): return bool(battle.runtime_ready_state)), "Map0 runtime ready")
	assert_not_null(battle._deployment)
	for cell in battle._deployment.get("_deploy_zone"):
		if battle.grid.is_walkable(cell):
			battle._on_cell_clicked(cell)
			break
	assert_true(await _until(func(): return battle.get_active_unit() == hero and battle._can_accept_player_intent()), "Real turn queue starts hero")
	assert_eq(hero.mastery_combat_adapter, battle._mastery_adapter)
	assert_not_null(battle._hud_port)
	var enemies: Array = battle.units.filter(func(unit): return unit.team == 1)
	assert_gte(enemies.size(), 1)
	var line := _find_empty_line()
	assert_eq(line.size(), 3, "Map0 supplies three legal cells before a wall")
	if line.size() != 3:
		return
	for enemy in enemies:
		enemy.max_hp.base_value = 1000
		enemy.current_hp = 1000
		enemy.crit_chance.base_value = 0
		enemy.esquive.base_value = 0
	assert_true(battle.grid.relocate_unit(hero, line[0]))
	assert_true(battle.grid.relocate_unit(enemies[0], line[2]))
	for unit in [hero, enemies[0]]:
		var view = battle._unit_views[unit]
		view.position = battle.grid_cell_to_parent_local(unit.grid_pos, view.get_parent())
	var guard := _spell(&"achilles_bronze_guard")
	battle._on_spell_pressed(guard)
	battle._on_cell_clicked(hero.grid_pos)
	assert_true(await _until(func(): return battle._mastery_panel.is_open()), "Native facing prompt")
	assert_eq(hero.current_ap, 6, "Facing prompt spends no AP")
	battle._on_mastery_option(&"east")
	assert_true(await _until(func(): return not battle._spell_resolution_pending and hero.current_ap == 4), "Guard completes")
	assert_gt(hero.get_shield_value(&"achilles_bronze_guard"), 0)
	assert_eq(hero.facing_dir, Vector2i.RIGHT)
	var guard_before := hero.current_shield
	var dash := _spell(&"achilles_fulminant_dash")
	battle._on_spell_pressed(dash)
	battle._on_cell_clicked(line[1])
	assert_true(await _until(func(): return not battle._spell_resolution_pending and hero.grid_pos == line[1]), "Native dash reaches its legal cell")
	assert_eq(hero.current_ap, 3)
	assert_lt(hero.current_shield, guard_before, "Bastion consumes its own guard source")
	assert_lt(enemies[0].current_hp, 1000, "Bastion impact resolved")
	var before: int = enemies[0].current_hp
	var strike := _spell(&"achilles_peleid_strike")
	battle._on_spell_pressed(strike)
	battle._on_cell_hovered(line[2])
	assert_true(battle.grid_view.get_highlight_snapshot().has(line[2]), "Real strike cell is previewed")
	battle._on_cell_clicked(line[2])
	assert_true(await _until(func(): return not battle._spell_resolution_pending and hero.current_ap == 0), "Strike animation and impact complete")
	assert_lt(enemies[0].current_hp, before)
	assert_true(battle._can_accept_player_intent(), "HUD recovers after the final manual cast")
	var activation := hero.activation_index
	assert_true(battle._finish_active_turn(&"smoke_completed"))
	assert_true(await _until(func(): return hero.activation_index > activation and battle.get_active_unit() == hero and battle._can_accept_player_intent(), 20000), "Enemy turn and next hero activation finish")
	assert_eq(hero.get_shield_value(&"achilles_bronze_guard"), 0, "Guard expires at its owner's next activation")
	assert_false(battle._mastery_panel.is_open())
	assert_eq(hero.current_ap, hero.max_ap.get_int())

func _spell(id: StringName) -> Spell:
	for value in hero.spells:
		var spell := value as Spell
		if spell.get_effective_spell_id() == id:
			return spell
	return null

func _find_empty_line() -> Array:
	for y in battle.grid.rows:
		for x in range(battle.grid.cols - 2):
			var cells: Array = []
			for offset in 3:
				var cell := Vector2i(x + offset, y)
				if battle.grid.is_walkable(cell) and battle.grid.get_type(cell) == GridData.CellType.NORMAL:
					cells.append(cell)
			if cells.size() == 3 and not battle.grid.is_walkable(Vector2i(x + 3, y)):
				return cells
	return []

func _until(predicate: Callable, timeout_ms: int = 12000) -> bool:
	var end := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < end:
		if predicate.call():
			return true
		await get_tree().process_frame
	return false
