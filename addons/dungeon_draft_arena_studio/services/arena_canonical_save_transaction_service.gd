@tool
class_name ArenaCanonicalSaveTransactionService
extends RefCounted

## Sauvegarde canonique transactionnelle du Studio Terrain.
##
## Le bouton le plus simple suit desormais le meme contrat que la production :
## 1. validation, 2. detection de conflit externe, 3. plan des fichiers,
## 4. recuperation et sauvegardes de secours, 5. ecritures, 6. relecture sans
## cache, 7. verification des empreintes, 8. rollback complet en cas d'echec,
## 9. reouverture d'une working copy propre par l'appelant.
##
## La working copy n'est jamais modifiee avant qu'une ecriture verifiee ait
## reussi : les assets mis en attente sont materialises sur une copie de
## publication, et leurs nouveaux chemins ne sont reportes sur le document
## edite qu'apres la verification finale.

const TRANSACTION_ROOT := "user://dungeon_draft_studio/arena_save_transactions"


## Plan lisible avant toute ecriture.
static func plan(
		arena: ArenaDefinition,
		session: ArenaEditSession = null,
		options := {}
	) -> Dictionary:
	if arena == null:
		return {"ok": false, "error": "no_arena", "blocking": PackedStringArray([
			"Aucun terrain n'est ouvert.",
		])}
	var blocking := PackedStringArray()
	var report := options.get("validation") as ArenaValidationReport
	if report == null:
		report = ArenaValidator.validate(arena, false)
	if not report.is_valid():
		blocking.append(
			"%d problème(s) bloquant(s) : corrigez l'étape Vérifier." % report.error_count()
		)
	var conflict := session != null and session.has_external_conflict()
	if conflict:
		blocking.append(
			"Le fichier a changé en dehors du Studio. Rechargez-le avant d'écrire."
		)
	var writes_visual := session != null and session.source_is_visual \
		and not arena.source_visual_path.is_empty()
	var path := _target_path(arena, session, writes_visual)
	var creates := PackedStringArray()
	var modifies := PackedStringArray()
	if FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		modifies.append(path)
	else:
		creates.append(path)
	var assets := ArenaSerializer.plan_staged_visual_assets(arena)
	if not bool(assets.get("ok", false)):
		blocking.append(
			"Une image en attente est introuvable ou vient d'un dossier interdit."
		)
	for target in (assets.get("mapping", {}) as Dictionary).values():
		if FileAccess.file_exists(ProjectSettings.globalize_path(str(target))):
			modifies.append(str(target))
		else:
			creates.append(str(target))
	if session != null and session.source_path.is_empty() \
			and not writes_visual and ResourceLoader.exists(path):
		blocking.append(
			"Un terrain canonique utilise déjà cet identifiant : changez le nom."
		)
	return {
		"ok": blocking.is_empty(),
		"path": path,
		"writes_production_visual": writes_visual,
		"creates": creates,
		"modifies": modifies,
		"external_conflict": conflict,
		"validation": report,
		"blocking": blocking,
		"summary": "Écrire « %s » dans %s" % [arena.display_name, path],
	}


