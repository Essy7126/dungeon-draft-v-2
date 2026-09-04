extends Node
## Capture le véritable après-combat de l'Odyssée, avec Achille seul.

const OUTPUT_DIR := "res://artifacts/odyssey_ui/captures/post_combat"
const SCREEN_SCENE := preload("res://ui/post_combat/PostCombatScreen.tscn")
const ODYSSEY_RUN: RunData = preload("res://data/runs/odyssey.tres")
const REFERENCE_SIZE := Vector2i(1672, 941)

var _screen: PostCombatScreen = null
var _failed := false


func _ready() -> void:
	var output_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUTPUT_DIR)
	)
	if output_error != OK:
		_fail("dossier de sortie inaccessible : %s" % OUTPUT_DIR)
		return
	get_window().size = REFERENCE_SIZE
	var skip_uhd := "--skip-uhd" in OS.get_cmdline_user_args()
	if not _prepare_odyssey_report():
		return
	_screen = SCREEN_SCENE.instantiate() as PostCombatScreen
	add_child(_screen)
	await _settle(4)

	if not await _advance_to_phase(&"COMBAT_STATS"):
		return
	await _finish_phase_animation()
	if not await _capture("odyssey_combat_report__1672x941"):
		return

	if not await _advance_to_phase(&"PROGRESSION"):
		return
	await _finish_phase_animation()
	if not await _capture("odyssey_progression__1672x941"):
		return

	if not await _advance_to_phase(&"REWARD_SELECTION"):
		return
	await get_tree().create_timer(0.72).timeout
	if not await _capture("odyssey_relic_two_cards__1672x941"):
		return
	var options := GameManager.get_post_combat_reward_options()
	if options.size() != 2:
		_fail("deux cartes de relique Odyssée attendues")
		return
	var selected := options[0] as Dictionary
	var selected_id := StringName(selected.get("item_id", &""))
	if not _screen.select_reward_by_id(selected_id):
		_fail("sélection de la relique Odyssée impossible")
		return
	await _settle(4)
	if not await _capture("odyssey_relic_selected__1672x941"):
		return

	var reward_sizes := [Vector2i(1280, 720)]
	if not skip_uhd:
		reward_sizes.append(Vector2i(2560, 1440))
	for viewport_size in reward_sizes:
		get_window().size = viewport_size
		_screen.apply_viewport_size_for_test(viewport_size)
		await _settle(5)
		if not await _capture(
			"odyssey_relic_selected__%dx%d" % [viewport_size.x, viewport_size.y]
		):
			return

	get_window().size = REFERENCE_SIZE
	_screen.apply_viewport_size_for_test(REFERENCE_SIZE)
	await _settle(4)
	# Le runner doit photographier l'état confirmé, pas le début du tween ni le
	# fondu vers la salle suivante. On débranche donc uniquement la transition
	# automatique de cette instance de capture, puis on attend le signal émis
	# après la durée complète de confirmation (mouvement normal ou réduit).
	var transition_callback := Callable(
		_screen, "_on_overlay_confirmation_finished"
	)
	if _screen.reward_overlay.confirmation_finished.is_connected(
		transition_callback
	):
		_screen.reward_overlay.confirmation_finished.disconnect(
			transition_callback
		)
	if not _screen.confirm_selected_reward():
		_fail("acquisition de la relique Odyssée impossible")
		return
	await _screen.reward_overlay.confirmation_finished
	await _settle(2)
	if not await _capture("odyssey_relic_applied__1672x941"):
		return
	if _failed:
		return
	GameManager.cleanup_run_state()
	print("POST_COMBAT_ODYSSEY_CAPTURE_VALIDATION=PASS")
	get_tree().quit(0)


func _prepare_odyssey_report() -> bool:
	GameManager.cleanup_run_state()
	var capture_run := ODYSSEY_RUN.duplicate(false) as RunData
	capture_run.randomize_seed_each_run = false
	var resolution := RunHeroResolver.resolve_runtime_hero_data(capture_run, false)
	if not resolution.is_valid():
		_fail("le profil Achille de l'Odyssée est invalide")
		return false
	if not GameManager._prepare_preconfigured_run(capture_run, resolution.heroes):
		_fail("la véritable Odyssée n'a pas pu être préparée")
		return false
	GameManager.current_room_index = 0
	var state := GameManager.get_character_state(&"achilles") as CharacterRunState
	if state == null or state.unit == null or state.get_disciplines().is_empty():
		_fail("Achille ou sa progression est indisponible")
		return false
	var achilles := state.unit as Unit
	achilles.grid_pos = Vector2i(4, 9)
	GameManager.begin_combat_report()
	var discipline := state.get_disciplines()[0] as DisciplineData
	state.add_discipline_xp(discipline.discipline_id, 5)
	var enemy := Unit.new("Rejeton de la Catabase", 1, 80)
	enemy.grid_pos = Vector2i(8, 2)
	enemy.take_damage(34, achilles)
	achilles.take_damage(18, enemy)
	achilles.heal(8, achilles)
	achilles.add_shield(7, achilles)
	var victim := Unit.new("Ombre chétive", 1, 9)
	victim.grid_pos = Vector2i(9, 2)
	victim.take_damage(12, achilles)
	achilles.grid_pos = Vector2i(6, 7)
	if not achilles.spells.is_empty():
		EventBus.spell_cast.emit(
			achilles,
			achilles.spells[0],
			{"affected_units": [enemy, victim]},
		)
	var pending := state.get_pending_progression_choices()
	if not pending.is_empty():
		var choice := pending[0] as Dictionary
		var available := choice.get("choices", []) as Array
		if not available.is_empty():
			state.select_upgrade(
				discipline.discipline_id,
				int(choice.get("rank", 2)),
				(available[0] as SkillUpgradeData).upgrade_id,
			)
	GameManager._room_outcome_resolved = true
	GameManager._last_combat_report = GameManager._finalize_current_combat_report(true)
	if GameManager._last_combat_report == null:
		_fail("le rapport de victoire Odyssée n'a pas été finalisé")
		return false
	if not GameManager.select_current_room_exit(
		GameManager._last_combat_report.report_id
	):
		_fail("la sortie de Catabase I n'a pas pu être sécurisée")
		return false
	if not GameManager.can_claim_post_combat_equipment(
		GameManager._last_combat_report.report_id
	):
		_fail("l'offre de reliques n'est pas accessible dans l'Odyssée")
		return false
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.NON_COMBAT)
	return true


func _capture(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUTPUT_DIR, file_name]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		_fail("capture impossible : %s" % path)
		return false
	print("CAPTURED %s" % path)
	return true


func _settle(frame_count: int = 2) -> void:
	for _index in frame_count:
		await get_tree().process_frame


func _advance_to_phase(target: StringName) -> bool:
	var guard := 0
	while _screen.get_phase_name() != target and guard < 16:
		guard += 1
		_screen.advance_or_skip()
		await _settle(2)
	if _screen.get_phase_name() != target:
		_fail("phase Odyssée %s inaccessible" % target)
		return false
	return true


func _finish_phase_animation() -> void:
	if _screen != null and _screen._animation_active:
		_screen.advance_or_skip()
	await _settle(3)


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error("CAPTURE POST-COMBAT ODYSSÉE : %s" % message)
	GameManager.cleanup_run_state()
	get_tree().quit(1)
