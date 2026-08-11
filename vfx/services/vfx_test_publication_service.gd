class_name VFXTestPublicationService
extends RefCounted

const TEST_ROOT := "res://test/fixtures/vfx/published"


func publish(
		profile: VFXProfile,
		target_path: String,
		expected_existing_fingerprint := ""
	) -> Dictionary:
	var normalized_root := TEST_ROOT.trim_suffix("/") + "/"
	if profile == null or not target_path.begins_with(normalized_root) or not target_path.ends_with(".tres"):
		return {"ok": false, "error": "Publication refusée hors fixture TEST."}
	var validation := VFXProfileValidator.validate(profile)
	if not bool(validation.ok):
		return {"ok": false, "error": "Publication refusée : profil invalide.", "validation": validation}
	if FileAccess.file_exists(target_path):
		var existing := ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_IGNORE) as VFXProfile
		var existing_fingerprint := VFXProfileSnapshotService.fingerprint(existing)
		if expected_existing_fingerprint.is_empty() or existing_fingerprint != expected_existing_fingerprint:
			return {"ok": false, "error": "Conflit de publication TEST.", "conflict": true}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_path.get_base_dir()))
	var stamp := Time.get_ticks_usec()
	var temp_path := "%s.tmp_%d.tres" % [target_path.get_basename(), stamp]
	var backup_path := "%s.backup_%d.tres" % [target_path.get_basename(), stamp]
	var save_error := ResourceSaver.save(profile, temp_path)
	if save_error != OK:
		return {"ok": false, "error": "Écriture temporaire impossible : %s" % error_string(save_error)}
	var reloaded := ResourceLoader.load(temp_path, "", ResourceLoader.CACHE_MODE_IGNORE) as VFXProfile
	if reloaded == null or VFXProfileSnapshotService.fingerprint(reloaded) != VFXProfileSnapshotService.fingerprint(profile):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return {"ok": false, "error": "Vérification transactionnelle échouée."}
	var had_target := FileAccess.file_exists(target_path)
	if had_target:
		var backup_error := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(target_path), ProjectSettings.globalize_path(backup_path)
		)
		if backup_error != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
			return {"ok": false, "error": "Backup TEST impossible."}
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(target_path)
	)
	if rename_error != OK:
		if had_target:
			DirAccess.rename_absolute(
				ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(target_path)
			)
		return {"ok": false, "error": "Publication transactionnelle impossible."}
	if had_target and FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
	return {
		"ok": true, "path": target_path,
		"fingerprint": VFXProfileSnapshotService.fingerprint(profile),
	}
