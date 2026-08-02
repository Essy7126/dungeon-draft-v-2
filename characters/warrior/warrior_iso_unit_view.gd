class_name WarriorIsoUnitView
extends CharacterIsoUnitView

const CAMERA_IDLE_SIZE := 2.70
const CAMERA_ATTACK_SIZE := 3.35
const CAMERA_HEAVY_SIZE := 3.70
const CAMERA_SPIN_SIZE := 3.35
const CAMERA_DEATH_SIZE := 3.00
const CAMERA_IDLE_HEIGHT := 0.85
const CAMERA_HEAVY_HEIGHT := 1.15
const CAMERA_SPIN_HEIGHT := 0.65


func get_warrior_visual() -> WarriorVisual3D:
	return get_character_visual() as WarriorVisual3D


func _on_visual_animation_started(animation_name: StringName) -> void:
	camera_orthographic_size = _camera_size_for_animation(animation_name)
	camera_look_at_height = _camera_height_for_animation(animation_name)
	super._on_visual_animation_started(animation_name)


func _on_visual_animation_finished(animation_name: StringName) -> void:
	super._on_visual_animation_finished(animation_name)
	if animation_name != WarriorVisual3D.ANIM_DEATH:
		camera_orthographic_size = CAMERA_IDLE_SIZE
		camera_look_at_height = CAMERA_IDLE_HEIGHT


func play_basic_attack() -> bool:
	var visual := get_warrior_visual()
	if visual == null:
		return false
	return _play_cast_action(
		WarriorVisual3D.ANIM_ATTACK,
		Callable(visual, "play_basic_attack")
	)


func play_hit() -> bool:
	if _death_locked or _visual_priority > VisualPriority.HIT:
		return false
	return _play_if_new(
		CharacterVisual3D.ACTION_HIT,
		VisualPriority.HIT,
		WarriorVisual3D.HIT_SPEED
	)


func play_death() -> bool:
	if _death_locked or _visual_priority == VisualPriority.DEATH:
		return false
	_death_locked = true
	_movement_active = false
	return _play_if_new(
		CharacterVisual3D.ACTION_DEATH,
		VisualPriority.DEATH,
		WarriorVisual3D.DEATH_SPEED
	)


func play_spell_action(spell: Spell = null) -> bool:
	var visual := get_warrior_visual()
	if visual == null:
		return false
	var animation_name := visual.get_animation_for_spell(spell)
	return _play_cast_action(
		animation_name,
		func() -> bool: return visual.play_spell_action(spell)
	)


func cancel_spell_action() -> void:
	var visual := get_warrior_visual()
	if visual != null and not visual.is_death_locked():
		visual.cancel_spell_action()
	_visual_priority = VisualPriority.IDLE


func get_weapon_effect_origin() -> Vector2:
	var visual := get_warrior_visual()
	return _project_effect_origin(
		visual.get_default_effect_mount() if visual != null else null,
		"warrior impact mount"
	)


func get_default_cast_effect_origin() -> Vector2:
	return get_weapon_effect_origin()


func _camera_size_for_animation(animation_name: StringName) -> float:
	match animation_name:
		WarriorVisual3D.ANIM_ATTACK:
			return CAMERA_ATTACK_SIZE
		WarriorVisual3D.ANIM_HEAVY_ATTACK:
			return CAMERA_HEAVY_SIZE
		WarriorVisual3D.ANIM_SPIN_ATTACK:
			return CAMERA_SPIN_SIZE
		WarriorVisual3D.ANIM_DEATH:
			return CAMERA_DEATH_SIZE
	return CAMERA_IDLE_SIZE


func _camera_height_for_animation(animation_name: StringName) -> float:
	match animation_name:
		WarriorVisual3D.ANIM_HEAVY_ATTACK:
			return CAMERA_HEAVY_HEIGHT
		WarriorVisual3D.ANIM_SPIN_ATTACK:
			return CAMERA_SPIN_HEIGHT
	return CAMERA_IDLE_HEIGHT
