class_name VFXDraftService
extends RefCounted

const DRAFT_DIRECTORY := "user://dungeon_draft_studio/vfx_drafts"


func save_draft(document: VFXStudioDocument) -> Dictionary:
	if document == null or document.working_copy == null:
		return {"ok": false, "error": "Aucun profil VFX ouvert."}
	var validation := VFXProfileValidator.validate(document.working_copy)
	if not bool(validation.ok):
		return {"ok": false, "error": "Draft invalide.", "validation": validation}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DRAFT_DIRECTORY))
	var path := DRAFT_DIRECTORY.path_join("%s.json" % document.working_copy.profile_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Impossible d’écrire le draft."}
	file.store_string(JSON.stringify(VFXProfileSnapshotService.to_dictionary(document.working_copy), "  "))
	file.close()
	document.mark_draft_saved()
	return {"ok": true, "path": path, "fingerprint": document.current_fingerprint()}


func load_draft(profile_id: StringName) -> Dictionary:
	var path := DRAFT_DIRECTORY.path_join("%s.json" % profile_id)
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Draft introuvable : %s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Draft illisible."}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"ok": false, "error": "Draft JSON invalide."}
	var profile := VFXProfileSnapshotService.from_dictionary(parsed)
	var validation := VFXProfileValidator.validate(profile)
	return {
		"ok": bool(validation.ok), "profile": profile, "path": path,
		"validation": validation,
	}
