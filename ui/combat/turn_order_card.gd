class_name TurnOrderCard
extends Button

signal unit_requested(unit: Unit)

const UNIT_PRESENTATION := preload("res://ui/combat/combat_unit_presentation.gd")
const VISUAL_THEME_FACTORY := preload(
	"res://ui/recraft_hud_v1/theme/hud_visual_theme_factory.gd"
)

@onready var preview: CharacterPreview3D = %CharacterPreview
@onready var fallback_portrait: TextureRect = %FallbackPortrait
@onready var active_marker: Label = %ActiveMarker
@onready var team_accent: ColorRect = %TeamAccent
@onready var portrait_shade: ColorRect = $PortraitClip/PortraitShade
@onready var premium_frame: TextureRect = %PremiumFrame

var unit: Unit = null
var _rank := 0
var _visual_skin: HudVisualSkinData = null
var _active_styles: Dictionary = {}
var _inactive_styles: Dictionary = {}


func _ready() -> void:
	pressed.connect(_on_pressed)
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	_refresh_style()


func configure(source: Unit) -> void:
	_disconnect_combat_form_signal()
	unit = source
	if is_instance_valid(unit):
		unit.combat_form_changed.connect(_on_combat_form_changed)
	_refresh_identity()
	if not is_node_ready():
		return
	_configure_portrait()
	_refresh_style()


func set_visual_rank(rank: int) -> void:
	_rank = maxi(0, rank)
	active_marker.visible = _rank == 0
	modulate = (
		Color.WHITE
		if _rank == 0
		else Color(
			1.0,
			1.0,
			1.0,
			_visual_skin.cooldown_content_opacity
			if _visual_skin != null
			else 0.94
		)
	)
	_refresh_style()


func apply_visual_skin(skin: HudVisualSkinData) -> void:
	_visual_skin = skin
	_active_styles.clear()
	_inactive_styles.clear()
	if is_node_ready():
		premium_frame.visible = _premium_skin_active()
	if skin == null or not is_node_ready():
		_refresh_style()
		return
	theme_type_variation = &"HudSpellSlot"
	for state_name in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		var active_state: StringName = state_name
		if state_name == &"normal":
			active_state = &"selected"
		_active_styles[state_name] = VISUAL_THEME_FACTORY.make_control_style(
			skin, active_state, skin.border_regular, skin.radius_tight
		)
		_inactive_styles[state_name] = VISUAL_THEME_FACTORY.make_control_style(
			skin, state_name, skin.border_thin, skin.radius_tight
		)
	active_marker.add_theme_font_override("font", skin.font_emphasis)
	active_marker.add_theme_color_override("font_color", skin.text_primary)
	portrait_shade.color = Color(
		skin.surface_scrim.r,
		skin.surface_scrim.g,
		skin.surface_scrim.b,
		0.18
	)
	_refresh_style()


func _configure_portrait() -> void:
	preview.visible = false
	fallback_portrait.visible = false
	if unit == null:
		return
	var data := _portrait_unit_data()
	if data != null and (data.preview_sprite_frames != null or data.preview_visual_scene != null):
		preview.visible = true
		preview.configure(data)
		if not preview.is_using_sprite_preview():
			preview.visual_root.rotation_degrees = Vector3(0.0, 32.0, 0.0)
			_frame_preview_face()
			preview.preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		return
	var texture := _get_fallback_texture()
	fallback_portrait.texture = texture
	fallback_portrait.visible = texture != null


func _get_fallback_texture() -> Texture2D:
	if unit == null:
		return null
	var hud_theme := CharacterHUDThemeCatalog.resolve_refined(unit)
	if hud_theme != null and hud_theme.portrait_texture != null:
		return hud_theme.portrait_texture
	if unit.sprite_frames == null:
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
	if is_node_ready():
		premium_frame.visible = _premium_skin_active()
		premium_frame.self_modulate = (
			Color(1.0, 0.9, 0.63, 1.0)
			if _rank == 0
			else Color(0.62, 0.5, 0.4, 0.84)
		)
	if _visual_skin != null and not _active_styles.is_empty():
		var styles := _active_styles if _rank == 0 else _inactive_styles
		for style_name in styles:
			add_theme_stylebox_override(style_name, styles[style_name])
		if is_node_ready():
			team_accent.color = (
				_visual_skin.text_secondary
				if unit != null and unit.team == 0
				else _visual_skin.border_unavailable_color
			)
		return
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


func _premium_skin_active() -> bool:
	return _visual_skin != null and not _visual_skin.neutral_grayscale


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


func _portrait_unit_data() -> UnitData:
	return UNIT_PRESENTATION.portrait_unit_data(unit)

func _refresh_identity() -> void:
	tooltip_text = unit.unit_name if is_instance_valid(unit) else "Combattant indisponible"
	if is_instance_valid(unit) and unit.combat_form_change != null \
			and unit.combat_form_id == unit.combat_form_change.target_form:
		tooltip_text += " · " + String(unit.combat_form_id).capitalize()


func _on_combat_form_changed(changed_unit: Unit, _old_form: StringName, _new_form: StringName) -> void:
	if changed_unit != unit:
		return
	_refresh_identity()
	if is_node_ready():
		_configure_portrait()


func _disconnect_combat_form_signal() -> void:
	if is_instance_valid(unit) and unit.combat_form_changed.is_connected(_on_combat_form_changed):
		unit.combat_form_changed.disconnect(_on_combat_form_changed)


func _exit_tree() -> void:
	_disconnect_combat_form_signal()
