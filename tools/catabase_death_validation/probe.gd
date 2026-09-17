extends Node
## GPU proof for the real Catabase defeat flow. The controller detaches from
## SceneTree.current_scene so production scene changes can replace Expedition,
## Battle, RunResultScreen, selection and title scenes without destroying it.

const RESULT_SCENE_PATH := "res://ui/RunResultScreen.tscn"
const SELECTION_SCENE_PATH := "res://ui/selection/CharacterSelectionScreen.tscn"
const TITLE_SCENE_PATH := "res://ui/TitreEcran.tscn"
const EXPEDITION_SCENE_PATH := "res://ui/expedition/ExpeditionScreen.tscn"
const INTRO_SCENE_PATH := "res://cinematics/intro/intro_cinematic.tscn"
const PROBE_SAVE_PATH := "user://catabase_death_validation.json"
const SEED := 2401
const SCENE_TIMEOUT_MS := 20_000
const BATTLE_TIMEOUT_MS := 30_000

var _output_root := ""
var _checks: Array[Dictionary] = []
var _captures: Array[Dictionary] = []
var _cases: Array[Dictionary] = []
var _requested_paths: Array[String] = []
var _original_save_path := ""


func _ready() -> void:
	# Production navigation may now replace the launched probe scene while this
	# controller remains a sibling owned by the root Window.
	if get_tree().current_scene == self:
		get_tree().current_scene = null
	call_deferred("_run")


func _run() -> void:
	_output_root = _argument("output")
	if _output_root.is_empty():
		_output_root = ProjectSettings.globalize_path("user://catabase_death_validation")
	DirAccess.make_dir_recursive_absolute(_output_root)
	_original_save_path = GameManager.expedition_save_path
	GameManager.expedition_save_path = PROBE_SAVE_PATH
	GameManager.set_reduced_motion_enabled(true)
	if not GameManager.scene_change_requested.is_connected(_on_scene_change_requested):
		GameManager.scene_change_requested.connect(_on_scene_change_requested)
	_check(
		DisplayServer.get_name() != "headless",
		"capture uses a real display renderer",
		Vector2i(1280, 720),
	)
	_check(
		RenderingServer.get_current_rendering_method() != "dummy",
		"capture does not use the dummy renderer",
		Vector2i(1280, 720),
	)

	await _run_retry_case(Vector2i(1280, 720))
	await _run_menu_case(Vector2i(1920, 1080))
	await _cleanup_runtime()
	GameManager.expedition_save_path = _original_save_path
	if GameManager.scene_change_requested.is_connected(_on_scene_change_requested):
		GameManager.scene_change_requested.disconnect(_on_scene_change_requested)

	var passed: bool = _checks.all(
		func(entry: Dictionary) -> bool: return bool(entry.get("passed", false))
	)
	var report: Dictionary = {
		"passed": passed,
		"checks": _checks,
		"captures": _captures,
		"cases": _cases,
		"contract": {
			"reference_seed": SEED,
			"save_path": PROBE_SAVE_PATH,
			"isolated_user_data": ProjectSettings.globalize_path("user://"),
			"viewports": ["1280x720", "1920x1080"],
			"display_server": DisplayServer.get_name(),
			"rendering_method": RenderingServer.get_current_rendering_method(),
			"adapter": RenderingServer.get_video_adapter_name(),
			"flows": ["defeat_to_retry", "defeat_to_main_menu"],
		},
	}
	var report_path: String = _output_root.path_join("report.json")
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write Catabase death validation report: %s" % report_path)
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify({"passed": passed, "report": report_path}))
	get_tree().quit(0 if passed else 1)


