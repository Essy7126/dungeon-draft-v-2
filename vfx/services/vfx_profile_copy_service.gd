class_name VFXProfileCopyService
extends RefCounted


func duplicate_profile(profile: VFXProfile) -> VFXProfile:
	return VFXProfileSnapshotService.from_dictionary(
		VFXProfileSnapshotService.to_dictionary(profile)
	)


func mutable_resources_are_distinct(source: VFXProfile, copy: VFXProfile) -> bool:
	if source == null or copy == null or source == copy or source.sequences.size() != copy.sequences.size():
		return false
	for sequence_index in source.sequences.size():
		var left := source.sequences[sequence_index]
		var right := copy.sequences[sequence_index]
		if left == right or left.modules.size() != right.modules.size():
			return false
		for module_index in left.modules.size():
			var left_module := left.modules[module_index]
			var right_module := right.modules[module_index]
			if left_module == right_module:
				return false
			if left_module.response_curve != null and left_module.response_curve == right_module.response_curve:
				return false
			if left_module.color_gradient != null and left_module.color_gradient == right_module.color_gradient:
				return false
	return true
