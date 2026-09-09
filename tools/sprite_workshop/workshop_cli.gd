extends Node

const Clips := preload("res://addons/dungeon_draft_arena_studio/services/sprite_clip_service.gd")


func _ready() -> void:
	call_deferred("run")


func run() -> void:
	var args := { }
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and "=" in argument:
			args[argument.get_slice("=", 0).trim_prefix("--")] = argument.substr(
				argument.find("=") + 1
			)
	var result: Dictionary
	match args.get("command", "check"):
		"capture":
			var capture := preload("res://tools/sprite_workshop/capture_review.gd").new()
			result = await capture.run(
				self,
				Clips.OUTPUT_ROOT + "ui_review/"
				+ str(args.get("report", "local")).replace("\\", "/").get_base_dir().get_file(),
			)
		"seed":
			result = seed_examples()
		"new":
			if FileAccess.file_exists(args.get("clip", "")):
				result = Clips.failure("Ce document existe déjà. Choisir un nouveau chemin.")
			else:
				var paths: Variant = JSON.parse_string(args.get("frames", "[]"))
				result = (
					Clips.new_clip(paths, args.get("reference", ""), args.get("animation", ""))
					if paths is Array
					else Clips.failure("Liste de PNG invalide.")
				)
				if result.ok:
					result = Clips.write_json(args.get("clip", ""), result.document)
		"import":
			if FileAccess.file_exists(args.get("clip", "")):
				result = Clips.failure(
					"Ce document existe déjà. Choisir un nouveau chemin pour l'import."
				)
			else:
				result = Clips.import_clip(
					args.get("resource", ""),
					args.get("animation", ""),
					args.get("profile", ""),
				)
				if result.ok:
					result = Clips.write_json(args.get("clip", ""), result.document)
		"check", "export":
			result = Clips.read_document(args.get("clip", ""))
			if result.ok:
				result = (
					Clips.export_clip(result.document)
					if args.get("command") == "export"
					else Clips.validate(result.document)
				)
		_:
			result = Clips.failure("Commande inconnue.")
	var report_path: String = args.get("report", "")
	if report_path.is_empty():
		print(JSON.stringify(result))
	else:
		# The dev harness supplies this exact report path in its unique run directory.
		var local := ProjectSettings.localize_path(report_path)
		if not local.begins_with("res://artifacts/dev/") or ".." in local:
			result = Clips.failure("Dossier de rapport invalide.")
		else:
			var file := FileAccess.open(local, FileAccess.WRITE)
			if file == null:
				result = Clips.failure("Impossible d'écrire le rapport.")
			else:
				file.store_string(JSON.stringify(result, "\t") + "\n")
	print("SPRITE_WORKSHOP=" + JSON.stringify({ "ok": result.ok, "report": report_path }))
	get_tree().quit(0 if result.ok else 1)


static func seed_examples(root := Clips.SOURCE_ROOT) -> Dictionary:
	var examples := [
		[
			"achille_dash_e",
			"Ruée d'Achille · référence",
			"res://assets/characters/Achilles/sprites_polish_v3/achilles_sprite_frames.tres",
			"dash_E",
			"res://data/visuals/achilles/achilles_polish_sprite_profile_v3.tres",
		],
		[
			"sentinelle_attack_e",
			"Attaque de la Sentinelle · à retravailler",
			"res://assets/characters/catabase_monsters/sentinelle_airain/sprite_frames.tres",
			"attack_E",
			"res://data/visuals/catabase_monsters/sentinelle_airain_sprite_profile.tres",
		],
	]
	var written := []
	var preserved := []
	for example in examples:
		var path: String = root.path_join(example[0] + ".json")
		if FileAccess.file_exists(path):
			preserved.append(path)
			continue
		var imported := Clips.import_clip(example[2], example[3], example[4])
		if not imported.ok:
			return imported
		var doc: Dictionary = imported.document
		doc.id = example[0]
		doc.title = example[1]
		if example[0] == "achille_dash_e":
			doc.intent = "Référence positive conservée : préparation, poussée, vol maintenu, réception. La translation appartient au contrôleur."
			doc.playback = { "mode": "arrival", "hold_frame": "f002", "arrival_preview_ms": 500.0 }
			for index in 4:
				doc.frames[index].duration_ms = [50.0, 50.0, 400.0, 80.0][index]
			doc.events = [
				{ "name": "release", "frame": "f002" },
				{ "name": "arrival", "frame": "f003" },
			]
			doc.open_questions = [
				"La durée d'arrivée de l'atelier est un scénario de revue, pas une durée fixe de déplacement en jeu."
			]
		else:
			doc.intent = "Tester la lisibilité de l'estoc, les appuis et les articulations ; conserver l'identité et l'équipement."
			doc.events = [{ "name": "release", "frame": "f004" }]
			doc.open_questions = [
				"Comparer d'abord une correction des poses existantes à une pose clé redessinée. Aucune nouvelle animation artistique produite par cet import."
			]
		doc.baseline.frames = doc.frames.duplicate(true)
		doc.baseline.playback = doc.playback.duplicate(true)
		doc.baseline.events = doc.events.duplicate(true)
		var check := Clips.validate(doc)
		if not check.ok:
			return check
		var saved := Clips.write_json(path, doc)
		if not saved.ok:
			return saved
		written.append(path)
	return {
		"ok": true,
		"written": written,
		"preserved": preserved,
		"artistic_validation": "pending",
	}
