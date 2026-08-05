class_name CombatFeedbackSettings
extends Resource

@export_group("Pool")
@export_range(0, 128, 1) var prewarm_count := 24
@export_range(1, 256, 1) var max_active := 48
@export_range(1, 12, 1) var max_visible_per_target := 4
@export_range(0.0, 0.5, 0.01) var sequence_interval := 0.09

@export_group("Motion")
@export_range(0.5, 1.5, 0.01) var duration := 0.86
@export_range(0.0, 160.0, 1.0) var rise_pixels_at_1080p := 64.0
@export_range(0.0, 0.3, 0.01) var appear_duration := 0.09
@export_range(0.1, 0.8, 0.01) var fade_fraction := 0.34
@export_range(0.0, 32.0, 1.0) var stack_step := 22.0
@export_range(0.0, 24.0, 1.0) var horizontal_step := 8.0

@export_group("Accessibility")
@export_range(0.5, 2.0, 0.05) var text_scale := 1.0
@export var reduced_motion := false
@export_range(0.0, 64.0, 1.0) var viewport_margin := 20.0

@export_group("Styles")
@export var styles: Array[CombatFeedbackStyle] = []


func style_for_fact(fact: CombatEventFact) -> CombatFeedbackStyle:
	var wanted := _style_id_for_fact(fact)
	for style in styles:
		if style != null and style.style_id == wanted:
			return style
	for style in styles:
		if style != null and style.event_type == fact.event_type:
			return style
	return _fallback_style(wanted, fact.event_type)


func _style_id_for_fact(fact: CombatEventFact) -> StringName:
	match fact.event_type:
		&"hp_damage_taken":
			if fact.is_periodic:
				return &"damage_periodic"
			if fact.is_critical:
				return &"damage_critical"
			return &"damage_magical" if fact.damage_type == 1 else &"damage_physical"
		&"heal_received":
			return &"healing_normal"
		&"shield_absorbed":
			return &"shield_absorbed"
		&"shield_granted":
			return &"shield_granted"
		&"attack_dodged":
			return &"avoidance_dodge"
		&"attack_immune":
			return &"avoidance_immune"
		&"status_added":
			return &"status_added"
		&"status_expired":
			return &"status_expired"
	return &"damage_physical"


func _fallback_style(style_id: StringName, event_type: StringName) -> CombatFeedbackStyle:
	var style := CombatFeedbackStyle.new()
	style.style_id = style_id
	style.event_type = event_type
	return style
