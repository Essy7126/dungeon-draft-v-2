@tool
class_name RunContentMigrationService
extends RefCounted

const MAIN_RUN_PATH := "res://data/runs/first_run.tres"
const TEST_RUN_PATH := "res://data/runs/fixed_trio_prototype_run.tres"
const MAIN_CONTENT_PATH := "res://data/runs/profiles/main_content_profile.tres"
const TEST_CONTENT_PATH := "res://data/runs/profiles/test_content_profile.tres"
const MANIFEST_PATH := "res://data/runs/profiles/run_content_isolation_manifest.json"
const CHARACTER_IDS: Array[StringName] = [&"elf", &"mage", &"warrior"]
const BASE_UNIT_PATHS := [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]


static func migrate_official_runs() -> Dictionary:
	var report := {
		"ok": false,
		"staging_root": "user://run_content_isolation_staging_%d" % Time.get_ticks_msec(),
		"backup_root": "user://run_content_isolation_backup_%d" % Time.get_ticks_msec(),
		"created_paths": PackedStringArray(),
		"restored_paths": PackedStringArray(),
		"fingerprints": {},
		"errors": PackedStringArray(),
		"audit": {},
	}
	var bases: Array[UnitData] = []
	for index in range(BASE_UNIT_PATHS.size()):
		var base := load(BASE_UNIT_PATHS[index]) as UnitData
		if base == null:
			report.errors.append("UnitData introuvable : %s" % BASE_UNIT_PATHS[index])
			continue
		if base.get_effective_unit_id() != CHARACTER_IDS[index]:
			report.errors.append(
				"Identite inattendue pour %s : %s." % [BASE_UNIT_PATHS[index], base.get_effective_unit_id()]
			)
		bases.append(base)
	if not report.errors.is_empty():
		return report

	var staging_profiles := _build_and_stage_profiles(bases, report)
	if not report.errors.is_empty():
		return report
	var staged_main: Array[CharacterProgressionProfile] = staging_profiles["main"]
	var staged_test: Array[CharacterProgressionProfile] = staging_profiles["test"]
	var staged_main_content := _build_content(
		&"main", "Contenu principal", bases, staged_main,
		"Progressions historiques de production."
	)
	var staged_test_content := _build_content(
		&"test", "Contenu test", bases, staged_test,
		"Copies de progression independantes dediees a la run de test."
	)
	if not _save_reload_content_checked(
			staged_main_content,
			report.staging_root.path_join("profiles/main_content_profile.tres"),
			report
		) or not _save_reload_content_checked(
			staged_test_content,
			report.staging_root.path_join("profiles/test_content_profile.tres"),
			report
		):
		return report
	var staged_first := RunData.new()
	staged_first.content_profile = staged_main_content
	var staged_second := RunData.new()
	staged_second.content_profile = staged_test_content
	var staged_audit := RunContentIsolationAuditService.compare_runs(staged_first, staged_second)
	if int(staged_audit.get("progression_shared_count", -1)) != 0:
		report.errors.append("Le staging partage encore des ressources de progression interdites.")
		return report

	var target_paths := PackedStringArray([MAIN_RUN_PATH, TEST_RUN_PATH, MAIN_CONTENT_PATH, TEST_CONTENT_PATH, MANIFEST_PATH])
	for character_id in CHARACTER_IDS:
		target_paths.append(_progression_path(&"main", character_id))
		target_paths.append(_progression_path(&"test", character_id))
	var backup_state := _backup_targets(target_paths, report)
	if not report.errors.is_empty():
		return report
	var new_paths: PackedStringArray = backup_state.get("new_paths", PackedStringArray())
	report.created_paths = new_paths.duplicate()

	# Reconstruction fraiche apres le staging : aucun chemin user:// ne peut
	# ainsi etre conserve dans les fichiers de production.
	var production_profiles := _build_production_profiles(bases, report)
	if not report.errors.is_empty():
		_rollback(backup_state, report)
		return report
	var main_profiles: Array[CharacterProgressionProfile] = production_profiles["main"]
	var test_profiles: Array[CharacterProgressionProfile] = production_profiles["test"]
	var main_content := _build_content(
		&"main", "Contenu principal", bases, main_profiles,
		"Progressions historiques de production."
	)
	var test_content := _build_content(
		&"test", "Contenu test", bases, test_profiles,
		"Copies de progression independantes dediees a la run de test."
	)
	if not _save_reload_content_checked(main_content, MAIN_CONTENT_PATH, report) \
			or not _save_reload_content_checked(test_content, TEST_CONTENT_PATH, report):
		_rollback(backup_state, report)
		return report
	main_content = ResourceLoader.load(
		MAIN_CONTENT_PATH, "RunContentProfile", ResourceLoader.CACHE_MODE_REPLACE
	) as RunContentProfile
	test_content = ResourceLoader.load(
		TEST_CONTENT_PATH, "RunContentProfile", ResourceLoader.CACHE_MODE_REPLACE
	) as RunContentProfile
	if main_content == null or test_content == null:
		report.errors.append("Les profils de contenu de production ne se rechargent pas.")
		_rollback(backup_state, report)
		return report

	var main_run := ResourceLoader.load(
		MAIN_RUN_PATH, "RunData", ResourceLoader.CACHE_MODE_REPLACE
	) as RunData
	var test_run := ResourceLoader.load(
		TEST_RUN_PATH, "RunData", ResourceLoader.CACHE_MODE_REPLACE
	) as RunData
	if main_run == null or test_run == null:
		report.errors.append("Une run officielle ne peut pas etre rechargee.")
		_rollback(backup_state, report)
		return report
	main_run.content_profile = main_content
	test_run.content_profile = test_content
	if ResourceSaver.save(main_run, MAIN_RUN_PATH) != OK \
			or ResourceSaver.save(test_run, TEST_RUN_PATH) != OK:
		report.errors.append("Echec de sauvegarde des RunData officielles.")
		_rollback(backup_state, report)
		return report

	main_run = ResourceLoader.load(MAIN_RUN_PATH, "RunData", ResourceLoader.CACHE_MODE_REPLACE) as RunData
	test_run = ResourceLoader.load(TEST_RUN_PATH, "RunData", ResourceLoader.CACHE_MODE_REPLACE) as RunData
	if main_run == null or test_run == null \
			or main_run.content_profile == null or test_run.content_profile == null:
		report.errors.append("Le rechargement final des RunData a echoue.")
		_rollback(backup_state, report)
		return report
	report.audit = RunContentIsolationAuditService.compare_runs(main_run, test_run)
	if report.audit.get("verdict", "INVALID") != "VALID" \
			or int(report.audit.get("progression_shared_count", -1)) != 0:
		report.errors.append("L'audit final d'isolation a echoue.")
		_rollback(backup_state, report)
		return report
	if not _write_manifest(main_run, test_run, report):
		_rollback(backup_state, report)
		return report
	report.ok = true
	return report


