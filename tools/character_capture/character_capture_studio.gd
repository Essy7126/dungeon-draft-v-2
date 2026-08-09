class_name CharacterCaptureStudio
extends Node

## Studio autonome de capture statique de personnages 3D.
## Le sujet est chargé depuis character_scene_path et n'est jamais modifié.

const CAPTURE_DIRECTIONS: Array[StringName] = [&"SE", &"SW", &"NW", &"NE"]
const DEFAULT_BASE_CHARACTER_YAW_DEGREES := 0.0
const CAMERA_AZIMUTH_DEGREES := 45.0
const CAMERA_ELEVATION_DEGREES := 30.0
const CAMERA_DISTANCE := 4.0
const FRAMING_MARGIN_RATIO := 0.10

@export_file("*.glb", "*.gltf", "*.tscn") var character_scene_path := (
	"res://assets/characters/Achilles/"
	+ "Meshy_AI_Spartan_of_the_Sun_0809102017_texture.glb"
)
@export var subject_slug := "achilles"
@export_range(-360.0, 360.0, 0.1) var base_character_yaw_degrees := (
	DEFAULT_BASE_CHARACTER_YAW_DEGREES
)
@export var capture_resolution := Vector2i(1024, 1024)

@onready var capture_viewport: SubViewport = $CaptureViewport
@onready var character_pivot: Node3D = $CaptureViewport/CaptureWorld/CharacterPivot
@onready var model_offset: Node3D = (
	$CaptureViewport/CaptureWorld/CharacterPivot/ModelOffset
)
@onready var camera: Camera3D = $CaptureViewport/CaptureWorld/CameraRig/Camera3D
@onready var preview: TextureRect = $UI/Layout/Columns/PreviewPanel/PreviewAspect/Preview
@onready var orientation_label: Label = (
	$UI/Layout/Columns/ControlsPanel/Controls/OrientationLabel
)
@onready var info_label: Label = $UI/Layout/Columns/ControlsPanel/Controls/InfoLabel
@onready var status_label: Label = $UI/Layout/Columns/ControlsPanel/Controls/StatusLabel
@onready var se_button: Button = (
	$UI/Layout/Columns/ControlsPanel/Controls/OrientationButtons/SE
)
@onready var sw_button: Button = (
	$UI/Layout/Columns/ControlsPanel/Controls/OrientationButtons/SW
)
@onready var nw_button: Button = (
	$UI/Layout/Columns/ControlsPanel/Controls/OrientationButtons/NW
)
@onready var ne_button: Button = (
	$UI/Layout/Columns/ControlsPanel/Controls/OrientationButtons/NE
)
@onready var capture_current_button: Button = (
	$UI/Layout/Columns/ControlsPanel/Controls/CaptureCurrent
)
@onready var capture_all_button: Button = (
	$UI/Layout/Columns/ControlsPanel/Controls/CaptureAll
)
@onready var transparent_toggle: CheckButton = (
	$UI/Layout/Columns/ControlsPanel/Controls/TransparentBackground
)

var current_orientation: StringName = &"SE"
var subject: Node3D = null
var source_bounds := AABB()
var normalized_bounds := AABB()
var framing_union_view := Rect2()
var framing_ortho_size := 0.0
var framing_target := Vector3.ZERO
var normalized_model_points: Array[Vector3] = []
var initialized := false
var capture_busy := false


func _ready() -> void:
	_connect_ui()
	capture_viewport.size = capture_resolution
	capture_viewport.transparent_bg = transparent_toggle.button_pressed
	preview.texture = capture_viewport.get_texture()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_set_status("Chargement du sujet et calcul du cadrage...")

	if not _instantiate_subject():
		_set_status("ERREUR : impossible de charger le sujet.", true)
		_maybe_quit_automation(1)
		return

	await get_tree().process_frame
	if not _measure_and_frame_subject():
		_set_status("ERREUR : aucun MeshInstance3D exploitable.", true)
		_maybe_quit_automation(1)
		return

	initialized = true
	set_orientation(&"SE")
	_update_information()
	_set_status("Prêt — cadrage commun calculé sur les 4 orientations.")
	print("CHARACTER_CAPTURE_MODEL=", character_scene_path)
	print("CHARACTER_CAPTURE_SOURCE_BOUNDS=", source_bounds)
	print("CHARACTER_CAPTURE_NORMALIZED_BOUNDS=", normalized_bounds)
	print("CHARACTER_CAPTURE_ORTHO_SIZE=%.6f" % framing_ortho_size)
	print("CHARACTER_CAPTURE_OUTPUT=", ProjectSettings.globalize_path(_capture_directory()))

	var arguments := OS.get_cmdline_user_args()
	if arguments.has("--self-test") or arguments.has("--capture-all"):
		await _run_automation(arguments)


