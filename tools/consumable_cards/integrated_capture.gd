extends Node
## Actual selection, Battle and ExpeditionScreen; no prototype screen or run.
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
var output := ""
var captures := 0
var failures: Array[String] = []
var scene: Node


class Manager:
	extends "res://core/game_manager.gd"
	func _request_scene_change(
		_path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		pass


	func start_next_battle() -> void:
		pass


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


func _ready() -> void:
	get_tree().create_timer(60).timeout.connect(func(): get_tree().quit(3))
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(
			ProjectSettings.globalize_path("res://artifacts/dev/").replace("\\", "/")
		):
		push_error("Capture requires an isolated artifacts/dev APPDATA and --output.")
		get_tree().quit(2)
		return
	GameManager.cleanup_run_state()
	GameManager.select_run_variant("cards")
	scene = load(GameManager.CHARACTER_SELECTION_SCREEN_PATH).instantiate()
	add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene._cards_setup.step = 2
	scene._cards_setup.reached = 4
	scene._cards_setup._render()
	await capture("01_selection_cartes")
	scene._cards_setup.step = 4
	scene._cards_setup._render()
	var sun = scene.find_child("DepartureMastery_sun", true, false)
	check(sun != null, "departure exposes initial allocation")
	if sun != null: sun.value = 4
	await get_tree().process_frame
	for allocation in scene.find_children("DepartureMastery_*", "SpinBox", true, false):
		check(allocation.size.y < 70, "departure allocation rows stay compact")
	await capture("02_depart")
	var manager := Manager.new()
	add_child(manager)
	manager.select_run_variant("cards")
	manager.expedition_save_path = "user://capture_entry.json"
	scene.selected_index = scene._cards_setup.hero
	check(scene.prepare_adventure(manager), "actual selection departure")
	check(manager.continue_after_intro(), "actual intro continuation")
	check(manager.finish_catabase_threshold().success, "actual threshold departure")
	clear_scene()
	var prepared_cards: Variant = manager.expedition.cards
	check(int(prepared_cards.masteries.sun) == 4, "initial allocation reaches public combat")
	var opening := ""
	for copy in prepared_cards.copies:
		if copy.family == "n02":
			opening = copy.id
			break
	check(not opening.is_empty() and prepared_cards.set_opening(opening), "opening")
	check(
		GameManager.restore_expedition_snapshot(manager.get_expedition_snapshot()),
		"restore entry",
	)
	manager.cleanup_run_state()
	manager.free()
	scene = GameManager.get_current_room().battle_scene.instantiate()
	add_child(scene)
	await get_tree().process_frame
	scene._deployment.on_cell_clicked(scene._deployment._deploy_zone[0])
	for _tick in 500:
		await get_tree().create_timer(.02).timeout
		if scene._can_accept_player_intent() and GameManager.expedition.cards.hand.size() == 5:
			break
	check(scene._can_accept_player_intent(), "real Battle interactive")
	await get_tree().create_timer(1.5).timeout
	await capture("03_combat_main")
	GameManager.expedition.cards.selected = opening
	await scene._on_request_cast_spell(
		GameManager.expedition.cards.family_spell("n02"),
		GameManager.expedition.character.unit.grid_pos,
	)
	for _tick in 500:
		await get_tree().create_timer(.02).timeout
		if not scene._spell_resolution_pending:
			break
	check(opening in GameManager.expedition.cards.consumed, "real cast consumes copy")
	check(GameManager.expedition.character.unit.current_shield == 8, "sun mastery scales the real guard cast at 16 power")
	await capture("04_combat_carte_consommee")
	clear_scene()
	# UI fixture for the postcombat windows, not a victory or balance simulation.
	GameManager._combat_report_tracker.discard()
	GameManager._release_persistent_run_ui()
	GameManager.expedition.combat_won()
	for page in ["rewards", "cards", "build", "gear"]:
		scene = load(GameManager.EXPEDITION_SCREEN_PATH).instantiate()
		scene.inspection_only = true
		scene.initial_page = page
		add_child(scene)
		scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await capture("05_" + page)
		clear_scene()
	GameManager.cleanup_run_state()
	await get_tree().process_frame
	print(
		"CARDS_INTEGRATED_CAPTURE "
		+ JSON.stringify(
			{
				"passed": failures.is_empty(),
				"captures": captures,
				"failures": failures,
				"directory": output,
			}
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)


func clear_scene() -> void:
	if is_instance_valid(scene):
		remove_child(scene)
		scene.free()
	scene = null


func capture(label: String) -> void:
	for _frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, label)
	captures += 1


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
