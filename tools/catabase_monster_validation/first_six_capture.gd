extends "res://tools/catabase_monster_validation/challenge_capture.gd"


func _ready() -> void:
	output = "res://artifacts/dev/first_six_capture"
	super._ready()


func _run() -> void:
	var guard := GameManager.get_expedition_replacement_guard()
	if bool(guard.get("exists", false)):
		GameManager.confirm_expedition_replacement(str(guard.token))
	if not GameManager.start_expedition(2401, { }, true, true):
		await _finish(false)
		return
	var deadline := Time.get_ticks_msec() + 90000
	var departure_done := false
	var thrown := false
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if scene is ExpeditionScreen and not departure_done:
			await _capture("01_preparation")
			var preset: Button = scene.find_child("Preset_disque", true, false)
			if preset == null:
				break
			preset.pressed.emit()
			var confirm: Button = scene.find_child("ConfirmCatabaseDeparture", true, false)
			var parent := confirm.get_parent()
			while parent != null and not parent is ScrollContainer:
				parent = parent.get_parent()
			if parent != null:
				await get_tree().process_frame
				parent.scroll_vertical = int(parent.get_v_scroll_bar().max_value)
			await _capture("02_disque_confirmation")
			confirm.pressed.emit()
			departure_done = true
			continue
		if scene == null or scene is ExpeditionScreen or not bool(scene.get("runtime_ready_state")):
			continue
		if scene._deployment != null and scene._deployment.is_active():
			scene._deployment.on_cell_clicked(GameManager.get_current_room().hero_spawn_zone[0])
			continue
		if is_instance_valid(scene._challenge_battle):
			var dialog = scene._challenge_battle.layer.get_node_or_null("ChallengeDialog")
			if dialog != null:
				dialog.find_child("Challenge_seal", true, false).pressed.emit()
				continue
		if not scene._can_accept_player_intent():
			continue
		var hero: Unit = scene.get_active_unit()
		if hero == null or hero.team != 0:
			continue
		if not thrown:
			await _capture("03_disque_combat")
			var spell: Spell = GameManager.expedition.build.catalog.get_spell("exp_ct_lancer")
			var target := Vector2i(-1, -1)
			for cell: Vector2i in [
				hero.grid_pos + Vector2i(2, 0),
				hero.grid_pos + Vector2i(0, 2),
				hero.grid_pos + Vector2i(-2, 0),
			]:
				if scene.spell_caster.can_cast(hero, spell, cell):
					target = cell
					break
			if target.x < 0:
				break
			scene._on_spell_pressed(spell)
			scene._on_cell_clicked(target)
			thrown = true
		elif hero.has_meta("ct_disc"):
			await _capture("04_disque_au_sol")
			var spell: Spell = GameManager.expedition.build.catalog.get_spell("exp_ct_retour")
			scene._on_spell_pressed(spell)
			scene._on_cell_clicked(hero.grid_pos)
			for frame in 90:
				await get_tree().process_frame
			await _capture("05_disque_recupere")
			var success := not hero.has_meta("ct_disc") and hero.current_ap == 1
			FileAccess.open(output.path_join("report.json"), FileAccess.WRITE).store_string(
				JSON.stringify(
					{
						"success": success,
						"ap": hero.current_ap,
						"preparation": GameManager.expedition.build.starting_selection,
						"scope": "Actual departure UI, deployment, challenge, HUD throw and return",
					},
					"\t",
				)
			)
			await _finish(success)
			return
	await _finish(false)
