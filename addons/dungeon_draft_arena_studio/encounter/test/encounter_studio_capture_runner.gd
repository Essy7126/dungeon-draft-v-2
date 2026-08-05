extends Control

const OUTPUT_ROOT := "res://artifacts/encounter_studio/captures"
const RUN_PATH := "res://data/runs/first_run.tres"

var studio: EncounterStudioMain
var resolution := Vector2i(1280, 720)


func _ready() -> void:
	call_deferred("_capture_suite")


func _capture_suite() -> void:
	var options := _options()
	resolution = Vector2i(
		int(options.get("width", 1280)), int(options.get("height", 720))
	)
	get_window().size = resolution
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	studio = EncounterStudioMain.new()
	studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(studio)
	for _frame in range(10):
		await get_tree().process_frame
	studio.open_run(RUN_PATH)
	await _settle()
	await _capture("01_premiere_run_ouverte")

	studio.session.select(0, 0)
	studio._refresh_all()
	await _capture("02_salle_1_selectionnee")
	await _capture("03_timeline_visible")

	studio.properties_tabs.current_tab = 0
	await _capture("04_composition_affrontement")

	studio._ensure_editable(func(): pass)
	await _capture("05_ressource_partagee")
	studio.shared_dialog.hide()

	studio.generate_preview()
	await _capture("06_placement_map_foret")
	studio.properties_tabs.current_tab = 1
	await _capture("07_distances_affichees")

	studio.properties_tabs.current_tab = 3
	await studio.analyze_seeds(100)
	await _capture("08_analyse_100_seeds")

	studio.session.select(studio.session.working_run.rooms.size() - 1, 9)
	studio._refresh_all()
	studio.properties_tabs.current_tab = 0
	await _capture("09_salle_finale_chefs_centurions")

	studio.session.current_encounter().forbidden_initial_spawn_cells.append(
		Vector2i(99, 99)
	)
	var validation := studio.validate_session()
	for index in range(validation.size()):
		if validation[index].severity == StudioValidationMessage.Severity.ERROR:
			studio.validation_list.select(index)
			studio.validation_list.ensure_current_is_visible()
			break
	await _capture("10_panneau_validation")
	print("ENCOUNTER_STUDIO_CAPTURES_OK ", resolution)
	get_tree().quit(0)


func _capture(case_name: String) -> void:
	await _settle()
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Encounter Studio : image de viewport indisponible.")
		get_tree().quit(1)
		return
	var directory := OUTPUT_ROOT.path_join("%dx%d" % [resolution.x, resolution.y])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path := directory.path_join(case_name + ".png")
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Capture impossible : %s" % error_string(error))
		get_tree().quit(1)


func _settle() -> void:
	for _frame in range(6):
		await get_tree().process_frame


func _options() -> Dictionary:
	var result := {}
	for argument in OS.get_cmdline_user_args():
		if not "=" in argument:
			continue
		var parts := argument.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1]
	return result
