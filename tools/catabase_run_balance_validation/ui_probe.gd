extends Node
## Captures the two r6 decision screens, exercises their real controls and
## verifies one real delayed warning in the production depth-I battle.

const SCREEN := preload("res://ui/expedition/ExpeditionScreen.tscn")
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
const DIRECT_TEST_TREE_META := &"arena_studio_test_options"
const FRAIL_HELLSPAWN_ID := &"catabase_frail_hellspawn"
const SHADOW_BOLT_ID := &"catabase_hellspawn_shadow_bolt"

var _output_root := ""
var _checks: Array[Dictionary] = []
var _captures: Array[Dictionary] = []
var _telegraph_cases: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_root = _argument("output")
	if _output_root.is_empty():
		_output_root = ProjectSettings.globalize_path("user://catabase_ui_probe")
	DirAccess.make_dir_recursive_absolute(_output_root)
	_check(
		DisplayServer.get_name() != "headless",
		"capture uses a real display renderer",
		SIZES[0],
	)
	for viewport_size in SIZES:
		await _probe_departure(viewport_size)
		await _probe_final_preparation(viewport_size)
		await _probe_delayed_telegraph(viewport_size)
	GameManager.cleanup_run_state()
	await get_tree().process_frame
	var passed: bool = _checks.all(func(entry: Dictionary): return bool(entry.passed))
	var report: Dictionary = {
		"passed": passed,
		"checks": _checks,
		"captures": _captures,
		"telegraph_cases": _telegraph_cases,
		"contract": {
			"catalog_revision": 6,
			"screens": [
				"departure_review",
				"final_preparation_xix",
				"delayed_telegraph_d01",
			],
			"viewports": ["1280x720", "1920x1080"],
			"display_server": DisplayServer.get_name(),
			"rendering_method": RenderingServer.get_current_rendering_method(),
		},
	}
	var report_path: String = _output_root.path_join("report.json")
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write UI probe report: %s" % report_path)
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify({"passed": passed, "report": report_path}))
	get_tree().quit(0 if passed else 1)


func _probe_departure(viewport_size: Vector2i) -> void:
	await _reset_runtime(viewport_size)
	var screen := SCREEN.instantiate() as ExpeditionScreen
	add_child(screen)
	await _settle()
	_check(screen.get("_page") == "departure", "departure opens on the required step", viewport_size)
	for expected_step in range(1, 7):
		var next := screen.find_child("DepartureNext", true, false) as Button
		_check(_usable(next), "departure next step %d is usable" % expected_step, viewport_size)
		if next == null or next.disabled:
			break
		next.pressed.emit()
		await _settle()
	var review := screen.find_child("ConfirmCatabaseDeparture", true, false) as Button
	var difficulty := screen.find_child("CatabaseDifficulty", true, false) as OptionButton
	_check(_usable(review), "departure review confirmation is usable", viewport_size)
	_check(_usable(difficulty), "departure review difficulty selector is usable", viewport_size)
	if difficulty != null:
		difficulty.select(1)
		difficulty.item_selected.emit(1)
		await _settle()
		_check(
			str(difficulty.get_item_text(difficulty.selected)).begins_with("Facile"),
			"difficulty selector changes through its real signal",
			viewport_size,
		)
		_check(
			GameManager.expedition.route.difficulty_id == "normal",
			"difficulty remains local before confirmation",
			viewport_size,
		)
	await _capture("departure_review", viewport_size, [review, difficulty])
	screen.queue_free()
	await _settle()


