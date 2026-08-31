@tool
class_name ArenaTerrainTypeSaveTransactionService
extends RefCounted

## Sauvegarde transactionnelle d'un type de tuile partage et de son effet.
##
## La transaction n'ecrit jamais directement une copie de travail dans le
## catalogue. Les deux Resources sont d'abord serialisees et relues dans des
## fichiers temporaires, puis les fichiers existants sont sauvegardes avant le
## remplacement. Toute erreur restaure les octets d'origine.

const TRANSACTION_ROOT := (
	"user://dungeon_draft_studio/terrain_type_save_transactions"
)
const WORKING_RECOVERY_ROOT := (
	"user://dungeon_draft_studio/terrain_type_working_recovery"
)
const TERRAIN_CATALOG_ROOT := (
	"res://addons/dungeon_draft_arena_studio/catalog/terrains"
)
const TERRAIN_EFFECT_ROOT := "res://data/terrain"
const DEFAULT_ALLOWED_ROOTS := [
	TERRAIN_CATALOG_ROOT,
	TERRAIN_EFFECT_ROOT,
]


static func recover_pending_transactions(options := {}) -> Dictionary:
	var transaction_root := str(options.get(
		"transaction_root", TRANSACTION_ROOT
	)).trim_suffix("/")
	if not _safe_user_directory(transaction_root):
		return {"ok": false, "error": "invalid_transaction_root", "failures": []}
	var absolute_root := ProjectSettings.globalize_path(transaction_root)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return {"ok": true, "recovered_count": 0, "failures": []}
	var directory_access := DirAccess.open(absolute_root)
	if directory_access == null:
		return {"ok": false, "error": "transaction_root_unreadable", "failures": []}
	var recovered_count := 0
	var failures: Array[Dictionary] = []
	for child_name in directory_access.get_directories():
		var directory := transaction_root.path_join(child_name)
		var latest := _latest_journal(directory)
		if not bool(latest.get("ok", false)):
			# Un dossier créé avant toute mutation ne nécessite aucune restauration.
			continue
		var journal := latest.get("data", {}) as Dictionary
		var status := str(journal.get("status", ""))
		if status in ["COMMITTED", "ROLLED_BACK", "EXTERNAL_CONFLICT", "BACKUP_FAILED"]:
			continue
		if status in ["ROLLBACK_CONFLICT", "ROLLBACK_FAILED"]:
			failures.append({
				"directory": directory,
				"status": status,
				"message": "Une transaction nécessite une récupération manuelle.",
			})
			continue
		if status not in ["PREPARED", "APPLYING", "STAGE_CLEANUP_FAILED"]:
			continue
		var restored := _recover_journal(journal, directory, options)
		if bool(restored.get("ok", false)):
			recovered_count += 1
		else:
			failures.append(restored)
	if recovered_count > 0:
		ArenaCatalogService.reset_cache()
	return {
		"ok": failures.is_empty(),
		"recovered_count": recovered_count,
		"failures": failures,
	}


