@tool
class_name ArenaProductionService
extends RefCounted

const GENERATED_BY := "dungeon_draft_studio_1_2"
const DEFAULT_ROOT := "res://data/arenas/produced"
const RECOVERY_ROOT := "user://dungeon_draft_studio/production_recovery"
const MANIFEST_FILE := "production_manifest.json"
const GENERATOR_REVISION := 2


static func suggested_destination(arena: ArenaDefinition) -> String:
	return DEFAULT_ROOT.path_join(str(arena.arena_id) if arena != null else "nouvelle_arene")


static func plan(arena: ArenaDefinition, destination := "") -> Dictionary:
	if arena == null:
		return {"ok": false, "error": "arena_missing"}
	if destination.is_empty():
		destination = suggested_destination(arena)
	if not _valid_destination(destination):
		return {"ok": false, "error": "invalid_destination"}
	var report := ArenaValidator.validate(arena, false)
	var names := _output_names(arena)
	var old_manifest := _read_json(destination.path_join(MANIFEST_FILE))
	var owned := str(old_manifest.get("generated_by", "")) == GENERATED_BY
	var expected_hashes: Dictionary = old_manifest.get("files", {}) \
		if owned and old_manifest.get("files", {}) is Dictionary else {}
	var creates: Array[String] = []
	var modifies: Array[String] = []
	var conflicts: Array[String] = []
	for name in names:
		var path := destination.path_join(name)
		if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
			creates.append(path)
			continue
		if name == MANIFEST_FILE:
			if owned:
				modifies.append(path)
			else:
				conflicts.append(path)
			continue
		if not owned or not expected_hashes.has(name):
			conflicts.append(path)
			continue
		var current_hash := FileAccess.get_sha256(path)
		if current_hash != str(expected_hashes.get(name, "")):
			conflicts.append(path)
		else:
			modifies.append(path)
	return {
		"ok": true,
		"destination": destination,
		"validation": report,
		"creates": creates,
		"modifies": modifies,
		"conflicts": conflicts,
		"can_produce": report.is_valid() and conflicts.is_empty(),
		"source_fingerprint": ArenaEditSession.fingerprint(arena.to_snapshot()),
	}


