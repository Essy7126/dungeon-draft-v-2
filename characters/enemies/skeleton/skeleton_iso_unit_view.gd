class_name SkeletonIsoUnitView
extends CharacterIsoUnitView

@export var combat_style: SkeletonVisual3D.CombatStyle = SkeletonVisual3D.CombatStyle.MELEE


func _ready() -> void:
	var visual := get_skeleton_visual()
	if visual != null:
		visual.set_combat_style(combat_style)
	super._ready()


func get_skeleton_visual() -> SkeletonVisual3D:
	return get_character_visual() as SkeletonVisual3D


func play_basic_attack() -> bool:
	if combat_style != SkeletonVisual3D.CombatStyle.MELEE:
		return false
	var visual := get_skeleton_visual()
	if visual == null:
		return false
	return _play_cast_action(
		SkeletonVisual3D.ANIM_MELEE,
		Callable(visual, "play_basic_attack")
	)


func play_spell_action(spell: Spell = null) -> bool:
	var visual := get_skeleton_visual()
	if visual == null:
		return false
	if combat_style == SkeletonVisual3D.CombatStyle.MELEE:
		return _play_cast_action(
			SkeletonVisual3D.ANIM_MELEE,
			Callable(visual, "play_basic_attack")
		)
	return _play_cast_action(
		SkeletonVisual3D.ANIM_RANGED,
		func() -> bool: return visual.play_spell_action(spell)
	)


func play_hit() -> bool:
	if _death_locked or _visual_priority > VisualPriority.HIT:
		return false
	return _play_if_new(
		CharacterVisual3D.ACTION_HIT,
		VisualPriority.HIT,
		SkeletonVisual3D.HIT_SPEED
	)


func play_death() -> bool:
	if _death_locked or _visual_priority == VisualPriority.DEATH:
		return false
	_death_locked = true
	_movement_active = false
	return _play_if_new(
		CharacterVisual3D.ACTION_DEATH,
		VisualPriority.DEATH,
		SkeletonVisual3D.DEATH_SPEED
	)


func cancel_spell_action() -> void:
	var visual := get_skeleton_visual()
	if visual != null and not visual.is_death_locked():
		visual.reset_to_idle()
	_visual_priority = VisualPriority.IDLE


func get_default_cast_effect_origin() -> Vector2:
	if combat_style == SkeletonVisual3D.CombatStyle.RANGED:
		return (get_left_hand_effect_origin() + get_right_hand_effect_origin()) * 0.5
	return get_right_hand_effect_origin()
