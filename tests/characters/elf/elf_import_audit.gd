class_name ElfImportAudit
extends RefCounted

const EXPECTED_ANIMATIONS: Array[String] = [
	"Elf_Idle",
	"Elf_Walk",
	"Elf_Run",
	"Elf_Cast_Full",
	"Elf_Cast_Start",
	"Elf_Cast_Hold",
	"Elf_Cast_End",
	"Elf_Hit",
	"Elf_Death",
]

const EXPECTED_LOOPS: Array[String] = [
	"Elf_Idle",
	"Elf_Walk",
	"Elf_Run",
]

const SOURCE_TO_IMPORTED_ANIMATION_NAMES := {
	"Elf_Idle-loop": "Elf_Idle",
	"Elf_Walk-loop": "Elf_Walk",
	"Elf_Run-loop": "Elf_Run",
}


static func audit_instance(instance: Node) -> Dictionary:
	var hierarchy: Array[String] = []
	_collect_hierarchy(instance, "", hierarchy)
	var skeletons: Array[Node] = instance.find_children("*", "Skeleton3D", true, false)
	var mesh_instances: Array[Node] = instance.find_children("*", "MeshInstance3D", true, false)
	var animation_players: Array[Node] = instance.find_children("*", "AnimationPlayer", true, false)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	warnings.append(
		"Godot used the -loop suffix as an import hint and normalized "
		+ "Elf_Idle-loop/Elf_Walk-loop/Elf_Run-loop to Elf_Idle/Elf_Walk/Elf_Run; "
		+ "their loop modes remain enabled."
	)

	if skeletons.size() != 1:
		errors.append("Expected exactly one Skeleton3D, found %d" % skeletons.size())
	if mesh_instances.size() != 1:
		errors.append("Expected exactly one MeshInstance3D, found %d" % mesh_instances.size())
	if animation_players.size() != 1:
		errors.append("Expected exactly one AnimationPlayer, found %d" % animation_players.size())

	var skeleton_data: Dictionary = {}
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	if skeleton != null:
		var bone_names: Array[String] = []
		var roots: Array[String] = []
		var parents: Dictionary = {}
		for bone_index in skeleton.get_bone_count():
			var bone_name := skeleton.get_bone_name(bone_index)
			bone_names.append(bone_name)
			var parent_index := skeleton.get_bone_parent(bone_index)
			parents[bone_name] = skeleton.get_bone_name(parent_index) if parent_index >= 0 else ""
			if parent_index < 0:
				roots.append(bone_name)
		skeleton_data = {
			"node_path": str(instance.get_path_to(skeleton)),
			"bone_count": skeleton.get_bone_count(),
			"bone_names": bone_names,
			"roots": roots,
			"parents": parents,
		}
		if skeleton.get_bone_count() != 24:
			errors.append("Expected 24 bones, found %d" % skeleton.get_bone_count())
		if roots != ["Hips"]:
			errors.append("Expected Hips as unique root bone, found %s" % str(roots))

	var surface_results: Array[Dictionary] = []
	var mesh_results: Array[Dictionary] = []
	var total_surfaces := 0
	var total_vertices := 0
	var total_indices := 0
	var total_invalid_bone_references := 0
	var total_bad_weight_sums := 0
	var total_negative_weights := 0
	var material_present := false
	var texture_present := false
	var skin_present := false
	var combined_aabb := AABB()
	var has_combined_aabb := false

	for node in mesh_instances:
		var mesh_instance := node as MeshInstance3D
		var mesh_resource := mesh_instance.mesh
		var mesh_aabb := mesh_instance.get_aabb()
		if not has_combined_aabb:
			combined_aabb = mesh_aabb
			has_combined_aabb = true
		else:
			combined_aabb = combined_aabb.merge(mesh_aabb)
		var mesh_result := {
			"node_path": str(instance.get_path_to(mesh_instance)),
			"mesh_name": mesh_resource.resource_name if mesh_resource != null else "",
			"surface_count": mesh_resource.get_surface_count() if mesh_resource != null else 0,
			"aabb_position": _vec3_to_array(mesh_aabb.position),
			"aabb_size": _vec3_to_array(mesh_aabb.size),
			"skin_present": mesh_instance.skin != null,
		}
		skin_present = skin_present or mesh_instance.skin != null
		if mesh_resource == null:
			errors.append("MeshInstance3D has no Mesh resource: %s" % mesh_instance.name)
			mesh_results.append(mesh_result)
			continue
		total_surfaces += mesh_resource.get_surface_count()
		for surface_index in mesh_resource.get_surface_count():
			var surface_format: int = int(mesh_resource.surface_get_format(surface_index))
			var use_eight: bool = bool(surface_format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			var arrays: Array = mesh_resource.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var weights_per_vertex: int = 8 if use_eight else 4
			if vertices.size() > 0 and weights.size() / vertices.size() in [4, 8]:
				weights_per_vertex = weights.size() / vertices.size()
			var histogram := {}
			for count in range(1, 9):
				histogram[str(count)] = 0
			var zero_influence_vertices := 0
			var maximum_nonzero := 0
			var minimum_weight_sum := INF
			var maximum_weight_sum := -INF
			var bad_weight_sums := 0
			var negative_weights := 0
			var invalid_bone_references := 0
			for vertex_index in vertices.size():
				var nonzero := 0
				var weight_sum := 0.0
				for influence_index in weights_per_vertex:
					var array_index := vertex_index * weights_per_vertex + influence_index
					if array_index >= weights.size() or array_index >= bones.size():
						continue
					var weight := float(weights[array_index])
					var bone_reference := int(bones[array_index])
					if weight < 0.0:
						negative_weights += 1
					if weight > 0.0:
						nonzero += 1
						weight_sum += weight
						if skeleton != null and (bone_reference < 0 or bone_reference >= skeleton.get_bone_count()):
							invalid_bone_references += 1
				maximum_nonzero = max(maximum_nonzero, nonzero)
				if nonzero == 0:
					zero_influence_vertices += 1
				elif nonzero <= 8:
					histogram[str(nonzero)] += 1
				minimum_weight_sum = min(minimum_weight_sum, weight_sum)
				maximum_weight_sum = max(maximum_weight_sum, weight_sum)
				if abs(weight_sum - 1.0) > 0.001:
					bad_weight_sums += 1
			var material := mesh_resource.surface_get_material(surface_index)
			var has_texture := false
			if material is BaseMaterial3D:
				has_texture = (material as BaseMaterial3D).albedo_texture != null
			material_present = material_present or material != null
			texture_present = texture_present or has_texture
			var surface_result := {
				"mesh_path": str(instance.get_path_to(mesh_instance)),
				"surface": surface_index,
				"format": surface_format,
				"uses_8_bone_weights_flag": use_eight,
				"vertex_count": vertices.size(),
				"index_count": indices.size(),
				"weights_array_count": weights.size(),
				"bones_array_count": bones.size(),
				"weights_per_vertex": weights_per_vertex,
				"maximum_nonzero_weights": maximum_nonzero,
				"nonzero_weight_histogram": histogram,
				"zero_influence_vertices": zero_influence_vertices,
				"minimum_weight_sum": minimum_weight_sum,
				"maximum_weight_sum": maximum_weight_sum,
				"bad_weight_sum_vertices": bad_weight_sums,
				"negative_weights": negative_weights,
				"invalid_bone_references": invalid_bone_references,
				"material_present": material != null,
				"material_name": material.resource_name if material != null else "",
				"texture_present": has_texture,
			}
			surface_results.append(surface_result)
			total_vertices += vertices.size()
			total_indices += indices.size()
			total_invalid_bone_references += invalid_bone_references
			total_bad_weight_sums += bad_weight_sums
			total_negative_weights += negative_weights
			if not use_eight:
				warnings.append("Surface %d is imported with four bone-weight slots" % surface_index)
			else:
				warnings.append("Surface %d is imported with eight bone-weight slots" % surface_index)
			if maximum_nonzero > 4:
				warnings.append("Surface %d uses up to %d non-zero bone weights" % [surface_index, maximum_nonzero])
		mesh_results.append(mesh_result)

	if not skin_present:
		errors.append("Imported mesh has no Skin")
	if not material_present:
		errors.append("Imported mesh has no material")
	if not texture_present:
		errors.append("Imported material has no albedo texture")
	if total_invalid_bone_references > 0:
		errors.append("Found %d references to nonexistent bones" % total_invalid_bone_references)
	if total_bad_weight_sums > 0:
		errors.append("Found %d vertices whose weight sum differs from 1 by more than 0.001" % total_bad_weight_sums)
	if total_negative_weights > 0:
		errors.append("Found %d negative weights" % total_negative_weights)

	var animation_results: Array[Dictionary] = []
	var animation_names: Array[String] = []
	if not animation_players.is_empty():
		var player := animation_players[0] as AnimationPlayer
		for animation_name_value in player.get_animation_list():
			var animation_name := str(animation_name_value)
			var animation := player.get_animation(animation_name_value)
			var loops := animation.loop_mode != Animation.LOOP_NONE
			animation_names.append(animation_name)
			animation_results.append({
				"name": animation_name,
				"length": animation.length,
				"loop_mode": animation.loop_mode,
				"loops": loops,
				"track_count": animation.get_track_count(),
			})
			if animation_name in EXPECTED_LOOPS and not loops:
				errors.append("Expected looping animation is not looped: %s" % animation_name)
			if animation_name not in EXPECTED_LOOPS and loops:
				errors.append("Unexpected animation is looped: %s" % animation_name)
	var sorted_actual := animation_names.duplicate()
	sorted_actual.sort()
	var sorted_expected := EXPECTED_ANIMATIONS.duplicate()
	sorted_expected.sort()
	if sorted_actual != sorted_expected:
		errors.append("Animation list mismatch. Expected %s, found %s" % [str(sorted_expected), str(sorted_actual)])

	if has_combined_aabb:
		var largest_extent: float = maxf(maxf(combined_aabb.size.x, combined_aabb.size.y), combined_aabb.size.z)
		if largest_extent > 10.0 or largest_extent < 0.5:
			warnings.append("Character AABB has an unusual largest extent: %.6f" % largest_extent)

	return {
		"root_type": instance.get_class(),
		"root_name": instance.name,
		"hierarchy": hierarchy,
		"skeleton_count": skeletons.size(),
		"skeleton": skeleton_data,
		"mesh_instance_count": mesh_instances.size(),
		"meshes": mesh_results,
		"surface_count": total_surfaces,
		"surfaces": surface_results,
		"skin_present": skin_present,
		"material_present": material_present,
		"texture_present": texture_present,
		"animation_player_count": animation_players.size(),
		"animations": animation_results,
		"source_to_imported_animation_names": SOURCE_TO_IMPORTED_ANIMATION_NAMES,
		"aabb_position": _vec3_to_array(combined_aabb.position) if has_combined_aabb else [],
		"aabb_size": _vec3_to_array(combined_aabb.size) if has_combined_aabb else [],
		"total_vertices": total_vertices,
		"total_indices": total_indices,
		"total_invalid_bone_references": total_invalid_bone_references,
		"total_bad_weight_sum_vertices": total_bad_weight_sums,
		"total_negative_weights": total_negative_weights,
		"errors": errors,
		"warnings": warnings,
	}


static func _collect_hierarchy(node: Node, prefix: String, output: Array[String]) -> void:
	output.append("%s%s [%s]" % [prefix, node.name, node.get_class()])
	for child in node.get_children():
		_collect_hierarchy(child, prefix + "  ", output)


static func _vec3_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