func _probe_final_preparation(viewport_size: Vector2i) -> void:
	await _reset_runtime(viewport_size)
	var reached: bool = _reach_depth_nineteen()
	_check(reached, "production route reaches preparation-only depth XIX", viewport_size)
	if not reached:
		return
	var screen := SCREEN.instantiate() as ExpeditionScreen
	add_child(screen)
	await _settle()
	var session: ExpeditionSession = GameManager.expedition
	_check(screen.get("_page") == "hub", "depth XIX resolves to the hub presentation step", viewport_size)
	_check(session.hub_services(GameManager.item_catalog).is_empty(), "depth XIX exposes no service", viewport_size)
	var techniques: Button = _button_by_text(screen, "Réviser mes techniques")
	var inventory: Button = _button_by_text(screen, "Vérifier mon équipement")
	var continue_button := screen.find_child("LeaveFinalPreparation", true, false) as Button
	_check(_usable(techniques), "depth XIX techniques button is usable", viewport_size)
	_check(_usable(inventory), "depth XIX inventory button is usable", viewport_size)
	_check(_usable(continue_button), "depth XIX continue button is usable", viewport_size)
	await _capture(
		"final_preparation_xix",
		viewport_size,
		[techniques, inventory, continue_button],
	)

	if _usable(techniques):
		techniques.pressed.emit()
		await _settle()
		_check(
			screen.get("_page") == "build"
			and screen.find_child("SkillsTab_equipped", true, false) != null,
			"techniques button opens the real build screen",
			viewport_size,
		)
		var close_build := screen.find_child("CloseExpeditionScreen", true, false) as Button
		if _usable(close_build):
			close_build.pressed.emit()
			await _settle()
		_check(screen.get("_page") == "hub", "build screen returns to depth XIX", viewport_size)

	inventory = _button_by_text(screen, "Vérifier mon équipement")
	if _usable(inventory):
		inventory.pressed.emit()
		await _settle()
		var persistent: PersistentRunUI = GameManager.get_persistent_run_ui()
		_check(
			persistent != null and persistent.is_inventory_open(),
			"inventory button opens the real inventory modal",
			viewport_size,
		)
		if persistent != null and persistent.is_inventory_open():
			var close_inventory := persistent.inventory_screen.find_child(
				"CloseButton", true, false
			) as Button
			if _usable(close_inventory):
				close_inventory.pressed.emit()
				await _settle()
			_check(not persistent.is_inventory_open(), "inventory closes through its real button", viewport_size)

	continue_button = screen.find_child("LeaveFinalPreparation", true, false) as Button
	if _usable(continue_button):
		continue_button.pressed.emit()
		await _settle()
		_check(
			session.route.phase == "map" and session.route.completed_node_ids.size() == 19,
			"continue consumes depth XIX once and returns to the route",
			viewport_size,
		)
	screen.queue_free()
	await _settle()


