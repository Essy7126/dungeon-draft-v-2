extends Node

const PREVIEW := preload("res://ui/recraft_hud_v1/preview/elf_hud_clean_preview.tscn")
const OUTPUT_DIR := "res://artifacts/hud_refined_polish/captures"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		await _capture_resolution(resolution)
	get_tree().quit()


func _capture_resolution(resolution: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = resolution
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(viewport)
	var preview := PREVIEW.instantiate()
	viewport.add_child(preview)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var suffix := "%dx%d" % [resolution.x, resolution.y]
	_save(viewport, "hud_refined_polish_%s.png" % suffix)
	if resolution == Vector2i(1920, 1080):
		var hud = preview.get_node("%CombatHUDRecraftV1")
		var slots: Array = hud.get("_spell_buttons")
		_save(viewport, "hud_refined_polish_utility_dock.png")
		hud.set_active_mode("move")
		_reset_slots(slots)
		await _settle(viewport)
		_save(viewport, "hud_refined_polish_move_selected.png")
		hud.set_active_mode("spell", slots[0].get_meta("spell"), false)
		await _settle(viewport)
		_save(viewport, "hud_refined_polish_spell_selected.png")
		hud.set_active_mode("")
		_reset_slots(slots)
		slots[1].set_visual_state(RecraftSpellSlotView.VisualState.DISABLED)
		await _settle(viewport)
		_save(viewport, "hud_refined_polish_spell_unavailable.png")
		_reset_slots(slots)
		slots[2].set_cooldown(2)
		await _settle(viewport)
		_save(viewport, "hud_refined_polish_cooldown.png")
		_reset_slots(slots)
		slots[3].set_visual_state(RecraftSpellSlotView.VisualState.UNAFFORDABLE)
		await _settle(viewport)
		_save(viewport, "hud_refined_polish_unaffordable.png")
		hud.get_node("%HealthBar").set_resource(12.0, 100.0, Color(0.62, 0.12, 0.14), null, "PV", true, false)
		await _settle(viewport)
		_save(viewport, "hud_refined_polish_low_health.png")
		var energy_bar = hud.get_node("%EnergyBar")
		energy_bar.visible = true
		energy_bar.set_resource(64.0, 100.0, Color(0.31, 0.58, 0.34), null, "N", true, false)
		await _settle(viewport)
		_save(viewport, "hud_refined_polish_preview_energy.png")
		energy_bar.visible = false
		await _settle(viewport)
		_save(viewport, "hud_refined_polish_without_energy.png")
	preview.queue_free()
	await get_tree().process_frame
	viewport.queue_free()


func _save(viewport: SubViewport, filename: String) -> void:
	var image := viewport.get_texture().get_image()
	var error := image.save_png("%s/%s" % [OUTPUT_DIR, filename])
	if error != OK:
		push_error("Capture failed: %s (%s)" % [filename, error])


func _reset_slots(slots: Array) -> void:
	for slot in slots:
		slot.set_visual_state(RecraftSpellSlotView.VisualState.NORMAL)


func _settle(viewport: SubViewport) -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
