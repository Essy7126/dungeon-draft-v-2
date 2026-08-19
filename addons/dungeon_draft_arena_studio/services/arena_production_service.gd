@tool
class_name ArenaProductionService
extends RefCounted

## Builds a complete bundle in a caller-owned staging directory. Publication
## into the canonical destination is exclusively owned by
## ArenaProductionTransactionService.

const GENERATED_BY := StudioVersion.GENERATED_BY
const COMPATIBLE_GENERATORS := [
	"dungeon_draft_studio_1_2",
	"dungeon_draft_studio_1_2_1",
	"dungeon_draft_studio_1_3_0",
	"dungeon_draft_studio_1_3_1",
	GENERATED_BY,
]
const DEFAULT_ROOT := "res://data/arenas/produced"
const MANIFEST_FILE := "production_manifest.json"
const MANIFEST_SCHEMA_VERSION := 3
const FINGERPRINT_ALGORITHM_ID := "arena_snapshot_canonical_json_sha256_v1"
const GENERATOR_REVISION := 5


static func suggested_destination(arena: ArenaDefinition) -> String:
	return DEFAULT_ROOT.path_join(str(arena.arena_id) if arena != null else "nouvelle_arene")


static func plan(
		arena: ArenaDefinition,
		destination := "",
		graph: StudioReferenceGraphService = null,
		options: Dictionary = {}
	) -> Dictionary:
	if arena == null:
		return {"ok": false, "error": "arena_missing"}
	if destination.is_empty():
		destination = suggested_destination(arena)
	if not _valid_destination(destination):
		return {"ok": false, "error": "invalid_destination"}
	var report := ArenaValidator.validate(arena, false)
	var visual_report := ArenaVisualAssembler.inspect(arena)
	var automatic_smoke := ArenaAutomaticRuntimeSmokeService.run(arena)
	var compatibility_outputs := _is_diagnostic_destination(destination)
	var names := _output_names(arena, compatibility_outputs)
	var inspection := ArenaBundleInspectionService.inspect(destination, graph)
	var bundle_resolution := ArenaBundleResolutionService.plan(
		arena, destination, inspection, graph
	)
	var owned: bool = inspection.state in [
		ArenaBundleInspectionService.OWNED_COMPLETE,
		ArenaBundleInspectionService.REFERENCED_COMPLETE,
	]
	var old_manifest: Dictionary = inspection.get("manifest", {})
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
		elif FileAccess.get_sha256(path) != str(expected_hashes.get(name, "")):
			conflicts.append(path)
		else:
			modifies.append(path)
	if inspection.state not in [
		ArenaBundleInspectionService.EMPTY,
		ArenaBundleInspectionService.OWNED_COMPLETE,
		ArenaBundleInspectionService.REFERENCED_COMPLETE,
	]:
		for relative_path in inspection.get("files", {}):
			var conflict_path := destination.path_join(str(relative_path))
			if not conflicts.has(conflict_path):
				conflicts.append(conflict_path)
	var topology_parity := {
		"valid": bool(automatic_smoke.get("topology_hashes_identical", false)) \
			and str(automatic_smoke.get("expected_floor_hash", "")) \
				== str(automatic_smoke.get("rendered_floor_hash", "")) \
			and (automatic_smoke.get("missing_cells", []) as Array).is_empty() \
			and (automatic_smoke.get("unexpected_cells", []) as Array).is_empty() \
			and (automatic_smoke.get("removed_cells_rendered", []) as Array).is_empty() \
			and (automatic_smoke.get("duplicate_cells", []) as Array).is_empty(),
		"canonical_topology_hash": automatic_smoke.get("working_topology_hash", ""),
		"temporary_topology_hash": automatic_smoke.get("temporary_topology_hash", ""),
		"runtime_topology_hash": automatic_smoke.get("runtime_topology_hash", ""),
		"expected_floor_hash": automatic_smoke.get("expected_floor_hash", ""),
		"rendered_floor_hash": automatic_smoke.get("rendered_floor_hash", ""),
		"missing_cells": automatic_smoke.get("missing_cells", []),
		"unexpected_cells": automatic_smoke.get("unexpected_cells", []),
		"removed_cells_rendered": automatic_smoke.get("removed_cells_rendered", []),
		"duplicate_cells": automatic_smoke.get("duplicate_cells", []),
	}
	var gate_report := ArenaIntegrationGatePolicy.evaluate(
		report, topology_parity, visual_report, automatic_smoke, inspection,
		ArenaIntegrationGatePolicy.Profile.PRODUCTION, {
			"arena_fingerprint": ArenaSnapshotService.arena_fingerprint(arena),
			"manual_test_performed": false,
			"art_alignment_confirmed": true,
			"destination_conflicts": conflicts,
			"requires_runtime_scene": false,
			"runtime_scene_result": options.get("runtime_scene_result", {}),
		}
	)
	return {
		"ok": true,
		"destination": destination,
		"validation": report,
		"creates": creates,
		"modifies": modifies,
		"conflicts": conflicts,
		"can_produce": bool(gate_report.ready_to_produce) and conflicts.is_empty(),
		"visual_report": visual_report,
		"automatic_runtime_smoke": automatic_smoke,
		"topology_parity": topology_parity,
		"gate_report": gate_report,
		"source_fingerprint": ArenaSnapshotService.arena_fingerprint(arena),
		"gameplay_fingerprint": ArenaSnapshotService.gameplay_fingerprint(arena),
		"bundle_state": inspection.state,
		"bundle_inspection": inspection,
		"bundle_resolution": bundle_resolution,
		"compatibility_outputs": compatibility_outputs,
	}