func _connect_ui() -> void:
	se_button.pressed.connect(_on_orientation_pressed.bind(&"SE"))
	sw_button.pressed.connect(_on_orientation_pressed.bind(&"SW"))
	nw_button.pressed.connect(_on_orientation_pressed.bind(&"NW"))
	ne_button.pressed.connect(_on_orientation_pressed.bind(&"NE"))
	capture_current_button.pressed.connect(_on_capture_current_pressed)
	capture_all_button.pressed.connect(_on_capture_all_pressed)
	transparent_toggle.toggled.connect(_on_transparent_background_toggled)


func _instantiate_subject() -> bool:
	var packed_scene := load(character_scene_path) as PackedScene
	if packed_scene == null:
		push_error("Character Capture Studio : ressource introuvable : %s" % character_scene_path)
		return false
	var instance := packed_scene.instantiate()
	if not instance is Node3D:
		instance.queue_free()
		push_error("Character Capture Studio : la racine du sujet doit être un Node3D.")
		return false
	subject = instance as Node3D
	subject.name = subject_slug.capitalize()
	model_offset.add_child(subject)
	return true


func _measure_and_frame_subject() -> bool:
	var source_points := _collect_mesh_aabb_points(character_pivot)
	if source_points.is_empty():
		return false
	source_bounds = _bounds_from_points(source_points)

	# Le GLB reste intact : ce parent runtime place le centre horizontal au pivot
	# et le point le plus bas sur Y=0, garantissant un ancrage de sol stable.
	var source_center := source_bounds.get_center()
	var normalization_offset := Vector3(
		-source_center.x,
		-source_bounds.position.y,
		-source_center.z
	)
	model_offset.position = normalization_offset
	normalized_model_points.clear()
	for point in source_points:
		normalized_model_points.append(point + normalization_offset)
	normalized_bounds = _bounds_from_points(normalized_model_points)

	_configure_common_camera_framing()
	return framing_ortho_size > 0.0


func _collect_mesh_aabb_points(relative_to: Node3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for mesh_instance in _find_mesh_instances(subject):
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		var to_reference := (
			relative_to.global_transform.affine_inverse()
			* mesh_instance.global_transform
		)
		var mesh_aabb := mesh_instance.mesh.get_aabb()
		for endpoint_index in range(8):
			points.append(to_reference * mesh_aabb.get_endpoint(endpoint_index))
	return points


func _find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		result.append(root as MeshInstance3D)
	for child in root.get_children():
		result.append_array(_find_mesh_instances(child))
	return result


func _bounds_from_points(points: Array[Vector3]) -> AABB:
	var result := AABB(points[0], Vector3.ZERO)
	for point in points:
		result = result.expand(point)
	return result


func _configure_common_camera_framing() -> void:
	var azimuth := deg_to_rad(CAMERA_AZIMUTH_DEGREES)
	var elevation := deg_to_rad(CAMERA_ELEVATION_DEGREES)
	var subject_to_camera := Vector3(
		sin(azimuth) * cos(elevation),
		sin(elevation),
		cos(azimuth) * cos(elevation)
	).normalized()

	camera.global_position = subject_to_camera * CAMERA_DISTANCE
	camera.look_at(Vector3.ZERO, Vector3.UP)
	var camera_right := camera.global_basis.x.normalized()
	var camera_up := camera.global_basis.y.normalized()
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)

	# L'union est calculée avant la capture et devient le cadrage immuable des
	# quatre directions. Aucun zoom n'est recalculé lors d'un changement de yaw.
	for direction in CAPTURE_DIRECTIONS:
		var yaw := deg_to_rad(direction_to_yaw_degrees(
			direction, base_character_yaw_degrees
		))
		for model_point in normalized_model_points:
			var world_point := model_point.rotated(Vector3.UP, yaw)
			var view_point := Vector2(
				world_point.dot(camera_right),
				world_point.dot(camera_up)
			)
			minimum = minimum.min(view_point)
			maximum = maximum.max(view_point)

	framing_union_view = Rect2(minimum, maximum - minimum)
	var view_center := framing_union_view.get_center()
	framing_target = camera_right * view_center.x + camera_up * view_center.y
	framing_ortho_size = maxf(
		framing_union_view.size.x,
		framing_union_view.size.y
	) * (1.0 + FRAMING_MARGIN_RATIO)
	camera.global_position = framing_target + subject_to_camera * CAMERA_DISTANCE
	camera.look_at(framing_target, Vector3.UP)
	camera.size = framing_ortho_size
	camera.near = 0.05
	camera.far = 20.0


