extends Node3D

const EXPECTED_GLB_SHA256 := "a9fecca234ec89d5309421f16b5e33d5b1d7d00c183423bb51dd3100cfd76931"
const OUTPUT_DIR := "C:/Blender_AI_Test/Output/godot_elf_visual_component"
const OUTPUT_FILE := OUTPUT_DIR + "/component_validation.json"
const ANIMATION_ORDER: Array[StringName] = [
	ElfVisual3D.ANIM_IDLE,
	ElfVisual3D.ANIM_WALK,
	ElfVisual3D.ANIM_RUN,
	ElfVisual3D.ANIM_CAST_FULL,
	ElfVisual3D.ANIM_CAST_START,
	ElfVisual3D.ANIM_CAST_HOLD,
	ElfVisual3D.ANIM_CAST_END,
	ElfVisual3D.ANIM_HIT,
	ElfVisual3D.ANIM_DEATH,
]

@onready var visual: ElfVisual3D = $ElfVisual3D
@onready var equipment_pool: Node3D = $EquipmentPool
@onready var debug_left_item: Node3D = $EquipmentPool/DebugLeftItem
@onready var debug_right_item: Node3D = $EquipmentPool/DebugRightItem
@onready var camera_three_quarter: Camera3D = $CameraThreeQuarter
@onready var camera_side: Camera3D = $CameraSide
@onready var animation_label: Label = $UI/Panel/Margin/VBox/Animation
@onready var camera_label: Label = $UI/Panel/Margin/VBox/Camera
@onready var socket_label: Label = $UI/Panel/Margin/VBox/Sockets
@onready var signal_label: Label = $UI/Panel/Margin/VBox/Signals
@onready var status_label: Label = $UI/Panel/Margin/VBox/Status

var _using_side_camera := false
var _started_signals: Array[String] = []
var _finished_signals: Array[String] = []
var _death_signal_count := 0
var _cast_release_signal_count := 0
var _hit_signal_count := 0
var _structural_result: Dictionary = {}
var _captured_screenshots: Array[String] = []
var _auto_test_running := false


func _ready() -> void:
	camera_three_quarter.look_at(Vector3(0.0, 0.72, 0.0))
	camera_side.look_at(Vector3(0.0, 0.72, 0.0))
	_set_side_camera(false)
	_connect_visual_signals()
	await get_tree().process_frame
	_structural_result = _run_structural_validation()
	_print_structural_validation(_structural_result)
	var user_args := OS.get_cmdline_user_args()
	if "--elf-component-auto-test" in user_args:
		_auto_test_running = true
		_run_automated_validation("--elf-component-auto-exit" in user_args)
	else:
		visual.clear_left_hand()
		visual.clear_right_hand()
		visual.set_socket_debug_visible(true)
		visual.reset_to_idle()


func _process(_delta: float) -> void:
	_update_ui()


func _unhandled_key_input(event: InputEvent) -> void:
	if _auto_test_running or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			var index := int(event.keycode) - int(KEY_1)
			if index < ANIMATION_ORDER.size():
				visual.play_animation(ANIMATION_ORDER[index])
		KEY_L:
			visual.set_socket_debug_visible(not visual.show_socket_debug)
		KEY_G:
			_toggle_left_item()
		KEY_D:
			_toggle_right_item()
		KEY_C:
			_set_side_camera(not _using_side_camera)
		KEY_R:
			visual.reset_to_idle()


func _connect_visual_signals() -> void:
	visual.animation_started.connect(func(animation_name: StringName) -> void:
		_started_signals.append(str(animation_name))
	)
	visual.animation_finished.connect(func(animation_name: StringName) -> void:
		_finished_signals.append(str(animation_name))
	)
	visual.death_animation_finished.connect(func() -> void:
		_death_signal_count += 1
	)
	visual.cast_release_reached.connect(func() -> void:
		_cast_release_signal_count += 1
	)
	visual.hit_reaction_finished.connect(func() -> void:
		_hit_signal_count += 1
	)


