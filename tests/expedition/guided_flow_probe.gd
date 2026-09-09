extends Node
## Visual walkthrough with simulated victories and an isolated checkpoint.

const SCREEN := preload("res://ui/expedition/ExpeditionScreen.tscn")
var _screen: Control
var _output := ""
var _failures: Array[String] = []
var _motion := false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var resolution := Vector2i(1280, 720)
	for argument in OS.get_cmdline_user_args():
		if argument == "motion=true": _motion = true
		if argument.begins_with("resolution="):
			var dimensions := argument.trim_prefix("resolution=").split("x")
			resolution = Vector2i(int(dimensions[0]), int(dimensions[1]))
	get_window().size = resolution
	_output = "res://artifacts/run_interface_v2/%dx%d" % [resolution.x, resolution.y]
	DirAccess.make_dir_recursive_absolute(_output)
	GameManager.expedition_save_path = _output.path_join("probe_save.json")
	GameManager.set_reduced_motion_enabled(not _motion)
	var run := ExpeditionRunFactory.create(2401)
	var heroes := GameManager.resolve_run_hero_data(run, false)
	GameManager._prepare_preconfigured_run(run, heroes.heroes)
	GameManager.expedition = ExpeditionSession.new()
	GameManager.expedition.initialize(GameManager.get_character_state(&"achilles"), 2401)
	GameManager.expedition.enter("d01_0")
	GameManager.expedition.combat_won()
	_screen = SCREEN.instantiate()
	add_child(_screen)
	await _capture("01_characteristics")
	while GameManager.expedition.character.champion_progression.unspent_attribute_points > 0:
		await _press("Attribute_power")
	await _capture("02_characteristics_complete")
	await _press("ContinueExpeditionFlow")
	await _press("RewardOption_0")
	await _capture("03_reward_selection")
	await _press("ConfirmExpeditionReward")
	await _capture("04_preparation")
	await _press("OpenRouteMap")
	await _capture("05_full_map")
	var route := _screen.find_child("ExpeditionRouteView", true, false)
	var scroll := _screen.find_child("RouteMapScroll", true, false) as ScrollContainer
	scroll.scroll_vertical = 600
	await _settle()
	var previous := scroll.scroll_vertical
	var nodes := GameManager.expedition.route.get_visible_nodes()
	for node in nodes:
		if int(node.depth) == 3:
			route._on_destination_selected(str(node.id))
			break
	await _settle()
	if scroll.scroll_vertical != previous: _failures.append("Destination inspection reset map scroll")
	await _capture("06_map_inspection")
	await _press("CatabaseTab_attributes")
	await _capture("06b_attributes_consultation")
	await _press("CloseExpeditionScreen")
	if str(_screen.get("_page")) != "map": _failures.append("Closing characteristics must return to the map")
	await _press("ReturnToPreparation")
	await _press("PrepareExpeditionEquipment")
	await _capture("07_inventory")
	GameManager.get_persistent_run_ui().close_inventory_screen()
	await _settle()
	await _press("ComposeCatabaseKit")
	await _capture("08_skills")
	await _press("SkillsTab_learn")
	await _capture("08b_skill_tree")
	_screen.queue_free()
	await _settle()
	var session := GameManager.expedition
	while session.route.completed_node_ids.size() < 5:
		session.enter(str(session.route.get_available_nodes()[0].id))
		if session.route.phase == "combat": session.combat_won()
		while session.character.champion_progression.unspent_attribute_points > 0:
			session.character.spend_champion_attribute(&"power")
		var offers := session.reward_options(GameManager.item_catalog)
		session.claim(str(offers.back().id), GameManager.run_inventory, GameManager.item_catalog)
	_screen = SCREEN.instantiate()
	add_child(_screen)
	await _capture("09_deep_map")
	var deep_scroll := _screen.find_child("RouteMapScroll", true, false) as ScrollContainer
	if deep_scroll.scroll_vertical < 400:
		_failures.append("Reopening a deep route must show the upcoming choices")
	_screen.queue_free()
	await _settle()
	session.enter(str(session.route.get_available_nodes()[0].id))
	var before := session.to_snapshot()
	_screen = SCREEN.instantiate()
	_screen.inspection_only = true
	add_child(_screen)
	await _capture("10_combat_map")
	if session.to_snapshot() != before: _failures.append("Combat inspection mutated the expedition")
	await _press("CloseExpeditionScreen")
	await _settle()
	GameManager.cleanup_run_state()
	print("GUIDED_FLOW_VISUAL: %d failures" % _failures.size())
	for failure in _failures: push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _press(button_name: String) -> void:
	var button := _screen.find_child(button_name, true, false) as Button
	if button == null or button.disabled:
		_failures.append("Missing or disabled action: " + button_name)
		return
	button.pressed.emit()
	await _settle()


func _settle() -> void:
	for frame in 6: await get_tree().process_frame
	if _motion: await get_tree().create_timer(0.4).timeout


func _capture(label: String) -> void:
	await _settle()
	var viewport_rect := get_viewport().get_visible_rect()
	if label == "01_characteristics":
		var attribute_scroll := _screen.find_child("AttributeScroll", true, false) as ScrollContainer
		for id in ["vitality", "power", "resolve", "wisdom"]:
			var choice := _screen.find_child("Attribute_" + id, true, false) as Button
			if choice == null or not attribute_scroll.get_global_rect().encloses(choice.get_global_rect()):
				_failures.append("All four attribute choices must be visible immediately: " + id)
	var surface := _screen
	var persistent := GameManager.get_persistent_run_ui()
	if persistent != null and persistent.is_inventory_open(): surface = persistent.inventory_screen
	for button in surface.find_children("*", "Button", true, false):
		if not button.is_visible_in_tree(): continue
		var in_scroll := false
		var ancestor: Node = button.get_parent()
		while ancestor != surface and ancestor != null:
			if ancestor is ScrollContainer: in_scroll = true
			ancestor = ancestor.get_parent()
		if not in_scroll and not viewport_rect.encloses(button.get_global_rect()):
			_failures.append(label + ": action outside viewport: " + str(button.name))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_output.path_join(label + ".png"))
	print("GUIDED_FLOW_CAPTURE: " + label)