static func _build_and_stage_profiles(bases: Array[UnitData], report: Dictionary) -> Dictionary:
	var main_profiles: Array[CharacterProgressionProfile] = []
	var test_profiles: Array[CharacterProgressionProfile] = []
	for index in range(bases.size()):
		var character_id := CHARACTER_IDS[index]
		var main_profile := _profile_from_base(bases[index])
		var main_stage_path: String = str(report["staging_root"]).path_join(
			"progression/main/%s_progression_profile.tres" % character_id
		)
		var staged_main := _save_reload_profile_checked(main_profile, main_stage_path, report)
		if staged_main == null:
			return {"main": main_profiles, "test": test_profiles}
		main_profiles.append(staged_main)
		var clone_result := RunProgressionCloneService.clone_profile(
			main_profile, &"test", str(report["staging_root"]).path_join("progression/test")
		)
		if not clone_result.is_valid():
			report.errors.append_array(clone_result.errors)
			return {"main": main_profiles, "test": test_profiles}
		var test_stage_path: String = str(report["staging_root"]).path_join(
			"progression/test/%s_progression_profile.tres" % character_id
		)
		var save_report := RunProgressionCloneService.save_reload_and_compare(clone_result, test_stage_path)
		if not save_report.get("ok", false):
			report.errors.append_array(save_report.get("errors", PackedStringArray()))
			return {"main": main_profiles, "test": test_profiles}
		test_profiles.append(save_report.get("reloaded") as CharacterProgressionProfile)
		report.fingerprints["staged_main/%s" % character_id] = (
			RunProgressionCloneService.semantic_fingerprint(staged_main)
		)
		report.fingerprints["staged_test/%s" % character_id] = save_report.after_fingerprint
	return {"main": main_profiles, "test": test_profiles}


static func _build_production_profiles(bases: Array[UnitData], report: Dictionary) -> Dictionary:
	var main_profiles: Array[CharacterProgressionProfile] = []
	var test_profiles: Array[CharacterProgressionProfile] = []
	for index in range(bases.size()):
		var character_id := CHARACTER_IDS[index]
		var main_profile := _profile_from_base(bases[index])
		var saved_main := _save_reload_profile_checked(
			main_profile, _progression_path(&"main", character_id), report
		)
		if saved_main == null:
			return {"main": main_profiles, "test": test_profiles}
		main_profiles.append(saved_main)
		var clone_result := RunProgressionCloneService.clone_profile(
			main_profile, &"test", _progression_path(&"test", character_id)
		)
		if not clone_result.is_valid():
			report.errors.append_array(clone_result.errors)
			return {"main": main_profiles, "test": test_profiles}
		var save_report := RunProgressionCloneService.save_reload_and_compare(
			clone_result, _progression_path(&"test", character_id)
		)
		if not save_report.get("ok", false):
			report.errors.append_array(save_report.get("errors", PackedStringArray()))
			return {"main": main_profiles, "test": test_profiles}
		var saved_test := save_report.get("reloaded") as CharacterProgressionProfile
		test_profiles.append(saved_test)
		report.fingerprints["main/%s" % character_id] = (
			RunProgressionCloneService.semantic_fingerprint(saved_main)
		)
		report.fingerprints["test/%s" % character_id] = (
			RunProgressionCloneService.semantic_fingerprint(saved_test)
		)
	return {"main": main_profiles, "test": test_profiles}