func _run_structural_validation() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var player := visual.get_animation_player()
	var skeleton := visual.get_skeleton()
	var model_root := visual.get_node_or_null("ModelPivot/ElfModel")
	var imported_meshes: Array[Node] = []
	if model_root != null:
		imported_meshes = model_root.find_children("*", "MeshInstance3D", true, false)
	if player == null:
		errors.append("AnimationPlayer introuvable")
	if skeleton == null:
		errors.append("Skeleton3D introuvable")
	if imported_meshes.size() != 1:
		errors.append("Un MeshInstance3D importé attendu, trouvé : %d" % imported_meshes.size())
	if skeleton != null and skeleton.get_bone_count() != 24:
		errors.append("24 os attendus, trouvé : %d" % skeleton.get_bone_count())
	if skeleton != null and not skeleton.global_transform.basis.get_scale().is_equal_approx(Vector3.ONE):
		warnings.append(
			"Le squelette importé utilise une échelle globale %s ; les équipements doivent respecter les unités du rig."
			% str(skeleton.global_transform.basis.get_scale())
		)
	warnings.append("cast_release_normalized_time=0.32 doit être calibré visuellement avec le futur effet de sort.")
	warnings.append("Elf_Death conserve son déplacement Hips importé ; aucun root motion n’est extrait.")
	warnings.append(
		"Le clip provisoire de tir est chargé comme Animation externe et conserve une légère translation Hips."
	)
	var missing_animations: Array[String] = []
	if player != null:
		for animation_name in ANIMATION_ORDER:
			if not player.has_animation(animation_name):
				missing_animations.append(str(animation_name))
	if not missing_animations.is_empty():
		errors.append("Animations manquantes : %s" % str(missing_animations))
	if player != null and not player.has_animation(ElfVisual3D.ANIM_BOW_SHOT):
		errors.append("Animation provisoire de tir à l'arc manquante.")
	elif player != null:
		var bow_animation := player.get_animation(ElfVisual3D.ANIM_BOW_SHOT)
		if not is_equal_approx(bow_animation.length, 0.7):
			errors.append(
				"Durée inattendue pour le tir à l'arc : %.6f s." % bow_animation.length
			)
	var left_socket := visual.find_child("WeaponSocketLeft", true, false) as BoneAttachment3D
	var right_socket := visual.find_child("WeaponSocketRight", true, false) as BoneAttachment3D
	var left_marker := visual.find_child("DebugLeftHandMarker", true, false) as Node3D
	var right_marker := visual.find_child("DebugRightHandMarker", true, false) as Node3D
	if left_socket == null or right_socket == null:
		errors.append("Deux BoneAttachment3D sont requis")
	else:
		if left_socket.bone_name == right_socket.bone_name:
			errors.append("Les sockets utilisent le même os")
		if skeleton != null:
			if skeleton.find_bone(left_socket.bone_name) < 0:
				errors.append("Os gauche invalide : %s" % left_socket.bone_name)
			if skeleton.find_bone(right_socket.bone_name) < 0:
				errors.append("Os droit invalide : %s" % right_socket.bone_name)
		if left_socket.override_pose or right_socket.override_pose:
			errors.append("override_pose doit rester désactivé")
		if not left_socket.use_external_skeleton or not right_socket.use_external_skeleton:
			errors.append("Les sockets doivent utiliser le squelette externe")
		if left_socket.get_skeleton() != skeleton or right_socket.get_skeleton() != skeleton:
			errors.append("Un socket ne résout pas le Skeleton3D importé")
	if visual.get_left_weapon_mount() == null or visual.get_right_weapon_mount() == null:
		errors.append("WeaponMount gauche ou droit introuvable")
	else:
		if not visual.get_left_weapon_mount().transform.is_equal_approx(Transform3D.IDENTITY):
			errors.append("WeaponMountLeft n’est pas à Transform3D.IDENTITY")
		if not visual.get_right_weapon_mount().transform.is_equal_approx(Transform3D.IDENTITY):
			errors.append("WeaponMountRight n’est pas à Transform3D.IDENTITY")
	if visual.show_socket_debug:
		errors.append("show_socket_debug doit être faux par défaut")
	if left_marker == null or right_marker == null:
		errors.append("Marqueur de socket gauche ou droit introuvable")
	elif left_marker.visible or right_marker.visible:
		errors.append("Les marqueurs doivent être cachés par défaut")
	var glb_hash := FileAccess.get_sha256("res://assets/characters/elf/elf_character_v01.glb")
	if glb_hash.to_lower() != EXPECTED_GLB_SHA256:
		errors.append("SHA-256 du GLB inattendu : %s" % glb_hash)
	return {
		"errors": errors,
		"warnings": warnings,
		"animation_player_path": str(visual.get_path_to(player)) if player != null else "",
		"skeleton_path": str(visual.get_path_to(skeleton)) if skeleton != null else "",
		"mesh_path": str(visual.get_path_to(imported_meshes[0])) if imported_meshes.size() == 1 else "",
		"bone_count": skeleton.get_bone_count() if skeleton != null else 0,
		"animation_count": player.get_animation_list().size() if player != null else 0,
		"left_bone": left_socket.bone_name if left_socket != null else "",
		"right_bone": right_socket.bone_name if right_socket != null else "",
		"left_external_skeleton": str(left_socket.external_skeleton) if left_socket != null else "",
		"right_external_skeleton": str(right_socket.external_skeleton) if right_socket != null else "",
		"glb_sha256": glb_hash,
	}


