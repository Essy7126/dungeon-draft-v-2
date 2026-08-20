class_name AchillesTheorycraftStore
extends RefCounted

const DRAFT_ROOT := "user://theorycraft/achilles"
const EXPORT_ROOT := "user://theorycraft/achilles/exports"
const MISSION_ARTIFACT_DIRECTORY := "ACHILLES_3D_CHARACTER_THEORYCRAFT_V1_20260820_181248"
const DURABLE_INTEGRATION_ROOT := (
	"C:/Dungeon_Draft_Production/Achilles/Integration/"
	+ MISSION_ARTIFACT_DIRECTORY
)
const FORBIDDEN_OUTPUT_FRAGMENTS := [
	"/dungeon_draft_production/achilles/canonical/",
	"/dungeon-draft-v-2-worktrees/achilles-3d-sword-odyssey-v1-20260820_133257/",
]

var _artifact_root := ""


func save_draft(build: AchillesTheorycraftBuild) -> Dictionary:
	if build == null or build.status != AchillesTheorycraftBuild.STATUS_DRAFT:
		return {"ok": false, "error": "ONLY_DRAFT_STATUS_CAN_BE_SAVED"}
	var safe := AchillesTheorycraftJson.safe_id(build.build_id)
	if safe.is_empty():
		return {"ok": false, "error": "INVALID_BUILD_ID"}
	build.mark_owner_editable_fields_as_draft()
	var errors := build.validation_errors()
	if not errors.is_empty():
		return {"ok": false, "error": "INVALID_DRAFT", "details": Array(errors)}
	var path := DRAFT_ROOT.path_join("%s.json" % safe)
	if not _ensure_directory(DRAFT_ROOT):
		return {"ok": false, "error": "DRAFT_DIRECTORY_FAILED"}
	if not _write(path, AchillesTheorycraftJson.stringify(build.to_dict())):
		return {"ok": false, "error": "DRAFT_WRITE_FAILED"}
	return {"ok": true, "path": path}


func load_draft(build_id: String) -> AchillesTheorycraftBuild:
	var safe := AchillesTheorycraftJson.safe_id(build_id)
	if safe.is_empty():
		return null
	var path := DRAFT_ROOT.path_join("%s.json" % safe)
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return null
	var build := AchillesTheorycraftBuild.from_dict(parsed)
	return build if build.status == AchillesTheorycraftBuild.STATUS_DRAFT else null


func export_review(
		report: TheorycraftComparisonReport,
		builds: Array[AchillesTheorycraftBuild],
		root := EXPORT_ROOT
	) -> Dictionary:
	if report == null:
		return {"ok": false, "error": "REPORT_REQUIRED"}
	if not _is_allowed_export_root(root):
		return {"ok": false, "error": "EXPORT_DESTINATION_FORBIDDEN"}
	if not _ensure_directory(root):
		return {"ok": false, "error": "EXPORT_DIRECTORY_FAILED"}
	var selected: Array[AchillesTheorycraftBuild] = builds.slice(0, 3)
	var payloads := {
		"comparison.json": report.to_dict(),
		"comparison.md": _comparison_markdown(report),
	}
	var names := ["build_a.json", "build_b.json", "build_c.json"]
	for index in range(3):
		payloads[names[index]] = (
			selected[index].to_dict()
			if index < selected.size()
			else {"status": "EMPTY_COMPARISON_SLOT", "slot": index}
		)
	var paths := {}
	for file_name in payloads.keys():
		var path := root.path_join(file_name)
		var content: String = payloads[file_name] if payloads[file_name] is String \
			else AchillesTheorycraftJson.stringify(payloads[file_name])
		if not _write(path, content):
			return {"ok": false, "error": "EXPORT_WRITE_FAILED", "path": path}
		paths[file_name] = path
	return {
		"ok": true,
		"paths": AchillesTheorycraftJson.canonicalize(paths),
		"comparison_sha": AchillesTheorycraftJson.fingerprint(report.to_dict()),
	}


func configure_artifact_root(root: String) -> bool:
	var normalized := _normalized_absolute(root)
	if normalized.is_empty() or not _is_mission_artifact_root(normalized):
		return false
	if _is_forbidden_absolute(normalized):
		return false
	_artifact_root = normalized.trim_suffix("/")
	return true


func _comparison_markdown(report: TheorycraftComparisonReport) -> String:
	var data := report.to_dict()
	var lines := PackedStringArray([
		"# Achilles Theorycraft Comparison",
		"",
		"This report is an isolated design aid. It does not activate a runtime build.",
		"",
		"## Builds",
		"",
	])
	for build in data.builds:
		lines.append("- `%s` - `%s` - runtime loadable: `%s`" % [
			build.get("build_id", ""),
			build.get("status", ""),
			build.get("runtime_loadable", false),
		])
	lines.append_array(PackedStringArray(["", "## Six AP sequences", ""]))
	var ids: Array = data.ap_sequences.keys()
	ids.sort()
	for build_id in ids:
		var analysis: Dictionary = data.ap_sequences[build_id]
		lines.append("- `%s`: %s abstract sequences; unused AP %s" % [
			build_id,
			analysis.get("sequence_count", "NOT_MEASURED"),
			analysis.get("unused_ap_histogram", {}),
		])
	lines.append_array(PackedStringArray(["", "## Warnings", ""]))
	if data.warnings.is_empty():
		lines.append("- No bounded warning triggered with the measured inputs.")
	else:
		for warning in data.warnings:
			lines.append("- `%s`: %s" % [warning.code, warning.message])
	lines.append_array(PackedStringArray([
		"",
		"## Not measured",
		"",
	]))
	for entry in data.not_measured:
		lines.append("- `%s / %s`: %s" % [
			entry.get("build_id", ""), entry.get("axis", ""), entry.get("reason", "")
		])
	lines.append("")
	return "\n".join(lines)


func _is_allowed_export_root(path: String) -> bool:
	if path == EXPORT_ROOT or path.begins_with(EXPORT_ROOT + "/"):
		return true
	if path.begins_with("res://") or path.begins_with("user://"):
		return false
	var absolute := _normalized_absolute(path)
	if absolute.is_empty() or _is_forbidden_absolute(absolute) or _artifact_root.is_empty():
		return false
	return absolute == _artifact_root or absolute.begins_with(_artifact_root + "/")


func _normalized_absolute(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ""
	var normalized := path.replace("\\", "/").simplify_path()
	return normalized if normalized.is_absolute_path() else ""


func _is_forbidden_absolute(path: String) -> bool:
	var lowered := (path.trim_suffix("/") + "/").to_lower()
	for fragment in FORBIDDEN_OUTPUT_FRAGMENTS:
		if lowered.contains(fragment):
			return true
	return false


func _is_mission_artifact_root(path: String) -> bool:
	var normalized := _normalized_absolute(path)
	if normalized.is_empty():
		return false
	var local_root_path := ProjectSettings.globalize_path("res://")
	local_root_path = local_root_path.path_join("artifacts")
	local_root_path = local_root_path.path_join(MISSION_ARTIFACT_DIRECTORY)
	var local_root := _normalized_absolute(local_root_path)
	var durable_root := _normalized_absolute(DURABLE_INTEGRATION_ROOT)
	return normalized.to_lower() in [local_root.to_lower(), durable_root.to_lower()]


func _ensure_directory(path: String) -> bool:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)) == OK


func _write(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.close()
	return true