static func produce(
		arena: ArenaDefinition,
		destination := "",
		provided_images := {}
	) -> Dictionary:
	var production_plan := plan(arena, destination)
	if not bool(production_plan.get("ok", false)):
		return production_plan
	if not bool(production_plan.get("can_produce", false)):
		return {
			"ok": false,
			"error": "validation_or_conflict",
			"plan": production_plan,
		}
	destination = str(production_plan.destination)
	var existing_manifest := _read_json(destination.path_join(MANIFEST_FILE))
	if str(existing_manifest.get("generated_by", "")) == GENERATED_BY \
			and int(existing_manifest.get("generator_revision", 0)) == GENERATOR_REVISION \
			and str(existing_manifest.get("source_fingerprint", "")) \
			== str(production_plan.source_fingerprint):
		var existing_arena_path := destination.path_join("arena.tres")
		var existing := ResourceLoader.load(
			existing_arena_path, "", ResourceLoader.CACHE_MODE_IGNORE
		) as ArenaDefinition
		if existing != null:
			var existing_report := ArenaValidator.validate(existing, false)
			if existing_report.is_valid() and ArenaEditSession.fingerprint(
					existing.to_snapshot()
				) == str(existing_manifest.get("produced_fingerprint", "")):
				return {
					"ok": true,
					"status": "SALLE_PRETE",
					"directory": destination,
					"arena_path": existing_arena_path,
					"validation": existing_report,
					"manifest": existing_manifest,
					"recovery": {"ok": true, "directory": "", "files": []},
					"created": [],
					"modified": [],
					"resources_reloaded": true,
					"direct_test_available": true,
					"idempotent_reuse": true,
				}
	var recovery := _create_recovery(production_plan)
	if not bool(recovery.get("ok", false)):
		return {"ok": false, "error": "recovery_failed", "details": recovery}
	var absolute := ProjectSettings.globalize_path(destination)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute)
	if directory_error != OK:
		return {"ok": false, "error": error_string(directory_error)}
	var clone := ArenaDefinition.new()
	if not clone.restore_snapshot(arena.to_snapshot()):
		return {"ok": false, "error": "snapshot_restore_failed"}
	clone.schema_version = ArenaDefinition.CURRENT_SCHEMA_VERSION
	clone.battle_scene = _battle_scene_for(clone)
	if clone.battle_scene == null:
		return {"ok": false, "error": "battle_scene_missing"}
	if clone.modular_visual_profile != null:
		var profile_path := destination.path_join("modular_visual_profile.tres")
		var profile_error := ResourceSaver.save(clone.modular_visual_profile, profile_path)
		if profile_error != OK:
			return {"ok": false, "error": error_string(profile_error), "file": profile_path}
		clone.modular_visual_profile = ResourceLoader.load(
			profile_path, "", ResourceLoader.CACHE_MODE_IGNORE
		) as ArenaModularVisualProfile
		if clone.modular_visual_profile == null:
			return {"ok": false, "error": "profile_reload_failed"}
	ArenaRuntimeBridge.sync_runtime_resources(clone)
	var arena_path := destination.path_join("arena.tres")
	var arena_error := ResourceSaver.save(clone, arena_path)
	if arena_error != OK:
		return {"ok": false, "error": error_string(arena_error), "file": arena_path}
	var reloaded := ResourceLoader.load(arena_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ArenaDefinition
	if reloaded == null:
		return {"ok": false, "error": "arena_reload_failed"}
	ArenaRuntimeBridge.sync_runtime_resources(reloaded)
	var produced_fingerprint := ArenaEditSession.fingerprint(reloaded.to_snapshot())
	var final_report := ArenaValidator.validate(reloaded, false)
	if not final_report.is_valid():
		return {"ok": false, "error": "produced_validation_failed", "validation": final_report}
	var art_result := ArenaArtKitExporter.export_kit(
		reloaded, destination.path_join("art_kit"), final_report, provided_images
	)
	if not bool(art_result.get("ok", false)):
		return {"ok": false, "error": "art_kit_failed", "details": art_result}
	var previews := _write_preview_images(reloaded, destination, provided_images)
	if not bool(previews.get("ok", false)):
		return previews
	var report_data := final_report.to_dict()
	report_data["generated_at"] = ""
	report_data["production"] = {
		"status": "SALLE_PRETE",
		"source_fingerprint": str(production_plan.source_fingerprint),
		"produced_fingerprint": produced_fingerprint,
	}
	if not _write_json(destination.path_join("validation_report.json"), report_data):
		return {"ok": false, "error": "validation_write_failed"}
	var configuration := {
		"arena_path": arena_path,
		"battle_scene": reloaded.battle_scene.resource_path,
		"configuration": "full_run",
		"heroes": [
			"res://data/units/alliés/elfe.tres",
			"res://data/units/alliés/mage.tres",
			"res://data/units/alliés/Guerrier.tres",
		],
	}
	if not _write_json(destination.path_join("test_configuration.json"), configuration):
		return {"ok": false, "error": "test_configuration_write_failed"}
	var hashes := {}
	for name in _output_names(reloaded):
		if name == MANIFEST_FILE:
			continue
		var path := destination.path_join(name)
		if FileAccess.file_exists(path):
			hashes[name] = FileAccess.get_sha256(path)
	var manifest := {
		"version": 1,
		"generator_revision": GENERATOR_REVISION,
		"generated_by": GENERATED_BY,
		"arena_id": str(reloaded.arena_id),
		"source_fingerprint": str(production_plan.source_fingerprint),
		"produced_fingerprint": produced_fingerprint,
		"battle_scene": reloaded.battle_scene.resource_path,
		"files": hashes,
		"art_kit": art_result.files,
	}
	if not _write_json(destination.path_join(MANIFEST_FILE), manifest):
		return {"ok": false, "error": "manifest_write_failed"}
	var verified := ResourceLoader.load(arena_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ArenaDefinition
	if verified == null or ArenaEditSession.fingerprint(verified.to_snapshot()) != produced_fingerprint:
		return {"ok": false, "error": "final_verification_failed"}
	return {
		"ok": true,
		"status": "SALLE_PRETE",
		"directory": destination,
		"arena_path": arena_path,
		"validation": final_report,
		"manifest": manifest,
		"recovery": recovery,
		"created": production_plan.creates,
		"modified": production_plan.modifies,
		"resources_reloaded": true,
		"direct_test_available": true,
	}


static func _battle_scene_for(arena: ArenaDefinition) -> PackedScene:
	var path := ArenaDefinition.MODULAR_BATTLE_SCENE \
		if arena.visual_mode == ArenaDefinition.VisualMode.MODULAR \
		else ArenaDefinition.DEFAULT_BATTLE_SCENE
	return load(path) as PackedScene if ResourceLoader.exists(path) else null


static func _output_names(arena: ArenaDefinition) -> Array[String]:
	var result: Array[String] = [
		"arena.tres", "thumbnail.png", "preview_logic.png", "preview_art.png",
		"preview_game.png", "validation_report.json", "test_configuration.json",
		"art_kit/map_reference.png", "art_kit/map_clean.png",
		"art_kit/map_logic.png", "art_kit/map_grid.png",
		"art_kit/map_game_preview.png", "art_kit/arena_definition.tres",
		"art_kit/art_brief.txt", "art_kit/validation_report.json",
		MANIFEST_FILE,
	]
	if arena.modular_visual_profile != null:
		result.append("modular_visual_profile.tres")
	return result


static func _write_preview_images(arena: ArenaDefinition, destination: String, provided: Dictionary) -> Dictionary:
	var fallbacks := {
		"preview_logic.png": ArenaArtKitExporter._logic_image(arena, false),
		"preview_art.png": ArenaArtKitExporter._background_image(arena),
		"preview_game.png": ArenaArtKitExporter._game_image(arena),
		"thumbnail.png": ArenaArtKitExporter._game_image(arena),
	}
	for name in fallbacks:
		var value = provided.get(name, fallbacks[name])
		if not value is Image or value.is_empty():
			value = fallbacks[name]
		var save_error := (value as Image).save_png(
			ProjectSettings.globalize_path(destination.path_join(name))
		)
		if save_error != OK:
			return {"ok": false, "error": error_string(save_error), "file": name}
	return {"ok": true}


static func _create_recovery(production_plan: Dictionary) -> Dictionary:
	var files: Array = production_plan.get("modifies", [])
	if files.is_empty():
		return {"ok": true, "directory": "", "files": []}
	var recovery_id := "%s/%d" % [
		str(production_plan.source_fingerprint).left(16), Time.get_ticks_usec(),
	]
	var destination := RECOVERY_ROOT.path_join(recovery_id)
	var absolute := ProjectSettings.globalize_path(destination)
	var error := DirAccess.make_dir_recursive_absolute(absolute)
	if error != OK:
		return {"ok": false, "error": error_string(error)}
	var copied: Array[String] = []
	var production_root := str(production_plan.get("destination", ""))
	for path_value in files:
		var path := str(path_value)
		if not FileAccess.file_exists(path):
			continue
		var relative := path.trim_prefix(production_root.trim_suffix("/") + "/")
		var target := destination.path_join(relative)
		var target_absolute := ProjectSettings.globalize_path(target)
		if DirAccess.make_dir_recursive_absolute(target_absolute.get_base_dir()) != OK:
			return {"ok": false, "error": "recovery_subdirectory_failed", "file": path}
		error = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(path), target_absolute
		)
		if error != OK:
			return {"ok": false, "error": error_string(error), "file": path}
		copied.append(target)
	return {"ok": true, "directory": destination, "files": copied}


static func _valid_destination(path: String) -> bool:
	return path.begins_with("res://") and not ".." in path \
		and path != "res://" and not path.ends_with(".tres")


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  "))
	file.close()
	return true
