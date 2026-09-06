class_name ParisSpellVFXRouter
extends RefCounted

const FX := preload("res://vfx/paris/paris_spell_sprite_vfx.gd")
const EFFECTS_PATH := "res://assets/vfx/paris/sprites_v1/effects.tres"
const SPELL_IDS := [&"paris_spectral_arrow", &"paris_fire_arrow", &"paris_ice_arrow",
	&"paris_vortex_arrow", &"paris_vortex_step", &"paris_infernal_whip",
	&"paris_infernal_sweep", &"paris_infernal_pull"]

var manager: Node
var frames: SpriteFrames
var effects: Array[Node] = []
var flights: Dictionary = {}
var resolved_actions: Array[String] = []


func _init(owner: Node) -> void:
	manager = owner


static func is_spell(caster: Unit, spell: Spell) -> bool:
	return is_instance_valid(caster) and caster.unit_id == &"catabase_shadow_paris" \
		and spell != null and spell.get_effective_spell_id() in SPELL_IDS


func load_frames() -> void:
	if frames == null and ResourceLoader.exists(EFFECTS_PATH):
		frames = load(EFFECTS_PATH) as SpriteFrames


func launch(caster: Unit, spell: Spell, cell: Vector2i) -> Node:
	if not manager._has_battle_view() or spell.impact_delay_seconds <= 0 \
			or not FX.FLIGHT_ANIMATIONS.has(spell.get_effective_spell_id()):
		return null
	var key: String = manager._flight_key(caster, spell)
	var previous: Variant = flights.get(key)
	if is_instance_valid(previous) and not previous.get_debug_state().closed:
		return previous
	var origin: Vector2 = manager._caster_effect_origin(caster)
	var targets: Array[Vector2] = [manager._impact_cell_position(cell)]
	var effect := _new_effect(spell.spell_id, origin, targets, 0.72)
	if effect != null:
		flights[key] = effect
		effect.start_flight(spell.impact_delay_seconds)
	return effect


func resolve(caster: Unit, spell: Spell, report: Dictionary) -> void:
	var key: String = manager._flight_key(caster, spell)
	var flight: Variant = flights.get(key)
	if bool(report.get("failed", false)):
		if is_instance_valid(flight):
			flight.cancel()
		flights.erase(key)
		return
	if not manager._has_battle_view():
		return
	var action_id := str(report.get("action_id", ""))
	var resolved_key := "%s:%s:%s" % [caster.get_instance_id(), spell.spell_id, action_id]
	if action_id != "" and resolved_actions.has(resolved_key):
		return
	if action_id != "":
		resolved_actions.append(resolved_key)
		if resolved_actions.size() > 128:
			resolved_actions.pop_front()
	var origin: Vector2 = manager._caster_effect_origin(caster)
	var cell: Vector2i = report.get("cell", caster.grid_pos)
	var impacted: Array[Vector2] = manager._resolved_impact_positions(report)
	if impacted.is_empty() and (not (report.get("terrain_changed", []) as Array).is_empty() \
			or not (report.get("status_changed_units", []) as Array).is_empty()):
		impacted.append(manager._impact_cell_position(cell))
	var id := spell.get_effective_spell_id()
	if FX.FLIGHT_ANIMATIONS.has(id):
		# All four arrows are single-target: preserve the pre-pull impact cell.
		if not (report.get("damaged_enemies", []) as Array).is_empty():
			impacted.assign([manager._impact_cell_position(cell)])
		flights.erase(key)
		if is_instance_valid(flight):
			flight.confirm_impact(impacted)
		elif not impacted.is_empty():
			var animation: StringName = &"hellfire" if id == &"paris_fire_arrow" \
				else &"vortex" if id == &"paris_vortex_arrow" else &"impact"
			_burst(spell.spell_id, animation, origin, impacted, 0.9, 0.30)
	elif id == &"paris_vortex_step":
		# SpellCaster records the actual arrival after terrain/portal resolution.
		# A rejected relocation cannot produce a decorative teleport.
		if report.has("caster_movement_from") and report.has("caster_movement_to"):
			var from: Vector2i = report.caster_movement_from
			var to: Vector2i = report.caster_movement_to
			if from != to:
				var positions: Array[Vector2] = [manager._grid_cell_global(from), manager._grid_cell_global(to)]
				_burst(id, &"vortex", origin, positions, 1.05, 0.48)
	elif id in [&"paris_infernal_whip", &"paris_infernal_pull"]:
		if not impacted.is_empty() or bool(report.get("pushed", false)):
			# Pull has already moved the target: the impact cell remains its launch cell.
			var targets: Array[Vector2] = [manager._impact_cell_position(cell)]
			_burst(id, &"whip", origin, targets, 1.0, 0.34)
	elif id == &"paris_infernal_sweep" and not impacted.is_empty():
		_burst(id, &"hellfire", origin, impacted, 1.0, 0.40)


func _burst(spell_id: StringName, animation: StringName, origin: Vector2,
		targets: Array[Vector2], width_ratio: float, duration: float) -> Node:
	var effect := _new_effect(spell_id, origin, targets, width_ratio)
	if effect != null:
		effect.start_burst(animation, duration)
	return effect


func _new_effect(spell_id: StringName, origin: Vector2,
		targets: Array[Vector2], width_ratio: float) -> Node:
	if not manager._has_battle_view() or targets.is_empty():
		return null
	load_frames()
	if frames == null:
		return null
	var parent: Node = manager._vfx_parent()
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var effect := FX.new()
	parent.add_child(effect)
	effect.configure(frames, spell_id, origin, targets, manager._cell_visual_width() * width_ratio)
	for index in range(effects.size() - 1, -1, -1):
		if not is_instance_valid(effects[index]):
			effects.remove_at(index)
	effects.append(effect)
	return effect


func clear() -> void:
	for effect in effects:
		if is_instance_valid(effect):
			effect.cancel()
	effects.clear()
	flights.clear()
	resolved_actions.clear()