func _run_retry_case(viewport_size: Vector2i) -> void:
	var started: Dictionary = await _start_real_battle(viewport_size, "")
	if not bool(started.get("success", false)):
		return
	var battle: Node = started.get("battle") as Node
	var death: Dictionary = await _kill_real_hero(battle, viewport_size, "achille")
	if not bool(death.get("success", false)):
		return
	var result_screen: Node = death.get("result_screen") as Node
	var snapshot: Dictionary = death.get("snapshot", {})
	await _validate_result_screen(
		result_screen,
		snapshot,
		viewport_size,
		"defeat_achille",
		"Achille",
	)
	var new_attempt: Button = result_screen.get_node_or_null("%NewAttemptButton") as Button
	var menu: Button = result_screen.get_node_or_null("%MenuButton") as Button
	if new_attempt == null or menu == null:
		return
	var selection_requests_before := _count_requested_path(SELECTION_SCENE_PATH)
	new_attempt.pressed.emit()
	_check(
		bool(result_screen.call("is_navigation_pending")),
		"new-attempt action becomes pending immediately",
		viewport_size,
	)
	_check(
		new_attempt.disabled and menu.disabled,
		"both result actions lock after the retry request",
		viewport_size,
	)
	new_attempt.pressed.emit()
	var direct_repeat: bool = GameManager.request_new_catabase_attempt()
	_check(
		not direct_repeat,
		"consumed Catabase result rejects a repeated retry request",
		viewport_size,
	)
	_check(
		_count_requested_path(SELECTION_SCENE_PATH) == selection_requests_before + 1,
		"retry requests exactly one selection transition",
		viewport_size,
	)
	var selection: Node = await _wait_for_scene(SELECTION_SCENE_PATH, SCENE_TIMEOUT_MS)
	_check(selection != null, "retry opens the real character selection", viewport_size)
	if selection == null:
		return
	_check(
		GameManager.expedition == null and not GameManager.run_active,
		"retry discards the dead expedition state",
		viewport_size,
	)
	_check(
		GameManager.get_ordered_heroes().is_empty(),
		"retry does not reuse the dead hero",
		viewport_size,
	)
	_check(
		GameManager.get_last_run_result().is_empty(),
		"retry consumes the terminal result exactly once",
		viewport_size,
	)
	_validate_no_resume(viewport_size, "retry selection")
	await _validate_selection_and_prepare_passe_rive(selection, viewport_size)


func _run_menu_case(viewport_size: Vector2i) -> void:
	var started: Dictionary = await _start_real_battle(viewport_size, "passe_rive")
	if not bool(started.get("success", false)):
		return
	var battle: Node = started.get("battle") as Node
	var death: Dictionary = await _kill_real_hero(battle, viewport_size, "passe_rive")
	if not bool(death.get("success", false)):
		return
	var result_screen: Node = death.get("result_screen") as Node
	var snapshot: Dictionary = death.get("snapshot", {})
	await _validate_result_screen(
		result_screen,
		snapshot,
		viewport_size,
		"defeat_passe_rive",
		"Passe-rive",
	)
	var menu: Button = result_screen.get_node_or_null("%MenuButton") as Button
	var new_attempt: Button = result_screen.get_node_or_null("%NewAttemptButton") as Button
	if menu == null or new_attempt == null:
		return
	var title_requests_before := _count_requested_path(TITLE_SCENE_PATH)
	menu.pressed.emit()
	_check(
		bool(result_screen.call("is_navigation_pending")),
		"menu action becomes pending immediately",
		viewport_size,
	)
	_check(
		menu.disabled and new_attempt.disabled,
		"both result actions lock after the menu request",
		viewport_size,
	)
	menu.pressed.emit()
	_check(
		_count_requested_path(TITLE_SCENE_PATH) == title_requests_before + 1,
		"menu requests exactly one title transition",
		viewport_size,
	)
	var title: Node = await _wait_for_scene(TITLE_SCENE_PATH, SCENE_TIMEOUT_MS)
	_check(title != null, "menu action opens the real main menu", viewport_size)
	if title == null:
		return
	_check(
		GameManager.expedition == null and not GameManager.run_active,
		"main-menu action clears the finished expedition state",
		viewport_size,
	)
	_check(
		GameManager.get_last_run_result().is_empty(),
		"main-menu action clears the consumed result",
		viewport_size,
	)
	_validate_no_resume(viewport_size, "main menu")
	_check(
		title.find_child("BoutonReprendreCatabase", true, false) == null,
		"main menu exposes no resume action for the dead run",
		viewport_size,
	)
	var new_game: Button = title.find_child("BoutonNouvellePartie", true, false) as Button
	_check(_usable(new_game), "main menu keeps the new-game action usable", viewport_size)
	await _capture("main_menu_after_defeat", viewport_size, [new_game])


