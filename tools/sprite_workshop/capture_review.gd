extends RefCounted
## Repeatable UI exercise and captures. These validate the workshop, not the art.

const Clips := preload("res://addons/dungeon_draft_arena_studio/services/sprite_clip_service.gd")
const Workshop := preload("res://tools/sprite_workshop/SpriteWorkshop.tscn")


func run(host: Node, output_root: String) -> Dictionary:
	if not output_root.begins_with(Clips.OUTPUT_ROOT) or not Clips.writable(output_root):
		return Clips.failure("Dossier de capture invalide.")
	if DisplayServer.get_name() == "headless":
		return Clips.failure("Les captures nécessitent un moteur avec rendu.")
	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(output_root)
	)
	if directory_error != OK:
		return Clips.failure(error_string(directory_error))
	var workshop := Workshop.instantiate()
	host.add_child(workshop)
	workshop.load_clip(Clips.SOURCE_ROOT + "sentinelle_attack_e.json")
	if workshop.document.is_empty():
		workshop.queue_free()
		return Clips.failure("Document de capture absent ou invalide.")
	var original: Dictionary = workshop.document.duplicate(true)
	workshop.select_frame(0)
	workshop.duration_input.value = original.frames[0].duration_ms + 30
	if workshop.document.frames[0].duration_ms != original.frames[0].duration_ms + 30:
		workshop.queue_free()
		return Clips.failure("Le champ de durée ne modifie pas la pose.")
	workshop.undo_edit()
	if Clips.fingerprint(workshop.document) != Clips.fingerprint(original):
		workshop.queue_free()
		return Clips.failure("Annuler ne restitue pas le document.")
	var captures := []
	for resolution in [Vector2i(1440, 900), Vector2i(1280, 900)]:
		host.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		host.get_window().size = resolution
		workshop.select_frame(4)
		workshop.onion_button.button_pressed = true
		await host.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := output_root.path_join("sentinelle_%dx%d.png" % [resolution.x, resolution.y])
		var error := host.get_viewport().get_texture().get_image().save_png(path)
		if error != OK:
			workshop.queue_free()
			return Clips.failure(error_string(error))
		captures.append(path)
	workshop.load_clip(Clips.SOURCE_ROOT + "achille_dash_e.json")
	workshop.arrival_input.value = 800
	workshop.elapsed_ms = 799
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	if workshop.preview_original.frame != 2 or workshop.preview_candidate.frame != 2:
		workshop.queue_free()
		return Clips.failure("La comparaison doit partager l'arrivée simulée.")
	await RenderingServer.frame_post_draw
	var airborne := output_root.path_join("achille_attente_799ms.png")
	var error := host.get_viewport().get_texture().get_image().save_png(airborne)
	if error != OK:
		workshop.queue_free()
		return Clips.failure(error_string(error))
	captures.append(airborne)
	workshop.elapsed_ms = 800
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	if workshop.preview_original.frame != 3 or workshop.preview_candidate.frame != 3:
		workshop.queue_free()
		return Clips.failure("La réception doit suivre l'arrivée simulée.")
	await RenderingServer.frame_post_draw
	var landing := output_root.path_join("achille_reception_800ms.png")
	error = host.get_viewport().get_texture().get_image().save_png(landing)
	if error != OK:
		workshop.queue_free()
		return Clips.failure(error_string(error))
	captures.append(landing)
	workshop.queue_free()
	await host.get_tree().process_frame
	return {
		"ok": true,
		"captures": captures,
		"checks": [
			"duration_control",
			"undo_restores_document",
			"shared_arrival_hold",
			"shared_arrival_landing",
		],
		"visual_review_required": true,
		"artistic_validation": "pending",
	}
