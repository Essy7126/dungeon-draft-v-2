extends Node2D
## Cel poses; all clocks are presentation-only. Holds are removed by the router.
const Catalog := preload("class_card_vfx_catalog.gd")
const Cel := preload("cel/recipes.gd")
const CEL := preload("cel/sheet.gdshader")
const WHITE := preload("ethereal/white.tres")
var recipe: Dictionary = { }
var playback: Dictionary = { }
var elapsed := 0.0
var duration := 1.0
var closed := false
var persistent := false
var badge_mode := false
var anchor: Node2D
var point := Vector2.ZERO
var origin := Vector2.INF
var width := 190.0
var sprites: Array[Sprite2D] = []
var manual := false
var status_slot := 0
var status_count := 1
var badge_size := 21.0
var badge_height := 106.0
var overflow: Label


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
	badge_mode = hold or (recipe.get("feedback_phase", "") == "expire" and recipe.has("status_id"))
	status_slot = int(recipe.get("status_slot", 0))
	status_count = int(recipe.get("status_count", 1))
	duration = maxf(.05, float(recipe.get("duration", 1.0)))
	playback = Cel.playback(recipe, hold)
	var colors: Array = Catalog.PALETTES.get(recipe.family, Catalog.PALETTES.slash)
	var body := Color(recipe.get("body_color", colors[0]))
	var core := Color(recipe.get("core_color", colors[1]))
	if playback.clip == "seal" and recipe.get("class_id", "") == "thaumaturge":
		body = Color("7852ae")
		core = Color("dcccff")
	if recipe.get("id", "") in ["t_guard", "i_t_guard"]:
		body = Color("605578")
		core = Color("c1b5d6")
	var palette_swap: bool = (
		recipe.family in ["bleed", "weaken", "disrupt", "poison"]
		or (playback.clip == "seal" and recipe.get("class_id", "") == "thaumaturge")
		or recipe.get("id", "") in ["t_guard", "i_t_guard"]
	)
	for part in 2:
		var sprite := Sprite2D.new()
		sprite.texture = WHITE
		var mat := ShaderMaterial.new()
		mat.shader = CEL
		mat.set_shader_parameter("artwork", Cel.texture(playback.clip))
		mat.set_shader_parameter("layer", float(part))
		mat.set_shader_parameter("holding", badge_mode)
		mat.set_shader_parameter("body_color", body)
		mat.set_shader_parameter("core_color", core)
		mat.set_shader_parameter("recolor", palette_swap)
		mat.set_shader_parameter(
			"clustered_pierce",
			playback.clip == "pierce" and playback.copies > 1,
		)
		mat.set_shader_parameter("copies", playback.copies)
		mat.set_shader_parameter("angle", deg_to_rad(playback.angle))
		mat.set_shader_parameter(
			"staging",
			{ "thrust": 1, "inward": 2, "volley": 3, "cross": 4, "step": 1 }.get(playback.motion, 0),
		)
		mat.set_shader_parameter(
			"frontal",
			playback.clip in ["cut", "pierce", "chain", "seal", "reaper"],
		)
		sprite.material = mat
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if is_instance_valid(anchor):
			anchor.add_child(sprite)
		else:
			add_child(sprite)
		sprite.z_index = 0 if part == 0 and not badge_mode else 3 + part
		if part == 0 and not badge_mode:
			sprite.show_behind_parent = true
			sprite.get_parent().move_child(sprite, 0)
		sprites.append(sprite)
	if hold:
		overflow = Label.new()
		overflow.add_theme_font_size_override("font_size", 13)
		overflow.add_theme_color_override("font_color", Color("fff1cc"))
		overflow.z_index = 6
		overflow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_instance_valid(anchor):
			anchor.add_child(overflow)
		else:
			add_child(overflow)
	sample(0.0)


func set_status_slot(slot: int, count: int) -> void:
	status_slot = slot
	status_count = count
	sample(elapsed)


func _process(delta: float) -> void:
	if manual or closed:
		return
	sample(elapsed + delta)
	if not persistent and elapsed >= duration:
		cancel()


