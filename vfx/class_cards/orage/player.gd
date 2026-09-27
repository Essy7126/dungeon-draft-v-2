extends Node2D
## One confirmed discharge, with no game-state or global modulation.
signal cancelled
const CONTACT := .30
const END := .92
const ART := "res://vfx/class_cards/orage/"
static var assets: Dictionary = { }
static var textures: Dictionary = { }
var recipe: Dictionary = { }
var point := Vector2.ZERO
var origin := Vector2.ZERO
var width := 128.0
var anchor: Node2D
var elapsed := 0.0
var duration := END
var closed := false
var persistent := false
var badge_mode := false
var manual := false
var confirmed := false
var preparing := false
var full_sequence := false
var hit_points: Array[Vector2] = []
var sheets: Array[Dictionary] = []
var _clock := 0.0


func configure(
	entry: Dictionary,
	at: Vector2,
	display_width: float,
	unit_anchor: Node2D = null,
	_hold := false,
) -> void:
	recipe = entry.duplicate(true)
	point = at
	origin = at
	width = display_width
	anchor = unit_anchor
	preparing = bool(entry.get("orage_preparing", false))
	full_sequence = preparing
	confirmed = not preparing
	duration = END if preparing else END - CONTACT
	global_position = point
	z_index = 4
	if assets.is_empty():
		assets = JSON.parse_string(FileAccess.get_file_as_string(ART + "provenance.json")).assets
	if preparing:
		_sheet("crown_back", point, 1.7, anchor, true)
		_sheet("crown_front", point, 1.7, anchor)
	sample(0.0)


func _sheet(
	id: String,
	at: Vector2,
	size_ratio: float,
	owner_view: Node2D = null,
	behind := false,
) -> void:
	if not textures.has(id):
		textures[id] = load(ART + id + ".png")
	var asset: Dictionary = assets[id]
	var sprite := Sprite2D.new()
	sprite.texture = textures[id]
	sprite.hframes = int(asset.columns)
	sprite.vframes = int(asset.rows)
	sprite.offset = Vector2(float(asset.size) * .5, float(asset.size) * .5) - Vector2(
		asset.pivot[0],
		asset.pivot[1],
	)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if is_instance_valid(owner_view):
		owner_view.add_child(sprite)
		sprite.show_behind_parent = behind
		sprite.z_index = 0 if behind else 3
		if behind:
			owner_view.move_child(sprite, 0)
	else:
		add_child(sprite)
	sheets.append(
		{
			"id": id,
			"sprite": sprite,
			"point": at,
			"ratio": size_ratio,
			"frames": int(asset.frames),
		}
	)
	sprite.global_scale = Vector2.ONE * width * size_ratio / float(asset.size)
	sprite.global_position = at


func set_impacts(points: Array[Vector2]) -> void:
	if closed or not hit_points.is_empty():
		return
	for at in points:
		if at in hit_points:
			continue
		hit_points.append(at)
		_sheet("bolt", at, 2.15)
		(sheets.back().sprite as Sprite2D).flip_h = hit_points.size() % 2 == 0
		_sheet("impact", at, 1.38)
	sample(elapsed)


func confirm() -> void:
	if closed or confirmed:
		return
	confirmed = true
	preparing = false
	elapsed = CONTACT
	sample(elapsed)


func _process(delta: float) -> void:
	if closed or manual:
		return
	sample(elapsed + delta)
	if (preparing and elapsed > CONTACT + .8) or (confirmed and elapsed >= duration):
		cancel()


func sample(time: float) -> void:
	elapsed = maxf(time, 0.0)
	_clock = elapsed if full_sequence else elapsed + CONTACT
	if preparing:
		_clock = minf(_clock, CONTACT - .00001)
	for sheet in sheets:
		var sprite: Sprite2D = sheet.sprite
		if not is_instance_valid(sprite):
			continue
		var crown: bool = str(sheet.id).begins_with("crown")
		var age: float = _clock if crown else _clock - CONTACT
		if crown and is_instance_valid(anchor):
			sprite.global_position = anchor.global_position
		else:
			sprite.global_position = sheet.point
		sprite.visible = (
			not closed and age >= 0 and age < float(sheet.frames) / 30.0 and (crown or confirmed)
		)
		sprite.frame = clampi(int(age * 30.0 + .00001), 0, sheet.frames - 1)
		sprite.modulate.a = 1.0 - smoothstep(
			.36 if not crown else .43,
			.50 if not crown else .60,
			age,
		)
	queue_redraw()


func cancel() -> void:
	if closed:
		return
	closed = true
	for sheet in sheets:
		if is_instance_valid(sheet.sprite):
			sheet.sprite.hide()
			sheet.sprite.queue_free()
	sheets.clear()
	hide()
	cancelled.emit()
	queue_free()


func _exit_tree() -> void:
	for sheet in sheets:
		if is_instance_valid(sheet.sprite):
			sheet.sprite.queue_free()
	sheets.clear()