func _run_automated_validation(exit_when_done: bool) -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	errors.append_array(_structural_result.get("errors", []) as Array)
	warnings.append_array(_structural_result.get("warnings", []) as Array)
	var player := visual.get_animation_player()
	var skeleton := visual.get_skeleton()
	var imported_mesh := _get_imported_mesh()
	if not errors.is_empty() or player == null or skeleton == null or imported_mesh == null:
		_finish_automated_validation(errors, warnings, [], exit_when_done)
		return
	var baseline_glb_hash := FileAccess.get_sha256("res://assets/characters/elf/elf_character_v01.glb")
	var baseline_skeleton := _skeleton_signature(skeleton)
	var baseline_mesh := _mesh_signature(imported_mesh)
	var baseline_visual_transform := visual.transform
	var original_left_transform := debug_left_item.transform
	var original_right_transform := debug_right_item.transform
	visual.attach_to_left_hand(null)
	visual.attach_to_right_hand(null)
	visual.attach_to_left_hand(debug_left_item)
	visual.attach_to_right_hand(debug_right_item)
	await get_tree().process_frame
	_assert(debug_left_item.get_parent() == visual.get_left_weapon_mount(), "Objet gauche non parenté au WeaponMountLeft", errors)
	_assert(debug_right_item.get_parent() == visual.get_right_weapon_mount(), "Objet droit non parenté au WeaponMountRight", errors)
	_assert(debug_left_item.transform.is_equal_approx(Transform3D.IDENTITY), "Transform local gauche non réinitialisé", errors)
	_assert(debug_right_item.transform.is_equal_approx(Transform3D.IDENTITY), "Transform local droit non réinitialisé", errors)
	visual.attach_to_right_hand(debug_left_item)
	await get_tree().process_frame
	_assert(visual.get_left_hand_item() == null, "Le déplacement gauche vers droite n’a pas libéré la main gauche", errors)
	_assert(visual.get_right_hand_item() == debug_left_item, "Le remplacement de l’objet droit a échoué", errors)
	visual.clear_right_hand()
	visual.attach_to_left_hand(debug_left_item)
	visual.attach_to_right_hand(debug_right_item)
	visual.set_socket_debug_visible(true)
	await get_tree().process_frame
	var observations: Array[Dictionary] = []
	for animation_name in [
		ElfVisual3D.ANIM_IDLE,
		ElfVisual3D.ANIM_WALK,
		ElfVisual3D.ANIM_RUN,
		ElfVisual3D.ANIM_CAST_FULL,
		ElfVisual3D.ANIM_HIT,
		ElfVisual3D.ANIM_DEATH,
	]:
		observations.append(await _observe_animation(animation_name, errors))
	# L'observation de Death verrouille volontairement le composant. Les tests
	# d'API indépendants qui suivent doivent repartir d'un état vivant.
	visual.reset_to_idle()
	await get_tree().process_frame
	var cast_release_before := _cast_release_signal_count
	visual.play_cast_full(8.0)
	await get_tree().create_timer(player.get_animation(ElfVisual3D.ANIM_CAST_FULL).length / 8.0 + 0.12).timeout
	_assert(_cast_release_signal_count == cast_release_before + 1, "cast_release_reached n’a pas été émis exactement une fois", errors)
	_assert(visual.get_current_animation() == ElfVisual3D.ANIM_IDLE, "Cast Full ne retourne pas vers Idle", errors)
	var hit_before := _hit_signal_count
	visual.play_hit(8.0)
	await get_tree().create_timer(player.get_animation(ElfVisual3D.ANIM_HIT).length / 8.0 + 0.12).timeout
	_assert(_hit_signal_count == hit_before + 1, "hit_reaction_finished non émis", errors)
	_assert(visual.get_current_animation() == ElfVisual3D.ANIM_IDLE, "Hit ne retourne pas vers Idle", errors)
	var hold_starts_before := _count_signal_name(_started_signals, str(ElfVisual3D.ANIM_CAST_HOLD))
	visual.play_cast_start(12.0)
	await get_tree().create_timer(player.get_animation(ElfVisual3D.ANIM_CAST_START).length / 12.0 + 0.08).timeout
	_assert(_count_signal_name(_started_signals, str(ElfVisual3D.ANIM_CAST_HOLD)) == hold_starts_before, "Cast Start a lancé Cast Hold automatiquement", errors)
	visual.play_cast_hold(12.0)
	await get_tree().process_frame
	var starts_after_hold_started := _started_signals.size()
	await get_tree().create_timer(player.get_animation(ElfVisual3D.ANIM_CAST_HOLD).length / 12.0 + 0.08).timeout
	_assert(player.get_animation(ElfVisual3D.ANIM_CAST_HOLD).loop_mode == Animation.LOOP_NONE, "Cast Hold est cyclique", errors)
	_assert(_started_signals.size() == starts_after_hold_started, "Cast Hold a lancé une transition automatique", errors)
	visual.play_cast_end(12.0)
	await get_tree().create_timer(player.get_animation(ElfVisual3D.ANIM_CAST_END).length / 12.0 + 0.1).timeout
	_assert(visual.get_current_animation() == ElfVisual3D.ANIM_IDLE, "Cast End ne retourne pas vers Idle", errors)
	var death_before := _death_signal_count
	var idle_starts_before_death := _count_signal_name(_started_signals, str(ElfVisual3D.ANIM_IDLE))
	visual.play_death(8.0)
	await get_tree().create_timer(player.get_animation(ElfVisual3D.ANIM_DEATH).length / 8.0 + 0.12).timeout
	_assert(_death_signal_count == death_before + 1, "death_animation_finished non émis", errors)
	_assert(_count_signal_name(_started_signals, str(ElfVisual3D.ANIM_IDLE)) == idle_starts_before_death, "Death est revenu automatiquement vers Idle", errors)
	_assert(visual.transform.is_equal_approx(baseline_visual_transform), "Death a déplacé le nœud racine ElfVisual3D", errors)
	visual.play_animation(&"Animation_Inconnue")
	visual.stop_animation()
	visual.play_animation(ElfVisual3D.ANIM_IDLE, 2.0, 0.0)
	await get_tree().process_frame
	_assert(visual.is_animation_playing(ElfVisual3D.ANIM_IDLE), "play_animation valide a échoué", errors)
	visual.stop_animation()
	visual.reset_to_idle()
	_assert(visual.get_current_animation() == ElfVisual3D.ANIM_IDLE, "reset_to_idle a échoué", errors)
	_assert(visual.is_animation_playing(ElfVisual3D.ANIM_IDLE), "is_animation_playing ne reconnaît pas Idle", errors)
	_assert(is_equal_approx(player.speed_scale, 1.0), "La vitesse globale de l’AnimationPlayer n’est pas revenue à 1", errors)
	visual.clear_left_hand()
	visual.clear_right_hand()
	await get_tree().process_frame
	_assert(debug_left_item.get_parent() == equipment_pool, "clear_left_hand n’a pas restauré le parent initial", errors)
	_assert(debug_right_item.get_parent() == equipment_pool, "clear_right_hand n’a pas restauré le parent initial", errors)
	_assert(debug_left_item.transform.is_equal_approx(original_left_transform), "clear_left_hand n’a pas restauré le transform initial", errors)
	_assert(debug_right_item.transform.is_equal_approx(original_right_transform), "clear_right_hand n’a pas restauré le transform initial", errors)
	_assert(_skeleton_signature(skeleton) == baseline_skeleton, "Le squelette ou sa pose de repos ont été modifiés", errors)
	_assert(_mesh_signature(imported_mesh) == baseline_mesh, "Le mesh importé a été modifié", errors)
	_assert(FileAccess.get_sha256("res://assets/characters/elf/elf_character_v01.glb") == baseline_glb_hash, "Le fichier GLB a été modifié", errors)
	_assert(ElfVisual3D.ANIM_CAST_FULL in _finished_signals, "animation_finished absent pour Cast Full", errors)
	_assert(ElfVisual3D.ANIM_HIT in _finished_signals, "animation_finished absent pour Hit", errors)
	_assert(ElfVisual3D.ANIM_DEATH in _finished_signals, "animation_finished absent pour Death", errors)
	visual.set_socket_debug_visible(true)
	visual.reset_to_idle()
	_finish_automated_validation(errors, warnings, observations, exit_when_done)


