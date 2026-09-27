extends Node2D
## One rosette per real ice cell. Seconds animate; terrain facts decide lifetime.
const ART := preload("ice.png")
var elapsed := 0.0
var closed := false
var fading := false
var fade_elapsed := 0.0
var family := "ice"
var remaining := 0
var motif := "frost_garden"
var manual := false
var canopy: Sprite2D
var _scale := 1.0
var pulse_age := 10.0


func configure(
	p_family: String,
	polygon: PackedVector2Array,
	turns: int,
	_seed: float,
	p_motif := "",
) -> void:
	family = p_family
	motif = p_motif
	remaining = turns
	var center := Vector2.ZERO
	var left := INF
	var right := -INF
	for point in polygon:
		center += point / float(polygon.size())
		left = minf(left, point.x)
		right = maxf(right, point.x)
	global_position = center
	_scale = (right - left) * .98 / 256.0
	canopy = Sprite2D.new()
	canopy.texture = ART
	canopy.hframes = 6
	canopy.vframes = 4
	canopy.offset = Vector2(0, -26.0494)
	canopy.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(canopy)
	sample(0.0)
	_place_after_base.call_deferred()


func _place_after_base() -> void:
	if not closed and is_inside_tree():
		get_parent().move_child(self, get_parent().get_child_count() - 1)


func sample(seconds: float) -> void:
	elapsed = maxf(0.0, seconds)
	canopy.frame = mini(23, int((elapsed + .00001) * 30.0))
	var withdrawal := smoothstep(0.0, .28, fade_elapsed) if fading else 0.0
	canopy.scale = Vector2.ONE * _scale * (1.0 - withdrawal)
	canopy.modulate.a = 1.0 - withdrawal
	queue_redraw()


func _process(delta: float) -> void:
	if closed or manual:
		return
	if fading:
		fade_elapsed += delta
	pulse_age += delta
	sample(elapsed + delta)
	if fading and fade_elapsed >= .28:
		cancel()


func release() -> void:
	fading = true


func pulse() -> void:
	pulse_age = 0.0
	queue_redraw()


func _draw() -> void:
	if closed or fading or pulse_age >= .32:
		return
	for side in [-1.0, 1.0]:
		var at := Vector2(side * (22.0 + pulse_age * 24.0), -8.0 - sin(pulse_age / .32 * PI) * 24.0) * _scale
		var size_value := 9.0 * _scale * (1.0 - smoothstep(.15, .32, pulse_age))
		draw_colored_polygon(
			PackedVector2Array(
				[
					at + Vector2(0, -size_value),
					at + Vector2(size_value * .6, 0),
					at + Vector2(0, size_value * .7),
					at - Vector2(size_value * .5, 0),
				]
			),
			Color("a3eaff"),
		)


func cancel() -> void:
	closed = true
	hide()
	queue_free()
