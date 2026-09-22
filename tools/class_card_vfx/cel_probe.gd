extends "extension_probe.gd"
## Cel review and preparation/casts/receipt/resume boundary in isolated user data.
var finishing := false


func _init() -> void:
	output_path = "res://artifacts/dev/class_card_vfx/cel/combat/"
	showcase = [
		"a_dagger",
		"a_reap",
		"g_guard",
		"g_bastion",
		"g_crash",
		"g_hook",
		"r_net",
		"r_scatter",
		"t_storm",
		"t_disrupt",
		"t_hourglass",
		"g_fault",
		"r_caltrop",
		"t_cataclysm",
		"t_flamewall",
		"t_glacier",
	]
	captured_frames = showcase.size() * 60
	pair_distance = 2


func _finish() -> void:
	if finishing:
		return
	finishing = true
	var ready_for_journey := checks.all(
		func(row):
			return row.ok,
	)
	if is_instance_valid(battle) and target != null and ready_for_journey:
		await _stack_and_resume()
	await super._finish()


func _stack_and_resume() -> void:
	heading.text = "Braise tenace · impact puis tick"
	caption.text = "Le tick est un petit retour local, déclenché par les dégâts réels"
	_cast("t_burn", target.grid_pos)
	_sample_all(.12)
	await _capture("burn_impact")
	_sample_all(2.0)
	var prior: Array = router.effects.duplicate()
	var hp_before := target.current_hp
	target.process_statuses()
	_check(target.current_hp < hp_before, "Cel burn tick comes from actual periodic damage")
	_sample_new_tick(prior)
	await _capture("burn_tick")
	for state in target.get_active_statuses().duplicate():
		target.remove_status(state.data.get_effective_status_id())
	router.clear()
	router.bind_terrain(battle.terrain_effects)
	heading.text = "Huit états simultanés"
	caption.text = "Cinq signes visibles et +3 · aucun empilement sur le corps"
	clock_label.text = "Fixture de cumul sur une vraie unité · caméra native ×2,4"
	for effect in ["marked", "bleed", "burn", "root", "slow", "weak", "disrupt", "lure"]:
		target.apply_status(Cards.status(effect, effect, 2), hero)
	_sample_all(3.0)
	_check(router.holds.size() == 8, "Eight statuses share one compact rail")
	await _capture("stack_eight")
	battle.camera.zoom /= 2.4
	await _capture("stack_eight_normal")
	for state in target.get_active_statuses().duplicate():
		target.remove_status(state.data.get_effective_status_id())
	router._process(.2)
	_check(router.holds.is_empty(), "Stack removal releases every status slot")
	var releases: Array = router.effects.filter(
		func(fx):
			return is_instance_valid(fx) and not fx.closed and fx.badge_mode and not fx.persistent,
	)
	_check(releases.size() <= 1, "A simultaneous purge releases at most one compact sign")
	for child in get_children():
		if child is CanvasLayer:
			child.hide()
	battle._begin_battle_shutdown()
	battle.queue_free()
	await get_tree().process_frame
	battle = null
	GameManager._combat_report_tracker.discard()
	# This is a setup win to inspect the real receipt boundary, not a played victory.
	_check(session.combat_won(), "Setup win reaches actual Cards receipt")
	var checkpoint := "user://cel_cards_journey.json"
	_check(
		GameManager.save_expedition(checkpoint),
		"Cards receipt is saved through the production service",
	)
	var original_deck := session.cards.active.duplicate()
	var original_node := session.route.current_node_id
	var receipt: Node = load("res://ui/expedition/ExpeditionScreen.tscn").instantiate()
	add_child(receipt)
	await get_tree().create_timer(.3).timeout
	_check(
		receipt.find_child("ClassLootContinue", true, false) != null,
		"Actual Cards receipt screen is mounted",
	)
	await _capture("journey_receipt")
	receipt.queue_free()
	await get_tree().process_frame
	# Keep this observer alive across the real scene change performed by resume.
	get_tree().current_scene = null
	var resumed := GameManager.resume_expedition(checkpoint)
	_check(resumed, "Real resume command loads the saved Cards run")
	if resumed:
		await get_tree().scene_changed
		await get_tree().create_timer(.4).timeout
		session = GameManager.expedition
		_check(
			session.cards.active == original_deck and session.route.current_node_id == original_node,
			"Resume preserves deck and destination",
		)
		var resumed_screen := get_tree().current_scene
		var close_button := resumed_screen.find_child("ClassLootContinue", true, false) as Button
		_check(close_button != null, "Resume returns to the real unreviewed receipt")
		await _capture("journey_resumed")
		if close_button != null:
			close_button.pressed.emit()
			await get_tree().create_timer(.2).timeout
			_check(
				session.class_combat_receipt_reviewed(),
				"Receipt button commits its reviewed state",
			)
		_check(
			router.holds.is_empty() and not router.is_card_battle(),
			"Combat VFX stay cleared across receipt and resume",
		)
		resumed_screen.queue_free()
		get_tree().current_scene = null
		await get_tree().process_frame
	ExpeditionSaveService.remove_snapshot(checkpoint)
