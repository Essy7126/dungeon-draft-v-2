class_name VFXProfileRunner
extends RefCounted


static func play(
		profile: VFXProfile,
		context: VFXExecutionContext,
		sequence_id: StringName = &"play",
		parent: Node = null,
		auto_process := true
	) -> Dictionary:
	var target_parent := parent if parent != null else context.get_target_layer()
	if target_parent == null or not is_instance_valid(target_parent):
		return {"ok": false, "errors": ["Couche cible VFX absente."], "instance": null}
	var instance := VFXRuntimeInstance.new()
	instance.name = "VFX_%s_%s" % [profile.profile_id if profile != null else &"invalid", sequence_id]
	target_parent.add_child(instance)
	var validation := instance.configure(profile, context, sequence_id, auto_process)
	if not bool(validation.ok):
		instance.clear()
		instance.free()
		return {"ok": false, "errors": validation.errors, "instance": null}
	return {"ok": true, "errors": [], "instance": instance}
