class_name SkeletonChiefImportValidation
extends Node3D

signal validation_finished(report: Dictionary)

const EXPECTED_ANIMATIONS: Array[StringName] = [
	&"DD_SkeletonChief_Attack",
	&"DD_SkeletonChief_Death",
	&"DD_SkeletonChief_HeavyAttack",
	&"DD_SkeletonChief_Hit",
	&"DD_SkeletonChief_Idle",
	&"DD_SkeletonChief_Run",
	&"DD_SkeletonChief_Walk",
]
const EXPECTED_LOOPED: Array[StringName] = [
	&"DD_SkeletonChief_Idle",
	&"DD_SkeletonChief_Run",
	&"DD_SkeletonChief_Walk",
]

var validation_report: Dictionary = {}


func _ready() -> void:
	call_deferred("run_validation")


func run_validation() -> Dictionary:
	var model := $SkeletonChiefModel
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
	var root_bones: Array[StringName] = []
	if skeletons.size() == 1:
		var skeleton := skeletons[0] as Skeleton3D
		for bone_index in skeleton.get_bone_count():
			bone_names.append(skeleton.get_bone_name(bone_index))
			if skeleton.get_bone_parent(bone_index) < 0:
				root_bones.append(skeleton.get_bone_name(bone_index))
		if bone_names.size() != 24:
			errors.append("Expected 24 bones, got %d" % bone_names.size())
		if root_bones != [&"Hips"]:
			errors.append("Unexpected root bones: %s" % str(root_bones))
		for required in [&"LeftHand", &"RightHand", &"LeftFoot", &"RightFoot", &"Head"]:
			if required not in bone_names:
				errors.append("Missing audited bone: %s" % required)

	var mesh_vertices := 0
	var mesh_triangles := 0
	var material_count := 0
	var maximum_influences := 0
	var has_skin := false
	var mesh_aabb := AABB()
	if meshes.size() == 1:
		var mesh_instance := meshes[0] as MeshInstance3D
		has_skin = mesh_instance.skin != null
		if not has_skin:
			errors.append("MeshInstance3D has no Skin")
		if mesh_instance.mesh != null:
			mesh_aabb = mesh_instance.mesh.get_aabb()
			for surface_index in mesh_instance.mesh.get_surface_count():
				var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				mesh_vertices += vertices.size()
				mesh_triangles += indices.size() / 3
				if mesh_instance.mesh.surface_get_material(surface_index) != null:
					material_count += 1
				var stride := weights.size() / maxi(vertices.size(), 1)
				for vertex_index in vertices.size():
					var influence_count := 0
					for influence_index in stride:
						if weights[vertex_index * stride + influence_index] > 0.000001:
							influence_count += 1
					maximum_influences = maxi(maximum_influences, influence_count)
	if mesh_triangles != 3354:
		errors.append("Expected 3354 triangles, got %d" % mesh_triangles)
	if material_count != 1:
		errors.append("Expected one material surface, got %d" % material_count)

	var animation_names: Array[StringName] = []
	var animation_lengths := {}
	var looped_animations: Array[StringName] = []
	var empty_animations: Array[StringName] = []
	if players.size() == 1:
		var player := players[0] as AnimationPlayer
		animation_names.assign(player.get_animation_list())
		for animation_name in animation_names:
			var animation := player.get_animation(animation_name)
			animation_lengths[animation_name] = animation.length
			if animation.get_track_count() == 0 or animation.length <= 0.0:
				empty_animations.append(animation_name)
			if animation.loop_mode != Animation.LOOP_NONE:
				looped_animations.append(animation_name)
		for expected_name in EXPECTED_ANIMATIONS:
			if not player.has_animation(expected_name):
				errors.append("Missing animation: %s" % expected_name)
		if animation_names.size() != EXPECTED_ANIMATIONS.size():
			errors.append("Expected exactly 7 animations, got %d" % animation_names.size())
		for animation_name in EXPECTED_LOOPED:
			if animation_name not in looped_animations:
				errors.append("Expected looped animation: %s" % animation_name)
		for animation_name in looped_animations:
			if animation_name not in EXPECTED_LOOPED:
				errors.append("Unexpected looped animation: %s" % animation_name)
	if not empty_animations.is_empty():
		errors.append("Empty animations: %s" % str(empty_animations))

	validation_report = {
		"passed": errors.is_empty(),
		"errors": errors,
		"skeleton_count": skeletons.size(),
		"bone_count": bone_names.size(),
		"bones": bone_names,
		"root_bones": root_bones,
		"mesh_instance_count": meshes.size(),
		"mesh_vertices": mesh_vertices,
		"mesh_triangles": mesh_triangles,
		"mesh_aabb": mesh_aabb,
		"has_skin": has_skin,
		"material_count": material_count,
		"maximum_influences": maximum_influences,
		"animations": animation_names,
		"animation_lengths": animation_lengths,
		"looped_animations": looped_animations,
		"empty_animations": empty_animations,
	}
	validation_finished.emit(validation_report)
	return validation_report