static func direction_to_index(direction: StringName) -> int:
	match direction:
		&"SE":
			return 0
		&"SW":
			return 1
		&"NW":
			return 2
		&"NE":
			return 3
	return -1


static func direction_to_yaw_degrees(
		direction: StringName,
		base_yaw_degrees: float = DEFAULT_BASE_CHARACTER_YAW_DEGREES
	) -> float:
	var index := direction_to_index(direction)
	return base_yaw_degrees + float(maxi(index, 0)) * 90.0


static func capture_filename_for(subject_name: String, direction: StringName) -> String:
	return "%s_%s.png" % [subject_name.to_lower(), String(direction)]


func set_orientation(direction: StringName) -> bool:
	if direction_to_index(direction) < 0:
		push_error("Character Capture Studio : orientation inconnue : %s" % direction)
		return false
	current_orientation = direction
	character_pivot.rotation_degrees.y = direction_to_yaw_degrees(
		direction, base_character_yaw_degrees
	)
	_update_orientation_label()
	return true


func _on_orientation_pressed(direction: StringName) -> void:
	if initialized and not capture_busy:
		set_orientation(direction)
		_set_status("Orientation %s affichée — cadrage inchangé." % direction)


func _on_capture_current_pressed() -> void:
	if initialized and not capture_busy:
		await capture_current()


func _on_capture_all_pressed() -> void:
	if initialized and not capture_busy:
		await capture_all()


func _on_transparent_background_toggled(enabled: bool) -> void:
	capture_viewport.transparent_bg = enabled
	_set_status(
		"Fond transparent activé." if enabled else "Fond studio neutre activé."
	)


func capture_current() -> bool:
	_set_busy(true)
	var result: Dictionary = await _capture_orientation(current_orientation)
	_set_busy(false)
	return bool(result.get("ok", false))


func capture_all() -> bool:
	_set_busy(true)
	var saved_orientation := current_orientation
	var images := {}
	var all_ok := true
	for direction in CAPTURE_DIRECTIONS:
		var result: Dictionary = await _capture_orientation(direction)
		if bool(result.get("ok", false)):
			images[direction] = result["image"]
		else:
			all_ok = false
			break
	set_orientation(saved_orientation)
	if all_ok:
		all_ok = _save_comparison_board(images)
		_set_status(
			"4 PNG créés dans %s" % ProjectSettings.globalize_path(_capture_directory())
			if all_ok else "Les PNG sont créés, mais la planche a échoué.",
			not all_ok
		)
	_set_busy(false)
	return all_ok


func _capture_orientation(direction: StringName) -> Dictionary:
	if not set_orientation(direction):
		return {"ok": false}
	_set_status("Rendu %s en cours..." % direction)

	# Deux frames de process puis frame_post_draw empêchent de relire la texture
	# correspondant au yaw précédent.
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := capture_viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Character Capture Studio : image vide pour %s." % direction)
		return {"ok": false}
	if image.get_size() != capture_resolution:
		push_error(
			"Character Capture Studio : résolution inattendue %s au lieu de %s."
			% [image.get_size(), capture_resolution]
		)
		return {"ok": false}

	var directory_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_capture_directory())
	)
	if directory_error != OK:
		push_error("Character Capture Studio : création du dossier impossible.")
		return {"ok": false}
	var output_path := _capture_directory().path_join(
		capture_filename_for(subject_slug, direction)
	)
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Character Capture Studio : échec PNG %s (%s)." % [output_path, save_error])
		return {"ok": false}
	print("CHARACTER_CAPTURE_SAVED=", ProjectSettings.globalize_path(output_path))
	return {"ok": true, "image": image, "path": output_path}


func _save_comparison_board(images: Dictionary) -> bool:
	var board_size := capture_resolution * 2
	var board := Image.create(board_size.x, board_size.y, false, Image.FORMAT_RGBA8)
	board.fill(Color(0.86, 0.87, 0.89, 0.0 if capture_viewport.transparent_bg else 1.0))
	for index in range(CAPTURE_DIRECTIONS.size()):
		var direction := CAPTURE_DIRECTIONS[index]
		if not images.has(direction):
			return false
		var source := (images[direction] as Image).duplicate()
		source.convert(Image.FORMAT_RGBA8)
		var destination := Vector2i(
			(index % 2) * capture_resolution.x,
			(index / 2) * capture_resolution.y
		)
		board.blit_rect(
			source,
			Rect2i(Vector2i.ZERO, capture_resolution),
			destination
		)
	var comparison_path := _capture_directory().path_join(
		"%s_comparison_2x2.png" % subject_slug.to_lower()
	)
	var save_error := board.save_png(comparison_path)
	if save_error == OK:
		print("CHARACTER_CAPTURE_COMPARISON=", ProjectSettings.globalize_path(comparison_path))
		return true
	push_error("Character Capture Studio : échec de la planche (%s)." % save_error)
	return false


