class_name ElfMagicRonceImpact
extends Node2D

@onready var ronce_animation: AnimatedSprite2D = $RonceAnimation


func _ready() -> void:
	print("[RONCE DEBUG] elf_magic_ronce_impact._ready() atteint | global_position=", global_position)
	ronce_animation.animation_finished.connect(_on_animation_finished)
	ronce_animation.play(&"impact")
	print("[RONCE DEBUG] animation lancée, visible=", ronce_animation.visible, " frame_count=", ronce_animation.sprite_frames.get_frame_count(&"impact"))


func _on_animation_finished(_animation_name: StringName = &"") -> void:
	queue_free()


# Fallback : si un jour ce vfx est utilisé avec un placement non-TARGET_CELL
# (VFXManager appelle alors initialiser_cible si dispo), on reste cohérent.
func initialiser_cible(target_position: Vector2) -> void:
	global_position = target_position
