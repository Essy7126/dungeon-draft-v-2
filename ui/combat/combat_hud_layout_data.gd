class_name CombatHUDLayoutData
extends Resource

@export_category("Global")
@export var overall_width := 1160.0
@export var overall_height := 190.0
@export_range(0.75, 1.25, 0.01) var hud_scale := 1.0
@export var character_identity_width := 340.0
@export var block_separation := 12.0
@export_range(0.0, 1.0, 0.01) var plate_opacity := 0.92
@export_range(0.0, 1.0, 0.01) var character_accent_intensity := 0.42

@export_category("Identity and resources")
@export var portrait_size := 96.0
@export var health_bar_size := Vector2(210.0, 26.0)
@export var special_resource_bar_size := Vector2(210.0, 22.0)
@export var action_resource_badge_size := 48.0
@export var identity_badge_size := 24.0
@export var move_action_size := Vector2(96.0, 100.0)
@export var contextual_text_size := 16

@export_category("Actions")
@export var action_slot_size := 92.0
@export var action_icon_size := 70.0
@export var action_slot_spacing := 8.0
@export var shortcut_plate_height := 16.0
@export_range(0.0, 1.0, 0.01) var slot_desaturation := 0.18
@export_range(0.05, 0.3, 0.01) var transition_duration := 0.1

@export_category("Turn")
@export var end_turn_size := Vector2(180.0, 54.0)

@export_category("Turn banner")
@export var turn_banner_size := Vector2(300.0, 800.0)
@export var turn_banner_position := Vector2.ZERO
@export_range(0.05, 1.0, 0.01) var banner_enter_duration := 0.28
@export_range(0.1, 2.0, 0.01) var banner_hold_duration := 1.32
@export_range(0.05, 1.0, 0.01) var banner_exit_duration := 0.3
@export_range(0.0, 1.0, 0.01) var banner_animation_intensity := 0.65
