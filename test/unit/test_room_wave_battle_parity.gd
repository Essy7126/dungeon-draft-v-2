extends GutTest

const FIRST_RUN: RunData = preload("res://data/runs/run_default.tres")


func before_each() -> void:
	GameManager.cleanup_run_state()
	assert_true(GameManager._prepare_preconfigured_run(
		FIRST_RUN,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	))
	GameManager.current_room_index = 0


func after_each() -> void:
	GameManager.cleanup_run_state()


func test_every_room_keeps_its_complete_launch_contract_across_all_waves() -> void:
	for room_index in range(FIRST_RUN.rooms.size()):
		var room := FIRST_RUN.rooms[room_index]
		var snapshots: Array[Dictionary] = []
		for wave_index in range(room.get_wave_count()):
			GameManager.current_room_index = room_index
			GameManager.current_wave_index = wave_index
			var context := "%s, vague %d" % [room.room_name, wave_index + 1]
			var battle = room.battle_scene.instantiate()
			add_child(battle)
			await get_tree().process_frame
			await get_tree().process_frame

			assert_not_null(battle.grid, "Grille : " + context)
			assert_not_null(battle.grid_view, "Vue : " + context)
			assert_not_null(battle.inspect_panel, "Inspection : " + context)
			assert_true(battle.inspect_panel.visible, "Inspection visible : " + context)
			assert_not_null(battle.player_combat_log, "Journal : " + context)
			assert_true(battle.player_combat_log.visible, "Journal visible : " + context)
			assert_not_null(battle.keyword_tooltip_layer, "Infobulles : " + context)
			assert_not_null(battle.action_bar, "HUD : " + context)
			assert_not_null(battle._deployment, "Deploiement : " + context)
			assert_true(battle._deployment.is_active(), "Deploiement actif : " + context)
			assert_true(
				battle.grid_view.cell_hovered.is_connected(battle._on_cell_hovered),
				"Survol connecte : " + context,
			)
			assert_true(
				battle.grid_view.cell_clicked.is_connected(battle._on_cell_clicked),
				"Clic connecte : " + context,
			)

			var enemies: Array = battle.units.filter(func(unit): return unit.team == 1)
			assert_false(enemies.is_empty(), "Ennemis : " + context)
			var inspected_enemy = enemies[0]
			battle._on_cell_hovered(inspected_enemy.grid_pos)
			assert_eq(battle.inspect_panel._displayed_unit, inspected_enemy, context)
			assert_eq(battle.inspect_panel._title.text, inspected_enemy.unit_name, context)
			assert_true(
				_inspection_contains_health(battle.inspect_panel, inspected_enemy),
				"PV inspectes : " + context,
			)

			snapshots.append({
				"enemy_count": enemies.size(),
				"unit_view_count": battle._unit_views.size(),
				"grid_size": Vector2i(battle.grid.cols, battle.grid.rows),
				"inspect_visible": battle.inspect_panel.visible,
				"combat_log_visible": battle.player_combat_log.visible,
				"hover_connected": battle.grid_view.cell_hovered.is_connected(
					battle._on_cell_hovered
				),
				"click_connected": battle.grid_view.cell_clicked.is_connected(
					battle._on_cell_clicked
				),
			})

			battle.free()
			await get_tree().process_frame

		for wave_index in range(1, snapshots.size()):
			assert_eq(snapshots[wave_index], snapshots[0], room.room_name)


func _inspection_contains_health(panel: CanvasLayer, enemy: Unit) -> bool:
	var expected := "%d / %d" % [enemy.current_hp, enemy.max_hp.get_int()]
	for child in panel._content.get_children():
		if child is RichTextLabel and expected in child.get_parsed_text():
			return true
	return false
