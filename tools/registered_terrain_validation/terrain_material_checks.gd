extends RefCounted

# Inspect live materials and the actual Land node, independently of palette
# metadata. A matching resource path alone cannot prove shared texture identity.
const PALETTE_SHADER := "res://battle/painted/registered_terrain/shaders/stone_palette.gdshader"
const UNIFORM_TOLERANCE := 0.000001
const UV_TOLERANCE_PX := 0.001

static func run(battle: Node, arena: ArenaDefinition, renderer: ArenaTerrainVisualRenderer) -> Dictionary:
	var terrain := battle.get_node_or_null("GreekTerrainComposition")
	var land := terrain.get_node_or_null("Land") as Polygon2D if terrain != null else null
	if land == null or land.texture == null:
		return {"ok": false, "errors": ["material_check_live_land_texture_missing"]}
	var raw_plan: Variant = terrain.get("plan")
	if not raw_plan is Dictionary or not raw_plan.get("land", {}) is Dictionary:
		return {"ok": false, "errors": ["material_check_land_style_missing"]}
	var style: Dictionary = raw_plan.get("land", {})
	var expected_scale := Vector2.ONE
	var scale_setting: Variant = style.get("texture_scale", [1,1])
	if scale_setting is Array and scale_setting.size() >= 2:
		expected_scale = Vector2(float(scale_setting[0]), float(scale_setting[1]))
	elif scale_setting is int or scale_setting is float:
		expected_scale = Vector2.ONE * float(scale_setting)
	expected_scale = Vector2(maxf(absf(expected_scale.x), 0.001), maxf(absf(expected_scale.y), 0.001))
	var errors: Array[String] = []
	var max_land_uv_error := 0.0
	if land.uv.size() != land.polygon.size():
		errors.append("material_check_land_uv_count_mismatch")
	else:
		for index in range(land.uv.size()):
			max_land_uv_error = maxf(max_land_uv_error, land.uv[index].distance_to(land.polygon[index] / expected_scale))
		if max_land_uv_error > UV_TOLERANCE_PX:
			errors.append("material_check_land_uv_scale_mismatch:%.6fpx" % max_land_uv_error)
	var expected_tint := land.color
	var expected_repeat := land.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED
	if land.texture_repeat != CanvasItem.TEXTURE_REPEAT_ENABLED and land.texture_repeat != CanvasItem.TEXTURE_REPEAT_DISABLED:
		errors.append("material_check_land_repeat_unresolved")
	if expected_repeat != bool(style.get("texture_repeat", true)):
		errors.append("material_check_land_repeat_differs_from_plan")
	var expected_count := 0
	var material_count := 0
	var texture_identity_matches := 0
	var scale_matches := 0
	var tint_matches := 0
	var repeat_matches := 0
	var max_scale_error := 0.0
	var max_tint_error := 0.0
	var mismatches: Array[Dictionary] = []
	for definition in arena.cells:
		if definition == null or not definition.defined or definition.cell_type == GridData.CellType.HOLE:
			continue
		expected_count += 1
		var root := renderer.node_for_cell(definition.coordinate)
		var sprite := root.get_node_or_null("Visual") as Sprite2D if root != null else null
		var material := sprite.material as ShaderMaterial if sprite != null else null
		var fields: Array[String] = []
		if material == null:
			fields.append("missing_sprite_shader_material")
		else:
			material_count += 1
			if sprite.use_parent_material:
				fields.append("sprite_uses_parent_material")
			if material.shader == null or material.shader.resource_path != PALETTE_SHADER:
				fields.append("unexpected_shader")
			var texture: Variant = material.get_shader_parameter("meadow_texture")
			if texture is Texture2D and texture.get_instance_id() == land.texture.get_instance_id():
				texture_identity_matches += 1
			else:
				fields.append("meadow_texture_instance")
			var scale_value: Variant = material.get_shader_parameter("meadow_texture_scale")
			if scale_value is Vector2:
				var scale_error: float = scale_value.distance_to(expected_scale)
				max_scale_error = maxf(max_scale_error, scale_error)
				if scale_error <= UNIFORM_TOLERANCE:
					scale_matches += 1
				else:
					fields.append("meadow_texture_scale")
			else:
				fields.append("meadow_texture_scale_missing")
			var tint_value: Variant = material.get_shader_parameter("meadow_tint")
			if tint_value is Color:
				var tint_error := _color_error(tint_value, expected_tint)
				max_tint_error = maxf(max_tint_error, tint_error)
				if tint_error <= UNIFORM_TOLERANCE:
					tint_matches += 1
				else:
					fields.append("meadow_tint")
			else:
				fields.append("meadow_tint_missing")
			var repeat_value: Variant = material.get_shader_parameter("meadow_repeat")
			if repeat_value is bool and repeat_value == expected_repeat:
				repeat_matches += 1
			else:
				fields.append("meadow_repeat")
		if not fields.is_empty():
			mismatches.append({"cell": [definition.coordinate.x, definition.coordinate.y], "fields": fields})
	if not mismatches.is_empty():
		errors.append("stone_land_material_mismatch:%d_cells" % mismatches.size())
	return {
		"ok": errors.is_empty(), "errors": errors,
		"authority": "Live floor Sprite2D ShaderMaterials compared by Texture2D instance identity with the rendered Land; scale checked against actual Land UVs, tint against Land.color, repeat against Land.texture_repeat.",
		"expected_floor_cells": expected_count, "shader_materials_checked": material_count,
		"land_texture_path": land.texture.resource_path, "land_texture_instance_id": str(land.texture.get_instance_id()),
		"texture_identity_matches": texture_identity_matches,
		"meadow_scale_matches": scale_matches, "meadow_tint_matches": tint_matches, "meadow_repeat_matches": repeat_matches,
		"expected_texture_scale": [expected_scale.x, expected_scale.y],
		"expected_tint_rgba": [expected_tint.r, expected_tint.g, expected_tint.b, expected_tint.a],
		"expected_repeat": expected_repeat,
		"maximum_scale_error": max_scale_error, "maximum_tint_channel_error": max_tint_error,
		"land_uv_max_error_px": max_land_uv_error, "uniform_tolerance": UNIFORM_TOLERANCE,
		"land_uv_tolerance_px": UV_TOLERANCE_PX, "mismatched_cells": mismatches,
	}

static func _color_error(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r-b.r), absf(a.g-b.g)), maxf(absf(a.b-b.b), absf(a.a-b.a)))