func _probe_delayed_telegraph(viewport_size: Vector2i) -> void:
	await _reset_runtime(viewport_size)
	var session: ExpeditionSession = GameManager.expedition
	var preparation: Dictionary = session.prepare_start(
		CatabasePreparationCatalog.preset("marteau"),
		GameManager.run_inventory,
		GameManager.item_catalog,
	)
	_check(
		bool(preparation.get("success", false)),
		"depth-I telegraph fixture uses a legal Catabase preparation",
		viewport_size,
	)
	if not bool(preparation.get("success", false)):
		return
	var entered: bool = session.enter("d01_0")
	_check(entered, "production route enters Catabase depth I", viewport_size)
	if not entered:
		return
	var route_node: Dictionary = session.route.get_current_node()
	var room: RoomData = ExpeditionRunFactory.make_room(route_node, GameManager.run_seed)
	_check(
		room != null and room.battle_scene != null,
		"depth I resolves to a production battle scene",
		viewport_size,
	)
	if room == null or room.battle_scene == null:
		return
	GameManager.current_room_index = 0
	GameManager.current_wave_index = 0
	if GameManager.rooms.is_empty():
		GameManager.rooms.resize(1)
	GameManager.rooms[0] = room
	# Keep the actual room, encounter, formation, actors, views, camera, AI and
	# SpellCaster. Only automatic turn progression and HUD ownership are paused
	# so the capture can stop precisely after the delayed cast is prepared.
	get_tree().set_meta(
		DIRECT_TEST_TREE_META,
		{
			"active": true,
			"configuration": "catabase_delayed_telegraph_capture",
			"spawn_heroes": true,
			"spawn_enemies": true,
			"deployment_enabled": false,
			"combat_enabled": false,
			"hud_enabled": false,
		},
	)
	var battle: Node = room.battle_scene.instantiate()
	add_child(battle)
	get_tree().remove_meta(DIRECT_TEST_TREE_META)
	var deadline: int = Time.get_ticks_msec() + 20_000
	while not bool(battle.get("runtime_ready_state")) \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var ready: bool = bool(battle.get("runtime_ready_state"))
	_check(ready, "real depth-I Battle reaches runtime_ready", viewport_size)
	if not ready:
		await _close_battle(battle)
		return
	var enemy: Unit = null
	var hero: Unit = null
	for unit_value: Variant in battle.get("units"):
		var unit: Unit = unit_value as Unit
		if unit == null:
			continue
		if unit.unit_id == FRAIL_HELLSPAWN_ID:
			enemy = unit
		elif unit.team == 0:
			hero = unit
	_check(enemy != null, "canonical frail hellspawn is spawned", viewport_size)
	_check(hero != null, "canonical Achille is spawned", viewport_size)
	if enemy == null or hero == null:
		await _close_battle(battle)
		return
	var spell: Spell = null
	for candidate: Spell in enemy.spells:
		if candidate.get_effective_spell_id() == SHADOW_BOLT_ID:
			spell = candidate
			break
	_check(spell != null, "frail hellspawn owns the authored shadow bolt", viewport_size)
	var caster: SpellCaster = battle.get("spell_caster") as SpellCaster
	var layer: TacticalTelegraphLayer = battle.get("_tactical_telegraphs") as TacticalTelegraphLayer
	_check(caster != null, "real Battle owns its SpellCaster", viewport_size)
	_check(layer != null, "real Battle owns its telegraph layer", viewport_size)
	if spell == null or caster == null or layer == null:
		await _close_battle(battle)
		return
	_check(layer.get_parent() == battle.get("grid_view"), "telegraph follows the real grid", viewport_size)
	_check(layer.name == "TacticalTelegraphs" and layer.z_index == 20, "telegraph layer has its production ordering", viewport_size)
	enemy.start_turn()
	var legal: bool = caster.can_cast(enemy, spell, hero.grid_pos)
	_check(
		legal,
		"opening formation keeps the delayed shadow bolt legal without relocation",
		viewport_size,
	)
	if not legal:
		await _close_battle(battle)
		return
	var ap_before: int = enemy.current_ap
	var cast_report: Dictionary = caster.cast(enemy, spell, hero.grid_pos)
	await _settle()
	_check(not bool(cast_report.get("failed", false)), "real delayed cast resolves its preparation", viewport_size)
	_check(bool(cast_report.get("telegraphed", false)), "real cast reports a telegraphed action", viewport_size)
	_check(enemy.current_ap == ap_before - spell.ap_cost, "real cast spends its authored AP", viewport_size)
	_check(not enemy.pending_ability.is_empty(), "real enemy stores the pending attack", viewport_size)
	_check(layer.get_telegraph_count() == 1, "one warning is visible before resolution", viewport_size)
	if layer.get_telegraph_count() != 1:
		await _close_battle(battle)
		return
	var warning: Dictionary = layer.get_debug_snapshot()[0]
	var source_cell: Vector2i = warning.get("source_cell", Vector2i(-1, -1))
	var target_cell: Vector2i = warning.get("target_cell", Vector2i(-1, -1))
	var source_position: Vector2 = warning.get("source_position", Vector2.ZERO)
	var target_position: Vector2 = warning.get("target_position", Vector2.ZERO)
	var grid_view: Node2D = battle.get("grid_view") as Node2D
	var expected_source: Vector2 = grid_view.call("grid_to_world", source_cell)
	var expected_target: Vector2 = grid_view.call("grid_to_world", target_cell)
	_check(warning.get("spell_id", &"") == SHADOW_BOLT_ID, "warning identifies the real spell", viewport_size)
	_check(source_cell == enemy.grid_pos, "warning starts on the caster cell", viewport_size)
	_check(target_cell == hero.grid_pos, "warning tracks Achille's cell", viewport_size)
	_check(
		source_position == expected_source and target_position == expected_target,
		"warning positions use the production grid conversion",
		viewport_size,
	)
	_check(
		str(warning.get("label", "")) == "Trait d’ombre — brisez la ligne de vue",
		"warning exposes the authored counterplay label",
		viewport_size,
	)
	var source_screen: Vector2 = layer.get_global_transform_with_canvas() * source_position
	var target_screen: Vector2 = layer.get_global_transform_with_canvas() * target_position
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport_size)).grow(2.0)
	_check(
		viewport_rect.has_point(source_screen) and viewport_rect.has_point(target_screen),
		"warning line endpoints stay on-screen",
		viewport_size,
	)
	_check(source_screen.distance_to(target_screen) >= 48.0, "warning line has a readable span", viewport_size)
	_telegraph_cases.append(
		{
			"viewport": "%dx%d" % [viewport_size.x, viewport_size.y],
			"spell_id": str(warning.get("spell_id", &"")),
			"source_cell": [source_cell.x, source_cell.y],
			"target_cell": [target_cell.x, target_cell.y],
			"source_screen": [source_screen.x, source_screen.y],
			"target_screen": [target_screen.x, target_screen.y],
			"label": str(warning.get("label", "")),
			"ap_before": ap_before,
			"ap_after": enemy.current_ap,
		}
	)
	await _capture("delayed_telegraph_d01", viewport_size, [])
	await _close_battle(battle)


