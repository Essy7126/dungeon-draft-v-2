class_name SkeletonImportValidation
extends Node3D

signal validation_finished(report: Dictionary)

const EXPECTED_ANIMATIONS: Array[StringName] = [
	&"DD_Skeleton_Death",
	&"DD_Skeleton_Hit",
	&"DD_Skeleton_Idle",
	&"DD_Skeleton_MeleeAttack",
	&"DD_Skeleton_RangedAttack",
	&"DD_Skeleton_Run",
	&"DD_Skeleton_Walk",
]

var validation_report: Dictionary = {}


func _ready() -> void:
	call_deferred("run_validation")


func run_validation() -> Dictionary:
	var model := $SkeletonModel
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var errors: Array[String] = []
	if skeletons.size() != 1:
		errors.append("Expected one Skeleton3D, got %d" % skeletons.size())
	if meshes.size() != 1:
		errors.append("Expected one MeshInstance3D, got %d" % meshes.size())
	if players.size() != 1:
		errors.append("Expected one AnimationPlayer, got %d" % players.size())

	var bone_names: Array[StringName] = []
	if skeletons.size() == 1:
		var skeleton := skeletons[0] as Skeleton3D
		for bone_index in skeleton.get_bone_count():
			bone_names.append(skeleton.get_bone_name(bone_index))
		if not &"LeftHand" in bone_names or not &"RightHand" in bone_names:
			errors.append("Audited hand bones are missing")

	var mesh_vertices := 0
	var mesh_triangles := 0
	var has_skin := false
	if meshes.size() == 1:
		var mesh_instance := meshes[0] as MeshInstance3D
		has_skin = mesh_instance.skin != null
		if not has_skin:
			errors.append("MeshInstance3D has no Skin")
		if mesh_instance.mesh != null:
			for surface_index in mesh_instance.mesh.get_surface_count():
				var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
				mesh_vertices += arrays[Mesh.ARRAY_VERTEX].size()
				mesh_triangles += arrays[Mesh.ARRAY_INDEX].size() / 3

	var animation_names: Array[StringName] = []
	var animation_lengths := {}
	var looped_animations: Array[StringName] = []
	if players.size() == 1:
		var player := players[0] as AnimationPlayer
		animation_names.assign(player.get_animation_list())
		for animation_name in animation_names:
			var animation := player.get_animation(animation_name)
			animation_lengths[animation_name] = animation.length
			if animation.loop_mode != Animation.LOOP_NONE:
				looped_animations.append(animation_name)
		for expected_name in EXPECTED_ANIMATIONS:
			if not player.has_animation(expected_name):
				errors.append("Missing animation: %s" % expected_name)

	validation_report = {
		"passed": errors.is_empty(),
		"errors": errors,
		"skeleton_count": skeletons.size(),
		"bone_count": bone_names.size(),
		"bones": bone_names,
		"mesh_instance_count": meshes.size(),
		"mesh_vertices": mesh_vertices,
		"mesh_triangles": mesh_triangles,
		"has_skin": has_skin,
		"animations": animation_names,
		"animation_lengths": animation_lengths,
		"looped_animations": looped_animations,
	}
	validation_finished.emit(validation_report)
	return validation_report