static func produce(
		arena: ArenaDefinition,
		destination := "",
		provided_images := {}
	) -> Dictionary:
	return ArenaProductionTransactionService.produce(
		arena, destination, provided_images
	)


static func produce_with_options(
		arena: ArenaDefinition,
		destination := "",
		provided_images := {},
		options := {}
	) -> Dictionary:
	return ArenaProductionTransactionService.produce(
		arena, destination, provided_images, options
	)


static func build_staged_bundle(
		arena: ArenaDefinition,
		staging: String,
		published_destination: String,
		provided_images := {},
		options := {}
	) -> Dictionary:
	if arena == null or not _valid_destination(staging):
		return {"ok": false, "error": "invalid_staging"}
	var compatibility_outputs := bool(options.get(
		"compatibility_outputs", _is_diagnostic_destination(published_destination)
	))
	var failure_step := str(options.get("failure_step", ""))
	var absolute := ProjectSettings.globalize_path(staging)
	if DirAccess.make_dir_recursive_absolute(absolute) != OK:
		return {"ok": false, "error": "staging_create_failed"}
	var clone := ArenaDefinition.new()
	if not ArenaSnapshotService.restore(clone, ArenaSnapshotService.capture(arena)):
		return {"ok": false, "error": "snapshot_restore_failed"}
	clone.schema_version = ArenaDefinition.CURRENT_SCHEMA_VERSION
	clone.battle_scene = _battle_scene_for(clone)
	if clone.battle_scene == null:
		return {"ok": false, "error": "battle_scene_missing"}
	var runtime_assets := _write_runtime_assets(
		clone, staging, published_destination, provided_images
	)
	if not runtime_assets.get("ok", false):
		return runtime_assets
	if failure_step == "after_runtime_assets":
		return _injected_failure(failure_step)
	if clone.modular_visual_profile != null:
		var profile_path := staging.path_join("modular_visual_profile.tres")
		var profile_error := ResourceSaver.save(clone.modular_visual_profile, profile_path)
		if profile_error != OK:
			return {"ok": false, "error": error_string(profile_error), "file": profile_path}
		clone.modular_visual_profile = ResourceLoader.load(
			profile_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as ArenaModularVisualProfile
		if clone.modular_visual_profile == null:
			return {"ok": false, "error": "profile_reload_failed"}
	if failure_step == "after_profile":
		return _injected_failure(failure_step)
	ArenaRuntimeBridge.sync_runtime_resources(clone)
	var expected_produced_fingerprint := ArenaSnapshotService.arena_fingerprint(clone)
	var arena_path := staging.path_join("arena.tres")
	var arena_error := ResourceSaver.save(
		clone, arena_path, ResourceSaver.FLAG_RELATIVE_PATHS
	)
	if arena_error != OK:
		return {"ok": false, "error": error_string(arena_error), "file": arena_path}
	if not _relativize_bundle_references(arena_path, staging):
		return {"ok": false, "error": "relative_reference_write_failed"}
	if failure_step == "after_arena":
		return _injected_failure(failure_step)
	var reloaded := ResourceLoader.load(
		arena_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	if reloaded == null:
		return {"ok": false, "error": "arena_reload_failed"}
	var produced_fingerprint := ArenaSnapshotService.arena_fingerprint(reloaded)
	var gameplay_fingerprint := ArenaSnapshotService.gameplay_fingerprint(reloaded)
	if produced_fingerprint != expected_produced_fingerprint \
			or gameplay_fingerprint != ArenaSnapshotService.gameplay_fingerprint(arena):
		return {
			"ok": false,
			"error": "staged_fingerprint_mismatch",
			"expected_arena": expected_produced_fingerprint,
			"actual_arena": produced_fingerprint,
		}
	var final_report := ArenaValidator.validate(reloaded, false)
	if not final_report.is_valid():
		return {"ok": false, "error": "produced_validation_failed", "validation": final_report}
	var final_visual_report := ArenaVisualAssembler.inspect(reloaded)
	if not final_visual_report.valid:
		return {"ok": false, "error": "visual_assembly_failed", "visual_report": final_visual_report}
	var art_result := {"ok": true, "files": []}
	if compatibility_outputs:
		art_result = ArenaArtKitExporter.export_kit(
			reloaded, staging.path_join("art_kit"), final_report, provided_images
		)
		if not art_result.get("ok", false):
			return {"ok": false, "error": "art_kit_failed", "details": art_result}
	if failure_step == "after_art":
		return _injected_failure(failure_step)
	if compatibility_outputs:
		var previews := _write_preview_images(reloaded, staging, provided_images)
		if not previews.get("ok", false):
			return previews
		if not _write_compatibility_reports(
			reloaded, staging, final_report, final_visual_report, produced_fingerprint
		):
			return {"ok": false, "error": "compatibility_report_write_failed"}
	if failure_step == "after_preview":
		return _injected_failure(failure_step)
	if failure_step == "before_manifest":
		return _injected_failure(failure_step)
	var hashes := {}
	for name in _output_names(reloaded, compatibility_outputs):
		if name == MANIFEST_FILE:
			continue
		var path := staging.path_join(name)
		if FileAccess.file_exists(path):
			hashes[name] = FileAccess.get_sha256(path)
	var manifest := {
		"version": MANIFEST_SCHEMA_VERSION,
		"manifest_schema_version": MANIFEST_SCHEMA_VERSION,
		"studio_product_version": StudioVersion.PRODUCT_VERSION,
		"generator_revision": GENERATOR_REVISION,
		"generated_by": GENERATED_BY,
		"complete": true,
		"arena_id": str(reloaded.arena_id),
		"fingerprint_algorithm_id": FINGERPRINT_ALGORITHM_ID,
		"physical_file_hash": hashes.duplicate(true),
		"logical_arena_fingerprint": produced_fingerprint,
		"gameplay_fingerprint": gameplay_fingerprint,
		# Compatibility aliases remain readable by older Studio builds. They are
		# never used to conflate physical integrity with logical identity.
		"source_fingerprint": ArenaSnapshotService.arena_fingerprint(arena),
		"source_gameplay_fingerprint": ArenaSnapshotService.gameplay_fingerprint(arena),
		"produced_fingerprint": produced_fingerprint,
		"produced_gameplay_fingerprint": gameplay_fingerprint,
		"battle_scene": reloaded.battle_scene.resource_path,
		"files": hashes,
		"runtime_bundle": not compatibility_outputs,
		"art_kit": art_result.get("files", []),
		"visual_assembly": final_visual_report.to_dict(),
		"runtime_assets": runtime_assets.get("files", []),
	}
	if not _write_json(staging.path_join(MANIFEST_FILE), manifest):
		return {"ok": false, "error": "manifest_write_failed"}
	return {
		"ok": true,
		"status": "STAGED",
		"directory": staging,
		"arena_path": arena_path,
		"validation": final_report,
		"manifest": manifest,
		"resources_reloaded": true,
		"direct_test_available": true,
		"visual_report": final_visual_report,
		"compatibility_outputs": compatibility_outputs,
	}


static func _battle_scene_for(arena: ArenaDefinition) -> PackedScene:
	var path := ArenaDefinition.MODULAR_BATTLE_SCENE \
		if arena.visual_mode == ArenaDefinition.VisualMode.MODULAR \
		else ArenaDefinition.DEFAULT_BATTLE_SCENE
	return load(path) as PackedScene if ResourceLoader.exists(path) else null


static func _output_names(
		arena: ArenaDefinition,
		compatibility_outputs := false
	) -> Array[String]:
	var result: Array[String] = ["arena.tres", MANIFEST_FILE]
	if arena.modular_visual_profile != null:
		result.append("modular_visual_profile.tres")
	for property_name in ["background_path", "foreground_path", "occlusion_mask_path"]:
		var value := str(arena.get(property_name))
		if value.contains("/assets/"):
			result.append("assets/%s" % value.get_file())
	if not compatibility_outputs:
		return result
	result.append_array([
		"thumbnail.png", "preview_logic.png", "preview_art.png", "preview_game.png",
		"validation_report.json", "test_configuration.json",
		"art_kit/map_reference.png", "art_kit/map_clean.png",
		"art_kit/map_logic.png", "art_kit/map_grid.png",
		"art_kit/map_game_preview.png", "art_kit/arena_definition.tres",
		"art_kit/reference_clean.png", "art_kit/reference_grid.png",
		"art_kit/reference_coordinates.png", "art_kit/reference_gameplay.png",
		"art_kit/reference_walls.png", "art_kit/playable_mask.png",
		"art_kit/void_mask.png", "art_kit/wall_mask.png",
		"art_kit/foreground_guide.png", "art_kit/depth_guide.png",
		"art_kit/alignment_markers.png", "art_kit/art_brief.txt",
		"art_kit/art_brief.md", "art_kit/arena_art_manifest.json",
		"art_kit/validation_report.json",
	])
	return result


static func _write_runtime_assets(
		clone: ArenaDefinition,
		staging: String,
		published_destination: String,
		provided: Dictionary
	) -> Dictionary:
	var files := PackedStringArray()
	var mappings := {
		"background.png": "background_path",
		"foreground.png": "foreground_path",
		"occlusion.png": "occlusion_mask_path",
	}
	for file_name in mappings:
		var supplied = provided.get(file_name)
		var property_name := str(mappings[file_name])
		var working_path := str(clone.get(property_name))
		if (not supplied is Image or supplied.is_empty()) \
				and working_path.begins_with("user://"):
			if not FileAccess.file_exists(working_path):
				return {
					"ok": false,
					"error": "transient_visual_missing",
					"property": property_name,
				}
			var staged_image := Image.load_from_file(
				ProjectSettings.globalize_path(working_path)
			)
			if staged_image == null or staged_image.is_empty():
				return {
					"ok": false,
					"error": "transient_visual_invalid",
					"property": property_name,
				}
			supplied = staged_image
		if not supplied is Image or supplied.is_empty():
			if not working_path.is_empty() \
					and not working_path.begins_with("res://") \
					and not working_path.begins_with("uid://"):
				return {
					"ok": false,
					"error": "absolute_visual_path_forbidden",
					"property": property_name,
				}
			continue
		var assets := staging.path_join("assets")
		if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(assets)) != OK:
			return {"ok": false, "error": "runtime_assets_directory_failed"}
		var staged_path := assets.path_join(file_name)
		var save_error := (supplied as Image).save_png(ProjectSettings.globalize_path(staged_path))
		if save_error != OK:
			return {"ok": false, "error": error_string(save_error), "file": staged_path}
		clone.set(property_name, published_destination.path_join("assets").path_join(file_name))
		files.append("assets/%s" % file_name)
	for property_name in mappings.values():
		var final_path := str(clone.get(property_name))
		var diagnostic_asset_root := published_destination.path_join("assets") + "/"
		if final_path.begins_with("user://") \
				and not final_path.begins_with(diagnostic_asset_root):
			return {
				"ok": false,
				"error": "transient_visual_path_not_materialized",
				"property": property_name,
			}
	return {"ok": true, "files": files}


static func _write_preview_images(
		arena: ArenaDefinition,
		destination: String,
		provided: Dictionary
	) -> Dictionary:
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


static func _write_compatibility_reports(
		arena: ArenaDefinition,
		destination: String,
		report: ArenaValidationReport,
		visual_report: ArenaVisualAssemblyReport,
		produced_fingerprint: String
	) -> bool:
	var report_data := report.to_dict()
	report_data["generated_at"] = ""
	report_data["production"] = {
		"status": "SALLE_PRETE",
		"produced_fingerprint": produced_fingerprint,
		"visual_assembly": visual_report.to_dict(),
	}
	if not _write_json(destination.path_join("validation_report.json"), report_data):
		return false
	return _write_json(destination.path_join("test_configuration.json"), {
		"arena_path": destination.path_join("arena.tres"),
		"battle_scene": arena.battle_scene.resource_path,
		"configuration": "full_run",
		"heroes": [
			"res://data/units/alliés/elfe.tres",
			"res://data/units/alliés/mage.tres",
			"res://data/units/alliés/Guerrier.tres",
		],
	})


static func _valid_destination(path: String) -> bool:
	return not path.is_empty() and not ".." in path and not path.ends_with(".tres") \
		and (path.begins_with("res://") or path.begins_with("user://"))


static func _is_diagnostic_destination(path: String) -> bool:
	return path.begins_with("res://artifacts/") or path.begins_with("user://artifacts/")


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


static func _relativize_bundle_references(arena_path: String, staging: String) -> bool:
	# ResourceSaver keeps an absolute res:// path when the referenced Resource
	# already owns one. Make bundle-local references portable before the first
	# reload; this is still staging-only and therefore cannot expose partial work.
	var text := FileAccess.get_file_as_string(arena_path)
	if text.is_empty():
		return false
	text = text.replace(staging.trim_suffix("/") + "/", "")
	var file := FileAccess.open(arena_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


static func _injected_failure(step: String) -> Dictionary:
	return {"ok": false, "error": "injected_failure", "failure_step": step}
