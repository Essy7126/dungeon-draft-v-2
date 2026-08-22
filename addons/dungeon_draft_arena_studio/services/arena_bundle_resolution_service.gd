@tool
class_name ArenaBundleResolutionService
extends RefCounted

## Orchestrateur unique des conflits de destination. plan() est strictement en
## lecture seule. execute() ne mute un bundle qu'apres une action UI explicite.

const RESUME_INTERRUPTED := &"RESUME_INTERRUPTED"
const ARCHIVE_AND_REBUILD := &"ARCHIVE_AND_REBUILD"
const VERSION_ALONGSIDE := &"VERSION_ALONGSIDE"
const REMOVE_FROM_PROJECT := &"REMOVE_FROM_PROJECT"
const EXAMINE_FILES := &"EXAMINE_FILES"
const CANCEL := &"CANCEL"

const RESUME_ROOT := "user://dungeon_draft_studio/production_resolutions"


static func plan(
		arena: ArenaDefinition,
		destination: String,
		inspection: Dictionary = {},
		graph: StudioReferenceGraphService = null
	) -> Dictionary:
	if inspection.is_empty():
		inspection = ArenaBundleInspectionService.inspect(destination, graph)
	var state := StringName(inspection.get("state", ArenaBundleInspectionService.UNKNOWN))
	var references := inspection.get("reference_report", {}) as Dictionary
	if references.is_empty():
		references = ArenaBundleReferenceService.inspect(
			destination.path_join("arena.tres"), graph
		)
	var resume := _resume_assessment(arena, destination, inspection, references)
	var version := ArenaBundleVersioningService.next_destination(destination)
	var unreferenced := not bool(references.get("referenced", false))
	var idle := not bool(references.get("busy", false))
	var has_files := not (inspection.get("files", {}) as Dictionary).is_empty()
	var actions: Array[Dictionary] = []
	if has_files:
		actions.append(_action(
			RESUME_INTERRUPTED, "Reprendre la production interrompue",
			bool(resume.get("ok", false)), true,
			str(resume.get("reason", "Le dossier de production ne peut pas être repris sans preuve suffisante."))
		))
		actions.append(_action(
			ARCHIVE_AND_REBUILD, "Archiver puis reconstruire",
			unreferenced and idle, true,
			"Disponible uniquement lorsque ni ressource, ni partie, ni transaction active ne référence le dossier de production."
		))
		actions.append(_action(
			VERSION_ALONGSIDE, "Créer une nouvelle version à côté",
			bool(version.get("ok", false)), false,
			"Conserve intégralement le dossier existant et choisit un nouveau chemin visible."
		))
		actions.append(_action(
			REMOVE_FROM_PROJECT, "Retirer les anciens fichiers du projet",
			unreferenced and idle, true,
			"Retire le dossier du projet après copie vérifiée dans une archive récupérable en local."
		))
		actions.append(_action(
			EXAMINE_FILES, "Examiner les fichiers", true, false,
			"Ouvre le dossier et conserve tous les fichiers inchangés."
		))
	actions.append(_action(CANCEL, "Annuler", true, false, "Aucune modification."))
	var required := has_files and state not in [
		ArenaBundleInspectionService.OWNED_COMPLETE,
		ArenaBundleInspectionService.REFERENCED_COMPLETE,
	]
	var recommended := &""
	if required:
		if bool(resume.get("ok", false)):
			recommended = RESUME_INTERRUPTED
		elif unreferenced and idle:
			recommended = ARCHIVE_AND_REBUILD
		else:
			recommended = VERSION_ALONGSIDE
	return {
		"ok": true,
		"required": required,
		"destination": destination,
		"state": state,
		"state_label": _state_label(state),
		"explanation": _explanation(state, inspection, references),
		"files": _file_records(inspection.get("files", {})),
		"references": references,
		"resume_assessment": resume,
		"version_plan": version,
		"recommended_action": recommended,
		"recommended_label": _action_label(actions, recommended),
		"actions": actions,
		"automatic_overwrite": false,
		"automatic_deletion": false,
	}


static func execute(
		action: StringName,
		arena: ArenaDefinition,
		destination: String,
		graph: StudioReferenceGraphService = null,
		reason := "Action explicite depuis Arena Studio"
	) -> Dictionary:
	var current := plan(arena, destination, {}, graph)
	var action_plan := _find_action(current.get("actions", []), action)
	if action_plan.is_empty() or not bool(action_plan.get("enabled", false)):
		return {
			"ok": false, "error": "resolution_action_unavailable",
			"action": action, "plan": current,
		}
	match action:
		RESUME_INTERRUPTED:
			return _resume_interrupted(arena, destination, current)
		ARCHIVE_AND_REBUILD, REMOVE_FROM_PROJECT:
			var archived := ArenaBundleOwnershipService.archive_unreferenced_bundle(
				destination, reason, graph, action
			)
			archived["action"] = action
			archived["destination"] = destination
			return archived
		VERSION_ALONGSIDE:
			var version := current.get("version_plan", {}) as Dictionary
			return version.merged({
				"action": action, "changed_destination_only": true,
				"existing_bundle_unchanged": true,
			}, true)
		EXAMINE_FILES:
			return {
				"ok": true, "action": action, "destination": destination,
				"absolute_path": ProjectSettings.globalize_path(destination),
				"plan": current, "mutated": false,
			}
		CANCEL:
			return {"ok": true, "action": action, "cancelled": true, "mutated": false}
	return {"ok": false, "error": "unknown_resolution_action", "action": action}


static func _resume_assessment(
		arena: ArenaDefinition,
		destination: String,
		inspection: Dictionary,
		references: Dictionary
	) -> Dictionary:
	if StringName(inspection.get("state", &"")) != ArenaBundleInspectionService.OWNED_INCOMPLETE:
		return {"ok": false, "reason": "L'état n'est pas une production structurelle incomplète."}
	if bool(references.get("referenced", false)):
		return {"ok": false, "reason": "Une ressource ou une partie référence déjà arena.tres."}
	if bool(references.get("busy", false)):
		return {"ok": false, "reason": "Une transaction de production est encore active."}
	if arena == null:
		return {"ok": false, "reason": "La version en cours est absente."}
	var allowed := {}
	for name in ArenaProductionService._output_names(arena, false):
		allowed[name] = true
	var unexpected := PackedStringArray()
	for relative_path in (inspection.get("files", {}) as Dictionary):
		if str(relative_path).ends_with(".import"):
			continue
		if not allowed.has(str(relative_path)):
			unexpected.append(str(relative_path))
	if not unexpected.is_empty():
		return {
			"ok": false,
			"reason": "Le dossier contient des fichiers non attendus : %s." % ", ".join(unexpected),
			"unexpected": unexpected,
		}
	var existing := ResourceLoader.load(
		destination.path_join("arena.tres"), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	if existing == null:
		return {"ok": false, "reason": "arena.tres ne peut pas être rechargé."}
	if existing.arena_id != arena.arena_id:
		return {
			"ok": false,
			"reason": "L'identifiant existant (%s) diffère de la version en cours (%s)." % [
				existing.arena_id, arena.arena_id,
			],
		}
	var existing_fingerprint := ArenaSnapshotService.arena_fingerprint(existing)
	var working_fingerprint := ArenaSnapshotService.arena_fingerprint(arena)
	if existing_fingerprint != working_fingerprint:
		return {
			"ok": false,
			"reason": "Les fingerprints existant et courant diffèrent ; une reprise serait ambiguë.",
			"existing_fingerprint": existing_fingerprint,
			"working_fingerprint": working_fingerprint,
		}
	var validation := ArenaValidator.validate(existing, false)
	var visual := ArenaVisualAssembler.inspect(existing)
	if not validation.is_valid() or not visual.valid:
		return {"ok": false, "reason": "Le dossier de production existant ne passe pas la validation ni le rendu dans le jeu."}
	return {
		"ok": true,
		"reason": "Identité, fingerprint, validation, rendu et absence de références sont vérifiés.",
		"existing_fingerprint": existing_fingerprint,
		"working_fingerprint": working_fingerprint,
		"arena_path": destination.path_join("arena.tres"),
	}


static func _resume_interrupted(
		arena: ArenaDefinition,
		destination: String,
		resolution: Dictionary
	) -> Dictionary:
	var assessment := resolution.get("resume_assessment", {}) as Dictionary
	if not bool(assessment.get("ok", false)):
		return {"ok": false, "error": "resume_not_verified", "assessment": assessment}
	var operation_id := "%s_%d" % [destination.get_file(), Time.get_ticks_usec()]
	var recovery := RESUME_ROOT.path_join(operation_id)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(recovery)) != OK:
		return {"ok": false, "error": "resume_recovery_failed"}
	var arena_path := destination.path_join("arena.tres")
	var arena_backup := recovery.path_join("arena_before.tres")
	if DirAccess.copy_absolute(
		ProjectSettings.globalize_path(arena_path),
		ProjectSettings.globalize_path(arena_backup)
	) != OK:
		return {"ok": false, "error": "resume_backup_failed", "recovery": recovery}
	var text := FileAccess.get_file_as_string(arena_path)
	var normalized := text.replace(destination.trim_suffix("/") + "/", "")
	if normalized != text and not _write_text(arena_path, normalized):
		var rollback_ok := _restore_resume(arena_backup, arena_path, destination)
		return {
			"ok": false, "error": "resume_normalization_failed",
			"recovery": recovery, "rollback_ok": rollback_ok,
		}
	var existing := ResourceLoader.load(
		arena_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as ArenaDefinition
	if existing == null:
		var rollback_ok := _restore_resume(arena_backup, arena_path, destination)
		return {
			"ok": false, "error": "resume_reload_failed",
			"recovery": recovery, "rollback_ok": rollback_ok,
		}
	var hashes := {}
	for relative_path in ArenaBundleInspectionService._files(destination):
		if str(relative_path).ends_with(".import") \
				or str(relative_path) == ArenaProductionService.MANIFEST_FILE:
			continue
		hashes[str(relative_path)] = FileAccess.get_sha256(
			destination.path_join(str(relative_path))
		)
	var manifest := {
		"version": ArenaProductionService.MANIFEST_SCHEMA_VERSION,
		"manifest_schema_version": ArenaProductionService.MANIFEST_SCHEMA_VERSION,
		"studio_product_version": StudioVersion.PRODUCT_VERSION,
		"generator_revision": ArenaProductionService.GENERATOR_REVISION,
		"generated_by": ArenaProductionService.GENERATED_BY,
		"complete": true,
		"arena_id": str(existing.arena_id),
		"fingerprint_algorithm_id": ArenaProductionService.FINGERPRINT_ALGORITHM_ID,
		"physical_file_hash": hashes.duplicate(true),
		"logical_arena_fingerprint": ArenaSnapshotService.arena_fingerprint(existing),
		"gameplay_fingerprint": ArenaSnapshotService.gameplay_fingerprint(existing),
		"source_fingerprint": ArenaSnapshotService.arena_fingerprint(arena),
		"source_gameplay_fingerprint": ArenaSnapshotService.gameplay_fingerprint(arena),
		"produced_fingerprint": ArenaSnapshotService.arena_fingerprint(existing),
		"produced_gameplay_fingerprint": ArenaSnapshotService.gameplay_fingerprint(existing),
		"battle_scene": existing.battle_scene.resource_path if existing.battle_scene != null else "",
		"files": hashes,
		"runtime_bundle": true,
		"art_kit": [],
		"visual_assembly": ArenaVisualAssembler.inspect(existing).to_dict(),
		"runtime_assets": [],
		"resumed_interrupted_production": true,
		"resumed_at": Time.get_datetime_string_from_system(true),
		"recovery": recovery,
	}
	var manifest_candidate := recovery.path_join("manifest_candidate.json")
	if not ArenaProductionService._write_json(manifest_candidate, manifest):
		var rollback_ok := _restore_resume(arena_backup, arena_path, destination)
		return {
			"ok": false, "error": "resume_manifest_staging_failed",
			"recovery": recovery, "rollback_ok": rollback_ok,
		}
	var manifest_path := destination.path_join(ArenaProductionService.MANIFEST_FILE)
	if DirAccess.copy_absolute(
		ProjectSettings.globalize_path(manifest_candidate),
		ProjectSettings.globalize_path(manifest_path)
	) != OK:
		var rollback_ok := _restore_resume(arena_backup, arena_path, destination)
		return {
			"ok": false, "error": "resume_manifest_write_failed",
			"recovery": recovery, "rollback_ok": rollback_ok,
		}
	var verification := ArenaProductionTransactionService._verify_bundle(destination, arena)
	var final_inspection := ArenaBundleInspectionService.inspect(destination)
	if not bool(verification.get("ok", false)) \
			or final_inspection.get("state", &"") != ArenaBundleInspectionService.OWNED_COMPLETE:
		var rollback_ok := _restore_resume(arena_backup, arena_path, destination)
		return {
			"ok": false, "error": "resume_verification_failed",
			"verification": verification, "inspection": final_inspection,
			"recovery": recovery, "rollback_ok": rollback_ok,
		}
	ArenaProductionService._write_json(recovery.path_join("resume_receipt.json"), {
		"operation_id": operation_id,
		"destination": destination,
		"completed_at": Time.get_datetime_string_from_system(true),
		"manifest_sha256": FileAccess.get_sha256(manifest_path),
		"files": final_inspection.get("files", {}),
	})
	return {
		"ok": true, "action": RESUME_INTERRUPTED,
		"destination": destination, "recovery": recovery,
		"manifest": manifest, "inspection": final_inspection,
		"resources_reloaded": true,
	}


static func _restore_resume(
		arena_backup: String,
		arena_path: String,
		destination: String
	) -> bool:
	var restored := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(arena_backup),
		ProjectSettings.globalize_path(arena_path)
	) == OK
	var manifest_path := destination.path_join(ArenaProductionService.MANIFEST_FILE)
	if FileAccess.file_exists(manifest_path):
		restored = DirAccess.remove_absolute(
			ProjectSettings.globalize_path(manifest_path)
		) == OK and restored
	return restored


