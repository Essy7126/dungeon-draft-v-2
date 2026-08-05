extends SceneTree

const DEFAULT_OUTPUT := "res://observatory/public/data/latest.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_path := DEFAULT_OUTPUT
	var fail_on_blocking := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument == "--fail-on-blocking":
			fail_on_blocking = true
	if not output_path.begins_with("res://"):
		push_error("La sortie Observatory doit utiliser un chemin res://.")
		quit(1)
		return

	var exporter := ObservatoryExporter.new()
	var result := exporter.build_snapshot()
	var errors := result.get("errors", []) as Array
	if not errors.is_empty():
		for error in errors:
			push_error(str(error))
		quit(1)
		return
	var snapshot := result.get("snapshot", {}) as Dictionary
	var validation := ObservatorySnapshotValidator.validate(snapshot)
	if not bool(validation.get("valid", false)):
		for error in validation.get("errors", []) as Array:
			push_error(str(error))
		quit(1)
		return
	if not _write_atomically(output_path, JSON.stringify(snapshot, "  ", false)):
		quit(1)
		return
	var blocking_count := int((snapshot.get("summary", {}) as Dictionary).get(
		"audit_blocking", 0
	))
	print("OBSERVATORY_EXPORT_OK %s" % output_path)
	print(JSON.stringify(snapshot.get("summary", {})))
	quit(2 if fail_on_blocking and blocking_count > 0 else 0)


func _write_atomically(output_path: String, content: String) -> bool:
	var absolute_output := ProjectSettings.globalize_path(output_path)
	var parent := absolute_output.get_base_dir()
	var make_error := DirAccess.make_dir_recursive_absolute(parent)
	if make_error != OK:
		push_error("Impossible de créer le dossier de sortie : %s." % error_string(make_error))
		return false
	var temporary := absolute_output + ".tmp"
	var backup := absolute_output + ".bak"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_error("Impossible d’écrire le fichier temporaire Observatory.")
		return false
	file.store_string(content + "\n")
	file.close()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(temporary))
	if not parsed is Dictionary:
		DirAccess.remove_absolute(temporary)
		push_error("Le fichier temporaire Observatory n’est pas un objet JSON valide.")
		return false
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	if FileAccess.file_exists(absolute_output):
		var backup_error := DirAccess.rename_absolute(absolute_output, backup)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary)
			push_error("Impossible de protéger le snapshot précédent.")
			return false
	var replace_error := DirAccess.rename_absolute(temporary, absolute_output)
	if replace_error != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, absolute_output)
		push_error("Impossible de remplacer le snapshot : %s." % error_string(replace_error))
		return false
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	return true
