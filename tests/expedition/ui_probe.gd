extends Node
## Actual Catabase screen and combat modal probe; later wins are fixture outcomes.
const SCREEN_PATH := "res://ui/expedition/ExpeditionScreen.tscn"
const OUTPUT_PATH := "res://artifacts/catabase_ui"
var is_observer := false
var _checks := 0
var _failures: Array[String] = []
var _captures: Array[Dictionary] = []
var _resolution := Vector2i(1280, 720)
var _output_dir := ""


func _ready() -> void:
	if is_observer:
		call_deferred("_run")
	else:
		var observer := Node.new()
		observer.set_script(get_script())
		observer.set("is_observer", true)
		get_tree().root.add_child.call_deferred(observer)


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("resolution="):
			var dimensions := argument.trim_prefix("resolution=").split("x")
			_resolution = Vector2i(int(dimensions[0]), int(dimensions[1]))
	_output_dir = ProjectSettings.globalize_path(OUTPUT_PATH.path_join("%dx%d" % [_resolution.x, _resolution.y]))
	DirAccess.make_dir_recursive_absolute(_output_dir)
	GameManager.expedition_save_path = _output_dir.path_join("probe_save.json")
	get_window().size = _resolution
	_check(GameManager.start_expedition(7642), "Canonical Catabase start failed")
	var ready_deadline := Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < ready_deadline:
		await get_tree().create_timer(0.05).timeout
		var battle := get_tree().current_scene
		if battle == null or not bool(battle.get("runtime_ready_state")): continue
		var deployment = battle.get("_deployment")
		if deployment != null and deployment.is_active():
			deployment.on_cell_clicked(GameManager.get_current_room().hero_spawn_zone[0])
			continue
		if bool(battle.call("_can_accept_player_intent")): break
	await _settle()
	var session: ExpeditionSession = GameManager.expedition
	if session == null:
		_finish()
		return
	_check(session.route.phase == "combat" and session.route.current_node_id == "d01_0", "Start must enter the authored first combat immediately")
	_check(session.character.loadout.get_equipped_spells().size() == 4 and session.build.points == 0, "Opening has four fixed spells and no preconfiguration points")
	var persistent: PersistentRunUI = GameManager.get_persistent_run_ui()
	var hud: Node = persistent.combat_hud
	var map_button := hud.get_node("%MapButton") as Button
	var inventory_button := hud.get_node("%InventoryButton") as Button
	_check(map_button.visible and not map_button.disabled, "Catabase map icon missing in combat")
	_check(inventory_button.visible and map_button.get_parent() == inventory_button.get_parent(), "Map must sit beside inventory")
	_check(not map_button.get_global_rect().intersects(inventory_button.get_global_rect()), "Map and inventory buttons overlap")
	for attempt in 180:
		if persistent.call("_combat_context_allows_run_modal"): break
		await get_tree().process_frame
	map_button.pressed.emit()
	await _settle()
	var inspection := persistent.get("_expedition_inspection") as Control
	_check(inspection != null, "Map icon failed to open its combat modal")
	if inspection != null:
		_check(str(inspection.get("_page")) == "map" and bool(inspection.get("inspection_only")), "Map icon must open the read-only map page")
		_check(persistent.has_active_modal(), "Map did not claim combat modal lock")
		await _capture("combat_map", inspection)
		for button in inspection.find_children("CommitDestination", "Button", true, false):
			_check(button.disabled, "Combat map must forbid choosing a path")
		persistent.call("_close_expedition_inspection")
		await _settle()
		_check(not persistent.has_active_modal(), "Closing map must release the combat modal lock")
		_check(session.route.phase == "combat", "Consultation mutated the route")
	_check(session.combat_won(), "First reward fixture failed")
	# The later state transitions are fixtures, so their boundary saves must no
	# longer be guarded by the real opening's still-active report tracker.
	GameManager.get("_combat_report_tracker").discard()
	get_tree().change_scene_to_file(SCREEN_PATH)
	await _settle()
	await _capture("first_reward")
	_check(bool(GameManager.claim_expedition_reward("supplies").get("success", false)), "First reward selection failed")
	var screen := get_tree().current_scene as Control
	screen.call("_render")
	await _settle()
	await _capture("parchment_map")
	var map_scroll: ScrollContainer = screen.get("_map_scroll")
	map_scroll.scroll_vertical = 700
	await _settle()
	var before := map_scroll.scroll_vertical
	map_scroll.get_child(0).emit_signal("node_selected", "d12_0")
	await _settle()
	_check((screen.get("_map_scroll") as ScrollContainer).scroll_vertical == before, "Inspecting a map node reset its scroll")
	await _capture("parchment_future")
	for page in ["build", "gear", "journal"]:
		screen.set("_page", page)
		screen.call("_render")
		await _settle()
		await _capture(page)
	screen.set("_page", "build")
	for doctrine in ["chiron", "eaque"]:
		screen.set("_doctrine", doctrine)
		screen.call("_render")
		await _settle()
		await _capture("tree_" + doctrine)
	while session.route.completed_node_ids.size() < 12:
		var available := session.route.get_available_nodes()
		_check(not available.is_empty(), "No next fixture destination")
		if available.is_empty(): break
		var chosen: Dictionary = available[0]
		if int(chosen.depth) == 4:
			for candidate in available:
				if str(candidate.kind) == "hub": chosen = candidate
		_check(session.enter(str(chosen.id)), "Cannot enter fixture destination")
		if session.route.phase == "combat": _check(session.combat_won(), "Fixture combat cannot resolve")
		var depth := int(session.route.get_current_node().depth)
		if depth in [4, 12]:
			screen.set("_page", "hub")
			screen.call("_render")
			await _settle()
			await _capture("hub" if depth == 4 else "sixth_choice")
			if depth == 4:
				var zones := screen.find_children("HubZone_*", "Button", true, false)
				_check(zones.size() >= 3, "Hub needs at least three real service zones")
				_check(bool(GameManager.use_catabase_hub_service("lore").get("success", false)), "Lore service failed")
				_check(bool(GameManager.use_catabase_hub_service("branch:elements").get("success", false)), "Elemental discovery failed")
				_check(session.build.is_axis_discovered("elements"), "Discovered branch not exposed to tree")
		if depth == ExpeditionBuildState.CAPACITY_DEPTH:
			_check(bool(GameManager.choose_expedition_capacity("slot").get("success", false)), "Sixth slot choice failed")
		var options := session.reward_options(GameManager.item_catalog)
		_check(not options.is_empty(), "No reward options after encounter")
		if options.is_empty(): break
		var choice := "supplies" if session.route.get_current_node().kind in ["normal", "elite", "boss"] else "leave_hub"
		_check(bool(GameManager.claim_expedition_reward(choice).get("success", false)), "Fixture reward/leave failed at %d" % depth)
	_check(session.character.loadout.get_active_slot_count() == 6, "Six-slot kit missing at XII")
	screen.set("_page", "build")
	screen.set("_doctrine", "elements")
	screen.call("_render")
	await _settle()
	await _capture("discovered_branch")
	screen.set("_show_loadout", true)
	screen.call("_render")
	await _settle()
	await _capture("six_spell_kit")
	get_tree().change_scene_to_file("res://ui/TitreEcran.tscn")
	await _settle()
	var resume := get_tree().current_scene.find_child("BoutonReprendreCatabase", true, false) as Button
	_check(resume != null, "Canonical title must expose the saved Catabase")
	if resume != null:
		resume.pressed.emit()
		await _settle()
		_check(get_tree().current_scene is ExpeditionScreen, "Title resume must reopen the canonical route")
		_check(GameManager.expedition != null and GameManager.expedition.route.completed_node_ids.size() == 12, "Title resume lost the saved path")
	_finish()