static func capture_opening_state(
		source: ArenaTerrainDefinition,
		options := {}
	) -> Dictionary:
	var pending_recovery := recover_pending_transactions(options)
	if not bool(pending_recovery.get("ok", false)):
		return {
			"ok": false,
			"message": (
				"Une transaction interrompue doit être récupérée manuellement avant "
				+ "d'ouvrir ce type."
			),
			"recovery": pending_recovery,
		}
	var paths := _target_paths(source, options)
	if not bool(paths.get("ok", false)):
		return paths
	var terrain_path := str(paths.terrain_path)
	var effect_path := str(paths.effect_path)
	var files := {}
	files[terrain_path] = _file_state(terrain_path)
	files[effect_path] = _file_state(effect_path)
	var disk_terrain := ResourceLoader.load(
		terrain_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaTerrainDefinition
	if disk_terrain == null:
		return {
			"ok": false,
			"message": "Le fichier du type partage ne peut pas etre relu.",
		}
	var disk_effect: TerrainEffectData = null
	if bool((files[effect_path] as Dictionary).get("exists", false)):
		disk_effect = ResourceLoader.load(
			effect_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as TerrainEffectData
		if disk_effect == null:
			return {
				"ok": false,
				"message": "Le fichier de l'effet partage ne peut pas etre relu.",
			}
	var source_effect_path := source.unit_effect.resource_path \
		if source.unit_effect != null else ""
	var disk_effect_path := disk_terrain.unit_effect.resource_path \
		if disk_terrain.unit_effect != null else ""
	if source_effect_path != disk_effect_path \
			or source_effect_path != (effect_path if source.unit_effect != null else "") \
			or terrain_fingerprint(source) != terrain_fingerprint(disk_terrain) \
			or effect_fingerprint(source.unit_effect) != effect_fingerprint(disk_effect):
		return {
			"ok": false,
			"message": (
				"Le catalogue en memoire differe des fichiers. Rechargez le Studio "
				+ "avant de modifier ce type."
			),
		}
	if _file_state(terrain_path) != files[terrain_path] \
			or _file_state(effect_path) != files[effect_path]:
		return {
			"ok": false,
			"message": "Un fichier a change pendant l'ouverture du type.",
		}
	return {
		"ok": true,
		"terrain_path": terrain_path,
		"effect_path": effect_path,
		"files": files,
	}


static func create_working_copy(
		source: ArenaTerrainDefinition
	) -> ArenaTerrainDefinition:
	var copy := _clone_terrain(source)
	if copy == null:
		return null
	copy.set_path_cache("")
	copy.unit_effect = _clone_effect(source.unit_effect) \
		if source.unit_effect != null else TerrainEffectData.new()
	if copy.unit_effect != null:
		copy.unit_effect.set_path_cache("")
	return copy


static func has_changes(
		source: ArenaTerrainDefinition,
		working: ArenaTerrainDefinition
	) -> bool:
	if source == null or working == null:
		return false
	var canonical_effect_path := source.unit_effect.resource_path \
		if source.unit_effect != null else ""
	if terrain_fingerprint(source, canonical_effect_path) \
			!= terrain_fingerprint(working, canonical_effect_path):
		return true
	if source.unit_effect != null:
		return effect_fingerprint(source.unit_effect) \
			!= effect_fingerprint(working.unit_effect)
	return _should_write_effect(source, working)


static func save_working_recovery(
		source: ArenaTerrainDefinition,
		working: ArenaTerrainDefinition,
		opening_state: Dictionary,
		options := {}
	) -> Dictionary:
	if source == null or working == null \
			or not bool(opening_state.get("ok", false)):
		return {"ok": false, "error": "invalid_working_session"}
	var ui_state := options.get("ui_state", {}) as Dictionary
	if not has_changes(source, working) and ui_state.is_empty():
		if not clear_working_recovery(source, options):
			return {
				"ok": false,
				"saved": false,
				"clean": true,
				"error": "working_recovery_cleanup_failed",
			}
		return {"ok": true, "saved": false, "clean": true}
	var recovery_root := str(options.get(
		"working_recovery_root", WORKING_RECOVERY_ROOT
	)).trim_suffix("/")
	if not _safe_user_directory(recovery_root):
		return {"ok": false, "error": "unsafe_working_recovery_root"}
	var safe_id := _safe_path_component(str(source.stable_id))
	if safe_id.is_empty():
		return {"ok": false, "error": "unsafe_stable_id"}
	var source_root := recovery_root.path_join(safe_id)
	if source_root != source_root.simplify_path() \
			or not source_root.begins_with(recovery_root + "/"):
		return {"ok": false, "error": "unsafe_source_recovery_root"}
	var created_usec := int(Time.get_unix_time_from_system() * 1_000_000.0)
	var directory := source_root.path_join(
		"recovery_%d_%d" % [created_usec, Time.get_ticks_usec()]
	)
	if DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(directory)
		) != OK:
		return {"ok": false, "error": "recovery_directory_failed"}
	var terrain_copy := _clone_terrain(working)
	var writes_effect := _should_write_effect(source, working)
	# Un brouillon contient toute la copie isolée, même lorsque l'effet n'a pas
	# changé. Une récupération motivée uniquement par une saisie UI invalide ne
	# doit jamais recréer un effet vide à la place de l'effet partagé inchangé.
	var stores_effect := working.unit_effect != null
	var effect_copy := _clone_effect(working.unit_effect) \
		if stores_effect else null
	if terrain_copy == null or (stores_effect and effect_copy == null):
		return {"ok": false, "error": "recovery_copy_failed"}
	var effect_path := directory.path_join("effect.tres")
	var terrain_path := directory.path_join("terrain.tres")
	var canonical_effect_path := source.unit_effect.resource_path \
		if source.unit_effect != null else str(opening_state.get("effect_path", ""))
	var expected_effect := effect_fingerprint(effect_copy)
	var expected_terrain := terrain_fingerprint(
		terrain_copy, canonical_effect_path if stores_effect else ""
	)
	if stores_effect:
		effect_copy.set_path_cache("")
		if ResourceSaver.save(effect_copy, effect_path) != OK:
			return {"ok": false, "error": "recovery_effect_write_failed"}
		var stored_effect := ResourceLoader.load(
			effect_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as TerrainEffectData
		if stored_effect == null \
				or effect_fingerprint(stored_effect) != expected_effect:
			return {"ok": false, "error": "recovery_effect_verify_failed"}
		terrain_copy.unit_effect = stored_effect
	else:
		terrain_copy.unit_effect = null
	terrain_copy.set_path_cache("")
	if ResourceSaver.save(terrain_copy, terrain_path) != OK:
		return {"ok": false, "error": "recovery_terrain_write_failed"}
	var stored_terrain := ResourceLoader.load(
		terrain_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaTerrainDefinition
	if stored_terrain == null \
			or terrain_fingerprint(
				stored_terrain, canonical_effect_path if stores_effect else ""
			) != expected_terrain \
			or effect_fingerprint(stored_terrain.unit_effect) != expected_effect:
		return {"ok": false, "error": "recovery_terrain_verify_failed"}
	var manifest := {
		"schema_version": 1,
		"source_path": source.resource_path,
		"stable_id": str(source.stable_id),
		"opening_files": opening_state.get("files", {}),
		"canonical_effect_path": canonical_effect_path,
		"terrain_path": terrain_path,
		"effect_path": effect_path if stores_effect else "",
		"stores_effect": stores_effect,
		"writes_effect": writes_effect,
		"terrain_fingerprint": expected_terrain,
		"effect_fingerprint": expected_effect,
		"ui_state": ui_state.duplicate(true),
		"created_usec": created_usec,
	}
	var manifest_path := directory.path_join("manifest.json")
	if not _write_json_verified(manifest_path, manifest):
		return {"ok": false, "error": "recovery_manifest_failed"}
	return {
		"ok": true,
		"saved": true,
		"directory": directory,
		"manifest_path": manifest_path,
	}


static func load_working_recovery(
		source: ArenaTerrainDefinition,
		opening_state: Dictionary,
		options := {}
	) -> Dictionary:
	if source == null or not bool(opening_state.get("ok", false)):
		return {"ok": false, "found": false, "error": "invalid_working_session"}
	var recovery_root := str(options.get(
		"working_recovery_root", WORKING_RECOVERY_ROOT
	)).trim_suffix("/")
	if not _safe_user_directory(recovery_root):
		return {"ok": false, "found": false, "error": "unsafe_recovery_root"}
	var safe_id := _safe_path_component(str(source.stable_id))
	if safe_id.is_empty():
		return {"ok": false, "found": false, "error": "unsafe_stable_id"}
	var source_root := recovery_root.path_join(safe_id)
	if source_root != source_root.simplify_path() \
			or not source_root.begins_with(recovery_root + "/"):
		return {"ok": false, "found": false, "error": "unsafe_source_root"}
	var access := DirAccess.open(ProjectSettings.globalize_path(source_root))
	if access == null:
		return {"ok": true, "found": false}
	var candidates: Array[Dictionary] = []
	for child_name in access.get_directories():
		var manifest_path := source_root.path_join(child_name).path_join(
			"manifest.json"
		)
		var parsed := _read_json(manifest_path)
		if not bool(parsed.get("ok", false)):
			continue
		var manifest := parsed.get("data", {}) as Dictionary
		if str(manifest.get("source_path", "")) == source.resource_path \
				and (manifest.get("opening_files", {}) as Dictionary) \
				== (opening_state.get("files", {}) as Dictionary):
			manifest["manifest_path"] = manifest_path
			candidates.append(manifest)
	if candidates.is_empty():
		return {"ok": true, "found": false}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_usec := int(a.get("created_usec", 0))
		var b_usec := int(b.get("created_usec", 0))
		if a_usec == b_usec:
			return str(a.get("manifest_path", "")) > str(b.get("manifest_path", ""))
		return a_usec > b_usec
	)
	for manifest in candidates:
		var terrain := ResourceLoader.load(
			str(manifest.get("terrain_path", "")), "",
			ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as ArenaTerrainDefinition
		if terrain == null:
			continue
		var canonical_effect_path := str(manifest.get(
			"canonical_effect_path", ""
		))
		if terrain_fingerprint(terrain, canonical_effect_path) \
				!= str(manifest.get("terrain_fingerprint", "")) \
				or effect_fingerprint(terrain.unit_effect) \
				!= str(manifest.get("effect_fingerprint", "")):
			continue
		var working := _clone_terrain(terrain)
		if working == null:
			continue
		working.set_path_cache("")
		working.unit_effect = _clone_effect(terrain.unit_effect) \
			if terrain.unit_effect != null else TerrainEffectData.new()
		if working.unit_effect != null:
			working.unit_effect.set_path_cache("")
		return {
			"ok": true,
			"found": true,
			"working": working,
			"manifest_path": str(manifest.get("manifest_path", "")),
			"ui_state": (
				manifest.get("ui_state", {}) as Dictionary
			).duplicate(true),
		}
	return {"ok": false, "found": true, "error": "recovery_verification_failed"}


static func clear_working_recovery(
		source: ArenaTerrainDefinition,
		options := {}
	) -> bool:
	if source == null:
		return true
	if bool(options.get("test_fail_clear", false)):
		return false
	var recovery_root := str(options.get(
		"working_recovery_root", WORKING_RECOVERY_ROOT
	)).trim_suffix("/")
	if not _safe_user_directory(recovery_root):
		return false
	var safe_id := _safe_path_component(str(source.stable_id))
	if safe_id.is_empty():
		return false
	var source_root := recovery_root.path_join(safe_id)
	if source_root != source_root.simplify_path() \
			or not source_root.begins_with(recovery_root + "/"):
		return false
	return _remove_user_directory_tree(source_root, recovery_root)


static func plan(
		source: ArenaTerrainDefinition,
		working: ArenaTerrainDefinition,
		opening_state: Dictionary,
		options := {}
	) -> Dictionary:
	var blocking := PackedStringArray()
	var paths := _target_paths(source, options)
	if source == null or working == null:
		blocking.append("Aucun type de tuile editable n'est ouvert.")
	if not bool(paths.get("ok", false)):
		blocking.append(str(paths.get(
			"message", "Les chemins du type de tuile sont invalides."
		)))
	var terrain_path := str(paths.get("terrain_path", ""))
	var effect_path := str(paths.get("effect_path", ""))
	if source != null and working != null and source.stable_id != working.stable_id:
		blocking.append(
			"L'identifiant stable ne peut pas etre modifie par cette operation."
		)
	if working != null and source != null and source.unit_effect != null \
			and working.unit_effect == null:
		blocking.append("L'effet de terrain de la copie de travail est absent.")
	if opening_state.is_empty() or not bool(opening_state.get("ok", false)):
		blocking.append(
			"L'empreinte d'ouverture manque : fermez puis rouvrez ce type."
		)
	elif str(opening_state.get("terrain_path", "")) != terrain_path \
			or str(opening_state.get("effect_path", "")) != effect_path:
		blocking.append(
			"Les chemins ont change depuis l'ouverture : fermez puis rouvrez ce type."
		)
	var conflicts := _external_conflicts(opening_state, terrain_path, effect_path)
	for conflict_value in conflicts:
		var conflict := conflict_value as Dictionary
		blocking.append(str(conflict.get(
			"message", "Un fichier a change en dehors du Studio."
		)))
	var creates := PackedStringArray()
	var modifies := PackedStringArray()
	var writes_effect := _should_write_effect(source, working)
	var write_order := PackedStringArray([terrain_path])
	if writes_effect:
		write_order = PackedStringArray([effect_path, terrain_path])
	for path in write_order:
		if path.is_empty():
			continue
		if FileAccess.file_exists(path):
			modifies.append(path)
		else:
			creates.append(path)
	var summary := "Mettre a jour le type partage dans %s." % terrain_path
	if writes_effect:
		summary = (
			"Mettre a jour le type partage dans %s et son effet dans %s."
			% [terrain_path, effect_path]
		)
	return {
		"ok": blocking.is_empty(),
		"terrain_path": terrain_path,
		"effect_path": effect_path,
		"writes_effect": writes_effect,
		"write_order": write_order,
		"creates": creates,
		"modifies": modifies,
		"blocking": blocking,
		"conflicts": conflicts,
		"summary": summary,
	}


static func save(
		source: ArenaTerrainDefinition,
		working: ArenaTerrainDefinition,
		opening_state: Dictionary,
		options := {}
	) -> Dictionary:
	var pending_recovery := recover_pending_transactions(options)
	if not bool(pending_recovery.get("ok", false)):
		return _failure(
			"PENDING_RECOVERY",
			"Une transaction précédente doit être récupérée manuellement avant d'enregistrer.",
			null, {}, pending_recovery
		)
	var save_plan := plan(source, working, opening_state, options)
	if not bool(save_plan.get("ok", false)):
		return _blocked(save_plan)
	var terrain_path := str(save_plan.terrain_path)
	var effect_path := str(save_plan.effect_path)
	var writes_effect := bool(save_plan.writes_effect)
	var terrain_copy := _clone_terrain(working)
	var effect_copy := _clone_effect(working.unit_effect) if writes_effect else null
	if terrain_copy == null or (writes_effect and effect_copy == null):
		return _failure(
			"COPY", "La copie de publication n'a pas pu etre preparee.", save_plan
		)
	terrain_copy.set_path_cache("")
	if effect_copy != null:
		effect_copy.set_path_cache("")
	else:
		terrain_copy.unit_effect = null
	var terrain_effect_path := effect_path if writes_effect else ""
	var expected_effect := effect_fingerprint(effect_copy)
	var expected_terrain := terrain_fingerprint(
		terrain_copy, terrain_effect_path
	)
	var transaction := _open_transaction(source, options)
	if not bool(transaction.get("ok", false)):
		return _failure(
			"TRANSACTION_DIRECTORY",
			"Le dossier de sauvegarde de secours n'a pas pu etre cree.",
			save_plan
		)
	var nonce := Time.get_ticks_usec()
	var stage_paths := {
		"effect": str(transaction.directory).path_join("stage_effect.tres"),
		"terrain": str(transaction.directory).path_join("stage_terrain.tres"),
		"effect_commit": "%s.terrain_type_commit_%d.tres" % [
			effect_path.get_basename(), nonce,
		],
		"terrain_commit": "%s.terrain_type_commit_%d.tres" % [
			terrain_path.get_basename(), nonce,
		],
		"effect_previous": "%s.terrain_type_previous_%d.tres" % [
			effect_path.get_basename(), nonce,
		],
		"terrain_previous": "%s.terrain_type_previous_%d.tres" % [
			terrain_path.get_basename(), nonce,
		],
	}
	# Consigne les temporaires avant même le staging. Si l'écriture ou son
	# nettoyage échoue, le prochain passage de recovery connaît ainsi chaque
	# stage user:// et chaque voisin de commit à retirer.
	transaction["stage_paths"] = stage_paths.duplicate(true)
	transaction["targets"] = (
		save_plan.get("write_order", PackedStringArray()) as PackedStringArray
	).duplicate()
	var staged := _stage(
		terrain_copy, effect_copy, terrain_path, effect_path,
		expected_terrain, expected_effect, stage_paths, options, writes_effect
	)
	_register_owned_stage_states(
		transaction, staged.get("owned_states", {}) as Dictionary
	)
	if not bool(staged.get("ok", false)):
		var cleanup := _cleanup_stages(stage_paths, transaction)
		var journal_ok := _close_transaction(
			transaction,
			&"STAGE_FAILED" if bool(cleanup.get("ok", false)) \
			else &"STAGE_CLEANUP_FAILED",
			{"staging": staged, "cleanup": cleanup}
		)
		if not journal_ok:
			return _failure(
				"TRANSACTION_JOURNAL",
				"Le staging a échoué et son statut terminal n'a pas pu être journalisé.",
				save_plan, transaction, {"staging": staged, "cleanup": cleanup}
			)
		if not bool(cleanup.get("ok", false)):
			return _failure(
				"STAGE_CLEANUP",
				"Le staging a échoué et un fichier temporaire subsiste.",
				save_plan, transaction, cleanup
			)
		staged["plan"] = save_plan
		return staged
	# Le staging peut prendre du temps : le controle concurrent est repete au
	# dernier moment, avant la premiere mutation d'un fichier cible.
	var late_conflicts := _external_conflicts(
		opening_state, terrain_path, effect_path
	)
	if not late_conflicts.is_empty():
		var conflicted := save_plan.duplicate(true)
		conflicted["ok"] = false
		conflicted["conflicts"] = late_conflicts
		conflicted["blocking"] = PackedStringArray([
			str((late_conflicts[0] as Dictionary).get(
				"message", "Un fichier a change en dehors du Studio."
			)),
		])
		var cleanup := _cleanup_stages(stage_paths, transaction)
		if not bool(cleanup.get("ok", false)):
			var journal_ok := _close_transaction(
				transaction, &"STAGE_CLEANUP_FAILED", cleanup
			)
			return _failure(
				"STAGE_CLEANUP" if journal_ok else "TRANSACTION_JOURNAL",
				"Un conflit a été détecté mais le staging n'a pas pu être retiré.",
				conflicted, transaction, cleanup
			)
		if not _close_transaction(transaction, &"EXTERNAL_CONFLICT", conflicted):
			return _failure(
				"TRANSACTION_JOURNAL",
				"Le conflit a été préservé mais son statut n'a pas pu être journalisé.",
				conflicted, transaction
			)
		return _blocked(conflicted)
	var targets := save_plan.write_order as PackedStringArray
	if not _backup_files(transaction, targets):
		var cleanup := _cleanup_stages(stage_paths, transaction)
		var journal_ok := _close_transaction(
			transaction,
			&"BACKUP_FAILED" if bool(cleanup.get("ok", false)) \
			else &"STAGE_CLEANUP_FAILED",
			{"plan": save_plan, "cleanup": cleanup}
		)
		return _failure(
			("BACKUP" if bool(cleanup.get("ok", false)) else "STAGE_CLEANUP") \
			if journal_ok else "TRANSACTION_JOURNAL",
			"Les copies de secours n'ont pas pu etre creees." \
			if bool(cleanup.get("ok", false)) else
			"Les copies de secours ont échoué et un staging subsiste.",
			save_plan, transaction, cleanup
		)
	var post_backup_conflicts := _external_conflicts(
		opening_state, terrain_path, effect_path
	)
	if not post_backup_conflicts.is_empty():
		var post_backup_plan := save_plan.duplicate(true)
		post_backup_plan["ok"] = false
		post_backup_plan["conflicts"] = post_backup_conflicts
		post_backup_plan["blocking"] = PackedStringArray([
			str((post_backup_conflicts[0] as Dictionary).get(
				"message", "Un fichier a change en dehors du Studio."
			)),
		])
		var cleanup := _cleanup_stages(stage_paths, transaction)
		if not bool(cleanup.get("ok", false)):
			var journal_ok := _close_transaction(
				transaction, &"STAGE_CLEANUP_FAILED", cleanup
			)
			return _failure(
				"STAGE_CLEANUP" if journal_ok else "TRANSACTION_JOURNAL",
				"Un conflit a été détecté mais le staging n'a pas pu être retiré.",
				post_backup_plan, transaction, cleanup
			)
		if not _close_transaction(
				transaction, &"EXTERNAL_CONFLICT", post_backup_plan
			):
			return _failure(
				"TRANSACTION_JOURNAL",
				"Le conflit a été préservé mais son statut n'a pas pu être journalisé.",
				post_backup_plan, transaction
			)
		return _blocked(post_backup_plan)
	var target_stages := {}
	target_stages[terrain_path] = str(stage_paths.terrain)
	if writes_effect:
		target_stages[effect_path] = str(stage_paths.effect)
	if not _prepare_journal(
			transaction, save_plan, target_stages, stage_paths, opening_state
		):
		var cleanup := _cleanup_stages(stage_paths, transaction)
		var journal_ok := _close_transaction(
			transaction,
			&"JOURNAL_PREPARE_FAILED" if bool(cleanup.get("ok", false)) \
			else &"STAGE_CLEANUP_FAILED",
			{"plan": save_plan, "cleanup": cleanup}
		)
		return _failure(
			("JOURNAL_PREPARE" \
			if bool(cleanup.get("ok", false)) else "STAGE_CLEANUP") \
			if journal_ok else "TRANSACTION_JOURNAL",
			"Le journal de récupération n'a pas pu être préparé ; rien n'a été écrit." \
			if bool(cleanup.get("ok", false)) else
			"Le journal et le nettoyage du staging ont échoué.",
			save_plan, transaction, cleanup
		)
	var applied := PackedStringArray()
	if writes_effect:
		if not _mark_target_touched(transaction, effect_path, save_plan):
			return _rollback_failure(
				"JOURNAL_EFFECT", "Le journal n'a pas pu sécuriser l'effet.",
				save_plan, transaction, stage_paths, applied
			)
		var effect_replace := _commit_stage(
			str(stage_paths.effect), str(stage_paths.effect_commit),
			str(stage_paths.effect_previous), effect_path, transaction, save_plan
		)
		if not bool(effect_replace.get("ok", false)):
			return _rollback_failure(
				"WRITE_EFFECT", "L'effet de terrain n'a pas pu etre remplace.",
				save_plan, transaction, stage_paths, applied
			)
		if str(options.get("failure_step", "")) \
				== "interrupt_after_effect_rename":
			return _failure(
				"INJECTED_INTERRUPTION",
				"Interruption injectée après le rename de l'effet ; reprise requise.",
				save_plan, transaction, {"stage_paths": stage_paths}
			)
		applied.append(effect_path)
		if not _mark_target_committed(transaction, effect_path, save_plan):
			return _rollback_failure(
				"JOURNAL_EFFECT_COMMIT",
				"Le remplacement de l'effet n'a pas pu être journalisé.",
				save_plan, transaction, stage_paths, applied
			)
		if str(options.get("failure_step", "")) == "interrupt_after_effect_commit":
			return _failure(
				"INJECTED_INTERRUPTION",
				"Interruption injectée après l'effet ; reprise requise.",
				save_plan, transaction, {"stage_paths": stage_paths}
			)
		if str(options.get("failure_step", "")) == "after_effect_commit":
			return _rollback_failure(
				"INJECTED_AFTER_EFFECT", "Echec injecte apres l'effet.",
				save_plan, transaction, stage_paths, applied
			)
		var restaged_terrain := _restage_terrain_after_effect_commit(
			terrain_copy, terrain_path, effect_path,
			str(stage_paths.terrain), expected_terrain, expected_effect,
			transaction, save_plan
		)
		if not bool(restaged_terrain.get("ok", false)):
			return _rollback_failure(
				"RESTAGE_TERRAIN",
				"Le type n'a pas pu être restagé avec l'effet publié.",
				save_plan, transaction, stage_paths, applied, restaged_terrain
			)
	if not _mark_target_touched(transaction, terrain_path, save_plan):
		return _rollback_failure(
			"JOURNAL_TERRAIN", "Le journal n'a pas pu sécuriser le type de tuile.",
			save_plan, transaction, stage_paths, applied
		)
	var terrain_replace := _commit_stage(
		str(stage_paths.terrain), str(stage_paths.terrain_commit),
		str(stage_paths.terrain_previous), terrain_path, transaction, save_plan
	)
	if not bool(terrain_replace.get("ok", false)):
		return _rollback_failure(
			"WRITE_TERRAIN", "Le type de tuile n'a pas pu etre remplace.",
			save_plan, transaction, stage_paths, applied
		)
	applied.append(terrain_path)
	if not _mark_target_committed(transaction, terrain_path, save_plan):
		return _rollback_failure(
			"JOURNAL_TERRAIN_COMMIT",
			"Le remplacement du type n'a pas pu être journalisé.",
			save_plan, transaction, stage_paths, applied
		)
	if str(options.get("failure_step", "")) == "after_terrain_commit":
		return _rollback_failure(
			"INJECTED_AFTER_TERRAIN", "Echec injecte apres le type de tuile.",
			save_plan, transaction, stage_paths, applied
		)
	var verification := _verify_written(
		terrain_path, effect_path, expected_terrain, expected_effect,
		writes_effect, transaction.get("prepared_states", {}) as Dictionary
	)
	if str(options.get("failure_step", "")) == "verification":
		verification = {"ok": false, "error": "injected_verification"}
	if not bool(verification.get("ok", false)):
		return _rollback_failure(
			"VERIFY", "La relecture ne correspond pas a la copie de travail.",
			save_plan, transaction, stage_paths, applied, verification
		)
	# Met a jour les instances deja distribuees par ResourceLoader avant que le
	# catalogue ne soit reconstruit. La relecture profonde evite un effet imbrique
	# reste dans un ancien etat de cache.
	var cached_effect: TerrainEffectData = null
	if writes_effect:
		cached_effect = ResourceLoader.load(
			effect_path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP
		) as TerrainEffectData
	var cached_terrain := ResourceLoader.load(
		terrain_path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP
	) as ArenaTerrainDefinition
	var cached_effect_path := cached_terrain.unit_effect.resource_path \
		if cached_terrain != null and cached_terrain.unit_effect != null else ""
	var cache_verification := {
		"ok": cached_terrain != null \
			and (cached_effect != null or not writes_effect) \
			and cached_effect_path == terrain_effect_path \
			and terrain_fingerprint(cached_terrain) \
			== expected_terrain \
			and effect_fingerprint(cached_effect) == expected_effect \
			and (not writes_effect or effect_fingerprint(
				cached_terrain.unit_effect
			) == expected_effect),
		"referenced_effect_path": cached_effect_path,
	}
	if not bool(cache_verification.ok):
		var cache_failure := _rollback_failure(
			"CACHE_REFRESH",
			"Le cache du catalogue ne correspond pas aux fichiers ecrits.",
			save_plan, transaction, stage_paths, applied, cache_verification
		)
		_reload_restored_cache(terrain_path, effect_path, writes_effect)
		return cache_failure
	var commit_cleanup := _cleanup_stages(stage_paths, transaction)
	if not bool(commit_cleanup.get("ok", false)):
		return _rollback_failure(
			"STAGE_CLEANUP",
			"Un fichier temporaire de commit n'a pas pu être retiré.",
			save_plan, transaction, stage_paths, applied, commit_cleanup
		)
	ArenaCatalogService.reset_cache()
	var commit_details := {
		"plan": save_plan,
		"verification": verification,
		"cache_verification": cache_verification,
	}
	if not _close_transaction(transaction, &"COMMITTED", commit_details):
		var journal_failure := _rollback_failure(
			"COMMIT_JOURNAL",
			"Le commit est vérifié mais son journal final n'a pas pu être écrit.",
			save_plan, transaction, stage_paths, applied, commit_details
		)
		_reload_restored_cache(terrain_path, effect_path, writes_effect)
		return journal_failure
	return {
		"ok": true,
		"step": "COMMITTED",
		"terrain_path": terrain_path,
		"effect_path": effect_path,
		"saved_paths": targets,
		"plan": save_plan,
		"rolled_back": false,
		"message": (
			"Type partage et effet enregistres puis relus sans erreur."
			if writes_effect else "Type partage enregistre puis relu sans erreur."
		),
	}


static func terrain_fingerprint(
		resource: ArenaTerrainDefinition,
		effect_path := ""
	) -> String:
	if resource == null:
		return ""
	var resolved_effect_path := effect_path
	if resolved_effect_path.is_empty() and resource.unit_effect != null:
		resolved_effect_path = resource.unit_effect.resource_path
	var snapshot := _storage_snapshot(resource, {
		"unit_effect": resolved_effect_path,
	})
	return JSON.stringify(snapshot).sha256_text()


static func effect_fingerprint(resource: TerrainEffectData) -> String:
	if resource == null:
		return ""
	var snapshot := _storage_snapshot(resource)
	return JSON.stringify(snapshot).sha256_text()


static func _should_write_effect(
		source: ArenaTerrainDefinition,
		working: ArenaTerrainDefinition
	) -> bool:
	if source != null and source.unit_effect != null:
		return true
	if working == null or working.unit_effect == null:
		return false
	if working.apply_on_enter or working.apply_on_turn_start \
			or working.refresh_status_while_standing:
		return true
	return effect_fingerprint(working.unit_effect) \
		!= effect_fingerprint(TerrainEffectData.new())


static func _target_paths(
		source: ArenaTerrainDefinition,
		options: Dictionary
	) -> Dictionary:
	if source == null or source.resource_path.is_empty():
		return {
			"ok": false,
			"message": "Le type partage ne possede pas de chemin canonique.",
		}
	var terrain_path := source.resource_path
	var effect_path := source.unit_effect.resource_path \
		if source.unit_effect != null else ""
	if effect_path.is_empty():
		effect_path = str(options.get(
			"new_effect_path",
			terrain_path.get_basename() + "_effect.tres"
		))
	var roots := _allowed_roots(options)
	if not _safe_path(terrain_path, roots) or not _safe_path(effect_path, roots):
		return {
			"ok": false,
			"terrain_path": terrain_path,
			"effect_path": effect_path,
			"message": "Un chemin sort des dossiers autorises pour cette transaction.",
		}
	if terrain_path == effect_path:
		return {
			"ok": false,
			"terrain_path": terrain_path,
			"effect_path": effect_path,
			"message": "Le type de tuile et son effet doivent utiliser deux fichiers distincts.",
		}
	return {
		"ok": true,
		"terrain_path": terrain_path,
		"effect_path": effect_path,
	}


static func _allowed_roots(options: Dictionary) -> PackedStringArray:
	var configured = options.get("allowed_roots", DEFAULT_ALLOWED_ROOTS)
	var roots := PackedStringArray()
	for value in configured:
		var root := str(value).trim_suffix("/")
		if not _has_unsafe_segments(root) \
				and root == root.simplify_path() \
				and (root.begins_with("res://") or root.begins_with("user://")):
			roots.append(root)
	return roots


static func _safe_path(path: String, roots: PackedStringArray) -> bool:
	if _has_unsafe_segments(path) or path != path.simplify_path() \
			or not path.ends_with(".tres") \
			or not (path.begins_with("res://") or path.begins_with("user://")):
		return false
	for root in roots:
		if path == root or path.begins_with(root + "/"):
			return true
	return false


static func _safe_user_directory(path: String) -> bool:
	return not path.is_empty() \
		and path.begins_with("user://") \
		and path != "user://" \
		and not _has_unsafe_segments(path) \
		and path == path.simplify_path()


static func _has_unsafe_segments(path: String) -> bool:
	if path.contains("\\"):
		return true
	for segment in path.split("/", false):
		if segment == "..":
			return true
	return false


static func _safe_path_component(value: String) -> String:
	var clean := value.strip_edges()
	if clean.is_empty() or clean in [".", ".."] \
			or clean.contains("/") or clean.contains("\\") \
			or clean.ends_with(".") or clean.ends_with(" ") \
			or clean.validate_filename() != clean:
		return ""
	var windows_base := clean.get_basename().to_upper()
	if windows_base in [
		"CON", "PRN", "AUX", "NUL",
		"COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
		"LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
	]:
		return ""
	return clean


static func _external_conflicts(
		opening_state: Dictionary,
		terrain_path: String,
		effect_path: String
	) -> Array[Dictionary]:
	var conflicts: Array[Dictionary] = []
	var files := opening_state.get("files", {}) as Dictionary
	for path in PackedStringArray([effect_path, terrain_path]):
		if path.is_empty():
			continue
		var expected := files.get(path, {}) as Dictionary
		var actual := _file_state(path)
		if expected.is_empty() or actual != expected:
			conflicts.append({
				"code": &"EXTERNAL_MODIFICATION",
				"path": path,
				"expected": expected,
				"actual": actual,
				"message": (
					"%s a change depuis l'ouverture ; rechargez le type avant d'enregistrer."
					% path
				),
			})
	return conflicts


static func _file_state(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {"exists": false}
	var uid := _resource_uid(path)
	return {
		"exists": true,
		"sha256": FileAccess.get_sha256(path),
		"uid": ResourceUID.id_to_text(uid) \
			if uid != ResourceUID.INVALID_ID else "",
	}


static func _resource_uid(path: String) -> int:
	# Un backup ou un stage porte bien le uid= du .tres, mais il n'est pas
	# enregistré dans la table globale ResourceUID à son chemin temporaire.
	# ResourceLoader.get_resource_uid() peut donc répondre INVALID_ID pour ces
	# voisins alors que leurs octets sont corrects. Lire l'en-tête évite aussi de
	# déplacer la correspondance globale du chemin canonique pendant le staging.
	if path.is_empty() or not FileAccess.file_exists(path):
		return ResourceUID.INVALID_ID
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ResourceUID.INVALID_ID
	var header := file.get_line()
	file.close()
	var marker := " uid=\""
	var marker_offset := header.find(marker)
	if marker_offset < 0:
		return ResourceUID.INVALID_ID
	var uid_offset := marker_offset + marker.length()
	var uid_end := header.find("\"", uid_offset)
	if uid_end <= uid_offset:
		return ResourceUID.INVALID_ID
	return ResourceUID.text_to_id(header.substr(
		uid_offset, uid_end - uid_offset
	))


static func _stage(
		terrain_copy: ArenaTerrainDefinition,
		effect_copy: TerrainEffectData,
		terrain_path: String,
		effect_path: String,
		expected_terrain: String,
		expected_effect: String,
		stage_paths: Dictionary,
		options: Dictionary,
		writes_effect: bool
	) -> Dictionary:
	var owned_states := {}
	var target_paths := PackedStringArray([terrain_path])
	if writes_effect:
		target_paths.append(effect_path)
	for target in target_paths:
		var error := DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(target.get_base_dir())
		)
		if error != OK:
			return _failure(
				"STAGE_DIRECTORY", "Un dossier cible est inaccessible.", null,
				{}, {"path": target, "code": error}
			)
	if writes_effect:
		if str(options.get("failure_step", "")) == "stage_effect":
			return _failure("STAGE_EFFECT", "Echec injecte pendant le staging.")
		var effect_error := ResourceSaver.save(
			effect_copy, str(stage_paths.effect)
		)
		if effect_error != OK:
			return _failure(
				"STAGE_EFFECT", "L'effet temporaire n'a pas pu etre ecrit.", null,
				{}, {"code": effect_error}
			).merged({"owned_states": owned_states}, true)
		owned_states[str(stage_paths.effect)] = _file_state(str(stage_paths.effect))
		var staged_effect := ResourceLoader.load(
			str(stage_paths.effect), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as TerrainEffectData
		if staged_effect == null \
				or effect_fingerprint(staged_effect) != expected_effect:
			return _failure(
				"VERIFY_STAGED_EFFECT",
				"La relecture temporaire de l'effet ne correspond pas."
			).merged({"owned_states": owned_states}, true)
		# Le type temporaire doit referencer le futur chemin canonique, jamais le
		# fichier de staging. set_path_cache ne publie pas la Resource dans le cache.
		staged_effect.set_path_cache(effect_path)
		terrain_copy.unit_effect = staged_effect
	else:
		terrain_copy.unit_effect = null
	if str(options.get("failure_step", "")) == "stage_terrain":
		return _failure(
			"STAGE_TERRAIN", "Echec injecte pendant le staging."
		).merged({"owned_states": owned_states}, true)
	var terrain_error := ResourceSaver.save(
		terrain_copy, str(stage_paths.terrain)
	)
	if terrain_error != OK:
		return _failure(
			"STAGE_TERRAIN", "Le type temporaire n'a pas pu etre ecrit.", null,
			{}, {"code": terrain_error}
		).merged({"owned_states": owned_states}, true)
	owned_states[str(stage_paths.terrain)] = _file_state(str(stage_paths.terrain))
	var staged_terrain := ResourceLoader.load(
		str(stage_paths.terrain), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaTerrainDefinition
	var staged_effect_path := staged_terrain.unit_effect.resource_path \
		if staged_terrain != null and staged_terrain.unit_effect != null else ""
	if staged_terrain == null \
			or staged_effect_path != (effect_path if writes_effect else "") \
			or terrain_fingerprint(staged_terrain) != expected_terrain:
		return _failure(
			"VERIFY_STAGED_TERRAIN",
			"La relecture temporaire du type de tuile ne correspond pas."
		).merged({"owned_states": owned_states}, true)
	return {"ok": true, "owned_states": owned_states}


static func _open_transaction(
		source: ArenaTerrainDefinition,
		options: Dictionary
	) -> Dictionary:
	var safe_id := _safe_path_component(str(source.stable_id))
	if safe_id.is_empty():
		return {"ok": false, "code": ERR_INVALID_PARAMETER}
	var transaction_id := "%s_%d" % [safe_id, Time.get_ticks_usec()]
	var transaction_root := str(options.get(
		"transaction_root", TRANSACTION_ROOT
	)).trim_suffix("/")
	if not _safe_user_directory(transaction_root):
		return {"ok": false, "code": ERR_INVALID_PARAMETER}
	var directory := transaction_root.path_join(transaction_id)
	if directory != directory.simplify_path() \
			or not directory.begins_with(transaction_root + "/"):
		return {"ok": false, "code": ERR_INVALID_PARAMETER}
	var error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)
	if error != OK:
		return {"ok": false, "code": error}
	return {
		"ok": true,
		"id": transaction_id,
		"directory": directory,
		"backups": {},
		"backup_states": {},
		"absent": PackedStringArray(),
		"prepared_states": {},
		"original_states": {},
		"committed_states": {},
		"renamed_targets": PackedStringArray(),
		"rename_intents": {},
		"previous_paths": {},
		"previous_states": {},
		"stage_owned_states": {},
		"touched": PackedStringArray(),
		"stage_paths": {},
		"journal_sequence": 0,
		"allowed_roots": _allowed_roots(options),
		"transaction_root": transaction_root,
		"failure_step": str(options.get("failure_step", "")),
		"before_target_quarantine_hook": options.get(
			"before_target_quarantine_hook", Callable()
		) as Callable,
		"after_target_quarantine_hook": options.get(
			"after_target_quarantine_hook", Callable()
		) as Callable,
		"before_rollback_quarantine_hook": options.get(
			"before_rollback_quarantine_hook", Callable()
		) as Callable,
	}


static func _backup_files(
		transaction: Dictionary,
		paths: PackedStringArray
	) -> bool:
	var backups := transaction.backups as Dictionary
	var backup_states := transaction.backup_states as Dictionary
	var absent := transaction.absent as PackedStringArray
	var index := 0
	for path in paths:
		if FileAccess.file_exists(path):
			var backup_path := str(transaction.directory).path_join(
				"backup_%d_%s" % [index, path.get_file()]
			)
			index += 1
			if DirAccess.copy_absolute(
				ProjectSettings.globalize_path(path),
				ProjectSettings.globalize_path(backup_path)
			) != OK:
				return false
			backups[path] = backup_path
			backup_states[path] = _file_state(backup_path)
		else:
			absent.append(path)
	transaction["backups"] = backups
	transaction["backup_states"] = backup_states
	transaction["absent"] = absent
	return true


static func _commit_stage(
		stage_path: String,
		neighbor_stage_path: String,
		previous_path: String,
		target_path: String,
		transaction: Dictionary,
		save_plan: Dictionary
	) -> Dictionary:
	var original_states := transaction.get("original_states", {}) as Dictionary
	var original_state := original_states.get(target_path, {}) as Dictionary
	var current_state := _file_state(target_path)
	if original_state.is_empty() or current_state != original_state:
		return {
			"ok": false,
			"conflict": true,
			"error": "external_modification_before_replace",
			"expected": original_state,
			"actual": current_state,
		}
	var uid_result := _preserve_target_uid(stage_path, original_state)
	if not bool(uid_result.get("ok", false)):
		return uid_result.merged({"error": "stage_uid_failed"}, true)
	if FileAccess.file_exists(neighbor_stage_path):
		return {
			"ok": false, "conflict": true,
			"error": "neighbor_stage_already_exists",
		}
	var prepared_state := _file_state(stage_path)
	if not bool(prepared_state.get("exists", false)):
		return {"ok": false, "error": "source_stage_missing"}
	_register_owned_stage_states(transaction, {stage_path: prepared_state})
	if not _release_uid_mapping_for_commit(
			target_path, stage_path, prepared_state
		):
		return {"ok": false, "error": "stage_uid_mapping_conflict"}
	var neighbor_copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(stage_path),
		ProjectSettings.globalize_path(neighbor_stage_path)
	)
	if FileAccess.file_exists(neighbor_stage_path):
		_register_owned_stage_states(transaction, {
			neighbor_stage_path: _file_state(neighbor_stage_path),
		})
	if neighbor_copy_error != OK:
		return {
			"ok": false, "error": "neighbor_stage_copy_failed",
			"code": neighbor_copy_error,
		}
	if _file_state(neighbor_stage_path) != prepared_state:
		return {"ok": false, "error": "neighbor_stage_verify_failed"}
	var prepared_states := transaction.get("prepared_states", {}) as Dictionary
	prepared_states[target_path] = prepared_state
	transaction["prepared_states"] = prepared_states
	var rename_intents := transaction.get("rename_intents", {}) as Dictionary
	rename_intents[target_path] = neighbor_stage_path
	transaction["rename_intents"] = rename_intents
	var previous_paths := transaction.get("previous_paths", {}) as Dictionary
	var previous_states := transaction.get("previous_states", {}) as Dictionary
	if bool(original_state.get("exists", false)):
		previous_paths[target_path] = previous_path
		previous_states[target_path] = original_state
	transaction["previous_paths"] = previous_paths
	transaction["previous_states"] = previous_states
	if not _write_journal(transaction, &"APPLYING", {
		"phase": "neighbor_stage_ready",
		"target": target_path,
		"plan": save_plan,
	}):
		return {"ok": false, "error": "stage_ready_journal_failed"}
	if bool(original_state.get("exists", false)):
		var quarantine := _move_verified(
			target_path, previous_path, original_state,
			transaction.get("before_target_quarantine_hook", Callable()) as Callable
		)
		if not bool(quarantine.get("ok", false)):
			return quarantine.merged({
				"error": "target_quarantine_conflict",
				"target": target_path,
			}, true)
		_register_stage_path(
			transaction, "previous_" + target_path.sha256_text().left(12),
			previous_path, original_state
		)
	elif _path_occupied(target_path):
		return {
			"ok": false, "conflict": true,
			"error": "new_external_target_before_replace",
			"target": target_path,
		}
	if not _write_journal(transaction, &"APPLYING", {
		"phase": "target_quarantined",
		"target": target_path,
		"plan": save_plan,
	}):
		return {"ok": false, "error": "quarantine_journal_failed"}
	var after_quarantine_hook := transaction.get(
		"after_target_quarantine_hook", Callable()
	) as Callable
	if after_quarantine_hook.is_valid():
		after_quarantine_hook.call(target_path, previous_path)
	var install := _move_verified(
		neighbor_stage_path, target_path, prepared_state
	)
	if not bool(install.get("ok", false)):
		var restored_previous := {}
		if bool(original_state.get("exists", false)) \
				and not _path_occupied(target_path):
			restored_previous = _move_verified(
				previous_path, target_path, original_state
			)
		return install.merged({
			"error": "target_install_failed",
			"restored_previous": restored_previous,
			"target": target_path,
		}, true)
	var renamed_targets := transaction.get(
		"renamed_targets", PackedStringArray()
	) as PackedStringArray
	if not renamed_targets.has(target_path):
		renamed_targets.append(target_path)
	transaction["renamed_targets"] = renamed_targets
	if not _write_journal(transaction, &"APPLYING", {
		"phase": "after_atomic_rename",
		"target": target_path,
		"plan": save_plan,
	}):
		return {"ok": false, "error": "rename_journal_failed"}
	return {"ok": true, "code": OK}


static func _move_verified(
		source_path: String,
		destination_path: String,
		expected_state: Dictionary,
		before_move_hook: Callable = Callable()
	) -> Dictionary:
	if source_path.is_empty() or destination_path.is_empty() \
			or expected_state.is_empty():
		return {"ok": false, "error": "invalid_verified_move"}
	if _file_state(source_path) != expected_state:
		return {
			"ok": false, "conflict": true,
			"error": "source_changed_before_move",
			"source": source_path,
			"current": _file_state(source_path),
			"expected": expected_state,
		}
	if _path_occupied(destination_path):
		return {
			"ok": false, "conflict": true,
			"error": "destination_occupied",
			"destination": destination_path,
		}
	if before_move_hook.is_valid():
		before_move_hook.call(source_path, destination_path)
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(destination_path)
	)
	if rename_error != OK:
		return {
			"ok": false,
			"conflict": _path_occupied(destination_path),
			"error": "verified_move_failed",
			"code": rename_error,
			"source": source_path,
			"destination": destination_path,
		}
	var moved_state := _file_state(destination_path)
	if moved_state == expected_state:
		return {
			"ok": true,
			"source": source_path,
			"destination": destination_path,
			"state": moved_state,
		}
	var returned := _return_moved_file(
		destination_path, source_path, moved_state
	)
	return {
		"ok": false,
		"conflict": true,
		"error": "moved_source_fingerprint_changed",
		"expected": expected_state,
		"moved": moved_state,
		"returned": returned,
		"preserved_path": source_path if bool(returned.get("ok", false)) \
			else destination_path,
	}


static func _return_moved_file(
		moved_path: String,
		original_path: String,
		moved_state: Dictionary
	) -> Dictionary:
	if moved_state.is_empty() or _file_state(moved_path) != moved_state \
			or _path_occupied(original_path):
		return {"ok": false, "preserved_path": moved_path}
	var error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(moved_path),
		ProjectSettings.globalize_path(original_path)
	)
	var restored := error == OK and _file_state(original_path) == moved_state
	if restored:
		restored = _sync_uid_mapping(original_path, moved_state)
	return {
		"ok": restored,
		"code": error,
		"preserved_path": original_path if error == OK else moved_path,
	}


static func _register_owned_stage_states(
		transaction: Dictionary,
		states: Dictionary
	) -> void:
	var owned := transaction.get("stage_owned_states", {}) as Dictionary
	for path_value in states:
		var path := str(path_value)
		var state := states[path_value] as Dictionary
		if not path.is_empty() and bool(state.get("exists", false)):
			owned[path] = state.duplicate(true)
	transaction["stage_owned_states"] = owned


static func _path_occupied(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(path)
	)


static func _register_stage_path(
		transaction: Dictionary,
		key: String,
		path: String,
		state: Dictionary
	) -> void:
	var stage_paths := transaction.get("stage_paths", {}) as Dictionary
	stage_paths[key] = path
	transaction["stage_paths"] = stage_paths
	_register_owned_stage_states(transaction, {path: state})


static func _restage_terrain_after_effect_commit(
		terrain_copy: ArenaTerrainDefinition,
		terrain_path: String,
		effect_path: String,
		terrain_stage_path: String,
		expected_terrain: String,
		expected_effect: String,
		transaction: Dictionary,
		save_plan: Dictionary
	) -> Dictionary:
	var committed_states := transaction.get("committed_states", {}) as Dictionary
	var committed_effect_state := committed_states.get(effect_path, {}) as Dictionary
	if committed_effect_state.is_empty() \
			or _file_state(effect_path) != committed_effect_state:
		return {"ok": false, "error": "committed_effect_changed"}
	var committed_effect := ResourceLoader.load(
		effect_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as TerrainEffectData
	if committed_effect == null \
			or effect_fingerprint(committed_effect) != expected_effect:
		return {"ok": false, "error": "committed_effect_unreadable"}
	terrain_copy.unit_effect = committed_effect
	if ResourceSaver.save(terrain_copy, terrain_stage_path) != OK:
		return {"ok": false, "error": "terrain_restage_write_failed"}
	var restaged := ResourceLoader.load(
		terrain_stage_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaTerrainDefinition
	var referenced_path := restaged.unit_effect.resource_path \
		if restaged != null and restaged.unit_effect != null else ""
	if restaged == null or referenced_path != effect_path \
			or terrain_fingerprint(restaged) != expected_terrain \
			or effect_fingerprint(restaged.unit_effect) != expected_effect:
		return {"ok": false, "error": "terrain_restage_verify_failed"}
	var prepared_states := transaction.get("prepared_states", {}) as Dictionary
	prepared_states[terrain_path] = _file_state(terrain_stage_path)
	transaction["prepared_states"] = prepared_states
	_register_owned_stage_states(transaction, {
		terrain_stage_path: prepared_states[terrain_path],
	})
	if not _write_journal(transaction, &"APPLYING", {
		"phase": "terrain_restaged_after_effect_commit",
		"target": terrain_path,
		"plan": save_plan,
	}):
		return {"ok": false, "error": "terrain_restage_journal_failed"}
	return {"ok": true}


static func _preserve_target_uid(
		stage_path: String,
		target_state: Dictionary
	) -> Dictionary:
	if not bool(target_state.get("exists", false)):
		return {"ok": true, "uid": str(_file_state(stage_path).get("uid", ""))}
	var uid_text := str(target_state.get("uid", ""))
	if uid_text.is_empty():
		# Les catalogues historiques sans header uid= restent publiables. Le
		# staging reçoit alors son propre UID de ResourceSaver ; il est consigné
		# dans prepared_states et devient le nouvel UID canonique après commit.
		var generated_uid := str(_file_state(stage_path).get("uid", ""))
		return {
			"ok": true,
			"uid": generated_uid,
			"policy": "generated_for_legacy_uidless_target" \
				if not generated_uid.is_empty() else "legacy_uidless_preserved",
		}
	var uid := ResourceUID.text_to_id(uid_text)
	if uid == ResourceUID.INVALID_ID:
		return {"ok": false, "error": "invalid_canonical_uid", "uid": uid_text}
	var error := ResourceSaver.set_uid(stage_path, uid)
	var actual_uid := str(_file_state(stage_path).get("uid", ""))
	var serialized := {"ok": actual_uid == uid_text}
	if actual_uid != uid_text:
		serialized = _write_text_resource_uid(stage_path, uid_text)
		actual_uid = str(_file_state(stage_path).get("uid", ""))
	return {
		"ok": bool(serialized.get("ok", false)) and actual_uid == uid_text,
		"uid": actual_uid,
		"expected_uid": uid_text,
		"set_uid_code": error,
		"serialized_uid": serialized,
	}


static func _write_text_resource_uid(path: String, uid_text: String) -> Dictionary:
	if path.is_empty() or not path.ends_with(".tres") \
			or ResourceUID.text_to_id(uid_text) == ResourceUID.INVALID_ID \
			or uid_text.contains("\""):
		return {"ok": false, "error": "invalid_serialized_uid_request"}
	var contents := FileAccess.get_file_as_string(path)
	var line_end := contents.find("\n")
	if contents.is_empty() or line_end < 0:
		return {"ok": false, "error": "invalid_text_resource"}
	var header := contents.substr(0, line_end)
	if not header.trim_suffix("\r").begins_with("[gd_resource"):
		return {"ok": false, "error": "invalid_text_resource_header"}
	var marker := " uid=\""
	var marker_index := header.find(marker)
	var rewritten_header := header
	if marker_index >= 0:
		var value_start := marker_index + marker.length()
		var value_end := header.find("\"", value_start)
		if value_end <= value_start \
				or header.find(marker, value_end + 1) >= 0:
			return {"ok": false, "error": "ambiguous_text_resource_uid"}
		rewritten_header = (
			header.substr(0, value_start)
			+ uid_text
			+ header.substr(value_end)
		)
	else:
		if header.find("uid=\"") >= 0:
			return {"ok": false, "error": "malformed_text_resource_uid"}
		var bracket_index := header.rfind("]")
		if bracket_index < 0:
			return {"ok": false, "error": "unterminated_text_resource_header"}
		rewritten_header = header.insert(
			bracket_index, " uid=\"%s\"" % uid_text
		)
	var rewritten := rewritten_header + contents.substr(line_end)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "serialized_uid_open_failed"}
	file.store_string(rewritten)
	file.flush()
	file.close()
	var bytes_match := FileAccess.get_file_as_string(path) == rewritten
	var actual_uid := str(_file_state(path).get("uid", ""))
	return {
		"ok": bytes_match and actual_uid == uid_text,
		"error": "" if bytes_match and actual_uid == uid_text \
			else "serialized_uid_verification_failed",
		"actual_uid": actual_uid,
	}


static func _sync_uid_mapping(path: String, state: Dictionary) -> bool:
	if not bool(state.get("exists", false)):
		return true
	var uid_text := str(state.get("uid", ""))
	if uid_text.is_empty():
		return _resource_uid(path) == ResourceUID.INVALID_ID
	var uid := ResourceUID.text_to_id(uid_text)
	if uid == ResourceUID.INVALID_ID:
		return false
	if ResourceUID.has_id(uid):
		ResourceUID.set_id(uid, path)
	else:
		ResourceUID.add_id(uid, path)
	return _resource_uid(path) == uid \
		and ResourceUID.get_id_path(uid) == path


static func _clear_owned_uid_mapping(
		path: String,
		owned_state: Dictionary,
		restored_state: Dictionary
	) -> bool:
	var owned_uid_text := str(owned_state.get("uid", ""))
	var restored_uid_text := str(restored_state.get("uid", ""))
	if owned_uid_text.is_empty() or owned_uid_text == restored_uid_text:
		return true
	var owned_uid := ResourceUID.text_to_id(owned_uid_text)
	if owned_uid == ResourceUID.INVALID_ID:
		return false
	if ResourceUID.has_id(owned_uid) \
			and ResourceUID.get_id_path(owned_uid) == path:
		ResourceUID.remove_id(owned_uid)
	return not ResourceUID.has_id(owned_uid) \
		or ResourceUID.get_id_path(owned_uid) != path


static func _release_uid_mapping_for_commit(
		target_path: String,
		stage_path: String,
		stage_state: Dictionary
	) -> bool:
	var uid_text := str(stage_state.get("uid", ""))
	if uid_text.is_empty():
		return true
	var uid := ResourceUID.text_to_id(uid_text)
	if uid == ResourceUID.INVALID_ID:
		return false
	if not ResourceUID.has_id(uid):
		return true
	var mapped_path := ResourceUID.get_id_path(uid)
	if mapped_path not in [target_path, stage_path, ""]:
		return false
	ResourceUID.remove_id(uid)
	return not ResourceUID.has_id(uid)


static func _prepare_journal(
		transaction: Dictionary,
		save_plan: Dictionary,
		target_stages: Dictionary,
		stage_paths: Dictionary,
		opening_state: Dictionary
	) -> bool:
	var prepared_states := {}
	for target_value in target_stages:
		var target := str(target_value)
		var stage_path := str(target_stages[target_value])
		var stage_state := _file_state(stage_path)
		if not bool(stage_state.get("exists", false)):
			return false
		prepared_states[target] = stage_state
	transaction["prepared_states"] = prepared_states
	transaction["original_states"] = (
		opening_state.get("files", {}) as Dictionary
	).duplicate(true)
	transaction["stage_paths"] = stage_paths.duplicate(true)
	transaction["targets"] = (save_plan.get(
		"write_order", PackedStringArray()
	) as PackedStringArray).duplicate()
	return _write_journal(transaction, &"PREPARED", {"plan": save_plan})


static func _mark_target_touched(
		transaction: Dictionary,
		target: String,
		save_plan: Dictionary
	) -> bool:
	var touched := transaction.get("touched", PackedStringArray()) as PackedStringArray
	if not touched.has(target):
		touched.append(target)
	transaction["touched"] = touched
	return _write_journal(transaction, &"APPLYING", {
		"phase": "before_replace",
		"target": target,
		"plan": save_plan,
	})


static func _mark_target_committed(
		transaction: Dictionary,
		target: String,
		save_plan: Dictionary
	) -> bool:
	var prepared_states := transaction.get("prepared_states", {}) as Dictionary
	var expected := prepared_states.get(target, {}) as Dictionary
	var actual := _file_state(target)
	if expected.is_empty() or actual != expected \
			or not _sync_uid_mapping(target, expected):
		return false
	var committed_states := transaction.get("committed_states", {}) as Dictionary
	committed_states[target] = actual
	transaction["committed_states"] = committed_states
	return _write_journal(transaction, &"APPLYING", {
		"phase": "after_replace",
		"target": target,
		"plan": save_plan,
	})


static func _write_journal(
		transaction: Dictionary,
		status: StringName,
		details
	) -> bool:
	var directory := str(transaction.get("directory", ""))
	if not _safe_user_directory(directory) \
			or not DirAccess.dir_exists_absolute(
				ProjectSettings.globalize_path(directory)
			):
		return false
	var sequence := int(transaction.get("journal_sequence", 0)) + 1
	var journal := {
		"schema_version": 1,
		"transaction_id": str(transaction.get("id", "")),
		"directory": directory,
		"transaction_root": str(transaction.get("transaction_root", "")),
		"sequence": sequence,
		"status": str(status),
		"created_at": Time.get_datetime_string_from_system(),
		"allowed_roots": transaction.get("allowed_roots", PackedStringArray()),
		"targets": transaction.get("targets", PackedStringArray()),
		"backups": (transaction.get("backups", {}) as Dictionary).duplicate(true),
		"backup_states": (
			transaction.get("backup_states", {}) as Dictionary
		).duplicate(true),
		"absent": transaction.get("absent", PackedStringArray()),
		"prepared_states": (
			transaction.get("prepared_states", {}) as Dictionary
		).duplicate(true),
		"original_states": (
			transaction.get("original_states", {}) as Dictionary
		).duplicate(true),
		"committed_states": (
			transaction.get("committed_states", {}) as Dictionary
		).duplicate(true),
		"renamed_targets": transaction.get(
			"renamed_targets", PackedStringArray()
		),
		"rename_intents": (
			transaction.get("rename_intents", {}) as Dictionary
		).duplicate(true),
		"previous_paths": (
			transaction.get("previous_paths", {}) as Dictionary
		).duplicate(true),
		"previous_states": (
			transaction.get("previous_states", {}) as Dictionary
		).duplicate(true),
		"stage_owned_states": (
			transaction.get("stage_owned_states", {}) as Dictionary
		).duplicate(true),
		"touched": transaction.get("touched", PackedStringArray()),
		"stage_paths": (
			transaction.get("stage_paths", {}) as Dictionary
		).duplicate(true),
		"details": details,
	}
	var journal_path := directory.path_join("journal_%06d.json" % sequence)
	var file := FileAccess.open(journal_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(journal, "  "))
	file.flush()
	file.close()
	var verified := _read_json(journal_path)
	if not bool(verified.get("ok", false)) \
			or int((verified.get("data", {}) as Dictionary).get(
				"sequence", -1
			)) != sequence:
		return false
	transaction["journal_sequence"] = sequence
	transaction["status"] = str(status)
	return true


static func _verify_written(
		terrain_path: String,
		effect_path: String,
		expected_terrain: String,
		expected_effect: String,
		writes_effect: bool,
		expected_states := {}
	) -> Dictionary:
	var effect: TerrainEffectData = null
	if writes_effect:
		effect = ResourceLoader.load(
			effect_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as TerrainEffectData
	var terrain := ResourceLoader.load(
		terrain_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaTerrainDefinition
	var actual_effect := effect_fingerprint(effect)
	var actual_terrain := terrain_fingerprint(terrain)
	var referenced_effect_path := terrain.unit_effect.resource_path \
		if terrain != null and terrain.unit_effect != null else ""
	var reference_ok := referenced_effect_path \
		== (effect_path if writes_effect else "")
	var referenced_effect_ok := not writes_effect or (
		terrain != null and terrain.unit_effect != null \
		and effect_fingerprint(terrain.unit_effect) == expected_effect
	)
	var file_states_ok := true
	for target_value in expected_states:
		var target := str(target_value)
		if _file_state(target) != (expected_states[target_value] as Dictionary):
			file_states_ok = false
			break
	return {
		"ok": (effect != null or not writes_effect) and terrain != null \
			and reference_ok and referenced_effect_ok \
			and actual_effect == expected_effect \
			and actual_terrain == expected_terrain and file_states_ok,
		"expected_effect": expected_effect,
		"actual_effect": actual_effect,
		"expected_terrain": expected_terrain,
		"actual_terrain": actual_terrain,
		"referenced_effect_path": referenced_effect_path,
		"reference_ok": reference_ok,
		"referenced_effect_ok": referenced_effect_ok,
		"file_states_ok": file_states_ok,
	}


static func _rollback_failure(
		step: String,
		message: String,
		plan_value: Dictionary,
		transaction: Dictionary,
		stage_paths: Dictionary,
		applied: PackedStringArray,
		details := {}
	) -> Dictionary:
	var rollback := _rollback(transaction)
	var cleanup := _cleanup_stages(stage_paths, transaction)
	ArenaCatalogService.reset_cache()
	var rollback_status := &"ROLLED_BACK"
	if not bool(rollback.get("ok", false)) or not bool(cleanup.get("ok", false)):
		var rollback_conflicts := rollback.get("conflicts", []) as Array
		var cleanup_conflicts := cleanup.get("conflicts", []) as Array
		rollback_status = &"ROLLBACK_CONFLICT" \
			if not rollback_conflicts.is_empty() or not cleanup_conflicts.is_empty() \
			else &"ROLLBACK_FAILED"
	var journal_ok := _close_transaction(transaction, rollback_status, {
		"step": step,
		"plan": plan_value,
		"applied": applied,
		"rollback": rollback,
		"cleanup": cleanup,
		"details": details,
	})
	var terminal_status := rollback_status if journal_ok else &"ROLLBACK_JOURNAL_FAILED"
	return {
		"ok": false,
		"step": step,
		"error": message,
		"plan": plan_value,
		"rolled_back": bool(rollback.get("ok", false)) \
			and bool(cleanup.get("ok", false)),
		"rollback_status": terminal_status,
		"status": terminal_status,
		"journal_ok": journal_ok,
		"transaction_terminal": journal_ok,
		"rollback": rollback,
		"cleanup": cleanup,
	}


static func _rollback(transaction: Dictionary) -> Dictionary:
	var failed := PackedStringArray()
	var conflicts: Array[Dictionary] = []
	var backups := transaction.get("backups", {}) as Dictionary
	var backup_states := transaction.get("backup_states", {}) as Dictionary
	var prepared_states := transaction.get("prepared_states", {}) as Dictionary
	var committed_states := transaction.get("committed_states", {}) as Dictionary
	var renamed_targets := transaction.get(
		"renamed_targets", PackedStringArray()
	) as PackedStringArray
	var rename_intents := transaction.get("rename_intents", {}) as Dictionary
	for target_value in backups:
		var target := str(target_value)
		var backup := str(backups[target_value])
		var backup_state := backup_states.get(target, _file_state(backup)) as Dictionary
		var owned_state := committed_states.get(
			target, prepared_states.get(target, {})
		) as Dictionary
		var current_state := _file_state(target)
		if current_state == backup_state:
			if not _clear_owned_uid_mapping(target, owned_state, backup_state) \
					or not _sync_uid_mapping(target, backup_state):
				failed.append(target)
			continue
		if not bool(current_state.get("exists", false)):
			if _rename_may_have_committed(
					committed_states, renamed_targets, rename_intents, target
				):
				conflicts.append({
					"path": target,
					"current": current_state,
					"transaction_state": owned_state,
					"backup": backup,
					"message": (
						"La cible a été supprimée après notre commit ; le backup n'a pas été recréé."
					),
				})
				continue
			var quarantined_original := _restore_quarantined_original(
				transaction, target, backup_state
			)
			if bool(quarantined_original.get("found", false)):
				if not bool(quarantined_original.get("ok", false)):
					if bool(quarantined_original.get("conflict", false)):
						conflicts.append(quarantined_original)
					else:
						failed.append(target)
				elif not _sync_uid_mapping(target, backup_state):
					failed.append(target)
				continue
		if bool(current_state.get("exists", false)) \
				and (owned_state.is_empty() or current_state != owned_state):
			conflicts.append({
				"path": target,
				"current": current_state,
				"transaction_state": owned_state,
				"backup": backup,
				"message": (
					"Le fichier a été modifié après notre écriture ; le backup "
					+ "est conservé pour récupération manuelle."
				),
			})
			continue
		if not bool(backup_state.get("exists", false)) \
				or not FileAccess.file_exists(backup) \
				or _file_state(backup) != backup_state:
			failed.append(target)
			continue
		var restored := _replace_owned_with_backup(
			transaction, target, owned_state, backup, backup_state
		)
		if not bool(restored.get("ok", false)):
			if bool(restored.get("conflict", false)):
				conflicts.append(restored)
			else:
				failed.append(target)
			continue
		if _file_state(target) != backup_state \
				or not _clear_owned_uid_mapping(
				target, owned_state, backup_state
			) \
				or not _sync_uid_mapping(target, backup_state):
			failed.append(target)
	for target in transaction.get("absent", PackedStringArray()) as PackedStringArray:
		var current_state := _file_state(target)
		if not bool(current_state.get("exists", false)):
			if _path_occupied(target):
				conflicts.append({
					"path": target,
					"current": {"exists": false, "directory": true},
					"message": "Un dossier externe occupe la cible ; il est préservé.",
				})
				continue
			if _rename_may_have_committed(
					committed_states, renamed_targets, rename_intents, target
				):
				conflicts.append({
					"path": target,
					"current": current_state,
					"transaction_state": committed_states.get(
						target, prepared_states.get(target, {})
					),
					"backup": "",
					"message": "La cible créée a été supprimée après notre commit.",
				})
			continue
		var owned_state := committed_states.get(
			target, prepared_states.get(target, {})
		) as Dictionary
		if owned_state.is_empty() or current_state != owned_state:
			conflicts.append({
				"path": target,
				"current": current_state,
				"transaction_state": owned_state,
				"backup": "",
				"message": (
					"Un nouveau fichier externe occupe la cible ; il n'a pas été supprimé."
				),
			})
			continue
		var quarantine_path := _rollback_neighbor_path(
			target, transaction, "created"
		)
		_register_stage_path(
			transaction, "rollback_created_" + target.sha256_text().left(12),
			quarantine_path, owned_state
		)
		var removed := _move_verified(
			target, quarantine_path, owned_state,
			transaction.get("before_rollback_quarantine_hook", Callable()) as Callable
		)
		if not bool(removed.get("ok", false)):
			if bool(removed.get("conflict", false)):
				removed["path"] = target
				removed["message"] = "La cible créée a changé pendant son déplacement ; elle a été préservée."
				conflicts.append(removed)
			else:
				failed.append(target)
			continue
		_register_owned_stage_states(transaction, {quarantine_path: owned_state})
		if _path_occupied(target):
			conflicts.append({
				"path": target,
				"current": _file_state(target),
				"transaction_state": owned_state,
				"preserved_studio_path": quarantine_path,
				"message": "Une cible externe est apparue pendant le rollback ; elle est préservée.",
			})
		else:
			_clear_owned_uid_mapping(target, owned_state, {"exists": false})
	for target in transaction.get("absent", PackedStringArray()) as PackedStringArray:
		if FileAccess.file_exists(target) and not _conflict_has_path(conflicts, target):
			failed.append(target)
	return {
		"ok": failed.is_empty() and conflicts.is_empty(),
		"failed_paths": failed,
		"conflicts": conflicts,
		"backups": backups.duplicate(true),
	}


static func _restore_quarantined_original(
		transaction: Dictionary,
		target: String,
		backup_state: Dictionary
	) -> Dictionary:
	var previous_paths := transaction.get("previous_paths", {}) as Dictionary
	if not previous_paths.has(target):
		return {"ok": false, "found": false}
	var previous_path := str(previous_paths[target])
	if not FileAccess.file_exists(previous_path):
		return {"ok": false, "found": false}
	var previous_state := _file_state(previous_path)
	if previous_state != backup_state:
		return {
			"ok": false, "found": true, "conflict": true,
			"path": target,
			"preserved_path": previous_path,
			"current": previous_state,
			"expected": backup_state,
			"message": "L'original déplacé a changé ; il est conservé sans écrasement.",
		}
	var restored := _move_verified(previous_path, target, backup_state)
	restored["found"] = true
	restored["path"] = target
	return restored


static func _replace_owned_with_backup(
		transaction: Dictionary,
		target: String,
		owned_state: Dictionary,
		backup_path: String,
		backup_state: Dictionary
	) -> Dictionary:
	var restore_path := _verified_restore_neighbor(
		transaction, target, backup_path, backup_state
	)
	if restore_path.is_empty():
		return {"ok": false, "path": target, "error": "restore_stage_failed"}
	var quarantine_path := _rollback_neighbor_path(
		target, transaction, "owned"
	)
	_register_stage_path(
		transaction, "rollback_owned_" + target.sha256_text().left(12),
		quarantine_path, owned_state
	)
	var quarantined := _move_verified(
		target, quarantine_path, owned_state,
		transaction.get("before_rollback_quarantine_hook", Callable()) as Callable
	)
	if not bool(quarantined.get("ok", false)):
		quarantined["path"] = target
		quarantined["message"] = (
			"La cible a changé pendant son déplacement de rollback ; son contenu a été préservé."
		)
		return quarantined
	_register_owned_stage_states(transaction, {quarantine_path: owned_state})
	var installed := _move_verified(restore_path, target, backup_state)
	if bool(installed.get("ok", false)):
		return {"ok": true, "path": target, "quarantine": quarantine_path}
	var studio_restored := {}
	if not _path_occupied(target):
		studio_restored = _move_verified(quarantine_path, target, owned_state)
	return installed.merged({
		"path": target,
		"studio_state_restored": studio_restored,
		"preserved_studio_path": quarantine_path,
	}, true)


static func _verified_restore_neighbor(
		transaction: Dictionary,
		target: String,
		backup_path: String,
		backup_state: Dictionary
	) -> String:
	var previous_paths := transaction.get("previous_paths", {}) as Dictionary
	var previous_path := str(previous_paths.get(target, ""))
	if not previous_path.is_empty() and _file_state(previous_path) == backup_state:
		return previous_path
	var restore_path := _rollback_neighbor_path(target, transaction, "restore")
	if _path_occupied(restore_path):
		return ""
	var error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(backup_path),
		ProjectSettings.globalize_path(restore_path)
	)
	if FileAccess.file_exists(restore_path):
		_register_stage_path(
			transaction, "restore_" + target.sha256_text().left(12),
			restore_path, _file_state(restore_path)
		)
	if error != OK or _file_state(restore_path) != backup_state:
		return ""
	return restore_path


static func _rollback_neighbor_path(
		target: String,
		transaction: Dictionary,
		kind: String
	) -> String:
	return "%s.terrain_type_%s_%s.tres" % [
		target.get_basename(), kind, str(transaction.get("id", "")).sha256_text().left(16),
	]


static func _cleanup_stages(
		stage_paths: Dictionary,
		transaction := {}
	) -> Dictionary:
	var failed := PackedStringArray()
	var conflicts: Array[Dictionary] = []
	var all_paths := stage_paths.duplicate(true)
	for key in (transaction.get("stage_paths", {}) as Dictionary):
		all_paths[key] = (transaction.get("stage_paths", {}) as Dictionary)[key]
	var owned_states := transaction.get("stage_owned_states", {}) as Dictionary
	var previous_paths := transaction.get("previous_paths", {}) as Dictionary
	var previous_states := transaction.get("previous_states", {}) as Dictionary
	var committed_states := transaction.get("committed_states", {}) as Dictionary
	var prepared_states := transaction.get("prepared_states", {}) as Dictionary
	var visited := PackedStringArray()
	for path_value in all_paths.values():
		var path := str(path_value)
		if path.is_empty() or visited.has(path):
			continue
		visited.append(path)
		var current := _file_state(path)
		if not bool(current.get("exists", false)):
			if _path_occupied(path):
				conflicts.append({
					"path": path,
					"current": {"exists": false, "directory": true},
					"owned": owned_states.get(path, {}),
					"message": "Un dossier externe occupe le temporaire ; il est conservé.",
				})
			continue
		var owned := owned_states.get(path, {}) as Dictionary
		if owned.is_empty() or current != owned:
			conflicts.append({
				"path": path,
				"current": current,
				"owned": owned,
				"message": "Le temporaire a changé ; il est conservé.",
			})
			continue
		var previous_target := ""
		for target_value in previous_paths:
			if str(previous_paths[target_value]) == path:
				previous_target = str(target_value)
				break
		if not previous_target.is_empty():
			var target_state := _file_state(previous_target)
			var original_state := previous_states.get(
				previous_target, {}
			) as Dictionary
			var studio_state := committed_states.get(
				previous_target, prepared_states.get(previous_target, {})
			) as Dictionary
			if target_state != original_state and target_state != studio_state:
				conflicts.append({
					"path": path,
					"target": previous_target,
					"current": current,
					"target_state": target_state,
					"owned": owned,
					"message": "L'original déplacé est conservé tant que la cible est externe.",
				})
				continue
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
			failed.append(path)
		elif bool(_file_state(path).get("exists", false)):
			failed.append(path)
	return {
		"ok": failed.is_empty() and conflicts.is_empty(),
		"failed_paths": failed,
		"conflicts": conflicts,
	}


static func _reload_restored_cache(
		terrain_path: String,
		effect_path: String,
		writes_effect: bool
	) -> void:
	if writes_effect and FileAccess.file_exists(effect_path):
		ResourceLoader.load(
			effect_path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP
		)
	if FileAccess.file_exists(terrain_path):
		ResourceLoader.load(
			terrain_path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP
		)
	ArenaCatalogService.reset_cache()


static func _blocked(save_plan: Dictionary) -> Dictionary:
	var blocking := save_plan.get("blocking", PackedStringArray()) as PackedStringArray
	return {
		"ok": false,
		"step": "BLOCKED",
		"error": blocking[0] if not blocking.is_empty() \
			else "Sauvegarde refusee.",
		"plan": save_plan,
		"rolled_back": false,
	}


static func _failure(
		step: String,
		message: String,
		plan_value = null,
		transaction := {},
		details := {}
	) -> Dictionary:
	var journal_incomplete := step == "TRANSACTION_JOURNAL"
	return {
		"ok": false,
		"step": step,
		"status": &"TRANSACTION_JOURNAL_FAILED" if journal_incomplete \
			else StringName(step),
		"transaction_terminal": not journal_incomplete,
		"error": message,
		"plan": plan_value,
		"transaction": transaction,
		"details": details,
		"rolled_back": false,
	}


static func _close_transaction(
		transaction: Dictionary,
		status: StringName,
		details
	) -> bool:
	var directory := str(transaction.get("directory", ""))
	if directory.is_empty():
		return false
	if str(transaction.get("failure_step", "")) == "close_journal":
		return false
	var journal_ok := _write_journal(transaction, status, details)
	var report := {
		"schema_version": 1,
		"transaction_id": transaction.get("id", ""),
		"status": str(status),
		"created_at": Time.get_datetime_string_from_system(),
		"backups": (transaction.get("backups", {}) as Dictionary).duplicate(true),
		"absent": transaction.get("absent", PackedStringArray()),
		"details": details,
	}
	var file := FileAccess.open(
		directory.path_join("transaction_report.json"), FileAccess.WRITE
	)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.flush()
		file.close()
	return journal_ok


static func _clone_terrain(
		source: ArenaTerrainDefinition
	) -> ArenaTerrainDefinition:
	if source == null:
		return null
	return source.duplicate(true) as ArenaTerrainDefinition


static func _clone_effect(source: TerrainEffectData) -> TerrainEffectData:
	if source == null:
		return null
	return source.duplicate(true) as TerrainEffectData


static func _resource_path(resource: Resource) -> String:
	return resource.resource_path if resource != null else ""


static func _storage_snapshot(
		resource: Resource,
		overrides := {}
	) -> Dictionary:
	var properties := {}
	var names := PackedStringArray()
	for property_value in resource.get_property_list():
		var property := property_value as Dictionary
		var property_name := str(property.get("name", ""))
		if property_name in ["resource_path", "script"] \
				or not (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE):
			continue
		names.append(property_name)
	names.sort()
	for property_name in names:
		properties[property_name] = _canonical_variant(
			overrides.get(property_name, resource.get(property_name))
		)
	var metadata := {}
	var metadata_names := PackedStringArray()
	for meta_name in resource.get_meta_list():
		metadata_names.append(str(meta_name))
	metadata_names.sort()
	for meta_name in metadata_names:
		metadata[meta_name] = _canonical_variant(
			resource.get_meta(StringName(meta_name))
		)
	return {
		"class": resource.get_class(),
		"resource_name": resource.resource_name,
		"properties": properties,
		"metadata": metadata,
	}


static func _canonical_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary_result := {}
		var keys := PackedStringArray()
		for key in value:
			keys.append(str(key))
		keys.sort()
		for key in keys:
			dictionary_result[key] = _canonical_variant(
				_dictionary_value(value, key)
			)
		return dictionary_result
	if value is Array:
		var array_result: Array = []
		for item in value:
			array_result.append(_canonical_variant(item))
		return array_result
	if value is StringName:
		return str(value)
	if value is NodePath:
		return str(value)
	if value is Resource:
		if not value.resource_path.is_empty():
			return value.resource_path
		return _storage_snapshot(value)
	if value is Vector2 or value is Vector2i \
			or value is Vector3 or value is Vector3i \
			or value is Vector4 or value is Vector4i \
			or value is Rect2 or value is Rect2i \
			or value is Transform2D or value is Transform3D \
			or value is Basis or value is Quaternion \
			or value is Plane or value is AABB \
			or value is Color:
		return var_to_str(value)
	return value


static func _dictionary_value(dictionary: Dictionary, text_key: String) -> Variant:
	if dictionary.has(text_key):
		return dictionary[text_key]
	var string_name := StringName(text_key)
	if dictionary.has(string_name):
		return dictionary[string_name]
	for key in dictionary:
		if str(key) == text_key:
			return dictionary[key]
	return null


static func _conflict_has_path(conflicts: Array[Dictionary], path: String) -> bool:
	for conflict in conflicts:
		if str(conflict.get("path", "")) == path:
			return true
	return false


static func _rename_may_have_committed(
		committed_states: Dictionary,
		renamed_targets: PackedStringArray,
		rename_intents: Dictionary,
		target: String
	) -> bool:
	if committed_states.has(target) or renamed_targets.has(target):
		return true
	if not rename_intents.has(target):
		return false
	# Le journal avant rename nomme le voisin. S'il existe encore, le rename
	# n'a pas eu lieu et l'absence cible vient de notre fenêtre remove→rename.
	# S'il a disparu, on suppose conservativement que le rename a réussi puis
	# qu'un tiers a supprimé la cible : ne jamais recréer le backup par-dessus.
	return not FileAccess.file_exists(str(rename_intents[target]))


static func _is_transaction_neighbor(path: String) -> bool:
	var file_name := path.get_file()
	for marker in [
		".terrain_type_commit_",
		".terrain_type_previous_",
		".terrain_type_owned_",
		".terrain_type_created_",
		".terrain_type_restore_",
	]:
		if file_name.contains(marker):
			return true
	return false


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "missing"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "open_failed"}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"ok": false, "error": "invalid_json"}
	return {"ok": true, "data": parsed as Dictionary}


static func _write_json_verified(path: String, data: Dictionary) -> bool:
	var payload := JSON.stringify(data, "  ")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(payload)
	file.flush()
	file.close()
	var stored := FileAccess.get_file_as_string(path)
	if stored != payload:
		return false
	var parsed := _read_json(path)
	return bool(parsed.get("ok", false))


static func _remove_user_directory_tree(path: String, allowed_root: String) -> bool:
	if not _safe_user_directory(path) or not _safe_user_directory(allowed_root) \
			or path == allowed_root or not path.begins_with(allowed_root + "/"):
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var access := DirAccess.open(absolute)
	if access == null:
		return true
	for child_directory in access.get_directories():
		if not _remove_user_directory_tree(
				path.path_join(child_directory), allowed_root
			):
			return false
	for file_name in access.get_files():
		if DirAccess.remove_absolute(absolute.path_join(file_name)) != OK:
			return false
	return DirAccess.remove_absolute(absolute) == OK


static func _latest_journal(directory: String) -> Dictionary:
	if not _safe_user_directory(directory):
		return {"ok": false, "error": "unsafe_directory"}
	var access := DirAccess.open(ProjectSettings.globalize_path(directory))
	if access == null:
		return {"ok": false, "error": "unreadable_directory"}
	var journal_names := PackedStringArray()
	for file_name in access.get_files():
		if file_name.begins_with("journal_") and file_name.ends_with(".json"):
			journal_names.append(file_name)
	journal_names.sort()
	for index in range(journal_names.size() - 1, -1, -1):
		var parsed := _read_json(directory.path_join(journal_names[index]))
		if bool(parsed.get("ok", false)):
			return parsed
	return {"ok": false, "error": "no_valid_journal"}


static func _recover_journal(
		journal: Dictionary,
		directory: String,
		options: Dictionary
	) -> Dictionary:
	if str(journal.get("directory", "")) != directory:
		return {
			"ok": false, "directory": directory,
			"error": "journal_directory_mismatch",
		}
	var roots := _allowed_roots(options)
	var targets := PackedStringArray()
	for target_value in journal.get("targets", []):
		var target := str(target_value)
		if not _safe_path(target, roots):
			return {
				"ok": false, "directory": directory,
				"error": "unsafe_recovery_target", "target": target,
			}
		targets.append(target)
	var backups := journal.get("backups", {}) as Dictionary
	for target_value in backups:
		var target := str(target_value)
		var backup := str(backups[target_value])
		if not targets.has(target) or _has_unsafe_segments(backup) \
				or backup != backup.simplify_path() \
				or not backup.begins_with(directory + "/"):
			return {
				"ok": false, "directory": directory,
				"error": "unsafe_recovery_backup", "backup": backup,
			}
	for absent_value in journal.get("absent", []):
		var absent_target := str(absent_value)
		if not targets.has(absent_target):
			return {
				"ok": false, "directory": directory,
				"error": "unsafe_absent_recovery_target",
				"target": absent_target,
			}
	var stage_paths := journal.get("stage_paths", {}) as Dictionary
	for stage_value in stage_paths.values():
		var stage_path := str(stage_value)
		var in_transaction := stage_path.begins_with(directory + "/") \
			and stage_path == stage_path.simplify_path() \
			and not _has_unsafe_segments(stage_path)
		var safe_neighbor := _safe_path(stage_path, roots) \
			and _is_transaction_neighbor(stage_path) \
			and not targets.has(stage_path)
		if not in_transaction and not safe_neighbor:
			return {
				"ok": false, "directory": directory,
				"error": "unsafe_recovery_stage", "stage": stage_path,
			}
	var rename_intents := journal.get("rename_intents", {}) as Dictionary
	for intent_target_value in rename_intents:
		var intent_target := str(intent_target_value)
		var neighbor := str(rename_intents[intent_target_value])
		if not targets.has(intent_target) \
				or not stage_paths.values().has(neighbor) \
				or not neighbor.get_file().contains(".terrain_type_commit_"):
			return {
				"ok": false, "directory": directory,
				"error": "unsafe_rename_intent", "target": intent_target,
			}
	var previous_paths := journal.get("previous_paths", {}) as Dictionary
	for previous_target_value in previous_paths:
		var previous_target := str(previous_target_value)
		var previous_path := str(previous_paths[previous_target_value])
		if not targets.has(previous_target) \
				or not stage_paths.values().has(previous_path) \
				or not previous_path.get_file().contains(".terrain_type_previous_"):
			return {
				"ok": false, "directory": directory,
				"error": "unsafe_previous_path", "target": previous_target,
			}
	var stage_owned_states := journal.get("stage_owned_states", {}) as Dictionary
	for owned_stage_value in stage_owned_states:
		var owned_stage := str(owned_stage_value)
		if not stage_paths.values().has(owned_stage):
			return {
				"ok": false, "directory": directory,
				"error": "untracked_owned_stage", "stage": owned_stage,
			}
	var transaction := {
		"ok": true,
		"id": str(journal.get("transaction_id", "")),
		"directory": directory,
		"transaction_root": str(options.get(
			"transaction_root", TRANSACTION_ROOT
		)).trim_suffix("/"),
		"allowed_roots": roots,
		"targets": targets,
		"backups": backups.duplicate(true),
		"backup_states": (
			journal.get("backup_states", {}) as Dictionary
		).duplicate(true),
		"absent": PackedStringArray(journal.get("absent", [])),
		"prepared_states": (
			journal.get("prepared_states", {}) as Dictionary
		).duplicate(true),
		"original_states": (
			journal.get("original_states", {}) as Dictionary
		).duplicate(true),
		"committed_states": (
			journal.get("committed_states", {}) as Dictionary
		).duplicate(true),
		"renamed_targets": PackedStringArray(journal.get(
			"renamed_targets", []
		)),
		"rename_intents": rename_intents.duplicate(true),
		"previous_paths": previous_paths.duplicate(true),
		"previous_states": (
			journal.get("previous_states", {}) as Dictionary
		).duplicate(true),
		"stage_owned_states": stage_owned_states.duplicate(true),
		"touched": PackedStringArray(journal.get("touched", [])),
		"stage_paths": stage_paths.duplicate(true),
		"journal_sequence": int(journal.get("sequence", 0)),
	}
	var rollback := _rollback(transaction)
	var cleanup := _cleanup_stages(stage_paths, transaction)
	var rollback_status := &"ROLLED_BACK"
	if not bool(rollback.get("ok", false)) or not bool(cleanup.get("ok", false)):
		var cleanup_conflicts := cleanup.get("conflicts", []) as Array
		rollback_status = &"ROLLBACK_CONFLICT" \
			if not (rollback.get("conflicts", []) as Array).is_empty() \
				or not cleanup_conflicts.is_empty() \
			else &"ROLLBACK_FAILED"
	var journal_ok := _close_transaction(transaction, rollback_status, {
		"automatic_recovery": true,
		"rollback": rollback,
		"cleanup": cleanup,
	})
	return {
		"ok": bool(rollback.get("ok", false)) \
			and bool(cleanup.get("ok", false)) and journal_ok,
		"directory": directory,
		"status": str(rollback_status) if journal_ok else "ROLLBACK_JOURNAL_FAILED",
		"rollback": rollback,
		"cleanup": cleanup,
		"journal_ok": journal_ok,
		"message": (
			"Transaction incomplète restaurée automatiquement."
			if bool(rollback.get("ok", false)) \
				and bool(cleanup.get("ok", false)) and journal_ok else
			"La restauration automatique n'a pas pu être terminée ; backups conservés."
		),
	}
