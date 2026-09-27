extends SceneTree
const Studio := preload("res://addons/dungeon_draft_arena_studio/services/sprite_clip_service.gd")


func _initialize() -> void:
	var provenance: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://vfx/class_cards/permutation/provenance.json")
	)
	var exports: Array = []
	for id: String in provenance.assets:
		var asset: Dictionary = provenance.assets[id]
		var paths: Array = []
		# Studio requires nonempty drawings. The runtime keeps this intentional
		# transparent anticipation frame; the editing clip records its offset.
		var leading_empty := 0
		for i in range(leading_empty, int(asset.frames)):
			paths.append(
				"res://artifacts/dev/class_card_vfx/permutation/render/%s/frame_%04d.png"
				% [id, i + 1]
			)
		var result := Studio.new_clip(
			paths,
			paths[mini(5, paths.size() - 1)],
			"permutation_" + id + "_E",
		)
		if not result.ok:
			push_error(str(result))
			quit(1)
			return
		var doc: Dictionary = result.document
		doc.id = "permutation_" + id
		doc.title = "Permutation — " + id
		doc.intent = "Production de la planche G validée le 27 septembre. Agrafes synchronisées et fente de bascule."
		doc.anchor = [roundi(asset.pivot[0]), roundi(asset.pivot[1])]
		for frame in doc.frames:
			frame.duration_ms = 1000.0 / 30.0
		doc.events = []
		doc.provenance = {
			"res://vfx/class_cards/permutation/provenance.json": FileAccess.get_sha256(
				"res://vfx/class_cards/permutation/provenance.json"
			),
		}
		doc["runtime_mapping"] = {
			"runtime_atlas": "res://vfx/class_cards/permutation/" + id + ".png",
			"leading_transparent_frames": leading_empty,
			"runtime_start_offset_ms": leading_empty * 1000.0 / 30.0,
		}
		doc.baseline.frames = doc.frames.duplicate(true)
		doc.baseline.anchor = doc.anchor.duplicate()
		doc.baseline.events = doc.events.duplicate(true)
		var saved := Studio.write_json("res://art/source/sprite_workshop/" + doc.id + ".json", doc)
		var exported := Studio.export_clip(doc) if saved.ok else saved
		if not exported.ok:
			push_error(str(exported))
			quit(1)
			return
		exports.append(exported)
	print(JSON.stringify({ "ok": true, "clips": exports }))
	quit(0)
