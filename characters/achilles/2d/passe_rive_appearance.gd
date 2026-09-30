extends RefCounted
## Canonical character dimensions, independent of atlas canvases and room profiles.
const SOURCE_HEIGHT := 214.0
const PALETTE_SHADER := preload("res://characters/achilles/2d/passe_rive_palette.gdshader")
const Palette := preload("res://characters/achilles/2d/passe_rive_palette_data.gd")


static func material_for(source: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PALETTE_SHADER
	material.set_shader_parameter("warm_light", 0.0)
	material.set_shader_parameter("warm_direction", 0.0)
	material.set_shader_parameter("cool_light", 0.0)
	apply_palette(material, source)
	return material


static func apply_palette(material: ShaderMaterial, source: String) -> void:
	if material == null:
		return
	var values: Dictionary = Palette.SOURCES.get(source, { })
	var centers: Dictionary = Palette.CENTERS.get(source, { })
	for group in ["teal", "cape", "leather", "gold", "ivory"]:
		var rgb: Array = values.get(group, [1.0, 1.0, 1.0])
		material.set_shader_parameter(group + "_gain", Vector3(rgb[0], rgb[1], rgb[2]))
		if centers.has(group):
			var center: Array = centers[group]
			material.set_shader_parameter(
				group + "_center",
				Vector3(center[0], center[1], center[2]),
			)
