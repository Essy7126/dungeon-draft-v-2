extends "res://tools/ui_chrome/menus_review.gd"
## Canonical run context, real HUD controls, disposable gallery availability fixtures.


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("output_dir="):
			_output = argument.trim_prefix("output_dir=")
	if _output.is_empty():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_output)
	GameManager.expedition_save_path = _output.path_join("fixture_save.json")
	GameManager.set_reduced_motion_enabled(true)
	var run := ExpeditionRunFactory.create(610)
	var resolved := RunHeroResolver.resolve_runtime_hero_data(run, false)
	_check(GameManager._prepare_preconfigured_run(run, resolved.heroes), "Canonical run prepares")
	GameManager.expedition = ExpeditionSession.new()
	GameManager.expedition.initialize(GameManager.get_character_state(&"achilles"), 610)
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.NON_COMBAT)
	var gallery: HudGrayboxGallery = load("res://tools/ui_snapshots/HudGrayboxGallery.tscn").instantiate()
	gallery.premium_skin = true
	add_child(gallery)
	await gallery.gallery_ready
	await _settle()
	var hud = gallery.get("_hud")
	var metrics := gallery.get_validation_metrics()
	_check(metrics.setup_valid, "Production gallery sources are valid")
	var navigation := [
		hud.get_node("%InventoryButton"),
		hud.get_node("%SkillsButton"),
		hud.get_node("%AttributesButton"),
		hud.get_node("%MapButton"),
	]
	var received := { "inventory": false, "skills": false, "attributes": false, "map": false }
	hud.utility_inventory_requested.connect(
		func(_id):
			received.inventory = true,
	)
	hud.utility_skill_tree_requested.connect(
		func(_id, _discipline):
			received.skills = true,
	)
	hud.utility_attributes_requested.connect(
		func():
			received.attributes = true,
	)
	hud.utility_map_requested.connect(
		func():
			received.map = true,
	)
	for button: Button in navigation:
		_check(button.size.x >= 36 and button.size.y >= 36, button.name + " target size")
		_check(not button.accessibility_name.is_empty(), button.name + " accessible name")
		await _click(button)
	for key in received:
		_check(received[key], "Actual navigation click routes " + key)
	await _capture(
		"combat_four",
		navigation + [hud.get_node("%CharacterAnchor"), hud.get_node("%EndTurnButton")],
	)
	var fixture: Unit = gallery.get("_fixture")
	# Repeated spell definitions are deliberate layout stress fixtures, not an earned build.
	fixture.spells.append(fixture.spells[0].duplicate())
	fixture.spells.append(fixture.spells[1].duplicate())
	hud.build_spell_buttons(fixture)
	await _settle()
	var slots: Array = hud.get("_spell_buttons")
	_check(slots.size() == 6, "Six actions are visible")
	for button: Button in slots:
		_check(button.size.x >= 48, "Six-slot target remains readable")
		_check(button.shortcut != null, "Each displayed action has a real shortcut")
	await _capture("combat_six", slots + navigation)
	var end_rect: Rect2 = hud.get_node("%EndTurnButton").get_global_rect()
	await _click(hud.get_node("%ShowItemsButton"))
	_check(hud.get_active_bar_mode() == "item", "Actual tab click switches to items")
	_check(
		hud.get_node("%EndTurnButton").get_global_rect().is_equal_approx(end_rect),
		"End turn stays fixed across tabs",
	)
	await _capture("combat_items", navigation + [hud.get_node("%ItemSlotsCenter")])
	await _click(hud.get_node("%ShowSpellsButton"))
	fixture.current_ap = 0
	# The gallery exposes availability explicitly rather than simulating combat rules.
	for index in range(fixture.spells.size()):
		fixture.call("_set_availability", index, &"pa")
	hud.update_info(fixture)
	await _settle()
	var badge: RecraftResourceBadgeView = hud.get_node("%ActionPointsBadge")
	_check(badge.value_label.text.begins_with("PA 0/"), "Zero AP is explicitly visible")
	_check(not badge.empty_overlay.visible, "Zero AP is not obscured")
	for button: RecraftSpellSlotView in slots:
		_check(
			button.disabled and button.visual_state == RecraftSpellSlotView.VisualState.UNAFFORDABLE,
			"Exhausted action is explicitly unavailable",
		)
	await _capture("combat_exhausted", slots + [badge])
	gallery.queue_free()
	await _settle()
	await _finish()