## Execute la sauvegarde. Retourne {ok, path, plan, rolled_back, error,
## message, asset_paths_applied}.
static func save(
		arena: ArenaDefinition,
		session: ArenaEditSession = null,
		options := {}
	) -> Dictionary:
	var save_plan := plan(arena, session, options)
	if not bool(save_plan.get("ok", false)):
		return {
			"ok": false,
			"error": str(save_plan.get("error", "blocked")),
			"plan": save_plan,
			"rolled_back": false,
			"message": _first_line(save_plan.get("blocking", PackedStringArray())),
		}
	var transaction := _open_transaction(arena)
	if not bool(transaction.get("ok", false)):
		return {
			"ok": false, "error": "transaction_directory_failed",
			"plan": save_plan, "rolled_back": false,
			"message": "Le dossier de transaction n'a pas pu être créé.",
		}
	var recovery_error := ArenaSerializer.save_recovery(arena, {
		"domain": &"arena", "status": "SAVE_TRANSACTION",
	})
	if recovery_error != OK:
		_close_transaction(transaction, &"RECOVERY_FAILED")
		return {
			"ok": false, "error": "recovery_failed", "plan": save_plan,
			"rolled_back": false,
			"message": "La copie de récupération n'a pas pu être créée : rien n'a été écrit.",
		}
	var touched := PackedStringArray()
	touched.append_array(save_plan.creates as PackedStringArray)
	touched.append_array(save_plan.modifies as PackedStringArray)
	if not _backup_files(transaction, touched):
		_close_transaction(transaction, &"BACKUP_FAILED")
		return {
			"ok": false, "error": "backup_failed", "plan": save_plan,
			"rolled_back": false,
			"message": "Les copies de secours n'ont pas pu être créées : rien n'a été écrit.",
		}
	var publish := _publication_copy(arena)
	if publish == null:
		_close_transaction(transaction, &"COPY_FAILED")
		return {
			"ok": false, "error": "publication_copy_failed", "plan": save_plan,
			"rolled_back": false,
			"message": "La copie de publication n'a pas pu être préparée.",
		}
	var materialized := ArenaSerializer.materialize_staged_visual_assets(publish, true)
	if not bool(materialized.get("ok", false)):
		_rollback(transaction, materialized.get("created", PackedStringArray()))
		_close_transaction(transaction, &"ASSET_MATERIALIZATION_FAILED", materialized)
		return {
			"ok": false, "error": "asset_materialization_failed", "plan": save_plan,
			"rolled_back": true,
			"message": "Les images n'ont pas pu être copiées : tout a été remis en état.",
		}
	var created_assets: PackedStringArray = materialized.get("created", PackedStringArray())
	if str(options.get("failure_step", "")) == "before_write":
		_rollback(transaction, created_assets)
		_close_transaction(transaction, &"INJECTED_BEFORE_WRITE")
		return {
			"ok": false, "error": "injected_before_write", "plan": save_plan,
			"rolled_back": true,
			"message": "Échec injecté avant écriture : tout a été remis en état.",
		}
	var path := str(save_plan.path)
	var write_error := ArenaSerializer.save_production_calibration(publish, path) \
		if bool(save_plan.writes_production_visual) \
		else _write_canonical(publish, path)
	if write_error != OK:
		_rollback(transaction, created_assets)
		_close_transaction(transaction, &"WRITE_FAILED", {"code": write_error})
		return {
			"ok": false, "error": "write_failed", "plan": save_plan,
			"rolled_back": true,
			"message": "L'écriture a échoué (%s) : tout a été remis en état." \
				% error_string(write_error),
		}
	var verified := _verify(publish, path, bool(save_plan.writes_production_visual))
	if str(options.get("failure_step", "")) == "after_write":
		verified = {"ok": false, "error": "injected_after_write"}
	if not bool(verified.get("ok", false)):
		_rollback(transaction, created_assets)
		_close_transaction(transaction, &"VERIFICATION_ROLLBACK", verified)
		return {
			"ok": false, "error": str(verified.get("error", "verification_failed")),
			"plan": save_plan, "rolled_back": true,
			"message": "La relecture ne correspond pas : tout a été remis en état.",
		}
	# La verification a reussi : seulement maintenant le document edite recoit
	# les chemins definitifs de ses images.
	var applied := _apply_asset_mapping(arena, materialized.get("mapping", {}))
	ArenaSerializer.remove_recovery(arena.arena_id)
	_close_transaction(transaction, &"COMMITTED", verified)
	return {
		"ok": true,
		"path": path,
		"plan": save_plan,
		"rolled_back": false,
		"published_snapshot": publish.to_snapshot().duplicate(true),
		"asset_paths_applied": applied,
		"created": save_plan.creates,
		"modified": save_plan.modifies,
		"message": "Brouillon enregistré et relu sans erreur : %s" % path,
	}


static func _target_path(
		arena: ArenaDefinition,
		session: ArenaEditSession,
		writes_visual: bool
	) -> String:
	if writes_visual:
		return arena.source_visual_path
	if session != null and session.source_path.begins_with("res://data/arenas/"):
		return session.source_path
	return ArenaSerializer.suggested_path(arena)


