extends SceneTree
## Reuse Studio's clip service for editable timing and pixel roundtrip review.
const Studio := preload("res://addons/dungeon_draft_arena_studio/services/sprite_clip_service.gd")


func _initialize() -> void:
	var paths: Array = []
	for i in 48:
		paths.append("res://artifacts/dev/class_card_vfx/sentence/hammer/frame_%04d.png" % (i + 1))
	# Studio requires a direction suffix; this target-local effect has one fixed view.
	var result := Studio.new_clip(paths, paths[10], "sentence_rempart_E")
	if not result.ok:
		push_error(str(result))
		quit(1)
		return
	var document: Dictionary = result.document
	document.id = "sentence_rempart"
	document.title = "Sentence du rempart — masse d'airain"
	document.intent = "Armement, accélération, contact à 0,5 s, rebond lourd et retrait. Objet Blender original ; contact et débris assemblés dans Godot."
	document.anchor = [192, 291]
	for frame in document.frames:
		frame.duration_ms = 1000.0 / 30.0
	document.events = [{ "name": "contact", "frame": "f015" }]
	document.baseline.frames = document.frames.duplicate(true)
	document.baseline.anchor = document.anchor.duplicate()
	document.baseline.events = document.events.duplicate(true)
	var saved := Studio.write_json(
		"res://art/source/sprite_workshop/sentence_rempart.json",
		document,
	)
	var exported := Studio.export_clip(document) if saved.ok else saved
	print(JSON.stringify(exported))
	quit(0 if exported.ok else 1)
