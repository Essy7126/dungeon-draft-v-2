class_name VFXProfileValidator
extends RefCounted


static func validate(
		profile: VFXProfile,
		context: VFXExecutionContext = null,
		sequence_id: StringName = &""
	) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if profile == null:
		return {"ok": false, "errors": ["VFXProfile absent."], "warnings": []}
	if profile.schema_version != 1:
		errors.append("schema_version non supporté : %d." % profile.schema_version)
	if profile.profile_id == &"":
		errors.append("profile_id stable requis.")
	if profile.render_policy not in VFXProfile.RENDER_POLICIES:
		errors.append("render_policy inconnu : %s." % profile.render_policy)
	if profile.art_status not in VFXProfile.ART_STATUSES:
		errors.append("art_status inconnu : %s." % profile.art_status)
	if profile.art_status == &"ART_APPROVED":
		warnings.append("ART_APPROVED ne peut être attribué que par un humain.")
	if profile.maximum_duration <= 0.0:
		errors.append("maximum_duration doit être positif.")
	if profile.sequences.is_empty():
		errors.append("Au moins une séquence est requise.")
	var sequence_ids := {}
	for sequence in profile.sequences:
		if sequence == null:
			errors.append("Séquence nulle.")
			continue
		if sequence.sequence_id == &"" or sequence_ids.has(sequence.sequence_id):
			errors.append("Identifiant de séquence absent ou dupliqué : %s." % sequence.sequence_id)
		sequence_ids[sequence.sequence_id] = true
		for module in sequence.modules:
			_validate_module(module, errors)
	if sequence_id != &"" and profile.get_sequence(sequence_id) == null:
		errors.append("Séquence inconnue : %s." % sequence_id)
	if context != null:
		for requirement in profile.context_requirements:
			if not context.has(requirement):
				errors.append("Contexte requis absent : %s." % requirement)
		var selected := profile.get_sequence(sequence_id) if sequence_id != &"" else null
		if selected != null:
			for module in selected.modules:
				if module == null or not module.enabled:
					continue
				for requirement in module.context_requirements:
					if not context.has(requirement):
						errors.append("%s requiert le contexte %s." % [module.module_id, requirement])
				_validate_module_context(module, errors, context)
	return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings}


static func _validate_module(
		module: VFXModuleData,
		errors: Array[String]
	) -> void:
	if module == null:
		errors.append("Module nul.")
		return
	if module.module_id == &"":
		errors.append("module_id requis.")
	if not VFXModuleRegistry.knows(module.module_type):
		errors.append("Module inconnu : %s." % module.module_type)
	if module.duration <= 0.0:
		errors.append("Durée invalide pour %s." % module.module_id)
	if module.start_offset < 0.0:
		errors.append("Start offset négatif pour %s." % module.module_id)
	if module is VFXFlipbookModuleData and module.module_type != &"FlipbookModule":
		errors.append("VFXFlipbookModuleData requiert module_type FlipbookModule.")
		return
	if module.module_type != &"FlipbookModule":
		return
	if not module is VFXFlipbookModuleData:
		errors.append("FlipbookModule requiert VFXFlipbookModuleData.")
		return
	var flipbook := module as VFXFlipbookModuleData
	if flipbook.asset == null:
		errors.append("Asset flipbook absent pour %s." % module.module_id)
		return
	errors.append_array(flipbook.asset.validate_structure())
	if flipbook.anchor not in VFXFlipbookModuleData.SUPPORTED_ANCHORS:
		errors.append("Ancre flipbook non supportée : %s." % flipbook.anchor)
	if flipbook.scale_multiplier.x <= 0.0 or flipbook.scale_multiplier.y <= 0.0:
		errors.append("Échelle flipbook strictement positive requise.")
	if flipbook.opacity < 0.0 or flipbook.opacity > 1.0:
		errors.append("Opacité flipbook hors [0, 1].")


static func _validate_module_context(
		module: VFXModuleData,
		errors: Array[String],
		context: VFXExecutionContext
	) -> void:
	if module.module_type != &"FlipbookModule" or not module is VFXFlipbookModuleData:
		return
	var flipbook := module as VFXFlipbookModuleData
	if flipbook.asset == null:
		return
	var selected := flipbook.asset.select_variant(context.get_seed() + flipbook.seed_offset)
	var texture: Texture2D = flipbook.asset.select_texture(
		selected, context.get_quality_tier()
	).get("texture") as Texture2D
	if texture == null:
		errors.append("Qualité flipbook demandée non résoluble.")
	match flipbook.anchor:
		&"TARGET_WORLD":
			if not context.has(&"target_world"):
				errors.append("TARGET_WORLD requiert target_world.")
		&"ORIGIN_WORLD":
			if not context.has(&"origin_world"):
				errors.append("ORIGIN_WORLD requiert origin_world.")
		&"FIRST_IMPACT_WORLD":
			if not context.has(&"impact_world_points"):
				errors.append("FIRST_IMPACT_WORLD requiert impact_world_points.")