func _start_real_battle(viewport_size: Vector2i, variant: String) -> Dictionary:
	await _cleanup_runtime()
	DisplayServer.window_set_size(viewport_size)
	get_tree().root.size = viewport_size
	await _settle()
	_validate_no_resume(viewport_size, "case start")
	var variants: Dictionary = {} if variant.is_empty() else {"achilles": variant}
	var started: bool = GameManager.start_expedition(
		SEED,
		variants,
		false,
		true,
		"normal",
	)
	_check(started, "public Catabase preparation starts", viewport_size)
	if not started:
		return {"success": false}
	_check(GameManager.run_active, "Catabase run is active before combat", viewport_size)
	var heroes: Array = GameManager.get_ordered_heroes()
	_check(heroes.size() == 1, "Catabase owns exactly one hero", viewport_size)
	if heroes.size() != 1:
		return {"success": false}
	var prepared_hero: Unit = heroes[0] as Unit
	_check(
		prepared_hero != null and prepared_hero.unit_id == &"achilles",
		"Catabase runtime hero is Achille, never the archived trio",
		viewport_size,
	)
	var checkpoint_before_death := ExpeditionSaveService.fingerprint(PROBE_SAVE_PATH)
	_check(
		checkpoint_before_death != "absent",
		"combat preparation writes an isolated resumable checkpoint",
		viewport_size,
	)
	var retry_while_active: bool = GameManager.request_new_catabase_attempt()
	_check(
		not retry_while_active,
		"new-attempt API cannot discard an active expedition",
		viewport_size,
	)
	_check(
		ExpeditionSaveService.fingerprint(PROBE_SAVE_PATH) == checkpoint_before_death,
		"rejected retry leaves the active checkpoint unchanged",
		viewport_size,
	)
	var expedition_screen: Node = await _wait_for_scene(
		EXPEDITION_SCENE_PATH,
		SCENE_TIMEOUT_MS,
	)
	_check(
		expedition_screen != null,
		"production preparation scene opens before battle",
		viewport_size,
	)
	if expedition_screen == null:
		return {"success": false}
	var preparation: Dictionary = GameManager.confirm_catabase_preparation(
		CatabasePreparationCatalog.preset("marteau")
	)
	_check(
		bool(preparation.get("success", false)) and bool(preparation.get("saved", false)),
		"a legal six-part Catabase build enters depth I",
		viewport_size,
	)
	if not bool(preparation.get("success", false)):
		return {"success": false}
	var room: RoomData = GameManager.get_current_room()
	var battle_path := ""
	if room != null and room.battle_scene != null:
		battle_path = room.battle_scene.resource_path
	_check(not battle_path.is_empty(), "depth I resolves a production Battle scene", viewport_size)
	if battle_path.is_empty():
		return {"success": false}
	var battle: Node = await _wait_for_scene(battle_path, BATTLE_TIMEOUT_MS)
	_check(battle != null, "production depth-I Battle opens", viewport_size)
	if battle == null:
		return {"success": false}
	var ready: bool = await _wait_for_battle_ready(battle, BATTLE_TIMEOUT_MS)
	_check(ready, "production Battle reaches runtime_ready", viewport_size)
	if not ready:
		return {"success": false}
	var deployment: Dictionary = await _complete_real_deployment(battle, viewport_size)
	if not bool(deployment.get("success", false)):
		return {"success": false}
	var case_record: Dictionary = {
		"viewport": _viewport_label(viewport_size),
		"variant": "achille" if variant.is_empty() else variant,
		"battle_scene": battle_path,
		"checkpoint_before_death": checkpoint_before_death,
		"deployment_cell": deployment.get("cell", []),
	}
	_cases.append(case_record)
	return {"success": true, "battle": battle, "case": case_record}


