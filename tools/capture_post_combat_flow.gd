extends Node

const OUTPUT_DIR := "res://artifacts/first_run_v2/captures/post_combat"
const SCREEN_SCENE := preload("res://ui/post_combat/PostCombatScreen.tscn")

var _screen: PostCombatScreen = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1920, 1080)
	_prepare_report(false)
	_screen = SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child(_screen)
	await _settle()
	await _advance_to_phase(&"ROOM_DECISION")
	await _capture("room_wave_decision")
	for viewport_size in [
		Vector2i(1280, 720),
		Vector2i(2560, 1440),
	]:
		get_window().size = viewport_size
		_screen.apply_viewport_size_for_test(viewport_size)
		await _settle(3)
		await _capture("room_wave_decision_%dx%d" % [viewport_size.x, viewport_size.y])
	get_window().size = Vector2i(1920, 1080)
	_screen.apply_viewport_size_for_test(Vector2(1920, 1080))
	await _settle()
	_screen.free()
	await _settle()

	_prepare_report(true)
	_screen = SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child(_screen)
	await _settle()
	await _advance_to_phase(&"REWARD_SELECTION")
	await _capture("equipment_two_cards")
	var options := GameManager.get_post_combat_reward_options()
	if options.size() != 2:
		_fail("deux cartes d'equipement attendues")
		return
	var selected := options[0] as Dictionary
	var selected_id := StringName(selected.get("item_id", &""))
	if not _screen.select_reward_by_id(selected_id):
		_fail("selection de la carte impossible")
		return
	await _settle()
	await _capture("equipment_selected")

	for viewport_size in [
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
	]:
		get_window().size = viewport_size
		await _settle(3)
		_screen.apply_viewport_size_for_test(viewport_size)
		await _capture("equipment_%dx%d" % [viewport_size.x, viewport_size.y])

	get_window().size = Vector2i(1920, 1080)
	_screen.apply_viewport_size_for_test(Vector2(1920, 1080))
	await _settle()
	if not _screen.confirm_selected_reward():
		_fail("application de l'equipement impossible")
		return
	await _settle()
	await _capture("equipment_applied")
	print("POST_COMBAT_CAPTURE_VALIDATION=PASS")
	get_tree().quit(0)


func _prepare_report(at_hidden_room_end: bool) -> void:
	GameManager.cleanup_run_state()
	var run := RunData.new()
	run.run_name = "Capture après-combat"
	run.rooms = [
		load("res://data/rooms/first_run_room_01.tres") as RoomData,
		load("res://data/rooms/first_run_room_02.tres") as RoomData,
	]
	GameManager._prepare_preconfigured_run(run, GameManager.PRODUCTION_HERO_DATA_PATHS)
	GameManager.current_room_index = 0
	if at_hidden_room_end:
		GameManager.current_wave_index = GameManager.get_current_room_wave_count() - 1
	var states := GameManager.get_ordered_character_states()
	var elf := states[0].unit as Unit
	var mage := states[1].unit as Unit
	var warrior := states[2].unit as Unit
	elf.grid_pos = Vector2i(0, 0)
	mage.grid_pos = Vector2i(1, 0)
	warrior.grid_pos = Vector2i(2, 0)
	GameManager.begin_combat_report()
	var elf_discipline := states[0].get_disciplines()[0] as DisciplineData
	states[0].add_discipline_xp(elf_discipline.discipline_id, 5)
	var enemy := Unit.new("Brute gobeline", 1, 80)
	enemy.take_damage(34, elf)
	elf.take_damage(13, enemy)
	mage.take_damage(42, enemy)
	warrior.take_damage(25, enemy)
	elf.heal(8, mage)
	elf.add_shield(7, warrior)
	var victim := Unit.new("Éclaireur gobelin", 1, 9)
	victim.take_damage(12, warrior)
	elf.grid_pos = Vector2i(4, 1)
	mage.grid_pos = Vector2i(3, 2)
	warrior.grid_pos = Vector2i(5, 0)
	EventBus.spell_cast.emit(elf, elf.spells[0], {"affected_units": [enemy]})
	EventBus.spell_cast.emit(mage, mage.spells[0], {"affected_units": [enemy]})
	EventBus.spell_cast.emit(mage, mage.spells[0], {"affected_units": [enemy, victim]})
	EventBus.spell_cast.emit(warrior, warrior.spells[0], {"affected_units": [victim]})
	var pending := states[0].get_pending_progression_choices()
	if not pending.is_empty():
		var choice := pending[0] as Dictionary
		var available := choice.get("choices", []) as Array
		if not available.is_empty():
			states[0].select_upgrade(
				elf_discipline.discipline_id,
				int(choice.get("rank", 2)),
				(available[0] as SkillUpgradeData).upgrade_id,
			)
	GameManager._last_combat_report = GameManager._finalize_current_combat_report(true)
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.NON_COMBAT)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, file_name]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Capture impossible : %s" % path)
	else:
		print("CAPTURED %s" % path)


func _settle(frame_count: int = 2) -> void:
	for _index in frame_count:
		await get_tree().process_frame


func _advance_to_phase(target: StringName) -> void:
	var guard := 0
	while _screen.get_phase_name() != target and guard < 16:
		guard += 1
		_screen.advance_or_skip()
		await _settle()
	if _screen.get_phase_name() != target:
		_fail("phase %s inaccessible" % target)


func _fail(message: String) -> void:
	push_error("CAPTURE POST-COMBAT: %s" % message)
	get_tree().quit(1)
