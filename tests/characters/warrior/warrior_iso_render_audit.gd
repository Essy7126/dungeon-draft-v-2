extends Node

const SCENE := preload("res://characters/warrior/WarriorIsoUnitView.tscn")
const OUTPUT := "C:/Blender_AI_Test/Output/warrior_iso_render_audit.json"
const IMAGE_DIR := "C:/Blender_AI_Test/Output/warrior_iso_render"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(IMAGE_DIR)
	var iso := SCENE.instantiate() as WarriorIsoUnitView
	add_child(iso)
	for _frame in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var visual := iso.get_warrior_visual()
	var player := visual.get_animation_player()
	var report := {
		"viewport_size": [iso.character_viewport.size.x, iso.character_viewport.size.y],
		"camera_size": iso.camera_orthographic_size,
		"character_scale": iso.character_scale,
		"display_scale": [iso.render_sprite.scale.x, iso.render_sprite.scale.y],
		"msaa_3d": iso.character_viewport.msaa_3d,
		"taa": iso.character_viewport.use_taa,
		"screen_space_aa": iso.character_viewport.screen_space_aa,
		"animations": {},
		"errors": [],
	}
	for animation_name in WarriorVisual3D.IMPORTED_ANIMATIONS:
		var animation := player.get_animation(animation_name)
		if animation == null:
			report.errors.append("Missing %s" % animation_name)
			continue
		player.play(animation_name, 0.0, 1.0)
		var union := Rect2i()
		var first := true
		var sample_reports := []
		for fraction in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]:
			player.seek(animation.length * fraction, true)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image := iso.character_viewport.get_texture().get_image()
			var bounds := _alpha_bounds(image)
			union = bounds if first else union.merge(bounds)
			first = false
			sample_reports.append({"fraction": fraction, "bounds": _rect_array(bounds)})
			if absf(fraction - 0.6) < 0.01:
				image.save_png("%s/%s.png" % [IMAGE_DIR, str(animation_name)])
		var margins := [
			union.position.x,
			union.position.y,
			iso.character_viewport.size.x - union.end.x,
			iso.character_viewport.size.y - union.end.y,
		]
		report.animations[animation_name] = {
			"length": animation.length,
			"loop_mode": animation.loop_mode,
			"union_bounds": _rect_array(union),
			"height_ratio": float(union.size.y) / iso.character_viewport.size.y,
			"margins": margins,
			"clipped": margins.min() <= 2,
			"samples": sample_reports,
		}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("WARRIOR_ISO_RENDER_AUDIT=", JSON.stringify(report))
	iso.queue_free()
	get_tree().quit(0 if report.errors.is_empty() else 2)


func _alpha_bounds(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.02:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _rect_array(rect: Rect2i) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