func _complete_real_deployment(
		battle: Node,
		viewport_size: Vector2i,
	) -> Dictionary:
	var deployment: DeploymentController = battle.get("_deployment") as DeploymentController
	_check(deployment != null, "production Battle owns its deployment controller", viewport_size)
	if deployment == null:
		return {"success": false}
	_check(deployment.is_active(), "manual deployment is active before hero placement", viewport_size)
	var start_callback := Callable(battle, "_start_battle")
	_check(
		deployment.deployment_completed.is_connected(start_callback),
		"deployment completion is bound to the real Battle start",
		viewport_size,
	)
	var deploy_ui: CanvasLayer = deployment.get("_deploy_ui") as CanvasLayer
	var deploy_label: Label = deployment.get("_deploy_label") as Label
	_check(
		deploy_ui != null and deploy_label != null \
			and not deploy_label.text.strip_edges().is_empty(),
		"deployment exposes its real placement instructions",
		viewport_size,
	)
	var panel: Control = null
	if deploy_ui != null and deploy_ui.get_child_count() > 0:
		panel = deploy_ui.get_child(0) as Control
	_check(
		_control_on_screen(panel, viewport_size),
		"deployment instructions stay on-screen",
		viewport_size,
	)
	var zone_value: Variant = deployment.get("_deploy_zone")
	var zone: Array = zone_value if zone_value is Array else []
	var grid: GridData = battle.get("grid") as GridData
	_check(grid != null, "deployment uses the real combat grid", viewport_size)
	if grid == null:
		return {"success": false}
	var cell := Vector2i(-1, -1)
	for cell_value: Variant in zone:
		var candidate := cell_value as Vector2i
		if grid.is_walkable(candidate) and not grid.has_unit(candidate):
			cell = candidate
			break
	_check(cell != Vector2i(-1, -1), "deployment has a legal authored hero cell", viewport_size)
	if cell == Vector2i(-1, -1):
		return {"success": false}
	# Exercise the same Battle click router used by the production grid.
	battle.call("_on_cell_clicked", cell)
	var deadline: int = Time.get_ticks_msec() + SCENE_TIMEOUT_MS
	var hero: Unit = null
	while is_instance_valid(battle) and Time.get_ticks_msec() < deadline:
		var units_value: Variant = battle.get("units")
		if units_value is Array:
			for unit_value: Variant in units_value:
				var unit: Unit = unit_value as Unit
				if unit != null and unit.team == 0:
					hero = unit
					break
		if hero != null and not deployment.is_active():
			break
		await get_tree().process_frame
	_check(hero != null, "real deployment places the Catabase hero", viewport_size)
	_check(not deployment.is_active(), "real deployment completes after solo placement", viewport_size)
	_check(
		hero != null and hero.grid_pos == cell \
			and grid.get_unit(cell) == hero,
		"deployed hero is registered on the real combat grid",
		viewport_size,
	)
	_check(
		hero != null and hero.died.is_connected(Callable(battle, "_on_unit_died")),
		"deployed hero death is bound to Battle outcome handling",
		viewport_size,
	)
	await _settle()
	return {
		"success": hero != null and not deployment.is_active(),
		"cell": [cell.x, cell.y],
	}


func _kill_real_hero(
		battle: Node,
		viewport_size: Vector2i,
		case_id: String,
	) -> Dictionary:
	var hero: Unit = null
	var attacker: Unit = null
	var units_value: Variant = battle.get("units")
	if units_value is Array:
		for unit_value: Variant in units_value:
			var unit: Unit = unit_value as Unit
			if unit == null:
				continue
			if unit.team == 0 and hero == null:
				hero = unit
			elif unit.team == 1 and attacker == null:
				attacker = unit
	_check(hero != null, "real Battle contains the Catabase hero", viewport_size)
	_check(attacker != null, "real Battle contains an authored enemy source", viewport_size)
	if hero == null or attacker == null:
		return {"success": false}
	var hp_before: int = hero.current_hp
	var damage_result: DamageResolver.DamageResult = hero.take_damage(
		1_000_000,
		attacker,
		Spell.DamageType.PHYSICAL,
		Spell.Element.NONE,
		{
			"ignore_defense": true,
			"cannot_be_dodged": true,
			"skip_vulnerability": true,
			"skip_outgoing": true,
			"action_id": StringName("death_probe_%s" % case_id),
			"impact_id": StringName("death_probe_%s:000" % case_id),
			"attack_classification": &"MELEE",
		},
	)
	_check(
		damage_result != null and not damage_result.dodged,
		"controlled lethal hit uses the real Unit damage pipeline",
		viewport_size,
	)
	_check(
		hero.current_hp == 0 and not hero.is_alive,
		"real Catabase hero dies from the controlled hit",
		viewport_size,
	)
	var result_screen: Node = await _wait_for_scene(RESULT_SCENE_PATH, BATTLE_TIMEOUT_MS)
	_check(
		result_screen != null,
		"GameManager opens the real run-result screen after defeat",
		viewport_size,
	)
	if result_screen == null:
		return {"success": false}
	var snapshot: Dictionary = GameManager.get_last_run_result()
	_check(not snapshot.is_empty(), "defeat records a terminal result snapshot", viewport_size)
	_check(not bool(snapshot.get("victory", true)), "terminal snapshot records defeat", viewport_size)
	_check(bool(snapshot.get("is_catabase", false)), "terminal snapshot identifies Catabase", viewport_size)
	_check(bool(snapshot.get("is_expedition", false)), "terminal snapshot uses expedition facts", viewport_size)
	_check(not GameManager.run_active, "defeat closes the active run", viewport_size)
	_validate_no_resume(viewport_size, "terminal result")
	var case_record: Dictionary = _cases.back()
	case_record["hero_hp_before"] = hp_before
	case_record["hero_hp_after"] = hero.current_hp
	case_record["damage"] = damage_result.hp_damage_applied if damage_result != null else 0
	case_record["result"] = snapshot.duplicate(true)
	return {
		"success": true,
		"result_screen": result_screen,
		"snapshot": snapshot,
	}


