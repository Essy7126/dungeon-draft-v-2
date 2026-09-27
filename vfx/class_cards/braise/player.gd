extends Node2D
## Authored charcoal and cel impact; the only retained object is a compact status sign.
signal cancelled
const CONTACT := .30
const END := .70
const ART := "res://vfx/class_cards/braise/"
static var assets: Dictionary = { }
static var textures: Dictionary = { }
var recipe: Dictionary = { }
var point := Vector2.ZERO
var origin := Vector2.ZERO
var width := 128.0
var elapsed := 0.0
var duration := END
var closed := false
var persistent := false
var badge_mode := false
var manual := false
var preparing := false
var confirmed := false
var full_sequence := false
var impact_confirmed := false
var anchor: Node2D
var sprites: Dictionary = { }
var status_slot := 0
var status_count := 1
var pulse_age := 99.0
var _clock := 0.0
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
	origin = entry.get("braise_origin", at)
	width = display_width
	anchor = unit_anchor
	persistent = hold
	badge_mode = bool(entry.get("braise_badge", false))
	preparing = bool(entry.get("braise_preparing", false))
	full_sequence = preparing
	confirmed = not preparing
	impact_confirmed = not preparing and not badge_mode
	duration = .22 if badge_mode else END if preparing else END - CONTACT
	status_slot = int(entry.get("status_slot", 0))
	status_count = int(entry.get("status_count", 1))
	pulse_age = float(entry.get("braise_pulse_age", 99.0))
	global_position = point
	z_index = 6
	if assets.is_empty():
		assets = JSON.parse_string(FileAccess.get_file_as_string(ART + "provenance.json")).assets
	for id in (["ember"] if badge_mode else ["coal", "impact"]):
		if not textures.has(id):
			textures[id] = load(ART + id + ".png")
		var sprite := Sprite2D.new()
		sprite.texture = textures[id]
		sprite.hframes = int(assets[id].columns)
		sprite.vframes = int(assets[id].rows)
		sprite.offset = Vector2.ONE * float(assets[id].size) * .5 - Vector2(
			assets[id].pivot[0],
			assets[id].pivot[1],
		)
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


func pulse() -> void:
	pulse_age = 0
	sample(elapsed)


func confirm(hit := true) -> void:
	if closed or confirmed:
		return
	confirmed = true
	preparing = false
	impact_confirmed = hit
	elapsed = CONTACT
	sample(elapsed)


func _process(delta: float) -> void:
	if closed or manual:
		return
	pulse_age += delta
	sample(elapsed + delta)
	if (
		not persistent
		and ((preparing and elapsed > CONTACT + .8) or (confirmed and elapsed >= duration))
	):
		cancel()


func sample(time: float) -> void:
	elapsed = maxf(time, 0)
	if badge_mode:
		var at := anchor.global_position if is_instance_valid(anchor) else point
		var offset := Vector2((status_slot - (mini(status_count, 6) - 1) * .5) * 24, -106)
		var sprite: Sprite2D = sprites.ember
		sprite.global_position = at + offset
		sprite.global_scale = Vector2.ONE * 34.0 / float(assets.ember.size)
		sprite.frame = mini(6, 1 + int(pulse_age * 30)) if pulse_age < .20 else 0
		sprite.visible = not closed and status_slot < (5 if status_count > 6 else 6)
		sprite.modulate.a = 1.0 if persistent else 1.0 - clampf(elapsed / duration, 0, 1)
		overflow.visible = not closed and persistent and status_count > 6 and status_slot == 5
		overflow.text = "+%d" % (status_count - 5)
		overflow.global_position = at + offset + Vector2(-9, -10)
		return
	_clock = elapsed if full_sequence else elapsed + CONTACT
	if preparing:
		_clock = minf(_clock, CONTACT - .00001)
	var destination := point + Vector2(0, -width * .32)
	var travel := clampf((_clock - .08) / (CONTACT - .08), 0, 1)
	var coal: Sprite2D = sprites.coal
	coal.global_position = origin.lerp(destination, travel * travel)
	coal.rotation = (destination - origin).angle()
	coal.global_scale = Vector2.ONE * width * lerpf(.25, .45, minf(_clock / .08, 1)) / float(
		assets.coal.size
	)
	coal.frame = mini(7, int(_clock * 30))
	coal.visible = not closed and full_sequence and _clock < CONTACT
	var burst: Sprite2D = sprites.impact
	var age := _clock - CONTACT
	burst.global_position = destination
	burst.global_scale = Vector2.ONE * width * .95 / float(assets.impact.size)
	burst.frame = clampi(int(age * 30.0 + .00001), 0, 11)
	burst.visible = not closed and impact_confirmed and age >= 0 and age < .40
	burst.modulate.a = 1.0 - smoothstep(.20, .40, age)


func cancel() -> void:
	if closed:
		return
	closed = true
	hide()
	cancelled.emit()
	queue_free()
