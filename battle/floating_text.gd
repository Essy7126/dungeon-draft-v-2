class_name FloatingCombatText
extends Control

signal finished(instance)

const APORIA_STATUS: StatusData = preload("res://data/status/enemies/philosopher_aporia.tres")

@onready var _badge: Label = %Badge
@onready var _icon: Label = %Icon
@onready var _amount: Label = %Amount
@onready var _detail: Label = %Detail

var screen_anchor := Vector2.ZERO
var animation_offset := Vector2.ZERO
var _tween: Tween = null
var _fact: CombatEventFact = null
var _style: CombatFeedbackStyle = null
var _settings: CombatFeedbackSettings = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	visible = false


func _process(_delta: float) -> void:
	position = screen_anchor + animation_offset - size * 0.5


func play_fact(
		fact: CombatEventFact,
		style: CombatFeedbackStyle,
		settings: CombatFeedbackSettings,
		freeze_for_snapshot := false,
		legacy_preset := false
	) -> void:
	_fact = fact
	_style = style
	_settings = settings
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var payload := describe_fact(fact, style, legacy_preset)
	_apply_payload(payload, style, settings, legacy_preset)
	visible = true
	modulate = Color.WHITE
	animation_offset = Vector2.ZERO
	if freeze_for_snapshot:
		scale = Vector2.ONE * float(payload.get("emphasis_scale", 1.0))
		return
	_play_motion(float(payload.get("emphasis_scale", 1.0)))


static func describe_fact(
		fact: CombatEventFact,
		style: CombatFeedbackStyle,
		legacy_preset := false
	) -> Dictionary:
	var amount_text := ""
	var label := _translated_label(style)
	var detail := ""
	match fact.event_type:
		&"hp_damage_taken":
			amount_text = "−%d" % fact.amount_applied
			if fact.is_periodic and fact.status_id != &"":
				detail = _status_detail(fact.status_id)
		&"heal_received":
			amount_text = "+%d" % fact.amount_applied
		&"shield_absorbed":
			amount_text = "%d" % fact.amount_absorbed
		&"shield_granted":
			amount_text = "+%d" % fact.amount_applied
		&"attack_dodged", &"attack_immune":
			amount_text = label
			label = ""
		&"status_added", &"status_expired":
			amount_text = label
			label = ""
			if fact.status_id != &"":
				detail = _status_detail(fact.status_id)
	if legacy_preset:
		return _legacy_payload(fact, amount_text)
	return {
		"amount_text": amount_text,
		"badge_text": label,
		"detail_text": detail,
		"icon_text": style.icon_text,
		"font_color": style.font_color,
		"accent_color": style.accent_color,
		"font_size": style.font_size,
		"outline_size": style.outline_size,
		"outline_color": style.outline_color,
		"emphasis_scale": style.emphasis_scale,
		"style_id": String(style.style_id),
	}


static func _status_detail(status_id: StringName) -> String:
	if status_id == APORIA_STATUS.get_effective_status_id():
		return APORIA_STATUS.status_name
	return String(status_id).replace("_", " ").capitalize()


static func _translated_label(style: CombatFeedbackStyle) -> String:
	if style == null or style.label_key == &"":
		return ""
	var translated := TranslationServer.translate(style.label_key)
	if translated == String(style.label_key):
		translated = style.label_fallback
	return translated.to_upper() if style.uppercase_label else translated


static func _legacy_payload(fact: CombatEventFact, amount_text: String) -> Dictionary:
	var color := Color(0.96, 0.96, 0.96)
	var font_size := 14
	var badge := ""
	match fact.event_type:
		&"hp_damage_taken":
			if fact.is_critical:
				color = Color(1.0, 0.42, 0.18)
				font_size = 20
				badge = "critique"
		&"heal_received":
			color = Color(0.55, 1.0, 0.62)
		&"shield_granted", &"shield_absorbed":
			color = Color(0.62, 0.72, 0.86)
			badge = "bouclier"
		&"attack_dodged":
			color = Color(0.85, 0.85, 0.7)
			font_size = 12
	return {
		"amount_text": amount_text,
		"badge_text": badge,
		"detail_text": "",
		"icon_text": "",
		"font_color": color,
		"accent_color": color,
		"font_size": font_size,
		"outline_size": 0,
		"outline_color": Color.TRANSPARENT,
		"emphasis_scale": 1.0,
		"style_id": "legacy_current",
	}


func _apply_payload(
		payload: Dictionary,
		style: CombatFeedbackStyle,
		settings: CombatFeedbackSettings,
		legacy_preset: bool
	) -> void:
	var scale_factor := settings.text_scale if settings != null else 1.0
	var font_size := maxi(8, int(round(float(payload["font_size"]) * scale_factor)))
	var font_color: Color = payload["font_color"]
	var accent_color: Color = payload["accent_color"]
	var outline_color: Color = payload["outline_color"]
	var outline_size := int(payload["outline_size"])
	_amount.text = str(payload["amount_text"])
	_badge.text = str(payload["badge_text"])
	_detail.text = str(payload["detail_text"])
	_icon.text = str(payload["icon_text"])
	_badge.visible = _badge.text != ""
	_detail.visible = _detail.text != ""
	_icon.visible = _icon.text != ""
	_amount.add_theme_font_size_override("font_size", font_size)
	_amount.add_theme_color_override("font_color", font_color)
	_amount.add_theme_color_override("font_outline_color", outline_color)
	_amount.add_theme_constant_override("outline_size", outline_size)
	_icon.add_theme_font_size_override("font_size", maxi(8, font_size - 3))
	_icon.add_theme_color_override("font_color", accent_color)
	_icon.add_theme_color_override("font_outline_color", outline_color)
	_icon.add_theme_constant_override("outline_size", outline_size)
	_badge.add_theme_color_override("font_color", accent_color)
	_badge.add_theme_color_override("font_outline_color", outline_color)
	_badge.add_theme_constant_override("outline_size", maxi(0, outline_size - 1))
	_detail.add_theme_color_override("font_color", Color(font_color, 0.82))
	_detail.add_theme_color_override("font_outline_color", outline_color)
	_detail.add_theme_constant_override("outline_size", maxi(0, outline_size - 2))
	if legacy_preset:
		_badge.add_theme_font_size_override("font_size", 9)
	else:
		_badge.add_theme_font_size_override("font_size", maxi(10, font_size - 10))
		_detail.add_theme_font_size_override("font_size", maxi(10, font_size - 9))


func _play_motion(emphasis_scale: float) -> void:
	var duration := _settings.duration
	var rise := _settings.rise_pixels_at_1080p * maxf(
		0.66, get_viewport_rect().size.y / 1080.0
	)
	if _settings.reduced_motion:
		rise = minf(rise, 8.0)
		scale = Vector2.ONE * emphasis_scale
	else:
		scale = Vector2.ONE * 0.84
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(
		self, "animation_offset:y", -rise, duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not _settings.reduced_motion:
		_tween.tween_property(
			self, "scale", Vector2.ONE * emphasis_scale,
			minf(_settings.appear_duration, duration)
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fade_duration := duration * _settings.fade_fraction
	_tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_delay(
		maxf(0.0, duration - fade_duration)
	)
	_tween.chain().tween_callback(_on_done)


func reset_for_pool() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_fact = null
	_style = null
	_settings = null
	visible = false
	modulate = Color.WHITE
	scale = Vector2.ONE
	animation_offset = Vector2.ZERO


func get_fact() -> CombatEventFact:
	return _fact


func _on_done() -> void:
	visible = false
	finished.emit(self)