func _observe_animation(animation_name: StringName, errors: Array[String]) -> Dictionary:
	var player := visual.get_animation_player()
	var animation := player.get_animation(animation_name)
	var speed := 6.0
	match animation_name:
		ElfVisual3D.ANIM_IDLE:
			speed = 1.0
			visual.play_idle(0.0)
		ElfVisual3D.ANIM_WALK:
			visual.play_walk(speed, 0.0)
		ElfVisual3D.ANIM_RUN:
			visual.play_run(speed, 0.0)
		ElfVisual3D.ANIM_CAST_FULL:
			visual.play_cast_full(speed)
		ElfVisual3D.ANIM_HIT:
			visual.play_hit(speed)
		ElfVisual3D.ANIM_DEATH:
			visual.play_death(speed)
		_:
			visual.play_animation(animation_name, speed, 0.0)
	await get_tree().process_frame
	var left_mount := visual.get_left_weapon_mount()
	var right_mount := visual.get_right_weapon_mount()
	var initial_left_relative := left_mount.global_transform.affine_inverse() * debug_left_item.global_transform
	var initial_right_relative := right_mount.global_transform.affine_inverse() * debug_right_item.global_transform
	var initial_left_global_scale := debug_left_item.global_transform.basis.get_scale()
	var initial_right_global_scale := debug_right_item.global_transform.basis.get_scale()
	await get_tree().create_timer(animation.length / speed * 0.5).timeout
	var screenshot := await _capture_frame(str(animation_name).to_lower())
	var mid_left_relative := left_mount.global_transform.affine_inverse() * debug_left_item.global_transform
	var mid_right_relative := right_mount.global_transform.affine_inverse() * debug_right_item.global_transform
	_assert(initial_left_relative.is_equal_approx(mid_left_relative), "%s : objet gauche instable relativement à la main" % animation_name, errors)
	_assert(initial_right_relative.is_equal_approx(mid_right_relative), "%s : objet droit instable relativement à la main" % animation_name, errors)
	_assert(debug_left_item.scale.is_equal_approx(Vector3.ONE), "%s : scale locale gauche modifiée" % animation_name, errors)
	_assert(debug_right_item.scale.is_equal_approx(Vector3.ONE), "%s : scale locale droite modifiée" % animation_name, errors)
	_assert(debug_left_item.global_transform.basis.get_scale().is_equal_approx(initial_left_global_scale), "%s : scale globale gauche instable" % animation_name, errors)
	_assert(debug_right_item.global_transform.basis.get_scale().is_equal_approx(initial_right_global_scale), "%s : scale globale droite instable" % animation_name, errors)
	await get_tree().create_timer(animation.length / speed * 0.55 + 0.03).timeout
	if animation.loop_mode != Animation.LOOP_NONE:
		visual.stop_animation()
	return {
		"animation": str(animation_name),
		"length": animation.length,
		"speed": speed,
		"left_relative_stable": initial_left_relative.is_equal_approx(mid_left_relative),
		"right_relative_stable": initial_right_relative.is_equal_approx(mid_right_relative),
		"screenshot": screenshot,
	}


