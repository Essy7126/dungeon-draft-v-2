extends Node

const OUTPUT_DIR := "res://artifacts/post_combat/captures"
const SCREEN_SCENE := preload("res://ui/post_combat/PostCombatScreen.tscn")

var _screen: PostCombatScreen = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1920, 1080)
	_prepare_report()
	_screen = SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child(_screen)
	await _settle()
	await _capture("victory_reveal")

	_screen.advance_or_skip()
	_screen.advance_or_skip()
	_screen.advance_or_skip()
	await _settle()
	await _capture("combat_stats")

	_screen.progression_step_duration = 0.75
	_screen.threshold_pause_duration = 0.65
	_screen.advance_or_skip()
	await get_tree().process_frame
	await _capture("progression_before")
	await get_tree().create_timer(0.24).timeout
	await _capture("progression_animating")
	await get_tree().create_timer(0.58).timeout
	await _capture("progression_threshold")
	_screen.advance_or_skip()
	await _settle()
	await _capture("progression_acquired_node")

	_screen.advance_or_skip()
	await _settle()
	await _capture("reward_three_cards")
	_screen.select_reward_by_id(&"hero_max_hp_10")
	await _settle()
	await _capture("reward_selected")

	for viewport_size in [
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
	]:
		get_window().size = viewport_size
		await _settle(3)
		await _capture("resolution_%dx%d" % [viewport_size.x, viewport_size.y])

	get_window().size = Vector2i(1920, 1080)
	await _settle()
	_screen.confirm_selected_reward()
	_screen.advance_or_skip()
	await get_tree().create_timer(0.15).timeout
	await _capture("transition_next_room")
	get_tree().quit()


func _prepare_report() -> void:
	GameManager.cleanup_run_state()
	var run := RunData.new()
	run.run_name = "Capture après-combat"
	run.rooms = [
		load("res://data/rooms/first_run_room_01.tres") as RoomData,
		load("res://data/rooms/first_run_room_02.tres") as RoomData,
	]
	GameManager._prepare_preconfigured_run(run, GameManager.PRODUCTION_HERO_DATA_PATHS)
	GameManager.current_room_index = 0
	var states := GameManager.get_ordered_character_states()
	var elf := states[0].unit as Unit
	var mage := states[1].unit as Unit
	var warrior := states[2].unit as Unit
	elf.grid_pos = Vector2i(0, 0)
	mage.grid_pos = Vector2i(1, 0)
	warrior.grid_pos = Vector2i(2, 0)
	var elf_discipline := states[0].get_disciplines()[0] as DisciplineData
	states[0].add_discipline_xp(elf_discipline.discipline_id, 2)
	GameManager.begin_combat_report()
	var enemy := Unit.new("Brute gobeline", 1, 80)
	enemy.take_damage(34, elf)
	elf.take_damage(13, enemy)
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
	var progress := states[0].get_discipline_progress(elf_discipline.discipline_id)
	var available := SkillTreeResolver.get_available_nodes(
		elf_discipline,
		2,
		progress.rank,
		progress.get_pending_rank_choices(),
		progress.get_selected_upgrade_ids(),
	)
	states[0].select_upgrade(elf_discipline.discipline_id, 2, available[0].upgrade_id)
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
