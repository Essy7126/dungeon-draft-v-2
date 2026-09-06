@tool
extends ColorRect
## Decorative material only. Content and hit targets remain separate controls.

const SURFACE_SHADER := preload("res://ui/recraft_hud_v1/theme/hud_material_surface.gdshader")

var _surface_material: ShaderMaterial
var _skin: HudVisualSkinData


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	color = Color.WHITE
	_surface_material = ShaderMaterial.new()
	_surface_material.shader = SURFACE_SHADER
	material = _surface_material
	resized.connect(_sync_size)


func configure(skin: HudVisualSkinData, modules: Array[Rect2]) -> void:
	_skin = skin
	visible = skin != null and skin.material_enabled and not skin.neutral_grayscale
	if not visible:
		return
	_surface_material.set_shader_parameter("material_texture", skin.material_texture)
	_surface_material.set_shader_parameter("has_texture", skin.material_texture != null)
	_surface_material.set_shader_parameter("texture_strength", skin.material_texture_strength)
	_surface_material.set_shader_parameter("tile_size", maxf(skin.material_tile_size, 32.0))
	_surface_material.set_shader_parameter("surface_color", skin.surface_dock)
	_surface_material.set_shader_parameter("metal_color", skin.border_strong_color)
	_surface_material.set_shader_parameter("metal_light", skin.material_edge_highlight)
	_surface_material.set_shader_parameter("rim_width", skin.material_rim_width)
	_surface_material.set_shader_parameter("bevel_cut", skin.material_corner_cut)
	for index in 3:
		var region := modules[index] if index < modules.size() else Rect2()
		_surface_material.set_shader_parameter(
			"module_%d" % index,
			Vector4(region.position.x, region.position.y, region.size.x, region.size.y)
		)
	_sync_size()


func _sync_size() -> void:
	if _surface_material != null:
		_surface_material.set_shader_parameter("surface_size", size.max(Vector2.ONE))