func _finish_automated_validation(
	errors: Array[String],
	warnings: Array[String],
	observations: Array[Dictionary],
	exit_when_done: bool
) -> void:
	var result := {
		"verdict": "ELF_VISUAL_COMPONENT_VALIDATED" if errors.is_empty() and warnings.is_empty() else (
			"ELF_VISUAL_COMPONENT_VALIDATED_WITH_WARNINGS" if errors.is_empty() else "ELF_VISUAL_COMPONENT_REJECTED"
		),
		"structural": _structural_result,
		"errors": errors,
		"warnings": warnings,
		"observations": observations,
		"signals": {
			"animation_started": _started_signals,
			"animation_finished": _finished_signals,
			"death_animation_finished": _death_signal_count,
			"cast_release_reached": _cast_release_signal_count,
			"hit_reaction_finished": _hit_signal_count,
		},
		"screenshots": _captured_screenshots,
	}
	var output := FileAccess.open(OUTPUT_FILE, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(result, "  "))
		output.close()
	else:
		errors.append("Impossible d’écrire %s" % OUTPUT_FILE)
	print("ELF_VISUAL_COMPONENT_RESULT=", JSON.stringify(result))
	_auto_test_running = false
	if exit_when_done:
		get_tree().quit(0 if errors.is_empty() else 7)


