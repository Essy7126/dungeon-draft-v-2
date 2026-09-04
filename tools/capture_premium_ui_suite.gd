extends Node
## Capture deterministe des principaux ecrans du langage visuel premium.

const OUTPUT_DIR := "res://artifacts/odyssey_ui/captures/system"
const CAPTURE_SIZE := Vector2i(1672, 941)
const TITLE_SCENE := preload("res://ui/TitreEcran.tscn")
const RUN_RESULT_SCENE := preload("res://ui/RunResultScreen.tscn")
const EVOLUTION_SCENE := preload(
	"res://ui/progression/evolution/SkillEvolutionOverlay.tscn"
)
const FOREST_BACKGROUND := preload(
	"res://asset/map/painted/room_01_forest/forest_background_v2.webp"
)
const ODYSSEY_RUN: RunData = preload("res://data/runs/odyssey.tres")

var _stage_nodes: Array[Node] = []
var _failed := false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = CAPTURE_SIZE
	await _settle(4)
	await _capture_title()
	if _failed:
		return
	if not _prepare_run():
		_fail("La run de capture n'a pas pu etre preparee.")
		return
	_add_odyssey_backdrop()
	await _capture_inventory()
	if _failed:
		return
	await _capture_pause_menu()
	if _failed:
		return
	await _capture_skill_tree()
	if _failed:
		return
	await _capture_combat_outcome()
	if _failed:
		return
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.TRANSITION)
	_clear_stage()
	await _capture_run_result()
	if _failed:
		return
	_add_odyssey_backdrop()
	await _capture_skill_evolution()
	if _failed:
		return
	GameManager.cleanup_run_state()
	print("PREMIUM_UI_CAPTURE_VALIDATION=PASS")
	get_tree().quit(0)


func _capture_title() -> void:
	var title_screen := TITLE_SCENE.instantiate()
	_add_stage_node(title_screen)
	await _settle(4)
	var animation_player := title_screen.get_node("AnimationPlayer") as AnimationPlayer
	var intro := animation_player.get_animation(&"intro")
	animation_player.seek(intro.length, true)
	title_screen.call("_on_intro_terminee", &"intro")
	await _settle(3)
	await _capture("01_menu_principal")
	_clear_stage()
	await _settle(3)


func _prepare_run() -> bool:
	GameManager.cleanup_run_state()
	var capture_run := ODYSSEY_RUN.duplicate(false) as RunData
	capture_run.randomize_seed_each_run = false
	var resolution := RunHeroResolver.resolve_runtime_hero_data(capture_run, false)
	if not resolution.is_valid():
		return false
	if not GameManager._prepare_preconfigured_run(
			capture_run,
			resolution.heroes,
		):
		return false
	var inventory := GameManager.get_run_inventory()
	for relic_id in [
		&"cendres_du_phenix",
		&"chaines_de_promethee",
		&"plume_de_nike",
		&"sablier_de_chronos",
	]:
		if not inventory.contains_definition(relic_id):
			inventory.try_add(relic_id)
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.NON_COMBAT)
	return true


func _capture_inventory() -> void:
	var run_ui := GameManager.get_persistent_run_ui()
	if run_ui == null or not run_ui.open_inventory_screen(&"achilles"):
		_fail("L'inventaire de capture ne s'ouvre pas.")
		return
	await _settle(4)
	var inventory_screen := run_ui.get_inventory_screen() as InventoryScreen
	var wanted := _find_inventory_instance(&"cendres_du_phenix")
	if wanted != null:
		inventory_screen._select_inventory_item(wanted.instance_id)
	await _settle(3)
	await _capture("02_inventaire_reliques")
	run_ui.close_inventory_screen()
	await _settle(3)


func _capture_pause_menu() -> void:
	var run_ui := GameManager.get_persistent_run_ui()
	run_ui.set_reduced_motion(true)
	if not run_ui.open_pause_menu():
		_fail("Le menu pause de capture ne s'ouvre pas.")
		return
	await _settle(3)
	await _capture("03_menu_pause")
	run_ui.close_pause_menu()
	run_ui.set_reduced_motion(false)
	await _settle(3)


