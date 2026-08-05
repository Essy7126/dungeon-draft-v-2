class_name CombatFeedbackStyle
extends Resource

@export var style_id: StringName = &"damage_physical"
@export var event_type: StringName = &"hp_damage_taken"
@export var font_color := Color.WHITE
@export var accent_color := Color.WHITE
@export_range(8, 72, 1) var font_size := 22
@export_range(0, 12, 1) var outline_size := 4
@export var outline_color := Color(0.02, 0.025, 0.04, 0.96)
@export var icon_text := ""
@export var label_key: StringName = &""
@export var label_fallback := ""
@export_range(0.5, 1.5, 0.01) var emphasis_scale := 1.0
@export var uppercase_label := true


func clone() -> CombatFeedbackStyle:
	return duplicate(true) as CombatFeedbackStyle
