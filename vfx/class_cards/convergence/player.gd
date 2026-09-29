extends Node2D
## Authored cel sheets. Grid positions and unit views are never written here.
signal cancelled
const CONTACT := 8.0 / 30.0
const STRIKE := 2.0 / 30.0
const RELEASE := 14.0 / 30.0
const ART := "res://vfx/class_cards/convergence/"
static var assets: Dictionary = { }
static var textures: Dictionary = { }
var recipe: Dictionary = { }
var point := Vector2.ZERO
var origin := Vector2.ZERO
var width := 128.0
var elapsed := 0.0
var duration := CONTACT + RELEASE
var closed := false
var persistent := false
var badge_mode := false
var manual := false
var preparing := false
var confirmed := false
var full_sequence := false
var basis: Array = []
var knot: Sprite2D
var sheets: Array[Dictionary] = []
var hit_points: Array[Vector2] = []
var pull_paths: Array[Dictionary] = []
var arm_points: Array[Vector2] = []
var _clock := 0.0


func configure(
	entry: Dictionary,
	at: Vector2,
	display_width: float,
	_anchor: Node2D = null,
	_hold := false,
) -> void:
	recipe = entry.duplicate(true)
	point = at
	origin = at
	width = display_width
	basis = entry.get(
		"convergence_basis",
		[Vector2(width * .5, width * .25), Vector2(-width * .5, width * .25)],
	)
	preparing = bool(entry.get("convergence_preparing", false))
	full_sequence = preparing
	duration = CONTACT + RELEASE if preparing else RELEASE
	global_position = at
	z_index = 5
	if assets.is_empty():
		assets = JSON.parse_string(FileAccess.get_file_as_string(ART + "provenance.json")).assets
	knot = _sprite("knot")
	knot.global_transform = Transform2D(
		basis[0] * 2.3 / 384.0,
		basis[1] * 2.3 / 384.0,
		at + Vector2(0, -width * .22),
	)
	sample(0)


func _sprite(id: String) -> Sprite2D:
	if not textures.has(id):
		textures[id] = load(ART + id + ".png")
	var sprite := Sprite2D.new()
	sprite.texture = textures[id]
	sprite.hframes = int(assets[id].columns)
	sprite.vframes = int(assets[id].rows)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	return sprite


func _segment(id: String, from: Vector2, to: Vector2) -> void:
	var sprite := _sprite(id)
	var direction := (to - from).normalized()
	var height := width * (.9 if id == "blade" else .65)
	var offset := Vector2(0, -width * .22)
	# Source visible endpoints are x +/-1.35 in a 3.4-unit orthographic canvas.
	sprite.global_transform = Transform2D(
		(to - from) / (384.0 * 2.7 / 3.4),
		direction.orthogonal() * height / 384.0,
		(from + to) * .5 + offset,
	)
	sheets.append({ "sprite": sprite, "id": id })


func confirm(arms: Array[Vector2], contacts: Array[Vector2], trails: Array[Dictionary]) -> void:
	if closed or confirmed:
		return
	confirmed = true
	preparing = false
	arm_points.assign(arms)
	hit_points.assign(contacts)
	pull_paths.assign(trails)
	for destination in arms:
		_segment("blade", point, destination)
	for path in trails:
		_segment("trail", path.from, path.to)
	for at in contacts:
		var sprite := _sprite("contact")
		sprite.global_position = at + Vector2(0, -width * .27)
		sprite.global_scale = Vector2.ONE * width * .90 / 384.0
		sprite.z_index = 2
		sheets.append({ "sprite": sprite, "id": "contact" })
	elapsed = CONTACT if full_sequence else 0.0
	sample(elapsed)


func sample(time: float) -> void:
	elapsed = maxf(0, time)
	_clock = elapsed if full_sequence else elapsed + CONTACT
	if preparing:
		_clock = minf(_clock, CONTACT - .00001)
	var age := _clock - CONTACT
	knot.visible = not closed and (preparing or (confirmed and age < .27))
	knot.frame = clampi(int(_clock * 30), 0, 7)
	knot.modulate.a = 1.0 - smoothstep(.08, .27, age)
	for sheet in sheets:
		var sprite: Sprite2D = sheet.sprite
		var id: String = sheet.id
		var local_age := age - (STRIKE if id == "contact" else 0.0)
		var end := float(assets[id].frames) / 30.0
		sprite.frame = clampi(int(local_age * 30.0 + .00001), 0, int(assets[id].frames) - 1)
		sprite.visible = not closed and confirmed and local_age >= 0 and local_age < end
		sprite.modulate.a = 1.0 - smoothstep(end * .55, end, local_age)


func _process(delta: float) -> void:
	if closed or manual:
		return
	sample(elapsed + delta)
	if (preparing and elapsed >= CONTACT + .8) or (confirmed and elapsed >= duration):
		cancel()


func cancel() -> void:
	if closed:
		return
	closed = true
	hide()
	cancelled.emit()
	queue_free()
