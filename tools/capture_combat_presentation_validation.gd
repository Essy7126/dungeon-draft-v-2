extends Node

## Galerie de validation du contrat de presentation de combat.
##
## Elle utilise les donnees et le HUD de production, mais fige volontairement
## les etats de presentation : ce n'est pas une simulation de gameplay.

const RUN := preload("res://data/runs/first_run.tres")
const BACKGROUND := preload("res://asset/map/iso/forest_room_01_source.png")
const PRESENTATION_STATE := preload("res://battle/combat_presentation_state.gd")
const END_TURN_CONFIRMATION := preload(
	"res://ui/combat/end_turn_confirmation.gd"
)
const OUTCOME_OVERLAY := preload("res://ui/combat/combat_outcome_overlay.gd")

const OUTPUT_DIR := "res://artifacts/combat_presentation_validation"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080)]

var _report: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_build_background()
	GameManager.cleanup_run_state()
	if not GameManager._prepare_preconfigured_run(
		RUN,
		GameManager.PRODUCTION_HERO_DATA_PATHS,
	):
		push_error("COMBAT PRESENTATION: initialisation First Run impossible")
		get_tree().quit(1)
		return
	GameManager.set_run_ui_mode(PersistentRunUI.RunUIMode.COMBAT)
	await _frames(4)

	var run_ui := GameManager.get_persistent_run_ui() as PersistentRunUI
	var character_state := (
		GameManager.get_ordered_character_states()[0] as CharacterRunState
	)
	var unit := character_state.unit as Unit
	var spell := unit.spells[0] as Spell
	var hud = run_ui.get_combat_hud()
	hud.update_info(unit)
	hud.build_spell_buttons(unit)

	var presentation = PRESENTATION_STATE.new()
	var confirmation = END_TURN_CONFIRMATION.new()
	var outcome = OUTCOME_OVERLAY.new()
	add_child(confirmation)
	add_child(outcome)
	await _frames(3)

	for resolution in RESOLUTIONS:
		get_window().size = resolution
		await _frames(5)

		hud.set_active_mode("", null)
		presentation.clear_feedback()
		presentation.begin_player_turn()
		hud.apply_presentation_snapshot(presentation.get_snapshot())
		await _capture("01_player_idle", resolution, hud)

		hud.set_active_mode("spell", spell)
		presentation.begin_targeting(&"spell")
		presentation.set_feedback(
			"Cible hors de portee (3 cases maximum).",
			&"warning",
		)
		hud.apply_presentation_snapshot(presentation.get_snapshot())
		await _capture("02_targeting_invalid", resolution, hud)

		presentation.clear_feedback()
		presentation.begin_resolution(&"spell")
		hud.apply_presentation_snapshot(presentation.get_snapshot())
		await _capture("03_action_resolution", resolution, hud)

		hud.set_active_mode("", null)
		presentation.begin_enemy_turn()
		hud.apply_presentation_snapshot(presentation.get_snapshot())
		await _capture("04_enemy_ownership", resolution, hud)

		presentation.begin_modal()
		hud.apply_presentation_snapshot(presentation.get_snapshot())
		confirmation.present(unit)
		await _capture("05_end_turn_confirmation", resolution, hud)
		confirmation.dismiss()

		presentation.begin_battle_ending()
		hud.apply_presentation_snapshot(presentation.get_snapshot())
		outcome.present(true, true)
		await _capture("06_victory", resolution, hud)
		outcome.hide_overlay()

	confirmation.queue_free()
	outcome.queue_free()
	GameManager.cleanup_run_state()
	await _frames(3)
	var report_path := OUTPUT_DIR.path_join("report.json")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"method": "fixture de presentation, UI et donnees de production",
			"captures": _report,
		}, "\t"))
		file.close()
	print("COMBAT_PRESENTATION_VALIDATION=" + JSON.stringify(_report))
	get_tree().quit(0 if file != null else 1)


func _build_background() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var image := TextureRect.new()
	image.texture = BACKGROUND
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(image)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.025, 0.20)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)


func _capture(stem: String, resolution: Vector2i, hud: Node) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var resource_path := OUTPUT_DIR.path_join(
		"%s_%dx%d.png" % [stem, resolution.x, resolution.y]
	)
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(resource_path))
	_report.append({
		"state": stem,
		"resolution": [resolution.x, resolution.y],
		"path": resource_path,
		"save_error": error,
		"presentation": hud.get_presentation_snapshot(),
	})
	print("CAPTURED " + resource_path)


func _frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame
