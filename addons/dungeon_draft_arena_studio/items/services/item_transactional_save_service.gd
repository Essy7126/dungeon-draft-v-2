@tool
class_name ItemTransactionalSaveService
extends RefCounted

var validation_service := ItemStudioValidationService.new()
var reference_service := ItemReferenceService.new()
var force_failure_after_write := false


func build_plan(
		document: ItemStudioDocument,
		target_path: String,
		target_status: StringName,
		catalog: ItemStudioCatalogService,
		reward_tag_changed := false
	) -> ItemSavePlan:
	var plan := ItemSavePlan.new()
	plan.catalog_path = catalog.catalog_path if catalog != null else ItemStudioCatalogService.DEFAULT_CATALOG_PATH
	plan.reward_tag_changed = reward_tag_changed
	if document == null or document.working_copy == null:
		plan.conflicts.append(ItemSaveConflict.new().configure(&"DOCUMENT_MISSING", "Aucun objet à sauvegarder."))
		return plan
	if target_status == StudioProjectContext.SCOPE_RUN_SPECIFIC:
		plan.conflicts.append(ItemSaveConflict.new().configure(&"RUN_SPECIFIC_UNSUPPORTED", "La portée « propre à une partie » est différée : aucun catalogue par partie n’existe."))
		return plan
	var validation := validation_service.validate(
		document.working_copy, catalog, target_path, document.source_path,
		document.original_item_id if document.status == ItemStudioDocument.STATUS_SHARED else &"",
	)
	for message_value in validation.get("messages", []) as Array:
		var message := message_value as Dictionary
		if int(message.get("severity", 0)) == ItemStudioValidationMessage.Severity.ERROR:
			plan.conflicts.append(ItemSaveConflict.new().configure(
				StringName(message.get("code", &"VALIDATION")),
				str(message.get("message", "Validation refusée.")),
				str(message.get("property_path", "")),
			))
		elif int(message.get("severity", 0)) == ItemStudioValidationMessage.Severity.WARNING:
			plan.warnings.append(str(message.get("message", "")))
	var entry := ItemSavePlanEntry.new()
	entry.source_path = document.source_path
	entry.destination_path = target_path
	entry.operation = &"UPDATE" if target_path == document.source_path and FileAccess.file_exists(target_path) else &"CREATE"
	entry.status = target_status
	entry.item_id = document.working_copy.item_id
	entry.old_fingerprint = document.original_fingerprint
	entry.new_fingerprint = document.current_fingerprint()
	entry.subresource_count = document.working_copy.stat_modifiers.size() + document.working_copy.spell_modifiers.size()
	plan.entries.append(entry)
	plan.references = reference_service.incoming_references(document.source)
	return plan