func _settle(frames := 10) -> void:
	for frame in frames: await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw


func _capture(label: String, override: Control = null) -> void:
	var screen := override if override != null else get_tree().current_scene as Control
	_check(screen != null, "No screen during capture " + label)
	if screen == null: return
	var overflows: Array[String] = []
	var cramped: Array[String] = []
	var buttons := 0
	for control in screen.find_children("*", "Control", true, false):
		if not control.is_visible_in_tree(): continue
		if control is Button and not control.disabled: buttons += 1
		if control is Label and control.text.length() > 30 and control.size.x < 80:
			cramped.append(str(screen.get_path_to(control)))
		var rect: Rect2 = control.get_global_rect()
		if rect.position.x < -1 or rect.end.x > _resolution.x + 1:
			overflows.append("%s x=%.1f w=%.1f" % [screen.get_path_to(control), rect.position.x, rect.size.x])
	_check(overflows.is_empty(), label + " horizontal overflow: " + str(overflows))
	_check(cramped.is_empty(), label + " cramped labels: " + str(cramped))
	_check(buttons > 0, label + " has no accessible buttons")
	var path := ""
	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		path = _output_dir.path_join(label + ".png")
		_check(image.save_png(path) == OK, "Could not capture " + label)
	_captures.append({"page": label, "path": path, "rendered": not path.is_empty(), "enabled_buttons": buttons, "horizontal_overflows": overflows, "cramped_labels": cramped})


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)


func _finish() -> void:
	var report := {"checks": _checks, "failures": _failures, "captures": _captures,
		"scope": "Real opening and combat map modal; later combat victories are supplied by fixture."}
	var file := FileAccess.open(_output_dir.path_join("report.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t"))
	print("Catabase UI %dx%d: %d checks, %d failures, %d views" % [_resolution.x, _resolution.y, _checks, _failures.size(), _captures.size()])
	for failure in _failures: printerr(failure)
	var scene := get_tree().current_scene
	get_tree().current_scene = null
	if scene != null: scene.queue_free()
	for frame in 3: await get_tree().process_frame
	GameManager.cleanup_run_state()
	for frame in 3: await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)
