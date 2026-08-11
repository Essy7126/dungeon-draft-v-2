class_name VFXRuntimeInstance
extends Node2D

signal completed(instance: VFXRuntimeInstance, reason: StringName)

var profile: VFXProfile
var context: VFXExecutionContext
var sequence: VFXSequenceData
var elapsed := 0.0
var lifecycle_state: StringName = &"NEW"
var diagnostics: Array[String] = []
var _visuals: Array[VFXModuleVisual] = []
var _auto_process := true
var _completion_emitted := false


func configure(
		vfx_profile: VFXProfile,
		execution_context: VFXExecutionContext,
		sequence_id: StringName,
		auto_process := true
	) -> Dictionary:
	profile = vfx_profile
	context = execution_context
	_auto_process = auto_process
	var validation := VFXProfileValidator.validate(profile, context, sequence_id)
	if not bool(validation.ok):
		diagnostics.assign(validation.errors)
		lifecycle_state = &"INVALID"
		set_process(false)
		return validation
	sequence = profile.get_sequence(sequence_id)
	_build_modules()
	lifecycle_state = &"PLAYING"
	set_process(_auto_process)
	return validation


func _process(delta: float) -> void:
	advance_simulation(delta)


func advance_simulation(delta: float) -> void:
	if lifecycle_state != &"PLAYING" or profile == null or context == null:
		return
	elapsed += maxf(delta, 0.0) * context.get_speed_scale()
	for index in range(sequence.modules.size()):
		var module := sequence.modules[index]
		if module == null or not module.enabled or index >= _visuals.size():
			continue
		var visual := _visuals[index]
		if visual == null or context.get_quality_tier() < module.minimum_quality:
			continue
		if elapsed < module.start_offset:
			visual.visible = false
			continue
		visual.set_normalized_progress((elapsed - module.start_offset) / maxf(module.duration, 0.01))
	var sequence_done := elapsed >= sequence.duration()
	var timed_out := elapsed >= profile.maximum_duration
	if sequence_done or timed_out:
		_finish(&"TIMEOUT" if timed_out and not sequence_done else &"COMPLETED")


func cancel() -> void:
	if lifecycle_state in [&"CLEARED", &"COMPLETED", &"CANCELLED", &"TIMEOUT"]:
		return
	_finish(&"CANCELLED")


func clear() -> void:
	if lifecycle_state == &"CLEARED":
		return
	_cleanup_visuals()
	lifecycle_state = &"CLEARED"
	set_process(false)


func active_visual_count() -> int:
	return _visuals.filter(func(visual): return is_instance_valid(visual)).size()


func geometry_fingerprint() -> String:
	var values: Array[String] = []
	for visual in _visuals:
		if is_instance_valid(visual):
			values.append(visual.geometry_fingerprint())
	return JSON.stringify(values).sha256_text()


func _build_modules() -> void:
	_visuals.clear()
	for index in range(sequence.modules.size()):
		var module := sequence.modules[index]
		var visual: VFXModuleVisual = null
		if module != null and module.enabled and context.get_quality_tier() >= module.minimum_quality:
			var seed := _module_seed(module, index)
			visual = VFXModuleRegistry.create_visual(module, context, seed)
			if visual != null:
				add_child(visual)
		_visuals.append(visual)


func _module_seed(module: VFXModuleData, index: int) -> int:
	var identity := "%s|%s|%s|%d" % [
		profile.profile_id, sequence.sequence_id, module.module_id, index,
	]
	return context.get_seed() + module.seed_offset + int(identity.hash())


func _finish(reason: StringName) -> void:
	if _completion_emitted:
		return
	_completion_emitted = true
	lifecycle_state = reason
	set_process(false)
	_cleanup_visuals()
	completed.emit(self, reason)


func _cleanup_visuals() -> void:
	for visual in _visuals:
		if is_instance_valid(visual):
			visual.free()
	_visuals.clear()
