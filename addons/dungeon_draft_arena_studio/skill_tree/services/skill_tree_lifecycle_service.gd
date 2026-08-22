@tool
class_name SkillTreeLifecycleService
extends RefCounted

const ARCHIVE_ROOT := "user://dungeon_draft_studio/skill_tree/archives"


static func detach_current(session: SkillTreeEditSession) -> Dictionary:
	if session == null or session.current_discipline() == null:
		return {"ok": false, "operation": "DETACH_REFERENCE", "error": "Aucune discipline sélectionnée."}
	var discipline := session.current_discipline()
	var path := discipline.resource_path
	var changed := session.detach_current_discipline()
	return {
		"ok": changed,
		"operation": "DETACH_REFERENCE",
		"resource": discipline,
		"path": path,
		"file_preserved": true,
	}


static func adopt_discipline(
		session: SkillTreeEditSession,
		source: DisciplineData
	) -> Dictionary:
	if session == null or session.working_unit == null or source == null:
		return {"ok": false, "operation": "ADOPT", "error": "Session ou discipline absente."}
	if source.discipline_id == &"":
		return {"ok": false, "operation": "ADOPT", "error": "Identifiant de discipline absent."}
	for discipline in session.working_unit.disciplines:
		if discipline != null and discipline.discipline_id == source.discipline_id:
			return {"ok": false, "operation": "ADOPT", "error": "Identifiant déjà rattaché."}
	var copied := SkillTreeCopyService.copy_discipline(source)
	var work := copied.get("work") as DisciplineData
	if work == null:
		return {"ok": false, "operation": "ADOPT", "error": "Version en cours impossible à créer."}
	var disciplines: Array[DisciplineData] = session.working_unit.disciplines.duplicate()
	disciplines.append(work)
	if not session.change_property(
			session.working_unit, &"disciplines", disciplines,
			"Adopter la discipline %s" % source.display_name
		):
		return {"ok": false, "operation": "ADOPT", "error": "Adoption non appliquée."}
	for source_value in copied.get("source_to_work", {}):
		var source_resource := source_value as Resource
		var work_resource := copied.source_to_work[source_value] as Resource
		session.source_to_work[source_resource] = work_resource
		session.work_to_source[work_resource] = source_resource
	session.select_discipline(work.discipline_id)
	return {
		"ok": true,
		"operation": "ADOPT",
		"resource": work,
		"source": source,
		"consequences": {
			"discipline_count_delta": 1,
			"source_path": source.resource_path,
		},
	}


static func archive_resource(
		resource: Resource,
		index: SkillTreeReferenceIndex,
		options: Dictionary = {}
	) -> Dictionary:
	return _archive_then_optionally_remove(resource, index, options, false)


static func delete_permanently(
		resource: Resource,
		index: SkillTreeReferenceIndex,
		confirmation_token: String,
		options: Dictionary = {}
	) -> Dictionary:
	var expected := _confirmation_token(resource)
	if confirmation_token != expected:
		return {
			"ok": false,
			"operation": "DELETE",
			"error": "Confirmation renforcée incorrecte.",
			"expected_token": expected,
		}
	return _archive_then_optionally_remove(resource, index, options, true)


static func _archive_then_optionally_remove(
		resource: Resource,
		index: SkillTreeReferenceIndex,
		options: Dictionary,
		permanent: bool
	) -> Dictionary:
	var operation := "DELETE" if permanent else "ARCHIVE"
	if resource == null or resource.resource_path.is_empty():
		return {"ok": false, "operation": operation, "error": "Resource externe absente."}
	if index != null:
		var deletion := index.can_delete(resource)
		if not deletion.get("allowed", false):
			return {
				"ok": false,
				"operation": operation,
				"error": "La Resource possède encore des références entrantes.",
				"incoming_references": deletion.get("incoming_references", []),
			}
	var source_path := resource.resource_path
	var roots := options.get("allowed_roots", PackedStringArray(["res://data/"]))
	if not _safe_source(source_path, roots):
		return {"ok": false, "operation": operation, "error": "Chemin source non autorisé."}
	var stamp := "%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var archive_dir := ARCHIVE_ROOT.path_join("archive_" + stamp)
	if DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(archive_dir)
		) != OK:
		return {"ok": false, "operation": operation, "error": "Dossier d'archive impossible."}
	var archived_path := archive_dir.path_join(source_path.get_file())
	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(archived_path)
	)
	if copy_error != OK or not FileAccess.file_exists(archived_path):
		return {"ok": false, "operation": operation, "error": "Copie d'archive impossible.", "code": copy_error}
	var manifest := {
		"schema_version": 1,
		"operation": operation,
		"source_path": source_path,
		"archived_path": archived_path,
		"fingerprint": SkillTreeSnapshotService.storage_fingerprint(resource),
		"created_at": Time.get_datetime_string_from_system(),
		"incoming_reference_count": 0,
	}
	if not _write_json(archive_dir.path_join("manifest.json"), manifest):
		return {"ok": false, "operation": operation, "error": "Manifeste d'archive impossible."}
	# Archiver et supprimer définitivement retirent tous deux le fichier du
	# projet ; la différence reste la confirmation et la présentation avancée.
	var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(source_path))
	if remove_error != OK:
		return {"ok": false, "operation": operation, "error": "Retrait du projet impossible.", "code": remove_error, "archive_path": archive_dir}
	return {
		"ok": true,
		"operation": operation,
		"source_path": source_path,
		"archive_path": archive_dir,
		"archived_resource_path": archived_path,
		"recoverable": true,
		"removed_from_project": true,
	}


static func _confirmation_token(resource: Resource) -> String:
	if resource is DisciplineData:
		return str(resource.discipline_id)
	if resource is SkillUpgradeData:
		return str(resource.upgrade_id)
	if resource is Spell:
		return str(resource.get_effective_spell_id())
	return resource.resource_path.get_file()


static func _safe_source(path: String, roots: Variant) -> bool:
	var normalized := PackedStringArray()
	if roots is PackedStringArray:
		normalized = roots
	elif roots is Array:
		for value in roots:
			normalized.append(str(value))
	return int(SkillTreePathReservationService.new(normalized).inspect(path).get(
		"status", SkillTreePathReservationService.Status.UNSAFE_PATH
	)) != SkillTreePathReservationService.Status.UNSAFE_PATH


static func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  "))
	file.flush()
	return file.get_error() == OK