func _close_battle(battle: Node) -> void:
	if is_instance_valid(battle):
		battle.call("_begin_battle_shutdown")
		battle.queue_free()
	await _settle()


func _reset_runtime(viewport_size: Vector2i) -> void:
	GameManager.cleanup_run_state()
	await _settle()
	DisplayServer.window_set_size(viewport_size)
	get_tree().root.size = viewport_size
	var data: RunData = ExpeditionRunFactory.create(2401, {})
	var resolution := GameManager.resolve_run_hero_data(data, false)
	var prepared: bool = resolution.is_valid() and bool(
		GameManager.call("_prepare_preconfigured_run", data, resolution.heroes)
	)
	_check(prepared, "canonical Catabase runtime prepares", viewport_size)
	if not prepared:
		return
	GameManager.expedition = ExpeditionSession.new()
	GameManager.expedition.initialize(
		GameManager.get_character_state(&"achilles"),
		GameManager.run_seed,
		"normal",
		6,
	)
	GameManager.expedition.needs_preparation = true
	await _settle()


func _reach_depth_nineteen() -> bool:
	var session: ExpeditionSession = GameManager.expedition
	if session == null:
		return false
	var start: Dictionary = session.prepare_start(
		CatabasePreparationCatalog.preset("marteau"),
		GameManager.run_inventory,
		GameManager.item_catalog,
	)
	if not bool(start.get("success", false)):
		return false
	for depth in range(1, 20):
		var options: Array = session.route.get_available_nodes()
		if options.is_empty() or not session.enter(str(options[0].id)):
			return false
		if session.route.phase == "combat" and not session.combat_won():
			return false
		if not _resolve_advancement(session):
			return false
		if depth == ExpeditionBuildState.CAPACITY_DEPTH:
			if not bool(session.build.choose_depth_eight("slot").get("success", false)):
				return false
		if depth == 19:
			break
		var rewards: Array = session.reward_options(GameManager.item_catalog, GameManager.run_inventory)
		var reward_id: String = ""
		for candidate in rewards:
			if str(candidate.id) == "leave_hub":
				reward_id = "leave_hub"
				break
			if str(candidate.id) == "supplies":
				reward_id = "supplies"
		if reward_id.is_empty() and not rewards.is_empty():
			reward_id = str(rewards.back().id)
		if reward_id.is_empty() or not bool(
			session.claim(reward_id, GameManager.run_inventory, GameManager.item_catalog).get(
				"success", false
			)
		):
			return false
	var node: Dictionary = session.route.get_current_node()
	return int(node.get("depth", 0)) == 19 \
		and bool(node.get("preparation_only", false)) \
		and session.route.phase == "reward"


