# core/vfx_manager.gd
extends Node

var _battle_view : Node = null

func register_battle_view(view: Node) -> void:
	_battle_view = view

func _ready() -> void:
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.status_applied.connect(_on_status_applied)
	EventBus.battle_view_ready.connect(register_battle_view)

func _on_spell_cast(caster: Unit, spell: Spell, report: Dictionary) -> void:
	if spell.impact_delay_seconds > 0.0:
		return
	play_spell_vfx(caster, spell, report.get("cell", caster.grid_pos))


func play_spell_vfx(caster: Unit, spell: Spell, cell: Vector2i) -> Node:
	if spell.vfx_scene == null:
		return null
	if _battle_view == null:
		return null
	var caster_view_pos := _caster_effect_origin(caster)
	var target_position := _grid_cell_global(cell)
	var vfx = spell.vfx_scene.instantiate()
	_vfx_parent().add_child(vfx)
	if spell.vfx_placement == Spell.VfxPlacement.TARGET_CELL:
		if vfx is Node2D:
			(vfx as Node2D).global_position = target_position
		elif vfx.has_method("initialiser_cible"):
			vfx.initialiser_cible(target_position)
	elif vfx.has_method("initialiser"):
		vfx.initialiser(caster_view_pos, target_position)
	elif vfx is Node2D:
		(vfx as Node2D).global_position = target_position
	return vfx

func _caster_effect_origin(caster: Unit) -> Vector2:
	if _battle_view != null and _battle_view.get_tree() != null:
		for candidate in _battle_view.get_tree().get_nodes_in_group("unit_views"):
			if candidate.get("unit") == caster \
					and candidate.has_method("get_cast_effect_origin_global"):
				return candidate.get_cast_effect_origin_global()
	return _grid_cell_global(caster.grid_pos)

func _on_status_applied(unit: Unit, status_data: StatusData) -> void:
	if status_data.vfx_scene == null:
		return
	if _battle_view == null:
		return
	var pos := _grid_cell_global(unit.grid_pos)
	var vfx = status_data.vfx_scene.instantiate()
	_vfx_parent().add_child(vfx)
	vfx.initialiser(pos)

func _grid_cell_global(cell: Vector2i) -> Vector2:
	var local_position: Vector2
	if _battle_view.has_method("grid_to_local"):
		local_position = _battle_view.grid_to_local(cell)
	else:
		local_position = _battle_view.grid_to_world(cell)
	return _battle_view.to_global(local_position)

func _vfx_parent() -> Node:
	var battle_root := _battle_view.get_parent()
	if battle_root != null:
		var layer := battle_root.get_node_or_null("VFXLayer")
		if layer != null:
			return layer
	return _battle_view
