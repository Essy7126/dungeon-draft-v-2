extends Node
## Real opening/HUD and halt transactions. Intermediate victories are explicit fixtures.

const SCREEN_PATH := "res://ui/expedition/ExpeditionScreen.tscn"
const ART := preload("res://ui/expedition/catabase_halt_art_catalog.gd")
const ICONS := preload("res://core/expedition/catabase_painted_icon_catalog.gd")
const ROUTES := preload("res://core/expedition/expedition_route_catalog.gd")
const OUTPUT := "res://artifacts/catabase_painted_art"
var is_observer := false
var _resolution := Vector2i(1280, 720)
var _output_dir := ""
var _checks := 0
var _failures: Array[String] = []
var _captures: Array[Dictionary] = []
var _transactions: Array[Dictionary] = []
var _layouts: Array[Dictionary] = []
var _seed := -1
var _route_path: Array[String] = []


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
			if dimensions.size() == 2:
				_resolution = Vector2i(int(dimensions[0]), int(dimensions[1]))
	_output_dir = ProjectSettings.globalize_path(OUTPUT.path_join("%dx%d" % [_resolution.x, _resolution.y]))
	DirAccess.make_dir_recursive_absolute(_output_dir)
	GameManager.expedition_save_path = _output_dir.path_join("probe_save.json")
	get_window().size = _resolution
	_find_fixture_route()
	_check(_seed >= 0 and _route_path.size() == 11, "A real seeded route must reach camp then the lore library")
	if _seed < 0:
		await _finish()
		return
	_check(GameManager.start_expedition(_seed, {"achilles": "painted_g"}), "Canonical painted Achilles launch")
	if GameManager.expedition == null:
		await _finish()
		return
	var battle_ready := false
	var deadline := Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05).timeout
		var battle := get_tree().current_scene
		if battle == null or not bool(battle.get("runtime_ready_state")):
			continue
		var deployment = battle.get("_deployment")
		if deployment != null and deployment.is_active():
			deployment.on_cell_clicked(GameManager.get_current_room().hero_spawn_zone[0])
			continue
		if bool(battle.call("_can_accept_player_intent")):
			battle_ready = true
			break
	_check(battle_ready, "Opening reaches a real controllable combat")
	if not battle_ready:
		await _finish()
		return
	await _settle()
	await _wait_for_opening_banner()
	_check_opening_hud()
	await _capture("opening_hud")
	var session: ExpeditionSession = GameManager.expedition
	# From this point the route advances by fixture victories, not played victories.
	GameManager.get("_combat_report_tracker").discard()
	_check(session.combat_won(), "Opening fixture reward transition")
	get_tree().change_scene_to_file(SCREEN_PATH)
	await _settle()
	for index in range(1, _route_path.size()):
		var previous := session.route.get_current_node()
		var claim := "leave_hub" if ROUTES.is_halt(str(previous.kind)) else "supplies"
		_check(bool(GameManager.claim_expedition_reward(claim).get("success", false)), "Fixture claim at " + str(previous.id))
		_check(session.enter(_route_path[index]), "Follow authored connection " + _route_path[index])
		var destination := session.route.get_current_node()
		if session.route.phase == "combat":
			_check(session.combat_won(), "Intermediate fixture victory " + str(destination.id))
		var key := ART.resolve_key(destination)
		if key in ["camp_compagnons", "bibliotheque_engloutie"]:
			await _probe_halt(key)
			if key == "camp_compagnons":
				await _probe_trees()
	await _finish()


func _find_fixture_route() -> void:
	for candidate_seed in range(64):
		var by_id := {}
		var camp := ""
		var library := ""
		for destination in ROUTES.create_nodes(candidate_seed):
			by_id[str(destination.id)] = destination
			var key := ART.resolve_key(destination)
			if key == "camp_compagnons": camp = str(destination.id)
			if key == "bibliotheque_engloutie": library = str(destination.id)
		if camp.is_empty() or library.is_empty():
			continue
		var first := _path_between(by_id, "d01_0", camp)
		var second := _path_between(by_id, camp, library)
		if first.is_empty() or second.is_empty():
			continue
		_seed = candidate_seed
		_route_path.assign(first)
		_route_path.append_array(second.slice(1))
		return


