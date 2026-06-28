extends Node3D

func _ready() -> void:
	var anim_player := $Model/AnimationPlayer as AnimationPlayer
	if anim_player:
		anim_player.play("birdcage-378914")