func sample(time: float) -> void:
	elapsed = maxf(0.0, time)
	var u := clampf(elapsed / duration, 0.0, 1.0)
	var at := (
		anchor.global_position
		if (is_instance_valid(anchor) and (badge_mode or recipe.get("follow_unit", false)))
		else point
	)
	var aim := Vector2.RIGHT
	if origin.is_finite():
		aim = (point + Vector2(0, -width * .24) - origin).normalized()
	if recipe.has("direction"):
		aim = recipe.direction
	var pose := 2 if persistent else Cel.frame_at(u, playback.motion)
	var alpha := 1.0 if persistent else 1.0 - smoothstep(.80, 1.0, u)
	var scale_value := 1.0
	if playback.motion == "brace" and not persistent:
		# A guard transfers into its badge; it does not crack while its shield is intact.
		scale_value = lerpf(1.0, .55, smoothstep(.55, 1.0, u))
	if recipe.get("travel_phase", "") == "arrival":
		pose = 3 + mini(2, int(u * 3.0))
	var showing_overflow := persistent and status_count > 6 and status_slot == 5
	var slot_count := mini(status_count, 6)
	var badge_offset := Vector2((status_slot - (slot_count - 1) * .5) * 24, -badge_height)
	if badge_mode and not persistent:
		badge_offset.y -= badge_size * (.28 + u * .65)
	for sprite in sprites:
		if not is_instance_valid(sprite):
			continue
		sprite.global_position = at
		sprite.visible = (
			not closed and (persistent or u < 1.0) and (not badge_mode or status_slot < 6)
		)
		if badge_mode:
			sprite.global_scale = Vector2.ONE * badge_size / 256.0
			sprite.offset = badge_offset * 256.0 / badge_size
		else:
			var size_value := width
			if playback.minor:
				size_value *= .50 if recipe.get("feedback_phase", "") == "tick" else .60
			if playback.motion in ["low", "bind", "step"]:
				size_value *= .68
			sprite.global_scale = Vector2.ONE * size_value / 256.0
			sprite.offset = Vector2(0, -107.52)
			if playback.motion in ["thrust", "inward", "volley"]:
				# The atlas tip, not its square centre, touches the actor's chest.
				var tip_direction := -aim if playback.motion == "inward" else aim
				var tip_fraction := .13 if playback.clip == "pierce" and playback.copies > 1 else .27
				sprite.offset = (Vector2(0, -58) - tip_direction * size_value * tip_fraction) * 256.0 / size_value - Vector2(
					0,
					12.8,
				)
		var mat := sprite.material as ShaderMaterial
		mat.set_shader_parameter("progress", u)
		mat.set_shader_parameter("flow_time", elapsed)
		mat.set_shader_parameter("frame_index", pose)
		mat.set_shader_parameter("pose_scale", scale_value)
		mat.set_shader_parameter("direction", aim)
		mat.set_shader_parameter(
			"opacity",
			0.0 if showing_overflow and sprite == sprites[1] else alpha,
		)
	if is_instance_valid(overflow):
		overflow.visible = not closed and showing_overflow
		overflow.text = "+%d" % (status_count - 5)
		overflow.global_position = at + badge_offset + Vector2(-9, -10)
		overflow.scale = Vector2.ONE / (overflow.get_parent() as CanvasItem) \
				.get_global_transform() \
				.get_scale()


func cancel() -> void:
	if closed:
		return
	closed = true
	for sprite in sprites:
		if is_instance_valid(sprite):
			sprite.visible = false
			sprite.queue_free()
	sprites.clear()
	if is_instance_valid(overflow):
		overflow.hide()
		overflow.queue_free()
	queue_free()


func _exit_tree() -> void:
	for sprite in sprites:
		if is_instance_valid(sprite) and sprite.get_parent() != self:
			sprite.queue_free()
	if is_instance_valid(overflow) and overflow.get_parent() != self:
		overflow.queue_free()