func execute(plan: ItemSavePlan, document: ItemStudioDocument) -> Dictionary:
	if plan == null or document == null or document.working_copy == null or not plan.is_valid():
		return {"ok": false, "error": "Plan de sauvegarde invalide.", "plan": plan.to_snapshot() if plan != null else {}}
	var entry := plan.entries[0]
	var target_path := entry.destination_path
	var absolute_target := ProjectSettings.globalize_path(target_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_target.get_base_dir())
	if directory_error != OK:
		return {"ok": false, "error": "Dossier de destination inaccessible : %s" % directory_error}
	var nonce := Time.get_ticks_usec()
	var temporary_path := "%s.studio_tmp_%d.tres" % [target_path.get_basename(), nonce]
	var backup_path := "%s.studio_backup_%d.tres" % [target_path.get_basename(), nonce]
	var expected_fingerprint := document.current_fingerprint()
	var save_candidate := ItemDeepCopyService.new().duplicate_definition(document.working_copy)
	if save_candidate == null:
		return {"ok": false, "error": "La version en cours ne peut pas être dupliquée pour l’écriture."}
	var save_error := ResourceSaver.save(save_candidate, temporary_path)
	if save_error != OK:
		return {"ok": false, "error": "ResourceSaver a refusé l’écriture : %s" % save_error}
	var temporary_resource := ResourceLoader.load(temporary_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	if temporary_resource == null or ItemFingerprintService.semantic_fingerprint(temporary_resource) != expected_fingerprint:
		_remove_temporary(temporary_path)
		return {"ok": false, "error": "La relecture temporaire ne conserve pas l’empreinte sémantique."}
	var target_existed := FileAccess.file_exists(target_path)
	if target_existed:
		var backup_error := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(target_path),
			ProjectSettings.globalize_path(backup_path),
		)
		if backup_error != OK:
			_remove_temporary(temporary_path)
			return {"ok": false, "error": "Point de restauration impossible : %s" % backup_error}
	var replace_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		absolute_target,
	)
	if replace_error != OK:
		_restore_backup(target_path, backup_path, target_existed)
		return {"ok": false, "error": "Remplacement transactionnel impossible : %s" % replace_error}
	# Deux relectures, chacune pour une raison distincte :
	# - CACHE_MODE_REPLACE rend l'instance partagée du chemin, celle que le
	#   catalogue et les documents ouverts référencent déjà ;
	# - CACHE_MODE_IGNORE rend le contenu réel du fichier.
	# Elles peuvent diverger : ResourceSaver omet du .tres toute propriété égale
	# à son défaut (un tags vidé ne produit aucune ligne « tags = »), et
	# CACHE_MODE_REPLACE n'assigne que ce qui est présent dans le fichier — la
	# valeur précédente survivrait donc à toute remise à zéro.
	var reloaded := ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_REPLACE) as ItemDefinition
	var written := ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	# La vérification porte sur `written` : lui seul reflète le fichier.
	var verified := not force_failure_after_write and reloaded != null \
		and written != null \
		and written.is_valid() \
		and ItemFingerprintService.semantic_fingerprint(written) == expected_fingerprint
	if not verified:
		_restore_backup(target_path, backup_path, target_existed)
		_resync_shared_instance(target_path)
		return {"ok": false, "error": "Vérification post-écriture échouée ; restauration effectuée."}
	_adopt_stored_properties(reloaded, written)
	if target_existed:
		_remove_temporary(backup_path)
	return {
		"ok": true,
		"path": target_path,
		"resource": reloaded,
		"fingerprint": expected_fingerprint,
		"plan": plan.to_snapshot(),
	}


static func _resync_shared_instance(target_path: String) -> void:
	# La relecture CACHE_MODE_REPLACE a lieu avant la vérification : en cas de
	# refus, l'instance partagée porte encore le contenu rejeté alors que le
	# fichier vient d'être restauré. On la réaligne sur le fichier.
	if not FileAccess.file_exists(target_path):
		return
	var cached := ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	var restored := ResourceLoader.load(target_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if cached != null and restored != null:
		_adopt_stored_properties(cached, restored)


static func _adopt_stored_properties(target: Resource, source: Resource) -> void:
	# Recopie sur l'instance partagée tout ce que le fichier définit, y compris
	# les propriétés qu'il omet parce qu'elles sont revenues à leur défaut : elles
	# valent alors ce défaut sur `source`, ce qui est exactement l'état voulu.
	# On écrit sur l'instance existante plutôt que d'en publier une neuve pour que
	# les références déjà distribuées (catalogue, document ouvert) suivent.
	if target == source:
		return
	for property_value in source.get_property_list():
		var property := property_value as Dictionary
		var property_name := str(property.get("name", ""))
		if property_name in ["resource_local_to_scene", "resource_name", "resource_path", "script"] \
				or not (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE):
			continue
		target.set(property_name, source.get(property_name))


func _restore_backup(target_path: String, backup_path: String, target_existed: bool) -> void:
	if FileAccess.file_exists(target_path):
		_remove_temporary(target_path)
	if target_existed and FileAccess.file_exists(backup_path):
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(backup_path),
			ProjectSettings.globalize_path(target_path),
		)


func _remove_temporary(resource_path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