func _capture_frame(suffix: String) -> String:
	await RenderingServer.frame_post_draw
	var output_path := "%s/%s.png" % [OUTPUT_DIR, suffix]
	var image := get_viewport().get_texture().get_image()
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_warning("Impossible d’enregistrer la capture %s" % output_path)
		return ""
	_captured_screenshots.append(output_path)
	return output_path


func _get_imported_mesh() -> MeshInstance3D:
	var model_root := visual.get_node_or_null("ModelPivot/ElfModel")
	if model_root == null:
		return null
	var meshes: Array[Node] = model_root.find_children("*", "MeshInstance3D", true, false)
	return meshes[0] as MeshInstance3D if meshes.size() == 1 else null


func _skeleton_signature(skeleton: Skeleton3D) -> String:
	var parts: Array[String] = []
	for bone_index in skeleton.get_bone_count():
		parts.append("%d|%s|%d|%s" % [
			bone_index,
			skeleton.get_bone_name(bone_index),
			skeleton.get_bone_parent(bone_index),
			str(skeleton.get_bone_global_rest(bone_index)),
		])
	return "\n".join(parts)


func _mesh_signature(mesh_instance: MeshInstance3D) -> String:
	var mesh := mesh_instance.mesh
	var parts: Array[String] = [
		str(mesh.get_instance_id()),
		str(mesh.get_surface_count()),
		str(mesh_instance.skin.get_instance_id() if mesh_instance.skin != null else 0),
	]
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		parts.append("%d|%d|%d|%d" % [
			mesh.surface_get_format(surface_index),
			(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
			(arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size(),
			(arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array).size(),
		])
	return "\n".join(parts)


func _assert(condition: bool, message: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(message)


func _count_signal_name(values: Array[String], expected_name: String) -> int:
	var count := 0
	for value in values:
		if value == expected_name:
			count += 1
	return count


func _toggle_left_item() -> void:
	if visual.get_left_hand_item() == null:
		visual.attach_to_left_hand(debug_left_item)
	else:
		visual.clear_left_hand()


func _toggle_right_item() -> void:
	if visual.get_right_hand_item() == null:
		visual.attach_to_right_hand(debug_right_item)
	else:
		visual.clear_right_hand()


func _set_side_camera(enabled: bool) -> void:
	_using_side_camera = enabled
	camera_three_quarter.current = not enabled
	camera_side.current = enabled


func _update_ui() -> void:
	if visual == null:
		return
	animation_label.text = "Animation : %s" % visual.get_current_animation()
	camera_label.text = "Caméra : %s" % ("latérale" if _using_side_camera else "trois-quarts")
	socket_label.text = "Sockets : %s | gauche=%s | droite=%s" % [
		"visibles" if visual.show_socket_debug else "masqués",
		"attaché" if visual.get_left_hand_item() != null else "libre",
		"attaché" if visual.get_right_hand_item() != null else "libre",
	]
	signal_label.text = "Signaux : start=%d finish=%d release=%d hit=%d death=%d" % [
		_started_signals.size(),
		_finished_signals.size(),
		_cast_release_signal_count,
		_hit_signal_count,
		_death_signal_count,
	]
	status_label.text = "Structure : %s" % (
		"OK" if (_structural_result.get("errors", []) as Array).is_empty() else "ERREUR"
	)


func _print_structural_validation(result: Dictionary) -> void:
	print("\n========== ELF VISUAL COMPONENT ==========")
	print(JSON.stringify(result, "  "))
	print("==========================================\n")
