extends Node2D
## Ethereal sheets split behind/in front of an actor; no combat logic.
const Catalog := preload("class_card_vfx_catalog.gd")
const VEIL := preload("ethereal/veil.gdshader")
const FIRE := preload("ethereal/fire.gdshader")
const SMOKE := preload("ethereal/smoke.gdshader")
const WHITE := preload("ethereal/white.tres")
const NOISE := preload("ethereal/flow_noise.tres")
const PILOT := preload("ethereal/pilot.gdshader")
const SPELL := preload("ethereal/spell.gdshader")
const POWER := preload("ethereal/power.gdshader")
const Power := preload("class_card_vfx_power.gd")
const Concepts := preload("class_card_vfx_concepts.gd")
var recipe: Dictionary = { }
var elapsed := 0.0
var duration := 1.0
var closed := false
var persistent := false
var anchor: Node2D
var point := Vector2.ZERO
var origin := Vector2.INF
var width := 190.0
var sprites: Array[Sprite2D] = []
var smoke: Sprite2D
var manual := false


func configure(
	entry: Dictionary,
	world_point: Vector2,
	display_width: float,
	unit_anchor: Node2D = null,
	hold := false,
) -> void:
	recipe = entry.duplicate(true)
	point = world_point
	width = display_width
	anchor = unit_anchor
	persistent = hold
	if persistent and recipe.family in ["guard", "stasis"]:
		width *= 1.2
	duration = maxf(.05, float(recipe.get("duration", 1.0)))
	var family := str(recipe.family)
	var colors: Array = Catalog.PALETTES.get(family, Catalog.PALETTES.slash)
	var motif := str(recipe.get("motif", ""))
	var authored := motif in Concepts.MOTIFS
	var power_shape := Power.shape(recipe, persistent)
	for part in 2:
		var shader := PILOT if motif != "" else FIRE if family == "fire" else VEIL
		if authored:
			shader = SPELL
		if power_shape != "":
			shader = POWER
		var sprite := _sheet(shader, -1 if part == 0 else 2)
		var mat := sprite.material as ShaderMaterial
		mat.set_shader_parameter("layer", float(part))
		mat.set_shader_parameter("holding", persistent)
		mat.set_shader_parameter("seed_value", float(int(recipe.get("seed", 0)) % 997) * .07)
		if power_shape != "":
			mat.set_shader_parameter("flow_noise", NOISE)
			mat.set_shader_parameter("shape", Power.SHAPES.find(power_shape))
			mat.set_shader_parameter("body_color", Color(recipe.get("body_color", colors[0])))
			mat.set_shader_parameter("core_color", Color(recipe.get("core_color", colors[1])))
		elif authored:
			mat.set_shader_parameter("flow_noise", NOISE)
			mat.set_shader_parameter("motif", Concepts.MOTIFS.find(motif))
			mat.set_shader_parameter("variant", float(recipe.get("variant", 0)))
			mat.set_shader_parameter("body_color", Color(colors[0]))
			mat.set_shader_parameter("core_color", Color(colors[1]))
			mat.set_shader_parameter(
				"power",
				float(recipe.get("power", 0)) if Power.is_cast(recipe, persistent) else 0.0,
			)
			mat.set_shader_parameter(
				"travel_phase",
				1.0 if recipe.get("travel_phase", "") == "arrival" else 0.0,
			)
		elif motif != "":
			mat.set_shader_parameter("flow_noise", NOISE)
			mat.set_shader_parameter("motif", ["dagger", "ember", "frost"].find(motif))
		elif family != "fire":
			mat.set_shader_parameter("flow_noise", NOISE)
			mat.set_shader_parameter("family", Catalog.FAMILIES.find(family))
			mat.set_shader_parameter("body_color", Color(colors[0]))
			mat.set_shader_parameter("core_color", Color(colors[1]))
		sprites.append(sprite)
	if family == "fire" and motif == "":
		smoke = _sheet(SMOKE, -2)
	sample(0.0)


func _sheet(shader: Shader, depth: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = WHITE
	sprite.offset = Vector2(0, -87.04)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	sprite.material = mat
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if is_instance_valid(anchor):
		anchor.add_child(sprite)
	else:
		add_child(sprite)
	# A negative Z falls behind the arena tiles in the production Y-sorted world.
	# Keep rear sheets at the actor's Z and draw them before its actual artwork.
	sprite.z_index = maxi(0, depth)
	if depth < 0:
		sprite.show_behind_parent = true
		sprite.get_parent().move_child(sprite, 0)
	sprite.global_scale = Vector2.ONE * width / 256.0
	return sprite


func _process(delta: float) -> void:
	if manual or closed:
		return
	sample(elapsed + delta)
	if not persistent and elapsed >= duration:
		cancel()


func sample(time: float) -> void:
	elapsed = maxf(0.0, time)
	var u := clampf(elapsed / duration, 0.0, 1.0)
	var alpha := 1.0
	var flow := elapsed
	if persistent:
		u = .24 + sin(elapsed * .9) * .025
		alpha = .34 if recipe.family == "fire" else .60 if recipe.family == "guard" else .55
		flow = elapsed * .8
		if recipe.has("motif"):
			alpha = .85
	elif recipe.get("feedback_phase", "") in ["expire", "break"]:
		u = .35 + u * .65
		alpha = (1.0 - u) * .7
	var at := (
		anchor.global_position
		if (is_instance_valid(anchor) and (persistent or recipe.get("follow_unit", false)))
		else point
	)
	for sprite in sprites:
		if not is_instance_valid(sprite):
			continue
		sprite.global_position = at
		sprite.visible = not closed and (persistent or (u > 0.0 and u < 1.0))
		var mat := sprite.material as ShaderMaterial
		mat.set_shader_parameter("progress", u)
		mat.set_shader_parameter("flow_time", flow)
		mat.set_shader_parameter("opacity", alpha)
		mat.set_shader_parameter("age", .52 if persistent else u * 1.8)
		if recipe.has("motif"):
			# origin is supplied by the router after creation; update at every sample.
			var direction := Vector2.RIGHT
			if origin.is_finite():
				direction = (point + Vector2(0, -width * .24) - origin).normalized()
			if recipe.has("direction"):
				direction = recipe.direction
			mat.set_shader_parameter("direction", direction)
			mat.set_shader_parameter(
				"release",
				u if recipe.get("feedback_phase", "") in ["expire", "break"] else 0.0,
			)
	if is_instance_valid(smoke):
		smoke.global_position = at
		smoke.visible = not closed and not persistent and u > 0.0 and u < 1.0
		smoke.material.set_shader_parameter("age", u * 1.9)
		smoke.material.set_shader_parameter("opacity", alpha)


func cancel() -> void:
	if closed:
		return
	closed = true
	for sprite in sprites:
		if is_instance_valid(sprite):
			sprite.visible = false
			sprite.queue_free()
	sprites.clear()
	if is_instance_valid(smoke):
		smoke.visible = false
		smoke.queue_free()
	queue_free()


func _exit_tree() -> void:
	# Anchor-local sheets are siblings and must not outlive their owner.
	for sprite in sprites:
		if is_instance_valid(sprite) and sprite.get_parent() != self:
			sprite.queue_free()
	if is_instance_valid(smoke) and smoke.get_parent() != self:
		smoke.queue_free()
