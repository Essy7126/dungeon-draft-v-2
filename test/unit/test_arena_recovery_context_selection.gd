extends GutTest

const ROOT_A := "user://dungeon_draft_studio/tests/recovery_context/root_a"
const ROOT_B := "user://dungeon_draft_studio/tests/recovery_context/root_b"


func after_each() -> void:
	ArenaProductionTransactionService._remove_tree(
		"user://dungeon_draft_studio/tests/recovery_context"
	)


func test_multiple_roots_prioritize_active_arena_run_and_room_before_mtime() -> void:
	_write(ROOT_A.path_join("active_old.json"), "forest", 10, {
		"run_path": "res://data/runs/main.tres",
		"room_path": "res://data/rooms/forest.tres",
		"room_index": 0,
	})
	_write(ROOT_B.path_join("same_arena_new_wrong_room.json"), "forest", 40, {
		"run_path": "res://data/runs/main.tres",
		"room_path": "res://data/rooms/lava.tres",
		"room_index": 1,
	})
	_write(ROOT_B.path_join("foreign_newest.json"), "volcano", 90, {})
	var result := ArenaRecoveryContextSelectionService.scan(_context(), [
		ROOT_A, ROOT_B,
	])
	assert_true(result.ok, str(result))
	assert_eq(result.selected.arena_id, "forest")
	assert_eq(result.selected.room_path, "res://data/rooms/forest.tres")
	assert_true(result.requires_confirmation)


func test_newest_recovery_wins_only_after_context_matches() -> void:
	_write(ROOT_A.path_join("older.json"), "forest", 10, _context())
	_write(ROOT_B.path_join("newer.json"), "forest", 20, _context())
	var result := ArenaRecoveryContextSelectionService.scan(_context(), [
		ROOT_A, ROOT_B,
	])
	assert_true(result.ok)
	assert_true(str(result.selected.path).ends_with("newer.json"))


func test_legacy_recovery_is_visible_and_explicitly_classified() -> void:
	_write(ROOT_A.path_join("legacy.json"), "forest", 10, {}, 1)
	var candidate := ArenaRecoveryContextSelectionService.inspect(
		ROOT_A.path_join("legacy.json")
	)
	assert_true(candidate.compatible)
	assert_eq(candidate.compatibility, &"LEGACY")
	assert_true(ArenaRecoveryContextSelectionService.describe(candidate).contains(
		"Compatibilité de schéma : LEGACY"
	))


func test_future_schema_is_incompatible_and_never_selected() -> void:
	_write(
		ROOT_A.path_join("future.json"), "forest", 10, {},
		ArenaDefinition.CURRENT_SCHEMA_VERSION + 1
	)
	var result := ArenaRecoveryContextSelectionService.scan(_context(), [ROOT_A])
	assert_false(result.ok)
	assert_eq(result.error, "contextual_recovery_missing")


func test_foreign_arena_is_never_restored_implicitly() -> void:
	_write(ROOT_A.path_join("foreign.json"), "volcano", 100, {})
	var result := ArenaRecoveryContextSelectionService.scan(_context(), [ROOT_A])
	assert_false(result.ok)
	assert_eq((result.foreign_candidates as Array).size(), 1)


func test_record_exposes_required_provenance_fields() -> void:
	_write(ROOT_A.path_join("active.json"), "forest", 10, _context())
	var result := ArenaRecoveryContextSelectionService.scan(_context(), [ROOT_A])
	var selected := result.selected as Dictionary
	for key in [
		"source", "arena_id", "run_path", "room_path", "room_index", "date",
		"age_seconds", "files", "transaction", "status", "compatibility",
	]:
		assert_has(selected, key)


func _context() -> Dictionary:
	return {
		"domain": &"arena",
		"arena_id": "forest",
		"run_path": "res://data/runs/main.tres",
		"room_path": "res://data/rooms/forest.tres",
		"room_index": 0,
	}


func _write(
	path: String,
	arena_id: String,
	saved_at: int,
	metadata: Dictionary,
	schema_version: int = ArenaDefinition.CURRENT_SCHEMA_VERSION
	) -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path.get_base_dir())
	), OK)
	var context := metadata.duplicate(true)
	context["domain"] = &"arena"
	context["arena_id"] = arena_id
	context["source"] = path
	context["transaction"] = "fixture"
	context["status"] = "RECOVERABLE"
	var payload := {
		"schema_version": schema_version,
		"arena_id": arena_id,
		"_recovery_saved_at_unix": saved_at,
		"_recovery_context": context,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(JSON.stringify(payload))
	file.close()