func _path_between(by_id: Dictionary, start: String, target: String) -> Array[String]:
	var pending: Array = [[start]]
	var visited := {}
	while not pending.is_empty():
		var path: Array = pending.pop_front()
		var current := str(path[-1])
		if current == target:
			var result: Array[String] = []
			result.assign(path)
			return result
		if visited.has(current):
			continue
		visited[current] = true
		for next_id in by_id[current].edges:
			if bool(by_id[next_id].hidden): continue
			var next_path := path.duplicate()
			next_path.append(str(next_id))
			pending.append(next_path)
	return []


func _check_opening_hud() -> void:
	var persistent: PersistentRunUI = GameManager.get_persistent_run_ui()
	_check(persistent != null and persistent.combat_hud != null, "Actual combat HUD exists")
	if persistent == null or persistent.combat_hud == null: return
	var buttons: Array = persistent.combat_hud.get("_spell_buttons")
	var checked := 0
	for button in buttons:
		var spell := button.get_meta("spell", null) as Spell
		if spell == null: continue
		var id := str(spell.get_effective_spell_id())
		var expected := ICONS.spell_icon(id)
		var icon := button.get_node("%SpellIcon") as TextureRect
		_check(expected != null, "Production painted icon exists for " + id)
		_check(spell.icon == expected, "Catabase runtime spell copy owns the painted icon for " + id)
		_check(icon != null and icon.texture == expected, "Real HUD uses painted icon for " + id)
		checked += 1
	_check(checked == 4, "All four canonical opening icons were inspected")


func _wait_for_opening_banner() -> void:
	var persistent := GameManager.get_persistent_run_ui()
	if persistent == null or persistent.combat_hud == null:
		return
	var banner := persistent.combat_hud.get_turn_intro_banner() as Control
	if banner == null:
		return
	var deadline := Time.get_ticks_msec() + 5000
	while banner.visible and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(not banner.visible, "Opening turn banner finishes naturally before the HUD capture")
	await _settle()


func _probe_halt(key: String) -> void:
	var screen := get_tree().current_scene as ExpeditionScreen
	_check(screen != null, "Actual ExpeditionScreen for " + key)
	if screen == null: return
	screen.set("_page", "hub")
	screen.set("_selected_service", "")
	screen.call("_render")
	await _settle()
	_check_halt_layout(screen, key)
	var session: ExpeditionSession = GameManager.expedition
	var before_selection := session.to_snapshot().duplicate(true)
	var target := _service_target(screen, "lore")
	_check(target != null, "Lore target exists at " + key)
	if target == null: return
	target.pressed.emit()
	await _settle()
	_check(str(screen.get("_selected_service")) == "lore", "Painted object selects the real lore service")
	_check(session.to_snapshot() == before_selection, "Selecting art is not a transaction")
	_check_halt_layout(screen, key)
	await _capture(key + "_selected_lore")
	var accept := screen.find_child("UseHubService", true, false) as Button
	_check(accept != null and not accept.disabled, "Explicit transaction confirmation is available")
	if accept == null or accept.disabled: return
	var before_gold := session.gold
	var current_id := session.route.current_node_id
	var completed_before := session.route.completed_node_ids.duplicate()
	accept.pressed.emit()
	await _settle()
	_check(session.gold == before_gold + 20, "Lore actually grants 20 oboles")
	_check(session.hub_used_ids.get(current_id, []).has("lore"), "Lore receipt is persisted in session")
	_check(session.route.current_node_id == current_id and session.route.completed_node_ids == completed_before and session.route.phase == "reward", "Using service stays in the same halt")
	var after_transaction := session.to_snapshot().duplicate(true)
	_check(not bool(GameManager.use_catabase_hub_service("lore").get("success", false)), "Repeated lore transaction is refused")
	_check(session.to_snapshot() == after_transaction, "Refused transaction changes neither currency nor receipt")
	_transactions.append({"halt": key, "service": "lore", "gold_before": before_gold, "gold_after": session.gold, "receipt": session.hub_used_ids.get(current_id, [])})
	var used_confirm := screen.find_child("UseHubService", true, false) as Button
	_check(used_confirm != null and used_confirm.disabled, "Used service is disabled in confirmation panel")
	_check_halt_layout(screen, key)
	await _capture(key + "_lore_completed")


func _service_target(screen: Node, service_id: String) -> Button:
	for candidate in screen.find_children("HubZone_*", "Button", true, false):
		if str(candidate.get_meta("service_id", "")) == service_id:
			return candidate as Button
	return null


