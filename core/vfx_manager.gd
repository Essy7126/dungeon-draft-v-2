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
	if spell.vfx_scene == null:
		return
	if _battle_view == null:
		return
	var caster_view_pos : Vector2 = _battle_view.grid_to_world(caster.grid_pos)
	var cell_cible : Vector2i = report.get("cell", caster.grid_pos)
	var vers : Vector2 = _battle_view.grid_to_world(cell_cible)
	var vfx = spell.vfx_scene.instantiate()
	_battle_view.add_child(vfx)
	vfx.initialiser(caster_view_pos, vers)

func _on_status_applied(unit: Unit, status_data: StatusData) -> void:
	if status_data.vfx_scene == null:
		return
	if _battle_view == null:
		return
	var pos : Vector2 = _battle_view.grid_to_world(unit.grid_pos)
	var vfx = status_data.vfx_scene.instantiate()
	_battle_view.add_child(vfx)
	vfx.initialiser(pos)