func _capture_directory() -> String:
	return "user://character_capture/%s" % subject_slug.to_lower()


func _set_busy(enabled: bool) -> void:
	capture_busy = enabled
	for button in [se_button, sw_button, nw_button, ne_button,
			capture_current_button, capture_all_button, transparent_toggle]:
		button.disabled = enabled


func _update_orientation_label() -> void:
	if not is_instance_valid(orientation_label):
		return
	orientation_label.text = "Orientation actuelle : %s\nYaw personnage : %.1f°" % [
		current_orientation,
		direction_to_yaw_degrees(current_orientation, base_character_yaw_degrees),
	]


func _update_information() -> void:
	info_label.text = (
		"Sujet : %s\n"
		+ "Axe vertical : Y\n"
		+ "Caméra : orthographique\n"
		+ "Azimut : %.1f°  •  Élévation : %.1f°\n"
		+ "Taille ortho commune : %.6f\n"
		+ "Bounds source : %.6f × %.6f × %.6f\n"
		+ "Bounds normalisés : %.6f × %.6f × %.6f\n"
		+ "Union caméra : %.6f × %.6f\n"
		+ "Marge : %.0f %%  •  PNG : %d × %d\n"
		+ "Sortie : %s"
	) % [
		character_scene_path.get_file(),
		CAMERA_AZIMUTH_DEGREES,
		CAMERA_ELEVATION_DEGREES,
		framing_ortho_size,
		source_bounds.size.x,
		source_bounds.size.y,
		source_bounds.size.z,
		normalized_bounds.size.x,
		normalized_bounds.size.y,
		normalized_bounds.size.z,
		framing_union_view.size.x,
		framing_union_view.size.y,
		FRAMING_MARGIN_RATIO * 100.0,
		capture_resolution.x,
		capture_resolution.y,
		ProjectSettings.globalize_path(_capture_directory()),
	]


func _set_status(message: String, is_error := false) -> void:
	status_label.text = message
	status_label.modulate = Color("ff8b7d") if is_error else Color("a9d7b8")


func _run_contract_checks() -> PackedStringArray:
	var failures := PackedStringArray()
	for index in range(CAPTURE_DIRECTIONS.size()):
		var expected_yaw := base_character_yaw_degrees + float(index) * 90.0
		var actual_yaw := direction_to_yaw_degrees(
			CAPTURE_DIRECTIONS[index], base_character_yaw_degrees
		)
		if not is_equal_approx(actual_yaw, expected_yaw):
			failures.append("yaw_%s" % CAPTURE_DIRECTIONS[index])
	if capture_filename_for(subject_slug, &"SE") != "achilles_SE.png":
		failures.append("capture_filename")
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		failures.append("orthographic_projection")
	if capture_viewport.size != capture_resolution:
		failures.append("capture_resolution")
	var stable_size := camera.size
	var saved_orientation := current_orientation
	for direction in CAPTURE_DIRECTIONS:
		set_orientation(direction)
		if not is_equal_approx(camera.size, stable_size):
			failures.append("stable_ortho_%s" % direction)
	set_orientation(saved_orientation)
	if normalized_model_points.is_empty() or framing_ortho_size <= 0.0:
		failures.append("bounds_framing")
	return failures


func _run_automation(arguments: PackedStringArray) -> void:
	var failures := _run_contract_checks()
	if not failures.is_empty():
		push_error("CHARACTER_CAPTURE_SELF_TEST_FAILED=%s" % ",".join(failures))
		_maybe_quit_automation(1)
		return
	print("CHARACTER_CAPTURE_SELF_TEST_PASSED")
	var success := true
	if arguments.has("--capture-all"):
		success = await capture_all()
	if arguments.has("--quit-after-capture"):
		get_tree().quit(0 if success else 1)


func _maybe_quit_automation(exit_code: int) -> void:
	if OS.get_cmdline_user_args().has("--quit-after-capture"):
		get_tree().quit(exit_code)
