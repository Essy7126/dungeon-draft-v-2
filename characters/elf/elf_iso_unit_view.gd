class_name ElfIsoUnitView
extends CharacterIsoUnitView

const PRECISE_SHOT_ID := &"elf_precise_shot"
const MAGIC_BOW_SCENE: PackedScene = preload(
	"res://asset/sorts/elfe_arc_magique/elf_magic_bow_charge.tscn"
)

@export var magic_bow_position_offset := Vector2.ZERO
@export_range(-180.0, 180.0, 0.1)
var magic_bow_rotation_offset_degrees := 0.0
@export_range(0.1, 4.0, 0.01)
var magic_bow_scale_multiplier := 0.35

var _active_magic_bow: Node2D = null


func get_elf_visual() -> Node:
	return get_character_visual()


func _process(delta: float) -> void:
	super._process(delta)
	_update_magic_bow_transform()


func _exit_tree() -> void:
	_active_magic_bow = null
	super._exit_tree()


func play_spell_action(spell: Spell = null) -> bool:
	if spell == null or spell.spell_id != PRECISE_SHOT_ID:
		return super.play_spell_action(spell)
	if is_instance_valid(_active_magic_bow):
		return false
	var visual := get_elf_visual() as ElfVisual3D
	if visual == null:
		return false
	var started := _play_cast_action(
		ElfVisual3D.ANIM_BOW_SHOT,
		Callable(visual, "play_bow_shot")
	)
	if not started:
		return false
	if not _spawn_magic_bow():
		visual.stop_animation()
		_visual_priority = VisualPriority.IDLE
		play_idle()
		return false
	return true


func play_death() -> bool:
	_cleanup_magic_bow()
	return super.play_death()


func get_default_cast_effect_origin() -> Vector2:
	if is_instance_valid(_active_magic_bow):
		var release_point := _active_magic_bow.get_node_or_null(
			"BowSprite/ReleasePoint"
		) as Node2D
		if is_instance_valid(release_point):
			return to_local(release_point.global_position)
	return super.get_default_cast_effect_origin()


func has_active_magic_bow() -> bool:
	return is_instance_valid(_active_magic_bow)


func get_active_magic_bow() -> Node2D:
	return _active_magic_bow if is_instance_valid(_active_magic_bow) else null


func cancel_spell_action() -> void:
	_cleanup_magic_bow()
	var visual := get_elf_visual() as ElfVisual3D
	if visual != null and not visual.is_death_locked():
		visual.reset_to_idle()
	_visual_priority = VisualPriority.IDLE


func _spawn_magic_bow() -> bool:
	if is_instance_valid(_active_magic_bow):
		return false
	var bow := MAGIC_BOW_SCENE.instantiate() as Node2D
	if bow == null:
		push_error("ElfIsoUnitView: impossible d'instancier l'arc magique.")
		return false
	add_child(bow)
	bow.z_index = 20
	_active_magic_bow = bow
	_update_magic_bow_transform()
	bow.tree_exited.connect(
		func() -> void:
			if _active_magic_bow == bow:
				_active_magic_bow = null
	)
	return true


func _update_magic_bow_transform() -> void:
	if not is_instance_valid(_active_magic_bow):
		return
	var left := get_left_hand_effect_origin()
	var right := get_right_hand_effect_origin()
	_active_magic_bow.position = (
		(left + right) * 0.5 + magic_bow_position_offset
	)
	_active_magic_bow.rotation = (
		_get_cast_screen_angle()
		+ deg_to_rad(magic_bow_rotation_offset_degrees)
	)
	_active_magic_bow.scale = Vector2.ONE * magic_bow_scale_multiplier


func _cleanup_magic_bow() -> void:
	if not is_instance_valid(_active_magic_bow):
		_active_magic_bow = null
		return
	var bow := _active_magic_bow
	_active_magic_bow = null
	if not bow.is_queued_for_deletion():
		bow.queue_free()


func _get_cast_screen_angle() -> float:
	var facing := get_facing_direction()
	var screen_direction := Vector2(
		float(facing.x - facing.y),
		float(facing.x + facing.y) * 0.5
	)
	if screen_direction.is_zero_approx():
		return 0.0
	return screen_direction.angle()


func _on_visual_animation_finished(animation_name: StringName) -> void:
	super._on_visual_animation_finished(animation_name)
	if animation_name == ElfVisual3D.ANIM_BOW_SHOT:
		_cleanup_magic_bow()