func _validate_result_screen(
		result_screen: Node,
		snapshot: Dictionary,
		viewport_size: Vector2i,
		capture_label: String,
		expected_name: String,
	) -> void:
	await _settle()
	var background: TextureRect = result_screen.get_node_or_null("%Background") as TextureRect
	var panel: Control = result_screen.get_node_or_null("%Panel") as Control
	var result_label: Label = result_screen.get_node_or_null("%Result") as Label
	var location: Label = result_screen.get_node_or_null("%Location") as Label
	var progression: Label = result_screen.get_node_or_null("%Progression") as Label
	var hero_status: Label = result_screen.get_node_or_null("%HeroStatus") as Label
	var seed: Label = result_screen.get_node_or_null("%Seed") as Label
	var stats: Control = result_screen.get_node_or_null("%Stats") as Control
	var new_attempt: Button = result_screen.get_node_or_null("%NewAttemptButton") as Button
	var menu: Button = result_screen.get_node_or_null("%MenuButton") as Button
	var feedback: Label = result_screen.get_node_or_null("%NavigationFeedback") as Label
	_check(
		background != null and panel != null and result_label != null and location != null,
		"run-result scene exposes its public visual contract",
		viewport_size,
	)
	_check(
		progression != null and hero_status != null and seed != null and stats != null,
		"run-result scene exposes progress, hero and metadata controls",
		viewport_size,
	)
	_check(
		new_attempt != null and menu != null and feedback != null,
		"run-result scene exposes both navigation actions and feedback",
		viewport_size,
	)
	if background == null or new_attempt == null or menu == null:
		return
	var captured: Texture2D = GameManager.get_post_combat_background_texture()
	var captured_image: Image = captured.get_image() if captured != null else null
	_check(captured != null, "defeat captures the final Battle frame", viewport_size)
	_check(
		background.texture == captured,
		"result background displays the captured final Battle frame",
		viewport_size,
	)
	_check(
		captured_image != null and captured_image.get_size() == viewport_size,
		"captured final Battle frame matches the viewport",
		viewport_size,
	)
	_check(
		captured_image != null and _image_has_visible_variance(captured_image),
		"captured final Battle frame contains rendered board information",
		viewport_size,
	)
	_check(
		result_label != null and result_label.text == "LE FIL SE ROMPT",
		"defeat screen uses the authored Catabase title",
		viewport_size,
	)
	_check(
		location != null and not location.text.strip_edges().is_empty(),
		"defeat screen names the last route location",
		viewport_size,
	)
	_check(
		hero_status != null and expected_name.to_lower() in hero_status.text.to_lower(),
		"defeat screen names the selected Catabase appearance",
		viewport_size,
	)
	_check(
		str(snapshot.get("featured_hero_name", "")) == expected_name,
		"result snapshot keeps the selected Catabase appearance",
		viewport_size,
	)
	_check(
		str(snapshot.get("difficulty_id", "")) == "normal",
		"result screen facts keep Normal difficulty",
		viewport_size,
	)
	_check(_usable(new_attempt), "new-attempt action is usable", viewport_size)
	_check(_usable(menu), "main-menu action is usable", viewport_size)
	_check(
		result_screen.get("return_button") == menu,
		"legacy return-button alias resolves to the main-menu action",
		viewport_size,
	)
	_check(
		not bool(result_screen.call("is_navigation_pending")),
		"result navigation starts idle",
		viewport_size,
	)
	await _capture(
		capture_label,
		viewport_size,
		[
			panel,
			result_label,
			location,
			progression,
			hero_status,
			seed,
			stats,
			new_attempt,
			menu,
		],
	)


