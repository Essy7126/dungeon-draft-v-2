@tool
class_name ArenaReportExporter
extends RefCounted

const ROOT := "res://artifacts/arena_studio"


static func export_report(
		arena: ArenaDefinition,
		report: ArenaValidationReport,
		test_log := ""
	) -> Dictionary:
	if arena == null or report == null:
		return {"ok": false, "error": "Aucune validation a exporter."}
	var directory := ROOT.path_join(str(arena.arena_id))
	var absolute := ProjectSettings.globalize_path(directory)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute)
	if directory_error != OK:
		return {"ok": false, "error": error_string(directory_error)}
	var definition := arena.to_snapshot()
	definition["runtime_entry"] = arena.battle_scene.resource_path \
		if arena.battle_scene != null else ""
	definition["godot_version"] = Engine.get_version_info().get("string", "unknown")
	definition.merge(StudioVersion.metadata("arena_report"), true)
	var report_data := report.to_dict()
	report_data.merge(StudioVersion.metadata("arena_validation"), true)
	var outputs := {
		"validation_report.json": JSON.stringify(report_data, "  "),
		"validation_report.md": report.to_markdown(),
		"arena_definition.json": JSON.stringify(definition, "  "),
		"test_log.txt": test_log,
	}
	for file_name in outputs:
		var file := FileAccess.open(directory.path_join(file_name), FileAccess.WRITE)
		if file == null:
			return {"ok": false, "error": error_string(FileAccess.get_open_error())}
		file.store_string(outputs[file_name])
	return {"ok": true, "directory": directory}


static func copy_for_codex(report: ArenaValidationReport) -> void:
	if report != null:
		DisplayServer.clipboard_set(report.to_markdown())