static func _profile_from_base(base: UnitData) -> CharacterProgressionProfile:
	var profile := CharacterProgressionProfile.new()
	profile.character_id = base.get_effective_unit_id()
	profile.active_spell_slots = base.active_spell_slots
	profile.spells.assign(base.spells)
	profile.disciplines.assign(base.disciplines)
	return profile


static func _build_content(
		profile_id: StringName,
		display_name: String,
		bases: Array[UnitData],
		progressions: Array[CharacterProgressionProfile],
		description: String
	) -> RunContentProfile:
	var content := RunContentProfile.new()
	content.profile_id = profile_id
	content.display_name = display_name
	content.description = description
	for index in range(bases.size()):
		var hero := RunHeroProfile.new()
		hero.character_id = CHARACTER_IDS[index]
		hero.base_unit_data = bases[index]
		hero.progression_profile = progressions[index]
		content.hero_profiles.append(hero)
	return content


static func _save_reload_profile_checked(
		profile: CharacterProgressionProfile,
		path: String,
		report: Dictionary
	) -> CharacterProgressionProfile:
	var before := RunProgressionCloneService.semantic_fingerprint(profile)
	if not _ensure_parent(path, report):
		return null
	var error := ResourceSaver.save(profile, path)
	if error != OK:
		report.errors.append("Echec de sauvegarde %s (erreur %d)." % [path, error])
		return null
	var reloaded := ResourceLoader.load(
		path, "CharacterProgressionProfile", ResourceLoader.CACHE_MODE_REPLACE
	) as CharacterProgressionProfile
	if reloaded == null or RunProgressionCloneService.semantic_fingerprint(reloaded) != before:
		report.errors.append("Le profil %s differe apres rechargement." % path)
		return null
	return reloaded


static func _save_reload_content_checked(
		content: RunContentProfile,
		path: String,
		report: Dictionary
	) -> bool:
	if not content.validation_errors().is_empty():
		report.errors.append_array(content.validation_errors())
		return false
	if not _ensure_parent(path, report):
		return false
	var error := ResourceSaver.save(content, path)
	if error != OK:
		report.errors.append("Echec de sauvegarde %s (erreur %d)." % [path, error])
		return false
	var reloaded := ResourceLoader.load(
		path, "RunContentProfile", ResourceLoader.CACHE_MODE_REPLACE
	) as RunContentProfile
	if reloaded == null or not reloaded.validation_errors().is_empty():
		report.errors.append("Le profil de contenu %s ne se recharge pas." % path)
		return false
	return true


static func _backup_targets(paths: PackedStringArray, report: Dictionary) -> Dictionary:
	var state := {"backup_root": report.backup_root, "backups": {}, "new_paths": PackedStringArray()}
	var backup_root_absolute := ProjectSettings.globalize_path(report.backup_root)
	if DirAccess.make_dir_recursive_absolute(backup_root_absolute) != OK:
		report.errors.append("Impossible de creer le dossier de backup.")
		return state
	for index in range(paths.size()):
		var path := paths[index]
		var absolute := ProjectSettings.globalize_path(path)
		if not FileAccess.file_exists(absolute):
			state.new_paths.append(path)
			continue
		var backup: String = str(report["backup_root"]).path_join(
			"%03d_%s" % [index, path.get_file()]
		)
		var copy_error := DirAccess.copy_absolute(absolute, ProjectSettings.globalize_path(backup))
		if copy_error != OK:
			report.errors.append("Echec du backup de %s (erreur %d)." % [path, copy_error])
			return state
		state.backups[path] = backup
	return state


static func _rollback(state: Dictionary, report: Dictionary) -> void:
	for path in state.get("new_paths", PackedStringArray()):
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
	for path in state.get("backups", {}):
		var backup: String = str(state["backups"][path])
		if DirAccess.copy_absolute(
				ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(path)
			) == OK:
			report.restored_paths.append(path)


static func _write_manifest(main_run: RunData, test_run: RunData, report: Dictionary) -> bool:
	if not _ensure_parent(MANIFEST_PATH, report):
		return false
	var manifest := {
		"schema_version": 1,
		"main": RunContentIsolationAuditService.deterministic_manifest(main_run),
		"test": RunContentIsolationAuditService.deterministic_manifest(test_run),
		"comparison": report.audit,
	}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		report.errors.append("Impossible d'ecrire le manifeste d'isolation.")
		return false
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	return true


static func _ensure_parent(path: String, report: Dictionary) -> bool:
	var error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path.get_base_dir())
	)
	if error != OK:
		report.errors.append("Impossible de creer %s (erreur %d)." % [path.get_base_dir(), error])
		return false
	return true


static func _progression_path(run_id: StringName, character_id: StringName) -> String:
	return "res://data/runs/progression/%s/%s_progression_profile.tres" % [run_id, character_id]
