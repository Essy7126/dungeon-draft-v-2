extends Node2D
## A visual overlay projected onto the actual cell polygon; no terrain mutation.
const Catalog := preload("class_card_vfx_catalog.gd")
const Player := preload("class_card_vfx_player.gd")
var elapsed := 0.0
var closed := false
var fading := false
var fade_elapsed := 0.0
var family := ""
var remaining := 0
var material_fx: ShaderMaterial


func configure(
	p_family: String,
	world_polygon: PackedVector2Array,
	turns: int,
	seed_value: float,
) -> void:
	family = p_family
	remaining = turns
	var shape := Polygon2D.new()
	var local_points := PackedVector2Array()
	for point in world_polygon:
		local_points.append(to_local(point))
	shape.polygon = local_points
	shape.texture = Player.WHITE
	shape.uv = PackedVector2Array(
		[Vector2.ZERO, Vector2(256, 0), Vector2(256, 256), Vector2(0, 256)]
	)
	material_fx = ShaderMaterial.new()
	material_fx.shader = preload("ethereal/ground.gdshader")
	material_fx.set_shader_parameter("flow_noise", Player.NOISE)
	material_fx.set_shader_parameter("body_color", Color(Catalog.PALETTES[family][0]))
	material_fx.set_shader_parameter("core_color", Color(Catalog.PALETTES[family][1]))
	material_fx.set_shader_parameter("kind", 0 if family == "fire" else 1 if family == "ice" else 2)
	material_fx.set_shader_parameter("seed_value", seed_value)
	shape.material = material_fx
	add_child(shape)
	sample(0.0)
	# The base adapter consumes surface_changed after surface_applied. Wait until
	# it has inserted its opaque tile, then draw our overlay last in that layer.
	_place_after_base.call_deferred()


func _place_after_base() -> void:
	if not closed and is_inside_tree():
		get_parent().move_child(self, get_parent().get_child_count() - 1)


func sample(seconds: float) -> void:
	elapsed = seconds
	material_fx.set_shader_parameter("age", elapsed)
	material_fx.set_shader_parameter(
		"opacity",
		(1.0 - clampf(fade_elapsed / .45, 0.0, 1.0)) if fading else minf(1.0, elapsed / .22),
	)


func _process(delta: float) -> void:
	if closed:
		return
	if fading:
		fade_elapsed += delta
	sample(elapsed + delta)
	if fading and fade_elapsed >= .45:
		cancel()


func release() -> void:
	fading = true


func cancel() -> void:
	closed = true
	visible = false
	queue_free()
