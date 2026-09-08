extends Node

## Exercices de la scène réelle. Ajouter -- --capture avec un renderer actif.
const SCENE_PATH := "res://hub/sanctuary_prototype/SanctuaryPrototype.tscn"
const OUTPUT_DIR := "res://artifacts/project_audit/2026-09-08/sanctuary"
const STEP := 1.0 / 60.0
const MAX_MOVEMENT_STEPS := 2400

class HaltFixtureManager:
	extends "res://core/game_manager.gd"
	func start_next_battle() -> void:
		_room_outcome_resolved = false

var root: Window
var _run_id := ""
var _live_halt_save := ""
var _manager: HaltFixtureManager
var _user_save_before := ""
var _user_inventory_before := ""
var _hub: Node
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _captures: Array[Dictionary] = []
var _motion_checks: Array[Dictionary] = []
var _resolution := ""
var _capture_enabled := false
var _started_at := 0


func _ready() -> void:
	root = get_tree().root
	get_tree().current_scene = null
	_run_id = str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(Time.get_ticks_usec())
	_started_at = Time.get_ticks_msec()
	_capture_enabled = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_user_save_before = FileAccess.get_sha256(ExpeditionSaveService.SAVE_PATH) if FileAccess.file_exists(ExpeditionSaveService.SAVE_PATH) else "absent"
	_user_inventory_before = FileAccess.get_sha256("user://inventory_equipment_v1.json") if FileAccess.file_exists("user://inventory_equipment_v1.json") else "absent"
	var global_manager := root.get_node("GameManager")
	global_manager.expedition_save_path = OUTPUT_DIR.path_join("unused_preparation_" + _run_id + ".json")
	var packed := load(SCENE_PATH) as PackedScene
	_check("scene_loads", packed != null, SCENE_PATH)
	if packed != null:
		for resolution: Vector2i in [Vector2i(1200, 896), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			_resolution = "%dx%d" % [resolution.x, resolution.y]
			root.size = resolution
			_manager = _halt_fixture()
			_hub = packed.instantiate()
			root.add_child(_hub)
			get_tree().current_scene = _hub
			var ready_deadline := Time.get_ticks_msec() + 10000
			while _hub.has_method("is_ready_for_play") and not bool(_hub.call("is_ready_for_play")) and Time.get_ticks_msec() < ready_deadline:
				await get_tree().process_frame
			var ready := _hub.has_method("is_ready_for_play") and bool(_hub.call("is_ready_for_play"))
			_check("scene_ready_within_10_seconds", ready)
			if ready:
				_hub.set_process(false)
				_hub.get_session().bind_runtime(_manager)
				_hub.call("_update_hud")
				await _exercise_scene()
			_hub.queue_free()
			await get_tree().process_frame
			await get_tree().process_frame
			_hub = null
			_manager.cleanup_run_state()
			_manager._exit_tree()
			_manager.free()
			await get_tree().process_frame
	await _exercise_live_bridge()
	global_manager.expedition_save_path = OUTPUT_DIR.path_join("unused_preparation_after_halt_" + _run_id + ".json")
	await _exercise_exits()
	var user_save_after := FileAccess.get_sha256(ExpeditionSaveService.SAVE_PATH) if FileAccess.file_exists(ExpeditionSaveService.SAVE_PATH) else "absent"
	_check("player_save_unchanged", user_save_after == _user_save_before)
	var user_inventory_after := FileAccess.get_sha256("user://inventory_equipment_v1.json") if FileAccess.file_exists("user://inventory_equipment_v1.json") else "absent"
	_check("player_inventory_save_unchanged", user_inventory_after == _user_inventory_before)
	_write_report()
	for failure: String in _failures:
		push_error("SANCTUARY_RUNTIME: " + failure)
	print("SANCTUARY_RUNTIME: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks.size(), _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _halt_fixture() -> HaltFixtureManager:
	var manager := HaltFixtureManager.new()
	manager.expedition_save_path = OUTPUT_DIR.path_join("bridge_save_" + _run_id + "_" + _resolution + ".json")
	manager._ready()
	_check("fixture_start", manager.start_expedition(2401))
	while int(manager.expedition.route.get_current_node().depth) < 4:
		_check("fixture_victory", manager.expedition.combat_won())
		_check("fixture_reward", bool(manager.claim_expedition_reward("supplies").get("success", false)))
		var nodes := manager.expedition.route.get_available_nodes()
		var chosen: Dictionary = nodes[0]
		for node: Dictionary in nodes:
			if int(node.depth) == 4 and str(node.kind) == "hub":
				chosen = node
		_check("fixture_next_node", manager.choose_expedition_node(str(chosen.id)))
	_check("fixture_is_real_halt", manager.get_sanctuary_context().mode == "halt")
	return manager


func _exercise_scene() -> void:
	var layout: Dictionary = _hub.get("layout")
	var nav: RefCounted = _hub.get("nav")
	var panels: Control = _hub.call("get_panels")
	var spawn := _point(layout.spawn)
	_check("no_node3d", _hub.find_children("*", "Node3D", true, false).is_empty())
	_check("initial_spawn_walkable", bool(nav.call("is_walkable", _position())))
	_check("real_currency", _manager.get_sanctuary_context().currency_label == "oboles")
	_validate_shaders()
	_validate_residents()
	_validate_routes(layout, nav)
	await _settle_ui()
	for caption: Label in _hub.find_children("NameLabel", "Label", true, false):
		_check("resident_name_readable_" + caption.get_parent().name, caption.get_theme_font_size("font_size") * caption.get_global_transform_with_canvas().get_scale().y >= 12.5)
	var player_screen: Vector2 = (_hub.get("world") as Node2D).get_global_transform_with_canvas() * _position()
	_check("player_clear_of_toolbar", player_screen.y > 88 and player_screen.y < root.size.y - 128)
	if _capture_enabled:
		var initial := await _capture("initial")
		await get_tree().create_timer(0.8).timeout
		var animated := await _capture("initial_after800ms")
		if initial != null and animated != null:
			var motion := _measure_water_motion(initial, animated, layout)
			_motion_checks.append(motion)
			_check("water_animates", int(motion.changed_samples) > 0)
	var merchant := _entity(layout, "merchant")
	var oracle := _entity(layout, "oracle")
	var before_move := _position()
	await _click_native(_point(merchant.position))
	_check("merchant_not_teleported", _position().is_equal_approx(before_move) and not panels.is_open())
	_check("merchant_arrives", await _advance_to(_point(merchant.approach), true))
	_check("modal_blocks_world", not _hub.request_move(spawn))
	await _settle_ui()
	await _capture("shop")
	var offers: Array[Dictionary] = _hub.get_session().services_for(&"merchant")
	_check("real_merchant_offer", not offers.is_empty())
	if offers.is_empty(): return
	var offer: Dictionary = offers[0]
	var buy := panels.find_child("Buy_" + str(offer.id).replace(":", "_"), true, false) as Button
	var before_gold := _manager.expedition.gold
	_check("buy_available", buy != null and not buy.disabled)
	if buy == null: return
	await _click_button(buy)
	_check("purchase_debits_exact_oboles", _manager.expedition.gold == before_gold - int(offer.cost))
	var inventory: Array = _manager.get_sanctuary_context().inventory
	_check("purchase_enters_real_inventory", inventory.any(func(item: Dictionary) -> bool: return item.item_id == offer.item_id and int(item.quantity) == 1))
	_check("purchase_saved", not ExpeditionSaveService.read_snapshot(_manager.expedition_save_path).is_empty())
	buy = panels.find_child("Buy_" + str(offer.id).replace(":", "_"), true, false) as Button
	_check("receipt_disables_duplicate_purchase", buy != null and buy.disabled)
	await _capture("shop_purchased")
	await _key(KEY_ESCAPE)
	_check("escape_closes_only_panel", not panels.is_open() and is_instance_valid(_hub))
	await _click_button(_hub.find_child("Visit_oracle", true, false) as Button)
	_check("shortcut_walks_to_oracle", await _advance_to(_point(oracle.approach), true))
	await _settle_ui()
	await _capture("oracle")
	var before_lore_gold := _manager.expedition.gold
	var select := panels.find_child("Select_lore", true, false) as Button
	await _click_button(select)
	_check("oracle_selection_has_no_effect", _manager.expedition.gold == before_lore_gold)
	var confirm := panels.find_child("ConfirmService", true, false) as Button
	_check("oracle_fixed_confirmation", confirm != null and not confirm.disabled and confirm.get_global_rect().end.y <= root.size.y)
	await _click_button(confirm)
	_check("oracle_real_reward", _manager.expedition.gold == before_lore_gold + 20)
	select = panels.find_child("Select_lore", true, false) as Button
	_check("oracle_receipt_survives_refresh", select != null and select.disabled)
	var restored := HaltFixtureManager.new()
	restored.expedition_save_path = OUTPUT_DIR.path_join("unused_restore_" + _run_id + ".json")
	restored._ready()
	_check("restore_real_save", restored.resume_expedition(_manager.expedition_save_path))
	_check("restored_gold_and_inventory", restored.expedition.gold == _manager.expedition.gold and restored.get_sanctuary_context().inventory == _manager.get_sanctuary_context().inventory)
	_check("restored_receipt", restored.expedition.hub_used_ids == _manager.expedition.hub_used_ids)
	if _live_halt_save.is_empty():
		_live_halt_save = OUTPUT_DIR.path_join("live_halt_" + _run_id + ".json")
		_check("isolated_live_halt_copy", DirAccess.copy_absolute(ProjectSettings.globalize_path(_manager.expedition_save_path), ProjectSettings.globalize_path(_live_halt_save)) == OK)
	restored.cleanup_run_state()
	restored._exit_tree()
	restored.free()
	await _capture("oracle_confirmed")
	await _key(KEY_TAB)
	var focus := root.gui_get_focus_owner()
	_check("keyboard_focus_stays_in_modal", focus != null and panels.is_ancestor_of(focus))
	await _key(KEY_ESCAPE)
	await _click_button(_hub.find_child("InventoryButton", true, false) as Button)
	await _capture("inventory")
	await _key(KEY_ESCAPE)
	await _key(KEY_3)
	_check("keyboard_reaches_passage", await _advance_to(_point(_entity(layout, "passage").approach), true))
	await _settle_ui()
	_check("new_panel_starts_at_top", (panels.find_child("ContentScroll", true, false) as ScrollContainer).scroll_vertical == 0)
	await _capture("departure")
	var departure := panels.find_child("ContinueJourney", true, false) as Button
	_check("departure_visible_and_available", departure != null and not departure.disabled and departure.get_global_rect().end.y <= root.size.y)
	await _click_button(departure)
	await get_tree().process_frame
	_check("departure_commits_halt", _manager.expedition.route.phase == "map")
	var saved := ExpeditionSaveService.read_snapshot(_manager.expedition_save_path)
	_check("departure_persists_map", str(saved.get("session", {}).get("route", {}).get("phase", "")) == "map")


func _exercise_live_bridge() -> void:
	_resolution = "1200x896"
	root.size = Vector2i(1200, 896)
	var live_manager := root.get_node("GameManager")
	live_manager.expedition_save_path = _live_halt_save
	_check("live_resume_halt", live_manager.resume_expedition(_live_halt_save))
	await _wait_scene("res://ui/expedition/ExpeditionScreen.tscn")
	_check("live_open_sanctuary", bool(live_manager.open_sanctuary().get("success", false)))
	await _wait_scene(SCENE_PATH)
	_hub = get_tree().current_scene
	var deadline := Time.get_ticks_msec() + 10000
	while not _hub.is_ready_for_play() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check("live_halt_context", _hub.get_session().get_context().mode == "halt")
	await _capture("live_halt")
	await _click_button(_hub.find_child("InventoryButton", true, false) as Button)
	await _capture("live_halt_inventory")
	await _key(KEY_ESCAPE)
	_check("live_escape_closes_panel", not _hub.get_panels().is_open() and get_tree().current_scene == _hub)
	await _click_button(_hub.find_child("SanctuaryMenuButton", true, false) as Button)
	await _wait_scene("res://ui/expedition/ExpeditionScreen.tscn")
	_check("live_return_keeps_halt", live_manager.expedition.route.phase == "reward")
	_check("live_reenter_sanctuary", bool(live_manager.open_sanctuary().get("success", false)))
	await _wait_scene(SCENE_PATH)
	_hub = get_tree().current_scene
	deadline = Time.get_ticks_msec() + 10000
	while not _hub.is_ready_for_play() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await _key(KEY_ESCAPE)
	await _wait_scene("res://ui/expedition/ExpeditionScreen.tscn")
	_check("live_escape_returns_halt", live_manager.expedition.route.phase == "reward")
	live_manager.return_to_title()
	await _wait_scene("res://ui/TitreEcran.tscn")
	_hub = null


func _wait_scene(path: String) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == path:
			await _settle_ui()
			return
	_check("scene_transition_" + path.get_file(), false)


func _exercise_exits() -> void:
	_resolution = "1200x896"
	root.size = Vector2i(1200, 896)
	get_tree().change_scene_to_file(SCENE_PATH)
	await _wait_scene(SCENE_PATH)
	_hub = get_tree().current_scene
	var deadline := Time.get_ticks_msec() + 10000
	while not _hub.is_ready_for_play() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_hub.set_process(false)
	var panels: Control = _hub.get_panels()
	panels.open_shop()
	await _settle_ui()
	_check("preparation_has_no_shop", panels.find_children("Buy_*", "Button", true, false).is_empty())
	await _capture("preparation")
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	for frame in 16: await get_tree().process_frame
	_check("sanctuary_escape_returns_title", get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://ui/TitreEcran.tscn")
	get_tree().change_scene_to_file("res://hub/StartHub.tscn")
	for frame in 24: await get_tree().process_frame
	var menu := get_tree().current_scene.find_child("HubMenuButton", true, false) as Button
	_check("legacy_hub_has_menu", menu != null and menu.is_visible_in_tree())
	await _key(KEY_ESCAPE)
	for frame in 16: await get_tree().process_frame
	_check("legacy_escape_returns_title", get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://ui/TitreEcran.tscn")
	_hub = null


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await get_tree().process_frame


func _validate_routes(layout: Dictionary, nav: RefCounted) -> void:
	var points: Array[Dictionary] = [{"id": "spawn", "point": _point(layout.spawn)}]
	for entity: Dictionary in layout.get("entities", []):
		points.append({"id": String(entity.id), "point": _point(entity.approach)})
	for from in points:
		for to in points:
			if from.id == to.id:
				continue
			var path: PackedVector2Array = nav.call("get_path", from.point, to.point)
			var connected := not path.is_empty() and path[0].distance_to(from.point) <= 0.5 and path[-1].distance_to(to.point) <= 0.5
			_check("route_%s_to_%s_connected" % [from.id, to.id], connected)
			if not connected:
				continue
			var samples_safe := true
			for segment in range(1, path.size()):
				var count := maxi(1, ceili(path[segment - 1].distance_to(path[segment]) / 4.0))
				for step in range(count + 1):
					var point := path[segment - 1].lerp(path[segment], float(step) / float(count))
					if not bool(nav.call("is_walkable", point)):
						samples_safe = false
			_check("route_%s_to_%s_stays_on_floor" % [from.id, to.id], samples_safe)


func _validate_shaders() -> void:
	for spec: Dictionary in [
		{"node": "World/Water", "shader": "painted_water.gdshader", "id": "water"},
		{"node": "World/Atmosphere", "shader": "brazier_smoke.gdshader", "id": "smoke"},
	]:
		var parent := _hub.get_node_or_null(String(spec.node))
		var matching := 0
		if parent != null:
			for child: Node in parent.get_children():
				if child is CanvasItem and child.material is ShaderMaterial:
					var material := child.material as ShaderMaterial
					if material.shader != null and material.shader.resource_path.ends_with(String(spec.shader)):
						matching += 1
		_check(String(spec.id) + "_shader_attached_to_scene", matching > 0, {"matching_nodes": matching})


func _validate_residents() -> void:
	var scene_entities: Dictionary = _hub.get("entities")
	for id: String in ["merchant", "oracle"]:
		var actor := scene_entities.get(StringName(id)) as Node2D
		var sprite := actor.get_node_or_null("ResidentSprite") as Sprite2D if actor != null else null
		var material := sprite.material as ShaderMaterial if sprite != null else null
		var shader_bound := material != null and material.shader != null and material.shader.resource_path.ends_with("resident_alpha.gdshader")
		_check(id + "_textured_sprite_and_alpha_shader", sprite != null and sprite.texture != null and shader_bound)
		var mask: Texture2D = material.get_shader_parameter("silhouette_mask") if material != null else null
		var mask_bound := mask != null and mask.get_width() > 0 and mask.get_height() > 0
		if sprite != null and sprite.texture != null and mask_bound:
			mask_bound = mask.get_size() == sprite.texture.get_size()
		_check(id + "_silhouette_mask_matches_atlas", mask_bound, {"mask_resource": mask.resource_path if mask != null else ""})

func _advance_to(destination: Vector2, expect_panel: bool) -> bool:
	var panels: Control = _hub.call("get_panels")
	var nav: RefCounted = _hub.get("nav")
	var unsafe_samples := 0
	for frame in range(MAX_MOVEMENT_STEPS):
		_hub.call("_process", STEP)
		if not bool(nav.call("is_walkable", _position())):
			unsafe_samples += 1
		var opened := bool(panels.call("is_open"))
		if opened:
			_check("movement_samples_remain_walkable", unsafe_samples == 0, {"samples": frame + 1, "unsafe_samples": unsafe_samples})
			return expect_panel and _position().distance_to(destination) <= 24.0
		if not expect_panel and _position().distance_to(destination) <= 2.0:
			_check("movement_samples_remain_walkable", unsafe_samples == 0, {"samples": frame + 1, "unsafe_samples": unsafe_samples})
			return true
		if frame % 120 == 0:
			await get_tree().process_frame
	_check("movement_arrives_within_40_simulated_seconds", false, {"target": [destination.x, destination.y], "position": _position_data()})
	return false


func _click_button(button: Button) -> void:
	if button == null:
		_check("button_exists_for_click", false)
		return
	var scroll := button.find_parent("ContentScroll") as ScrollContainer
	if scroll != null:
		scroll.ensure_control_visible(button)
	await _settle_ui()
	var center := button.get_global_rect().get_center()
	await _click_screen(center)
	await _settle_ui()


func _click_native(point: Vector2) -> void:
	var world := _hub.get("world") as Node2D
	await _click_screen(world.get_global_transform_with_canvas() * point)


func _click_screen(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.position = point
	down.global_position = point
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = point
	up.global_position = point
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _settle_ui() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _capture(label: String) -> Image:
	if not _capture_enabled:
		return null
	await _settle_ui()
	await RenderingServer.frame_post_draw
	var image := _hub.get_viewport().get_texture().get_image()
	var path := "%s/%s_%s.png" % [OUTPUT_DIR, label, _resolution]
	var error := image.save_png(ProjectSettings.globalize_path(path)) if image != null and not image.is_empty() else ERR_CANT_CREATE
	_captures.append({"state": label, "resolution": _resolution, "path": path, "saved": error == OK})
	_check("capture_" + label, error == OK)
	return image


func _measure_water_motion(before: Image, after: Image, layout: Dictionary) -> Dictionary:
	var world := _hub.get("world") as Node2D
	var transform := world.get_global_transform_with_canvas()
	var sampled := 0
	var changed := 0
	var greatest_delta := 0.0
	for raw: Array in layout.get("water_polygons", []):
		var polygon := _polygon(raw)
		var minimum := polygon[0]
		var maximum := polygon[0]
		for point: Vector2 in polygon:
			minimum = minimum.min(point)
			maximum = maximum.max(point)
		for y in range(int(minimum.y) + 4, int(maximum.y) - 3, 4):
			for x in range(int(minimum.x) + 4, int(maximum.x) - 3, 4):
				var native_point := Vector2(x, y)
				if not Geometry2D.is_point_in_polygon(native_point, polygon):
					continue
				var screen_point := Vector2i(transform * native_point)
				if screen_point.x < 0 or screen_point.y < 0 or screen_point.x >= before.get_width() or screen_point.y >= before.get_height():
					continue
				var first := before.get_pixelv(screen_point)
				var last := after.get_pixelv(screen_point)
				var delta := absf(first.r - last.r) + absf(first.g - last.g) + absf(first.b - last.b)
				sampled += 1
				greatest_delta = maxf(greatest_delta, delta)
				if delta > 0.002:
					changed += 1
	return {"resolution": _resolution, "interval_seconds": 0.8, "sample_region": "water_polygons_only", "samples": sampled, "changed_samples": changed, "max_rgb_delta": greatest_delta}


func _position() -> Vector2:
	return _hub.call("get_player_position")


func _position_data() -> Array[float]:
	var position := _position()
	return [position.x, position.y]


func _entity(layout: Dictionary, id: String) -> Dictionary:
	for entity: Dictionary in layout.get("entities", []):
		if String(entity.id) == id:
			return entity
	return {}


func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


func _polygon(value: Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for pair: Array in value:
		polygon.append(_point(pair))
	return polygon


func _interior_point(polygon: PackedVector2Array) -> Vector2:
	var triangles := Geometry2D.triangulate_polygon(polygon)
	if triangles.size() >= 3:
		return (polygon[triangles[0]] + polygon[triangles[1]] + polygon[triangles[2]]) / 3.0
	return polygon[0]


func _check(id: String, passed: bool, details: Variant = null) -> void:
	_checks.append({"id": id, "resolution": _resolution, "passed": passed, "details": details})
	if not passed:
		_failures.append("%s [%s]" % [id, _resolution])


func _write_report() -> void:
	var report := {
		"scene": SCENE_PATH,
		"created_utc": Time.get_datetime_string_from_system(true),
		"elapsed_ms": Time.get_ticks_msec() - _started_at,
		"godot_version": Engine.get_version_info().string,
		"display_server": DisplayServer.get_name(),
		"capture_enabled": _capture_enabled,
		"passed": _failures.is_empty(),
		"check_count": _checks.size(),
		"failure_count": _failures.size(),
		"failures": _failures,
		"checks": _checks,
		"captures": _captures,
		"water_animation": _motion_checks,
		"method": "Real Sanctuary scene, mouse/key events and fixed-step movement. Three earlier combat victories are explicit fixtures; all halt purchases, discoveries, departure and isolated snapshot restore use production GameManager services. Original player save is hash-checked unchanged.",
	}
	var file := FileAccess.open(OUTPUT_DIR + "/runtime_validation.json", FileAccess.WRITE)
	if file == null:
		_failures.append("runtime_validation.json could not be written")
		return
	file.store_string(JSON.stringify(report, "\t"))