static func _write_canonical(arena: ArenaDefinition, path: String) -> Error:
	if not path.begins_with("res://") or not path.ends_with(".tres"):
		return ERR_INVALID_PARAMETER
	ArenaRuntimeBridge.sync_runtime_resources(arena)
	var absolute := ProjectSettings.globalize_path(path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		return directory_error
	return ResourceSaver.save(arena, path)


static func _verify(
		arena: ArenaDefinition,
		path: String,
		writes_visual: bool
	) -> Dictionary:
	if writes_visual:
		return {
			"ok": ArenaSerializer.production_visual_matches(arena, path),
			"error": "visual_calibration_mismatch",
		}
	var reloaded := ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ArenaDefinition
	if reloaded == null:
		return {"ok": false, "error": "reload_failed"}
	var expected := ArenaEditSession.fingerprint(arena.to_snapshot())
	var actual := ArenaEditSession.fingerprint(reloaded.to_snapshot())
	return {
		"ok": expected == actual,
		"error": "fingerprint_mismatch",
		"expected": expected,
		"actual": actual,
	}


static func _publication_copy(arena: ArenaDefinition) -> ArenaDefinition:
	var copy := ArenaDefinition.new()
	return copy if copy.restore_snapshot(arena.to_snapshot()) else null


static func _apply_asset_mapping(
		arena: ArenaDefinition,
		mapping: Dictionary
	) -> Dictionary:
	var applied := {}
	for property_name in mapping:
		var target := str(mapping[property_name])
		if str(arena.get(property_name)) == target:
			continue
		arena.set(property_name, target)
		applied[property_name] = target
	return applied


static func _open_transaction(arena: ArenaDefinition) -> Dictionary:
	var transaction_id := "%s_%d" % [
		ArenaDefinition.sanitize_id(str(arena.arena_id)), Time.get_ticks_usec(),
	]
	var directory := TRANSACTION_ROOT.path_join(transaction_id)
	if DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(directory)
		) != OK:
		return {"ok": false}
	return {
		"ok": true,
		"transaction_id": transaction_id,
		"directory": directory,
		"backups": {},
		"absent": PackedStringArray(),
	}


static func _backup_files(
		transaction: Dictionary,
		paths: PackedStringArray
	) -> bool:
	var directory := str(transaction.directory)
	var backups := transaction.backups as Dictionary
	var absent := transaction.absent as PackedStringArray
	var index := 0
	for path in paths:
		if backups.has(path) or absent.has(path):
			continue
		var absolute := ProjectSettings.globalize_path(path)
		if not FileAccess.file_exists(absolute):
			absent.append(path)
			continue
		var backup := directory.path_join("backup_%d_%s" % [index, path.get_file()])
		index += 1
		if DirAccess.copy_absolute(
				absolute, ProjectSettings.globalize_path(backup)
			) != OK:
			return false
		backups[path] = backup
	transaction["absent"] = absent
	return true


static func _rollback(
		transaction: Dictionary,
		created_assets: PackedStringArray
	) -> Dictionary:
	var restored := 0
	var removed := 0
	for path in created_assets:
		var absolute := ProjectSettings.globalize_path(str(path))
		if FileAccess.file_exists(absolute) \
				and not (transaction.backups as Dictionary).has(str(path)):
			if DirAccess.remove_absolute(absolute) == OK:
				removed += 1
	for path in transaction.backups:
		var absolute := ProjectSettings.globalize_path(str(path))
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
		if DirAccess.copy_absolute(
				ProjectSettings.globalize_path(str(transaction.backups[path])), absolute
			) == OK:
			restored += 1
	for path in transaction.absent as PackedStringArray:
		var absolute := ProjectSettings.globalize_path(str(path))
		if FileAccess.file_exists(absolute):
			if DirAccess.remove_absolute(absolute) == OK:
				removed += 1
	return {"ok": true, "restored": restored, "removed": removed}


static func _close_transaction(
		transaction: Dictionary,
		status: StringName,
		details := {}
	) -> void:
	var directory := str(transaction.get("directory", ""))
	if directory.is_empty():
		return
	var report := StudioVersion.metadata("arena_canonical_save_transaction")
	report.merge({
		"transaction_id": transaction.get("transaction_id", ""),
		"status": str(status),
		"backups": (transaction.get("backups", {}) as Dictionary).keys(),
		"absent": transaction.get("absent", PackedStringArray()),
		"details": details,
	}, true)
	var file := FileAccess.open(
		directory.path_join("save_transaction_report.json"), FileAccess.WRITE
	)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()


static func _first_line(values) -> String:
	var lines := values as PackedStringArray
	return lines[0] if lines != null and not lines.is_empty() else "Sauvegarde refusée."
