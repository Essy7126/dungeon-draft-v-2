extends Node2D
## A visual overlay projected onto the actual cell polygon; no terrain mutation.
const Catalog := preload("class_card_vfx_catalog.gd")
const Player := preload("class_card_vfx_player.gd")
const GROUND_SHADER := preload("cel/ground.gdshader")
const Cel := preload("cel/recipes.gd")
var elapsed := 0.0
var closed := false
var fading := false
var fade_elapsed := 0.0
var family := ""
var remaining := 0
var material_fx: ShaderMaterial
var motif := ""
var canopy: Sprite2D
var manual := false


func configure(
	p_family: String,
	world_polygon: PackedVector2Array,
	turns: int,
	seed_value: float,
	p_motif := "",
) -> void:
	family = p_family
	motif = p_motif
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
	material_fx.shader = GROUND_SHADER
	material_fx.set_shader_parameter("body_color", Color(Catalog.PALETTES[family][0]))
	material_fx.set_shader_parameter("core_color", Color(Catalog.PALETTES[family][1]))
	material_fx.set_shader_parameter("kind", 0 if family == "fire" else 1 if family == "ice" else 2)
	material_fx.set_shader_parameter("seed_value", seed_value)
	material_fx.set_shader_parameter(
		"variant",
		["pyre", "fault", "embers", "frost_garden", "caltrop"].find(motif),
	)
	shape.material = material_fx
	add_child(shape)
	if motif != "":
		var center := Vector2.ZERO
		var left := INF
		var right := -INF
		for point in local_points:
			center += point * .25
			left = minf(left, point.x)
			right = maxf(right, point.x)
		canopy = Sprite2D.new()
		canopy.texture = Player.WHITE
		canopy.position = center
		canopy.offset = Vector2(0, -107.52)
		var extent: float = { "fault": .34, "embers": .30, "caltrop": .28 }.get(motif, .58)
		canopy.scale = Vector2.ONE * (right - left) * extent / 256.0
		var veil := ShaderMaterial.new()
		veil.shader = Player.CEL
		veil.set_shader_parameter("artwork", Cel.texture("fire" if family == "fire" else "ice"))
		veil.set_shader_parameter("frontal", true)
		veil.set_shader_parameter("layer", 1.0)
		canopy.material = veil
		add_child(canopy)
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
	var alpha := minf(1.0, elapsed / .22)
	if fading:
		alpha = 1.0 - clampf(fade_elapsed / .45, 0.0, 1.0)
	material_fx.set_shader_parameter("opacity", alpha)
	if is_instance_valid(canopy):
		var pose := mini(2, int(elapsed * 9.0)) if elapsed < .35 else 1 + int(elapsed * 2.0) % 2
		canopy.material.set_shader_parameter(
			"frame_index",
			4 + mini(1, int(fade_elapsed * 4)) if fading else pose,
		)
		canopy.material.set_shader_parameter("opacity", alpha * .90)


func _process(delta: float) -> void:
	if closed or manual:
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
