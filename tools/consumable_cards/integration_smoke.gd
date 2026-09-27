extends Node
## Public Cartes flow, isolated from the player's user directory.
const Catalog := preload("res://core/expedition/consumable_card_catalog.gd")
var failures: Array[String] = []


class Manager:
	extends "res://core/game_manager.gd"
	var requested_scene := ""


	func _request_scene_change(
		path: String,
		_mode: PersistentRunUI.RunUIMode = PersistentRunUI.RunUIMode.NON_COMBAT,
	) -> void:
		requested_scene = path


	func start_next_battle() -> void:
		requested_scene = "battle"


	func _ensure_persistent_run_ui() -> PersistentRunUI:
		return null


func _ready() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").begins_with(
		ProjectSettings.globalize_path("res://artifacts/dev/").replace("\\", "/")
	):
		push_error("Integration smoke requires an isolated artifacts/dev APPDATA.")
		get_tree().quit(2)
		return
	var manager := Manager.new()
	add_child(manager)
	check(
		ExpeditionSaveService.write_snapshot(
			{ "sentinel": "classic" },
			ExpeditionSaveService.SAVE_PATH,
		),
		"classic fixture",
	)
	var classic := ExpeditionSaveService.fingerprint(ExpeditionSaveService.SAVE_PATH)
	check(not manager.select_run_variant("cards_v2"), "no third run")
	check(manager.select_run_variant("cards"), "existing mode")
	check(manager.configure_next_run(ExpeditionRunFactory.create(641), 0), "selected hero")
	check(manager.configure_cards_departure(Catalog.preset("gardien")), "15-copy departure")
	check(manager.continue_after_intro(), "introduction")
	check(manager.requested_scene == manager.CATABASE_THRESHOLD_SCREEN_PATH, "existing threshold")
	check(manager.finish_catabase_threshold().success, "threshold departure")
	check(
		manager.expedition != null and manager.expedition.uses_consumable_cards(),
		"existing expedition session",
	)
	check(manager.requested_scene == "battle", "authored Battle")
	check(manager.expedition.cards.active.size() == 15, "prepared copies")
	check(
		manager.expedition_save_path == ExpeditionSaveService.CARDS_SAVE_PATH,
		"existing save slot",
	)
	manager.cleanup_run_state()
	check(manager.resume_expedition(), "public continue")
	check(manager.requested_scene == "battle", "resume real combat")
	check(
		ExpeditionSaveService.fingerprint(ExpeditionSaveService.SAVE_PATH) == classic,
		"classic save preserved",
	)
	manager.cleanup_run_state()
	manager.free()
	print(
		"CARDS_INTEGRATION "
		+ JSON.stringify(
			{
				"passed": failures.is_empty(),
				"failures": failures,
				"user_data": OS.get_user_data_dir(),
			}
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
