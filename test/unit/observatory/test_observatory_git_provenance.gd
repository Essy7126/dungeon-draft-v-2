extends GutTest

const Exporter := preload("res://tools/observatory/observatory_exporter.gd")
const CONTRACT_PATH := "res://docs/observatory/design_contract.json"
const MANIFEST_PATH := "res://docs/observatory/data_source_manifest.json"

var _repository_path := ""


func before_each() -> void:
	_repository_path = ProjectSettings.globalize_path(
		"user://observatory_git_provenance_%d" % Time.get_ticks_usec()
	)
	assert_eq(DirAccess.make_dir_recursive_absolute(_repository_path), OK)
	assert_eq(_git(["init", "-b", "main"]), 0)
	assert_eq(_git(["config", "user.email", "observatory@example.invalid"]), 0)
	assert_eq(_git(["config", "user.name", "Observatory Test"]), 0)
	_write("tracked.txt", "baseline\n")
	assert_eq(_git(["add", "tracked.txt"]), 0)
	assert_eq(_git(["commit", "-m", "baseline"]), 0)


func after_each() -> void:
	_remove_tree(_repository_path)


func test_clean_and_dirty_flags_come_from_the_selected_git_worktree() -> void:
	var exporter := _exporter()
	var clean := exporter.read_git_provenance()
	assert_true(clean.get("source_git_available", false))
	assert_false(clean.get("source_worktree_dirty_before_export", true))
	assert_true(clean.get("source_generated_from_clean_checkout", false))
	assert_eq(clean.get("source_game_commit"), _git_output(["rev-parse", "HEAD"]))

	_write("untracked.txt", "dirty\n")
	var dirty := exporter.read_git_provenance()
	assert_true(dirty.get("source_worktree_dirty_before_export", false))
	assert_false(dirty.get("source_generated_from_clean_checkout", true))


func test_manifest_cannot_override_meta_source_game_commit() -> void:
	var manifest := JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH)) as Dictionary
	manifest["source_game_commit"] = "0000000000000000000000000000000000000000"
	_write("manifest.json", JSON.stringify(manifest, "  ") + "\n")
	assert_eq(_git(["add", "manifest.json"]), 0)
	assert_eq(_git(["commit", "-m", "manifest"]), 0)
	var expected_head := _git_output(["rev-parse", "HEAD"])
	var exporter := _exporter()
	var result := exporter.build_snapshot(
		_repository_path.path_join("manifest.json"),
		CONTRACT_PATH,
	)
	_handle_known_gameplay_uid_warning()
	assert_true((result.get("errors", []) as Array).is_empty())
	var meta := (result.get("snapshot", {}) as Dictionary).get("meta", {}) as Dictionary
	assert_eq(meta.get("source_game_commit"), expected_head)
	assert_ne(meta.get("source_game_commit"), manifest["source_game_commit"])
	assert_true((result.get("warnings", []) as Array).any(func(value: Variant) -> bool:
		return "obsolète" in str(value)
	))


func test_missing_git_is_unknown_only_in_documentary_mode() -> void:
	var exporter := Exporter.new()
	exporter.configure_git_for_tests("git", _repository_path.path_join("missing"))
	var documentary := exporter.read_git_provenance(true)
	assert_false(documentary.get("source_git_available", true))
	assert_eq(documentary.get("source_game_commit"), "unknown")
	var release := exporter.build_snapshot(MANIFEST_PATH, CONTRACT_PATH, false)
	assert_false((release.get("errors", []) as Array).is_empty())


func _exporter() -> ObservatoryExporter:
	var exporter := Exporter.new()
	exporter.configure_git_for_tests("git", _repository_path)
	return exporter


func _git(arguments: Array[String]) -> int:
	var output: Array = []
	var args := PackedStringArray(["--no-optional-locks", "-C", _repository_path])
	args.append_array(PackedStringArray(arguments))
	return OS.execute("git", args, output, true)


func _git_output(arguments: Array[String]) -> String:
	var output: Array = []
	var args := PackedStringArray(["--no-optional-locks", "-C", _repository_path])
	args.append_array(PackedStringArray(arguments))
	var code := OS.execute("git", args, output, true)
	assert_eq(code, 0)
	return str(output[0]).strip_edges() if not output.is_empty() else ""


func _write(relative_path: String, content: String) -> void:
	var file := FileAccess.open(_repository_path.path_join(relative_path), FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(content)
	file.close()


func _handle_known_gameplay_uid_warning() -> void:
	for error in get_errors():
		if error.contains_text("invalid UID: uid://0flkpto1jkby"):
			error.handled = true


func _remove_tree(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry not in [".", ".."]:
			var child := path.path_join(entry)
			if directory.current_is_dir():
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
