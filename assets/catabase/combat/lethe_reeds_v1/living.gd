extends Node2D
## Local painting effects use an explicit clock, so pause/reduced motion stay still.
const SETTINGS := "res://assets/catabase/combat/lethe_reeds_v1/fx.json"
const MASK := "res://assets/catabase/combat/lethe_reeds_v1/material_mask.png"
const PIT_WATER := preload("res://assets/catabase/combat/lethe_reeds_v1/pit_water.gdshader")
const PIT_WATER_PATCH := Rect2(475, 847, 120, 90)
var effect_time := 0.0
var _material: ShaderMaterial
var _reduced := false
var _pit_platform: Node2D
var _pit_material: ShaderMaterial
var _pit_native_transform := Transform2D.IDENTITY
var _pit_transform_initialized := false


func _ready() -> void:
	var land := get_parent().get_node_or_null("Land") as Polygon2D
	if land == null or not land.material is ShaderMaterial:
		_fail("Missing Land shader material")
		return
	_material = land.material as ShaderMaterial
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
	if not parsed is Dictionary or not _valid_settings(parsed):
		_fail("Invalid fx.json: native lamp bounds and finite foliage settings are required")
		return
	var mask := load(MASK) as Texture2D
	if mask == null:
		_fail("Missing material_mask.png")
		return
	var lamp: Dictionary = parsed.lamp
	_material.set_shader_parameter("material_mask", mask)
	_material.set_shader_parameter("lamp_center", Vector2(lamp.center[0], lamp.center[1]))
	_material.set_shader_parameter("lamp_radius", Vector2(lamp.radius[0], lamp.radius[1]))
	_material.set_shader_parameter("lamp_enabled", true)
	_material.set_shader_parameter("foliage_strength", float(parsed.get("foliage_strength", 1.7)))
	_material.set_shader_parameter("foliage_speed", float(parsed.get("foliage_speed", 0.85)))
	if not _attach_pit_water(land.texture):
		return
	_reduced = GameManager.is_reduced_motion_enabled()
	GameManager.reduced_motion_changed.connect(_on_reduced_motion)
	seek_for_review(0.0)


func _process(delta: float) -> void:
	_sync_pit_transform()
	if not _reduced and not get_tree().paused and is_finite(delta) and delta > 0.0:
		seek_for_review(effect_time + delta)


func _on_reduced_motion(value: bool) -> void:
	_reduced = value


func seek_for_review(seconds: float) -> void:
	if not is_finite(seconds) or seconds < 0.0:
		return
	effect_time = seconds
	if _material != null:
		_material.set_shader_parameter("effect_time", effect_time)
	if _pit_material != null:
		_pit_material.set_shader_parameter("effect_time", effect_time)


func _attach_pit_water(water_texture: Texture2D) -> bool:
	# The registered battle creates Platform before installing this local decor.
	var composition := get_parent() as Node2D
	_pit_platform = composition.get_parent().get_node_or_null("GreekPlatformRisersAndPits") as Node2D
	if _pit_platform == null or _pit_platform.material != null or _pit_platform.use_parent_material:
		_fail("Pit water requires the unmodified GreekPlatformRisersAndPits CanvasItem")
		return false
	var plan: Variant = composition.get("plan")
	if not plan is Dictionary or not plan.get("pit_palette", { }) is Dictionary:
		_fail("Missing pit palette for local water")
		return false
	if (
		water_texture == null
		or not Rect2(Vector2.ZERO, water_texture.get_size()).encloses(PIT_WATER_PATCH)
	):
		_fail("Land texture does not contain the calibrated pit-water sample")
		return false
	var texture_size := water_texture.get_size()
	var palette: Dictionary = plan.get("pit_palette", { })
	var floor_color := Color.from_string(str(palette.get("floor", "#263a35")), Color("263a35"))
	var linear_color := floor_color.srgb_to_linear()
	_pit_material = ShaderMaterial.new()
	_pit_material.shader = PIT_WATER
	_pit_material.set_shader_parameter("water_texture", water_texture)
	_pit_material.set_shader_parameter(
		"water_patch_uv",
		Vector4(
			PIT_WATER_PATCH.position.x / texture_size.x,
			PIT_WATER_PATCH.position.y / texture_size.y,
			PIT_WATER_PATCH.size.x / texture_size.x,
			PIT_WATER_PATCH.size.y / texture_size.y,
		),
	)
	# Match the primitive color before shading in either renderer color space.
	_pit_material.set_shader_parameter(
		"pit_floor_srgb",
		Vector3(floor_color.r, floor_color.g, floor_color.b),
	)
	_pit_material.set_shader_parameter(
		"pit_floor_linear",
		Vector3(linear_color.r, linear_color.g, linear_color.b),
	)
	_pit_platform.material = _pit_material
	_sync_pit_transform()
	return true


func _sync_pit_transform() -> void:
	if _pit_material == null or not is_instance_valid(_pit_platform):
		return
	var composition := get_parent() as Node2D
	var to_native := composition.global_transform.affine_inverse() * _pit_platform.global_transform
	if _pit_transform_initialized and to_native.is_equal_approx(_pit_native_transform):
		return
	_pit_native_transform = to_native
	_pit_transform_initialized = true
	_pit_material.set_shader_parameter("native_axis_x", to_native.x)
	_pit_material.set_shader_parameter("native_axis_y", to_native.y)
	_pit_material.set_shader_parameter("native_origin", to_native.origin)


func _exit_tree() -> void:
	# A terrain-plan reload removes its own effect without leaving a stale clock.
	if is_instance_valid(_pit_platform) and _pit_platform.material == _pit_material:
		_pit_platform.material = null


func _valid_settings(settings: Dictionary) -> bool:
	var lamp: Variant = settings.get("lamp")
	if not lamp is Dictionary:
		return false
	if not _finite_pair(lamp.get("center")) or not _finite_pair(lamp.get("radius")):
		return false
	if lamp.center[0] < 0 or lamp.center[0] > 1920 or lamp.center[1] < 0 or lamp.center[1] > 1200:
		return false
	if lamp.radius[0] <= 0 or lamp.radius[1] <= 0:
		return false
	for key in ["foliage_strength", "foliage_speed"]:
		if settings.has(key):
			var value: Variant = settings[key]
			if not (value is float or value is int):
				return false
			if not is_finite(float(value)) or float(value) < 0.0 or float(value) > 4.0:
				return false
	return true


func _finite_pair(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for coordinate in value:
		if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)):
			return false
	return true


func _fail(message: String) -> void:
	set_process(false)
	push_error("Lethe reeds effects: " + message)
