class_name PasseRiveAutoSpriteView
extends AchillesIsoUnitView

var _stride_position := Vector2.ZERO
var pull_tether: Node2D
const PullTether := preload("res://vfx/class_cards/passe_rive_pull_tether.gd")
const S19Backend := preload("res://characters/achilles/2d/passe_rive_s19_backend.gd")
# The Battle/painted-room wrapper owns terrain calibration and camera scaling.
# Never cancel it here: doing so makes this actor grow relative to all enemies
# when the card dock reduces the playable viewport.


func uses_s19_cards() -> bool:
	var session = CatabaseCombatModifier.session_for(_unit) if _unit != null else null
	return session != null and session.cards != null


func set_spell_target_context(cell: Vector2i, spell: Spell) -> void:
	_clear_pull_tether()
	if spell == null or spell.spell_id != &"cc2_g04" or not uses_s19_cards():
		return
	var battle: Node = get_parent()
	while battle != null and not battle.has_method("grid_cell_to_parent_local"):
		battle = battle.get_parent()
	if battle == null or not is_instance_valid(sprite_backend):
		return
	var target: Unit = battle.grid.get_unit(cell)
	var view: Node2D = battle._unit_views.get(target)
	if not is_instance_valid(target) or not is_instance_valid(view):
		return
	var canvas := view.get_parent() as Node2D
	pull_tether = PullTether.new()
	canvas.add_child(pull_tether)
	var projector := func(at: Vector2i) -> Vector2:
		return canvas.to_global(battle.grid_cell_to_parent_local(at, canvas))
	pull_tether.configure(
		sprite_backend,
		_unit,
		target,
		view,
		projector,
		VFXManager._cell_visual_width(),
	)


func _clear_pull_tether() -> void:
	if is_instance_valid(pull_tether):
		pull_tether.cancel()
	pull_tether = null


func cancel_pending_visual_actions() -> void:
	_clear_pull_tether()
	super.cancel_pending_visual_actions()


func _sync_cards_mode() -> void:
	if sprite_backend is S19Backend:
		sprite_backend.set_cards_mode(uses_s19_cards())


func _play_active_action() -> bool:
	_sync_cards_mode()
	return super._play_active_action()


func _play_active_idle() -> bool:
	_sync_cards_mode()
	return super._play_active_idle()


func _play_active_movement() -> bool:
	_sync_cards_mode()
	return super._play_active_movement()


func get_movement_segment_duration(path: Array) -> float:
	if not uses_s19_cards() or sprite_profile == null or path.size() < 2:
		return super.get_movement_segment_duration(path)
	# Exploration's full stride takes 0.72 s walking / 0.60 s running. A cell
	# is not a stride: convert its actual projected length to actor units first.
	var battle: Node = get_parent()
	while battle != null and not battle.has_method("grid_cell_to_parent_local"):
		battle = battle.get_parent()
	if battle == null:
		return super.get_movement_segment_duration(path)
	var parent: Node = get_parent().get_parent()
	var origin: Vector2 = battle.grid_cell_to_parent_local(path[0], parent)
	var target: Vector2 = battle.grid_cell_to_parent_local(path[1], parent)
	var ground := target - origin
	var distance := Vector2(ground.x, ground.y * 2.0).length() / maxf(absf(scale.x), .001)
	var running := path.size() - 1 >= sprite_profile.run_min_path_cells
	var stride := (300.0 if running else 180.0) * sprite_profile.display_scale
	return clampf(distance / stride * (0.60 if running else 0.72), .05, 1.0)


func _ready() -> void:
	super._ready()
	EventBus.attack_dodged.connect(_on_attack_dodged)


func _exit_tree() -> void:
	_clear_pull_tether()
	if EventBus.attack_dodged.is_connected(_on_attack_dodged):
		EventBus.attack_dodged.disconnect(_on_attack_dodged)
	super._exit_tree()


func get_action_presentation() -> Dictionary:
	var presentation := super.get_action_presentation()
	if (
		not uses_s19_cards()
		and PasseRiveAutoSpriteBackend.action_for(&"cast", presentation) == "bow_air"
	):
		# Presentation distance scales with the battlefield, not the sprite atlas.
		presentation["projectile_arc_ratio"] = 0.65
	return presentation


func _on_attack_dodged(target: Unit, _attacker: Unit) -> void:
	if (
		target == _unit and not _closing and not _dead
		and sprite_backend is PasseRiveAutoSpriteBackend
	):
		(sprite_backend as PasseRiveAutoSpriteBackend).play_dodge(_facing)


func _begin_movement_feedback(
	from_cell: Vector2i,
	to_cell: Vector2i,
	action_id: StringName,
) -> void:
	_stride_position = (get_parent() as Node2D).position
	super._begin_movement_feedback(from_cell, to_cell, action_id)


func update_movement_stride(_step_index: int, _progress: float) -> void:
	if _closing or _dead or _action_pending or not _movement_feedback_owned:
		return
	var current := (get_parent() as Node2D).position
	var delta := current - _stride_position
	_stride_position = current
	if sprite_backend is PasseRiveAutoSpriteBackend:
		(sprite_backend as PasseRiveAutoSpriteBackend).advance_ground_distance(
			Vector2(delta.x, delta.y * 2.0).length()
			/ (maxf(absf(scale.x), 0.001) if uses_s19_cards() else 1.0)
		)
