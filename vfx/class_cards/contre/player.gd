extends Node2D
## Bronze assembly, quiet readiness token and a short ivory return stroke.
signal cancelled
const ART := "res://vfx/class_cards/contre/"
static var assets: Dictionary = { }
static var textures: Dictionary = { }
var recipe: Dictionary = { }
var point := Vector2.ZERO
var origin := Vector2.ZERO
var target := Vector2.ZERO
var width := 128.0
var elapsed := 0.0
var duration := 14.0 / 30.0
var closed := false
var persistent := false
var badge_mode := false
var manual := false
var anchor: Node2D
var mode := "arm"
var sprites: Dictionary = { }
var status_slot := 0
var status_count := 1
var appear_after := 0.0
var overflow: Label


func configure(
	entry: Dictionary,
	at: Vector2,
	display_width: float,
	unit_anchor: Node2D = null,
	hold := false,
) -> void:
	recipe = entry.duplicate(true)
	point = at
	width = display_width
	anchor = unit_anchor
	persistent = hold
	mode = entry.get("contre_mode", "arm")
	badge_mode = mode == "token"
	origin = entry.get("contre_origin", at)
	target = entry.get("contre_target", at)
	if mode == "arm" and origin.distance_to(at) < 4:
		origin = at + Vector2(width * .28, -width * .42)
	duration = .22 if badge_mode else .37 if mode == "riposte" else 14.0 / 30.0
	status_slot = int(entry.get("status_slot", 0))
	status_count = int(entry.get("status_count", 1))
	global_position = at
	z_index = 6
	if assets.is_empty():
		assets = JSON.parse_string(FileAccess.get_file_as_string(ART + "provenance.json")).assets
	for id in (["token"] if badge_mode else ["slash", "contact"] if mode == "riposte" else ["arm"]):
		if not textures.has(id):
			textures[id] = load(ART + id + ".png")
		var sprite := Sprite2D.new()
		sprite.texture = textures[id]
		sprite.hframes = int(assets[id].columns)
		sprite.vframes = int(assets[id].rows)
		add_child(sprite)
		sprites[id] = sprite
	if badge_mode:
		overflow = Label.new()
		overflow.add_theme_font_size_override("font_size", 13)
		overflow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(overflow)
	sample(0)


func set_status_slot(slot: int, count: int) -> void:
	status_slot = slot
	status_count = count
	sample(elapsed)


func sample(time: float) -> void:
	elapsed = maxf(0, time)
	var at := anchor.global_position if is_instance_valid(anchor) else point
	if badge_mode:
		var offset := Vector2((status_slot - (mini(status_count, 6) - 1) * .5) * 24, -106)
		var token: Sprite2D = sprites.token
		token.global_position = at + offset
		token.global_scale = Vector2.ONE * 38.0 / 384.0
		token.visible = (
			not closed and elapsed >= appear_after and status_slot < (5 if status_count > 6 else 6)
		)
		token.modulate.a = 1.0 if persistent else 1.0 - clampf(elapsed / duration, 0, 1)
		overflow.visible = not closed and persistent and status_count > 6 and status_slot == 5
		overflow.text = "+%d" % (status_count - 5)
		overflow.global_position = at + offset + Vector2(-9, -10)
		return
	if mode == "arm":
		var arm: Sprite2D = sprites.arm
		arm.global_position = at + origin - point
		if is_instance_valid(anchor) and anchor.has_method("get_cast_effect_origin_global"):
			arm.global_position = anchor.get_cast_effect_origin_global()
		arm.flip_h = origin.x < point.x
		arm.global_scale = Vector2.ONE * width * 1.18 / 384.0
		_sheet(arm, "arm", elapsed)
		return
	var offset := Vector2(0, -width * .38)
	var delta := target - origin
	var direction := delta.normalized()
	var slash: Sprite2D = sprites.slash
	slash.global_transform = Transform2D(
		delta / (384.0 * 2.7 / 3.4),
		direction.orthogonal() * width * .85 / 384.0,
		(origin + target) * .5 + offset,
	)
	_sheet(slash, "slash", elapsed)
	var contact: Sprite2D = sprites.contact
	contact.global_position = target + offset
	contact.global_scale = Vector2.ONE * width * .68 / 384.0
	_sheet(contact, "contact", elapsed - 2.0 / 30.0)


func _sheet(sprite: Sprite2D, id: String, age: float) -> void:
	var count := int(assets[id].frames)
	var end := count / 30.0
	sprite.frame = clampi(int(age * 30.0 + .00001), 0, count - 1)
	sprite.visible = not closed and age >= 0 and age < end
	sprite.modulate.a = 1.0 - smoothstep(end * .72, end, age)


func _process(delta: float) -> void:
	if closed or manual:
		return
	sample(elapsed + delta)
	if not persistent and elapsed >= duration:
		cancel()


func cancel() -> void:
	if closed:
		return
	closed = true
	hide()
	cancelled.emit()
	queue_free()