func _resolve_advancement(session: ExpeditionSession) -> bool:
	while not session.advancement_step.is_empty():
		if session.advancement_step == "progression":
			while session.character.champion_progression.unspent_attribute_points > 0:
				if not session.character.spend_champion_attribute(&"vitality"):
					return false
		if not bool(session.advance_level_step().get("success", false)):
			return false
	return true


func _capture(
		label: String,
		viewport_size: Vector2i,
		critical_controls: Array,
	) -> void:
	await _settle()
	await RenderingServer.frame_post_draw
	var suffix: String = "%dx%d" % [viewport_size.x, viewport_size.y]
	var path: String = _output_root.path_join("%s_%s.png" % [label, suffix])
	var image: Image = get_tree().root.get_texture().get_image()
	var saved: bool = image != null and image.save_png(path) == OK
	_check(saved, "%s screenshot is written" % label, viewport_size)
	_check(
		image != null and image.get_size() == viewport_size,
		"%s screenshot has the requested resolution" % label,
		viewport_size,
	)
	_check(
		image != null and _image_has_visible_variance(image),
		"%s screenshot contains rendered visual information" % label,
		viewport_size,
	)
	var controls: Array[Dictionary] = []
	for control in critical_controls:
		if control is Control:
			var rect: Rect2 = control.get_global_rect()
			var visible_area: Rect2 = rect.intersection(
				Rect2(Vector2.ZERO, Vector2(viewport_size))
			)
			var on_screen: bool = (
				(control as Control).is_visible_in_tree()
				and visible_area.get_area() > 0.0
			)
			_check(on_screen, "%s critical control stays on-screen" % label, viewport_size)
			controls.append({
				"name": str(control.name),
				"text": str(control.get("text")),
				"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
				"visible": on_screen,
			})
	_captures.append({
		"screen": label,
		"viewport": suffix,
		"path": path,
		"controls": controls,
	})


func _image_has_visible_variance(image: Image) -> bool:
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		return false
	var x_step: int = maxi(1, image.get_width() / 32)
	var y_step: int = maxi(1, image.get_height() / 18)
	var minimum_luminance: float = 1.0
	var maximum_luminance: float = 0.0
	var visible_samples: int = 0
	for y in range(0, image.get_height(), y_step):
		for x in range(0, image.get_width(), x_step):
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.05:
				continue
			visible_samples += 1
			minimum_luminance = minf(minimum_luminance, color.get_luminance())
			maximum_luminance = maxf(maximum_luminance, color.get_luminance())
	return visible_samples >= 32 and maximum_luminance - minimum_luminance >= 0.04


func _button_by_text(root: Node, text: String) -> Button:
	for candidate in root.find_children("*", "Button", true, false):
		if candidate is Button and candidate.text == text:
			return candidate
	return null


func _usable(control: Control) -> bool:
	return control != null and control.is_visible_in_tree() \
		and (not (control is BaseButton) or not control.disabled)


func _check(passed: bool, label: String, viewport_size: Vector2i) -> void:
	_checks.append({
		"passed": passed,
		"label": label,
		"viewport": "%dx%d" % [viewport_size.x, viewport_size.y],
	})
	if not passed:
		push_error("UI probe: %s (%dx%d)" % [label, viewport_size.x, viewport_size.y])


func _settle() -> void:
	for frame in 4:
		await get_tree().process_frame


func _argument(key: String) -> String:
	for raw in OS.get_cmdline_user_args():
		var value: String = str(raw)
		if value.begins_with(key + "="):
			return value.trim_prefix(key + "=")
	return ""
