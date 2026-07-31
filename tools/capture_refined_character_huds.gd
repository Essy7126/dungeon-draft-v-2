extends Node

const HUD_SCENE := preload(
	"res://ui/recraft_hud_v1/combat/combat_hud_recraft_v1.tscn"
)
const OUTPUT_DIR := "res://artifacts/hud_refined_characters/captures"
const CASES := [
	{"slug": "elf", "unit": "res://data/units/alliés/elfe.tres"},
	{"slug": "mage", "unit": "res://data/units/alliés/mage.tres"},
	{"slug": "guardian", "unit": "res://data/units/alliés/Gardien.tres"},
	{"slug": "warrior", "unit": "res://data/units/alliés/Guerrier.tres"},
	{"slug": "druid", "unit": "res://data/units/alliés/healer.tres"},
	{"slug": "assassin", "unit": "res://data/units/alliés/Assassin.tres"},
	{"slug": "necromancer", "unit": "res://data/units/alliés/Necromant.tres"},
	{"slug": "hoplite", "unit": "res://data/units/alliés/Hoplite.tres"},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.027, 0.034, 0.043, 1.0)
	viewport.add_child(backdrop)
	for case_data in CASES:
		print("Capture HUD: %s" % case_data["slug"])
		await _capture_character(viewport, backdrop, case_data, Vector2i(1920, 1080), true)
	await _capture_character(viewport, backdrop, CASES[0], Vector2i(1280, 720), false)
	await _capture_character(viewport, backdrop, CASES[0], Vector2i(2560, 1440), false)
	viewport.queue_free()
	get_tree().quit()


func _capture_character(
		viewport: SubViewport,
		backdrop: ColorRect,
		case_data: Dictionary,
		resolution: Vector2i,
		capture_banner: bool
	) -> void:
	viewport.size = resolution
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(resolution)

	var unit := Unit.from_data(load(case_data["unit"]) as UnitData)
	if unit.has_energy():
		unit.current_energy = unit.energy_type.max_energy * 0.68
	var hud = HUD_SCENE.instantiate()
	hud.skin_variant = hud.HudSkinVariant.REFINED
	viewport.add_child(hud)
	hud.set_ui_mode(hud.RunUIMode.COMBAT)
	hud.set_player_controls_enabled(true)
	hud.update_info(unit)
	hud.build_spell_buttons(unit)
	var base_buttons: Array = hud.get("_spell_buttons").filter(
		func(button): return not button.get_meta("imprinted", false)
	)
	if not base_buttons.is_empty():
		var selected_spell: Spell = base_buttons[0].get_meta("spell")
		hud.set_active_mode("spell", selected_spell, false)
	await _settle()

	var suffix := "%dx%d" % [resolution.x, resolution.y]
	_save(viewport, "hud_refined_%s_selected_%s.png" % [case_data["slug"], suffix])
	if case_data["slug"] == "elf" and resolution == Vector2i(1920, 1080):
		_save(viewport, "hud_refined_system_dock_1920x1080.png")

	if capture_banner:
		hud.set_active_mode("")
		var banner: CharacterTurnIntroBanner = hud.get_turn_intro_banner()
		banner.present(unit, hud.get_active_character_theme())
		await get_tree().create_timer(0.34).timeout
		await RenderingServer.frame_post_draw
		_save(viewport, "hud_refined_%s_turn_banner_%s.png" % [case_data["slug"], suffix])
		banner.hide_immediately()

	unit.clear_traits()
	hud.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.12).timeout
	await RenderingServer.frame_post_draw


func _save(viewport: SubViewport, filename: String) -> void:
	var image := viewport.get_texture().get_image()
	var error := image.save_png("%s/%s" % [OUTPUT_DIR, filename])
	if error != OK:
		push_error("Capture failed: %s (%s)" % [filename, error])
