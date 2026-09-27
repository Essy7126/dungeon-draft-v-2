extends SceneTree
const Studio := preload("res://addons/dungeon_draft_arena_studio/services/sprite_clip_service.gd")


func _initialize() -> void:
	var exports: Array = []
	for layer in ["back", "front"]:
		var paths: Array = []
		for i in 48:
			paths.append(
				"res://artifacts/dev/class_card_vfx/bastion/render/%s/frame_%04d.png"
				% [layer, i + 1]
			)
		var result := Studio.new_clip(paths, paths[16], "bastion_vivant_%s_E" % layer)
		if not result.ok:
			push_error(str(result))
			quit(1)
			return
		var document: Dictionary = result.document
		document.id = "bastion_vivant_" + layer
		document.title = "Bastion vivant — plan " + layer
		document.intent = "Trois plaques articulées après attribution réelle, verrouillage, retrait vers le signe actif. Plan séparé pour garder le personnage visible."
		document.anchor = [192, 246]
		for frame in document.frames:
			frame.duration_ms = 1000.0 / 30.0
		document.events = [
			{ "name": "left_lock", "frame": "f008" },
			{ "name": "rear_lock", "frame": "f010" },
			{ "name": "right_lock", "frame": "f012" },
		]
		document.baseline.frames = document.frames.duplicate(true)
		document.baseline.anchor = document.anchor.duplicate()
		document.baseline.events = document.events.duplicate(true)
		var saved := Studio.write_json(
			"res://art/source/sprite_workshop/" + document.id + ".json",
			document,
		)
		var exported := Studio.export_clip(document) if saved.ok else saved
		exports.append(exported)
		if not exported.ok:
			push_error(str(exported))
			quit(1)
			return
	print(JSON.stringify({ "ok": true, "clips": exports }))
	quit(0)
