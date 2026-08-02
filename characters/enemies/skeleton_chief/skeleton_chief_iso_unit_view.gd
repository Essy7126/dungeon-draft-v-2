class_name SkeletonChiefIsoUnitView
extends CharacterIsoUnitView


func get_skeleton_chief_visual() -> SkeletonChiefVisual3D:
	return get_character_visual() as SkeletonChiefVisual3D


func play_basic_attack() -> bool:
	var visual := get_skeleton_chief_visual()
	if visual == null:
		return false
	return _play_cast_action(
		SkeletonChiefVisual3D.ANIM_ATTACK,
		Callable(visual, "play_basic_attack")
	)


func play_spell_action(spell: Spell = null) -> bool:
	var visual := get_skeleton_chief_visual()
	if visual == null or not visual.is_heavy_strike(spell):
		return false
	return _play_cast_action(
		SkeletonChiefVisual3D.ANIM_HEAVY_ATTACK,
		func() -> bool: return visual.play_spell_action(spell)
	)


func play_hit() -> bool:
	if _death_locked or _visual_priority > VisualPriority.HIT:
		return false
	return _play_if_new(
		CharacterVisual3D.ACTION_HIT,
		VisualPriority.HIT,
		SkeletonChiefVisual3D.HIT_SPEED
	)


func play_death() -> bool:
	if _death_locked or _visual_priority == VisualPriority.DEATH:
		return false
	_death_locked = true
	_movement_active = false
	return _play_if_new(
		CharacterVisual3D.ACTION_DEATH,
		VisualPriority.DEATH,
		SkeletonChiefVisual3D.DEATH_SPEED
	)


func cancel_spell_action() -> void:
	var visual := get_skeleton_chief_visual()
	if visual != null and not visual.is_death_locked():
		visual.reset_to_idle()
	_visual_priority = VisualPriority.IDLE


func get_default_cast_effect_origin() -> Vector2:
	return get_right_hand_effect_origin()
