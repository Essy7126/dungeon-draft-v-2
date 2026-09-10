extends Node2D

## Ground-level fog for the threshold painting; one input-transparent ColorRect.
## Add this node in the same local coordinate space as the full painted image.
## configure(extent, definition) returns false and exposes configuration_error if
## an explicitly requested mask cannot load. It then leaves the layer hidden.
##
## definition.threshold_fog (all keys optional):
##   density_mask: res:// path to a PNG, white=dense / black=fully clear.
##                 Static normalized image coordinates; grayscale R is sampled.
##                 Omit for a soft side-bank fallback preserving the central lane.
##   opacity: 0..0.6, default 0.20; a strict ceiling even on a white mask.
##   color: RGB color string or Color, default #447b80; alpha uses opacity only.
##   drift: [x,y] in image fractions/second, default [-0.0008,0.00003].
##          Components limited to +/-0.005; horizontal motion is preferred.
##   scale: 0.5..2, default 1; larger values make the sheets and wisps smaller.
##   curl: 0..2, default 1; sideways curling and stretching of the sheets.
##   detail: 0..1, default 0.75; blend broad smoke into thin, broken wisps.
##   edge_fade: image fraction 0.005..0.3, default 0.065; no rectangular edge.
##   reduced_strength: 0..1, default 0.55; reduced mode also freezes its phase.
##   seed: 0..1000, default 17; deterministic placement of the fog sheets.
##
## Call set_state with the owner's time; no process callback or autonomous clock.
## Repeated time values give the same picture. Reduced mode holds the phase at
## entry until it is disabled, even if the owner's time continues to advance.
## The mask never drifts: clear paths and statue-head exclusions stay clear.
## Render order is deliberately owned by the adapter, as is the density painting.

const SHADER := preload("res://hub/catabase_threshold/threshold_fog.gdshader")
const DEFAULT_COLOR := Color("447b80")
const DEFAULT_DRIFT := Vector2(-0.0008, 0.00003)

var configuration_error := ""
var configured := false
var _panel: ColorRect
var _material: ShaderMaterial
var _density_texture: Texture2D
var _clock := 0.0
var _reduced_clock := 0.0
var _enabled := true
var _reduced := false
var _opacity := 0.20
var _reduced_strength := 0.55


func configure(extent: Vector2, definition: Dictionary) -> bool:
	configured = false
	configuration_error = ""
	_density_texture = null
	if is_instance_valid(_panel):
		_panel.hide()
	if _material != null:
		_material.set_shader_parameter("density_mask", null)
	if not extent.is_finite() or extent.x <= 0.0 or extent.y <= 0.0:
		configuration_error = "La brume nécessite une étendue d’image positive et finie."
		return false
	var raw_settings: Variant = definition.get("threshold_fog", { })
	if not raw_settings is Dictionary:
		configuration_error = "threshold_fog doit être un objet."
		return false
	var settings: Dictionary = raw_settings
	var raw_path: Variant = settings.get("density_mask", "")
	if not raw_path is String:
		configuration_error = "Le masque de brume doit être un chemin res://."
		return false
	var mask_path: String = raw_path
	if not mask_path.is_empty():
		if not mask_path.begins_with("res://") or ".." in mask_path.split("/"):
			configuration_error = "Le masque de brume doit rester dans les ressources du projet."
			return false
		_density_texture = _load_density(mask_path)
		if _density_texture == null:
			configuration_error = "Masque de brume illisible : " + mask_path
			return false
	if not is_instance_valid(_panel):
		_panel = ColorRect.new()
		_panel.name = "ThresholdGroundFog"
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.focus_mode = Control.FOCUS_NONE
		_panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_panel)
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	_panel.position = Vector2.ZERO
	_panel.size = extent
	_panel.material = _material
	_opacity = _number(settings, "opacity", 0.20, 0.0, 0.6)
	_reduced_strength = _number(settings, "reduced_strength", 0.55, 0.0, 1.0)
	var tint := DEFAULT_COLOR
	var raw_color: Variant = settings.get("color", DEFAULT_COLOR)
	if raw_color is Color:
		tint = raw_color
	elif raw_color is String:
		tint = Color.from_string(raw_color, DEFAULT_COLOR)
	if not is_finite(tint.r) or not is_finite(tint.g) or not is_finite(tint.b):
		tint = DEFAULT_COLOR
	tint = Color(clampf(tint.r, 0, 1), clampf(tint.g, 0, 1), clampf(tint.b, 0, 1), 1)
	var motion := DEFAULT_DRIFT
	var raw_drift: Variant = settings.get("drift", DEFAULT_DRIFT)
	if raw_drift is Vector2:
		motion = raw_drift
	elif raw_drift is Array and raw_drift.size() == 2:
		if (
			(raw_drift[0] is int or raw_drift[0] is float)
			and (raw_drift[1] is int or raw_drift[1] is float)
		):
			motion = Vector2(float(raw_drift[0]), float(raw_drift[1]))
	if not motion.is_finite():
		motion = DEFAULT_DRIFT
	motion = motion.clamp(Vector2(-0.005, -0.005), Vector2(0.005, 0.005))
	_material.set_shader_parameter("density_mask", _density_texture)
	_material.set_shader_parameter("has_density_mask", _density_texture != null)
	_material.set_shader_parameter("fog_color", tint)
	_material.set_shader_parameter("opacity", _opacity)
	_material.set_shader_parameter("drift", motion)
	_material.set_shader_parameter("field_scale", _number(settings, "scale", 1.0, 0.5, 2.0))
	_material.set_shader_parameter("curl_strength", _number(settings, "curl", 1.0, 0.0, 2.0))
	_material.set_shader_parameter("detail_strength", _number(settings, "detail", 0.75, 0.0, 1.0))
	_material.set_shader_parameter("edge_fade", _number(settings, "edge_fade", 0.065, 0.005, 0.3))
	_material.set_shader_parameter("seed", _number(settings, "seed", 17.0, 0.0, 1000.0))
	configured = true
	_apply_state()
	return true


func set_state(time: float, enabled: bool, reduced: bool) -> void:
	if not is_finite(time):
		return
	_clock = time
	if reduced and not _reduced:
		_reduced_clock = time
	_enabled = enabled
	_reduced = reduced
	_apply_state()


func _apply_state() -> void:
	if not is_instance_valid(_panel) or _material == null:
		return
	var strength := _reduced_strength if _reduced else 1.0
	_panel.visible = configured and _enabled and _opacity > 0.0 and strength > 0.0
	_material.set_shader_parameter("effect_time", _reduced_clock if _reduced else _clock)
	_material.set_shader_parameter("effect_strength", strength)


func _load_density(path: String) -> Texture2D:
	# Imported textures remain available in packed builds. A raw fallback also
	# supports temporary unimported PNGs used during authoring and unit tests.
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			return ImageTexture.create_from_image(image)
	return null


func _number(settings: Dictionary, key: String, fallback: float, low: float, high: float) -> float:
	var value: Variant = settings.get(key, fallback)
	if not (value is int or value is float) or not is_finite(float(value)):
		return fallback
	return clampf(float(value), low, high)
