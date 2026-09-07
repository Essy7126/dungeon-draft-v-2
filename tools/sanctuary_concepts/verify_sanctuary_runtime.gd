extends SceneTree

## Exercices de la scène réelle. Ajouter -- --capture avec un renderer actif.
const SCENE_PATH := "res://hub/sanctuary_prototype/SanctuaryPrototype.tscn"
const OUTPUT_DIR := "res://artifacts/sanctuary_prototype"
const STEP := 1.0 / 60.0
const MAX_MOVEMENT_STEPS := 2400

var _hub: Node
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _captures: Array[Dictionary] = []
var _motion_checks: Array[Dictionary] = []
var _resolution := ""
var _capture_enabled := false
var _started_at := 0


func _initialize() -> void:
	_started_at = Time.get_ticks_msec()
	_capture_enabled = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed := load(SCENE_PATH) as PackedScene
	_check("scene_loads", packed != null, SCENE_PATH)
	if packed != null:
		for resolution: Vector2i in [Vector2i(1600, 900), Vector2i(1200, 896)]:
			_resolution = "%dx%d" % [resolution.x, resolution.y]
			root.size = resolution
			_hub = packed.instantiate()
			root.add_child(_hub)
			current_scene = _hub
			var ready_deadline := Time.get_ticks_msec() + 10000
			while _hub.has_method("is_ready_for_play") and not bool(_hub.call("is_ready_for_play")) and Time.get_ticks_msec() < ready_deadline:
				await process_frame
			var ready := _hub.has_method("is_ready_for_play") and bool(_hub.call("is_ready_for_play"))
			_check("scene_ready_within_10_seconds", ready)
			if ready:
				_hub.set_process(false)
				await _exercise_scene()
			_hub.queue_free()
			await process_frame
			await process_frame
			_hub = null
	_write_report()
	for failure: String in _failures:
		push_error("SANCTUARY_RUNTIME: " + failure)
	print("SANCTUARY_RUNTIME: %s (%d checks, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _checks.size(), _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _exercise_scene() -> void:
	var api_ok := true
	for method: String in ["request_move", "interact_with", "get_player_position", "get_session", "get_panels", "reset_visit", "_process"]:
		var exists := _hub.has_method(method)
		_check("public_api_" + method, exists)
		api_ok = api_ok and exists
	if not api_ok:
		return
	var layout: Dictionary = _hub.get("layout")
	var nav: RefCounted = _hub.get("nav")
	var panels: Control = _hub.call("get_panels")
	var session: RefCounted = _hub.call("get_session")
	var spawn := _point(layout.get("spawn", [0, 0]))
	var entities: Array = layout.get("entities", [])
	_check("no_node3d", _hub.find_children("*", "Node3D", true, false).is_empty())
	_check("no_subviewport", _hub.find_children("*", "SubViewport", true, false).is_empty())
	_check("initial_panels_closed", not bool(panels.call("is_open")))
	_check("initial_spawn_walkable", bool(nav.call("is_walkable", _position())))
	_check("initial_spawn_matches_layout", _position().distance_to(spawn) <= 2.0)
	_check("initial_balance", int(session.call("get_drachmes")) == 120)
	_check("entities_present", entities.size() >= 3)
	_validate_shaders()
	_validate_residents()
	_validate_routes(layout, nav)
	if _capture_enabled:
		var initial := await _capture("initial")
		await create_timer(0.8).timeout
		var animated := await _capture("initial_after800ms")
		if initial != null and animated != null:
			var water_motion := _measure_water_motion(initial, animated, layout)
			_motion_checks.append(water_motion)
			_check("water_animates_on_rendered_pixels", int(water_motion.changed_samples) > 0, water_motion)

	var merchant := _entity(layout, "merchant")
	var oracle := _entity(layout, "oracle")
	_check("merchant_and_oracle_present", not merchant.is_empty() and not oracle.is_empty())
	if merchant.is_empty() or oracle.is_empty():
		return
	var merchant_approach := _point(merchant.approach)
	var before_move := _position()
	await _click_native(_point(merchant.position))
	_check("merchant_stays_closed_before_arrival", not bool(panels.call("is_open")))
	_check("interaction_does_not_teleport", _position().is_equal_approx(before_move))
	_hub.call("_process", STEP)
	_check("merchant_click_starts_approach", _position().distance_to(before_move) > 0.1 and not bool(panels.call("is_open")))
	var arrived := await _advance_to(merchant_approach, true)
	_check("merchant_opens_only_at_approach", arrived and bool(panels.call("is_open")) and _position().distance_to(merchant_approach) <= 24.0, _position_data())
	if not arrived:
		return
	await _settle_ui()
	await _capture("shop")
	var frozen_position := _position()
	_check("modal_refuses_world_movement", not bool(_hub.call("request_move", spawn)))
	_hub.call("_process", 0.25)
	_check("modal_keeps_achilles_still", _position().is_equal_approx(frozen_position))
	var buy := panels.find_child("Buy_nectar_des_sources", true, false) as Button
	_check("real_purchase_button_present", buy != null and not buy.disabled)
	if buy != null and not buy.disabled:
		await _click_button(buy)
	_check("button_purchase_debits_balance", int(session.call("get_drachmes")) == 95)
	var inventory: Dictionary = session.call("get_inventory")
	_check("button_purchase_adds_inventory", int(inventory.get(&"nectar_des_sources", 0)) == 1)
	_check("button_purchase_updates_display", (panels.find_child("DrachmesBalance", true, false) as Label).text == "95 drachmes")
	var stocks: Array = session.call("get_shop_items")
	var nectar_stock := -1
	for item: Dictionary in stocks:
		if String(item.id) == "nectar_des_sources":
			nectar_stock = int(item.stock)
	_check("button_purchase_decrements_stock", nectar_stock == 1)
	await _click_button(panels.find_child("ClosePanel", true, false) as Button)
	_check("button_close_restores_world", not bool(panels.call("is_open")) and bool(_hub.call("request_move", spawn)))
	_check("movement_resumes_after_close", await _advance_to(spawn, false))

	# Une intention en cours doit être remplacée par un véritable clic sur le sol.
	_check("oracle_intent_accepted", bool(_hub.call("interact_with", &"oracle")))
	_hub.call("_process", STEP * 2.0)
	_check("oracle_stays_closed_before_arrival", not bool(panels.call("is_open")))
	await _click_native(spawn)
	var returned_to_floor := await _advance_to(spawn, false)
	for _frame in range(180):
		_hub.call("_process", STEP)
	_check("floor_click_replaces_entity_intent", returned_to_floor and not bool(panels.call("is_open")) and _position().distance_to(spawn) <= 2.0, _position_data())

	var water_polygons: Array = layout.get("water_polygons", [])
	_check("water_mask_present", not water_polygons.is_empty())
	for index in range(water_polygons.size()):
		var water_point := _interior_point(_polygon(water_polygons[index]))
		var before_water := _position()
		_check("water_destination_%d_refused" % index, not bool(_hub.call("request_move", water_point)))
		_hub.call("_process", 0.25)
		_check("water_destination_%d_no_teleport" % index, _position().is_equal_approx(before_water))

	_check("oracle_second_intent_accepted", bool(_hub.call("interact_with", &"oracle")))
	var oracle_approach := _point(oracle.approach)
	var oracle_arrived := await _advance_to(oracle_approach, true)
	_check("oracle_opens_only_at_approach", oracle_arrived and bool(panels.call("is_open")) and _position().distance_to(oracle_approach) <= 24.0, _position_data())
	if not oracle_arrived:
		return
	await _settle_ui()
	await _capture("oracle")
	var confirm := panels.find_child("ConfirmBlessing", true, false) as Button
	_check("oracle_requires_explicit_selection", confirm != null and confirm.disabled)
	var athena := panels.find_child("Select_athena", true, false) as Button
	_check("athena_button_present", athena != null and not athena.disabled)
	if athena == null or confirm == null:
		return
	await _click_button(athena)
	var chosen: Dictionary = session.call("get_selected_blessing")
	_check("selection_alone_does_not_commit", chosen.is_empty())
	confirm = panels.find_child("ConfirmBlessing", true, false) as Button
	_check("confirmation_becomes_available", confirm != null and not confirm.disabled)
	if confirm != null:
		await _click_button(confirm)
	chosen = session.call("get_selected_blessing")
	_check("confirmation_commits_athena", String(chosen.get("id", "")) == "athena")
	var hermes := panels.find_child("Select_hermes", true, false) as Button
	_check("second_blessing_button_disabled", hermes != null and hermes.disabled)
	if hermes != null:
		await _click_button(hermes)
	chosen = session.call("get_selected_blessing")
	_check("disabled_button_cannot_replace_blessing", String(chosen.get("id", "")) == "athena")
	var repeated: Dictionary = session.call("choose_blessing", &"hermes")
	_check("session_also_rejects_double_choice", not bool(repeated.get("ok", true)))
	await _capture("oracle_chosen")
	await _click_button(panels.find_child("ClosePanel", true, false) as Button)
	_check("oracle_close_restores_control", not bool(panels.call("is_open")) and bool(_hub.call("request_move", spawn)))
	_check("return_from_oracle", await _advance_to(spawn, false))
	_hub.call("reset_visit")
	await _settle_ui()
	_check("reset_restores_balance", int(session.call("get_drachmes")) == 120)
	_check("reset_clears_inventory", (session.call("get_inventory") as Dictionary).is_empty())
	_check("reset_clears_blessing", (session.call("get_selected_blessing") as Dictionary).is_empty())
	_check("reset_returns_to_spawn", _position().distance_to(spawn) <= 2.0)


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
			await process_frame
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
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = point
	up.global_position = point
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _settle_ui() -> void:
	await process_frame
	await process_frame
	await process_frame


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
		"method": "Real SanctuaryPrototype scene; fixed-step controller movement; native floor click; viewport clicks on actual UI buttons. Pixel animation checks use only the painted water polygons.",
	}
	var file := FileAccess.open(OUTPUT_DIR + "/runtime_validation.json", FileAccess.WRITE)
	if file == null:
		_failures.append("runtime_validation.json could not be written")
		return
	file.store_string(JSON.stringify(report, "\t"))
