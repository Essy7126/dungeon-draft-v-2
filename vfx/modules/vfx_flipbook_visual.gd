class_name VFXFlipbookVisual
extends VFXModuleVisual

var sprite: Sprite2D
var flipbook_data: VFXFlipbookModuleData
var selected_variant: VFXFlipbookVariant
var selected_quality_tier := -1
var selected_texture_path := ""
var current_frame := 0


func configure(data: VFXModuleData, execution_context: VFXExecutionContext, local_seed: int) -> void:
	flipbook_data = data as VFXFlipbookModuleData
	super.configure(data, execution_context, local_seed)
	if flipbook_data == null or flipbook_data.asset == null:
		return
	selected_variant = flipbook_data.asset.select_variant(local_seed)
	var selection := flipbook_data.asset.select_texture(
		selected_variant, execution_context.get_quality_tier()
	)
	var texture := selection.get("texture") as Texture2D
	selected_quality_tier = int(selection.get("quality_tier", -1))
	selected_texture_path = texture.resource_path if texture != null else ""
	if texture == null:
		return
	sprite = Sprite2D.new()
	sprite.name = "FlipbookSprite"
	sprite.texture = texture
	sprite.hframes = flipbook_data.asset.columns
	sprite.vframes = flipbook_data.asset.rows
	sprite.centered = true
	sprite.position = _anchor_position() + flipbook_data.asset.local_offset
	sprite.rotation_degrees = flipbook_data.rotation_degrees
	sprite.modulate = Color(
		flipbook_data.color_modulate.r,
		flipbook_data.color_modulate.g,
		flipbook_data.color_modulate.b,
		flipbook_data.color_modulate.a * flipbook_data.opacity,
	)
	var frame_size := Vector2(
		float(texture.get_width()) / float(flipbook_data.asset.columns),
		float(texture.get_height()) / float(flipbook_data.asset.rows),
	)
	sprite.offset = (Vector2(0.5, 0.5) - flipbook_data.asset.pivot_normalized) * frame_size
	var cell_size: Vector2 = execution_context.get_value(&"cell_visual_size", Vector2.ZERO)
	if cell_size.x > 0.0 and cell_size.y > 0.0:
		var desired_size := flipbook_data.asset.nominal_size_in_cells * cell_size
		sprite.scale = desired_size / frame_size * flipbook_data.scale_multiplier
	else:
		sprite.scale = flipbook_data.scale_multiplier
	var material: Material
	match flipbook_data.asset.blend_mode:
		&"MIX":
			var canvas_material := CanvasItemMaterial.new()
			canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
			material = canvas_material
		&"ADD":
			var canvas_material := CanvasItemMaterial.new()
			canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			material = canvas_material
		&"PREMULTIPLIED":
			if flipbook_data.asset.alpha_mode == &"STRAIGHT":
				var shader := Shader.new()
				shader.code = """shader_type canvas_item;
render_mode blend_premul_alpha;
void fragment() {
	vec4 sampled = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(sampled.rgb * sampled.a, sampled.a);
}
"""
				var shader_material := ShaderMaterial.new()
				shader_material.shader = shader
				material = shader_material
			else:
				var canvas_material := CanvasItemMaterial.new()
				canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
				material = canvas_material
	sprite.material = material
	add_child(sprite)
	_update_frame(0.0)
	visible = false


func set_normalized_progress(value: float) -> void:
	normalized_progress = maxf(value, 0.0)
	visible = sprite != null
	_update_frame(normalized_progress)


func get_current_frame() -> int:
	return current_frame


func get_selected_variant_id() -> StringName:
	return selected_variant.variant_id if selected_variant != null else &""


func get_selected_quality_tier() -> int:
	return selected_quality_tier


func get_selected_texture_path() -> String:
	return selected_texture_path


func geometry_fingerprint() -> String:
	return JSON.stringify({
		"variant": str(get_selected_variant_id()),
		"quality": selected_quality_tier,
		"texture": selected_texture_path,
		"anchor": str(flipbook_data.anchor) if flipbook_data != null else "",
		"position": [sprite.position.x, sprite.position.y] if sprite != null else [],
		"scale": [sprite.scale.x, sprite.scale.y] if sprite != null else [],
	}).sha256_text()


func _update_frame(progress: float) -> void:
	if sprite == null or flipbook_data == null or flipbook_data.asset == null:
		return
	var asset := flipbook_data.asset
	var sampled := 0
	if asset.playback_mode == &"FIT_MODULE_DURATION":
		if progress >= 1.0:
			sampled = asset.frame_count - 1
		else:
			sampled = floori(clampf(progress, 0.0, 0.999999) * float(asset.frame_count))
	else:
		var elapsed := maxf(progress, 0.0) * maxf(flipbook_data.duration, 0.01)
		sampled = floori(elapsed * asset.frames_per_second)
	sampled += flipbook_data.frame_offset
	current_frame = posmod(sampled, asset.frame_count) if asset.loop \
		else clampi(sampled, 0, asset.frame_count - 1)
	sprite.frame = current_frame


func _anchor_position() -> Vector2:
	match flipbook_data.anchor:
		&"ORIGIN_WORLD":
			return context.get_value(&"origin_world", Vector2.ZERO)
		&"FIRST_IMPACT_WORLD":
			var impacts: PackedVector2Array = context.get_value(
				&"impact_world_points", PackedVector2Array()
			)
			return impacts[0] if not impacts.is_empty() else Vector2.ZERO
		_:
			return context.get_value(&"target_world", Vector2.ZERO)