func _check_halt_layout(screen: Node, key: String) -> void:
	var target := _service_target(screen, "lore")
	if target == null:
		_check(false, "Halt canvas missing")
		return
	var canvas := target.get_parent() as CatabaseHubCanvas
	_check(canvas.get_art_key() == key and canvas.get_art_status() == "ready", "Correct approved painting loaded: " + key)
	var art_rect := canvas.get_art_rect()
	_check(absf(art_rect.size.x / art_rect.size.y - 1.6) < 0.0001, "Painting has uniform 16:10 fitting")
	var canvas_rect := canvas.get_global_rect()
	var label_report: Array[Dictionary] = []
	for label in canvas._labels:
		label_report.append({"service": str(label.get_meta("service_id")), "text": label.text,
			"rect": _rect_data(label.get_global_rect()), "anchor": str(label.get_meta("art_anchor"))})
		_check(canvas_rect.encloses(label.get_global_rect()), "Service label fits the halt viewport")
		for object_target in canvas._buttons:
			_check(not label.get_rect().intersects(object_target.get_rect()), "Label does not cover a painted target")
		for other in canvas._labels:
			if label != other:
				_check(not label.get_rect().intersects(other.get_rect()), "Service labels are distinct")
	var target_report: Array[Dictionary] = []
	for object_target in canvas._buttons:
		var anchor: Vector2 = object_target.get_meta("art_anchor")
		var expected := art_rect.position + art_rect.size * anchor
		_check((object_target.position + object_target.size * 0.5).distance_to(expected) < 0.01, "Target matches measured painting coordinate")
		target_report.append({"service": str(object_target.get_meta("service_id")), "rect": _rect_data(object_target.get_global_rect()), "anchor": [anchor.x, anchor.y]})
	_layouts.append({"halt": key, "canvas": _rect_data(canvas_rect), "painting_local_rect": _rect_data(art_rect), "labels": label_report, "targets": target_report})
	var leave := screen.find_child("LeaveHub", true, false) as Button
	_check(leave != null and not leave.disabled, "Departure remains a separate available action")


func _probe_trees() -> void:
	var screen := get_tree().current_scene as ExpeditionScreen
	var session: ExpeditionSession = GameManager.expedition
	for doctrine in ["colere", "chiron"]:
		screen.set("_page", "build")
		screen.set("_doctrine", doctrine)
		screen.set("_selected_technique", "")
		screen.call("_render")
		await _settle()
		var ids: Array[String] = []
		ids.append("briseur.learn_a" if doctrine == "colere" else "danseur.learn_a")
		for id in ids:
			var button := screen.find_child("Technique_" + id.replace(".", "_"), true, false) as Button
			var expected := ICONS.node_icon(session.build.catalog.get_node(id))
			_check(button != null and expected != null, "Painted tree technique exists: " + id)
			if button != null:
				_check(button.icon == expected, "Actual tree renders expected painted icon: " + id)
		await _capture("tree_" + doctrine)


func _settle() -> void:
	for frame in 10: await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw


func _capture(label: String) -> void:
	var path := ""
	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		_check(image != null and image.get_size() == _resolution, "Capture resolution " + label)
		if image != null:
			path = _output_dir.path_join(label + ".png")
			_check(image.save_png(path) == OK, "Capture saved: " + label)
	_captures.append({"view": label, "path": path, "rendered": not path.is_empty()})


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition: _failures.append(message)


func _rect_data(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _finish() -> void:
	var report := {"checks": _checks, "failures": _failures, "captures": _captures,
		"transactions": _transactions, "layouts": _layouts, "seed": _seed, "fixture_path": _route_path,
		"scope": "Real opening HUD and two halt transactions through their confirmation buttons; intermediate victories are fixtures, not combat validation."}
	var file := FileAccess.open(_output_dir.path_join("report.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t"))
	file = null
	print("Catabase painted art %dx%d: %d checks, %d failures" % [_resolution.x, _resolution.y, _checks, _failures.size()])
	for failure in _failures: printerr(failure)
	var scene := get_tree().current_scene
	get_tree().current_scene = null
	if scene != null: scene.queue_free()
	for frame in 3: await get_tree().process_frame
	GameManager.cleanup_run_state()
	for frame in 3: await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)