func _capture_skill_tree() -> void:
	var run_ui := GameManager.get_persistent_run_ui()
	var state := GameManager.get_character_state(&"achilles") as CharacterRunState
	if state == null or state.get_disciplines().is_empty():
		_fail("La progression d'Achille est indisponible.")
		return
	var discipline := state.get_disciplines()[0] as DisciplineData
	state.add_discipline_xp(discipline.discipline_id, 7)
	var screen := run_ui.get_skill_tree_screen() as SkillTreeScreen
	if not screen.open_for_state(state, discipline.discipline_id):
		_fail("L'arbre de competences de capture ne s'ouvre pas.")
		return
	await _settle(4)
	await _capture("04_arbre_competences")
	screen.close_for_run_cleanup()
	await _settle(3)


func _capture_combat_outcome() -> void:
	var outcome := CombatOutcomeOverlay.new()
	_add_stage_node(outcome)
	await _settle(2)
	outcome.present(true, true)
	await _settle(3)
	await _capture("05_issue_combat")
	_remove_stage_node(outcome)
	await _settle(3)


func _capture_run_result() -> void:
	var screen := RUN_RESULT_SCENE.instantiate()
	_add_stage_node(screen)
	await _settle(3)
	screen.call("_apply_result", {
		"victory": true,
		"is_catabase": true,
		"featured_hero_name": "Achille",
		"run_name": ODYSSEY_RUN.run_name,
		"rooms_cleared": ODYSSEY_RUN.rooms.size(),
		"room_total": ODYSSEY_RUN.rooms.size(),
		"reached_room_number": ODYSSEY_RUN.rooms.size(),
		"reached_room_name": (ODYSSEY_RUN.rooms.back() as RoomData).room_name,
		"seed_available": true,
		"seed": 1337,
		"epitaph": "L'Archiviste consigne une Odyssée achevée sans rompre la ligne.",
	})
	await _settle(3)
	await _capture("06_resultat_run")
	_clear_stage()
	await _settle(3)


func _capture_skill_evolution() -> void:
	var choice := GameManager.get_next_pending_progression_choice()
	if choice.is_empty() or (choice.get("choices", []) as Array).size() != 2:
		_fail("Le choix d'évolution d'Achille est indisponible.")
		return
	var request := EvolutionRequest.create(
		StringName(choice.get("character_id", &"")),
		StringName(choice.get("discipline_id", &"")),
		int(choice.get("rank", 0)),
		StringName(choice.get("spell_id", &"")),
		1,
		&"odyssey_capture_achilles_evolution",
	)
	var overlay := EVOLUTION_SCENE.instantiate() as SkillEvolutionOverlay
	_add_stage_node(overlay)
	await _settle(3)
	if not overlay.present(request, choice, false):
		_fail("L'évolution d'Achille ne peut pas être présentée.")
		return
	var upgrades := overlay.get_available_upgrade_ids()
	if upgrades.size() != 2 or not overlay.select_upgrade_by_id(upgrades[0]):
		_fail("L'évolution d'Achille ne peut pas être sélectionnée.")
		return
	await _settle(8)
	await _capture("07_evolution_competence")
	_clear_stage()
	await _settle(3)


func _find_inventory_instance(definition_id: StringName) -> ItemInstance:
	for instance in GameManager.get_run_inventory().get_slots():
		if instance != null and instance.definition_id == definition_id:
			return instance
	return null


func _add_odyssey_backdrop() -> void:
	var backdrop := TextureRect.new()
	backdrop.name = "CaptureBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var first_room := ODYSSEY_RUN.rooms[0] as RoomData
	backdrop.texture = (
		first_room.painted_map_visual_data.load_background_texture()
		if first_room != null and first_room.painted_map_visual_data != null
		else FOREST_BACKGROUND
	)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.68, 0.70, 0.66, 1.0)
	_add_stage_node(backdrop)
	move_child(backdrop, 0)


func _add_stage_node(node: Node) -> void:
	add_child(node)
	_stage_nodes.append(node)


func _remove_stage_node(node: Node) -> void:
	_stage_nodes.erase(node)
	if is_instance_valid(node):
		node.queue_free()


func _clear_stage() -> void:
	for node in _stage_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_stage_nodes.clear()


func _capture(file_stem: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s__%dx%d.png" % [
		OUTPUT_DIR,
		file_stem,
		CAPTURE_SIZE.x,
		CAPTURE_SIZE.y,
	]
	var error := get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path(path)
	)
	if error != OK:
		_fail("Capture impossible : %s" % path)
	else:
		print("CAPTURED %s" % path)


func _settle(frame_count: int = 2) -> void:
	for _index in frame_count:
		await get_tree().process_frame


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error("CAPTURE PREMIUM UI : %s" % message)
	get_tree().paused = false
	GameManager.cleanup_run_state()
	get_tree().quit(1)