func _validate_selection_and_prepare_passe_rive(
		selection: Node,
		viewport_size: Vector2i,
	) -> void:
	await _settle()
	var entries_value: Variant = selection.call("get_entries")
	var entries: Array = entries_value if entries_value is Array else []
	_check(entries.size() == 3, "public selection exposes the three Achille appearances", viewport_size)
	var passe_rive_index := -1
	var only_catabase_achilles := not entries.is_empty()
	var ids: Array[String] = []
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var unit: UnitData = entry.get("unit") as UnitData
		var run: RunData = entry.get("run") as RunData
		var entry_id := str(entry.get("id", ""))
		ids.append(entry_id)
		if entry_id == "achilles_passe_rive":
			passe_rive_index = index
		only_catabase_achilles = only_catabase_achilles \
			and unit != null and unit.get_effective_unit_id() == &"achilles" \
			and run != null and run.catabase_route_enabled
	_check(
		only_catabase_achilles,
		"public selection contains only solo Catabase entries",
		viewport_size,
	)
	_check(
		not ids.has("elf") and not ids.has("mage") and not ids.has("warrior"),
		"public selection contains no archived trio entry",
		viewport_size,
	)
	_check(passe_rive_index >= 0, "public selection contains Passe-rive", viewport_size)
	if passe_rive_index < 0:
		return
	var roster_value: Variant = selection.get("_roster_buttons")
	var roster: Array = roster_value if roster_value is Array else []
	var passe_rive_button: Button = (
		roster[passe_rive_index] as Button
		if passe_rive_index < roster.size() else null
	)
	_check(_usable(passe_rive_button), "Passe-rive roster action is usable", viewport_size)
	if passe_rive_button == null:
		return
	passe_rive_button.pressed.emit()
	await _settle()
	var selected_value: Variant = selection.call("get_selected_entry")
	var selected: Dictionary = selected_value if selected_value is Dictionary else {}
	_check(
		str(selected.get("id", "")) == "achilles_passe_rive",
		"real roster action selects Passe-rive",
		viewport_size,
	)
	var start_button: Button = selection.get("start_button") as Button
	_check(_usable(start_button), "selected Passe-rive can start an adventure", viewport_size)
	await _capture(
		"retry_selection_passe_rive",
		viewport_size,
		[passe_rive_button, start_button],
	)
	if start_button == null:
		return
	start_button.pressed.emit()
	var configured: RunData = GameManager.peek_next_run_data()
	_check(configured != null, "real selection action configures a run", viewport_size)
	if configured == null:
		return
	_check(
		configured.catabase_route_enabled,
		"selected adventure configures Catabase",
		viewport_size,
	)
	_check(
		str(configured.hero_visual_variants.get("achilles", "")) == "passe_rive",
		"configured Catabase keeps the Passe-rive appearance",
		viewport_size,
	)
	var resolution: RunHeroResolution = RunHeroResolver.resolve_runtime_hero_data(
		configured,
		false,
	)
	_check(
		resolution.is_valid() and resolution.heroes.size() == 1 \
			and resolution.heroes[0].get_effective_unit_id() == &"achilles",
		"configured adventure resolves one Achille and never the trio",
		viewport_size,
	)
	var intro: Node = await _wait_for_scene(INTRO_SCENE_PATH, SCENE_TIMEOUT_MS)
	_check(intro != null, "real start action enters the authored Catabase intro", viewport_size)


