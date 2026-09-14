extends Node
## Exercise real normal-loadout UI after removing the deck. Isolated checkpoint.
var output := "res://artifacts/dev/challenge_capture"
var phase := 0
var initial_spells: Array = []
var initial_ap := 0
var frames_after_cast := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	GameManager.expedition_save_path = output.path_join("checkpoint.json")
	GameManager.set_reduced_motion_enabled(true)
	get_tree().current_scene = null
	_run.call_deferred()


func _run() -> void:
	var guard := GameManager.get_expedition_replacement_guard()
	if bool(guard.get("exists", false)):
		GameManager.confirm_expedition_replacement(str(guard.token))
	if not GameManager.start_expedition(2401, { }, true):
		get_tree().quit(1)
		return
	var deadline := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var battle := get_tree().current_scene
		if battle == null or not bool(battle.get("runtime_ready_state")):
			continue
		if battle._deployment != null and battle._deployment.is_active():
			battle._deployment.on_cell_clicked(GameManager.get_current_room().hero_spawn_zone[0])
			continue
		if not is_instance_valid(battle._challenge_battle):
			continue
		var controller = battle._challenge_battle
		var dialog = controller.layer.get_node_or_null("ChallengeDialog")
		if dialog != null:
			await _capture("01_challenge")
			dialog.find_child("Challenge_seal", true, false).pressed.emit()
			continue
		if not battle._can_accept_player_intent():
			continue
		var hero: Unit = battle.get_active_unit()
		if hero == null or hero.team != 0:
			continue
		if phase == 0:
			initial_spells = hero.spells.duplicate()
			initial_ap = hero.current_ap
			await _capture("02_normal_spells")
			for ability: Spell in hero.spells:
				if ability.can_target_self and battle.spell_caster.can_cast(
						hero,
						ability,
						hero.grid_pos,
					):
					battle._on_spell_pressed(ability)
					battle._on_cell_clicked(hero.grid_pos)
					phase = 1
					break
		elif phase == 1 and hero.current_ap < initial_ap:
			frames_after_cast += 1
			if frames_after_cast < 12:
				continue
			await _capture("03_after_spell")
			var success := hero.spells == initial_spells and hero.spells.size() == 4
			var report := {
				"success": success,
				"spell_count": hero.spells.size(),
				"spells_unchanged_after_cast": hero.spells == initial_spells,
				"ap_before": initial_ap,
				"ap_after": hero.current_ap,
				"contract": controller.state.contract,
				"shield": hero.current_shield,
			}
			FileAccess.open(output.path_join("report.json"), FileAccess.WRITE).store_string(
				JSON.stringify(report, "\t")
			)
			await _finish(success)
			return
	await _finish(false)


func _capture(label: String) -> void:
	for frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(label + ".png"))


func _finish(success: bool) -> void:
	var scene := get_tree().current_scene
	get_tree().current_scene = null
	if scene != null:
		scene.queue_free()
	for frame in 8:
		await get_tree().process_frame
	GameManager.cleanup_run_state()
	get_tree().quit(0 if success else 1)