static func _write_text(path: String, value: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(value)
	file.close()
	return true


static func _action(
		id: StringName,
		label: String,
		enabled: bool,
		requires_confirmation: bool,
		reason: String
	) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"enabled": enabled,
		"requires_confirmation": requires_confirmation,
		"reason": reason,
	}


static func _find_action(actions: Array, action: StringName) -> Dictionary:
	for value in actions:
		var candidate := value as Dictionary
		if StringName(candidate.get("id", &"")) == action:
			return candidate.duplicate(true)
	return {}


static func _action_label(actions: Array, action: StringName) -> String:
	return str(_find_action(actions, action).get("label", ""))


static func _file_records(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var files := value as Dictionary if value is Dictionary else {}
	var paths := PackedStringArray()
	for path in files:
		paths.append(str(path))
	paths.sort()
	for path in paths:
		var metadata := files[path] as Dictionary
		result.append({
			"path": path,
			"size": int(metadata.get("size", 0)),
			"sha256": str(metadata.get("sha256", "")),
		})
	return result


static func _state_label(state: StringName) -> String:
	return {
		ArenaBundleInspectionService.EMPTY: "Destination vide",
		ArenaBundleInspectionService.OWNED_COMPLETE: "Production Studio complète",
		ArenaBundleInspectionService.REFERENCED_COMPLETE: "Production Studio complète et référencée",
		ArenaBundleInspectionService.OWNED_INCOMPLETE: "Production interrompue sans manifeste",
		ArenaBundleInspectionService.REFERENCED_INCOMPLETE: "Production incomplète déjà référencée",
		ArenaBundleInspectionService.OWNED_DIRTY: "Production Studio modifiée hors manifeste",
		ArenaBundleInspectionService.FOREIGN_CONTENT: "Fichiers sans preuve de propriété Studio",
		ArenaBundleInspectionService.CORRUPT_MANIFEST: "Manifeste illisible",
		ArenaBundleInspectionService.LEGACY_BUNDLE: "Ancienne production",
		ArenaBundleInspectionService.LEGACY_LOGICAL_FINGERPRINT: "Empreinte logique historique",
	}.get(state, "État de destination inconnu")


static func _explanation(
		state: StringName,
		inspection: Dictionary,
		references: Dictionary
	) -> String:
	var file_count := (inspection.get("files", {}) as Dictionary).size()
	var reference_count := int(references.get("canonical_count", 0))
	var transaction_count := (references.get("active_transaction_references", []) as Array).size()
	match state:
		ArenaBundleInspectionService.OWNED_INCOMPLETE:
			return "%d fichier(s) structuraux sont présents, mais aucun production_manifest.json reconnu ne prouve leur propriété. Références : %d ; transactions actives : %d." % [file_count, reference_count, transaction_count]
		ArenaBundleInspectionService.REFERENCED_INCOMPLETE:
			return "Le dossier de production est incomplet et déjà utilisé par %d ressource(s) ou partie(s). Aucun déplacement n'est sûr." % reference_count
		ArenaBundleInspectionService.OWNED_DIRTY:
			return "Le manifeste est reconnu, mais des hashes ou fichiers étrangers divergent. L'écrasement reste protégé."
		ArenaBundleInspectionService.FOREIGN_CONTENT:
			var manifest := inspection.get("manifest", {}) as Dictionary
			var generator := str(manifest.get("generated_by", ""))
			return "Le manifeste déclare generated_by='%s', qui n'est pas reconnu par cette version du Studio ; aucune propriété n'est supposée." % generator \
				if not generator.is_empty() else "Les fichiers présents ne possèdent aucune preuve de propriété Arena Studio."
		ArenaBundleInspectionService.CORRUPT_MANIFEST:
			return "production_manifest.json existe mais ne peut pas être interprété de façon sûre."
		ArenaBundleInspectionService.LEGACY_BUNDLE:
			return "Une ancienne structure de dossier de production est détectée ; elle doit être conservée ou versionnée explicitement."
		ArenaBundleInspectionService.LEGACY_LOGICAL_FINGERPRINT:
			return "Les fichiers correspondent physiquement au manifeste, mais l'algorithme d'empreinte logique est historique. Une migration explicite et sauvegardée du manifeste est requise."
		ArenaBundleInspectionService.EMPTY:
			return "La destination est vide et peut être produite."
	return "%d fichier(s), %d référence(s), %d transaction(s) active(s)." % [file_count, reference_count, transaction_count]
