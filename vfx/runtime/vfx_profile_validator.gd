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
	return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings}


static func _validate_module(module: VFXModuleData, errors: Array[String]) -> void:
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