func _validate_no_resume(viewport_size: Vector2i, context: String) -> void:
	_check(
		ExpeditionSaveService.fingerprint(PROBE_SAVE_PATH) == "absent",
		"%s has no checkpoint file" % context,
		viewport_size,
	)
	_check(
		ExpeditionSaveService.read_snapshot(PROBE_SAVE_PATH).is_empty(),
		"%s has no resumable snapshot" % context,
		viewport_size,
	)


func _cleanup_runtime() -> void:
	var current: Node = get_tree().current_scene
	if current != null and current != self:
		if current.has_method("_begin_battle_shutdown"):
			current.call("_begin_battle_shutdown")
		get_tree().current_scene = null
		current.queue_free()
	await get_tree().process_frame
	GameManager.cleanup_run_state()
	ExpeditionSaveService.remove_snapshot(PROBE_SAVE_PATH)
	await _settle()


func _wait_for_scene(path: String, timeout_ms: int) -> Node:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		var current: Node = get_tree().current_scene
		if current != null and is_instance_valid(current) \
				and current.scene_file_path == path and current.is_node_ready():
			return current
		await get_tree().process_frame
	return null


func _wait_for_battle_ready(battle: Node, timeout_ms: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while is_instance_valid(battle) and Time.get_ticks_msec() < deadline:
		if bool(battle.get("runtime_ready_state")):
			return true
		await get_tree().process_frame
	return false


func _capture(
		label: String,
		viewport_size: Vector2i,
		critical_controls: Array,
	) -> void:
	await _settle()
	await RenderingServer.frame_post_draw
	var suffix := _viewport_label(viewport_size)
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
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	for control_value: Variant in critical_controls:
		var control: Control = control_value as Control
		if control == null:
			continue
		var rect: Rect2 = control.get_global_rect()
		var visible_area: Rect2 = rect.intersection(viewport_rect)
		var minimum_fraction := 0.98 if rect.get_area() > 0.0 else 0.0
		var visible_fraction := (
			visible_area.get_area() / rect.get_area()
			if rect.get_area() > 0.0 else 0.0
		)
		var on_screen: bool = control.is_visible_in_tree() \
			and visible_fraction >= minimum_fraction
		_check(on_screen, "%s critical control stays on-screen" % label, viewport_size)
		controls.append({
			"name": str(control.name),
			"text": str(control.get("text")),
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"visible_fraction": visible_fraction,
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
	var minimum_luminance := 1.0
	var maximum_luminance := 0.0
	var visible_samples := 0
	for y in range(0, image.get_height(), y_step):
		for x in range(0, image.get_width(), x_step):
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.05:
				continue
			visible_samples += 1
			minimum_luminance = minf(minimum_luminance, color.get_luminance())
			maximum_luminance = maxf(maximum_luminance, color.get_luminance())
	return visible_samples >= 32 and maximum_luminance - minimum_luminance >= 0.04


func _usable(control: Control) -> bool:
	return control != null and control.is_visible_in_tree() \
		and (not (control is BaseButton) or not (control as BaseButton).disabled)


func _control_on_screen(control: Control, viewport_size: Vector2i) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	var rect: Rect2 = control.get_global_rect()
	if rect.get_area() <= 0.0:
		return false
	var visible: Rect2 = rect.intersection(Rect2(Vector2.ZERO, Vector2(viewport_size)))
	return visible.get_area() / rect.get_area() >= 0.98


func _check(passed: bool, label: String, viewport_size: Vector2i) -> void:
	_checks.append({
		"passed": passed,
		"label": label,
		"viewport": _viewport_label(viewport_size),
	})
	if not passed:
		push_error(
			"Catabase death probe: %s (%dx%d)"
			% [label, viewport_size.x, viewport_size.y]
		)


func _on_scene_change_requested(path: String) -> void:
	_requested_paths.append(path)


func _count_requested_path(path: String) -> int:
	return _requested_paths.count(path)


func _settle() -> void:
	for frame in 5:
		await get_tree().process_frame


func _viewport_label(viewport_size: Vector2i) -> String:
	return "%dx%d" % [viewport_size.x, viewport_size.y]


func _argument(key: String) -> String:
	for raw: String in OS.get_cmdline_user_args():
		if raw.begins_with(key + "="):
			return raw.trim_prefix(key + "=")
	return ""
