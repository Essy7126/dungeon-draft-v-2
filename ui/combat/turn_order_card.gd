class_name TurnOrderCard
extends Button

signal unit_requested(unit: Unit)

@onready var preview: CharacterPreview3D = %CharacterPreview
@onready var fallback_portrait: TextureRect = %FallbackPortrait
@onready var active_marker: Label = %ActiveMarker
@onready var team_accent: ColorRect = %TeamAccent

var unit: Unit = null
var _rank := 0


func _ready() -> void:
	pressed.connect(_on_pressed)
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_refresh_style()


func configure(source: Unit) -> void:
	unit = source
	tooltip_text = unit.unit_name if unit != null else "Combattant indisponible"
	if not is_node_ready():
		return
	_configure_portrait()
	_refresh_style()


func set_visual_rank(rank: int) -> void:
	_rank = maxi(0, rank)
	active_marker.visible = _rank == 0
	modulate = Color.WHITE if _rank == 0 else Color(0.82, 0.84, 0.86, 0.94)
	_refresh_style()


func _configure_portrait() -> void:
	preview.visible = false
	fallback_portrait.visible = false
	if unit == null:
		return
	var data := unit.character_data
	if data != null and data.preview_visual_scene != null:
		preview.visible = true
		preview.configure(data)
		preview.visual_root.rotation_degrees = Vector3(0.0, 32.0, 0.0)
		_frame_preview_face()
		preview.preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		return
	var texture := _get_fallback_texture()
	fallback_portrait.texture = texture
	fallback_portrait.visible = texture != null


func _get_fallback_texture() -> Texture2D:
	if unit == null or unit.sprite_frames == null:
		return null
	var animation := StringName(unit.idle_animation)
	if not unit.sprite_frames.has_animation(animation):
		var animations := unit.sprite_frames.get_animation_names()
		if animations.is_empty():
			return null
		animation = animations[0]
	if unit.sprite_frames.get_frame_count(animation) <= 0:
		return null
	return unit.sprite_frames.get_frame_texture(animation, 0)


func _frame_preview_face() -> void:
	var visual := preview.get_visual_instance()
	if visual == null:
		return
	var skeleton_frame := _calculate_skeleton_frame(visual)
	if not skeleton_frame.is_empty():
		var skeleton_target := skeleton_frame["target"] as Vector3
		preview.camera.position = skeleton_target + Vector3(-3.0, 0.1, 4.0)
		preview.camera.look_at(skeleton_target, Vector3.UP)
		preview.camera.size = maxf(
			0.18,
			float(skeleton_frame["body_height"]) * 0.38,
		)
		return
	var bounds := _calculate_visual_bounds(visual)
	if bounds.size.length_squared() <= 0.000001:
		preview.camera.position = Vector3(3.9, 1.2, 3.9)
		preview.camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
		preview.camera.size = 0.85
		return
	var target := bounds.get_center()
	target.y = bounds.position.y + bounds.size.y * 0.78
	preview.camera.position = target + Vector3(3.0, 0.15, 4.0)
	preview.camera.look_at(target, Vector3.UP)
	preview.camera.size = maxf(0.18, bounds.size.y * 0.4)


func _calculate_skeleton_frame(root: Node3D) -> Dictionary:
	var root_inverse := preview.visual_root.global_transform.affine_inverse()
	for node in root.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		if skeleton == null or skeleton.get_bone_count() <= 0:
			continue
		var head_found := false
		var head_position := Vector3.ZERO
		var minimum_y := INF
		var maximum_y := -INF
		for bone_index in range(skeleton.get_bone_count()):
			var bone_world := (
				skeleton.global_transform
				* skeleton.get_bone_global_pose(bone_index).origin
			)
			var bone_position := root_inverse * bone_world
			minimum_y = minf(minimum_y, bone_position.y)
			maximum_y = maxf(maximum_y, bone_position.y)
			var bone_name := skeleton.get_bone_name(bone_index).to_lower()
			if "head" in bone_name:
				head_position = bone_position
				head_found = true
		if head_found:
			var body_height := maxf(0.1, maximum_y - minimum_y)
			head_position.y += body_height * 0.04
			return {
				"target": head_position,
				"body_height": body_height,
			}
	return {}


func _calculate_visual_bounds(root: Node3D) -> AABB:
	var has_bounds := false
	var result := AABB()
	var root_inverse := preview.visual_root.global_transform.affine_inverse()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform := root_inverse * mesh_instance.global_transform
		var mesh_bounds := mesh_instance.get_aabb()
		for endpoint_index in range(8):
			var point := relative_transform * mesh_bounds.get_endpoint(endpoint_index)
			if not has_bounds:
				result = AABB(point, Vector3.ZERO)
				has_bounds = true
			else:
				result = result.expand(point)
	return result


func _refresh_style() -> void:
	var team_color := (
		Color(0.3, 0.68, 0.92, 1.0)
		if unit != null and unit.team == 0
		else Color(0.9, 0.32, 0.26, 1.0)
	)
	if is_node_ready():
		team_accent.color = team_color
	var border_color := Color(0.96, 0.75, 0.3, 1.0) if _rank == 0 else team_color
	add_theme_stylebox_override("normal", _make_style(border_color, 0.94))
	add_theme_stylebox_override("hover", _make_style(border_color.lightened(0.18), 0.98))
	add_theme_stylebox_override("pressed", _make_style(Color.WHITE, 1.0))
	add_theme_stylebox_override("focus", _make_style(border_color.lightened(0.25), 1.0))


func _make_style(border_color: Color, opacity: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.03, 0.04, opacity)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	return style


func _on_pressed() -> void:
	if unit != null and is_instance_valid(unit):
		unit_requested.emit(unit)
