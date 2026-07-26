extends Node2D

@onready var impact_animation: AnimatedSprite2D = $ImpactAnimation


func _ready() -> void:
	impact_animation.animation_finished.connect(_on_animation_finished)
	impact_animation.play(&"impact")


func _on_animation_finished() -> void:
	queue_free()
