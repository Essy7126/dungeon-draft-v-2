class_name ElfMagicBowCharge
extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play(&"charge_release")


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"charge_release":
		queue_free()
