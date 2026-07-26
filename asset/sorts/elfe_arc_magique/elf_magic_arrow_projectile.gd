extends Node2D

@export var travel_duration: float = 0.35
@export var impact_scene: PackedScene

@onready var arrow_animation: AnimatedSprite2D = $ArrowAnimation


func launch(start_position: Vector2, target_position: Vector2) -> void:
	global_position = start_position

	var direction := target_position - start_position
	rotation = direction.angle()

	arrow_animation.play(&"fly")

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(
		self,
		"global_position",
		target_position,
		travel_duration
	)

	tween.finished.connect(
		func() -> void:
			_spawn_impact(target_position)
			queue_free()
	)


func _spawn_impact(target_position: Vector2) -> void:
	if impact_scene == null:
		push_warning("Aucune scène d'impact assignée au projectile.")
		return

	var impact := impact_scene.instantiate() as Node2D
	get_parent().add_child(impact)
	impact.global_position = target_position


func initialiser(
	start_position: Vector2,
	target_position: Vector2
) -> void:
	launch(start_position, target_position)
