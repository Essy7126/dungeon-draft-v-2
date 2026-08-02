extends Node

const OUTPUT_DIR := "res://artifacts/skill_trees/in_combat_captures"
const BATTLE_BACKGROUND := preload("res://asset/map/iso/forest_room_01_source.png")

var _status_label: Label
var _victory_overlay: ColorRect
var _capture_index := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1920, 1080)
	_build_battle_background()
	var run := RunData.new()
	run.run_name = "Captures évolution en combat"
	run.rooms = [RoomData.new(), RoomData.new()]
	if not GameManager._prepare_preconfigured_run(
		run,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	):
		push_error("Impossible de préparer le trio pour les captures.")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var run_ui := GameManager.get_persistent_run_ui()
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.COMBAT)
	await get_tree().process_frame
	var states := GameManager.get_ordered_character_states()
	for state in states:
		var discipline := state.get_disciplines()[0] as DisciplineData
		state.add_discipline_xp(discipline.discipline_id, 3)
		var request := _request(state, discipline, 2)
		_status_label.text = "%s vient de terminer son action" % state.unit.unit_name
		run_ui._show_evolution_feedback(request)
		await _capture("threshold_%s" % state.character_id)
		run_ui.evolution_feedback.hide()

	var mage_state := states[1] as CharacterRunState
	var mage_discipline := mage_state.get_disciplines()[0] as DisciplineData
	var mage_request := _request(mage_state, mage_discipline, 2)
	_status_label.text = "Action résolue · combat verrouillé · choix obligatoire"
	await _open_and_capture(run_ui, mage_request, "focused_available_choice")
	var mage_screen := run_ui.get_skill_tree_screen()
	var mage_choice := mage_screen.get_available_evolution_node_ids()[0]
	var mage_node := mage_screen.get_graph().get_node_view(mage_choice).node_data
	mage_screen.confirm_evolution_choice(mage_choice)
	await get_tree().process_frame
	run_ui.evolution_title.text = "ÉVOLUTION APPLIQUÉE"
	run_ui.evolution_discipline.text = "%s · actif dès le prochain lancement" % mage_node.display_name
	run_ui.evolution_feedback.show()
	_status_label.text = "Le prochain sort lit déjà le nouveau SpellModifier"
	await _capture("modifier_active_next_spell")
	run_ui.evolution_title.text = "COMBAT REPRIS"
	run_ui.evolution_discipline.text = "%s peut agir à nouveau" % mage_state.unit.unit_name
	_status_label.text = "File vide · contrôles et tour restaurés"
	await _capture("combat_resumed_after_choice")
	run_ui.evolution_feedback.hide()

	var warrior_state := states[2] as CharacterRunState
	var warrior_discipline := warrior_state.get_disciplines()[0] as DisciplineData
	var warrior_request := _request(warrior_state, warrior_discipline, 2)
	_status_label.text = "Dernier ennemi vaincu · victoire différée jusqu’au choix"
	await _open_and_capture(run_ui, warrior_request, "last_action_choice_before_victory")
	var warrior_screen := run_ui.get_skill_tree_screen()
	var warrior_choice := warrior_screen.get_available_evolution_node_ids()[0]
	warrior_screen.confirm_evolution_choice(warrior_choice)
	await get_tree().process_frame
	_victory_overlay.show()
	_status_label.text = "Évolution enregistrée · la victoire peut maintenant continuer"
	await _capture("last_action_victory_after_choice")
	_victory_overlay.hide()

	var elf_state := states[0] as CharacterRunState
	var responsive_discipline := elf_state.get_disciplines()[1] as DisciplineData
	elf_state.add_discipline_xp(responsive_discipline.discipline_id, 3)
	var responsive_request := _request(elf_state, responsive_discipline, 2)
	for viewport_size in [
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
	]:
		get_window().size = viewport_size
		await get_tree().process_frame
		_status_label.text = "Choix en combat · %d×%d" % [
			viewport_size.x,
			viewport_size.y,
		]
		await _open_and_capture(
			run_ui,
			responsive_request,
			"resolution_%dx%d" % [viewport_size.x, viewport_size.y],
		)
		run_ui.get_skill_tree_screen().close_for_run_cleanup()
		await get_tree().process_frame
	GameManager.cleanup_run_state()
	get_tree().quit()


func _request(
		state: CharacterRunState,
		discipline: DisciplineData,
		rank: int
	) -> EvolutionRequest:
	_capture_index += 1
	var spell: Spell = state.unit.spells.filter(
		func(candidate): return candidate.discipline_id == discipline.discipline_id
	)[0]
	return EvolutionRequest.create(
		state.character_id,
		discipline.discipline_id,
		rank,
		spell.get_effective_spell_id(),
		_capture_index,
		StringName("capture_%03d" % _capture_index),
	)


func _open_and_capture(
		run_ui: PersistentRunUI,
		request: EvolutionRequest,
		file_stem: String
	) -> void:
	var screen := run_ui.get_skill_tree_screen()
	if screen.visible:
		screen.close_for_run_cleanup()
	if not screen.open_for_evolution(request, GameManager):
		push_error("Capture impossible : requête refusée %s" % request.request_id)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture(file_stem)


func _capture(file_stem: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUTPUT_DIR, file_stem]
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Capture impossible %s : %s" % [path, error_string(error)])
	else:
		print("CAPTURED %s" % path)


func _build_battle_background() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var image := TextureRect.new()
	image.texture = BATTLE_BACKGROUND
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(image)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.03, 0.22)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	_status_label = Label.new()
	_status_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_status_label.offset_left = -390.0
	_status_label.offset_top = -88.0
	_status_label.offset_right = 390.0
	_status_label.offset_bottom = -38.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
	_status_label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.02, 0.98))
	_status_label.add_theme_constant_override("outline_size", 7)
	root.add_child(_status_label)
	_victory_overlay = ColorRect.new()
	_victory_overlay.color = Color(0.005, 0.012, 0.008, 0.68)
	_victory_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_victory_overlay)
	var victory := Label.new()
	victory.text = "VICTOIRE !"
	victory.set_anchors_preset(Control.PRESET_CENTER)
	victory.offset_left = -260.0
	victory.offset_top = -55.0
	victory.offset_right = 260.0
	victory.offset_bottom = 55.0
	victory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory.add_theme_font_size_override("font_size", 58)
	victory.add_theme_color_override("font_color", Color(0.42, 1.0, 0.55))
	_victory_overlay.add_child(victory)
	_victory_overlay.hide()
